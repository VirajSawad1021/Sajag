"""Drive the Flutter app's web build like a user, on a phone-sized screen, and screenshot every step.

    python backend/run.py                         # serves the API and the app at /app
    python scripts/ui_check_app.py [check] [recovery]   # screenshots -> "test data/results/ui/"

Uses Flutter's accessibility tree (semantics) to find buttons by their label, so it doesn't depend on pixel
positions. Runs a real analysis with Gemma, so it takes about a minute.
"""

from __future__ import annotations

import sys
import time
from pathlib import Path

from playwright.sync_api import Page, sync_playwright

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "test data" / "results" / "ui"
URL = "http://127.0.0.1:8000/app/"


def shot(page: Page, name: str) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    page.screenshot(path=str(OUT / f"{name}.png"), full_page=False)
    print("screenshot", name)


def tap(page: Page, label: str, timeout: float = 15) -> None:
    """Click the smallest *button* in Flutter's accessibility tree whose label or text contains `label`."""
    deadline = time.time() + timeout
    while time.time() < deadline:
        buttons = page.locator("flt-semantics[role='button']").filter(has_text=label)
        if not buttons.count():
            buttons = page.locator(f"flt-semantics[role='button'][aria-label*='{label}']")
        if not buttons.count():  # other tappables may not carry the button role
            buttons = page.locator(f"flt-semantics[aria-label*='{label}']")
        if not buttons.count():
            buttons = page.locator("flt-semantics").filter(has_text=label)
        if buttons.count():
            buttons.last.click()  # innermost match comes last in document order
            return
        page.wait_for_timeout(300)
    nodes = page.evaluate(
        "() => [...document.querySelectorAll('flt-semantics')].map(e => [e.getAttribute('role') || '', "
        "e.getAttribute('aria-label') || '', (e.textContent || '').slice(0, 50)].join(' | '))"
    )
    print("\n".join(n for n in nodes if n.strip(" |")))
    raise TimeoutError(f"no button with label containing {label!r}")


def wait_text(page: Page, text: str, timeout: float = 150) -> None:
    deadline = time.time() + timeout
    while time.time() < deadline:
        if page.locator(f"flt-semantics:has-text('{text}'), flt-semantics[aria-label*='{text}']").count():
            return
        page.wait_for_timeout(500)
    raise TimeoutError(f"text {text!r} never appeared")


def open_app(p, name: str):
    browser = p.chromium.launch(channel="chrome")
    ctx = browser.new_context(viewport={"width": 390, "height": 844}, device_scale_factor=2, locale="en-US")
    page = ctx.new_page()
    page.goto(URL)
    page.wait_for_timeout(4000)
    # Turn on Flutter's accessibility tree so buttons are findable by label.
    page.evaluate("document.querySelector('flt-semantics-placeholder')?.click()")
    page.wait_for_timeout(800)
    shot(page, f"{name}-01-home")
    tap(page, "Switch to English")  # stable English labels for the test
    page.wait_for_timeout(600)
    return browser, page


def scroll_shots(page: Page, names: list[str], step: int = 800) -> None:
    page.mouse.move(195, 500)
    for name in names:
        page.mouse.wheel(0, step)
        page.wait_for_timeout(900)
        shot(page, name)


def flow_check(p) -> None:
    """Before paying: scam chat + QR -> live analysis -> verdict, X-Ray, warnings, agent."""
    browser, page = open_app(p, "check")
    tap(page, "New check")
    page.wait_for_timeout(1200)
    shot(page, "check-02-new")
    tap(page, "COD")  # sample: COD -> advance + QR
    page.wait_for_timeout(800)
    tap(page, "Check it")
    page.wait_for_timeout(6000)
    shot(page, "check-03-live")
    wait_text(page, "Scam X-Ray")
    page.wait_for_timeout(2500)
    shot(page, "check-04-verdict")
    scroll_shots(page, ["check-05-xray", "check-06-warnings", "check-07-agent"])
    browser.close()


def flow_recovery(p) -> None:
    """After paying: voice note + receipt -> 'Act now' -> recovery plan -> Gemma fills the Cyber Bureau form."""
    browser, page = open_app(p, "recovery")
    tap(page, "New check")
    page.wait_for_timeout(1200)
    tap(page, "Paid, nothing came")  # voice-note + receipt sample, sets 'already paid'
    page.wait_for_timeout(1500)
    shot(page, "recovery-02-new")
    tap(page, "Check it")
    wait_text(page, "Act now")
    page.wait_for_timeout(2500)
    shot(page, "recovery-03-verdict")
    tap(page, "Start recovery")
    page.wait_for_timeout(2500)
    shot(page, "recovery-04-plan")
    scroll_shots(page, ["recovery-04b-plan"], step=600)
    # Step 5: Cyber Bureau application (collapse step 1 first so step 5 is on screen)
    page.mouse.wheel(0, 1500)
    page.wait_for_timeout(800)
    tap(page, "File with the Cyber Bureau")
    page.wait_for_timeout(1200)
    tap(page, "Cyber Bureau application")
    page.wait_for_timeout(1500)
    shot(page, "recovery-05-petition")
    tap(page, "Let Gemma fill it")
    page.wait_for_timeout(20000)  # Gemma fills the form (about 10 s)
    scroll_shots(page, ["recovery-06-filled", "recovery-07-filled", "recovery-08-filled", "recovery-09-filled",
                        "recovery-10-filled", "recovery-11-filled"], step=700)
    wait_text(page, "Make the PDF", timeout=10)
    browser.close()


def main() -> int:
    flows = {"check": flow_check, "recovery": flow_recovery}
    chosen = sys.argv[1:] or list(flows)
    with sync_playwright() as p:
        for name in chosen:
            print("== flow", name)
            flows[name](p)
    return 0


if __name__ == "__main__":
    sys.exit(main())
