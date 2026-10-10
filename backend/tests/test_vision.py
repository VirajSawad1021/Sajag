from app.schemas import Region, Signal, Source
from app.vision import attach_regions, match_region

REGIONS = [
    Region(kind="message", text="Namaste! iPhone 15 128GB new box pack, Rs 1,15,000. COD milcha", box=[100, 20, 200, 800]),
    Region(kind="message", text="Sorry dai, COD band bhayo. Advance 50% pathaunus ani matra dispatch huncha.", box=[300, 20, 400, 800]),
    Region(kind="qr", text="", box=[600, 30, 950, 570]),
]


def _sig(pattern_id, quote, origin="model", grounded=True):
    return Signal(pattern_id=pattern_id, title_en="t", title_ne="t", severity="medium", source_id="img_1",
                  quote=quote, grounded=grounded, origin=origin)


def test_quote_matches_its_bubble():
    assert match_region("Advance 50% pathaunus", REGIONS) == 1
    assert match_region("COD milcha", REGIONS) == 0


def test_unrelated_quote_matches_nothing():
    assert match_region("send me your OTP now", REGIONS) is None


def test_attach_only_grounded_and_qr_goes_to_qr_box():
    src = Source(id="img_1", kind="image", regions=REGIONS)
    model_sig = _sig("advance_payment", "Advance 50% pathaunus")
    qr_sig = _sig("qr_payee_mismatch", "SITA SHARMA", origin="qr")
    ungrounded = _sig("urgency_pressure", "Advance 50% pathaunus", grounded=False)
    attach_regions([src], [model_sig, qr_sig, ungrounded])
    assert model_sig.region == 1
    assert qr_sig.region == 2
    assert ungrounded.region is None  # unverified warnings never light up
