# Team tasks — Aakriti and Chandan

Work in the **private** repo `VirajSawad1021/hactober_hack`, each on your own branch, then open a pull request
into `main`. Don't push to the public `Sajag` repo directly — Viraj's scheduled pushes go there and would fail;
your merged commits will be added to it afterwards (under your own name).

Each person has separate files, so there are no merge conflicts. Make **one small commit per task**.

## Setup (both)

```bash
git clone https://github.com/VirajSawad1021/hactober_hack.git
cd hactober_hack
git checkout -b <your-name>/<topic>          # e.g. aakriti/nepali-patterns
cp .env.example .env                         # add your own GEMINI_API_KEY (aistudio.google.com/apikey)
pip install -r backend/requirements.txt
cd backend && python -m pytest -q            # should pass before you start
```

Rules: never commit `.env`, real chats of other people, your own QR screenshots, or phone numbers / account
numbers. Run `cd backend && python -m pytest -q` before every commit. Push with `git push -u origin <branch>`.

---

## Aakriti — Nepali language and new scam patterns

Files you own: `patterns/*.yaml`, `evals/cases.yaml`, `mobile/lib/l10n.dart` (Nepali strings only).

| # | Commit | What |
|---|---|---|
| A1 | `Review Nepali text in warning patterns` | Make `title_ne`, `why_ne` and the Nepali `next_steps` in `patterns/*.yaml` sound natural and simple for an older reader. Don't change ids or English meaning. |
| A2 | `Pattern: fake prize, lottery or gift` | New `patterns/prize_lottery.yaml` ("you won… pay a fee / share details to claim") + 2 cases in `evals/cases.yaml` (one scam, one harmless). |
| A3 | `Pattern: fake bank or wallet staff (KYC update)` | New `patterns/fake_kyc_call.yaml` ("account will be blocked, update KYC, send OTP") + 2 cases. |
| A4 | `Review Nepali UI strings` | Polish the `'ne'` values in `mobile/lib/l10n.dart` (no code changes). |

### Prompt Aakriti can paste into Claude Code (or another coding assistant) inside the repo

> I'm working on Sajag, a Nepali-first scam-safety app (repo: this folder; read `README.md`, `overall.md` and
> `CONTRIBUTING.md` first). I own only these files: `patterns/*.yaml`, `evals/cases.yaml`, and the Nepali (`'ne'`)
> strings in `mobile/lib/l10n.dart`. Do not edit anything else.
>
> Do these as four separate small commits, running `cd backend && python -m pytest -q` before each:
> 1. "Review Nepali text in warning patterns": improve `title_ne`, `why_ne` and Nepali `next_steps` in every
>    `patterns/*.yaml` so they read naturally and simply for an older Nepali reader. Keep ids, severities, English
>    text and meaning unchanged. Show me the before/after for each file and let me approve before committing.
> 2. "Pattern: fake prize, lottery or gift": add `patterns/prize_lottery.yaml` following the exact format of the
>    existing files (id must match the filename; include `not_always_scam_en`, Romanized-Nepali/Devanagari/English
>    `keywords` and synthetic `examples`, safe `next_steps` in English and Nepali — no phone numbers or URLs). Add two
>    synthetic cases to `evals/cases.yaml` in the existing format: one prize scam that must flag it, one harmless
>    message that must not.
> 3. "Pattern: fake bank or wallet staff (KYC update)": same for `patterns/fake_kyc_call.yaml` (callers/SMS saying the
>    account will be blocked unless KYC is updated or an OTP is shared). Two cases again.
> 4. "Review Nepali UI strings": improve only the `'ne'` values in `mobile/lib/l10n.dart`; keep keys and `'en'`
>    values, keep Dart syntax valid (escape apostrophes or use double quotes).
>
> All examples must be made up — no real names, phone numbers or account numbers. Commit messages exactly as
> above. Then push my branch with `git push -u origin aakriti/nepali-patterns`.

---

## Chandan — open source, verification and the pitch

Files you own: `skills/`, `docs/qr-findings.md`, `data/resources.yaml`, `docs/demo-script.md`.

| # | Commit | What |
|---|---|---|
| C1 | `Agent Skill: sajag-check` | `skills/sajag-check/SKILL.md` following the Agent Skills open standard (YAML front matter with `name` and `description`, then instructions) — teaches an AI agent to check a suspicious purchase chat with Sajag's API and warning patterns. Needed for the open-source track. |
| C2 | `Real payment QR findings` | Run `python scripts/inspect_qr.py` on screenshots of **your own** eSewa / Khalti / Fonepay / bank "receive" QRs placed in `test data/private/` (git-ignored). Write only the masked structure in `docs/qr-findings.md`. Never commit the images. |
| C3 | `Re-verify official contacts` | Open each source link in `data/resources.yaml` in a browser; fix anything changed; set `last_checked` to today; fill in the source for `consumer_complaint` if you can verify it. Only official sites. |
| C4 | `Pitch: 3-minute demo script` | Update `docs/demo-script.md` for the current phone app: share-to-Sajag → live analysis → Scam X-Ray → agent scripts → friend check → recovery and Cyber Bureau application; mention demo mode as backup. |

### Prompt Chandan can paste into Claude Code (or another coding assistant) inside the repo

> I'm working on Sajag, a Nepali-first scam-safety app (repo: this folder; read `README.md`, `overall.md`,
> `backend/app/main.py` and `patterns/` first). I own only these files: `skills/`, `docs/qr-findings.md`,
> `data/resources.yaml`, `docs/demo-script.md`. Do not edit anything else.
>
> Do these as four separate small commits, running `cd backend && python -m pytest -q` before each:
> 1. "Agent Skill: sajag-check": create `skills/sajag-check/SKILL.md` that follows the Agent Skills open standard —
>    YAML front matter with `name: sajag-check` and a clear `description` of when to use it, then concise instructions
>    for an agent: how to call `POST /api/analyze` (multipart: `text`, `stage`, `images`, `audios`) and `POST
>    /api/agent`, how to read the response (only `grounded` signals count; never call anyone a scammer; "insufficient"
>    is valid), and where the warning patterns live. Look up the current Agent Skills spec online before writing it.
> 2. "Real payment QR findings": I've put screenshots of my own payment QRs in `test data/private/` (git-ignored).
>    Run `python scripts/inspect_qr.py`, then write `docs/qr-findings.md` summarising per wallet: format (EMVCo/JSON/
>    other), whether a payee name and an account ID are present, static vs dynamic, CRC valid — using only the masked
>    output. Never copy unmasked numbers or commit the images. Say what this means for the payee check.
> 3. "Re-verify official contacts": for each entry in `data/resources.yaml`, I'll open the `source` link in my
>    browser and tell you what it says; update only what I confirm, set `last_checked` to today's date, and don't
>    add any number or URL I haven't confirmed from an official site.
> 4. "Pitch: 3-minute demo script": rewrite `docs/demo-script.md` for the current Flutter phone app (read
>    `overall.md` for the features), timed beats totalling ~3 minutes, with demo mode as the backup if Wi-Fi fails.
>
> Commit messages exactly as above. Then push my branch with `git push -u origin chandan/skill-qr-pitch`.

---

When your branch is pushed, open a pull request into `main` on GitHub and tell Viraj. After it's merged, your
commits are added to the public `Sajag` repo too.
