import { useEffect, useState, type ReactNode } from "react";
import { getResources } from "../api";
import { afterPaymentText, levelText, t } from "../i18n";
import { downloadReport } from "../report";
import type { Analysis, Lang, Resource, RiskLevel, Signal, Source } from "../types";
import AgentPanel from "./AgentPanel";
import { AudioPlayer, Thumb } from "./InputView";

interface Props {
  lang: Lang;
  result: Analysis;
  files: File[];
  audios: File[];
  previousLevel: RiskLevel | null;
  onNew: () => void;
  onComplaint: () => void;
  onAddReply: () => void;
}

export default function ResultView({ lang, result, files, audios, previousLevel, onNew, onComplaint, onAddReply }: Props) {
  const [resources, setResources] = useState<Resource[]>([]);
  const [active, setActive] = useState<Signal | null>(null);
  useEffect(() => {
    getResources().then(setResources).catch(() => setResources([]));
  }, []);

  const grounded = result.signals.filter((s) => s.grounded);
  const unverified = result.signals.filter((s) => !s.grounded);
  const paidLevel = result.stage === "after_payment" ? afterPaymentText[result.overall.level]?.[lang] : undefined;
  const level = paidLevel ?? levelText[result.overall.level][lang];
  const summary = lang === "ne" ? result.overall.summary_ne : result.overall.summary_en;
  const sourceLabel = (id: string) => {
    const s = result.sources.find((x) => x.id === id);
    return s?.filename ?? (s?.kind === "text" ? (lang === "ne" ? "टाँसिएको पाठ" : "Pasted text") : id);
  };

  function showEvidence(sig: Signal) {
    setActive(sig);
    requestAnimationFrame(() =>
      document.getElementById(`src-${sig.source_id}`)?.scrollIntoView({ behavior: "smooth", block: "start" }),
    );
  }

  const complaintButton = (
    <button className={result.stage === "after_payment" ? "primary" : "secondary"} onClick={onComplaint}>
      {t("prepareComplaint", lang)}
    </button>
  );

  return (
    <section className="stack">
      <div className={`banner level-${result.overall.level}`} role="status">
        <h1>{level.title}</h1>
        <p>{level.body}</p>
        {summary && result.engine === "gemma" && <p className="banner-summary">{summary}</p>}
      </div>

      {previousLevel && (
        <p className="notice">
          {previousLevel !== result.overall.level ? (
            <>{t("riskChanged", lang)}: {levelText[previousLevel][lang].title} → <strong>{level.title}</strong></>
          ) : (
            <>{t("riskSame", lang)}: <strong>{level.title}</strong></>
          )}
        </p>
      )}
      {result.engine === "offline-rules" && <p className="notice">{t("offlineEngine", lang)}</p>}
      {result.warnings.map((w) => (
        <p key={w} className="notice">{w}</p>
      ))}

      {result.stage === "after_payment" && complaintButton}

      {result.qr.length > 0 && (
        <div className="card stack-sm">
          <h2>{t("qrTitle", lang)}</h2>
          {result.qr.map((q, i) => (
            <dl key={i} className="qr">
              <dt>{t("qrPayee", lang)}</dt>
              <dd className="qr-payee">{q.payee_name ?? "—"}</dd>
              {q.amount && (<><dt>Amount</dt><dd>{q.currency ?? ""} {q.amount}</dd></>)}
              {q.city && (<><dt>City</dt><dd>{q.city}</dd></>)}
              {q.network_ids.length > 0 && (<><dt>Network</dt><dd>{q.network_ids.join(", ")}</dd></>)}
              {q.crc_valid === false && <dd className="error">{t("qrChecksumBad", lang)}</dd>}
              {q.notes.map((n) => <dd key={n} className="muted small">{n}</dd>)}
            </dl>
          ))}
        </div>
      )}

      <div className="stack-sm">
        <h2>{t("signals", lang)}</h2>
        {grounded.length === 0 && <p className="muted">{t("noSignals", lang)}</p>}
        {grounded.map((sig, i) => (
          <SignalCard key={i} sig={sig} lang={lang} sourceLabel={sourceLabel} onShow={() => showEvidence(sig)} />
        ))}
      </div>

      <AgentPanel lang={lang} result={result} onAddReply={onAddReply} />

      <div className="card stack-sm">
        <h2>{t("nextSteps", lang)}</h2>
        <ol className="steps">
          {result.next_steps.map((step, i) => {
            const res = resources.find((r) => r.id === step.resource_id);
            return (
              <li key={i}>
                {lang === "ne" ? step.text_ne : step.text_en}
                {res && <ResourceLink res={res} lang={lang} />}
              </li>
            );
          })}
        </ol>
      </div>

      {result.events.length > 0 && (
        <div className="card stack-sm">
          <h2>{t("timeline", lang)}</h2>
          <ol className="timeline">
            {result.events.map((ev, i) => (
              <li key={i}>
                <span className="timeline-when">{ev.when ?? "—"}</span>
                <span>{lang === "ne" ? ev.summary_ne || ev.summary_en : ev.summary_en}</span>
                {ev.span && <span className="muted small"> · {sourceLabel(ev.source_id)}</span>}
              </li>
            ))}
          </ol>
        </div>
      )}

      {unverified.length > 0 && (
        <details className="card">
          <summary>{t("unverified", lang)} ({unverified.length})</summary>
          <p className="muted small">{t("unverifiedHelp", lang)}</p>
          {unverified.map((sig, i) => (
            <SignalCard key={i} sig={sig} lang={lang} sourceLabel={sourceLabel} />
          ))}
        </details>
      )}

      <div className="stack-sm">
        <h2>{t("sources", lang)}</h2>
        {result.sources.map((src) => (
          <SourceCard
            key={src.id}
            src={src}
            file={fileFor(src, files, audios)}
            signals={grounded.filter((s) => s.source_id === src.id && s.span)}
            active={active}
            lang={lang}
          />
        ))}
      </div>

      <div className="actions">
        <button className="secondary" onClick={() => downloadReport(result, files, audios)}>{t("downloadReport", lang)}</button>
        {result.stage !== "after_payment" && complaintButton}
        <button className="ghost" onClick={onNew}>{t("newCheck", lang)}</button>
      </div>
    </section>
  );
}

