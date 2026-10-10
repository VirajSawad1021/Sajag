"""The analysis pipeline: QR decode -> Gemma extraction -> quote grounding -> deterministic checks."""

from __future__ import annotations

import re
from collections.abc import Callable
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from datetime import date
from difflib import SequenceMatcher

from pydantic import ValidationError

from . import asr, catalog, gemma, vision
from .config import MOCK_MODE
from .grounding import find_span, normalize
from .prompts import build_analyze_prompt
from .qr import decode_qr_payloads, parse_payment_qr
from .rules import keyword_analyze
from .sms import parse_payments
from .schemas import (
    AnalysisResponse,
    Deadline,
    Event,
    Fact,
    ModelOutput,
    NextStep,
    Overall,
    QrInfo,
    Signal,
    Source,
    Span,
)

SEVERITY_ORDER = {"high": 0, "medium": 1, "low": 2}


@dataclass
class UploadedImage:
    filename: str
    data: bytes
    mime: str


@dataclass
class UploadedAudio:
    filename: str
    data: bytes


Progress = Callable[[str, dict], None]


def _noop(_step: str, _data: dict) -> None:
    pass


def analyze(
    text: str,
    images: list[UploadedImage],
    stage: str,
    audios: list[UploadedAudio] | None = None,
    progress: Progress | None = None,
) -> AnalysisResponse:
    """Run the full pipeline. `progress(step, data)` is called as each stage finishes (for the live feed)."""
    emit = progress or _noop
    pattern_catalog = catalog.patterns()
    warnings: list[str] = []
    audios = audios or []

    sources: list[Source] = []
    if text.strip():
        sources.append(Source(id="text_1", kind="text", transcript=normalize(text.strip()), transcript_by="user"))
    for i, img in enumerate(images, start=1):
        sources.append(Source(id=f"img_{i}", kind="image", filename=img.filename))
    audio_sources = [Source(id=f"aud_{i}", kind="audio", filename=a.filename) for i, a in enumerate(audios, start=1)]
    sources += audio_sources
    emit("received", {"images": len(images), "audios": len(audios), "text": bool(text.strip())})
    payments = [p for s in sources if s.kind == "text" for p in parse_payments(s.transcript, s.id)]
    for p in payments:
        emit("sms", {"amount": p.amount, "direction": p.direction, "transaction_id": p.transaction_id, "date": p.date})

    pool = ThreadPoolExecutor(max_workers=max(1, len(images)))
    # Scam X-Ray boxes run in parallel with everything else; they only decorate verified warnings.
    locate = {} if MOCK_MODE else {img_src.id: pool.submit(_safe_locate, img) for img_src, img in
                                   zip((s for s in sources if s.kind == "image"), images)}

    if audios:
        _transcribe_audio(audio_sources, audios, warnings)
        for s in audio_sources:
            if s.transcript:
                emit("voice", {"source_id": s.id, "seconds": s.duration_s, "transcript": s.transcript[:240]})

    qr: list[QrInfo] = []
    for source, img in zip((s for s in sources if s.kind == "image"), images):
        for payload in decode_qr_payloads(img.data):
            info = parse_payment_qr(payload, source.id)
            qr.append(info)
            emit("qr", {"source_id": source.id, "payee": info.payee_name, "crc_valid": info.crc_valid})

    if images or any(s.transcript for s in sources):
        emit("reading", {"images": len(images), "engine": "offline-rules" if MOCK_MODE else "gemma"})
    model_out, engine = _run_model(sources, images, qr, stage, pattern_catalog, warnings, _phase_reporter(emit))

    for source in sources:
        if source.kind == "image" and source.id in model_out.transcripts:
            source.transcript = normalize(model_out.transcripts[source.id])
            source.transcript_by = "model"
    transcripts = {s.id: s.transcript for s in sources}
    emit("read", {"events": len(model_out.events), "facts": len(model_out.facts),
                  "sellers": model_out.claimed_seller_names[:3]})

    signals = _ground_signals(model_out, transcripts, pattern_catalog, engine, warnings)
    facts = [Fact(**f.model_dump(), span=_span_in(f.quote, f.source_id, transcripts)) for f in model_out.facts]
    events = [Event(**e.model_dump(), span=_span_in(e.quote, e.source_id, transcripts)) for e in model_out.events]
    deadlines = [_check_deadline(d, transcripts) for d in model_out.deadlines]

    signals += _qr_checks(qr, model_out.claimed_seller_names, pattern_catalog, facts)
    _add_payment_facts(payments, facts, events, transcripts)

    signals.sort(key=lambda s: (not s.grounded, SEVERITY_ORDER[s.severity]))
    grounded = [s for s in signals if s.grounded]
    for s in grounded:
        emit("signal", {"pattern_id": s.pattern_id, "title_en": s.title_en, "title_ne": s.title_ne,
                        "severity": s.severity, "quote": s.quote[:160], "origin": s.origin})
    dropped = len(signals) - len(grounded)
    if dropped:
        warnings.append(
            f"{dropped} possible signal(s) quoted text that could not be found in your evidence. "
            "They are listed as unverified and do not affect the result."
        )

    for source in sources:
        if source.id in locate:
            source.regions = locate[source.id].result()
    pool.shutdown(wait=False)
    vision.attach_regions(sources, signals)
    boxed = sum(1 for s in signals if s.region is not None)
    if boxed:
        emit("xray", {"boxes": boxed})

    return AnalysisResponse(
        overall=Overall(
            level=_level(grounded, model_out.enough_information, sources),
            summary_en=model_out.summary_en,
            summary_ne=model_out.summary_ne,
        ),
        stage=stage,
        sources=sources,
        qr=qr,
        facts=facts,
        events=events,
        signals=signals,
        next_steps=_next_steps(grounded, stage, pattern_catalog),
        deadlines=deadlines,
        seller_names=[n for n in dict.fromkeys(model_out.claimed_seller_names) if n.strip()],
        payments=payments,
        warnings=warnings,
        engine=engine,
    )


