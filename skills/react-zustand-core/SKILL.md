---
name: react-zustand-core
description: Use whenever working on any React SPA that uses Zustand for state and axios for transport — including creating a page, store, or service, deciding where a piece of logic belongs, wiring a new module end to end, or reading/writing any file under pages/, store/, services/, components/. This is the always-on core skill for React+Zustand work; trigger it before the narrower skills (networking, state, routing, ui-conventions, etc.).
---

# React + Zustand Core

React gives you rendering. It gives you nothing else — no opinion on where a fetch
lives, where state lives, or who shows an error. Every React codebase that rots
rots the same way: those three answers get decided per-file instead of once.

This skill fixes the answers. Four layers, four boundaries, and a rule for what
each layer may never do.

## Before you start

Confirm this is the right stack:

- `package.json` lists `zustand` and `axios` → these conventions apply.
- There is already a `src/store/` or `src/services/` directory → **match the local
  shapes exactly**, even where they differ from this skill.
- The project uses Redux Toolkit, TanStack Query, or RSC/server actions → this is
  a different architecture. Do not introduce Zustand alongside it uninvited.

**Read one existing store and one existing service before writing new ones.**
Projects diverge in small, stubborn ways — `store/` vs `stores/`, whether services
return `response.data` or `response.data.data`, whether actions rethrow. Matching
the local convention beats a textbook pattern every time.

## The four boundaries

This is the whole architecture. Everything else in this skill family is a detail
of one of these four rows.

| Layer | Owns | May NEVER contain |
|---|---|---|
| `pages/` + `components/` | Rendering, local UI state, user intent | `axios`, response shaping, business rules |
| `store/` | Shared state, actions, loading/error flags | JSX, `axios`, `toast` |
| `services/` | One function per endpoint, returns domain data | State, JSX, `toast`, retry policy |
| `services/api.js` | Auth header, locale headers, progress bar, global 401/403/5xx | Anything module-specific |

```
pages/ProductList.jsx        render + local filter state
      |  useProductStore(useShallow(...))
      v
store/productStore.js        { items, current, pagination, isLoading, error }
      |  productService.getAll(params)
      v
services/productService.js   api.get('/products/index') -> returns unwrapped data
      |
      v
services/api.js              ONE axios instance — token, headers, NProgress,
                             401 -> logout, 403 -> permission, 5xx -> toast
```

**The single most valuable property of this layout:** there is exactly one place a
network error can be displayed from. When every page decides for itself whether to
`toast.error`, users get two toasts for one failure, or none.

## Folder layout

```
src/
├── main.jsx                 mount, global CSS imports
├── App.jsx                  router tree ONLY — no data fetching
├── pages/                   one file per route. Flat. No index.jsx barrels.
├── components/
│   ├── ui/                  primitives: Button, Input, Modal, Table, Badge…
│   │   └── index.js         barrel — the ONLY barrel in the project
│   └── <Feature>Thing.jsx   app-specific composites (PageHeader, Pagination)
├── store/                   one file per domain module, named <domain>Store.js
├── services/                one file per domain module, named <domain>Service.js
│   └── api.js               the single axios instance
├── hooks/                   cross-page reusable hooks only
├── utils/                   pure functions. No imports from store/ or services/.
└── styles/
    ├── variables.css        every design token
    └── <Page>.module.css    one per page
```

Naming: files that export a component are `PascalCase.jsx`. Everything else is
`camelCase.js`. Stores are `<domain>Store.js` exporting `use<Domain>Store`;
services are `<domain>Service.js` exporting a default object.

## The module triad: service + store + page

The most common task is "add a screen for X". Three files, and they must agree on
the data shape.

**1. Service** — `src/services/productService.js`. Thin. One function per endpoint.

