"""Sajag on Telegram: forward it, Sajag checks it.

Forward screenshots, payment QRs, voice notes, bank SMS text or a WhatsApp "Export chat" file. Sajag waits a few
seconds for everything you send together, analyses it with the same pipeline as the web app, and replies with
buttons for Suraksha Scripts, adding the seller's reply, "I already paid" and a complaint draft.

Run:  python backend/bot.py      (needs TELEGRAM_BOT_TOKEN, GEMINI_API_KEY and GEMMA_MODEL in .env)

Privacy: evidence is kept in memory only while a case is open (cleared after CASE_TTL or /new) and never logged.
The bot only replies to the person who wrote to it; it never messages sellers.
"""

from __future__ import annotations

import asyncio
import html
import io
import json
import logging
import time
import zipfile
from dataclasses import dataclass, field

import httpx

from .agent import run_agent
from .analysis import UploadedAudio, UploadedImage, analyze
from .complaint import build_complaint
from .config import TELEGRAM_BOT_TOKEN
from .gemma import ModelError
from .schemas import AnalysisResponse, Complainant, ComplaintRequest

log = logging.getLogger("sajag.telegram")

API = "https://api.telegram.org/bot{token}/{method}"
FILE_API = "https://api.telegram.org/file/bot{token}/{path}"
DEBOUNCE_S = 4  # wait for albums / several forwards to arrive together
CASE_TTL_S = 60 * 60
MAX_FILE_BYTES = 15 * 1024 * 1024
IMAGE_EXT = {".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".webp": "image/webp"}
AUDIO_EXT = (".opus", ".ogg", ".m4a", ".mp3", ".aac", ".wav")

LEVEL = {
    "high": ("🔴", "धेरै सावधान", "High caution"),
    "caution": ("🟠", "सावधान", "Caution"),
    "low": ("🟢", "ठूलो संकेत भेटिएन", "No major signs"),
    "insufficient": ("⚪", "जानकारी अपुग", "Not enough information"),
}
PAID_LEVEL = {"high": ("🔴", "अहिले नै कदम चाल्नुहोस्", "Act now")}

TEXT = {
    "start": {
        "ne": "नमस्ते! म <b>Sajag</b> हुँ। 🛡\n\nपैसा पठाउनुअघि बिक्रेताको च्याटको स्क्रिनसट, भुक्तानी QR, भ्वाइस नोट, बैंकको SMS "
              "वा WhatsApp को <i>Export chat</i> फाइल मलाई फरवार्ड गर्नुहोस्। म चेतावनीका संकेत प्रमाणसहित देखाउँछु र बिक्रेतालाई "
              "सोध्ने प्रश्न तयार गर्छु।\n\n/new — नयाँ जाँच · /en — English · /privacy — गोपनीयता",
        "en": "Hi! I'm <b>Sajag</b>. 🛡\n\nBefore you pay, forward me the seller's chat screenshots, the payment QR, voice "
              "notes, a bank SMS or a WhatsApp <i>Export chat</i> file. I'll show the warning signs with evidence and "
              "prepare questions to ask the seller.\n\n/new — new check · /ne — नेपाली · /privacy — privacy",
    },
    "privacy": {
        "ne": "तपाईंका फाइल जाँचका लागि Sajag सर्भर र Google को Gemini API मा पठाइन्छन्। केस खुला रहँदासम्म मात्र (बढीमा १ घण्टा "
              "वा /new नगरेसम्म) मेमोरीमा राखिन्छ, लग गरिँदैन। Sajag ले कसैलाई म्यासेज पठाउँदैन।",
        "en": "Your files are sent to the Sajag server and Google's Gemini API for the check. They are kept in memory "
              "only while the case is open (up to 1 hour, or until /new) and are not logged. Sajag never messages anyone.",
    },
    "got": {"ne": "📥 पाएँ: {items}। जाँच हुँदैछ… (१५–४० सेकेन्ड)", "en": "📥 Got {items}. Checking… (15–40 s)"},
    "new": {"ne": "🆕 नयाँ जाँच सुरु भयो। प्रमाण पठाउनुहोस्।", "en": "🆕 New check started. Send your evidence."},
    "reply_mode": {
        "ne": "↩ बिक्रेताको जवाफ (स्क्रिनसट वा भ्वाइस नोट) पठाउनुहोस्। अघिल्लो प्रमाणसँगै फेरि जाँचिन्छ।",
        "en": "↩ Send the seller's reply (screenshot or voice note). I'll re-check it together with the earlier evidence.",
    },
    "agent_wait": {"ne": "🛡 अनलाइन जाँच गर्दै र प्रश्न तयार गर्दै… (२०–३० सेकेन्ड)",
                   "en": "🛡 Checking online and preparing questions… (20–30 s)"},
    "scripts_intro": {"ne": "👇 यी म्यासेज बिक्रेतालाई फरवार्ड वा कपी गरेर पठाउनुहोस्:",
                      "en": "👇 Forward or copy these messages to the seller:"},
    "nothing": {"ne": "पहिले स्क्रिनसट, भ्वाइस नोट वा म्यासेज पठाउनुहोस्।", "en": "Send a screenshot, voice note or message first."},
    "error": {"ne": "⚠️ जाँच गर्न सकिएन: {err}", "en": "⚠️ The check failed: {err}"},
    "complaint": {"ne": "📝 उजुरीको मस्यौदा। [....] भएका ठाउँ भरेर, सच्याएर आफैं पेस गर्नुहोस्। Sajag ले केही पेस गर्दैन।",
                  "en": "📝 Complaint draft (in Nepali). Fill in the [....] parts, edit it and submit it yourself."},
    "changed": {"ne": "जोखिम बदलियो: {a} → <b>{b}</b>", "en": "Risk changed: {a} → <b>{b}</b>"},
    "same": {"ne": "बिक्रेताको जवाफसहित फेरि जाँचियो — अझै <b>{b}</b>", "en": "Re-checked with the reply — still <b>{b}</b>"},
    "disclaimer": {"ne": "<i>यी चेतावनीका संकेत हुन्, ठगीको प्रमाण होइनन्।</i>",
                   "en": "<i>These are warning signs, not proof of fraud.</i>"},
}

BUTTONS = {
    "scripts": {"ne": "🛡 बिक्रेतालाई के सोध्ने?", "en": "🛡 What to ask the seller"},
    "reply": {"ne": "↩ बिक्रेताको जवाफ थप्नुहोस्", "en": "↩ Add seller's reply"},
    "paid": {"ne": "💸 मैले पैसा तिरिसकें", "en": "💸 I already paid"},
    "complaint": {"ne": "📝 उजुरीको मस्यौदा", "en": "📝 Complaint draft"},
    "new": {"ne": "🆕 नयाँ जाँच", "en": "🆕 New check"},
}


@dataclass
class Case:
    lang: str = "ne"
    stage: str = "before_payment"
    texts: list[str] = field(default_factory=list)
    images: list[UploadedImage] = field(default_factory=list)
    audios: list[UploadedAudio] = field(default_factory=list)
    pending: int = 0  # items received since the last analysis
    last_level: str | None = None
    analysis: AnalysisResponse | None = None
    timer: asyncio.Task | None = None
    touched: float = field(default_factory=time.time)


class SajagBot:
    def __init__(self, token: str):
        self.token = token
        self.http = httpx.AsyncClient(timeout=70)
        self.cases: dict[int, Case] = {}

    # ---------------- Telegram API helpers

    async def call(self, method: str, files: dict | None = None, **params) -> dict:
        url = API.format(token=self.token, method=method)
        if files:
            data = {k: (json.dumps(v) if isinstance(v, (dict, list)) else v) for k, v in params.items()}
            resp = await self.http.post(url, data=data, files=files)
        else:
            resp = await self.http.post(url, json=params)
        body = resp.json()
        if not body.get("ok"):
            raise RuntimeError(f"Telegram {method} failed: {body.get('description')}")
        return body["result"]

    async def send(self, chat_id: int, text: str, buttons: list[list[tuple[str, str]]] | None = None) -> None:
        params: dict = {"chat_id": chat_id, "text": text, "parse_mode": "HTML", "disable_web_page_preview": True}
        if buttons:
            params["reply_markup"] = {"inline_keyboard": [[{"text": t, "callback_data": d} for t, d in row] for row in buttons]}
        await self.call("sendMessage", **params)

    async def download(self, file_id: str) -> bytes:
        info = await self.call("getFile", file_id=file_id)
        if info.get("file_size", 0) > MAX_FILE_BYTES:
            raise ValueError("file too large")
        resp = await self.http.get(FILE_API.format(token=self.token, path=info["file_path"]))
        resp.raise_for_status()
        return resp.content

    # ---------------- update handling

    def case(self, chat_id: int) -> Case:
        now = time.time()
        for cid in [c for c, v in self.cases.items() if now - v.touched > CASE_TTL_S]:
            del self.cases[cid]  # expire old evidence
        case = self.cases.setdefault(chat_id, Case())
        case.touched = now
        return case

    def t(self, case: Case, key: str, **kw) -> str:
        return TEXT[key][case.lang].format(**kw)

    async def handle_update(self, update: dict) -> None:
        if "callback_query" in update:
            await self.handle_button(update["callback_query"])
            return
        msg = update.get("message")
        if not msg or msg.get("chat", {}).get("type") != "private":
            return  # only private chats: evidence is personal
        chat_id = msg["chat"]["id"]
        case = self.case(chat_id)
        text = msg.get("text") or ""

        if text.startswith("/"):
            command = text.split()[0].split("@")[0]
            if command in ("/start", "/help"):
                await self.send(chat_id, self.t(case, "start"))
            elif command == "/new":
                self.cases[chat_id] = Case(lang=case.lang)
                await self.send(chat_id, self.t(case, "new"))
            elif command in ("/en", "/ne"):
                case.lang = command[1:]
                await self.send(chat_id, self.t(case, "start"))
            elif command == "/privacy":
                await self.send(chat_id, self.t(case, "privacy"))
            return

        try:
            added = await self.collect(msg, case)
        except Exception as exc:
            log.warning("could not read message: %s", exc)
            await self.send(chat_id, self.t(case, "error", err=html.escape(str(exc)[:200])))
            return
        if added:
            case.pending += added
            if case.timer:
                case.timer.cancel()
            case.timer = asyncio.create_task(self.analyse_later(chat_id, case))

    async def collect(self, msg: dict, case: Case) -> int:
        """Add the evidence in one Telegram message to the case. Returns the number of items added."""
        added = 0
        body = msg.get("text") or msg.get("caption") or ""
        if body.strip():
            origin = msg.get("forward_origin") or {}
            label = "Forwarded message" if origin else "Message from user"
            case.texts.append(f"[{label}]\n{body.strip()}")
            added += 1
        if msg.get("photo"):
            biggest = max(msg["photo"], key=lambda p: p.get("file_size", 0))
            case.images.append(UploadedImage(f"photo-{len(case.images) + 1}.jpg", await self.download(biggest["file_id"]), "image/jpeg"))
            added += 1
        for kind in ("voice", "audio", "video_note"):
            if msg.get(kind):
                data = await self.download(msg[kind]["file_id"])
                case.audios.append(UploadedAudio(f"{kind}-{len(case.audios) + 1}", data))
                added += 1
        doc = msg.get("document")
        if doc:
            name = (doc.get("file_name") or "file").lower()
            mime = doc.get("mime_type") or ""
            data = await self.download(doc["file_id"])
            ext = "." + name.rsplit(".", 1)[-1] if "." in name else ""
            if ext in IMAGE_EXT:
                case.images.append(UploadedImage(name, data, IMAGE_EXT[ext]))
                added += 1
            elif mime.startswith("audio/") or ext in AUDIO_EXT:
                case.audios.append(UploadedAudio(name, data))
                added += 1
            elif ext == ".txt":
                case.texts.append(f"[Chat export: {name}]\n{data.decode('utf-8', errors='replace')[-15000:]}")
                added += 1
            elif ext == ".zip":
                added += self.read_whatsapp_zip(data, case)
        return added

    def read_whatsapp_zip(self, data: bytes, case: Case) -> int:
        """WhatsApp 'Export chat' (with media) is a zip with _chat.txt plus images and .opus voice notes."""
        added = 0
        with zipfile.ZipFile(io.BytesIO(data)) as zf:
            for info in zf.infolist():
                name = info.filename.lower()
                if info.file_size > MAX_FILE_BYTES:
                    continue
                ext = "." + name.rsplit(".", 1)[-1] if "." in name else ""
                if ext == ".txt":
                    text = zf.read(info).decode("utf-8", errors="replace")
                    case.texts.append(f"[WhatsApp chat export]\n{text[-15000:]}")
                    added += 1
                elif ext in IMAGE_EXT and len(case.images) < 6:
                    case.images.append(UploadedImage(info.filename, zf.read(info), IMAGE_EXT[ext]))
                    added += 1
                elif ext in AUDIO_EXT and len(case.audios) < 3:
                    case.audios.append(UploadedAudio(info.filename, zf.read(info)))
                    added += 1
        return added

    async def analyse_later(self, chat_id: int, case: Case) -> None:
        try:
            await asyncio.sleep(DEBOUNCE_S)
        except asyncio.CancelledError:
            return
        await self.run_analysis(chat_id, case)

    async def run_analysis(self, chat_id: int, case: Case) -> None:
        if not (case.texts or case.images or case.audios):
            await self.send(chat_id, self.t(case, "nothing"))
            return
        parts = []
        if case.images:
            parts.append(f"{len(case.images)} 🖼")
        if case.audios:
            parts.append(f"{len(case.audios)} 🎙")
        if case.texts:
            parts.append(f"{len(case.texts)} 💬")
        await self.send(chat_id, self.t(case, "got", items=" · ".join(parts)))
        await self.call("sendChatAction", chat_id=chat_id, action="typing")
        case.pending = 0
        try:
            result = await asyncio.to_thread(
                analyze, "\n\n".join(case.texts), case.images[:6], case.stage, case.audios[:3]
            )
        except Exception as exc:
            log.exception("analysis failed")
            await self.send(chat_id, self.t(case, "error", err=html.escape(str(exc)[:200])))
            return
        previous = case.last_level
        case.analysis, case.last_level = result, result.overall.level
        await self.send(chat_id, self.format_result(case, result, previous), self.result_buttons(case))

    # ---------------- formatting

    def level_title(self, case: Case, level: str) -> tuple[str, str]:
        table = PAID_LEVEL if case.stage == "after_payment" and level in PAID_LEVEL else LEVEL
        emoji, ne, en = table[level]
        return emoji, ne if case.lang == "ne" else en

    def format_result(self, case: Case, r: AnalysisResponse, previous: str | None) -> str:
        ne = case.lang == "ne"
        emoji, title = self.level_title(case, r.overall.level)
        lines = [f"{emoji} <b>{html.escape(title)}</b>"]
        summary = r.overall.summary_ne if ne else r.overall.summary_en
        if summary and r.engine == "gemma":
            lines.append(html.escape(summary))
        if previous:
            a = self.level_title(case, previous)[1]
            key = "same" if previous == r.overall.level else "changed"
            lines.append(self.t(case, key, a=html.escape(a), b=html.escape(title)))
        for q in r.qr:
            if q.payee_name:
                lines.append(f"\n💳 QR → <b>{html.escape(q.payee_name)}</b>" + (" ⚠️ checksum" if q.crc_valid is False else ""))
        grounded = [s for s in r.signals if s.grounded]
        if grounded:
            lines.append("")
        for s in grounded[:5]:
            icon = {"high": "🔴", "medium": "🟠", "low": "🔵"}[s.severity]
            lines.append(f"{icon} <b>{html.escape(s.title_ne if ne else s.title_en)}</b>")
            lines.append(f"   “{html.escape(s.quote[:160])}”")
            explanation = (s.explanation_ne or s.explanation_en) if ne else s.explanation_en
            if explanation:
                lines.append(f"   {html.escape(explanation[:300])}")
        if r.next_steps:
            lines.append("\n<b>" + ("अब के गर्ने?" if ne else "What to do now") + "</b>")
            for step in r.next_steps[:4]:
                lines.append("• " + html.escape(step.text_ne if ne else step.text_en))
        for w in r.warnings:
            lines.append(f"\n<i>{html.escape(w)}</i>")
        lines.append("\n" + self.t(case, "disclaimer"))
        return "\n".join(lines)[:4000]

    def result_buttons(self, case: Case) -> list[list[tuple[str, str]]]:
        b = lambda key: (BUTTONS[key][case.lang], key)  # noqa: E731
        rows = [[b("scripts")], [b("reply")]]
        rows.append([b("complaint")] if case.stage == "after_payment" else [b("paid")])
        rows.append([b("new")])
        return rows

    # ---------------- buttons

    async def handle_button(self, query: dict) -> None:
        await self.call("answerCallbackQuery", callback_query_id=query["id"])
        chat_id = query["message"]["chat"]["id"]
        case = self.case(chat_id)
        action = query.get("data")
        if action == "new":
            self.cases[chat_id] = Case(lang=case.lang)
            await self.send(chat_id, self.t(case, "new"))
        elif action == "reply":
            await self.send(chat_id, self.t(case, "reply_mode"))
        elif not case.analysis:
            await self.send(chat_id, self.t(case, "nothing"))
        elif action == "paid":
            case.stage = "after_payment"
            await self.run_analysis(chat_id, case)
        elif action == "scripts":
            await self.send_scripts(chat_id, case)
        elif action == "complaint":
            await self.send_complaint(chat_id, case)

    async def send_scripts(self, chat_id: int, case: Case) -> None:
        if case.analysis.engine != "gemma":
            await self.send(chat_id, self.t(case, "error", err="Gemma is offline"))
            return
        await self.send(chat_id, self.t(case, "agent_wait"))
        try:
            agent = await asyncio.to_thread(run_agent, case.analysis)
        except ModelError as exc:
            await self.send(chat_id, self.t(case, "error", err=html.escape(str(exc)[:200])))
            return
        ne = case.lang == "ne"
        online = agent.online_summary_ne if ne and agent.online_summary_ne else agent.online_summary_en
        searched = "\n".join(f"🔎 {html.escape(q.replace('web_search: ', ''))}" for q in agent.trace)
        await self.send(chat_id, (searched + "\n\n" if searched else "") + html.escape(online))
        await self.send(chat_id, self.t(case, "scripts_intro"))
        for s in agent.scripts:
            # Each script is its own plain message so it can be forwarded to the seller as-is.
            await self.call("sendMessage", chat_id=chat_id, text=s.message_ne)
        changes = agent.what_changes_risk_ne if ne and agent.what_changes_risk_ne else agent.what_changes_risk_en
        if changes:
            await self.send(chat_id, f"<i>{html.escape(changes)}</i>", [[(BUTTONS["reply"][case.lang], "reply")]])

    async def send_complaint(self, chat_id: int, case: Case) -> None:
        text = build_complaint(ComplaintRequest(analysis=case.analysis, recipient="bank", complainant=Complainant()))
        await self.send(chat_id, self.t(case, "complaint"))
        await self.call(
            "sendDocument",
            chat_id=chat_id,
            files={"document": ("sajag-complaint-draft.txt", text.encode("utf-8"), "text/plain")},
        )

    # ---------------- main loop

    async def run(self) -> None:
        me = await self.call("getMe")
        await self.call("setMyCommands", commands=[
            {"command": "new", "description": "नयाँ जाँच / New check"},
            {"command": "en", "description": "English"},
            {"command": "ne", "description": "नेपाली"},
            {"command": "privacy", "description": "गोपनीयता / Privacy"},
        ])
        log.warning("Sajag bot running as @%s", me.get("username"))
        offset = 0
        while True:
            try:
                updates = await self.call("getUpdates", offset=offset, timeout=50, allowed_updates=["message", "callback_query"])
            except (httpx.HTTPError, RuntimeError) as exc:
                log.warning("getUpdates failed: %s", exc)
                await asyncio.sleep(3)
                continue
            for update in updates:
                offset = update["update_id"] + 1
                asyncio.create_task(self._safe(update))

    async def _safe(self, update: dict) -> None:
        try:
            await self.handle_update(update)
        except Exception:
            log.exception("update failed")


def main() -> None:
    logging.basicConfig(level=logging.WARNING, format="%(asctime)s %(name)s %(message)s")
    logging.getLogger("httpx").setLevel(logging.WARNING)  # httpx INFO logs would include the token in URLs
    if not TELEGRAM_BOT_TOKEN:
        raise SystemExit("Set TELEGRAM_BOT_TOKEN in .env (create a bot with @BotFather).")
    asyncio.run(SajagBot(TELEGRAM_BOT_TOKEN).run())
