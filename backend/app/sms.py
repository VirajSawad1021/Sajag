"""Bank / wallet SMS reader. Deterministic: pulls the amount, debit/credit, transaction ID and date out of
forwarded payment messages, so those facts in the timeline and the Cyber Bureau application come from the
user's own SMS, not from the model. Formats differ between banks, so this is tolerant; Gemma still reads the
text too and covers anything this misses."""

from __future__ import annotations

import re
from datetime import date

from pydantic import BaseModel

AMOUNT = re.compile(r"(?:Rs\.?|NPR|रु\.?|रू\.?)\s*([0-9][0-9,]*(?:\.\d{1,2})?)", re.IGNORECASE)
DEBIT = re.compile(r"\b(debited|debit|sent|paid|transferred|deducted|withdrawn|withdrawal|purchase)\b|डेबिट|पठाइयो|भुक्तानी", re.IGNORECASE)
CREDIT = re.compile(r"\b(credited|credit|received|deposited|refund(?:ed)?)\b|क्रेडिट|प्राप्त", re.IGNORECASE)
TXN = re.compile(
    r"(?:Txn\.?\s*(?:ID|No\.?)?|Transaction\s*(?:ID|No\.?|Ref\.?)|Ref(?:erence)?\.?\s*(?:ID|No\.?)?|TID|Trace\s*No\.?)"
    r"\s*[:#.\-]?\s*([A-Z0-9][A-Z0-9\-]{4,})",
    re.IGNORECASE,
)
DATE_PATTERNS = [
    (re.compile(r"\b(\d{4})-(\d{2})-(\d{2})\b"), ("y", "m", "d")),
    (re.compile(r"\b(\d{1,2})[-/.](\d{1,2})[-/.](\d{4})\b"), ("d", "m", "y")),
    (re.compile(r"\b(\d{1,2})[-/.](\d{1,2})[-/.](\d{2})\b"), ("d", "m", "yy")),
]


class SmsPayment(BaseModel):
    source_id: str
    amount: str
    direction: str  # "debit" | "credit" | "unknown"
    transaction_id: str | None = None
    date: str | None = None  # ISO, only if it parses as a real date (AD)
    quote: str  # the exact message text this came from


def _iso(text: str) -> str | None:
    for pattern, order in DATE_PATTERNS:
        m = pattern.search(text)
        if not m:
            continue
        parts = dict(zip(order, m.groups()))
        year = int(parts.get("y") or 2000 + int(parts["yy"]))
        if year > 2070:  # a Bikram Sambat year (e.g. 2083) — don't misread it as AD
            return None
        try:
            return date(year, int(parts["m"]), int(parts["d"])).isoformat()
        except ValueError:
            continue
    return None


def parse_payments(text: str, source_id: str) -> list[SmsPayment]:
    """One payment per message. Messages are split on blank lines (forwarded SMS usually arrive that way)."""
    out: list[SmsPayment] = []
    for message in [m.strip() for m in re.split(r"\n\s*\n", text) if m.strip()]:
        amount = AMOUNT.search(message)
        is_debit, is_credit = DEBIT.search(message), CREDIT.search(message)
        if not amount or not (is_debit or is_credit):
            continue
        txn = TXN.search(message)
        out.append(
            SmsPayment(
                source_id=source_id,
                amount=amount.group(1).replace(",", ""),
                direction="debit" if is_debit and not is_credit else "credit" if is_credit and not is_debit else "unknown",
                transaction_id=txn.group(1) if txn else None,
                date=_iso(message),
                quote=message[:400],
            )
        )
    return out
