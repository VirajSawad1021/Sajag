import { useEffect, useState } from "react";
import { runAgent, type AgentResult } from "../api";
import { t } from "../i18n";
import type { Analysis, Lang } from "../types";

// Runs automatically once results are shown: Gemma searches the web with tools it chooses and writes
// Suraksha Scripts (messages the user can send to the seller). The agent never contacts anyone itself.
export default function AgentPanel({ lang, result, onAddReply }: { lang: Lang; result: Analysis; onAddReply: () => void }) {
  const [agent, setAgent] = useState<AgentResult | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [copied, setCopied] = useState<number | null>(null);

  useEffect(() => {
    if (result.engine !== "gemma") return;
    let cancelled = false;
    setAgent(null);
    setError(null);
    runAgent(result)
      .then((r) => !cancelled && setAgent(r))
      .catch((e) => !cancelled && setError(e instanceof Error ? e.message : String(e)));
    return () => {
      cancelled = true;
    };
  }, [result]);

  if (result.engine !== "gemma") return null;

  function copy(text: string, i: number) {
    navigator.clipboard.writeText(text).then(() => {
      setCopied(i);
      setTimeout(() => setCopied(null), 2000);
    });
  }

  return (
    <div className="card stack-sm agent">
      <h2>🛡 {t("agentTitle", lang)}</h2>
      {!agent && !error && <p className="muted" aria-live="polite">{t("agentWorking", lang)}</p>}
      {error && <p className="error small">{error}</p>}
      {agent && (
        <>
          {agent.trace.length > 0 && (
            <ul className="trace small muted">
              {agent.trace.map((line, i) => (
                <li key={i}>🔎 {line.replace(/^web_search: /, "")}</li>
              ))}
            </ul>
          )}
          <p>{lang === "ne" ? agent.online_summary_ne || agent.online_summary_en : agent.online_summary_en}</p>
          {agent.findings.some((f) => f.sources.length > 0) && (
            <details>
              <summary className="small">{t("agentSources", lang)}</summary>
              <ul className="small">
                {agent.findings.map((f, i) => (
                  <li key={i}>
                    <strong>{f.query}</strong>: {f.summary}{" "}
                    {f.sources.map((s, j) => (
                      <a key={j} href={s.url} target="_blank" rel="noopener noreferrer">[{s.title}]</a>
                    ))}
                  </li>
                ))}
              </ul>
            </details>
          )}

          <h3>{t("scriptsTitle", lang)}</h3>
          <p className="muted small">{t("scriptsHelp", lang)}</p>
          {agent.scripts.map((s, i) => (
            <div key={i} className="script">
              <p className="label">{lang === "ne" ? s.purpose_ne || s.purpose_en : s.purpose_en}</p>
              <blockquote lang="ne">{s.message_ne}</blockquote>
              {lang === "en" && s.message_en && <p className="small muted">{s.message_en}</p>}
              {s.verifies_en && <p className="small muted">↳ {s.verifies_en}</p>}
              <button className="secondary small" onClick={() => copy(s.message_ne, i)}>
                {copied === i ? t("copied", lang) : t("copy", lang)}
              </button>
            </div>
          ))}
          <p className="small">
            <strong>{t("whatChanges", lang)}:</strong>{" "}
            {lang === "ne" ? agent.what_changes_risk_ne || agent.what_changes_risk_en : agent.what_changes_risk_en}
          </p>
          <button className="primary" onClick={onAddReply}>{t("addReply", lang)}</button>
        </>
      )}
    </div>
  );
}