function SignalCard({
  sig,
  lang,
  sourceLabel,
  onShow,
}: {
  sig: Signal;
  lang: Lang;
  sourceLabel: (id: string) => string;
  onShow?: () => void;
}) {
  return (
    <article className={`signal sev-${sig.severity}`}>
      <header>
        <span className={`badge sev-${sig.severity}`}>{sig.severity}</span>
        <h3>{lang === "ne" ? sig.title_ne : sig.title_en}</h3>
      </header>
      <blockquote>“{sig.quote}”</blockquote>
      <p className="muted small">
        {t("evidence", lang)}: {sourceLabel(sig.source_id)}
        {sig.origin === "qr" && " · QR"}
        {onShow && sig.span && (
          <button className="link" onClick={onShow}>↓</button>
        )}
      </p>
      <p>{lang === "ne" ? sig.explanation_ne || sig.explanation_en : sig.explanation_en}</p>
      {sig.unknowns_en.length > 0 && (
        <p className="small"><strong>{t("unknowns", lang)}:</strong> {sig.unknowns_en.join("; ")}</p>
      )}
      {sig.not_always_scam_en && (
        <p className="small muted"><strong>{t("notAlways", lang)}:</strong> {sig.not_always_scam_en}</p>
      )}
    </article>
  );
}

function fileFor(src: Source, files: File[], audios: File[]): File | undefined {
  const index = Number(src.id.split("_")[1]) - 1;
  if (src.kind === "image") return files[index];
  if (src.kind === "audio") return audios[index];
  return undefined;
}

function ResourceLink({ res, lang }: { res: Resource; lang: Lang }) {
  const name = lang === "ne" ? res.name_ne : res.name_en;
  const checked = res.last_checked
    ? `${t("checkedOn", lang)} ${res.last_checked}`
    : t("notVerifiedLink", lang);
  return (
    <div className="resource small">
      {res.url ? <a href={res.url} target="_blank" rel="noopener noreferrer">{name} ↗</a> : <strong>{name}</strong>}
      <span className="muted"> · {checked}</span>
    </div>
  );
}

function SourceCard({
  src,
  file,
  signals,
  active,
  lang,
}: {
  src: Source;
  file?: File;
  signals: Signal[];
  active: Signal | null;
  lang: Lang;
}) {
  return (
    <div className="card source" id={`src-${src.id}`}>
      <p className="label">{src.filename ?? (lang === "ne" ? "टाँसिएको पाठ" : "Pasted text")}</p>
      {file && src.kind === "image" && <div className="source-image"><Thumb file={file} /></div>}
      {file && src.kind === "audio" && <AudioPlayer file={file} />}
      {src.transcript_by === "model" && <p className="muted small">{t("readByModel", lang)}</p>}
      {src.transcript_by === "asr" && <p className="muted small">{t("voiceTranscript", lang)}</p>}
      {src.transcript && <pre className="transcript">{highlight(src.transcript, signals, active)}</pre>}
    </div>
  );
}

function highlight(text: string, signals: Signal[], active: Signal | null) {
  const spans = signals
    .map((s) => ({ ...s.span!, sig: s }))
    .sort((a, b) => a.start - b.start)
    .filter((s, i, arr) => i === 0 || s.start >= arr[i - 1].end); // drop overlaps
  const out: ReactNode[] = [];
  let pos = 0;
  spans.forEach((s, i) => {
    if (s.start > pos) out.push(text.slice(pos, s.start));
    const isActive = active?.span?.start === s.start && active.source_id === s.sig.source_id;
    out.push(
      <mark key={i} className={`sev-${s.sig.severity}${isActive ? " active" : ""}`}>
        {text.slice(s.start, s.end)}
      </mark>,
    );
    pos = s.end;
  });
  out.push(text.slice(pos));
  return out;
}
