from datetime import date

from app.petition import Complainant, PetitionFields, TimelineItem, bs_date, bs_from_iso, ne_digits, render_html


def test_bs_dates():
    assert bs_date(date(2025, 4, 14)) == "२०८२-०१-०१"  # Nepali new year 2082
    assert bs_from_iso("2026-09-30") == "२०८३-०६-१४"
    assert bs_from_iso("not a date") is None


def test_html_has_annexes_and_escapes():
    fields = PetitionFields(amount="3200", transaction_id="TXN-1", narrative_ne="<b>x</b>",
                            timeline=[TimelineItem(when="Oct 3", what_ne="अर्डर")])
    doc = render_html(fields, Complainant(name="राम"), [("chat.png", b"\x89PNG", "image/png")])
    assert "अनुसूची-१" in doc and "रु." in doc and ne_digits("3200") in doc
    assert "&lt;b&gt;x&lt;/b&gt;" in doc  # user/model text is escaped
    assert "भोटाहिटी" in doc
