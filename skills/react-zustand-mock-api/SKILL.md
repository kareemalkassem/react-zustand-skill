---
name: react-zustand-mock-api
description: Use when the backend does not exist yet or is unstable and the React frontend must be built anyway — mock-first development, a fake API, seed data, demo personas, simulated latency and 403/422 errors, a prototype or demo build, or switching a mocked app over to the real backend. Trigger on "mock", "fake API", "no backend yet", "prototype", "demo data", "seed", "personas", "mock-first".
---

# Mock-First API

Building UI before the backend exists usually goes one of two ways. Either pages
hardcode arrays and every screen is rewritten at integration time, or a mock
returns whatever shape was convenient and the real envelope breaks every store.

The fix is a mock that sits **behind the one axios instance** and returns the
**real contract**. Pages, stores, and services never know they are mocked; going
live deletes one line.

## The shape

```
pages → store → service → api.js (one axios instance)
                               │ adapter
                    ┌──────────┴──────────┐
     VITE_USE_MOCKS=true            VITE_USE_MOCKS=false
     mocks/adapter.js               default http adapter → backend
       → handlers/<domain>.js
       → seed.js, personas.js
       → envelope.js (ok / fail / paginate)
```

## Wiring it into the one instance

```js
// src/services/api.js  (only the added lines)
import { mockAdapter } from '../mocks/adapter';

const api = axios.create({ baseURL: import.meta.env.VITE_API_URL, /* ... */ });

if (import.meta.env.VITE_USE_MOCKS === 'true') {
  api.defaults.adapter = mockAdapter;       // interceptors still run
}
```

An axios adapter replaces only the transport. Request and response interceptors —
token, locale, 401/403/5xx handling — run exactly as in production, so the mock
exercises the real error paths.

```js
// src/mocks/adapter.js
import { routes } from './routes';
import { wait } from './envelope';

export async function mockAdapter(config) {
  await wait();
  const method = config.method.toUpperCase();
  const url = config.url.replace(/^https?:\/\/[^/]+/, '').replace(/^\/api/, '');
  for (const route of routes) {
    const params = route.match(method, url);
    if (!params) continue;
    try {
      const data = await route.handler({ params, query: config.params ?? {}, body: parseBody(config.data), headers: config.headers });
      return { data, status: 200, statusText: 'OK', headers: {}, config };
    } catch (err) {
      if (!err.status) throw err;
      return Promise.reject(Object.assign(new Error(err.message), {
        config, response: { data: err.envelope, status: err.status, headers: {}, config },
      }));
    }
  }
  return Promise.reject(Object.assign(new Error('Mock route not found'), {
    config, response: { status: 404, data: { success: false, message: `No mock for ${method} ${url}` }, config },
  }));
}

const parseBody = (data) => (typeof data === 'string' ? JSON.parse(data || '{}') : data);
```

## The envelope helpers

```js
// src/mocks/envelope.js
export const LATENCY_MS = 220;
export const wait = (ms = LATENCY_MS) => new Promise((r) => setTimeout(r, ms));
const requestId = () => globalThis.crypto?.randomUUID?.() ?? `req_${Date.now().toString(36)}`;

export const ok = (data = null, message = 'Success') =>
  ({ success: true, message, data, request_id: requestId(), error_code: null, errors: null });

export const fail = (status, error_code, message, errors = {}) =>
  Object.assign(new Error(message), {
    status,
    envelope: { success: false, message, data: null, request_id: requestId(), error_code, errors },
  });

export const paginate = (all, { page = 1, per_page = 15 } = {}) => ({
  items: all.slice((page - 1) * per_page, page * per_page),
  meta: { page: Number(page), per_page: Number(per_page), total: all.length,
          last_page: Math.max(1, Math.ceil(all.length / per_page)) },
});
```

Use the envelope from the project's FOUNDATION contract. If the real API wraps
lists as `data.pagination` instead of `data.meta`, the mock does too.

## A handler

