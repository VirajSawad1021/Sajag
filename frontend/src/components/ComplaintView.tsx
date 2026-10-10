import { useState } from "react";
import { draftComplaint, type ComplaintInput } from "../api";
import { t } from "../i18n";
import type { Analysis, Lang, Resource } from "../types";

const RECIPIENTS: { id: ComplaintInput["recipient"]; ne: string; en: string }[] = [
  { id: "bank", ne: "बैंक / वालेट", en: "Bank / wallet" },
  { id: "cyber_bureau", ne: "साइबर ब्युरो", en: "Cyber Bureau" },
  { id: "nrb", ne: "नेपाल राष्ट्र बैंक", en: "Nepal Rastra Bank" },
  { id: "consumer", ne: "वाणिज्य विभाग", en: "Dept. of Commerce" },
];

export default function ComplaintView({ lang, result, onBack }: { lang: Lang; result: Analysis; onBack: () => void }) {
  const [input, setInput] = useState<ComplaintInput>({
    recipient: "bank",
    bank_name: "",
    complainant: { name: "", address: "", phone: "" },
    user_story_ne: "",
    amount_paid: "",
    paid_on: "",
    transaction_ref: "",
  });
  const [draft, setDraft] = useState("");
  const [resources, setResources] = useState<Resource[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [copied, setCopied] = useState(false);

  const set = <K extends keyof ComplaintInput>(key: K, value: ComplaintInput[K]) =>
    setInput((prev) => ({ ...prev, [key]: value }));
  const setPerson = (key: keyof ComplaintInput["complainant"], value: string) =>
    setInput((prev) => ({ ...prev, complainant: { ...prev.complainant, [key]: value } }));

  async function make() {
    setError(null);
    try {
      const res = await draftComplaint(result, input);
      setDraft(res.text_ne);
      setResources(res.resources);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    }
  }

  function download() {
    const url = URL.createObjectURL(new Blob([draft], { type: "text/plain;charset=utf-8" }));
    const a = document.createElement("a");
    a.href = url;
    a.download = "sajag-complaint-draft.txt";
    a.click();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  }

  const field = (label: string, value: string, onChange: (v: string) => void, type = "text") => (
    <label className="stack-xs">
      <span className="label">{label}</span>
      <input type={type} value={value} onChange={(e) => onChange(e.target.value)} />
    </label>
  );

  return (
    <section className="stack">
      <button className="ghost back" onClick={onBack}>← {t("back", lang)}</button>
      <h1>{t("complaintTitle", lang)}</h1>
      <p className="notice">{t("complaintHelp", lang)}</p>

      <fieldset className="card">
        <legend>{t("recipient", lang)}</legend>
        <div className="segmented wrap">
          {RECIPIENTS.map((r) => (
            <button key={r.id} aria-pressed={input.recipient === r.id} onClick={() => set("recipient", r.id)}>
              {r[lang]}
            </button>
          ))}
        </div>
      </fieldset>

      <div className="card grid-2">
        {input.recipient === "bank" && field(t("bankName", lang), input.bank_name, (v) => set("bank_name", v))}
        {field(t("name", lang), input.complainant.name, (v) => setPerson("name", v))}
        {field(t("address", lang), input.complainant.address, (v) => setPerson("address", v))}
        {field(t("phone", lang), input.complainant.phone, (v) => setPerson("phone", v), "tel")}
        {field(t("amountPaid", lang), input.amount_paid, (v) => set("amount_paid", v), "number")}
        {field(t("paidOn", lang), input.paid_on, (v) => set("paid_on", v))}
        {field(t("txnRef", lang), input.transaction_ref, (v) => set("transaction_ref", v))}
        <label className="stack-xs span-2">
          <span className="label">{t("story", lang)}</span>
          <textarea rows={4} value={input.user_story_ne} onChange={(e) => set("user_story_ne", e.target.value)} />
        </label>
      </div>

      {error && <p className="error" role="alert">{error}</p>}
      <button className="primary" onClick={make}>{t("makeDraft", lang)}</button>

      {draft && (
        <div className="card stack-sm">
          <textarea className="draft" rows={22} value={draft} onChange={(e) => setDraft(e.target.value)} />
          <div className="actions">
            <button
              className="secondary"
              onClick={() => navigator.clipboard.writeText(draft).then(() => setCopied(true))}
            >
              {copied ? t("copied", lang) : t("copy", lang)}
            </button>
            <button className="secondary" onClick={download}>{t("download", lang)}</button>
          </div>
          {resources.length > 0 && (
            <>
              <h2>{t("officialLinks", lang)}</h2>
              <ul className="steps">
                {resources.map((r) => (
                  <li key={r.id}>
                    {r.url ? <a href={r.url} target="_blank" rel="noopener noreferrer">{lang === "ne" ? r.name_ne : r.name_en} ↗</a> : <strong>{lang === "ne" ? r.name_ne : r.name_en}</strong>}
                    <div className="muted small">
                      {lang === "ne" ? r.note_ne : r.note_en} · {r.last_checked ? `${t("checkedOn", lang)} ${r.last_checked}` : t("notVerifiedLink", lang)}
                    </div>
                  </li>
                ))}
              </ul>
            </>
          )}
        </div>
      )}
    </section>
  );
}
