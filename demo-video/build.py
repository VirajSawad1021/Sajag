"""Cut the phone recordings to the narration and lay them out on a 1920x1080 frame.

    python build.py   ->  sajag-demo-<TEMPO>x.mp4  (TEMPO=1.5 python build.py)
"""

import os
import subprocess
import textwrap
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).parent
W, H = 1920, 1080
TEMPO = float(os.environ.get("TEMPO", "1.35"))  # narration speed-up, pitch kept
PHONE_H = 1000
PHONE_W = round(PHONE_H * 1080 / 2340 / 2) * 2
BG, INK, MUTED, ACCENT = (247, 242, 236), (24, 22, 20), (110, 102, 94), (196, 74, 42)
FONT = "C:/Windows/Fonts/segoeui.ttf"
BOLD = "C:/Windows/Fonts/segoeuib.ttf"
DEVA = "C:/Windows/Fonts/Nirmala.ttc"
ICON = HERE.parent / "mobile/assets/art/sajag-icon.png"
FOOT = "Recorded on a Samsung Galaxy A55. Demo mode replays real Gemma 4 runs, labelled in the app."

# (narration clip, title, subtitle, [(take, start, end), ...])
SCENES = [
    ("01", "Before you pay, stay alert.", "A Nepali-first scam safety companion, powered by Gemma 4.", [("s1", 0, 17)]),
    ("02", "Add the chat and the QR", "Screenshots, voice notes, pasted text, or share straight from Messenger.",
     [("s2", 1, 9.5), ("s2", 29, 31)]),
    ("03", "Gemma 4 reads the evidence", "Every warning must quote the exact line it came from, or it is dropped.",
     [("s2", 31, 48)]),
    ("04", "Scam X-Ray and the QR check", "The QR is decoded by code, not AI. It pays SITA SHARMA, not the shop.",
     [("s2", 48, 52), ("s2", 69.5, 79)]),
    ("05", "Reads the result aloud", "In Nepali, with the phone's own voice.", [("s5", 1, 9)]),
    ("06", "A hacked friend asking for money", "Sajag says: call them on the number you already have.",
     [("s6", 0.3, 16)]),
    ("09", "Did it arrive?", "On the promised delivery date, Sajag checks in.", [("s7", 35.5, 44)]),
    ("07", "Recovery, in NRB's order", "Verified eSewa, Khalti and Cyber Bureau contacts, step by step.",
     [("s7", 58, 70), ("s7", 86, 90)]),
    ("08", "Cyber Bureau application", "Gemma drafts it in Nepali. Amount and transaction ID come from your evidence.",
     [("s7", 116, 119), ("s7", 138, 150), ("s7", 153, 157)]),
    ("10", "Open source. Before you pay, be Sajag.", "github.com/VirajSawad1021/Sajag", [("s1", 17, 20.6)]),
]


def run(*args: str) -> None:
    subprocess.run(["ffmpeg", "-v", "error", "-y", *args], check=True)


def duration(path: Path) -> float:
    out = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(path)],
                         capture_output=True, text=True, check=True)
    return float(out.stdout)


def card(title: str, subtitle: str, index: int, out: Path) -> None:
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    icon = Image.open(ICON).convert("RGBA").resize((64, 64))
    mask = Image.new("L", (64, 64), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, 63, 63), fill=255)
    img.paste(icon, (140, 110), mask)
    d.text((222, 116), "Sajag", font=ImageFont.truetype(BOLD, 40), fill=INK)
    d.text((345, 112), "सजग", font=ImageFont.truetype(DEVA, 40), fill=MUTED)
    d.text((140, 330), f"{index:02d} / {len(SCENES):02d}", font=ImageFont.truetype(BOLD, 26), fill=ACCENT)
    y = 380
    for line in textwrap.wrap(title, 24):
        d.text((140, y), line, font=ImageFont.truetype(BOLD, 72), fill=INK)
        y += 92
    y += 18
    for line in textwrap.wrap(subtitle, 44):
        d.text((140, y), line, font=ImageFont.truetype(FONT, 36), fill=MUTED)
        y += 52
    d.text((140, H - 150), "Team Markovian · Hacktoberfest 2026 Hack Day", font=ImageFont.truetype(BOLD, 26), fill=INK)
    d.text((140, H - 108), FOOT, font=ImageFont.truetype(FONT, 22), fill=MUTED)
    # soft shadow behind the phone
    px, py = W - PHONE_W - 240, (H - PHONE_H) // 2
    d.rounded_rectangle((px - 14, py - 14, px + PHONE_W + 14, py + PHONE_H + 14), 36, fill=(232, 224, 214))
    img.save(out)


def scene(i: int, voice: str, title: str, subtitle: str, cuts: list) -> Path:
    vo = HERE / f"vo_{voice}.wav"
    target = duration(vo) / TEMPO + 0.25
    takes = sorted({t for t, _, _ in cuts})
    inputs, chains = [], []
    for t in takes:
        inputs += ["-i", str(HERE / f"raw_{t}.mp4")]
    for k, (t, a, b) in enumerate(cuts):
        chains.append(f"[{takes.index(t)}:v]trim={a}:{b},setpts=PTS-STARTPTS,fps=30[c{k}]")
    length = sum(b - a for _, a, b in cuts)
    speed = min(max(length / target, 1.0), 3.0)
    chains.append("".join(f"[c{k}]" for k in range(len(cuts))) + f"concat=n={len(cuts)}:v=1:a=0,setpts=PTS/{speed:.4f},"
                  f"tpad=stop_mode=clone:stop_duration={target:.2f},trim=0:{target:.2f},"
                  f"scale={PHONE_W}:{PHONE_H}[phone]")
    bg = HERE / f"card_{i:02d}.png"
    card(title, subtitle, i, bg)
    px, py = W - PHONE_W - 240, (H - PHONE_H) // 2
    chains.append(f"[{len(takes)}:v][phone]overlay={px}:{py},format=yuv420p[v]")
    out = HERE / f"scene_{i:02d}.mp4"
    run(*inputs, "-loop", "1", "-i", str(bg), "-i", str(vo),
        "-filter_complex", ";".join(chains) + f";[{len(takes) + 1}:a]atempo={TEMPO},apad,atrim=0:{target:.2f},aresample=48000[a]",
        "-map", "[v]", "-map", "[a]", "-t", f"{target:.2f}", "-r", "30",
        "-c:v", "libx264", "-preset", "medium", "-crf", "20", "-c:a", "aac", "-b:a", "160k", str(out))
    print(f"scene {i:02d}: {target:.1f}s (speed x{speed:.2f})")
    return out


def main() -> None:
    outs = [scene(i, *s) for i, s in enumerate(SCENES, 1)]
    lst = HERE / "scenes.txt"
    lst.write_text("".join(f"file '{p.name}'\n" for p in outs))
    run("-f", "concat", "-safe", "0", "-i", str(lst), "-c", "copy", "-movflags", "+faststart", str(HERE / f"sajag-demo-{TEMPO}x.mp4"))
    print("total", round(duration(HERE / f"sajag-demo-{TEMPO}x.mp4"), 1), "s")


if __name__ == "__main__":
    main()
