"""Loads the community-maintained pattern files, stage steps and official resources."""

from __future__ import annotations

from functools import lru_cache

import yaml

from .config import DATA_DIR, PATTERNS_DIR

REQUIRED_PATTERN_KEYS = {"id", "severity", "title_en", "title_ne", "description", "next_steps"}


@lru_cache
def patterns() -> dict[str, dict]:
    out: dict[str, dict] = {}
    for path in sorted(PATTERNS_DIR.glob("*.yaml")):
        data = yaml.safe_load(path.read_text(encoding="utf-8"))
        missing = REQUIRED_PATTERN_KEYS - data.keys()
        if missing:
            raise ValueError(f"{path.name} is missing {sorted(missing)}")
        if data["id"] != path.stem:
            raise ValueError(f"{path.name}: id must match the file name")
        out[data["id"]] = data
    return out


@lru_cache
def stage_steps() -> dict[str, list[dict]]:
    return yaml.safe_load((DATA_DIR / "stage_steps.yaml").read_text(encoding="utf-8"))


@lru_cache
def resources() -> list[dict]:
    return yaml.safe_load((DATA_DIR / "resources.yaml").read_text(encoding="utf-8"))
