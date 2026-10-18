# react-zustand-skill

A [Claude Code plugin](https://code.claude.com/docs/en/plugins-reference) bundling a family of **24 focused skills** for building React SPAs with Vite, Zustand, react-router, axios, and CSS Modules — from project planning and mock-first development through real-time, Arabic/RTL, Playwright verification, and Three.js 3D views — plus a convention-review agent, a feature-scaffolding command, and an eslint-fix-on-edit hook. Each skill lives in `skills/react-zustand-<name>/` with a `SKILL.md` and triggers independently based on the task at hand; no single skill tries to cover everything.

These are not textbook React conventions. They were **extracted from a shipped production admin dashboard** — roughly 34,000 lines across 171 files, 55 lazy-loaded pages, 24 services, 15 stores, 10 UI primitives, 37 CSS modules — and then corrected where that codebase got it wrong. `skills/react-zustand-core/references/extraction-notes.md` tags every convention as **verified**, **corrected**, or **recommended** so a reader can tell a field-proven pattern from a sound default.

## Install

The repo is its own single-plugin marketplace, so installing it takes two lines
from anywhere — no clone, no path:

```
claude plugin marketplace add kareemalkassem/react-zustand-skill
claude plugin install react-zustand@react-zustand-marketplace
```

Or interactively inside Claude Code: `/plugin marketplace add kareemalkassem/react-zustand-skill`
then `/plugin install react-zustand`.

Install it **once per machine** and it is available in every React project you
open — the skills trigger on the task, not on the repo you happen to be in.

### Using it

Nothing to invoke. Once installed, the skills fire on their own triggers:

| You say | What loads |
|---|---|
| "add a products section" | `feature-template` → scaffolds service + store + pages + route |
| "why does this page re-render constantly" | `debugging` + `performance` |
| "wire up login" | `auth-session` + `networking` |
| "review this" (after a change) | the `react-reviewer` agent |
| "start a new admin dashboard" | `project-workflow` → planning docs, milestones, definition of done |
| "there is no backend yet" | `mock-api` |
| "make the queue update live" | `realtime` |
| "add Arabic" / "fix RTL" | `i18n-rtl` |
| "check it in the browser" / "smoke test" | `e2e-playwright` |
| "add a 3D product viewer" | `3d-scenes` + `3d-assets` |
| anything touching `store/`, `services/`, `pages/` | `core`, always-on |

Explicit entry points when you want them:

```
/react-feature orders            # scaffold a whole module
/react-feature coupons --read-only
```

### Updating

```
claude plugin marketplace update react-zustand-marketplace
claude plugin install react-zustand@react-zustand-marketplace
```

### Verify it took

`/plugin` lists installed plugins; `react-zustand` should show 24 skills, one
agent, and one command.

## The prescribed stack

```
React 19 · Vite 7 · react-router-dom 7 · zustand 5 (+persist) · axios
CSS Modules + CSS custom properties · clsx · lucide-react
react-hot-toast · nprogress · Vitest + React Testing Library
```

No Tailwind, no styled-components. One styling system per project is a hard rule — the mixed-system drift it prevents is documented in `react-zustand-design-tokens`.

## The architecture in four rows

Every skill in this family is a detail of one of these boundaries.

| Layer | Owns | May never contain |
|---|---|---|
| `pages/` + `components/` | Rendering, local UI state, user intent | `axios`, response shaping, business rules |
| `store/` | Shared state, actions, loading/error flags | JSX, `axios`, `toast` |
| `services/` | One function per endpoint, returns domain data | State, JSX, `toast`, retry policy |
| `services/api.js` | Auth header, locale headers, progress, global 401/403/5xx | Anything module-specific |

Plus one contract that most codebases leave implicit: **reads swallow into `error`, writes throw.**

## What the plugin ships

| Component | What it does |
|---|---|
| `skills/` (24) | The react-zustand skill family — see table below |
| `agents/react-reviewer.md` | Subagent that reviews a React diff against these conventions (boundaries, selectors, error contract, styling drift) with 🔴🟠🟡🔵 severities |
| `commands/react-feature.md` | `/react-feature <name>` — scaffolds service + store + list page + form page + styles + route via the feature-template skill |
| `hooks/hooks.json` | PostToolUse hook: runs `eslint --fix` on any JS/JSX file Claude edits (never blocks) |
| `scripts/validate-skills.mjs` | Zero-dependency repo validator: frontmatter, cross-references, dead links, README skill-count and table |

## Skills

| Skill | Triggers on |
|---|---|
| [`react-zustand-core`](skills/react-zustand-core/SKILL.md) | Any React+Zustand task — the four boundaries, folder layout, the service/store/page triad, the read/write error contract. Always-on. |
| [`react-zustand-networking`](skills/react-zustand-networking/SKILL.md) | The axios instance — interceptors, auth and locale headers, global 401/403/5xx, service wrappers, FormData, blobs, cancellation. |
| [`react-zustand-state`](skills/react-zustand-state/SKILL.md) | Store shape, actions, `persist`/`partialize`, `useShallow`, cross-store access, when *not* to create a store. |
| [`react-zustand-routing`](skills/react-zustand-routing/SKILL.md) | Route tree, guard routes, `Outlet` layouts, `lazy()`+`Suspense`, and the URL as filter state. |
| [`react-zustand-ui-conventions`](skills/react-zustand-ui-conventions/SKILL.md) | Where a component belongs, the `ui/` barrel, `clsx(styles[variant])`, compound components, the five data states. |
| [`react-zustand-design-tokens`](skills/react-zustand-design-tokens/SKILL.md) | `variables.css`, CSS Modules, theming, and the one-styling-system rule. |
| [`react-zustand-auth-session`](skills/react-zustand-auth-session/SKILL.md) | Login, logout, session restore on reload, token storage, roles, global 401. |
| [`react-zustand-permissions`](skills/react-zustand-permissions/SKILL.md) | Fine-grained gating — permission store, route wrapper, action gating, 403 inference and its drift risk. |
| [`react-zustand-data-tables`](skills/react-zustand-data-tables/SKILL.md) | List pages — search debounce, filters, pagination, sorting, bulk selection, skeletons, empty/error states. |
| [`react-zustand-forms-validation`](skills/react-zustand-forms-validation/SKILL.md) | Controlled forms, client validators, mapping a backend 422 to field errors, dirty guards. |
| [`react-zustand-assets-media`](skills/react-zustand-assets-media/SKILL.md) | Image URL resolution, upload validation, previews, FormData, downloads, Vite static assets. |
| [`react-zustand-feature-template`](skills/react-zustand-feature-template/SKILL.md) | "Create a new feature" — full service+store+page+styles+route scaffold with `.tpl` templates. |
| [`react-zustand-testing`](skills/react-zustand-testing/SKILL.md) | Vitest + RTL setup, testing store actions, mocking the axios instance, the 422 path, fake timers. |
| [`react-zustand-performance`](skills/react-zustand-performance/SKILL.md) | Re-render diagnosis, selector scoping, Vite chunking, long lists, images, profiling. |
| [`react-zustand-gotchas`](skills/react-zustand-gotchas/SKILL.md) | The consolidated 78-entry anti-pattern list. Read before a review or a refactor. |
| [`react-zustand-api-contract`](skills/react-zustand-api-contract/SKILL.md) | Frontend/backend drift — parity scripting, mirrored enums, generating services from a spec. |
| [`react-zustand-debugging`](skills/react-zustand-debugging/SKILL.md) | Symptom decision trees — render loops, stale stores, 401 loops, blank pages, dev-vs-prod breaks. |
| [`react-zustand-project-workflow`](skills/react-zustand-project-workflow/SKILL.md) | New project order of work — FOUNDATION / EXECUTION_PLAN / TRACKER / CLAUDE.md templates, milestones, bottom-up wiring, definition of done. |
| [`react-zustand-mock-api`](skills/react-zustand-mock-api/SKILL.md) | Mock-first development — an axios adapter returning the real envelope, seed data, personas, latency, 403/422, switching to the real backend. |
| [`react-zustand-realtime`](skills/react-zustand-realtime/SKILL.md) | Live screens — subscription contract, store `connect`/`disconnect`, resync on reconnect, stale indicator, Reverb/Echo, polling. |
| [`react-zustand-i18n-rtl`](skills/react-zustand-i18n-rtl/SKILL.md) | Locale store, `dir` on `<html>`, translation keys, logical CSS properties, `Intl` formatting, locale header. |
| [`react-zustand-e2e-playwright`](skills/react-zustand-e2e-playwright/SKILL.md) | Driving the app — smoke script, per-persona screenshots, blank-page diagnosis, CI. Ships `.tpl` scripts. |
| [`react-zustand-3d-scenes`](skills/react-zustand-3d-scenes/SKILL.md) | Three.js / React Three Fiber — canvas setup, store vs frame loop, performance rules, WebGL vs WebGPU, accessibility, verification. |
| [`react-zustand-3d-assets`](skills/react-zustand-3d-assets/SKILL.md) | GLB pipeline — export, `gltf-transform` inspect and targeted compression, `gltfjsx`, decoders, caching, budgets. |

## Design

- **`react-zustand-core` stays small** because it fires on nearly every prompt; everything else triggers narrowly on its own concern and is loaded only when relevant.
- Skills cross-reference each other by name rather than duplicating content — `core` points at `gotchas` for the full anti-pattern list, at `networking` for interceptor detail, and so on.
- `feature-template`, `testing`, `project-workflow`, and `e2e-playwright` ship `.tpl` placeholder files under `templates/` for scaffold generation.
- Findings from the source codebase are marked **[observed]** in `gotchas` so a real defect is distinguishable from a hypothetical one.

## Validating

```
node scripts/validate-skills.mjs
claude plugin validate .
```

The first checks frontmatter, cross-references, dead links, and that this README's skill count and table match the folders. Both must pass before committing.

## Extending

Adding a skill: keep the `react-zustand-*` prefix under `skills/`, write a specific (not broad) trigger description, cross-reference it from `react-zustand-core`'s "Related skills" section so it is discoverable from the entry point, and add a row to the table above. Repo workflow rules live in [`CLAUDE.md`](CLAUDE.md).
