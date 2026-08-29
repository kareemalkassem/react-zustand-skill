---
name: react-zustand-state
description: Use when creating or editing a Zustand store — choosing the store shape, writing actions, adding persist/partialize, selecting state in a component, using useShallow, reading one store from another, or debugging unnecessary re-renders and stale store values. Trigger on "store", "zustand", "global state", "selector", "persist", "re-render" in a React context.
---

# Zustand Store Conventions

Zustand has almost no API, which means almost all of its failure modes are
conventions you did not set. This skill sets them.

## The standard shape

One store per domain module, in `src/store/<domain>Store.js`, exporting
`use<Domain>Store`.

```js
import { create } from 'zustand';
import productService from '../services/productService';
import { extractApiErrorMessage } from '../utils/apiError';

export const useProductStore = create((set, get) => ({
  // --- state ---
  items: [],
  current: null,
  pagination: null,
  isLoading: false,
  error: null,

  // --- reads: swallow, write error into state ---
  fetchAll: async (params) => {
    set({ isLoading: true, error: null });
    try {
      const data = await productService.getAll(params);
      set({ items: data.items, pagination: data.pagination, isLoading: false });
    } catch (error) {
      set({ error: extractApiErrorMessage(error), isLoading: false });
    }
  },

  // --- writes: throw, caller owns the UI ---
  create: async (payload) => {
    const created = await productService.create(payload);
    set((state) => ({ items: [...state.items, created] }));
    return created;
  },

  remove: async (id) => {
    await productService.remove(id);
    set((state) => ({ items: state.items.filter((p) => p.id !== id) }));
  },

  reset: () => set({ items: [], current: null, pagination: null, error: null }),
}));
```

Five state fields cover almost every server-backed module:

| Field | Holds |
|---|---|
| `items` | the list |
| `current` | the single entity a detail page is showing |
| `pagination` | `{ current_page, last_page, total, per_page }` from the server |
| `isLoading` | in-flight flag for the *list* read |
| `error` | message string for the *list* read, or `null` |

Keep the names identical across stores. Uniformity is the point — a developer who
has read one store has read all of them.

## The read/write error contract

Restated here because it is a store-level rule:

- **Reads swallow.** `fetchAll` catches, sets `error`, returns nothing.
- **Writes throw.** `create`/`update`/`remove` do not catch.

Never `console.error` and swallow a write. That is the shape that produces a
button that appears to succeed while nothing was saved.

## Actions never touch JSX or axios

An action may call a service, transform the result into state, and read another
store. It may not import `axios`, render, or call `toast`. Toasting from a store
means the same failure notifies twice — once from the `api.js` interceptor, once
here.

The one defensible exception is an action with no UI caller at all (a background
refresh triggered by a socket event). Comment the exception where you make it.

## Selecting state in a component

**Single field** — plain selector:

```js
const items = useProductStore((s) => s.items);
```

**Multiple fields** — `useShallow`, always:

```js
import { useShallow } from 'zustand/react/shallow';

const { items, isLoading, error, fetchAll } = useProductStore(
  useShallow((s) => ({
    items: s.items, isLoading: s.isLoading, error: s.error, fetchAll: s.fetchAll,
  }))
);
```

The selector returns a **new object literal on every call**. Zustand compares the
previous and next selector result by reference, so without `useShallow` the
comparison is always "changed" and the component re-renders on every write to any
part of the store — including writes it does not read. `useShallow` compares the
object one level deep instead.

**Never** select the whole store:

```js
const store = useProductStore();          // re-renders on every store write
```

**Never** derive inside the selector:

```js
// new array reference every call — same bug as the object literal
const active = useProductStore((s) => s.items.filter((i) => i.active));
```

Select `items`, derive with `useMemo` in the component.

## Actions are stable — deps are safe

Zustand action identities never change across renders, so this is correct and does
not loop:

```js
useEffect(() => { fetchAll({ page }); }, [fetchAll, page]);
```

An inline wrapper is *not* stable and will loop:

