"""Start Sajag (app + API) on one port. Reads GEMINI_API_KEY and GEMMA_MODEL from .env.

    python backend/run.py           (from the repo root, or anywhere)
"""

import os
import sys
from pathlib import Path

os.environ.setdefault("SAJAG_MOCK", "0")
sys.path.insert(0, str(Path(__file__).resolve().parent))

import uvicorn  # noqa: E402

if __name__ == "__main__":
    # SAJAG_HOST=0.0.0.0 lets a phone on the same Wi-Fi reach this laptop (Windows may ask to allow it).
    uvicorn.run("app.main:app", host=os.getenv("SAJAG_HOST", "127.0.0.1"), port=int(os.getenv("PORT", "8000")))
