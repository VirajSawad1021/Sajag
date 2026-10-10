"""Run Sajag on the labelled cases and report how many pass.

    python evals/run_eval.py            # uses Gemma (needs GEMINI_API_KEY + GEMMA_MODEL in .env)
    SAJAG_MOCK=1 python evals/run_eval.py   # offline keyword baseline, for comparison

Report both numbers honestly. Honest-seller cases matter as much as scam cases: they measure false alarms.
"""

from __future__ import annotations

import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "backend"))

from app.analysis import analyze  # noqa: E402


def main() -> int:
    cases = yaml.safe_load((ROOT / "evals" / "cases.yaml").read_text(encoding="utf-8"))
    passed = 0
    engine = "?"
    for case in cases:
        result = analyze(case["text"], [], case.get("stage", "before_payment"))
        engine = result.engine
        flagged = {s.pattern_id for s in result.signals if s.grounded}
        exp = case["expected"]
        problems = []
        if result.overall.level not in exp.get("level_in", [result.overall.level]):
            problems.append(f"level={result.overall.level}, expected one of {exp['level_in']}")
        if missing := set(exp.get("must_flag", [])) - flagged:
            problems.append(f"missed {sorted(missing)}")
        if wrong := set(exp.get("must_not_flag", [])) & flagged:
            problems.append(f"false alarm {sorted(wrong)}")
        ungrounded = sum(1 for s in result.signals if not s.grounded)
        if ungrounded:
            problems.append(f"{ungrounded} ungrounded quote(s)")
        ok = not problems
        passed += ok
        print(f"{'PASS' if ok else 'FAIL'}  {case['id']:<28} [{case['lang']}]  {'; '.join(problems)}")
    print(f"\n{passed}/{len(cases)} passed  (engine: {engine})")
    return 0 if passed == len(cases) else 1


if __name__ == "__main__":
    raise SystemExit(main())
