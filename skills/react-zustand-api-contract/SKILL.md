---
name: react-zustand-api-contract
description: Use when the frontend and backend can drift — verifying that every service URL matches a real backend route, generating services from a Postman/OpenAPI export, diffing a mirrored enum or permission catalog against its backend source, or debugging a 404 on an endpoint that "should exist". Trigger on "API parity", "endpoint mismatch", "404 on a route that exists", "Postman collection", "OpenAPI", "sync with backend".
---

# API Contract & Parity

A React SPA holds three copies of backend knowledge:

1. **Endpoint URLs** in `services/`
2. **Enums** mirrored as frontend constants (statuses, roles, permissions)
3. **Response shapes** assumed by stores and pages

All three drift, and all three fail *at runtime, in production, on one screen*.
A 404 from a renamed route does not break the build and does not break any other
page. This skill makes the drift visible before a user finds it.

## Rule 1 — never invent an endpoint

Before writing a service function, read the actual route definition: the backend's
route file, a Postman export, an OpenAPI spec, or the network tab of a working
client. Guessing `/api/products` when the route is `/api/admin/products/index`
produces a 404 that looks like a server problem.

Record where you got it:

```js
// Source: backend/routes/api.php — Route::prefix('admin')->prefix('products')
const BASE = '/admin/products';
```

## Rule 2 — script the parity check

A script that lists every URL your services call and every route the backend
defines, then prints the symmetric difference. Roughly 150 lines, no dependencies,
runs in CI.

```js
// scripts/api-parity-check.js
import fs from 'node:fs';
import path from 'node:path';

const BACKEND_ROUTES = path.resolve('..', 'backend', 'routes', 'api.php');
const SERVICES_DIR = path.resolve('src', 'services');

// Collapse every parameter form to one token so the sets are comparable:
//   `${id}` (JS template)  {id} (Laravel)  :id (Express)  /42 (a literal id)
const normalize = (url) =>
  String(url)
    .replace(/https?:\/\/[^/]+/i, '')
    .split('?')[0]
    .replace(/\$\{[^}]+\}/g, ':p')
    .replace(/\{[^}]+\}/g, ':p')
    .replace(/:[A-Za-z0-9_]+/g, ':p')
    .replace(/\/(\d+)(?=\/|$)/g, '/:p')
    .replace(/\/+/g, '/')
    .replace(/\/$/, '');

// Frontend: every api.<method>('<url>') call found in services/
const frontendCalls = () => {
  const calls = new Set();
  for (const file of fs.readdirSync(SERVICES_DIR)) {
    const src = fs.readFileSync(path.join(SERVICES_DIR, file), 'utf8');
    for (const m of src.matchAll(/api\.(get|post|put|patch|delete)\(\s*[`'"]([^`'"]+)[`'"]/g)) {
      calls.add(`${m[1].toUpperCase()} ${normalize(m[2])}`);
    }
  }
  return calls;
};

const backendRoutes = () => { /* parse the route file; shape is backend-specific */ };

const fe = frontendCalls();
const be = backendRoutes();

const orphans = [...fe].filter((c) => !be.has(c));   // frontend calls nothing serves
const unused  = [...be].filter((r) => !fe.has(r));   // routes no page uses

