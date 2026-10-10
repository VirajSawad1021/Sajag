"""Generate synthetic demo screenshots (no real people or chats) into frontend/public/demo/.

    python scripts/make_demo_data.py

Romanized Nepali only: Pillow's basic text layout cannot shape Devanagari correctly.
"""

from __future__ import annotations

import sys
from pathlib import Path

import qrcode
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "backend"))
from app.qr import crc16_ccitt  # noqa: E402

OUT = ROOT / "frontend" / "public" / "demo"
W = 720


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    for name in (["arialbd.ttf", "DejaVuSans-Bold.ttf"] if bold else ["arial.ttf", "DejaVuSans.ttf"]):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default(size)


def emv_qr(name: str, city: str = "KATHMANDU") -> Image.Image:
    def tlv(tag: str, value: str) -> str:
        return f"{tag}{len(value):02d}{value}"

    body = (
        tlv("00", "01") + tlv("01", "11")
        + tlv("26", tlv("00", "DEMO") + tlv("01", "9800000000"))
        + tlv("52", "5999") + tlv("53", "524") + tlv("58", "NP")
        + tlv("59", name) + tlv("60", city) + "6304"
    )
    return qrcode.make(body + crc16_ccitt(body)).convert("RGB")


def wrap(draw: ImageDraw.ImageDraw, text: str, f: ImageFont.FreeTypeFont, width: int) -> list[str]:
    lines, line = [], ""
    for word in text.split():
        trial = f"{line} {word}".strip()
        if draw.textlength(trial, font=f) <= width:
            line = trial
        else:
            lines.append(line)
            line = word
    return lines + [line]


def chat(page: str, messages: list[tuple[str, str, str]], qr_name: str | None = None) -> Image.Image:
    """messages: (sender 'seller'|'buyer', time, text)."""
    img = Image.new("RGB", (W, 2400), "white")
    d = ImageDraw.Draw(img)
    f, small = font(26), font(18)
    d.rectangle((0, 0, W, 90), fill="#f2f2f5")
    d.ellipse((20, 18, 74, 72), fill="#0f766e")
    d.text((90, 18), page, font=font(30, bold=True), fill="black")
    d.text((90, 54), "Active now", font=small, fill="#6b6b6b")
    y = 115
    for sender, time, text in messages:
        lines = wrap(d, text, f, 430)
        h = 24 + 34 * len(lines)
        seller = sender == "seller"
        x0 = 20 if seller else W - 20 - 470
        d.rounded_rectangle((x0, y, x0 + 470, y + h), 22, fill="#e9e9eb" if seller else "#0b84ff")
        for i, ln in enumerate(lines):
            d.text((x0 + 20, y + 12 + 34 * i), ln, font=f, fill="black" if seller else "white")
        d.text((x0 + (8 if seller else 390), y + h + 4), time, font=small, fill="#8a8a8a")
        y += h + 40
    if qr_name:
        qr = emv_qr(qr_name).resize((360, 360))
        d.rounded_rectangle((20, y, 400, y + 380), 22, fill="#e9e9eb")
        img.paste(qr, (30, y + 10))
        y += 400
    return img.crop((0, 0, W, y + 20))


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    chat(
        "KTM Mobile Hub",
        [
            ("seller", "Oct 3, 10:02", "Namaste! iPhone 15 128GB new box pack, Rs 1,15,000. COD milcha, ghar samma delivery."),
            ("buyer", "Oct 3, 10:05", "Thik cha, COD ma linchu. Kahile aaucha?"),
            ("seller", "Oct 4, 18:40", "Sorry dai, COD band bhayo. Advance 50% pathaunus ani matra dispatch huncha."),
            ("seller", "Oct 4, 18:41", "Stock sakincha, aaja nai pathaunus. Yo QR ma pathaunus:"),
        ],
        qr_name="SITA SHARMA",
    ).save(OUT / "scam-chat.png")
    chat(
        "Thamel Kurta House",
        [
            ("seller", "Oct 5, 11:10", "Namaste! Cotton kurta Rs 1,800. COD available cha."),
            ("buyer", "Oct 5, 11:12", "Size M cha? Ramro bhayena bhane?"),
            ("seller", "Oct 5, 11:15", "M cha. Ghar ma aayera check garera matra paisa dinus. Size milena bhane 3 din bhitra exchange milcha."),
        ],
    ).save(OUT / "honest-chat.png")
    chat(
        "Global Parcel Service",
        [
            ("seller", "Oct 6, 09:00", "Tapaiko parcel customs ma rokiyo. Release garna Rs 2,500 clearance fee pathaunus."),
            ("buyer", "Oct 6, 09:20", "Maile pahile nai Rs 5,000 tirisake. Refund dinus."),
            ("seller", "Oct 6, 09:22", "Refund garna pani 1,500 processing fee lagcha. Ani verify garna OTP pathaunus."),
        ],
    ).save(OUT / "refund-fee-chat.png")
    print("wrote", sorted(p.name for p in OUT.glob("*.png")))


if __name__ == "__main__":
    main()
