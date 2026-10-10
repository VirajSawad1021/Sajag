// Builds a self-contained HTML evidence report in the browser. Nothing is uploaded.
import type { Analysis } from "./types";

const esc = (s: string) =>
  s.replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]!);

async function sha256(file: File): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", await file.arrayBuffer());
  return Array.from(new Uint8Array(digest), (b) => b.toString(16).padStart(2, "0")).join("");
}

async function dataUrl(file: File): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(reader.result as string);
    reader.onerror = reject;
    reader.readAsDataURL(file);
  });
}

export async function downloadReport(a: Analysis, files: File[], audios: File[]): Promise<void> {
  const created = new Date().toISOString();
  const sources = await Promise.all(
    a.sources.map(async (s) => {
      const index = Number(s.id.split("_")[1]) - 1;
      const file = s.kind === "image" ? files[index] : s.kind === "audio" ? audios[index] : undefined;
      const hash = file && crypto.subtle ? await sha256(file) : null;
      const img = file && s.kind === "image" ? `<img src="${await dataUrl(file)}" alt="${esc(s.filename ?? s.id)}">` : "";
      return `<section><h3>${esc(s.id)} — ${esc(s.filename ?? "pasted text")}</h3>
        ${hash ? `<p class="meta">SHA-256: ${hash}</p>` : ""}
        ${img}
        ${s.transcript ? `<p class="meta">Text (${s.transcript_by === "model" ? "read by AI, may contain errors" : s.transcript_by === "asr" ? "voice note transcribed by speech-to-text, may contain errors" : "as provided by user"}):</p><pre>${esc(s.transcript)}</pre>` : ""}
      </section>`;
    }),
  );

  const signals = a.signals
    .map(
      (s) => `<li><strong>${esc(s.title_en)}</strong> (${s.severity}${s.grounded ? "" : ", UNVERIFIED quote"})<br>
      “${esc(s.quote)}” — ${esc(s.source_id)}<br>${esc(s.explanation_en)}</li>`,
    )
    .join("");
  const events = a.events
    .map((e) => `<li>${esc(e.when ?? "date unknown")} [${e.when_source}] — ${esc(e.summary_en)} (${esc(e.source_id)})</li>`)
    .join("");
  const qr = a.qr
    .map((q) => `<li>${esc(q.source_id)}: payee ${esc(q.payee_name ?? "unknown")}${q.amount ? `, amount ${esc(q.amount)}` : ""}${q.crc_valid === false ? " — CHECKSUM MISMATCH" : ""}</li>`)
    .join("");

  const html = `<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1"><title>Sajag case report</title>
<style>body{font-family:system-ui,sans-serif;max-width:800px;margin:2rem auto;padding:0 1rem;line-height:1.5;color:#1c1c1a}
img{max-width:100%;border:1px solid #ccc}pre{white-space:pre-wrap;background:#f4f4f2;padding:.75rem}
.meta{color:#666;font-size:.85rem;word-break:break-all}.note{background:#fff8e6;padding:.75rem;border-left:4px solid #d4a017}</style>
</head><body>
<h1>Sajag case report</h1>
<p class="meta">Created ${esc(created)} · stage: ${esc(a.stage)} · engine: ${esc(a.engine)} · overall: ${esc(a.overall.level)}</p>
<p class="note">This report lists possible warning signs found by software. It is not proof of fraud and is not an official document.
Original files are attached below with SHA-256 checksums; a checksum shows a file was not changed after this report was made, not that its content is true.</p>
<h2>Summary</h2><p>${esc(a.overall.summary_en)}</p><p>${esc(a.overall.summary_ne)}</p>
${qr ? `<h2>Payment QR codes</h2><ul>${qr}</ul>` : ""}
<h2>Warning signs</h2>${signals ? `<ul>${signals}</ul>` : "<p>None found.</p>"}
<h2>Timeline</h2>${events ? `<ol>${events}</ol>` : "<p>No events extracted.</p>"}
<h2>Evidence</h2>${sources.join("")}
</body></html>`;

  const url = URL.createObjectURL(new Blob([html], { type: "text/html" }));
  const link = document.createElement("a");
  link.href = url;
  link.download = `sajag-report-${created.slice(0, 10)}.html`;
  link.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}