def _add_payment_facts(payments, facts: list, events: list, transcripts: dict[str, str]) -> None:
    """Payments read by code from SMS become facts (and a timeline event if Gemma didn't already add one)."""
    for p in payments:
        span = _span_in(p.quote.splitlines()[0], p.source_id, transcripts)
        facts.append(Fact(field="payment", value=f"Rs {p.amount} {p.direction}", source_id=p.source_id,
                          quote=p.quote.splitlines()[0], span=span))
        if p.transaction_id:
            facts.append(Fact(field="transaction_id", value=p.transaction_id, source_id=p.source_id,
                              quote=p.transaction_id, span=_span_in(p.transaction_id, p.source_id, transcripts)))
    if payments and not any(e.type == "payment_made" for e in events):
        p = next((x for x in payments if x.direction == "debit"), payments[0])
        events.append(Event(when=p.date, when_source="shown" if p.date else "unknown", type="payment_made",
                            summary_en=f"Rs {p.amount} {p.direction} (from SMS)",
                            summary_ne=f"रु {p.amount} {'भुक्तानी गरियो' if p.direction == 'debit' else 'प्राप्त भयो'} (SMS अनुसार)",
                            source_id=p.source_id, quote=p.quote.splitlines()[0]))


def _safe_locate(img: UploadedImage) -> list:
    try:
        return vision.locate_regions(img.data, img.mime)
    except Exception as exc:  # X-Ray is decoration; never fail the analysis over it
        vision.log.warning("locate failed: %s", str(exc)[:200])
        return []


def _check_deadline(d, transcripts: dict[str, str]) -> Deadline:
    """Keep a due date only if it is a real ISO date; ground the quote like any other claim."""
    due = d.due
    try:
        due = date.fromisoformat(due).isoformat() if due else None
    except ValueError:
        due = None
    grounded = bool(d.quote) and _span_in(d.quote, d.source_id, transcripts) is not None
    return Deadline(**{**d.model_dump(), "due": due}, grounded=grounded)


