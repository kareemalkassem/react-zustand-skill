---
name: react-zustand-feature-template
description: Use when scaffolding a whole new module in a React+Zustand app — "create a new feature", "add a products section", "scaffold the orders module". Generates the service, store, list page, detail/form page, CSS module, and route entry as one consistent set. Trigger on any request to create a new feature, module, section, or CRUD screen rather than edit an existing one.
---

# Feature Scaffold

A feature is **five files plus one route edit**. Generate them together or they
drift — a store whose action names do not match the service, a page importing a
field the store never sets.

```
src/services/<name>Service.js       transport
src/store/<name>Store.js            state + actions
src/pages/<Name>s.jsx               list page
src/pages/<Name>Form.jsx            create/edit page   (skip if read-only)
src/styles/<Name>s.module.css       page styles
src/App.jsx                         + lazy import + route entries
```

## Before generating

Answer these four. Guessing produces a scaffold that has to be rewritten.

1. **Entity and plural** — `product` / `products`. Drives every filename and path.
2. **Endpoints** — the real paths and methods. Read the backend routes or a Postman
   export; do not invent `/api/products` and hope.
3. **Response envelope** — `{ data: { items, pagination } }`, `{ data: [...] }`, or
   a bare array. Determines what the service unwraps.
4. **Read-only or full CRUD** — a read-only module skips the form page and the
   write actions.

Then **read one existing service and one existing store in the target project** and
match their shape. A scaffold that does not look like its neighbours is worse than
no scaffold.

## Templates

`templates/` holds four placeholder files. Substitute:

| Placeholder | Example | Used in |
|---|---|---|
| `__ENTITY__` | `product` | variables, imports |
| `__ENTITIES__` | `products` | store fields, URLs |
| `__Entity__` | `Product` | component and type names |
| `__Entities__` | `Products` | page component, file names |
| `__BASE_PATH__` | `/admin/products` | service URLs |
| `__PERMISSION__` | `products` | permission prefix |

- `service.js.tpl` → `src/services/__ENTITY__Service.js`
- `store.js.tpl` → `src/store/__ENTITY__Store.js`
- `list-page.jsx.tpl` → `src/pages/__Entities__.jsx`
- `page.module.css.tpl` → `src/styles/__Entities__.module.css`

## Generation order

Bottom-up. Each layer's shape constrains the one above it.

1. **Service.** One function per endpoint, unwrap the envelope, no `try`/`catch`.
2. **Store.** `{ items, current, pagination, isLoading, error }`; reads swallow,
   writes throw; include `reset()`.
3. **CSS module.** Tokens only, no literal values.
4. **List page.** URL-seeded filters, debounced fetch, five states, pagination.
5. **Form page** (if CRUD). Controlled `values`, `extractFieldErrors` on 422.
6. **Route entry.** `lazy()` import plus routes under the right guard, wrapped in
   `RequirePermission` if the app has permissions.
7. **Nav entry**, with its permission attached.
8. **Logout reset.** Add the new store's `reset()` to the auth store's `logout`.

Step 8 is the one that gets forgotten, and its symptom — the previous user's rows
briefly visible after a re-login — appears far from its cause.

## Route entry

```jsx
const Products      = lazy(() => import('./pages/Products'));
const ProductForm   = lazy(() => import('./pages/ProductForm'));
```

```jsx
<Route path="/admin/products" element={
  <RequirePermission permission="products.view">{withSuspense(Products)}</RequirePermission>
} />
<Route path="/admin/products/new" element={
  <RequirePermission permission="products.create">{withSuspense(ProductForm)}</RequirePermission>
} />
<Route path="/admin/products/:id/edit" element={
  <RequirePermission permission="products.edit">{withSuspense(ProductForm)}</RequirePermission>
} />
```

One `ProductForm` serves create and edit — it branches on `useParams().id`. Two
near-identical files diverge within a month.

## After generating — verify, do not assume

1. `npm run lint` — zero new warnings.
2. `npm run dev`, open the route: list renders, skeleton shows while loading,
   empty state appears with an impossible filter, error state appears with the API
   stopped.
3. Network tab: one request per filter change, not one per keystroke. The
   `Authorization` header is present.
4. Create, edit, and delete one record. Confirm the list updates without a manual
   reload.
5. Reload mid-list — filters restore from the URL.
6. Write at least one test per new store action (`react-zustand-testing`).

Report what you actually observed. "Should work" is not a verification.

## Checklist

- [ ] Service: one function per endpoint, envelope unwrapped, no `try`/`catch`, no `toast`
- [ ] Store: standard five fields, reads swallow, writes throw, `reset()` present
- [ ] Store registered in the auth store's `logout` reset list
- [ ] List page: URL-seeded filters, debounce with cleanup, `setPage(1)` on filter change
- [ ] All five states rendered: loading, empty, error, disabled, success
- [ ] `useShallow` on the multi-field store select
- [ ] Form page: controlled values, `extractFieldErrors` on 422, `submitting` in `finally`
- [ ] CSS module: tokens only, no literal colors or spacing
- [ ] Route: `lazy()` + `withSuspense` + permission wrapper, under the right guard
- [ ] Nav item added with its permission
- [ ] Lint clean, flows manually verified, at least one test written

## Related skills

- `react-zustand-core` — the boundaries the scaffold enforces.
- `react-zustand-networking` — service rules.
- `react-zustand-state` — store rules.
- `react-zustand-data-tables` — list page anatomy.
- `react-zustand-forms-validation` — form page anatomy.
- `react-zustand-routing` — route registration.
- `react-zustand-permissions` — gating the new routes and actions.
- `react-zustand-testing` — what to test once it exists.
