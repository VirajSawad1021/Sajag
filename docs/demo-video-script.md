# Demo video script (1:24)

Narration in the Viraj_v8 voice (OmniVoice), sped up 1.35× with the pitch kept the same. The footage was recorded on a Samsung Galaxy A55.
Scenes marked *replay* use demo mode, which plays back a recorded real Gemma 4 run. The app labels these replays on screen.
To rebuild: `TEMPO=1.35 python demo-video/build.py`

| # | Time | On screen | Narration |
|---|------|-----------|-----------|
| 1 | 0:00 | First-run intro → home | In Nepal, online shopping scams take people's savings every day. And once money leaves your wallet, it is almost impossible to get back. Sajag is a scam safety companion, powered by Gemma 4, built for the few seconds before you pay. |
| 2 | 0:13 | New check → "COD → advance + QR" sample added → Check it | Here, a seller first promised cash on delivery, then switched to advance only, and sent a payment QR. I add the chat and the QR to Sajag. You can also share them straight from Messenger. |
| 3 | 0:23 | Live analysis feed: QR decoded, Gemma reading, phases *(replay)* | Gemma 4 reads the screenshots, in Nepali, English or Romanized Nepali, and shows what it finds as it goes. Every warning must quote the exact line from the evidence, or it is thrown away. |
| 4 | 0:33 | High caution → Scam X-Ray marks → "Who the QR actually pays: SITA SHARMA" *(replay)* | High caution. Scam X-Ray marks each warning on the screenshot itself. And the QR is decoded by code, not by AI. It pays a different person than the shop in the chat. |
| 5 | 0:42 | Switch to Nepali → Read aloud (button shows रोक्नुहोस्) | For anyone who prefers to listen, Sajag reads the result aloud, in Nepali. |
| 6 | 0:46 | "Sita Didi" friend case: warnings, "call your friend" step | It also catches the most common trick on Messenger. A hacked friend asking for money, and then for a code. Sajag tells you to call them on the number you already have, before sending anything. |
| 7 | 0:57 | Paid-but-nothing-came case: Act now + "Did it arrive?" card *(replay)* | And on the delivery date the seller promised, Sajag checks in. Did it arrive? If not, one tap starts recovery. |
| 8 | 1:03 | Recovery plan: wallet contacts, step marked done | If you have already paid, Sajag switches to recovery. The steps follow Nepal Rastra Bank's order, with verified wallet and Cyber Bureau contacts. |
| 9 | 1:11 | Cyber Bureau application: Gemma fills it, amount/TXN "found in evidence", Nepali text, Make the PDF *(replay)* | Gemma then drafts the Cyber Bureau application in Nepali, with the Bikram Sambat date, and every piece of evidence fingerprinted, ready to print and submit. |
| 10 | 1:20 | Home screen, github.com/VirajSawad1021/Sajag | Sajag is open source, and anyone can add a new scam pattern. Before you pay, be Sajag. |

## Not in this cut (needs live Gemma, which was blocked by the API spending cap)

- Sajag Agent panel: web search on the seller and questions to ask.
- Bank SMS sample: amount, transaction ID and date read by code.
- Voice note recorded in the app.
