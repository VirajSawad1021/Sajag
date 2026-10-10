"""Thin wrapper around Gemma 4 on the Gemini API."""

from __future__ import annotations

import json
import logging
import re
import threading
import time
from collections.abc import Callable

from google import genai
from google.genai import types

from .config import GEMINI_API_KEY, GEMMA_MODEL, THINKING_LEVEL


log = logging.getLogger("sajag.gemma")


class ModelError(RuntimeError):
    pass


_client: genai.Client | None = None
_client_lock = threading.Lock()


def _get_client() -> genai.Client:
    global _client
    if not GEMINI_API_KEY or not GEMMA_MODEL:
        raise ModelError("GEMINI_API_KEY and GEMMA_MODEL must be set (or run with SAJAG_MOCK=1).")
    # Locked: two threads creating clients at once would let one be garbage-collected (and closed) mid-request.
    with _client_lock:
        if _client is None:
            _client = genai.Client(api_key=GEMINI_API_KEY)
    return _client


def generate_json(
    prompt: str,
    images: list[tuple[bytes, str]],
    attempts: int = 3,
    on_text: Callable[[str], None] | None = None,
) -> dict:
    """Send images + prompt, return the parsed JSON object from the reply.

    With `on_text`, the reply is streamed and `on_text(text_so_far)` is called as it grows (for live progress).
    Retries transient failures (rate limits, 5xx, a malformed reply) with a short backoff."""
    parts: list = [types.Part.from_bytes(data=data, mime_type=mime) for data, mime in images]
    parts.append(prompt)
    config = types.GenerateContentConfig(
        temperature=0.1,
        # MINIMAL thinking: ~5x faster on Gemma 4 and still passes our evals.
        thinking_config=types.ThinkingConfig(thinking_level=THINKING_LEVEL) if THINKING_LEVEL else None,
    )
    last_error: Exception | None = None
    wait = 0.0
    for attempt in range(attempts):
        if attempt:
            time.sleep(wait or 2 * attempt)
        wait = 0.0
        try:
            if on_text is None:
                response = _get_client().models.generate_content(model=GEMMA_MODEL, contents=parts, config=config)
                return extract_json(response.text or "")
            text = ""
            for chunk in _get_client().models.generate_content_stream(model=GEMMA_MODEL, contents=parts, config=config):
                if chunk.text:
                    text += chunk.text
                    on_text(text)
            return extract_json(text)
        except ModelError as exc:  # unparseable reply: worth one more try
            last_error = exc
        except Exception as exc:  # network / quota / server errors
            last_error = ModelError(f"Gemma request failed: {exc}")
            wait = rate_limit_wait(str(exc))
        log.warning("Gemma attempt %d/%d failed: %s", attempt + 1, attempts, str(last_error)[:300])
    raise last_error  # type: ignore[misc]


def rate_limit_wait(message: str) -> float:
    """Seconds to wait after a 429 (the free tier limits requests per minute). Uses Google's retryDelay hint."""
    if "429" not in message and "RESOURCE_EXHAUSTED" not in message:
        return 0.0
    hint = re.search(r"retryDelay['\"]?\s*:\s*['\"]?(\d+(?:\.\d+)?)s", message)
    return min(float(hint.group(1)) + 1 if hint else 15.0, 30.0)


def extract_json(text: str) -> dict:
    """Pull the outermost {...} object out of a reply that may include ``` fences or chatter."""
    start, end = text.find("{"), text.rfind("}")
    if start == -1 or end <= start:
        raise ModelError("Model reply contained no JSON object.")
    try:
        return json.loads(text[start : end + 1])
    except json.JSONDecodeError as exc:
        raise ModelError(f"Model reply was not valid JSON: {exc}") from exc
