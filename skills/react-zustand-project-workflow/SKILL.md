---
name: react-zustand-project-workflow
description: Use when starting a new React+Zustand frontend or dashboard from scratch, planning a milestone, writing the app's CLAUDE.md/AGENTS.md, deciding build order, forking an existing React app as a reference for a new one, or deciding when a feature is "done". Trigger on "new dashboard", "new admin panel", "start a React project", "plan the frontend", "milestones", "tracker", "definition of done".
---

# Project Workflow

Most frontends fail before the first component is written: there is no written
contract for the API envelope, no order of work, and no definition of "done". The
result is pages built before primitives, three error-display paths, and a
backend integration that turns into a UI rewrite.

This skill is the order of operations around the other `react-zustand-*` skills.
It does not repeat their code — it says which one to apply, and when.

## The shape

```
FOUNDATION.md ──► EXECUTION_PLAN.md ──► TRACKER.md ──► CLAUDE.md
 (what + contract)  (milestones, "Done when")  (tasks)    (rules for agents)
        │
        ▼
M0 scaffold → M1 tokens + shell + primitives → M2 api.js + auth + permissions
            → M3..Mn one domain module per milestone → last: polish + demo
        │
        ▼
per task: wire bottom-up → verify by driving the app → update TRACKER
```

Templates for all four documents live in `templates/`.

## 1. Write the contract before code

`templates/FOUNDATION.md.tpl` holds: who uses the app and its 3–5 jobs, the role
and permission catalog, the **API envelope** (success/data/errors/request id,
pagination shape, auth scheme, locale header), brand tokens, locales, and which
surfaces are real-time.

The envelope is the one decision every later file depends on. Write it down even
when the backend does not exist yet — that is exactly when `react-zustand-mock-api`
needs it.

## 2. Milestones with a testable "Done when"

`templates/EXECUTION_PLAN.md.tpl`. Every milestone ends in a line a reviewer can
check: "`npm run build` passes and the shell route renders", not "set up the
project". A milestone without one never closes.

Fixed order for the first three:

| Milestone | Delivers | Skills |
|---|---|---|
| M0 Setup | Vite app, folder layout, lint/build scripts | `react-zustand-core` |
| M1 Design system | `variables.css`, shell, `ui/` primitives, RTL if bilingual | `react-zustand-design-tokens`, `react-zustand-ui-conventions`, `react-zustand-i18n-rtl` |
| M2 Platform | `api.js`, auth store, permission store, guarded route tree, mock layer | `react-zustand-networking`, `react-zustand-auth-session`, `react-zustand-permissions`, `react-zustand-routing`, `react-zustand-mock-api` |

Primitives come before pages because the first page written without them becomes
the de facto primitive library, copied with its bugs into every later page.

## 3. Tasks with acceptance criteria

`templates/TRACKER.md.tpl` — one row per task: ID, milestone, task, status
(`Todo` / `In Progress` / `Blocked` / `Done`), depends-on, acceptance criteria.
Keep "Decisions" and "Open questions" sections under the table so a decision is
recorded once instead of re-litigated per session.

If the repo already runs a planning system (`.planning/`, an issue tracker), use
that instead. Two trackers drift within a week.

## 4. Rules for agents next to the code

`templates/CLAUDE.md.tpl` — stack table, folder map, architecture notes, personas,
commands, coding rules, and **a reference codebase section**: which proven app
this one is modeled on, what it inherits, and where it deliberately diverges.

The divergence table is the valuable part. Without it an agent "fixes" every
intentional difference back to the reference app's way.

## 5. Wire each feature bottom-up

Per task, always in this order — each step is testable before the next exists:

1. Backend route or mock handler exists (`react-zustand-api-contract` /
   `react-zustand-mock-api`). Never invent an endpoint.
2. Service (`react-zustand-networking`).
3. Store (`react-zustand-state`).
4. Page with loading, empty, error, and 403 states (`react-zustand-data-tables`,
   `react-zustand-forms-validation`).
5. Lazy route, permission gate, nav entry (`react-zustand-routing`,
   `react-zustand-permissions`).
6. Translation keys if bilingual (`react-zustand-i18n-rtl`).

For a whole CRUD module this is exactly what `react-zustand-feature-template`
scaffolds.

## 6. Definition of done

A task is done when all of these were **run**, not assumed:

- `npm run build` passes and `npm run lint` is clean.
- Route parity script shows no service URL without a backend route
  (`react-zustand-api-contract`).
- Unit tests for any new store logic pass (`react-zustand-testing`).
- The smoke script logs in, walks the changed routes, and collects zero page or
  console errors; screenshots of changed screens were looked at
  (`react-zustand-e2e-playwright`).
- The TRACKER row is updated with what changed.

Report the actual results ("build ok, 0 lint errors, smoke 7/7 routes"), never
"should work".

## 7. Branches and commits

- One concern per branch; merge `main` in often rather than one large merge at the
  end. Run the parity check after every merge that touches `services/`.
- Conventional messages: `feat(orders): add bulk export`, `fix(auth): stop 401
  loop on login page`. A message of `.` or `fix` cannot be reviewed or reverted
  safely.
- Try visual experiments on a branch with a screenshot check. A string of
  `Revert "..."` commits on `main` means experiments were merged before they were
  looked at.
- Never commit local databases, logs, `.env`, or screenshot artifacts.

## Forking a proven app for a new domain

Copy the structure, not the domain: `api.js`, stores' shape, `ui/` primitives,
`RequirePermission`, and the shell. Then rename every domain term and swap the
brand tokens in M1. Record the fork in the new app's CLAUDE.md reference section.

## Pitfalls

- **Pages before primitives** — each page invents its own button and table, and
  the later primitive library never gets adopted.
- **No written envelope** — every service guesses `data.data` vs `data.items`, and
  stores end up normalizing, which breaks the core boundary.
- **"Done" without running the app** — a build that passes can still render a
  blank page; only the smoke run catches it.
- **Tracker not updated** — the next session redoes or contradicts finished work.
- **Planning docs that restate code** — they rot. Docs hold decisions and
  contracts; code holds implementation.

## Related skills

- `react-zustand-core` — the four boundaries every milestone builds on.
- `react-zustand-feature-template` — the per-module scaffold used in step 5.
- `react-zustand-mock-api` — building M2 before a backend exists.
- `react-zustand-e2e-playwright` — the smoke and screenshot gate in step 6.
- `react-zustand-api-contract` — the parity check in step 6.
- `react-zustand-i18n-rtl` — bilingual apps decide this in M1, not later.