```js
// src/mocks/handlers/reservations.js
import { ok, fail, paginate } from '../envelope';
import { db } from '../seed';
import { requirePermission, currentPersona } from '../auth';

export const reservationRoutes = [
  route('GET', '/reservations', ({ query, headers }) => {
    requirePermission(headers, 'reservations.view');           // → 403 envelope
    const rows = db.reservations.filter((r) => !query.status || r.status === query.status);
    return ok(paginate(rows, query));
  }),
  route('PATCH', '/reservations/:id/check-in', ({ params, body, headers }) => {
    requirePermission(headers, 'reservations.check_in');
    if (!body.room_id) throw fail(422, 'validation_failed', 'Room is required', { room_id: ['Room is required'] });
    const r = db.reservations.find((x) => x.id === params.id);
    if (!r) throw fail(404, 'not_found', 'Reservation not found');
    Object.assign(r, { status: 'checked_in', room_id: body.room_id, updated_at: new Date().toISOString(),
                       updated_by: currentPersona(headers).id });
    return ok(r, 'Checked in');
  }),
];
```

```js
// src/mocks/route.js
export const route = (method, pattern, handler) => {
  const keys = [];
  const re = new RegExp(`^${pattern.replace(/:(\w+)/g, (_, k) => { keys.push(k); return '([^/]+)'; })}/?$`);
  return {
    handler,
    match: (m, url) => {
      if (m !== method) return null;
      const hit = re.exec(url.split('?')[0]);
      return hit ? Object.fromEntries(keys.map((k, i) => [k, decodeURIComponent(hit[i + 1])])) : null;
    },
  };
};
// src/mocks/routes.js:  export const routes = [...reservationRoutes, ...queueRoutes, ...authRoutes];
```

Keep one handler file per backend domain so `react-zustand-api-contract`'s parity
script can diff mock routes against the real route file later.

## Seed data and personas

- **Realistic, deterministic seed.** UUIDs, UTC ISO timestamps, enough rows to
  paginate (30+), every status value present. Generate from a fixed seed so
  screenshots are reproducible.
- **Mutable in memory.** Handlers mutate `db`, so create → list shows the new row.
  Reload resets it; that is a feature for demos.
- **One persona per role**, shared demo password, each with a distinct permission
  set — including a locale-`ar` persona if the app is bilingual. List them in the
  app's CLAUDE.md. Personas are how permissions, RTL, and empty states get
  demonstrated without a backend.
- `POST /auth/login` validates against personas and returns the same user shape
  as the real login; `GET /auth/me` restores from the token.

## Making the mock honest

The mock must fail the way the server will, or the UI is only tested on the
happy path:

| Behaviour | Why |
|---|---|
| ~200 ms latency on every call | Loading skeletons actually render |
| 403 for missing permission | Exercises hide/disable logic |
| 422 with an `errors` bag | Exercises field-error mapping |
| 404 for unknown ids | Detail pages handle a deleted record |
| Optional `?fail=1` or a dev toggle → 500 | Error states and toasts are visible |

## Going live

1. Set `VITE_USE_MOCKS=false` for the environment. Nothing else changes.
2. Run the parity script against the real route file.
3. Run the smoke script against the real backend with real accounts.
4. Keep the mocks for demos and Playwright runs; delete only when they stop
   matching the contract.

## Pitfalls

- **Mocking inside services or stores** (`if (USE_MOCKS) return fakeData`) —
  every file carries two code paths and integration touches all of them.
- **A mock envelope that differs from the real one** — stores normalize around the
  mock and break on day one of integration.
- **A second HTTP client for mocks** (a custom fetch wrapper) — interceptors are
  bypassed, so 401/403 handling is never exercised.
- **Zero latency** — loading states are never seen and race conditions hide until
  production.
- **Random data per load** — screenshots and Playwright assertions become flaky.
- **Mock leaking into production** — guard on the env flag and fail the build if
  `VITE_USE_MOCKS=true` in a production mode.

## Related skills

- `react-zustand-networking` — the axios instance the adapter plugs into.
- `react-zustand-api-contract` — parity between mock routes, services and backend.
- `react-zustand-auth-session` — login/rehydrate flow the persona mock serves.
- `react-zustand-permissions` — what the mock's 403s exercise.
- `react-zustand-realtime` — mock subscriptions for live surfaces.
- `react-zustand-e2e-playwright` — personas drive the smoke and screenshot runs.
- `react-zustand-project-workflow` — mock-first as a milestone strategy.
