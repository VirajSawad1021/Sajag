"""Deterministic payment-QR reading. No AI here: what this returns is exactly what the QR encodes.

Nepali interoperable QRs (Fonepay / NepalPay) are expected to follow EMVCo merchant-presented
TLV format, where tag 59 is the payee (merchant) name. Wallet "personal" QRs may use other
formats (e.g. JSON) — test real eSewa / Khalti / Fonepay / bank QRs and extend parse_payment_qr.

Debug a real QR locally (prints the raw payload, never upload it anywhere):
    python -m app.qr path/to/screenshot.png
"""

from __future__ import annotations

import json
import re
import sys

import cv2
import numpy as np

from .schemas import QrInfo

EMV_NAMES = {
    "52": "merchant_category_code",
    "53": "currency",
    "54": "amount",
    "58": "country",
    "59": "payee_name",
    "60": "city",
}


def decode_qr_payloads(image_bytes: bytes) -> list[str]:
    """Return every QR payload OpenCV can find in an image (screenshots included)."""
    arr = np.frombuffer(image_bytes, np.uint8)
    img = cv2.imdecode(arr, cv2.IMREAD_COLOR)
    if img is None:
        return []
    detector = cv2.QRCodeDetector()
    found: list[str] = []
    candidates = [img]
    h, w = img.shape[:2]
    if max(h, w) < 1200:  # small QRs inside screenshots decode better when upscaled
        candidates.append(cv2.resize(img, (w * 2, h * 2), interpolation=cv2.INTER_CUBIC))
    for candidate in candidates:
        try:
            ok, decoded, _, _ = detector.detectAndDecodeMulti(candidate)
            if ok:
                found.extend(d for d in decoded if d)
            if not found:
                single, _, _ = detector.detectAndDecode(candidate)
                if single:
                    found.append(single)
        except cv2.error:
            continue
        if found:
            break
    return list(dict.fromkeys(found))


def parse_tlv(payload: str) -> list[tuple[str, str]]:
    """Parse EMVCo ID(2) LEN(2) VALUE(LEN) records. Raises ValueError if malformed."""
    items: list[tuple[str, str]] = []
    i = 0
    while i < len(payload):
        if i + 4 > len(payload):
            raise ValueError("truncated TLV header")
        tag, length = payload[i : i + 2], payload[i + 2 : i + 4]
        if not (tag.isdigit() and length.isdigit()):
            raise ValueError(f"bad TLV header at {i}")
        n = int(length)
        value = payload[i + 4 : i + 4 + n]
        if len(value) != n:
            raise ValueError("truncated TLV value")
        items.append((tag, value))
        i += 4 + n
    return items


def crc16_ccitt(data: str) -> str:
    """CRC-16/CCITT-FALSE as used by EMVCo QR (tag 63)."""
    crc = 0xFFFF
    for byte in data.encode("utf-8"):
        crc ^= byte << 8
        for _ in range(8):
            crc = ((crc << 1) ^ 0x1021) if crc & 0x8000 else (crc << 1)
            crc &= 0xFFFF
    return f"{crc:04X}"


def mask(value: str) -> str:
    """Hide the middle of account-like numbers so they are not echoed in full."""
    if len(re.sub(r"\D", "", value)) < 6:
        return value
    return value[:2] + "•" * (len(value) - 5) + value[-3:]


def parse_payment_qr(raw: str, source_id: str) -> QrInfo:
    if raw.startswith("000201"):
        return _parse_emvco(raw, source_id)
    try:
        data = json.loads(raw)
    except ValueError:
        data = None
    if isinstance(data, dict):
        return _parse_json(data, source_id)
    return QrInfo(source_id=source_id, format="unknown", notes=["QR is not a recognised payment format."])


def _parse_emvco(raw: str, source_id: str) -> QrInfo:
    info = QrInfo(source_id=source_id, format="emvco")
    try:
        records = parse_tlv(raw)
    except ValueError as exc:
        info.notes.append(f"Could not fully parse QR: {exc}")
        return info
    for tag, value in records:
        field = EMV_NAMES.get(tag)
        if field:
            setattr(info, field, value)
        elif 26 <= int(tag) <= 51:  # merchant account information templates
            try:
                nested = parse_tlv(value)
                info.account_hints.extend(mask(v) for t, v in nested if t != "00")
                info.network_ids.extend(v for t, v in nested if t == "00")
            except ValueError:
                info.account_hints.append(mask(value))
    if "6304" in raw[-8:]:
        body, given = raw[:-4], raw[-4:]
        info.crc_valid = crc16_ccitt(body) == given.upper()
        if not info.crc_valid:
            info.notes.append("QR checksum does not match — the QR may be damaged or edited.")
    if info.currency == "524":
        info.currency = "NPR"
    return info


def _parse_json(data: dict, source_id: str) -> QrInfo:
    info = QrInfo(source_id=source_id, format="json")
    for key, value in data.items():
        k = key.lower()
        if not isinstance(value, (str, int)):
            continue
        if "name" in k and not info.payee_name:
            info.payee_name = str(value)
        elif any(word in k for word in ("id", "number", "mobile", "account")):
            info.account_hints.append(mask(str(value)))
    return info


if __name__ == "__main__":
    for path in sys.argv[1:]:
        with open(path, "rb") as fh:
            for payload in decode_qr_payloads(fh.read()):
                print(path, "->", payload)
                print("   parsed:", parse_payment_qr(payload, "debug").model_dump(exclude_none=True))
