---
name: react-zustand-routing
description: Use when working on the router of a React SPA — building the route tree in App.jsx, adding a page and its route, code-splitting with lazy/Suspense, writing auth or role guards, nesting layouts with Outlet, redirecting by role, handling 404s, or storing filter/sort/page state in the URL with useSearchParams. Trigger on "route", "router", "navigate", "guard", "redirect", "URL params", "404" in a React context.
---

# Routing (react-router-dom v6/v7)

`App.jsx` is a route table. It declares the tree, the guards, and nothing else — no
data fetching, no store subscriptions beyond what a guard needs to make its
decision.

## The route tree

Guards are **routes**, not wrappers. A guard route renders `<Outlet />` when it
passes and `<Navigate />` when it does not, so a whole subtree is protected by one
line instead of a wrapper repeated per page.

```jsx
<Router>
  <Toaster position="top-right" />
  <Routes>
    <Route path="/login" element={withSuspense(Login)} />

    <Route element={<ProtectedRoute />}>          {/* authenticated only */}
      <Route element={<Layout />}>                {/* sidebar + header shell */}

        <Route element={<AdminRoute />}>          {/* role: admin | employee */}
          <Route path="/admin/dashboard" element={withSuspense(Dashboard)} />
          <Route path="/admin/products"  element={withSuspense(Products)} />
          <Route path="/admin/products/:id" element={withSuspense(ProductDetails)} />
        </Route>

        <Route element={<SellerRoute />}>         {/* role: seller */}
          <Route path="/seller/dashboard" element={withSuspense(SellerDashboard)} />
        </Route>

      </Route>
    </Route>

    <Route path="/" element={<RedirectBasedOnRole />} />
    <Route path="*" element={withSuspense(NotFound)} />
  </Routes>
</Router>
```

Read top to bottom: authenticated → inside the shell → allowed for this role →
the page. Each layer answers one question.

## Guards

```jsx
const ProtectedRoute = () => {
  const isAuthenticated = useAuthStore((s) => s.isAuthenticated);
  const location = useLocation();

  if (!isAuthenticated) {
    return <Navigate to="/login" state={{ from: location }} replace />;
  }
  return <Outlet />;
};

const AdminRoute = () => {
  const user = useAuthStore((s) => s.user);
  if (user?.role && !['admin', 'employee'].includes(user.role)) {
    return <Navigate to="/seller/dashboard" replace />;
  }
  return <Outlet />;
};
```

- **`replace` on every guard redirect.** Without it the blocked URL stays in
  history and Back bounces the user between guard and target forever.
- **Carry `state={{ from: location }}`** so login can return the user where they
  were headed.
- **Select one field.** A guard runs on every navigation; subscribing to the whole
  auth store re-renders the entire subtree on unrelated writes.
- **Guard on `user?.role &&`, not `!== 'admin'`.** During hydration `role` is
  briefly `undefined`; a bare inequality redirects the user out of their own app on
  first paint.

Guards decide *visibility of a route*. Permission checks inside a page are a
different concern — see `react-zustand-permissions`.

## Layout via `<Outlet />`

The shell is a route, not a wrapper component around every page.

```jsx
const Layout = () => (
  <div className={styles.shell}>
    <Sidebar />
    <div className={styles.main}>
      <Header />
      <main className={styles.content}><Outlet /></main>
    </div>
  </div>
);
```

The payoff: navigating between two pages under `Layout` remounts only the page.
The sidebar keeps its scroll position and its collapsed state, and nothing above
`<Outlet />` re-renders.

## Code splitting — every page

```jsx
import React, { Suspense, lazy } from 'react';

const Products = lazy(() => import('./pages/Products'));
const Orders   = lazy(() => import('./pages/Orders'));

const RouteFallback = () => (
  <div className={styles.routeFallback}>Loading page…</div>
);

const withSuspense = (Component) => (
  <Suspense fallback={<RouteFallback />}>
    {React.createElement(Component)}
  </Suspense>
);
```

- **Every page is `lazy()`.** No exceptions, including the dashboard — one page
  eagerly imported drags its whole import graph into the initial bundle.
- **One shared `withSuspense` helper**, so the fallback is identical everywhere.
- `React.createElement(Component)` rather than `<Component />` keeps the helper a
  plain function instead of a component, avoiding a remount on every parent render.
