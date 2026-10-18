# Extraction notes — where these conventions come from

This skill family was not written from general React knowledge. It was extracted
from a shipped production React admin dashboard (React 19 · Vite 7 · Zustand 5 ·
react-router-dom 7 · axios · CSS Modules) — roughly 34,000 lines across 171 source
files: 55 lazy-loaded pages, 24 services, 15 stores, 10 UI primitives, 37 CSS
modules.

The rules below are tagged so a future reader can tell a verified pattern from a
recommended one, and can re-check the verified ones instead of taking them on
faith.

## VERIFIED — observed working in the source codebase

| Convention | Evidence in the source |
|---|---|
| One axios instance owning token, locale headers, progress, 401/403/5xx | `services/api.js` — a single `axios.create` with one request and one response interceptor |
| Service returns the unwrapped envelope (`response.data.data`) | All 24 service files return `data.data`; no store touches an axios response |
| Role-aware base path resolved inside the service | `productService.getBasePath()` reads the auth store's role and returns `/seller/products` or `/admin/products`, letting one service serve two roles |
| `useShallow` on multi-field store selects | `pages/Products.jsx` selects eight fields through `useShallow`, avoiding a rerender per unrelated store write |
| Store shape `{ items, current, pagination, isLoading, error }` | Repeated across all 15 stores |
| `persist` + `partialize` on the auth store | `store/authStore.js` persists only `user`, `token`, `isAuthenticated` under key `auth-storage`; the request interceptor reads that same key |
| `clsx(styles.base, styles[variant], styles[size])` variant lookup | `components/ui/Button.jsx` — variant and size map directly to CSS-module class names, no conditional class strings |
| One `ui/index.js` barrel, no other barrels | `components/ui/index.js` re-exports nine primitives; `pages/` has none |
| Every route `lazy()` + a single `withSuspense` helper | `App.jsx` — 55 lazy imports, one shared `RouteFallback` |
| Nested guard routes via `<Outlet />` | `App.jsx` — `ProtectedRoute` → `Layout` → `AdminRoute` / `SellerRoute` |
| Permission grants inferred from successful responses | `api.js` response interceptor calls `markGranted(perm)` on 2xx; 403 calls `markMissing(...)` using `required_permissions` from the body |
| URL as filter state | `pages/Products.jsx` reads `useSearchParams` for `search`/`category`/`page`, writes back with `{ replace: true }` |
| Debounced fetch in a `useEffect` with cleanup | `pages/Products.jsx` — 500 ms `setTimeout`, cleared on dep change |
| Design tokens in one `:root` block | `styles/variables.css` — 174 lines of `--color-*`, `--space-*`, `--radius-*`, `--shadow-*`, `--transition-*`, `--z-index-*` |
| Field-error extraction from a Laravel-style 422 | `utils/apiError.js` — `extractApiErrorMessage` walks `errors` → `error` → `message`; `extractFieldErrors` flattens `field.0` keys to `field` |
| Image URL normalization through a file proxy | `utils/imageUtils.js` — passes absolute URLs through, otherwise rewrites to `/api/file/public/...` |
| Frontend/backend route parity as a script | `scripts/api-parity-check.js` — parses the backend route file and diffs it against URLs found in `services/` |
| Manual vendor chunking in Vite | `vite.config.js` — `manualChunks` splits `xlsx`, `qrcode.react`, `date-fns` out of the main vendor bundle |

## CORRECTED — the source got this wrong, the skill prescribes the fix

These are real defects found during extraction. The skill documents the fix, not
the source behavior.

| Defect in the source | What the skill prescribes instead |
|---|---|
| Two styling systems: 37 CSS modules + `variables.css`, **and** Tailwind with an empty `theme.extend` used ad hoc in `App.jsx` / `RequirePermission.jsx`. Tailwind classes could not reference the tokens, so every Tailwind usage hardcoded a color. | CSS Modules + `variables.css` only. No Tailwind. `react-zustand-design-tokens` |
| Design docs claimed primary `#4f46e5` and Inter/Outfit while `variables.css` had `#f59f00` and Space Grotesk — generated code shipped the wrong brand. | Tokens are the single source; docs quote the token name, never the literal value. `react-zustand-design-tokens` |
| Store actions inconsistent: `fetchProducts` swallowed, `addProduct` rethrew, with no stated rule. | The read/write error contract: reads swallow into `error`, writes throw. `react-zustand-core` |
| Pagination envelope unwrapped inside the store, with a comment citing the backend PHP class. | Unwrap in the service. `react-zustand-core` |
| Pages up to 1,106 lines; one custom hook for 55 pages. | Split past ~300 lines; derived data goes in a `useMemo` hook. `react-zustand-data-tables` |
| Permission catalog hardcoded as 44 strings in the store, discovered by firing probe requests and reading 403s. | Prefer a permissions list returned by the login response; probing is the documented fallback with its drift risk stated. `react-zustand-permissions` |
| No tests, no test runner in `package.json`. | Vitest + RTL from the start. `react-zustand-testing` |

