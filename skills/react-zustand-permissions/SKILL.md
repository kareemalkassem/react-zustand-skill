---
name: react-zustand-permissions
description: Use when gating UI by fine-grained permissions in a React SPA — hiding nav items, disabling action buttons, wrapping a page in a permission check, modelling a permission store, handling 403 responses, or keeping a frontend permission catalog in sync with a backend enum. Trigger on "permission", "role-based access", "can the user", "403", "hide the button", "ACL" in a React context.
---

# Permissions

Roles decide **which routes exist**. Permissions decide **which actions inside a
route are available**. Different granularity, different mechanism — do not conflate
them (`react-zustand-auth-session` owns roles).

**The frontend permission check is a UX affordance, never a security control.** The
server enforces. Everything here exists so the user does not click a button that
was always going to 403.

## Source of truth — prefer the server

Three ways to know what a user may do, best first:

1. **The login response returns the permission list.** One request, always correct,
   no drift. Ask the backend for this before building anything else.
2. **A dedicated `GET /me/permissions`** called once after login.
3. **Inference from responses** — a fallback described below. Use it only when
   neither of the above exists, and write down why.

## The permission store

```js
import { create } from 'zustand';
import { persist } from 'zustand/middleware';

// MIRROR of the backend permission enum (app/Enums/PermissionEnum.php).
// This list WILL drift. Prefer permissions returned by the login response.
const PERMISSIONS = [
  'products.view', 'products.create', 'products.edit', 'products.delete',
  'orders.view', 'orders.confirm', 'orders.assign_driver',
  'settings.view', 'settings.edit',
];

const buildMap = (status) => PERMISSIONS.reduce((acc, p) => ({ ...acc, [p]: status }), {});
const UNKNOWN = buildMap('unknown');

export const usePermissionStore = create(
  persist(
    (set, get) => ({
      permissions: UNKNOWN,          // { [perm]: 'granted' | 'missing' | 'unknown' }

      hydrate: (role, list = []) => {
        if (role === 'admin') return set({ permissions: buildMap('granted') });
        const granted = new Set(list.filter((p) => PERMISSIONS.includes(p)));
        set({
          permissions: PERMISSIONS.reduce(
            (acc, p) => ({ ...acc, [p]: granted.has(p) ? 'granted' : 'missing' }), {}
          ),
        });
      },

      markGranted: (perm) =>
        PERMISSIONS.includes(perm) &&
        set((s) => ({ permissions: { ...s.permissions, [perm]: 'granted' } })),

      markMissing: (perms) => {
        const list = Array.isArray(perms) ? perms : [perms];
        set((s) => {
          const next = { ...s.permissions };
          list.forEach((p) => { if (PERMISSIONS.includes(p)) next[p] = 'missing'; });
          return { permissions: next };
        });
      },

      has: (perm, role = 'user', allowUnknown = false) => {
        if (role === 'admin') return true;
        const status = get().permissions?.[perm] ?? 'unknown';
        if (status === 'granted') return true;
        if (status === 'missing') return false;
        return allowUnknown;              // unknown -> deny by default
      },

      getStatus: (perm) => get().permissions?.[perm] ?? 'unknown',
      reset: () => set({ permissions: UNKNOWN }),
    }),
    { name: 'permission-store', partialize: (s) => ({ permissions: s.permissions }) }
  )
);
```

### Three states, not two

`granted` / `missing` / `unknown` is the design decision that makes this work. A
boolean map forces every unfetched permission to read as `false`, which blanks the
entire UI for one frame after login. The third state lets a caller distinguish "the
user may not" from "we have not found out yet" and render a checking state instead
of a denial.

**`unknown` denies by default.** `allowUnknown` is an explicit opt-in for
low-stakes affordances where a hidden-but-allowed button is worse than a
shown-but-denied one.

## Inferring permissions from responses (fallback)

When the server offers no permission list, the axios interceptor can learn them:

```js
// success -> whatever permission this endpoint required, the user has
api.interceptors.response.use(
  (response) => {
    const perm = findPermissionForRequest(response.config);
    if (perm) usePermissionStore.getState().markGranted(perm);
    return response;
  },
  (error) => {
    if (error.response?.status === 403) {
      const perms = error.response.data?.required_permissions
                 ?? findPermissionForRequest(error.config);
      usePermissionStore.getState().markMissing(perms);
    }
    return Promise.reject(error);
  }
);
```

`findPermissionForRequest` maps a request to a permission with an ordered
method+regex table:

