"""Builds an editable Nepali complaint (निवेदन) from the reviewed case.

Deliberately a template, not free model text: every line comes from the user's own words or from
evidence-linked facts, so nothing is invented. The user edits it before using it anywhere."""

from __future__ import annotations

from datetime import date

from . import catalog
from .schemas import ComplaintRequest

_DEVANAGARI_DIGITS = str.maketrans("0123456789", "०१२३४५६७८९")

RECIPIENTS = {
    "cyber_bureau": ("श्रीमान् प्रमुखज्यू", "नेपाल प्रहरी साइबर ब्युरो"),
    "bank": ("श्रीमान् गुनासो सुनुवाइ अधिकारीज्यू", "{bank}"),
    "nrb": ("श्रीमान्", "नेपाल राष्ट्र बैंक"),
    "consumer": ("श्रीमान्", "वाणिज्य, आपूर्ति तथा उपभोक्ता संरक्षण विभाग"),
}

SUBJECTS = {
    "cyber_bureau": "अनलाइन खरिदमा भएको सम्भावित ठगीसम्बन्धी उजुरी।",
    "bank": "विद्युतीय भुक्तानीमा भएको सम्भावित ठगीसम्बन्धी गुनासो।",
    "nrb": "विद्युतीय भुक्तानीमा भएको सम्भावित ठगीसम्बन्धी गुनासो।",
    "consumer": "अनलाइन खरिद गरिएको सामान/सेवासम्बन्धी उजुरी।",
}


def ne_digits(text: str) -> str:
    return text.translate(_DEVANAGARI_DIGITS)


def _blank(value: str, placeholder: str = "................") -> str:
    return value.strip() or placeholder


def build_complaint(req: ComplaintRequest) -> str:
    a, c = req.analysis, req.complainant
    salutation, office = RECIPIENTS[req.recipient]
    office = office.format(bank=_blank(req.bank_name, "................ बैंक / वालेट"))

    timeline = []
    for i, ev in enumerate(a.events, start=1):
        when = f"{ev.when}: " if ev.when else ""
        summary = ev.summary_ne or ev.summary_en
        timeline.append(f"{ne_digits(str(i))}. {when}{summary}")
    if not timeline:
        timeline.append("(घटनाक्रम यहाँ लेख्नुहोस्)")

    evidence = []
    for s in a.sources:
        label = s.filename or ("च्याट/म्यासेजको पाठ" if s.kind == "text" else s.id)
        evidence.append(f"- {label}")

    payment = []
    if req.amount_paid:
        payment.append(f"भुक्तानी गरिएको रकम: रु. {ne_digits(req.amount_paid)}")
    if req.paid_on:
        payment.append(f"भुक्तानी मिति: {ne_digits(req.paid_on)}")
    if req.transaction_ref:
        payment.append(f"कारोबार नम्बर (Transaction ID): {req.transaction_ref}")
    for q in a.qr:
        if q.payee_name:
            payment.append(f"भुक्तानी QR मा उल्लेखित प्राप्तकर्ता: {q.payee_name}")

    parts = [
        f"मिति: {ne_digits(date.today().isoformat())}",
        "",
        f"{salutation},",
        office,
        "",
        f"विषय: {SUBJECTS[req.recipient]}",
        "",
        "महोदय,",
        f"म {_blank(c.name)}, {_blank(c.address)} निवासी, तल उल्लेख गरिएको घटनाबारे यो निवेदन पेस गर्दछु।",
        "",
        "घटनाको विवरण:",
        _blank(req.user_story_ne, "(आफ्नो शब्दमा के भयो लेख्नुहोस्)"),
        "",
    ]
    if payment:
        parts += ["भुक्तानी विवरण:", *payment, ""]
    parts += [
        "घटनाक्रम:",
        *timeline,
        "",
        "संलग्न प्रमाणहरू:",
        *evidence,
        "",
        "माथि उल्लेखित विवरण मैले जाने-बुझेसम्म सत्य हो। यस विषयमा आवश्यक छानबिन गरी उचित कारबाहीका लागि अनुरोध गर्दछु।",
        "",
        "निवेदक,",
        f"नाम: {_blank(c.name)}",
        f"ठेगाना: {_blank(c.address)}",
        f"सम्पर्क नम्बर: {_blank(ne_digits(c.phone))}",
        "हस्ताक्षर: ................",
    ]
    return "\n".join(parts)


def complaint_resources(recipient: str) -> list[dict]:
    wanted = {
        "cyber_bureau": ["cyber_bureau"],
        "bank": ["bank_or_wallet", "nrb_gunaso"],
        "nrb": ["nrb_gunaso"],
        "consumer": ["consumer_complaint"],
    }[recipient]
    return [r for r in catalog.resources() if r["id"] in wanted]