## v1.1 sources — workflow, mock-first, real-time, RTL, verification

Version 1.1 added seven skills. Their verified rows come from two further
codebases by the same team, reviewed 2026-10-18:

- **Carlton staff dashboard** — a mock-first hotel operations dashboard
  forked from the source above (Vite 7, React 19, Zustand 5, 23 pages, 18
  services, 18 stores), bilingual English/Arabic.
- **Scouts** — an earlier Next.js 15 + Django REST app (JWT auth, CRUD with file
  uploads), public at github.com/KhalilArabiKatbi/Scouts.

### VERIFIED

| Convention | Evidence |
|---|---|
| Planning docs before code: FOUNDATION (spec + envelope + tokens), EXECUTION_PLAN (milestones with "Done when"), TRACKER (T-001… with acceptance criteria) | Carlton root `CARLTON_DASHBOARD_FOUNDATION.md`, `_EXECUTION_PLAN.md`, `_TRACKER.md` |
| App-level CLAUDE.md with a reference-codebase table of inherited vs deliberately different areas | Carlton `dashboard/CLAUDE.md` "CartX Reference" section |
| Mock layer returning the real envelope `{success, message, data, request_id, error_code, errors}`, ~220 ms latency, `data.items` + `data.meta` pagination | Carlton `src/mocks/envelope.js` (`DEFAULT_MOCK_LATENCY_MS = 220`), `mockClient.js` |
| Seed personas, one per role, shared demo password, including Arabic-locale personas | Carlton `src/mocks/personas.js`, CLAUDE.md persona table |
| Real-time as `subscribe(cb) → unsubscribe`, owned by a store with idempotent `connect` / `disconnect`, plus a connection indicator | Carlton `src/mocks/realtime.js`, `store/queueStore.js`, `components/common/RealtimeIndicator.jsx` |
| `applyDocumentDirection()` setting `lang`/`dir` on `<html>`; `{ en, ar }` labels read with `pickLocalized` | Carlton `src/utils/i18n.js` |
| Python Playwright smoke script: login, route walk, heading asserts, page/console error collection | Carlton `scripts/smoke_carlton.py` |
| Per-persona screenshots reusing ONE context to avoid Vite HMR socket stalls | Carlton `scripts/capture_personas.py` docstring |
| One-off diagnosis scripts per symptom | Carlton `scripts/diagnose_blank_pages.py`, `diagnose_chart.py` |
| Client network errors reported to the backend via `fetch(..., { keepalive: true })` outside the interceptor | Source `services/api.js` `logClientError` → `/api/client-logs` |

### CORRECTED

| Defect observed | What the skills prescribe instead |
|---|---|
| API base `http://192.168.1.7:8000` hardcoded in components; changed, made dynamic and reverted in one day | One `VITE_API_URL` read only in `api.js` — gotcha 66 |
| Six `Revert "..."` commits on `main` for UI experiments within two weeks | Branch + screenshot check before merge — gotcha 67, `react-zustand-project-workflow` |
| Token decode and refresh inside a page HOC, axios called from components | Auth store + interceptor; pages read `isAuthenticated` — `react-zustand-auth-session` |
| Carlton chose a custom fetch client for the mock layer, diverging from the one-axios rule | Mock behind an axios adapter so interceptors run — `react-zustand-mock-api` |
| 20 of one contributor's 91 commits titled `.`, `fix`, `curr` or a name | Conventional commit messages — `react-zustand-project-workflow` |

### RECOMMENDED (3D)

`react-zustand-3d-scenes` and `react-zustand-3d-assets` are not extracted from a
codebase — none of the sources has 3D. They follow the official React Three
Fiber pitfalls, scaling-performance and v9 migration pages, the glTF Transform CLI
docs, and three@0.186.1 source (`WebGPURenderer` `forceWebGL`; `PostProcessing`
deprecated in r183 → `RenderPipeline`), all read 2026-10-18. Re-check versions
before relying on them.

## RECOMMENDED — general practice, not observed in the source

Everything not in the two tables above is standard React/Zustand practice applied
consistently: Vitest/RTL setup, the `hooks/` derived-data convention, list
virtualization thresholds, and the debugging decision trees. Treat these as sound
defaults rather than field-proven claims, and correct them against a real codebase
when one is available.