```js
import api from './api';

const productService = {
  getAll: async (params) => {
    const { data } = await api.get('/products/index', { params });
    return data.data;                       // unwrap the envelope HERE, once
  },

  getById: async (id) => {
    const { data } = await api.get(`/products/get/${id}`);
    return data.data;
  },

  create: async (payload) => {
    const isForm = payload instanceof FormData;
    const { data } = await api.post('/products/create', payload,
      isForm ? { headers: { 'Content-Type': 'multipart/form-data' } } : {});
    return data.data;
  },

  remove: async (id) => {
    const { data } = await api.delete(`/products/delete/${id}`);
    return data.data;
  },
};

export default productService;
```

Rules this encodes:

- **The envelope is unwrapped in the service, never in the store.** If the API
  returns `{ data: { items, pagination }, code }`, the service is the only file
  that knows that. A store that reaches into `response.data.data` has leaked
  transport into state.
- **No `try`/`catch` in a service.** It rethrows by omission; the store decides.
- **No `toast` in a service.** `api.js` owns global errors, the store owns
  module-specific ones.
- Services never import from `store/` — with one narrow exception, see
  `react-zustand-networking` on role-aware base paths.

**2. Store** — `src/store/productStore.js`.

```js
import { create } from 'zustand';
import productService from '../services/productService';
import { extractApiErrorMessage } from '../utils/apiError';

export const useProductStore = create((set) => ({
  items: [],
  current: null,
  pagination: null,
  isLoading: false,
  error: null,

  fetchAll: async (params) => {
    set({ isLoading: true, error: null });
    try {
      const data = await productService.getAll(params);
      set({ items: data.items, pagination: data.pagination, isLoading: false });
    } catch (error) {
      set({ error: extractApiErrorMessage(error), isLoading: false });
    }
  },

  create: async (payload) => {
    const created = await productService.create(payload);
    set((state) => ({ items: [...state.items, created] }));
    return created;                          // mutations THROW — see below
  },
}));
```

**3. Page** — `src/pages/Products.jsx`.

```jsx
const Products = () => {
  const { items, isLoading, error, fetchAll } = useProductStore(
    useShallow((s) => ({
      items: s.items, isLoading: s.isLoading, error: s.error, fetchAll: s.fetchAll,
    }))
  );

  useEffect(() => { fetchAll({ page: 1 }); }, [fetchAll]);

  if (error) return <ErrorState message={error} onRetry={() => fetchAll({ page: 1 })} />;
  return <ProductTable items={items} isLoading={isLoading} />;
};
```

`useShallow` is not optional on multi-field selects. Without it the returned object
is a new reference on every store write, and the page re-renders on state it does
not read. See `react-zustand-state`.

## The read/write error contract

This is the rule most codebases get wrong, and getting it wrong makes every page
guess.

- **Reads swallow.** A fetch action catches, writes `error` into the store, and
  returns nothing. The page renders `<ErrorState>` from `error`. No throw.
- **Writes throw.** A create/update/delete action does *not* catch. The page awaits
  it inside its own `try`, shows a `toast.error`, and unwinds its own submitting
  state.

The reason is who owns the recovery UI. A failed list fetch replaces the page body;
a failed save must leave the form intact with its values and let the user retry.
Different UIs, so different control flow.

State this rule in the store file if the project is new to it — do not leave it
implicit. A codebase where half the actions swallow and half rethrow forces every
call site to read the store source before it can be written.

## Decision points

### Where does this piece of state go?

