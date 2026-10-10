"""Runtime settings, read from environment variables (or a .env file at the repo root)."""

import os
from pathlib import Path

from dotenv import load_dotenv

REPO_ROOT = Path(__file__).resolve().parents[2]
load_dotenv(REPO_ROOT / ".env")

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")
# Find the exact Gemma 4 model id with: python -m app.list_models
GEMMA_MODEL = os.getenv("GEMMA_MODEL", "")
# MINIMAL keeps answers fast; set empty to use the model default (much slower).
THINKING_LEVEL = os.getenv("GEMMA_THINKING_LEVEL", "MINIMAL")
# Speech-to-text model for voice notes (Gemma 4 on the API has no audio input).
ASR_MODEL = os.getenv("SAJAG_ASR_MODEL", "gemini-2.5-flash")
# Telegram bot token from @BotFather (python backend/bot.py)
TELEGRAM_BOT_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN", "")
# SAJAG_MOCK=1 skips the model and uses the offline keyword analyzer (for frontend work / no key).
MOCK_MODE = os.getenv("SAJAG_MOCK", "0") == "1"

PATTERNS_DIR = REPO_ROOT / "patterns"
DATA_DIR = REPO_ROOT / "data"
FRONTEND_DIST = REPO_ROOT / "frontend" / "dist"

MAX_IMAGES = 6
MAX_IMAGE_BYTES = 8 * 1024 * 1024
MAX_TEXT_CHARS = 20_000
MAX_AUDIO = 3
MAX_AUDIO_BYTES = 15 * 1024 * 1024
MAX_AUDIO_SECONDS = 120
