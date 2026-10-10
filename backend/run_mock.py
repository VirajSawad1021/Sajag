"""Start Sajag without an API key, using the offline keyword analyzer.

    python backend/run_mock.py      (from the repo root, or anywhere)
"""

import os
import sys
from pathlib import Path

os.environ["SAJAG_MOCK"] = "1"
sys.path.insert(0, str(Path(__file__).resolve().parent))

import uvicorn  # noqa: E402

if __name__ == "__main__":
    uvicorn.run("app.main:app", host="127.0.0.1", port=int(os.getenv("PORT", "8000")))
