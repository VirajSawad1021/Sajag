"""Tests for the offline keyword analyzer (rules.py)."""

import pytest

from app.rules import keyword_analyze
from app.schemas import Source


def test_keyword_analyze_finds_advance_payment():
    sources = [
        Source(id="text_1", kind="text", transcript="Seller: Advance 50% pathaunus ani dispatch huncha"),
    ]
    pattern_catalog = {
        "advance_payment": {
            "id": "advance_payment",
            "severity": "medium",
            "title_en": "Payment requested before delivery",
            "title_ne": "सामान आउनुअघि नै पैसा माग",
            "description": "The seller asks for payment before delivery.",
            "why_en": "Advance payment is risky.",
            "why_ne": "अग्रिम भुक्तानी जोखिमपूर्ण हो।",
            "keywords": ["advance", "agrim", "अग्रिम", "pahile paisa", "पहिले पैसा"],
            "next_steps": [],
        }
    }
    result = keyword_analyze(sources, pattern_catalog)
    assert len(result.signals) == 1
    assert result.signals[0].pattern_id == "advance_payment"
    assert "Advance 50%" in result.signals[0].quote


def test_keyword_analyze_finds_otp_request():
    sources = [
        Source(id="text_1", kind="text", transcript="OTP pathaunus verify garnu parcha"),
    ]
    pattern_catalog = {
        "otp_credential_request": {
            "id": "otp_credential_request",
            "severity": "high",
            "title_en": "Asks for OTP, PIN or password",
            "title_ne": "OTP, PIN वा पासवर्ड माग",
            "description": "Anyone asking for a one-time code.",
            "why_en": "Seller never needs OTP.",
            "why_ne": "बिक्रेतालाई OTP चाहिँदैन।",
            "keywords": ["otp", "mpin", "pin code", "password", "ओटीपी", "पासवर्ड", "code pathaunus"],
            "next_steps": [],
        }
    }
    result = keyword_analyze(sources, pattern_catalog)
    assert len(result.signals) == 1
    assert result.signals[0].pattern_id == "otp_credential_request"


def test_keyword_analyze_ignores_images():
    sources = [
        Source(id="img_1", kind="image", transcript=""),
        Source(id="text_1", kind="text", transcript="Advance 50% pathaunus"),
    ]
    pattern_catalog = {
        "advance_payment": {
            "id": "advance_payment",
            "severity": "medium",
            "title_en": "Payment requested before delivery",
            "title_ne": "सामान आउनुअघि नै पैसा माग",
            "description": "The seller asks for payment before delivery.",
            "why_en": "Advance payment is risky.",
            "why_ne": "अग्रिम भुक्तानी जोखिमपूर्ण हो।",
            "keywords": ["advance", "agrim"],
            "next_steps": [],
        }
    }
    result = keyword_analyze(sources, pattern_catalog)
    assert len(result.signals) == 1
    assert result.signals[0].source_id == "text_1"


def test_keyword_analyze_case_insensitive_for_ascii():
    sources = [
        Source(id="text_1", kind="text", transcript="SELLER: ADVANCE 50% PATHAUNUS"),
    ]
    pattern_catalog = {
        "advance_payment": {
            "id": "advance_payment",
            "severity": "medium",
            "title_en": "Payment requested before delivery",
            "title_ne": "सामान आउनुअघि नै पैसा माग",
            "description": "The seller asks for payment before delivery.",
            "why_en": "Advance payment is risky.",
            "why_ne": "अग्रिम भुक्तानी जोखिमपूर्ण हो।",
            "keywords": ["advance", "agrim"],
            "next_steps": [],
        }
    }
    result = keyword_analyze(sources, pattern_catalog)
    assert len(result.signals) == 1


def test_keyword_analyze_multiple_patterns_on_same_line():
    sources = [
        Source(id="text_1", kind="text", transcript="Advance 50% pathaunus, OTP pani dinus"),
    ]
    pattern_catalog = {
        "advance_payment": {
            "id": "advance_payment",
            "severity": "medium",
            "title_en": "Payment requested before delivery",
            "title_ne": "सामान आउनुअघि नै पैसा माग",
            "description": "The seller asks for payment before delivery.",
            "why_en": "Advance payment is risky.",
            "why_ne": "अग्रिम भुक्तानी जोखिमपूर्ण हो।",
            "keywords": ["advance"],
            "next_steps": [],
        },
        "otp_credential_request": {
            "id": "otp_credential_request",
            "severity": "high",
            "title_en": "Asks for OTP, PIN or password",
            "title_ne": "OTP, PIN वा पासवर्ड माग",
            "description": "Anyone asking for a one-time code.",
            "why_en": "Seller never needs OTP.",
            "why_ne": "बिक्रेतालाई OTP चाहिँदैन।",
            "keywords": ["otp"],
            "next_steps": [],
        },
    }
    result = keyword_analyze(sources, pattern_catalog)
    assert len(result.signals) == 2
    pattern_ids = {s.pattern_id for s in result.signals}
    assert "advance_payment" in pattern_ids
    assert "otp_credential_request" in pattern_ids


def test_keyword_analyze_no_keywords_no_signals():
    sources = [
        Source(id="text_1", kind="text", transcript="Hello, how are you?"),
    ]
    pattern_catalog = {
        "advance_payment": {
            "id": "advance_payment",
            "severity": "medium",
            "title_en": "Payment requested before delivery",
            "title_ne": "सामान आउनुअघि नै पैसा माग",
            "description": "The seller asks for payment before delivery.",
            "why_en": "Advance payment is risky.",
            "why_ne": "अग्रिम भुक्तानी जोखिमपूर्ण हो।",
            "keywords": ["advance", "agrim"],
            "next_steps": [],
        }
    }
    result = keyword_analyze(sources, pattern_catalog)
    assert len(result.signals) == 0


def test_keyword_analyze_enough_information_true_with_text():
    sources = [
        Source(id="text_1", kind="text", transcript="Advance 50% pathaunus"),
    ]
    pattern_catalog = {
        "advance_payment": {
            "id": "advance_payment",
            "severity": "medium",
            "title_en": "Payment requested before delivery",
            "title_ne": "सामान आउनुअघि नै पैसा माग",
            "description": "The seller asks for payment before delivery.",
            "why_en": "Advance payment is risky.",
            "why_ne": "अग्रिम भुक्तानी जोखिमपूर्ण हो।",
            "keywords": ["advance"],
            "next_steps": [],
        }
    }
    result = keyword_analyze(sources, pattern_catalog)
    assert result.enough_information is True


def test_keyword_analyze_enough_information_false_without_text():
    sources = [
        Source(id="img_1", kind="image", transcript=""),
    ]
    pattern_catalog = {}
    result = keyword_analyze(sources, pattern_catalog)
    assert result.enough_information is False