```js
const endpointPermissions = [
  { method: 'get',    matcher: /\/products\/index/,          permission: 'products.view' },
  { method: 'post',   matcher: /\/products\/create/,         permission: 'products.create' },
  { method: 'post',   matcher: /\/products\/update\//,       permission: 'products.edit' },
  { method: 'delete', matcher: /\/products\/delete\//,       permission: 'products.delete' },
];

export const findPermissionForRequest = (config = {}) => {
  const method = String(config.method || 'get').toLowerCase();
  const url = String(config.url || '');
  return endpointPermissions.find((e) => e.method === method && e.matcher.test(url))?.permission ?? null;
};
```

- **Order matters** — first match wins, so put specific patterns above general ones.
  `/\/products/` above `/\/products\/create/` swallows the specific case.
- **Prefer `required_permissions` from the 403 body** when the backend sends it;
  the server's own answer beats a regex guess.
- **Optional cold-start probing**: fire the safe `GET` endpoints once after login to
  populate `view` permissions before the user navigates. Probe reads only — never a
  `POST` or `DELETE` — and rate-limit it (one probe pass per 5 minutes) or every
  reload storms the API.

### State the drift risk where the catalog lives

This whole fallback is a client-side reconstruction of a server-side truth. Two
copies of one list will diverge: a permission renamed in the backend enum leaves
the frontend permanently reporting `unknown`, and the UI silently hides a feature
the user actually has.

Put the comment naming the backend file directly above the array, and prefer the
server list the moment it becomes available. `react-zustand-api-contract` describes
scripting the comparison.

## Route-level gating

```jsx
const RequirePermission = ({ permission, children, loadingFallback }) => {
  const role = useAuthStore((s) => s.user?.role) ?? 'user';
  const { has, getStatus } = usePermissionStore(
    useShallow((s) => ({ has: s.has, getStatus: s.getStatus }))
  );

  if (role === 'admin') return children;
  if (has(permission, role)) return children;
  if (getStatus(permission) === 'unknown') {
    return loadingFallback ?? <div className={styles.checking}>Checking permissions…</div>;
  }
  return <NoPermission permission={permission} />;
};
```

```jsx
<Route path="/admin/products" element={
  <RequirePermission permission="products.view">
    {withSuspense(Products)}
  </RequirePermission>
} />
```

`NoPermission` renders an explanatory panel naming the required permission — not a
redirect. Bouncing the user somewhere else with no explanation reads as a bug, and
a redirect from a linked page loops if the destination is also gated.

## Action-level gating

```jsx
const role = useAuthStore((s) => s.user?.role) ?? 'user';
const has = usePermissionStore((s) => s.has);
const can = (perm) => has(perm, role);

{can('products.create') && <Button icon={Plus} onClick={openCreate}>Add product</Button>}

<Button
  variant="danger"
  disabled={!can('products.delete')}
  title={can('products.delete') ? undefined : 'You do not have permission to delete products'}
  onClick={confirmDelete}
>
  Delete
</Button>
```

**Hide vs disable:**

- **Hide** a whole capability the user will never have — a nav item, a create
  button. A permanently disabled control is just clutter.
- **Disable with a tooltip** when the user could plausibly expect the action —
  a Delete beside rows they can otherwise edit. Silent disappearance reads as a bug.

Define `can` once per page. A `has(perm, role)` call scattered through JSX drifts
in its arguments.

## Navigation gating

```jsx
const NAV = [
  { to: '/admin/products', label: 'Products', icon: Package, permission: 'products.view' },
  { to: '/admin/orders',   label: 'Orders',   icon: ShoppingCart, permission: 'orders.view' },
];

{NAV.filter((item) => can(item.permission)).map(renderNavItem)}
```

Declare nav as data with its permission attached. A hand-written conditional per
item is where a link to a page the user cannot open eventually survives.

## Pitfalls

- **Treating the frontend check as security** — it is UX. The server enforces.
- **A two-state boolean map** — the UI blanks for a frame after login.
- **`unknown` defaulting to allow** — flashes buttons that immediately 403.
- **A general regex above a specific one** in the endpoint table — wrong permission
  attributed.
- **Probing with writes** — a permission probe that fires `DELETE` deletes something.
- **Unbounded probing** — every reload storms the API.
- **A hardcoded catalog with no drift note** — silently hides features after a
  backend rename.
- **Forgetting `reset()` on logout** — the next user inherits the previous one's
  permission map from `localStorage`.
- **Redirecting on denial** — reads as a bug and can loop. Explain instead.

## Related skills

- `react-zustand-auth-session` — roles, and where permissions are hydrated.
- `react-zustand-networking` — the interceptor doing the inference.
- `react-zustand-routing` — role guards, the coarser mechanism.
- `react-zustand-state` — catalog constants and `persist`.
- `react-zustand-api-contract` — scripting the frontend/backend catalog diff.
