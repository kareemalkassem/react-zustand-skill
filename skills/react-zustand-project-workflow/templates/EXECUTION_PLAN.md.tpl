# {{App}} Execution Plan

Date: {{YYYY-MM-DD}}
Strategy: {{backend-first | mock-first — UI built against mocks shaped like the real contract}}

## Working rules

- Every task ends with build + lint + smoke green and the TRACKER row updated.
- Backend integration is a service-layer swap, never a UI rewrite.

## M0 — Setup

Deliverables: Vite React app, folder layout, eslint, scripts (`dev`, `build`, `lint`, `smoke`).
Done when: `npm run build` passes and a placeholder shell route renders.

## M1 — Design system and shell

Deliverables: `variables.css` tokens, app shell (sidebar, header), `ui/` primitives, RTL if bilingual, login screen.
Done when: every primitive renders on a demo route in LTR {{and RTL}}.

## M2 — Platform

Deliverables: `api.js`, auth store (login/logout/rehydrate), permission store + gate, guarded lazy route tree, {{mock layer + personas}}.
Done when: each persona logs in, sees only its permitted nav, and 401/403/422 are visible in the UI.

## M3 — {{Domain module}}

Deliverables: {{pages}}.
Done when: {{acceptance in user terms}}.

## M{{n}} — Polish and demo readiness

Done when: smoke passes for every persona, screenshots reviewed, no console errors.
