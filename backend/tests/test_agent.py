from app.agent import _mentions_private, _parse_output


def test_private_searches_blocked():
    assert _mentions_private("SITA SHARMA esewa scam", ["SITA SHARMA"])
    assert _mentions_private("9812345678 fraud", [])
    assert not _mentions_private("KTM Mobile Hub reviews Nepal", ["SITA SHARMA"])


def test_scripts_without_nepali_fall_back_or_drop():
    out = _parse_output(
        '{"scripts": [{"purpose_en": "a", "message_ne": "भिडियो पठाउनुस्"},'
        ' {"purpose_en": "b", "message_ne": "लाइभ भिडियो", "message_en": "Live video"}, {"purpose_en": "c"}]}'
    )
    assert out is not None
    assert [s.message_ne for s in out.scripts] == ["भिडियो पठाउनुस्", "लाइभ भिडियो"]


def test_english_in_the_nepali_field_triggers_a_retry():
    assert _parse_output('{"scripts": [{"message_ne": "I will call you first"}]}') is None


def test_no_usable_scripts_is_none():
    assert _parse_output('{"scripts": []}') is None
    assert _parse_output("not json") is None


def test_rate_limit_wait_uses_google_hint():
    from app.gemma import rate_limit_wait

    assert rate_limit_wait("500 INTERNAL") == 0.0
    assert rate_limit_wait("429 RESOURCE_EXHAUSTED ... 'retryDelay': '22s'") == 23.0
    assert rate_limit_wait("429 RESOURCE_EXHAUSTED") == 15.0
    assert rate_limit_wait("429 'retryDelay': '90s'") == 30.0
