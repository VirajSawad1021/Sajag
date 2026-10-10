# Sajag (सजग)

**पैसा पठाउनुअघि, सजग।** — *Before you send money, stay alert.*

Sajag is an open-source, Nepali-first safety companion for people buying through Facebook, Instagram, TikTok and chat apps — from the first message to delivery, or to recovery if it goes wrong. Share a seller's chat, payment QR or voice note **before you pay**: Gemma 4 reads it, lights up the risky messages on your own screenshot, checks the seller online and writes the questions to send back. If money is already gone, Sajag walks you through recovery and fills the Cyber Bureau's application for you to sign.

**Apps:** a Flutter phone app ([`mobile/`](mobile/)) and a web app ([`frontend/`](frontend/)), both on the same FastAPI + Gemma 4 backend.

Built by **Team Markovian** (Viraj Sawad, Aakriti Pandey, Chandan Kumar Shah) for Hacktoberfest 2026 Hack Day.

## What makes it different

| | |
|---|---|
| **Reads who the QR really pays** | Payment QRs are decoded by plain code (no AI). Sajag compares the payee name inside the QR with the shop name used in the chat. |
| **Every warning has a quote** | Gemma 4 must quote the exact text behind each warning. Code checks the quote exists in your evidence; if it doesn't, the warning is marked *unverified* and does not count. |
| **Nepali, Romanized Nepali, English** | Handles "COD mildaina dai, advance pathaunus" as well as Devanagari and English. |
| **Explain by voice** | Upload a Messenger/Viber/WhatsApp voice note or record in the app. It is transcribed, then analysed by Gemma like any other evidence. |
| **Share straight from your phone** | Installable web app (PWA). On Android it appears in the Share menu, so you can share a screenshot directly from Messenger or Gallery. |
| **From "I paid" to a complaint draft** | Timeline + editable Nepali निवेदन for the bank/wallet, Cyber Bureau, NRB or Department of Commerce. Sajag never submits anything. |
| **Scam X-Ray** | Gemma 4 locates each message on your screenshot; Sajag dims the rest and marks only messages behind a *verified* warning. |
| **Live reasoning** | While Gemma works, the app streams what it is doing: QR decoded, messages read, timeline built, each warning verified. |
| **Sajag Agent** | Gemma calls tools: Google Search about the shop/page and the product's real price (never private names or numbers), then writes Suraksha Scripts — polite Nepali messages to test the seller. |
| **Follow-ups** | Gemma extracts promised dates ("3 din bhitra"); verified ones become phone reminders: *"Did your order arrive?"* |
| **Recovery mode** | A checklist in NRB's order — wallet first, final message, report the page, Cyber Bureau, NRB escalation — with verified official contacts only. |
| **Cyber Bureau application** | The Bureau has no online form. Gemma fills its *Online Financial Fraud* application from the case (each field checked against the evidence); you review it and get a print-ready PDF with a B.S. date and numbered annexes. |
| **"I shared my OTP"** | An emergency screen for the most common scam: call the wallet, change PINs, eSewa's 48-hour insurance window, report. |
| **Hide private details** | Before upload, drag boxes over OTPs, balances, account numbers or faces; they're blacked out in the image pixels and only that copy is sent. |
| **Read aloud in Nepali** | Verdict, warnings and next steps spoken with the phone's own Nepali voice — for parents and grandparents. Works offline. |
| **"A friend asked for money?"** | Hacked-account check: no web search, but scripts to verify the person (a question only they'd know, a call on their usual number, refuse codes). |
| **Your cases stay on your phone** | The Casebook is stored on the device. No account, no server copy. |
| **Community-maintained patterns** | Warning patterns are YAML files in [`patterns/`](patterns/) — add one with a pull request. |

Sajag shows **warning signs, not verdicts**. It never says a seller is a scammer, and "not enough information" is a valid result.

## How it works

```
screenshots / pasted text / QR / voice notes
        │
        ├─► voice notes ─► ffmpeg ─► speech-to-text (Gemini 2.5 Flash) ─► transcript      [ASR only]
        ├─► QR decoder (OpenCV + EMVCo parser) ──► payee name, amount, checksum   [deterministic]
        │
        └─► Gemma 4 (Gemini API) ──► transcript, facts, events, candidate signals   [AI]
                                          │
                          quote grounding: is each quote really in the evidence?  [deterministic]
                          QR payee vs claimed seller name                         [deterministic]
                          risk level from grounded signals only                   [deterministic]
                          next steps from reviewed pattern files                  [deterministic]
                                          │
                                   results · timeline · report · complaint draft
```

Gemma reads and interprets. Everything that decides what the user sees as evidence — QR facts, quote checks, risk level, advice text — is ordinary code and reviewed data, so the model cannot invent official advice or phone numbers.

## Run it

Requirements: Python 3.11+, Node 18+, ffmpeg (for voice notes).

```bash
cp .env.example .env          # add GEMINI_API_KEY and GEMMA_MODEL
pip install -r backend/requirements.txt
cd backend && python -m app.list_models   # find the exact Gemma 4 model id for .env
```

**Development (two terminals):**

```bash
cd backend && uvicorn app.main:app --reload
cd frontend && npm install && npm run dev      # http://localhost:5173
```

**No API key yet?** Run with the offline keyword analyzer (text only, much weaker):

```bash
cd frontend && npm install && npm run build && cd .. && python backend/run_mock.py   # http://localhost:8000
```

**Single server (demo):** `npm run build` in `frontend/`, then `uvicorn app.main:app` in `backend/` serves the app and API on port 8000.

### Phone app (Flutter)

```bash
cd mobile && flutter pub get
flutter build apk --release                 # -> build/app/outputs/flutter-apk/app-release.apk
```

Install the APK on an Android phone (or `flutter run` with USB debugging on). Run the backend so the phone can
reach it — phone and laptop on the same Wi-Fi:

```bash
SAJAG_HOST=0.0.0.0 python backend/run.py     # Windows may ask to allow Python through the firewall
```

In the app: **Settings → Sajag server address** → `http://<laptop Wi-Fi IP>:8000` → *Test connection*.

The same app also runs in a browser: `cd mobile && flutter build web --base-href /app/`, then open
`http://localhost:8000/app/`. `python scripts/ui_check_app.py` drives it like a user and screenshots every step.

### Testing the web app on a phone

Install and Share-menu features need HTTPS. Expose the single server with a tunnel, e.g. `cloudflared tunnel --url http://localhost:8000`, open the HTTPS link on Android Chrome, choose **Add to Home screen**, then share a screenshot to Sajag. (iPhone: install works, but sharing into web apps isn't supported — use the upload button.)

### Tests and evaluation

```bash
cd backend && python -m pytest -q          # unit + API tests (offline)
python scripts/run_test_data.py            # 21 end-to-end cases on synthetic screenshots, QRs and voice notes
python evals/run_eval.py                 # with Gemma
SAJAG_MOCK=1 python evals/run_eval.py    # offline baseline
```

`evals/cases.yaml` and [`test data/`](test%20data/README.md) include honest-seller cases, so false alarms are measured as well as catches. Latest full run: **21/21** end-to-end cases passing, including prompt injection, a tampered QR, a blurry screenshot and voice notes in three formats.

## Privacy

- Uploads are processed in memory for one check and are not stored or logged by the backend.
- They **are** sent to the server and to the Gemini API for analysis. This is not on-device processing.
- QR account numbers are masked in responses.
- The evidence report is built in the browser and includes SHA-256 checksums of the original images.
- Demo with synthetic chats or your own, with permission — never other people's private conversations.

## Project layout

```
backend/app/     FastAPI app: analysis pipeline, QR parser, grounding, complaint builder
backend/tests/   pytest suite
frontend/        React + TypeScript PWA (share target in public/manifest.webmanifest + public/sw.js)
patterns/        warning patterns (one YAML file each) — contributions welcome
data/            official resources (with last-checked dates) and per-stage next steps
evals/           labelled cases and evaluation runner
docs/            demo script
```

## Limitations

- Gemma's transcription of screenshots can be wrong; the UI shows the transcript so users can check it.
- **Voice notes:** Gemma 4 on the Gemini API does not accept audio, so speech-to-text uses Gemini 2.5 Flash (`SAJAG_ASR_MODEL`). Gemma does all the analysis. Self-hosted Gemma 4 E2B/E4B accepts audio directly and could replace this step. The server needs `ffmpeg`.
- A check takes about 15–45 seconds on the free Gemini API tier.
- The Telegram bot (`backend/bot.py`) works, but Telegram is blocked in Nepal (NTA order, July 2025) — don't rely on it there.
- See [docs/research.md](docs/research.md) for sources behind every official contact and procedure.
- QR parsing is verified on EMVCo-format QRs; wallet-specific personal QRs need testing with real samples.
- Official links in `data/resources.yaml` must be re-checked and dated before release.
- Not a substitute for your bank, wallet provider, police or a lawyer.

## License

[MIT](LICENSE)
