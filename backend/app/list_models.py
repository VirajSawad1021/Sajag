"""List Gemma models available to your Gemini API key.

Usage (from backend/):  python -m app.list_models
"""

from google import genai

from .config import GEMINI_API_KEY


def main() -> None:
    if not GEMINI_API_KEY:
        raise SystemExit("Set GEMINI_API_KEY in .env first.")
    client = genai.Client(api_key=GEMINI_API_KEY)
    for model in client.models.list():
        if "gemma" in model.name.lower():
            print(model.name)


if __name__ == "__main__":
    main()
