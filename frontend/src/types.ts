// Mirrors backend/app/schemas.py
export type Stage = "before_payment" | "after_payment";
export type RiskLevel = "high" | "caution" | "low" | "insufficient";
export type Lang = "ne" | "en";

export interface Span { start: number; end: number }

export interface Source {
  id: string;
  kind: "text" | "image" | "audio";
  filename: string | null;
  transcript: string;
  transcript_by: "user" | "model" | "asr" | "none";
  duration_s: number | null;
}

export interface QrInfo {
  source_id: string;
  format: "emvco" | "json" | "unknown";
  payee_name: string | null;
  city: string | null;
  amount: string | null;
  currency: string | null;
  network_ids: string[];
  account_hints: string[];
  crc_valid: boolean | null;
  notes: string[];
}

export interface Fact { field: string; value: string; source_id: string; quote: string; span: Span | null }

export interface TimelineEvent {
  when: string | null;
  when_source: "shown" | "user" | "unknown";
  type: string;
  summary_en: string;
  summary_ne: string;
  source_id: string;
  quote: string;
  span: Span | null;
}

export interface Signal {
  pattern_id: string;
  title_en: string;
  title_ne: string;
  severity: "high" | "medium" | "low";
  source_id: string;
  quote: string;
  span: Span | null;
  grounded: boolean;
  origin: "model" | "rule" | "qr";
  explanation_en: string;
  explanation_ne: string;
  unknowns_en: string[];
  not_always_scam_en: string;
}

export interface NextStep { text_en: string; text_ne: string; resource_id: string | null }

export interface Analysis {
  overall: { level: RiskLevel; summary_en: string; summary_ne: string };
  stage: Stage;
  sources: Source[];
  qr: QrInfo[];
  facts: Fact[];
  events: TimelineEvent[];
  signals: Signal[];
  next_steps: NextStep[];
  warnings: string[];
  engine: "gemma" | "offline-rules";
}

export interface Resource {
  id: string;
  name_en: string;
  name_ne: string;
  url: string | null;
  note_en: string;
  note_ne: string;
  last_checked: string | null;
}
