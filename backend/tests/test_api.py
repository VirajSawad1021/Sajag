from fastapi.testclient import TestClient

from app import catalog
from app.main import app

client = TestClient(app)


def test_patterns_load_and_are_valid():
    pats = catalog.patterns()
    assert "qr_payee_mismatch" in pats and len(pats) >= 8


def test_analyze_flags_and_grounds_offline():
    text = "Seller: COD mildaina dai\nSeller: Advance 50% pathaunus, stock sakincha\nSeller: OTP pathaunus"
    res = client.post("/api/analyze", data={"text": text, "stage": "before_payment"})
    assert res.status_code == 200
    body = res.json()
    flagged = {s["pattern_id"] for s in body["signals"]}
    assert {"no_cod_or_verification", "advance_payment", "otp_credential_request"} <= flagged
    assert all(s["grounded"] for s in body["signals"])
    assert body["overall"]["level"] == "high"
    assert body["engine"] == "offline-rules"


def test_honest_seller_not_flagged():
    text = "Seller: COD available cha. Ghar ma aayera check garera matra paisa dinus."
    body = client.post("/api/analyze", data={"text": text}).json()
    assert body["signals"] == []
    assert body["overall"]["level"] == "low"


def test_empty_request_rejected():
    assert client.post("/api/analyze", data={"text": "  "}).status_code == 400


def test_complaint_is_nepali_and_uses_inputs():
    analysis = client.post(
        "/api/analyze", data={"text": "Advance pathaunus", "stage": "after_payment"}
    ).json()
    res = client.post(
        "/api/complaint",
        json={
            "analysis": analysis,
            "recipient": "cyber_bureau",
            "complainant": {"name": "Test User", "address": "Kathmandu", "phone": "9800000000"},
            "user_story_ne": "मैले जुत्ता मगाएको थिएँ।",
            "amount_paid": "3200",
        },
    )
    assert res.status_code == 200
    text = res.json()["text_ne"]
    assert "नेपाल प्रहरी साइबर ब्युरो" in text and "रु. ३२००" in text and "मैले जुत्ता मगाएको थिएँ।" in text


def test_qr_image_upload_reads_payee():
    qrcode = __import__("pytest").importorskip("qrcode")
    import io

    from tests.test_qr import emv_payload

    buf = io.BytesIO()
    qrcode.make(emv_payload(name="SITA SHARMA")).save(buf, format="PNG")
    res = client.post(
        "/api/analyze",
        data={"text": "Seller: Kathmandu iPhone Store ma swagat cha"},
        files=[("images", ("qr.png", buf.getvalue(), "image/png"))],
    )
    assert res.status_code == 200
    body = res.json()
    assert body["qr"][0]["payee_name"] == "SITA SHARMA"
    assert body["qr"][0]["crc_valid"] is True
    assert any(f["field"] == "qr_payee" for f in body["facts"])


def test_tampered_qr_raises_code_signal():
    qrcode = __import__("pytest").importorskip("qrcode")
    import io

    from tests.test_qr import emv_payload

    buf = io.BytesIO()
    qrcode.make(emv_payload(name="HARI PRASAD KC").replace("HARI PRASAD KC", "HARI PRASAD KX")).save(buf, format="PNG")
    body = client.post("/api/analyze", files=[("images", ("qr.png", buf.getvalue(), "image/png"))]).json()
    assert any(s["pattern_id"] == "qr_checksum_invalid" and s["origin"] == "qr" for s in body["signals"])


def test_voice_note_in_offline_mode_warns_instead_of_failing():
    res = client.post(
        "/api/analyze",
        data={"text": "Seller: advance pathaunus"},
        files=[("audios", ("note.ogg", b"not really audio", "audio/ogg"))],
    )
    assert res.status_code == 200
    body = res.json()
    assert any(s["kind"] == "audio" for s in body["sources"])
    assert any("Voice notes need online mode" in w for w in body["warnings"])


def test_non_audio_upload_rejected():
    res = client.post("/api/analyze", files=[("audios", ("x.txt", b"hello", "text/plain"))])
    assert res.status_code == 415


def test_stream_emits_progress_then_result():
    with client.stream("POST", "/api/analyze/stream", data={"text": "Seller: OTP pathaunus"}) as res:
        assert res.status_code == 200
        body = "".join(res.iter_text())
    assert "event: progress" in body and '"step": "received"' in body
    assert "event: result" in body and "otp_credential_request" in body
