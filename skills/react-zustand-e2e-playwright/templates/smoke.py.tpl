"""
Smoke test: log in, walk the key routes, fail on any page or console error.

Usage:  python scripts/smoke.py        (dev server or preview must be running)
Env:    APP_URL, SMOKE_EMAIL, SMOKE_PASSWORD
"""

import os
import re
import sys

from playwright.sync_api import expect, sync_playwright

APP_URL = os.environ.get("APP_URL", "http://127.0.0.1:5173")
EMAIL = os.environ.get("SMOKE_EMAIL", "{{admin@app.test}}")
PASSWORD = os.environ.get("SMOKE_PASSWORD", "{{demo1234}}")
HOME_URL = re.compile(r".*/{{dashboard}}$")

# (path, visible heading) — one entry per route the change touched, plus the home route
ROUTES = [
    ("/{{dashboard}}", "{{Dashboard}}"),
    ("/{{products}}", "{{Products}}"),
]


def main():
    errors = []

    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(headless=True)
        context = browser.new_context(viewport={"width": 1440, "height": 1000})
        context.add_init_script("localStorage.clear();")
        page = context.new_page()
        page.on("pageerror", lambda error: errors.append(f"pageerror: {error}"))
        page.on(
            "console",
            lambda message: errors.append(f"console: {message.text}")
            if message.type == "error" and "Failed to load resource" not in message.text
            else None,
        )

        page.goto(f"{APP_URL}/login", wait_until="networkidle")
        page.locator('input[type="email"]').fill(EMAIL)
        page.locator('input[type="password"]').fill(PASSWORD)
        page.get_by_role("button", name=re.compile(r"sign in|log in|login", re.I)).click()
        page.wait_for_url(HOME_URL)

        for path, heading in ROUTES:
            page.goto(f"{APP_URL}{path}", wait_until="networkidle")
            expect(page.get_by_role("heading", name=heading)).to_be_visible()

        browser.close()

    if errors:
        print("Smoke FAILED:")
        print("\n".join(errors))
        sys.exit(1)

    print(f"Smoke OK: login + {len(ROUTES)} routes, 0 errors")


if __name__ == "__main__":
    main()
