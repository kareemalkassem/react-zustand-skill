# {{App}} — CLAUDE.md

## What this is

{{One paragraph: who uses it, real backend or mock-first, current milestone.}}

## Tech stack

| Layer | Tool |
| --- | --- |
| Build | Vite |
| UI | React + react-router-dom |
| State | Zustand |
| HTTP | axios — one instance in `src/services/api.js` |
| Styling | CSS Modules + `src/styles/variables.css` |
| Icons | lucide-react |
| Tests | Vitest + RTL; Playwright smoke scripts |

## Project structure

```
src/
├── components/ui/      primitives
├── components/         app composites (layout, PageHeader, RequirePermission)
├── pages/              one lazy route per file
├── services/           api.js + one <domain>Service.js per API domain
├── store/              one <domain>Store.js per domain
├── mocks/              mock adapter, handlers, seed, personas (mock-first only)
├── styles/             variables.css + <Page>.module.css
└── utils/              pure helpers (apiError, i18n, date, money)
scripts/                smoke.py, capture_screens.py, api-parity-check.js
```

## Architecture

- API: envelope `{{shape}}`, unwrapped in services only.
- Auth: {{flow}}. 401 → login; 403 → hide/disable; 422 → field errors.
- Permissions: permission names only; `super_admin` bypasses.
- Real-time: {{none | subscription → store connect/disconnect}}.
- i18n: {{en | en + ar, dir set on <html>, logical CSS properties}}.

## Personas (mock mode)

| Email | Role | Permissions |
| --- | --- | --- |
| admin@{{app}}.test | super_admin | all |

Password for all personas: `{{demo1234}}`.

## Commands

```bash
npm run dev       # http://localhost:5173
npm run build
npm run lint
npm run smoke     # requires dev server
npm run screens   # screenshots → artifacts/screens/
npm run api:parity
```

## Coding rules

- Never import axios outside `services/`.
- Never branch on role names in UI.
- Every data surface: loading, empty (with next action), error (message + request id), 403.
- UTC timestamps; format in the browser.
- Read FOUNDATION / EXECUTION_PLAN / TRACKER before starting; update TRACKER when done.

## Reference codebase

Modeled on {{path or repo}}.

| Area | Reference | This app |
| --- | --- | --- |
| {{Styling}} | {{...}} | {{...}} |

When adding a feature, check how the reference implemented the equivalent page first, then adapt to this app's domain and tokens.
