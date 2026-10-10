import { prepareImage } from "./images";
import type { Analysis, Resource, Stage } from "./types";

async function asJson<T>(res: Response): Promise<T> {
  if (!res.ok) {
    let detail = res.statusText;
    try {
      detail = (await res.json()).detail ?? detail;
    } catch {
      /* not JSON */
    }
    throw new Error(typeof detail === "string" ? detail : JSON.stringify(detail));
  }
  return res.json() as Promise<T>;
}

const ANALYZE_TIMEOUT_MS = 120_000;

export async function analyze(text: string, images: File[], audios: File[], stage: Stage): Promise<Analysis> {
  const form = new FormData();
  form.append("text", text);
  form.append("stage", stage);
  const prepared = await Promise.all(images.map(prepareImage));
  prepared.forEach((f) => form.append("images", f, f.name));
  audios.forEach((f) => form.append("audios", f, f.name));
  try {
    return asJson(
      await fetch("/api/analyze", { method: "POST", body: form, signal: AbortSignal.timeout(ANALYZE_TIMEOUT_MS) }),
    );
  } catch (e) {
    if (e instanceof DOMException && e.name === "TimeoutError") {
      throw new Error("The check took longer than 2 minutes. Try fewer screenshots, or paste the text instead.");
    }
    throw e;
  }
}

export interface ComplaintInput {
  recipient: "cyber_bureau" | "bank" | "nrb" | "consumer";
  bank_name: string;
  complainant: { name: string; address: string; phone: string };
  user_story_ne: string;
  amount_paid: string;
  paid_on: string;
  transaction_ref: string;
}

export async function draftComplaint(
  analysis: Analysis,
  input: ComplaintInput,
): Promise<{ text_ne: string; resources: Resource[] }> {
  return asJson(
    await fetch("/api/complaint", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ analysis, ...input }),
    }),
  );
}

export interface AgentResult {
  online_summary_en: string;
  online_summary_ne: string;
  scripts: { purpose_en: string; purpose_ne: string; message_ne: string; message_en: string; verifies_en: string }[];
  what_changes_risk_en: string;
  what_changes_risk_ne: string;
  findings: { query: string; summary: string; sources: { title: string; url: string }[] }[];
  trace: string[];
}

export async function runAgent(analysis: Analysis): Promise<AgentResult> {
  return asJson(
    await fetch("/api/agent", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ analysis }),
      signal: AbortSignal.timeout(120_000),
    }),
  );
}

export async function getResources(): Promise<Resource[]> {
  return asJson(await fetch("/api/resources"));
}
