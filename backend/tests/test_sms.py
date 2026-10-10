from app.sms import parse_payments

# Synthetic messages in the styles Nepali banks and wallets use (no real numbers).
BANK = "Dear Customer, your A/C XXXX1234 has been debited by NPR 3,200.00 on 28-09-2026 for fund transfer. Ref No: FT2609281928. Bal: NPR 4,512.50"
WALLET = "You have sent Rs. 3200 to 98XXXXX321 (Sushil Rai). Txn ID: TXN-7Q4K-2291 on 2026-09-28 19:28"
CREDIT = "Your account has been credited with Rs 500 on 01/10/2026. Transaction ID: CR77881122"
CHAT = "Seller: Advance 50% pathaunus, stock sakincha"


def test_bank_debit_sms():
    [p] = parse_payments(BANK, "text_1")
    assert p.amount == "3200.00" and p.direction == "debit"
    assert p.transaction_id == "FT2609281928" and p.date == "2026-09-28"


def test_wallet_sms():
    [p] = parse_payments(WALLET, "text_1")
    assert p.amount == "3200" and p.direction == "debit"
    assert p.transaction_id == "TXN-7Q4K-2291" and p.date == "2026-09-28"


def test_credit_and_several_messages():
    payments = parse_payments(BANK + "\n\n" + CREDIT, "text_1")
    assert [p.direction for p in payments] == ["debit", "credit"]
    assert payments[1].date == "2026-10-01"


def test_ordinary_chat_is_not_a_payment():
    assert parse_payments(CHAT, "text_1") == []


def test_bikram_sambat_year_not_misread():
    [p] = parse_payments("NPR 1,000 debited on 2083-06-12. Ref: AB12345", "text_1")
    assert p.date is None
