"""Tiny helper to drive the Sajag app on a USB-connected Android phone (adb), for testing.

    python scripts/phone.py dump                 # list on-screen labels and their positions
    python scripts/phone.py tap "Settings"       # tap the element whose label contains the text
    python scripts/phone.py shot out.png         # screenshot
    python scripts/phone.py launch               # open Sajag
"""

from __future__ import annotations

import os
import re
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ADB = str(Path(os.environ["LOCALAPPDATA"]) / "Android" / "Sdk" / "platform-tools" / "adb.exe")
PACKAGE = "np.sajag.sajag"


def adb(*args: str, binary: bool = False):
    out = subprocess.run([ADB, *args], capture_output=True, timeout=60)
    return out.stdout if binary else out.stdout.decode("utf-8", "replace")


def elements() -> list[tuple[str, int, int]]:
    """(label, centre x, centre y) for every on-screen node with a text or content description."""
    adb("shell", "uiautomator", "dump", "/sdcard/sajag-ui.xml")
    xml = adb("shell", "cat", "/sdcard/sajag-ui.xml")
    out = []
    for node in re.findall(r"<node [^>]+>", xml):
        label = " ".join(v for v in re.findall(r'(?:text|content-desc)="([^"]*)"', node) if v).replace("&#10;", " ")
        bounds = re.search(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', node)
        if label and bounds:
            x1, y1, x2, y2 = map(int, bounds.groups())
            out.append((label, (x1 + x2) // 2, (y1 + y2) // 2))
    return out


def sajag_in_front() -> bool:
    """Only ever tap inside Sajag — never in another app on the user's phone."""
    focus = adb("shell", "dumpsys", "window", "displays") + adb("shell", "dumpsys", "activity", "activities")
    m = re.search(r"(?:mCurrentFocus|topResumedActivity|mResumedActivity)[^\n]*", focus)
    return bool(m and PACKAGE in m.group(0))


def tap(text: str, retries: int = 6) -> bool:
    if not sajag_in_front():
        print("refusing to tap: Sajag is not the app in front")
        return False
    for _ in range(retries):
        matches = [e for e in elements() if text.lower() in e[0].lower()]
        if matches:
            label, x, y = min(matches, key=lambda e: len(e[0]))  # most specific match
            adb("shell", "input", "tap", str(x), str(y))
            print(f"tapped {label[:60]!r} at {x},{y}")
            return True
        time.sleep(1)
    print(f"not found: {text!r}")
    return False


def shot(path: str) -> None:
    Path(path).write_bytes(adb("exec-out", "screencap", "-p", binary=True))
    print("saved", path)


def main() -> None:
    cmd, *rest = sys.argv[1:] or ["dump"]
    if cmd == "dump":
        for label, x, y in elements():
            print(f"{x:>5},{y:<5} {label[:90]}")
    elif cmd == "tap":
        tap(rest[0])
    elif cmd == "shot":
        shot(rest[0] if rest else str(Path(tempfile.gettempdir()) / "phone.png"))
    elif cmd == "launch":
        adb("shell", "monkey", "-p", PACKAGE, "-c", "android.intent.category.LAUNCHER", "1")
    elif cmd == "tapxy":  # for labels that don't survive the Windows command line (e.g. Devanagari)
        if sajag_in_front():
            adb("shell", "input", "tap", rest[0], rest[1])
        else:
            print("refusing to tap: Sajag is not the app in front")
    elif cmd == "scroll":
        if sajag_in_front():
            adb("shell", "input", "swipe", "540", "1700", "540", "700", "300")
    elif cmd == "back":
        if sajag_in_front():
            adb("shell", "input", "keyevent", "4")
        else:
            print("refusing to press back: Sajag is not the app in front")


if __name__ == "__main__":
    os.environ.setdefault("MSYS_NO_PATHCONV", "1")
    main()
