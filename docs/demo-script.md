# Demo script (about 3 minutes)

Use synthetic chats or your own screenshots, with permission. Prepare these the day before:

- `demo/1-listing.png` — a listing: "iPhone 15, Rs 1,15,000, COD available", page name e.g. "KTM Mobile Hub".
- `demo/2-chat.png` — chat in Romanized Nepali: COD first, then "COD band bhayo, advance 50% pathaunus, stock sakincha".
- `demo/3-qr.png` — a payment QR whose payee name is a *different* personal name (generate one with `backend/tests/test_qr.py::emv_payload`, or use a team member's own QR with their consent).
- `demo/honest.png` — an honest seller chat: COD, exchange policy, no pressure.
- `demo/receipt.png` — a payment receipt (synthetic).

## Flow

1. **Hook (15 s).** "Once money is sent from a wallet, it is very hard to get back. The safest moment is the few seconds before someone scans the QR. Sajag is for that moment."
2. **Share from phone (30 s).** On Android, share `2-chat.png` and `3-qr.png` from Gallery to Sajag (installed PWA).
3. **Result (60 s).**
   - Banner: *High caution*.
   - QR card: the QR pays a different name than "KTM Mobile Hub" — read by code, not AI.
   - Signals: "terms changed" and "advance before delivery", each with the exact quoted line highlighted in the transcript.
   - Point out "Not always a scam" and the unknowns: Sajag doesn't accuse anyone.
4. **Honest counterexample (20 s).** Check `honest.png` and get *No major signs*. This shows it isn't just flagging everything.
5. **Already paid (40 s).** Switch to "Yes, I paid", add `receipt.png`. Show the timeline, then **Prepare a complaint draft**, which produces a Nepali निवेदन with the official links. Download the evidence report with checksums.
6. **Open source (15 s).** Show `patterns/*.yaml`: anyone can add a pattern with a PR, and `evals/` measures false alarms too.

## If the Wi-Fi or API fails

Run `python backend/run_mock.py` and paste the chat text instead. The offline keyword engine still flags it, and the UI says it is in offline mode.
