# react-zustand-skill — design

**Date:** 2026-08-29
**Status:** implemented

## Problem

There is a codified Claude Code plugin for Flutter+GetX conventions
(`flutter-getx`, 17 skills) but no equivalent for React work. React itself has no
opinion on where a fetch lives, where state lives, or who displays an error, so
every React codebase re-decides those three questions per file and drifts.

The goal is a **project-agnostic** skill family that encodes one coherent React
architecture, extracted from a real shipped codebase rather than authored from
general knowledge.

## Source

A production React admin dashboard: React 19, Vite 7, Zustand 5,
react-router-dom 7, axios, CSS Modules. ~34,000 lines across 171 source files —
55 lazy-loaded pages, 24 services, 15 stores, 13 components plus 10 UI primitives,
8 utils, 37 CSS modules, 1 custom hook, 0 tests.

The source is **evidence, not subject.** No skill names the source project or its
domain. Conventions appear as generic React practice; the provenance ledger lives
in `skills/react-zustand-core/references/extraction-notes.md`.

## Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Scope | Project-agnostic | The user asked for a reusable base, not documentation of one app |
| Styling | CSS Modules + CSS custom properties; no Tailwind | What the source actually is, so every rule cites real evidence; tokens stay runtime-themeable |
| Language | JavaScript + JSX | Matches the source. TS would be a separate, family-wide decision |
| Repo shape | Mirror of `flutter-getx` | Familiar to the user; a proven plugin layout |
| Skill count | 17 | One per concern; matches the boundaries found in the source |
| Naming | `react-zustand-*` | Zustand is the distinguishing library, as GetX is for the Flutter family |
| Placement | Standalone repo at `~/Desktop/react-zustand-skill` | Its own git repo and single-plugin marketplace, independent of any project |

## Architecture the family encodes

Four layers with an explicit "may never contain" rule each:

```
pages/     render + local UI state       | no axios, no data shaping
store/     state, actions, error flags   | no JSX, no axios, no toast
services/  transport, unwraps envelope   | no state, no toast
api.js     auth, headers, 401/403/5xx    | the only error display path
```

Plus one contract most codebases leave implicit: **reads swallow into `error`,
writes throw.** Read failures replace the page body; write failures must leave the
form intact. Different recovery UI, therefore different control flow.

## Deliverables

- 17 `skills/react-zustand-*/SKILL.md`
- `skills/react-zustand-core/references/extraction-notes.md` — VERIFIED /
  CORRECTED / RECOMMENDED provenance ledger
- 4 scaffold templates + 2 test templates
- `agents/react-reviewer.md` — boundary-violation reviewer
- `commands/react-feature.md` — `/react-feature`
- `hooks/hooks.json` + `scripts/format-js.sh` — non-blocking eslint-fix-on-edit
- `scripts/validate-skills.mjs` — zero-dependency repo validator
- `.claude-plugin/plugin.json` + `marketplace.json`, `README.md`, `CLAUDE.md`

## Defects corrected from the source

The extraction found real defects. The skills document the fix, not the source
behavior; `react-zustand-gotchas` marks them **[observed]**.

1. Two styling systems — 37 CSS modules plus Tailwind with an empty `theme.extend`,
   so every Tailwind usage hardcoded a color no token could reach.
2. Design docs quoting literal hex values that had drifted from `variables.css`,
   so anything generated from the docs shipped the wrong brand.
3. Inconsistent store error contract — one store swallowing reads and rethrowing
   writes with no stated rule.
4. Response envelope unwrapped in a store rather than its service.
5. Pages up to 1,106 lines; one custom hook across 55 pages.
6. A hardcoded 44-entry permission catalog discovered by probing, mirroring a
   backend enum with no drift guard.
7. No tests and no test runner.

## Non-goals

- Documenting the source project's domain, routes, or business rules.
- Prescribing TypeScript, Tailwind, Redux, or TanStack Query.
- Server-side rendering, Next.js, or React Server Components.
- Replacing a project's existing conventions — every skill instructs Claude to read
  local code first and match it where it is internally consistent.
