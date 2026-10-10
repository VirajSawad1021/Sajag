"""Check that model quotes really exist in the source text. A signal without a verified quote is
never shown as evidence — this is the line between "explained warning" and "hallucinated accusation"."""

from __future__ import annotations

import re
import unicodedata

from .schemas import Span

_EDGE_CHARS = " \t\n\"'“”‘’`.,!?…।:;-–—()[]"


def normalize(text: str) -> str:
    return unicodedata.normalize("NFC", text)


def find_span(quote: str, transcript: str) -> Span | None:
    """Find `quote` in `transcript`, ignoring case, whitespace differences and edge punctuation.

    A quote joining several excerpts with "..." or line breaks (e.g. two chat messages, without the
    "Buyer:" label between them) is grounded only if every excerpt is found; the span returned is the
    first excerpt's."""
    parts = [p for p in re.split(r"\.{3}|…|\n", quote) if p.strip(_EDGE_CHARS)]
    if len(parts) > 1:
        spans = [_find_one(p, transcript) for p in parts]
        return spans[0] if all(spans) else None
    return _find_one(quote, transcript)


def _find_one(quote: str, transcript: str) -> Span | None:
    words = normalize(quote).strip(_EDGE_CHARS).split()
    if not words:
        return None
    pattern = r"\s+".join(re.escape(w) for w in words)
    match = re.search(pattern, transcript, re.IGNORECASE)
    return Span(start=match.start(), end=match.end()) if match else None
