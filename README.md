# react-zustand-skill

A [Claude Code plugin](https://code.claude.com/docs/en/plugins-reference) bundling a family of **17 focused skills** for building React SPAs with Vite, Zustand, react-router, axios, and CSS Modules — plus a convention-review agent, a feature-scaffolding command, and an eslint-fix-on-edit hook. Each skill lives in `skills/react-zustand-<name>/` with a `SKILL.md` and triggers independently based on the task at hand; no single skill tries to cover everything.

These are not textbook React conventions. They were **extracted from a shipped production admin dashboard** — roughly 34,000 lines across 171 files, 55 lazy-loaded pages, 24 services, 15 stores, 10 UI primitives, 37 CSS modules — and then corrected where that codebase got it wrong. `skills/react-zustand-core/references/extraction-notes.md` tags every convention as **verified**, **corrected**, or **recommended** so a reader can tell a field-proven pattern from a sound default.

## Install

The repo is its own single-plugin marketplace:

```
claude plugin marketplace add <path-or-github-url-to-this-repo>
claude plugin install react-zustand@react-zustand-marketplace
```

Or interactively inside Claude Code: `/plugin marketplace add …` then `/plugin install react-zustand`.

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
| `skills/` (17) | The react-zustand skill family — see table below |
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
| [`react-zustand-gotchas`](skills/react-zustand-gotchas/SKILL.md) | The consolidated 64-entry anti-pattern list. Read before a review or a refactor. |
| [`react-zustand-api-contract`](skills/react-zustand-api-contract/SKILL.md) | Frontend/backend drift — parity scripting, mirrored enums, generating services from a spec. |
| [`react-zustand-debugging`](skills/react-zustand-debugging/SKILL.md) | Symptom decision trees — render loops, stale stores, 401 loops, blank pages, dev-vs-prod breaks. |

## Design

- **`react-zustand-core` stays small** because it fires on nearly every prompt; everything else triggers narrowly on its own concern and is loaded only when relevant.
- Skills cross-reference each other by name rather than duplicating content — `core` points at `gotchas` for the full anti-pattern list, at `networking` for interceptor detail, and so on.
- `feature-template` and `testing` ship `.tpl` placeholder files under `templates/` for scaffold generation.
- Findings from the source codebase are marked **[observed]** in `gotchas` so a real defect is distinguishable from a hypothetical one.

## Validating

```
node scripts/validate-skills.mjs
claude plugin validate .
```

The first checks frontmatter, cross-references, dead links, and that this README's skill count and table match the folders. Both must pass before committing.

## Extending

Adding a skill: keep the `react-zustand-*` prefix under `skills/`, write a specific (not broad) trigger description, cross-reference it from `react-zustand-core`'s "Related skills" section so it is discoverable from the entry point, and add a row to the table above. Repo workflow rules live in [`CLAUDE.md`](CLAUDE.md).