- Components are **not** lazy — only routes. Splitting a `Button` costs a request
  and saves nothing.

Route-level splitting pairs with vendor chunking in `vite.config.js`; see
`react-zustand-performance`.

## Navigation

- `useNavigate()` inside components and event handlers.
- `<Link>` / `<NavLink>` for anything a user should be able to open in a new tab.
  A `div` with `onClick={() => navigate(...)}` is not a link: no middle-click, no
  copy-link, no keyboard focus.
- `navigate(-1)` for Back; prefer an explicit destination when the page can be
  entered by deep link, since Back from a deep link leaves the app.
- Outside the router tree — interceptors, stores — use `window.location.href`.
  Router hooks are unavailable there, and a hard navigation is correct for session
  death anyway.

## The URL is the store for list state

Search, filters, sort, and current page belong in the query string, not `useState`.
Then a reload keeps the view, and a pasted link reproduces it.

```jsx
const [searchParams, setSearchParams] = useSearchParams();

const [search, setSearch]   = useState(searchParams.get('search') || '');
const [category, setCategory] = useState(searchParams.get('category') || 'All');
const [page, setPage]       = useState(parseInt(searchParams.get('page')) || 1);

// state -> URL
useEffect(() => {
  const params = new URLSearchParams();
  if (search) params.set('search', search);
  if (category !== 'All') params.set('category', category);
  if (page > 1) params.set('page', page);
  setSearchParams(params, { replace: true });
}, [search, category, page, setSearchParams]);
```

- **Seed `useState` from the URL once**, then mirror state back. Reading
  `searchParams` on every render instead makes the input lag a frame behind typing.
- **`{ replace: true }`.** Without it every keystroke pushes a history entry and
  Back becomes character-by-character undo.
- **Omit defaults.** `?page=1&category=All` is noise; an absent key means default.

Pair this with the debounced fetch effect in `react-zustand-data-tables`.

## Route params

```jsx
const { id } = useParams();

useEffect(() => { fetchOne(id); }, [fetchOne, id]);
```

`id` is always a **string**. Compare with `===` against strings, or coerce once at
the top. `item.id === id` where `item.id` is a number is silently always false.

## Route constants

Past ~15 routes, centralize the paths so a rename is one edit:

```js
export const ROUTES = {
  login: '/login',
  products: '/admin/products',
  productDetails: (id) => `/admin/products/${id}`,
};
```

Parameterized routes are functions, so call sites cannot mis-assemble them.

## Redirect-by-role landing

```jsx
const RedirectBasedOnRole = () => {
  const isAuthenticated = useAuthStore((s) => s.isAuthenticated);
  const user = useAuthStore((s) => s.user);
  if (!isAuthenticated) return <Navigate to="/login" replace />;
  return <Navigate to={user?.role === 'seller' ? '/seller/dashboard' : '/admin/dashboard'} replace />;
};
```

One component owns "where does `/` go", instead of that logic appearing in the
login handler, the guard, and the sidebar.

## 404

`<Route path="*" element={withSuspense(NotFound)} />` last. Note that it only
catches unmatched paths — a *matched* route whose entity does not exist (a valid
`/products/:id` for a deleted product) is the page's own empty state, not this.

## Pitfalls

- **A guard redirect without `replace`** — Back-button ping-pong.
- **`!== 'admin'` during hydration** — redirects the user out on first paint.
- **Selecting the whole auth store in a guard** — re-renders the app on any write.
- **A page not `lazy()`-imported** — silently inflates the initial bundle.
- **Filter state in `useState` only** — reload loses the view, links are not shareable.
- **`setSearchParams` without `replace`** — history spam.
- **`useParams` string vs numeric id** — comparisons silently always false.
- **Router hooks in an interceptor** — throws; use `window.location`.
- **Data fetching in `App.jsx`** — it is a route table. Fetching belongs in pages.

## Related skills

- `react-zustand-core` — where routing sits in the four boundaries.
- `react-zustand-auth-session` — what `isAuthenticated` means and when it flips.
- `react-zustand-permissions` — gating *within* an allowed route.
- `react-zustand-data-tables` — the debounced fetch that reads this URL state.
- `react-zustand-performance` — chunking alongside route splitting.
