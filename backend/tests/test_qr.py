import io

from app.qr import crc16_ccitt, decode_qr_payloads, parse_payment_qr, parse_tlv


def tlv(tag: str, value: str) -> str:
    return f"{tag}{len(value):02d}{value}"


def emv_payload(name: str = "RAM BAHADUR THAPA", account: str = "9800012345") -> str:
    body = (
        tlv("00", "01")
        + tlv("01", "12")
        + tlv("26", tlv("00", "fonepay") + tlv("01", account))
        + tlv("52", "5999")
        + tlv("53", "524")
        + tlv("54", "3200")
        + tlv("58", "NP")
        + tlv("59", name)
        + tlv("60", "KATHMANDU")
        + "6304"
    )
    return body + crc16_ccitt(body)


def test_crc_known_vector():
    assert crc16_ccitt("123456789") == "29B1"  # CRC-16/CCITT-FALSE check value


def test_parse_tlv_roundtrip():
    assert parse_tlv(tlv("59", "ABC") + tlv("60", "KTM")) == [("59", "ABC"), ("60", "KTM")]


def test_emvco_fields_and_masking():
    info = parse_payment_qr(emv_payload(), "img_1")
    assert info.format == "emvco"
    assert info.payee_name == "RAM BAHADUR THAPA"
    assert info.amount == "3200" and info.currency == "NPR" and info.city == "KATHMANDU"
    assert info.crc_valid is True
    assert info.network_ids == ["fonepay"]
    assert "9800012345" not in info.account_hints[0]


def test_tampered_crc_detected():
    payload = emv_payload()
    tampered = payload.replace("RAM BAHADUR THAPA", "RAM BAHADUR THAPX")
    assert parse_payment_qr(tampered, "img_1").crc_valid is False


def test_json_wallet_qr():
    info = parse_payment_qr('{"eSewa_id": "9800012345", "name": "Sita Sharma"}', "img_1")
    assert info.format == "json" and info.payee_name == "Sita Sharma"


def test_decode_from_image():
    qrcode = __import__("pytest").importorskip("qrcode")
    payload = emv_payload()
    buf = io.BytesIO()
    qrcode.make(payload).save(buf, format="PNG")
    assert decode_qr_payloads(buf.getvalue()) == [payload]
