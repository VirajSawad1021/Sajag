"""Offline keyword analyzer. Used when SAJAG_MOCK=1 (no API key) and as a fallback if Gemma
fails. It only reads pasted text — it cannot read screenshots — and it is much weaker than Gemma."""

from __future__ import annotations

import re

from .schemas import ModelOutput, ModelSignal, Source


def _keyword_regex(keyword: str) -> re.Pattern:
    escaped = re.escape(keyword)
    if keyword.isascii():
        return re.compile(rf"\b{escaped}\b", re.IGNORECASE)
    return re.compile(escaped)


def keyword_analyze(sources: list[Source], pattern_catalog: dict[str, dict]) -> ModelOutput:
    signals: list[ModelSignal] = []
    for source in sources:
        if source.kind not in ("text", "audio"):
            continue
        for line in source.transcript.splitlines():
            line = line.strip()
            if not line:
                continue
            for pattern in pattern_catalog.values():
                if any(_keyword_regex(k).search(line) for k in pattern.get("keywords") or []):
                    signals.append(
                        ModelSignal(
                            pattern_id=pattern["id"],
                            source_id=source.id,
                            quote=line[:200],
                            explanation_en=pattern.get("why_en", ""),
                            explanation_ne=pattern.get("why_ne", ""),
                        )
                    )
    has_text = any(s.kind == "text" and s.transcript.strip() for s in sources)
    return ModelOutput(
        enough_information=has_text,
        summary_en="Offline keyword check only — Gemma was not used, so screenshots were not read.",
        summary_ne="केवल अफलाइन शब्द-जाँच — Gemma प्रयोग नभएकाले स्क्रिनसट पढिएन।",
        signals=signals,
    )