```js
const load = () => fetchAll({ page });
useEffect(() => { load(); }, [load]);      // new identity every render
```

## Reading a store outside React

`useXStore.getState()` reads without subscribing. Use it in services, interceptors,
utils, and inside other stores' actions.

```js
const role = useAuthStore.getState().user?.role;
useNotificationStore.getState().markAllRead();
```

Calling the hook form outside a component throws. `getState()` is also a *snapshot*
— it does not re-run when the value changes, so never use it where you needed a
subscription.

## Cross-store access

Stores may import each other, but keep the direction one-way: domain stores may
read the session store, never the reverse. A cycle between two stores is a
module-init deadlock in Vite.

```js
// authStore.js — on logout, tell dependents to clear
logout: () => {
  set({ user: null, token: null, isAuthenticated: false });
  usePermissionStore.getState().reset();
  useProductStore.getState().reset();
},
```

Give every domain store a `reset()` so the session store can clear the app in one
place. Without it, logging out and back in as a different user shows the previous
user's rows for a frame.

## `persist`

Persist only what must survive a reload: the session, and user preferences. Never
persist server data — it goes stale and you have built a cache with no
invalidation.

```js
import { persist } from 'zustand/middleware';

export const useAuthStore = create(
  persist(
    (set) => ({ user: null, token: null, isAuthenticated: false, /* actions */ }),
    {
      name: 'auth-storage',
      partialize: (state) => ({
        user: state.user,
        token: state.token,
        isAuthenticated: state.isAuthenticated,
      }),
    }
  )
);
```

- **`partialize` is mandatory.** Without it, `isLoading: true` and a stale `error`
  are persisted too, and the app reloads into a permanent spinner.
- **The `name` is a public contract.** The axios request interceptor reads this key
  directly to break a circular import (see `react-zustand-networking`). Renaming it
  silently unauthenticates every request. Comment it in both files.
- The persisted value is `{ state, version }` — anything reading the raw key must
  destructure `state`.
- Bump `version` and supply `migrate` when the persisted shape changes, or a
  returning user hydrates into a shape the code no longer understands.

## Enumerated / catalog state

Where a store holds a fixed catalog (statuses, permissions, roles) mirrored from
the backend, declare the list as a module constant above the store and derive maps
from it. Never scatter the strings through actions.

```js
const STATUSES = ['pending', 'confirmed', 'preparing', 'delivered'];
const buildMap = (value) => STATUSES.reduce((acc, s) => ({ ...acc, [s]: value }), {});
```

Any such catalog is a **duplicate of a backend enum** and will drift. Say so in a
comment naming the backend file, and prefer fetching the list at runtime when the
API offers it. See `react-zustand-permissions` for the worked case.

## When NOT to create a store

- State used by one component → `useState`.
- State used by a page and its children → `useState` in the page, props down.
- Filters, sort, and current page → `useSearchParams`. The URL is the store; it
  survives reload and is shareable. See `react-zustand-routing`.
- Derived data → `useMemo`, in a named hook if reused.

A store is for state that crosses a **route** boundary.

## Pitfalls

- **Multi-field select without `useShallow`** — the top re-render bug in Zustand apps.
- **Deriving inside a selector** — new reference every call, same bug.
- **`useProductStore()` with no selector** — subscribes to everything.
- **Persisting `isLoading`** — app reloads into a stuck spinner.
- **Persisting server data** — a cache with no invalidation.
- **Mutating state in place** — `state.items.push(x)` does not notify. Always
  return a new array or object from `set`.
- **`getState()` where a subscription was needed** — the value never updates.
- **A store that both fetches and formats for display** — put formatting in a hook.

## Related skills

- `react-zustand-core` — the four boundaries and the error contract.
- `react-zustand-networking` — the services these actions call.
- `react-zustand-auth-session` — the persisted session store in full.
- `react-zustand-permissions` — a catalog store with a documented drift risk.
- `react-zustand-performance` — selector scoping and render-cost measurement.
- `react-zustand-testing` — testing actions without React.
- `react-zustand-debugging` — infinite-render and stale-value decision trees.
