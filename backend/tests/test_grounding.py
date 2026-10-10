from app.analysis import names_match
from app.grounding import find_span

TRANSCRIPT = "Seller: COD milcha\nSeller: Advance 50%   pathaunus,\nstock sakincha"


def test_exact_quote_found_with_whitespace_and_case_differences():
    span = find_span('"advance 50% pathaunus"', TRANSCRIPT)
    assert span is not None
    assert TRANSCRIPT[span.start : span.end] == "Advance 50%   pathaunus"


def test_quote_across_line_break():
    assert find_span("pathaunus, stock sakincha", TRANSCRIPT) is not None


def test_paraphrase_is_not_grounded():
    assert find_span("please send half the money first", TRANSCRIPT) is None


def test_devanagari_quote():
    assert find_span("पहिले पैसा", "बिक्रेता: पहिले पैसा पठाउनुहोस्") is not None


def test_names_match():
    assert names_match("RAM BAHADUR THAPA", "Ram Thapa Mobiles")
    assert not names_match("SITA SHARMA", "Kathmandu iPhone Store")


def test_multi_part_quote_needs_every_part():
    assert find_span("COD milcha ... advance 50% pathaunus", "Seller: COD milcha\nSeller: Advance 50% pathaunus") is not None
    assert find_span("COD milcha … send OTP", "Seller: COD milcha\nSeller: Advance 50% pathaunus") is None


def test_multi_line_quote_without_speaker_labels():
    transcript = "Buyer: 6 din bhayo, saman aayena.\nBuyer: Hello? Phone pani uthaunu hunna?"
    assert find_span("6 din bhayo, saman aayena.\nHello? Phone pani uthaunu hunna?", transcript) is not None