1. **Used by one component, dies with it** (a dropdown's open flag, a hovered row)
   → `useState` in that component. Do not create a store.
2. **Used by one page and its children** (form values, selected rows) → `useState`
   in the page, passed down as props. Still no store.
3. **Filter/sort/page state that should survive a refresh or be shareable** →
   `useSearchParams`, not `useState`. The URL is the store. See
   `react-zustand-routing`.
4. **Server data read by more than one route** (product list, current order) → a
   Zustand store.
5. **App-global session** (auth token, current user, locale, permissions) → a
   Zustand store with `persist`. See `react-zustand-auth-session`.

A store per domain module, not per page. Two pages showing products share
`useProductStore`.

### `useState` vs store vs URL — the smell

If you are lifting `useState` into a store so a sibling can read it, check first
whether the sibling should just receive a prop. Stores are for state crossing a
*route* boundary, not a component boundary.

### Where does derived data go?

Never in the store. A store holds server truth; filtered, sorted, and formatted
views of it are computed at read time with `useMemo`, ideally in a named hook:

```js
export const useFilteredCustomers = (customers, search, sort) =>
  useMemo(() => { /* map -> filter -> sort */ }, [customers, search, sort]);
```

Storing a derived array means two sources of truth that drift the moment one update
path forgets to recompute.

### Where does an API call go?

Always a service. A page or store that imports `axios` directly is the single most
common boundary break; it bypasses the interceptors, so that call has no auth
header, no progress bar, and no global 401 handling.

## Common pitfalls

- **Selecting the whole store** — `const store = useProductStore()` re-renders on
  every unrelated write. Select fields, and use `useShallow` for more than one.
- **`useEffect` with an inline action in deps** — Zustand actions are stable across
  renders, so `[fetchAll]` is safe. An inline arrow wrapping it is not.
- **Unwrapping the envelope in the store** — leaks transport into state.
- **`toast` in a service or in a store fetch** — double-notifies with the `api.js`
  interceptor.
- **Fat pages.** Past ~300 lines a page is holding logic that belongs in a hook, a
  store action, or a child component. Split it.
- **A second axios instance.** There is one. See `react-zustand-networking`.

For the full anti-pattern list, see `react-zustand-gotchas`.

## Team conventions

- **Commits**: `feat: add coupon list page`, `fix: unwrap paginated envelope in
  service`, `chore: drop unused imports` — type-prefixed, imperative mood.
- **PR checklist**: no `axios` import outside `services/`; no `toast` in a store
  fetch; every new store field has a loading and an error flag; no hardcoded colors
  (see `react-zustand-design-tokens`); every new page is `lazy()`-imported in the
  router (see `react-zustand-routing`).
- **Lint baseline**: `eslint` flat config with `js.configs.recommended`,
  `eslint-plugin-react-hooks`, and `eslint-plugin-react-refresh`. Treat
  `react-hooks/exhaustive-deps` as an error for new code, not a warning. Extend the
  project's existing `eslint.config.js`; do not start a new ruleset.
- **Comments**: one line above a store action whose behavior is non-obvious
  (optimistic update, cache invalidation, deliberate swallow). Never a restatement
  of the next line.

## Related skills

Load these only when the task touches their concern — do not pre-load:

- `react-zustand-networking` — the axios instance, interceptors, error extraction.
- `react-zustand-state` — store shapes, `persist`, selectors, cross-store access.
- `react-zustand-routing` — route tree, guards, lazy loading, URL as state.
- `react-zustand-ui-conventions` — `ui/` primitives, `clsx` + CSS Modules.
- `react-zustand-design-tokens` — `variables.css`, theming, no hardcoded values.
- `react-zustand-auth-session` — login, token persistence, global 401 logout.
- `react-zustand-permissions` — permission store, route and action gating.
- `react-zustand-data-tables` — list pages: search, filters, pagination, skeletons.
- `react-zustand-forms-validation` — controlled forms, backend 422 field errors.
- `react-zustand-assets-media` — image URLs, upload validation, FormData.
- `react-zustand-feature-template` — full service+store+page+styles scaffold.
- `react-zustand-testing` — Vitest + RTL, mocking the axios instance.
- `react-zustand-performance` — chunking, selector scoping, list size.
- `react-zustand-gotchas` — anti-pattern reference; read when designing or reviewing.
- `react-zustand-api-contract` — keeping service URLs in parity with the backend.
- `react-zustand-debugging` — symptom decision trees.

`references/extraction-notes.md` records which conventions here were verified
against a shipped production codebase and which are general React practice.