if (orphans.length) {
  console.error('Frontend calls with no backend route:');
  orphans.forEach((o) => console.error('  ' + o));
}
console.log(`${unused.length} backend routes unused by the frontend.`);
process.exit(orphans.length ? 1 : 0);
```

```json
"scripts": { "api:parity": "node scripts/api-parity-check.js" }
```

Notes that decide whether it works:

- **Normalize parameters on both sides.** `${id}`, `{id}`, `:id`, and a literal
  `/42` must all collapse to the same token, or every parameterized route reports
  as an orphan and the whole output becomes noise you learn to ignore.
- **Handle template literals**, since services build URLs with backticks.
- **Fail the build on orphans; only report unused routes.** An orphan is a broken
  screen. An unused route is usually just a feature not built yet.
- **Strip comments before parsing**, or commented-out routes count as real.
- A service that computes its base path at runtime (role-aware prefixes) needs
  both variants enumerated — either handle it in the script or add an inline
  allow-list entry with a comment.

## Rule 3 — mirrored enums declare their source

Any frontend constant list duplicating a backend enum gets a comment naming the
file, and ideally a script check:

```js
// MIRROR of backend/app/Enums/OrderStatusEnum.php — keep in sync.
// Verified against commit a1b2c3d.
export const ORDER_STATUSES = ['pending', 'confirmed', 'preparing', 'delivered'];
```

The dangerous case is a **silent** mismatch. A renamed status does not throw — the
label lookup returns `undefined`, the badge renders blank, and the filter option
matches nothing. Guard the lookup so drift becomes visible:

```js
export const statusLabel = (status) => {
  const label = STATUS_LABELS[status];
  if (!label && import.meta.env.DEV) {
    console.warn(`[enum drift] Unknown order status "${status}" — check OrderStatusEnum.php`);
  }
  return label ?? status;
};
```

Returning the raw value rather than `undefined` degrades to something readable
instead of an empty cell.

The same applies to permission catalogs — see `react-zustand-permissions`.

## Rule 4 — generating services from a spec

Given a Postman collection or an OpenAPI document:

1. **Group by resource**, not by folder order — one service file per domain module.
2. **Method names describe intent**, not HTTP: `getAll`, `getById`, `create`,
   `update`, `remove`, `togglePublish` — not `postProductsCreate`.
3. **Extract the base path to a `BASE` constant** at the top of the file.
4. **Path params become function params**, query params go through `{ params }`.
5. **Inspect a real response body** to decide the unwrap. A spec's declared schema
   is often stale; the actual payload is not.
6. **Do not generate a store per endpoint.** One store per domain module, whatever
   the endpoint count.
7. **Skip endpoints nothing uses.** A generated service full of dead functions
   makes the parity check useless.

Treat generated output as a draft: read every line, delete what the app does not
call, and match the project's existing service shape.

## Rule 5 — assumed response shapes

Stores assume fields exist. When the backend renames `full_name` to `name`, the
page renders blank rather than failing.

Defend at the boundary, in the service or a mapper, not scattered through the JSX:

```js
const toProduct = (raw) => ({
  id: raw.id,
  name: raw.name ?? raw.title ?? '',
  price: Number(raw.price ?? 0),
  isPublished: Boolean(raw.published),
});
```

One place to update when the API changes, and one place to read to know what the
app expects. Do not add fallbacks reflexively — add them where the API genuinely
varies, and let a truly required missing field fail loudly instead.

## Debugging a mismatch

1. **Network tab, not the source.** Read the exact URL sent and the exact status.
2. **404** → path wrong, or the route sits under a prefix the service omits.
3. **405** → path right, method wrong. Many backends use `POST` for updates.
4. **401 on one endpoint only** → that route needs auth the interceptor did not
   attach; check the base URL is the same origin the token was issued for.
5. **403 with a body** → read `required_permissions`; this is authorization, not a
   routing bug.
6. **200 with a blank screen** → the envelope shape changed. Log the raw
   `response.data` before the unwrap.
7. **CORS error in dev only** → a proxy or backend CORS config issue, not the
   service.

Fix the service to match the backend. Do not change the backend to match a guess
unless you own it and the guess is genuinely better.

## Pitfalls

- **Inventing endpoints** — a 404 that looks like a server outage.
- **Un-normalized params in the parity script** — every route reports as an orphan
  and the output gets ignored.
- **Mirrored enums with no source comment** — silent blank badges after a rename.
- **Trusting a spec's schema over a real response** — specs go stale.
- **A generated service full of unused functions** — parity output becomes noise.
- **Defensive fallbacks scattered through JSX** — the shape assumption is now
  everywhere and nowhere.
- **Only running parity locally** — put it in CI or it decays.

## Related skills

- `react-zustand-networking` — service and envelope conventions.
- `react-zustand-permissions` — the permission catalog as a mirrored enum.
- `react-zustand-feature-template` — reading real endpoints before scaffolding.
- `react-zustand-debugging` — network-level symptom triage.
