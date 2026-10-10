"""Run every case in "test data/cases.yaml" against a running Sajag server and check the results.

    python backend/run.py                       # in another terminal
    python scripts/run_test_data.py             # all cases
    python scripts/run_test_data.py 03 11       # only cases whose id starts with these prefixes

Writes "test data/results/<case>.json" and "test data/results/summary.md".
"""

from __future__ import annotations

import json
import mimetypes
import re
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import httpx
import yaml

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "test data"
RESULTS = DATA / "results"
API = "http://127.0.0.1:8000"
CONTENT_TYPES = {".m4a": "audio/mp4", ".ogg": "audio/ogg", ".wav": "audio/wav"}


def content_type(path: Path) -> str:
    return CONTENT_TYPES.get(path.suffix) or mimetypes.guess_type(path.name)[0] or "application/octet-stream"


def run_case(case: dict, client: httpx.Client) -> dict:
    files = []
    for rel in case.get("images", []):
        p = DATA / rel
        files.append(("images", (p.name, p.read_bytes(), content_type(p))))
    for rel in case.get("audio", []):
        p = DATA / rel
        files.append(("audios", (p.name, p.read_bytes(), content_type(p))))
    text = case.get("text", "")
    if case.get("text_file"):
        text = (DATA / case["text_file"]).read_text(encoding="utf-8")

    start = time.time()
    res = client.post(f"{API}/api/analyze", data={"text": text, "stage": case["stage"]}, files=files or None)
    elapsed = time.time() - start
    if res.status_code != 200:
        return dict(case=case, ok=False, problems=[f"HTTP {res.status_code}: {res.text[:200]}"], seconds=elapsed)
    body = res.json()
    problems = check(case["expect"], body)

    complaint = None
    if case["expect"].get("complaint"):
        c = client.post(f"{API}/api/complaint", json={
            "analysis": body, "recipient": "bank", "bank_name": "PaisaPay Wallet",
            "complainant": {"name": "Test User", "address": "Kathmandu", "phone": "9800000000"},
            "user_story_ne": "मैले अनलाइनबाट जुत्ता मगाएँ, पैसा तिरें तर सामान आएन।",
            "amount_paid": "3200", "transaction_ref": "TXN-7Q4K-2291"})
        if c.status_code != 200:
            problems.append(f"complaint HTTP {c.status_code}")
        else:
            complaint = c.json()["text_ne"]
            if "TXN-7Q4K-2291" not in complaint or "३२००" not in complaint:
                problems.append("complaint draft is missing the transaction ID or amount")

    RESULTS.mkdir(exist_ok=True)
    (RESULTS / f"{case['id']}.json").write_text(
        json.dumps({"elapsed_s": round(elapsed, 1), "analysis": body, "complaint_ne": complaint},
                   ensure_ascii=False, indent=2), encoding="utf-8")
    return dict(case=case, ok=not problems, problems=problems, seconds=elapsed, body=body)


def check(exp: dict, body: dict) -> list[str]:
    problems = []
    grounded = [s for s in body["signals"] if s["grounded"]]
    flagged = {s["pattern_id"] for s in grounded}
    level = body["overall"]["level"]
    if body["engine"] != "gemma":
        problems.append(f"engine={body['engine']} (Gemma did not run): {body['warnings']}")
    if "level_in" in exp and level not in exp["level_in"]:
        problems.append(f"level={level}, expected {exp['level_in']}")
    if missing := set(exp.get("must_flag", [])) - flagged:
        problems.append(f"missed {sorted(missing)}")
    if wrong := set(exp.get("must_not_flag", [])) & flagged:
        problems.append(f"false alarm {sorted(wrong)}")
    if "max_signals" in exp and len(grounded) > exp["max_signals"]:
        problems.append(f"{len(grounded)} signals, expected at most {exp['max_signals']}: {sorted(flagged)}")
    if "min_events" in exp and len(body["events"]) < exp["min_events"]:
        problems.append(f"{len(body['events'])} events, expected >= {exp['min_events']}")
    if "qr_payee" in exp and exp["qr_payee"] not in [q["payee_name"] for q in body["qr"]]:
        problems.append(f"QR payee {exp['qr_payee']!r} not read (got {[q['payee_name'] for q in body['qr']]})")
    if "qr_crc_valid" in exp and exp["qr_crc_valid"] not in [q["crc_valid"] for q in body["qr"]]:
        problems.append(f"QR checksum validity {exp['qr_crc_valid']} not reported")
    for pattern in exp.get("transcript_contains", []):
        audio_text = " ".join(s["transcript"] for s in body["sources"] if s["kind"] == "audio")
        if not re.search(pattern, audio_text):
            problems.append(f"voice transcript lacks /{pattern}/")
    return problems


def main() -> int:
    cases = yaml.safe_load((DATA / "cases.yaml").read_text(encoding="utf-8"))
    if prefixes := sys.argv[1:]:
        cases = [c for c in cases if c["id"].startswith(tuple(prefixes))]
    with httpx.Client(timeout=180) as client, ThreadPoolExecutor(max_workers=3) as pool:
        results = list(pool.map(lambda c: run_case(c, client), cases))

    lines = ["| Case | Result | Level | Grounded signals | Time | Problems |", "|---|---|---|---|---|---|"]
    for r in results:
        body = r.get("body") or {}
        signals = ", ".join(sorted({s["pattern_id"] for s in body.get("signals", []) if s["grounded"]})) or "—"
        level = body.get("overall", {}).get("level", "—")
        status = "PASS" if r["ok"] else "FAIL"
        lines.append(f"| {r['case']['id']} | {status} | {level} | {signals} | {r['seconds']:.0f}s | "
                     f"{'; '.join(r['problems']) or ''} |")
        print(f"{status}  {r['case']['id']:<34} {level:<12} {r['seconds']:>5.0f}s  {'; '.join(r['problems'])}")
    passed = sum(r["ok"] for r in results)
    summary = f"**{passed}/{len(results)} passed**\n\n" + "\n".join(lines) + "\n"
    RESULTS.mkdir(exist_ok=True)
    (RESULTS / "summary.md").write_text(summary, encoding="utf-8")
    print(f"\n{passed}/{len(results)} passed — details in {RESULTS}")
    return 0 if passed == len(results) else 1


if __name__ == "__main__":
    raise SystemExit(main())
