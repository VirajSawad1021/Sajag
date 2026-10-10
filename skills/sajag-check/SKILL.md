---
name: sajag-check
description: Check a seller's chat text, screenshots, payment QRs or voice notes with Sajag before money is sent — quote-grounded risk signals, QR payee-vs-name check, and recovery/complaint drafts. Use when asked to "check this seller with Sajag", "run a Sajag check", or to analyse Nepali marketplace chat evidence for scam patterns.
---

# Sajag check

Sajag is a Nepali-first safety companion for people buying through Facebook, Instagram, TikTok and chat apps. This skill drives its FastAPI backend the same way the phone and web apps do.

## Rules you must follow

- Sajag shows **warning signs, not verdicts**. Never say "this seller is a scammer". Report the risk level and the signals, and say "not enough information" when it is.
- Only signals whose `quote` appears in the evidence count. If a warning's quote is not in the evidence, it is unverified — do not repeat it as fact.
- Never submit anything on the user's behalf. Sajag prepares drafts (bank/wallet message, Cyber Bureau application, NRB grievance); a human reviews, signs and submits.
- Evidence belongs to the user. Do not copy screenshots, QRs, transcripts or case data anywhere except the Sajag backend the user chose.

## Setup

```bash
# from the repo root
pip install -r backend/requirements.txt
cp .env.example .env        # add GEMINI_API_KEY and GEMMA_MODEL for AI analysis

cd backend && SAJAG_HOST=0.0.0.0 uvicorn app.main:app --port 8000
# no key? offline keyword engine (text only, weaker):
python backend/run_mock.py
```

Confirm with `GET /api/health` → `{"ok": true, "mock": false|true}`. When `mock` is true, `engine` in results is `offline-rules` and the summary says Gemma was not used — say so in your report.

## How to check

`POST /api/analyze` — multipart form:

| field | value |
|---|---|
| `text` | chat transcript, bank SMS or seller messages (Nepali, Romanized Nepali or English) |
| `stage` | `before_payment` (default) or `after_payment` |
| `images` | screenshots, payment QR photos, receipts |
| `audios` | Messenger/Viber/WhatsApp voice notes (≤15 MB each) |

```bash
curl -s -X POST http://localhost:8000/api/analyze \
  -F "text=COD mildaina dai, advance pathaunus" -F "stage=before_payment"
```

## Reading the result

- `overall.level` — risk banner shown to the user: `high`, `caution`, `low` or `insufficient` (not enough evidence to judge).
- `signals[]` — each has `pattern_id`, `title_en`/`title_ne`, `severity`, `quote`, `source_id`. Read the `quote` aloud and point to it in the evidence.
- `qr[]` — decoded by plain code (EMVCo), including payee name and CRC check; a payee that does not match the seller name in the chat is flagged without AI.
- `next_steps[]`, `deadlines[]` — advice drawn from reviewed pattern files, not invented by the model.
- `warnings[]` — engine-level notices (for example the offline fallback); surface them honestly.

## More endpoints

- `POST /api/analyze/stream` — same input, Server-Sent Events progress (QR decoded, messages read, each warning verified).
- `POST /api/agent` — the Sajag Agent: public-web checks about the shop/page and product price, then Suraksha Scripts (polite Nepali messages to test the seller).
- `POST /api/petition/draft` and `POST /api/petition/pdf` — Cyber Bureau "Online Financial Fraud" application draft and print-ready PDF.
- `POST /api/complaint` — bank/wallet complaint draft.
- `GET /api/patterns` — the community-maintained warning patterns (`patterns/*.yaml`). To teach Sajag a new pattern, add a YAML file there with a pull request — do not hardcode advice in your own prompts.
- `GET /api/resources` — verified official contacts (`data/resources.yaml`). Never substitute numbers from chats or news articles.