def _transcribe_audio(audio_sources: list[Source], audios: list[UploadedAudio], warnings: list[str]) -> None:
    if not audios:
        return
    if MOCK_MODE:
        warnings.append("Voice notes need online mode (speech-to-text); they were not analysed.")
        return

    def run(audio: UploadedAudio):
        try:
            return asr.transcribe(audio.data)
        except asr.AsrError as exc:
            return exc

    with ThreadPoolExecutor(max_workers=len(audios)) as pool:
        results = list(pool.map(run, audios))
    for source, result in zip(audio_sources, results):
        if isinstance(result, Exception):
            warnings.append(f"{source.filename}: {result}")
            continue
        transcript, seconds = result
        source.duration_s = round(seconds, 1)
        if transcript.strip() == "[no speech]":
            warnings.append(f"{source.filename}: no speech was detected.")
            continue
        source.transcript = normalize(transcript)
        source.transcript_by = "asr"


# Keys in Gemma's JSON reply, in the order it writes them, mapped to a live-feed phase.
_PHASES = [
    ('"transcripts"', "transcribing"),
    ('"facts"', "facts"),
    ('"events"', "timeline"),
    ('"signals"', "signals"),
    ('"deadlines"', "deadlines"),
]


def _phase_reporter(emit: Progress) -> Callable[[str], None]:
    """Turn Gemma's streamed reply into 'phase' progress events (once per phase) plus a character count."""
    seen: set[str] = set()
    last = [0]

    def on_text(text: str) -> None:
        for key, phase in _PHASES:
            if phase not in seen and key in text:
                seen.add(phase)
                emit("phase", {"phase": phase})
        if len(text) - last[0] >= 600:
            last[0] = len(text)
            emit("writing", {"chars": len(text)})

    return on_text


def _run_model(sources, images, qr, stage, pattern_catalog, warnings, on_text=None) -> tuple[ModelOutput, str]:
    if MOCK_MODE:
        return keyword_analyze(sources, pattern_catalog), "offline-rules"
    if not images and not any(s.transcript for s in sources):
        return ModelOutput(enough_information=False), "gemma"  # nothing readable (e.g. silent voice note)
    source_lines = []
    for s in sources:
        if s.kind == "text":
            source_lines.append(f'### {s.id} (TEXT pasted by user)\n"""\n{s.transcript}\n"""')
        elif s.kind == "audio":
            if s.transcript:
                source_lines.append(
                    f"### {s.id} (VOICE NOTE, already transcribed by speech-to-text; may contain recognition "
                    f'errors; speaker not identified)\n"""\n{s.transcript}\n"""'
                )
        else:
            source_lines.append(f"### {s.id} (IMAGE #{s.id.split('_')[1]} attached above, file: {s.filename})")
    prompt = build_analyze_prompt(source_lines, qr, stage, pattern_catalog)
    try:
        raw = gemma.generate_json(prompt, [(img.data, img.mime) for img in images], on_text=on_text)
        return ModelOutput.model_validate(raw), "gemma"
    except (gemma.ModelError, ValidationError) as exc:
        warnings.append(f"Gemma analysis failed ({type(exc).__name__}); showing offline keyword checks only.")
        return keyword_analyze(sources, pattern_catalog), "offline-rules"


def _span_in(quote: str, source_id: str, transcripts: dict[str, str]) -> Span | None:
    return find_span(quote, transcripts.get(source_id, "")) if quote else None


def _ground_signals(model_out, transcripts, pattern_catalog, engine, warnings) -> list[Signal]:
    out: list[Signal] = []
    seen: set[tuple] = set()
    for sig in model_out.signals:
        pattern = pattern_catalog.get(sig.pattern_id)
        if pattern is None or pattern.get("detected_by") == "code":  # QR checks are decided by code only
            if pattern is None:
                warnings.append(f"Ignored unknown pattern id from model: {sig.pattern_id!r}")
            continue
        source_id, span = sig.source_id, _span_in(sig.quote, sig.source_id, transcripts)
        if span is None:  # the model sometimes labels the wrong source; look in the others
            for other_id, transcript in transcripts.items():
                if (span := find_span(sig.quote, transcript)) is not None:
                    source_id = other_id
                    break
        key = (sig.pattern_id, source_id, span.start if span else sig.quote)
        if key in seen:
            continue
        seen.add(key)
        out.append(
            Signal(
                pattern_id=sig.pattern_id,
                title_en=pattern["title_en"],
                title_ne=pattern["title_ne"],
                severity=pattern["severity"],
                source_id=source_id,
                quote=sig.quote,
                span=span,
                grounded=span is not None,
                origin="model" if engine == "gemma" else "rule",
                explanation_en=sig.explanation_en or pattern.get("why_en", ""),
                explanation_ne=sig.explanation_ne or pattern.get("why_ne", ""),
                unknowns_en=sig.unknowns_en,
                not_always_scam_en=pattern.get("not_always_scam_en", ""),
            )
        )
    return out


