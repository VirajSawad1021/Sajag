"""Show the *structure* of real payment QRs without revealing account details.

    python scripts/inspect_qr.py                 # every image in "test data/private/"
    python scripts/inspect_qr.py path/to/qr.png

Prints the QR format, which EMVCo tags are present, and masked values, so the team can check whether real
eSewa / Khalti / Fonepay / bank QRs contain a payee name and a stable account ID — without sharing them.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "backend"))

from app.qr import EMV_NAMES, crc16_ccitt, decode_qr_payloads, parse_tlv  # noqa: E402

TAG_NAMES = {
    "00": "payload format", "01": "static(11)/dynamic(12)", "52": "merchant category", "53": "currency",
    "54": "amount", "58": "country", "59": "payee name", "60": "city", "61": "postal code", "62": "additional data",
    "63": "CRC", "64": "language template",
}


def mask(value: str, keep: int = 2) -> str:
    """Keep the shape (length, digits vs letters) but hide the content."""
    if len(value) <= keep * 2:
        return "•" * len(value)
    shaped = re.sub(r"[A-Za-z]", "a", re.sub(r"\d", "9", value[keep:-keep]))
    return value[:keep] + shaped + value[-keep:]


def mask_name(name: str) -> str:
    return " ".join(w[0] + "•" * (len(w) - 1) for w in name.split())


def describe_emv(payload: str) -> None:
    body_ok = payload[-8:-4] == "6304" and crc16_ccitt(payload[:-4]) == payload[-4:].upper()
    print(f"  EMVCo QR, CRC {'valid' if body_ok else 'INVALID/absent'}")
    for tag, value in parse_tlv(payload):
        label = TAG_NAMES.get(tag) or ("merchant account" if 26 <= int(tag) <= 51 else EMV_NAMES.get(tag, "other"))
        if tag == "59":
            shown = mask_name(value)
        elif tag in ("00", "01", "52", "53", "58", "63"):
            shown = value
        elif 26 <= int(tag) <= 51 or tag == "62":
            try:
                inner = parse_tlv(value)
                shown = "; ".join(f"{t}={v if t == '00' and not v.isdigit() else mask(v)}" for t, v in inner)
            except ValueError:
                shown = mask(value)
        else:
            shown = mask(value)
        print(f"   [{tag}] {label:<24} {shown}")


def describe(payload: str) -> None:
    if payload.startswith("000201"):
        try:
            describe_emv(payload)
            return
        except ValueError as exc:
            print(f"  looked like EMVCo but did not parse: {exc}")
    try:
        data = json.loads(payload)
        print("  JSON QR with keys:", {k: (mask_name(str(v)) if "name" in k.lower() else mask(str(v))) for k, v in data.items()})
        return
    except ValueError:
        pass
    print(f"  Other format: {len(payload)} chars, starts {payload[:6]!r}, shape {mask(payload, 3)[:60]}")


def main() -> int:
    paths = [Path(p) for p in sys.argv[1:]] or sorted(
        p for p in (ROOT / "test data" / "private").glob("*") if p.suffix.lower() in (".png", ".jpg", ".jpeg", ".webp")
    )
    if not paths:
        print('No images. Put QR screenshots in "test data/private/".')
        return 1
    for path in paths:
        payloads = decode_qr_payloads(path.read_bytes())
        print(f"\n{path.name}: {len(payloads)} QR found")
        for payload in payloads:
            describe(payload)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
