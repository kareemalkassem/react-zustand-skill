"""
Per-persona screenshots → artifacts/screens/{persona}-{nn}-{name}.png

One browser context is reused for every persona (log out between them):
new contexts against the Vite dev server can stall on HMR WebSocket teardown.
"""

import os
import re
from pathlib import Path

from playwright.sync_api import sync_playwright

APP_URL = os.environ.get("APP_URL", "http://127.0.0.1:5173")
PASSWORD = os.environ.get("SCREENS_PASSWORD", "{{demo1234}}")
OUT = Path("artifacts/screens")

PERSONAS = [
    {"slug": "admin", "email": "{{admin@app.test}}", "pages": [("dashboard", "/{{dashboard}}"), ("products", "/{{products}}")]},
    {"slug": "staff-ar", "email": "{{staff.ar@app.test}}", "pages": [("dashboard", "/{{dashboard}}")]},
]


def login(page, email):
    page.goto(f"{APP_URL}/login", wait_until="networkidle")
    page.locator('input[type="email"]').fill(email)
    page.locator('input[type="password"]').fill(PASSWORD)
    page.get_by_role("button", name=re.compile(r"sign in|log in|login", re.I)).click()
    page.wait_for_load_state("networkidle")


def logout(page):
    page.evaluate("localStorage.clear()")
    page.goto(f"{APP_URL}/login", wait_until="networkidle")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(headless=True)
        page = browser.new_context(viewport={"width": 1440, "height": 1000}).new_page()

        for persona in PERSONAS:
            login(page, persona["email"])
            for index, (name, path) in enumerate(persona["pages"], start=1):
                page.goto(f"{APP_URL}{path}", wait_until="networkidle")
                target = OUT / f"{persona['slug']}-{index:02d}-{name}.png"
                page.screenshot(path=str(target), full_page=True)
                print(f"saved {target}")
            logout(page)

        browser.close()


if __name__ == "__main__":
    main()
