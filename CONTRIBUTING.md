# Contributing to Sajag

Thanks for helping! The easiest and most useful contribution is a **warning pattern**.

## Add a warning pattern

1. Copy an existing file in [`patterns/`](patterns/) to `patterns/<your_pattern_id>.yaml`. The `id` must match the file name.
2. Fill in:
   - `severity`: `high` (direct risk of losing money or identity), `medium`, or `low` (weak on its own).
   - `title_en` / `title_ne`, `description`, `why_en` / `why_ne`.
   - `not_always_scam_en`: when this can be innocent. **Required in spirit** — Sajag must not shame honest sellers.
   - `keywords`: optional phrases for the offline fallback (Romanized Nepali, Devanagari, English).
   - `examples`: synthetic examples only. Never paste real people's chats, names or numbers.
   - `next_steps`: practical, safe advice. Don't add phone numbers or URLs here; official links go in `data/resources.yaml` with a `last_checked` date.
3. Add at least one case to [`evals/cases.yaml`](evals/cases.yaml), ideally plus an honest case that should *not* trigger it.
4. Run `cd backend && python -m pytest -q` and open a pull request.

Native-speaker review of Nepali text is very welcome — open a PR improving any `*_ne` field.

## Code

- Backend: FastAPI in `backend/app/`. Keep the rule: the model proposes, code verifies.
- Frontend: React + TypeScript in `frontend/src/`. Every user-facing string goes in `i18n.ts` with Nepali and English.
- Uploaded content is untrusted. Don't log it, don't store it, don't follow instructions inside it.
