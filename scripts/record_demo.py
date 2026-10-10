"""Record real runs of the demo scenarios so the app's demo mode can replay them offline.

    python backend/run.py            # in another terminal
    python scripts/record_demo.py    # -> mobile/assets/demo/recordings.json

Each scenario is sent to the live backend exactly as the app sends it; every progress event is saved with its
timestamp, together with the final analysis, the agent's output and (after payment) the petition draft.
Demo mode labels replays as "replay of a real Gemma run" — nothing is invented.
"""

from __future__ import annotations

import json
import mimetypes
import time
from pathlib import Path

import httpx

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "mobile" / "assets" / "demo"
API = "http://127.0.0.1:8000"

SCENARIOS = {
    "scam": {"files": ["scam-chat.png"], "stage": "before_payment"},
    "scam_reply": {"files": ["scam-chat.png", "seller-reply.png"], "stage": "before_payment"},
    "honest": {"files": ["honest-chat.png"], "stage": "before_payment"},
    "victim": {
        "files": ["voice-victim.ogg", "receipt.png"],
        "stage": "after_payment",
        "story": "मैले फेसबुकको Nepal Shoes Corner पेजबाट जुत्ता मगाएँ। पैसा तिरें तर सामान आएन र फोन उठाउँदैनन्।",
    },
}
TYPES = {".ogg": "audio/ogg", ".png": "image/png"}


def record(name: str, spec: dict, client: httpx.Client) -> dict:
    files = []
    for fname in spec["files"]:
        path = ASSETS / fname
        field = "audios" if path.suffix == ".ogg" else "images"
        files.append((field, (fname, path.read_bytes(), TYPES.get(path.suffix) or mimetypes.guess_type(fname)[0])))
    events, result, start = [], None, time.time()
    with client.stream("POST", f"{API}/api/analyze/stream", data={"text": "", "stage": spec["stage"]}, files=files) as res:
        res.raise_for_status()
        event = None
        for line in res.iter_lines():
            if line.startswith("event: "):
                event = line[7:].strip()
            elif line.startswith("data: "):
                data = json.loads(line[6:])
                if event == "progress":
                    events.append({"t": round(time.time() - start, 2), **data})
                elif event == "result":
                    result = data
                elif event == "error":
                    raise RuntimeError(f"{name}: {data}")
    if result is None or result.get("engine") != "gemma":
        raise RuntimeError(f"{name}: no Gemma result")
    print(f"{name}: {len(events)} events in {events[-1]['t'] if events else 0}s, level {result['overall']['level']}")
    rec = {"files": spec["files"], "stage": spec["stage"], "events": events, "result": result,
           "recorded_at": time.strftime("%Y-%m-%d %H:%M")}
    rec["agent"] = client.post(f"{API}/api/agent", json={"analysis": result}, timeout=180).raise_for_status().json()
    print(f"  agent: {len(rec['agent']['scripts'])} scripts, searches {rec['agent']['trace']}")
    if spec["stage"] == "after_payment":
        rec["petition"] = client.post(
            f"{API}/api/petition/draft", json={"analysis": result, "user_story_ne": spec.get("story", "")}, timeout=180
        ).raise_for_status().json()
        print("  petition draft recorded")
    return rec


def main() -> None:
    out = {}
    with httpx.Client(timeout=240) as client:
        for name, spec in SCENARIOS.items():
            out[name] = record(name, spec, client)
            time.sleep(8)  # stay under the free tier's per-minute limit
    path = ASSETS / "recordings.json"
    path.write_text(json.dumps(out, ensure_ascii=False), encoding="utf-8")
    print(f"wrote {path} ({path.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
