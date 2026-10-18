---
name: react-zustand-e2e-playwright
description: Use when verifying a React app by actually driving it in a browser — a smoke test after a change, logging in as each role/persona, screenshotting screens for visual review, catching blank pages and console errors, diagnosing a page that renders nothing, or adding end-to-end checks to CI. Trigger on "playwright", "e2e", "end-to-end", "smoke test", "screenshot", "blank page", "console errors", "check it in the browser".
---

# End-to-End Verification with Playwright

A green build proves the code compiles. It does not prove the login works, the
route renders, or the page is not blank because a lazy import threw. Unit tests
(`react-zustand-testing`) cover store logic; this skill covers "does the app work
when a person uses it".

Three scripts, each with one job:

| Script | Job | When |
|---|---|---|
| `scripts/smoke.py` | Log in, walk key routes, assert headings, fail on any page/console error | Every change, before "done" |
| `scripts/capture_screens.py` | Screenshot every route per persona → `artifacts/screens/` | Visual changes, RTL, demos |
| `scripts/diagnose_<symptom>.py` | One-off probe for a specific bug | When a bug appears |

Python Playwright is used so the scripts need no Node test runner config; a
`@playwright/test` version is equally valid if the project already has one.

## Setup

```bash
py -m pip install playwright          # or: pip install playwright
py -m playwright install chromium
```

```json
// package.json
"scripts": {
  "smoke": "python scripts/smoke.py",
  "screens": "python scripts/capture_screens.py"
}
```

Both scripts expect the dev server (`npm run dev`) or a preview build
(`npm run build && npm run preview`) to be running; `APP_URL` overrides the
default `http://127.0.0.1:5173`.

## The smoke script

Full template: `templates/smoke.py.tpl`. The essential parts:

```python
errors = []
page.on("pageerror", lambda e: errors.append(f"pageerror: {e}"))
page.on("console", lambda m: errors.append(f"console: {m.text}")
        if m.type == "error" and "Failed to load resource" not in m.text else None)

page.goto(f"{APP_URL}/login", wait_until="networkidle")
page.locator('input[type="email"]').fill(EMAIL)
page.locator('input[type="password"]').fill(PASSWORD)
page.get_by_role("button", name=re.compile(r"sign in|log in", re.I)).click()
page.wait_for_url(re.compile(r".*/(dashboard|overview)$"))

for path, heading in ROUTES:
    page.goto(f"{APP_URL}{path}", wait_until="networkidle")
    expect(page.get_by_role("heading", name=heading)).to_be_visible()

if errors:
    print("\n".join(errors)); sys.exit(1)
```

Rules:

- **Collect page errors and console errors, and fail on them.** Most "blank page"
  bugs are an uncaught render error that only shows in the console.
- **Assert a heading per route**, by role and accessible name — it proves the lazy
  chunk loaded and the page rendered, and doubles as an accessibility check.
- **Start from a clean state**: `context.add_init_script("localStorage.clear();")`
  so a persisted session from the last run does not skip the login path.
- **One happy path through a mutation** (create → appears in list) catches the
  service/store wiring that headings do not.
- Exit non-zero on failure so CI and agents can trust the result.

## Per-persona screenshots

Full template: `templates/capture_screens.py.tpl`.

- A `PERSONAS` list: slug, email, and the routes that persona should see.
- **Reuse one browser context** and log out between personas. Creating a new
  context per persona against the Vite dev server can stall on the HMR WebSocket
  teardown.
- Name files `{persona}-{nn}-{route}.png` so a folder listing reads as a storyboard.
- Include an RTL persona when the app is bilingual, and a persona with minimal
  permissions — their screenshots prove the nav and actions are gated.
- **Look at the screenshots.** Writing them is not reviewing them.

## Diagnosis scripts

When a page misbehaves, write a 30-line probe instead of guessing:

```python
# scripts/diagnose_blank_page.py
page.on("console", lambda m: print(f"[{m.type}] {m.text}"))
page.on("pageerror", lambda e: print(f"[pageerror] {e}"))
page.on("requestfailed", lambda r: print(f"[failed] {r.method} {r.url} {r.failure}"))
page.on("response", lambda r: print(f"[{r.status}] {r.url}") if r.status >= 400 else None)
page.goto(f"{APP_URL}{TARGET}", wait_until="networkidle")
print(page.locator("#root").inner_html()[:2000])
page.screenshot(path="artifacts/diagnose.png", full_page=True)
```

It answers the three questions every blank-page bug reduces to: did a request
fail, did render throw, and what is actually in `#root`. Delete it once the bug is
fixed, or keep it under `scripts/` if the symptom recurs.

## In CI

```yaml
- run: npm ci && npm run build
- run: npx vite preview --port 5173 &
- run: pip install playwright && python -m playwright install --with-deps chromium
- run: VITE_USE_MOCKS=true python scripts/smoke.py
```

Run against the mock build (`react-zustand-mock-api`) so CI does not depend on a
live backend, and upload `artifacts/screens/` as a build artifact.

## Pitfalls

- **Asserting with `wait_for_timeout`** — slow machines fail, fast ones pass
  without checking anything. Wait for a URL, a role, or `networkidle`.
- **CSS-selector assertions** (`.MuiBox-root > div:nth-child(3)`) — break on every
  style change. Use roles, labels, and visible text.
- **Ignoring console errors** — the most common blank-page cause goes unreported.
- **Leaving a persisted session** — the login path is never tested.
- **Screenshots nobody opens** — visual regressions ship anyway.
- **Smoke tests that need production data** — flaky and unsafe; use mocks or a
  seeded test account.

## Related skills

- `react-zustand-testing` — unit tests for stores and components; this skill is
  the layer above.
- `react-zustand-mock-api` — personas and deterministic data for stable runs.
- `react-zustand-debugging` — what to do with what the diagnosis script shows.
- `react-zustand-project-workflow` — the definition of done this gate enforces.
- `react-zustand-i18n-rtl` — screenshotting both directions.
- `react-zustand-3d-scenes` — screenshotting a WebGL canvas headless.