def _tokens(name: str) -> set[str]:
    return {t for t in re.findall(r"\w+", name.casefold()) if len(t) >= 3}


def names_match(a: str, b: str) -> bool:
    if _tokens(a) & _tokens(b):
        return True
    return SequenceMatcher(None, a.casefold(), b.casefold()).ratio() >= 0.6


def _qr_checks(qr: list[QrInfo], seller_names: list[str], pattern_catalog: dict, facts: list[Fact]) -> list[Signal]:
    signals: list[Signal] = []
    pattern = pattern_catalog["qr_payee_mismatch"]
    for q in qr:
        if q.crc_valid is False:
            bad = pattern_catalog["qr_checksum_invalid"]
            signals.append(
                Signal(
                    pattern_id=bad["id"],
                    title_en=bad["title_en"],
                    title_ne=bad["title_ne"],
                    severity=bad["severity"],
                    source_id=q.source_id,
                    quote=q.payee_name or "QR",
                    grounded=True,
                    origin="qr",
                    explanation_en=bad["why_en"],
                    explanation_ne=bad["why_ne"],
                    not_always_scam_en=bad.get("not_always_scam_en", ""),
                )
            )
    seller_names = [n for n in dict.fromkeys(seller_names) if n.strip()]
    for q in qr:
        if not q.payee_name:
            continue
        facts.append(Fact(field="qr_payee", value=q.payee_name, source_id=q.source_id))
        if not seller_names or any(names_match(q.payee_name, n) for n in seller_names):
            continue
        claimed = ", ".join(f'"{n}"' for n in seller_names[:3])
        signals.append(
            Signal(
                pattern_id=pattern["id"],
                title_en=pattern["title_en"],
                title_ne=pattern["title_ne"],
                severity=pattern["severity"],
                source_id=q.source_id,
                quote=q.payee_name,
                grounded=True,
                origin="qr",
                explanation_en=f'The QR code pays "{q.payee_name}", but the chat/listing uses {claimed}. '
                + pattern["why_en"],
                explanation_ne=f'QR ले "{q.payee_name}" लाई पैसा पठाउँछ, तर च्याट/विज्ञापनमा {claimed} नाम छ। '
                + pattern["why_ne"],
                unknowns_en=["Whether the seller personally owns this account"],
                not_always_scam_en=pattern.get("not_always_scam_en", ""),
            )
        )
    return signals


def _level(grounded: list[Signal], enough_information: bool, sources: list[Source]) -> str:
    if not sources:
        return "insufficient"
    severities = {s.severity for s in grounded}
    if "high" in severities:
        return "high"
    if "medium" in severities or len(grounded) >= 2:
        return "caution"
    if grounded:
        return "low"
    return "low" if enough_information else "insufficient"


def _next_steps(grounded: list[Signal], stage: str, pattern_catalog: dict[str, dict]) -> list[NextStep]:
    steps: list[NextStep] = []
    seen: set[str] = set()

    def add(items: list[dict]) -> None:
        for item in items:
            if item["en"] not in seen:
                seen.add(item["en"])
                steps.append(NextStep(text_en=item["en"], text_ne=item["ne"], resource_id=item.get("resource")))

    if stage == "after_payment":
        add(catalog.stage_steps()["after_payment"])
    for sig in grounded:
        add(pattern_catalog[sig.pattern_id]["next_steps"])
    if stage == "before_payment":
        add(catalog.stage_steps()["before_payment"])
    return steps
