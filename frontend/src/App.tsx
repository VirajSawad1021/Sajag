import { useEffect, useState } from "react";
import { analyze } from "./api";
import ComplaintView from "./components/ComplaintView";
import InputView from "./components/InputView";
import ResultView from "./components/ResultView";
import { t } from "./i18n";
import { takeSharedItems } from "./share";
import type { Analysis, Lang, RiskLevel, Stage } from "./types";

type View = "input" | "result" | "complaint";

export default function App() {
  const [lang, setLang] = useState<Lang>("ne");
  const [view, setView] = useState<View>("input");
  const [stage, setStage] = useState<Stage>("before_payment");
  const [text, setText] = useState("");
  const [files, setFiles] = useState<File[]>([]);
  const [audios, setAudios] = useState<File[]>([]);
  const [result, setResult] = useState<Analysis | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [previousLevel, setPreviousLevel] = useState<RiskLevel | null>(null);

  useEffect(() => {
    takeSharedItems().then((shared) => {
      if (!shared) return;
      setFiles(shared.files);
      if (shared.text) setText(shared.text);
    });
  }, []);

  async function runCheck() {
    setLoading(true);
    setError(null);
    try {
      setResult(await analyze(text, files, audios, stage));
      setView("result");
      window.scrollTo(0, 0);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setLoading(false);
    }
  }

  function reset() {
    setText("");
    setFiles([]);
    setAudios([]);
    setResult(null);
    setPreviousLevel(null);
    setView("input");
  }

  return (
    <div className="app">
      <header className="topbar">
        <button className="brand" onClick={reset} aria-label="Sajag home">
          <img src="/icon-192.png" alt="" width={28} height={28} />
          <span>Sajag <span className="brand-ne">सजग</span></span>
        </button>
        <div className="lang-toggle" role="group" aria-label="Language">
          <button aria-pressed={lang === "ne"} onClick={() => setLang("ne")}>नेपाली</button>
          <button aria-pressed={lang === "en"} onClick={() => setLang("en")}>EN</button>
        </div>
      </header>

      <main>
        {view === "input" && (
          <InputView
            lang={lang}
            stage={stage}
            setStage={setStage}
            text={text}
            setText={setText}
            files={files}
            setFiles={setFiles}
            audios={audios}
            setAudios={setAudios}
            loading={loading}
            error={error}
            onSubmit={runCheck}
            followUp={previousLevel !== null}
          />
        )}
        {view === "result" && result && (
          <ResultView
            lang={lang}
            result={result}
            files={files}
            audios={audios}
            previousLevel={previousLevel}
            onNew={reset}
            onComplaint={() => setView("complaint")}
            onAddReply={() => {
              // Keep the earlier evidence; the user adds the seller's reply and we re-check everything together.
              setPreviousLevel(result.overall.level);
              setView("input");
              window.scrollTo(0, 0);
            }}
          />
        )}
        {view === "complaint" && result && (
          <ComplaintView lang={lang} result={result} onBack={() => setView("result")} />
        )}
      </main>

      <footer className="footer">{t("disclaimer", lang)}</footer>
    </div>
  );
}
