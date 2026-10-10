"""API and model-output schemas. Everything the model returns is validated through these."""

from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field

Stage = Literal["before_payment", "after_payment"]
RiskLevel = Literal["high", "caution", "low", "insufficient"]


class QrInfo(BaseModel):
    source_id: str
    format: Literal["emvco", "json", "unknown"]
    payee_name: str | None = None
    city: str | None = None
    amount: str | None = None
    currency: str | None = None
    country: str | None = None
    merchant_category_code: str | None = None
    network_ids: list[str] = Field(default_factory=list)
    account_hints: list[str] = Field(default_factory=list)  # masked
    crc_valid: bool | None = None
    notes: list[str] = Field(default_factory=list)


# ---------- raw model output (lenient: the model may omit fields) ----------


class ModelFact(BaseModel):
    field: str = "other"
    value: str = ""
    source_id: str = ""
    quote: str = ""


class ModelEvent(BaseModel):
    when: str | None = None
    when_source: Literal["shown", "user", "unknown"] = "unknown"
    type: str = "other"
    summary_en: str = ""
    summary_ne: str = ""
    source_id: str = ""
    quote: str = ""


class ModelSignal(BaseModel):
    pattern_id: str
    source_id: str = ""
    quote: str = ""
    explanation_en: str = ""
    explanation_ne: str = ""
    unknowns_en: list[str] = Field(default_factory=list)


class ModelOutput(BaseModel):
    transcripts: dict[str, str] = Field(default_factory=dict)
    enough_information: bool = True
    summary_en: str = ""
    summary_ne: str = ""
    claimed_seller_names: list[str] = Field(default_factory=list)
    facts: list[ModelFact] = Field(default_factory=list)
    events: list[ModelEvent] = Field(default_factory=list)
    signals: list[ModelSignal] = Field(default_factory=list)
    deadlines: list[ModelDeadline] = Field(default_factory=list)


# ---------- API response ----------


class Region(BaseModel):
    """A located area of a screenshot: box is [ymin, xmin, ymax, xmax] normalised to 0-1000."""

    kind: Literal["message", "qr", "other"] = "other"
    text: str = ""
    box: list[int]


class ModelDeadline(BaseModel):
    what_en: str = ""
    what_ne: str = ""
    due: str | None = None  # ISO date (YYYY-MM-DD) if the evidence states one
    source_id: str = ""
    quote: str = ""


class Span(BaseModel):
    start: int
    end: int


class Source(BaseModel):
    id: str
    kind: Literal["text", "image", "audio"]
    filename: str | None = None
    transcript: str = ""
    transcript_by: Literal["user", "model", "asr", "none"] = "none"
    duration_s: float | None = None
    regions: list[Region] = Field(default_factory=list)


class Fact(ModelFact):
    span: Span | None = None


class Event(ModelEvent):
    span: Span | None = None


class Signal(BaseModel):
    pattern_id: str
    title_en: str
    title_ne: str
    severity: Literal["high", "medium", "low"]
    source_id: str
    quote: str
    span: Span | None = None
    grounded: bool  # True only if the quote was found verbatim in the source (or is a QR fact)
    origin: Literal["model", "rule", "qr"]
    explanation_en: str = ""
    explanation_ne: str = ""
    unknowns_en: list[str] = Field(default_factory=list)
    not_always_scam_en: str = ""
    region: int | None = None  # index into the source's regions (Scam X-Ray box), if matched


class Deadline(ModelDeadline):
    grounded: bool = False


class NextStep(BaseModel):
    text_en: str
    text_ne: str
    resource_id: str | None = None


class Overall(BaseModel):
    level: RiskLevel
    summary_en: str = ""
    summary_ne: str = ""


class AnalysisResponse(BaseModel):
    overall: Overall
    stage: Stage
    sources: list[Source]
    qr: list[QrInfo]
    facts: list[Fact]
    events: list[Event]
    signals: list[Signal]
    next_steps: list[NextStep]
    deadlines: list[Deadline] = Field(default_factory=list)
    seller_names: list[str] = Field(default_factory=list)  # names the seller uses (not receivers/payees)
    warnings: list[str] = Field(default_factory=list)
    engine: Literal["gemma", "offline-rules"]


# ---------- complaint ----------


class Complainant(BaseModel):
    name: str = ""
    address: str = ""
    phone: str = ""


class ComplaintRequest(BaseModel):
    analysis: AnalysisResponse
    recipient: Literal["cyber_bureau", "bank", "nrb", "consumer"] = "cyber_bureau"
    bank_name: str = ""
    complainant: Complainant = Field(default_factory=Complainant)
    user_story_ne: str = ""
    amount_paid: str = ""
    paid_on: str = ""
    transaction_ref: str = ""


class ComplaintResponse(BaseModel):
    text_ne: str
    resources: list[dict]
