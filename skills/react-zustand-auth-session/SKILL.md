---
name: react-zustand-auth-session
description: Use when building login, logout, session restore on reload, token storage, role-based landing, or global 401 handling in a React SPA. Trigger on "login", "logout", "auth", "token", "session", "sign in", "remember me", "401", "refresh token" in a React context.
---

# Auth & Session

The session is one persisted Zustand store, one axios interceptor, and one guard
route. Anything more distributed produces the classic bugs: a reload that logs the
user out, a logout that leaves stale rows on screen, or five redirect loops from
one expired token.

## The auth store

```js
import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import authService from '../services/authService';
import { usePermissionStore } from './permissionStore';

export const useAuthStore = create(
  persist(
    (set) => ({
      user: null,
      token: null,
      isAuthenticated: false,
      isLoading: false,
      error: null,

      login: async (email, password) => {
        set({ isLoading: true, error: null });
        try {
          const response = await authService.login({ email, password });

          const token = response.data?.token ?? response.token;
          const role  = response.data?.role  ?? response.role ?? 'user';
          const permissions = response.data?.permissions ?? response.permissions ?? [];

          if (!token) throw new Error('Token missing from login response');

          const user = {
            id: response.data?.id ?? response.id,
            name: response.data?.name ?? response.name ?? '',
            email,
            role,
            permissions,
          };

          usePermissionStore.getState().hydrate(role, permissions);

          set({ user, token, isAuthenticated: true, isLoading: false });
          return { success: true };
        } catch (error) {
          const fieldErrors = error.response?.data?.errors ?? {};
          set({
            error: fieldErrors.email?.[0]
                ?? fieldErrors.password?.[0]
                ?? error.response?.data?.message
                ?? 'Invalid credentials',
            isLoading: false,
          });
          return { success: false, errors: fieldErrors };
        }
      },

      logout: () => {
        set({ user: null, token: null, isAuthenticated: false });
        localStorage.removeItem('auth-storage');
        usePermissionStore.getState().reset();
        // every domain store exposes reset() — call them here
      },

      clearError: () => set({ error: null }),
    }),
    {
      name: 'auth-storage',
      partialize: (s) => ({ user: s.user, token: s.token, isAuthenticated: s.isAuthenticated }),
    }
  )
);
```

Notes that matter:

- **`login` returns a result object, it does not throw.** Login failure is expected
  input, not an exception. The page reads `{ success, errors }` and paints field
  errors. This is the one deliberate exception to the write-actions-throw rule in
  `react-zustand-core`, and it is worth stating in a comment where you make it.
- **`partialize` excludes `isLoading` and `error`.** Persisting them means the app
  reloads into a spinner showing a week-old error.
- **`??` not `||` when reading the response.** A legitimate `0` id or empty-string
  name is not a missing value.
- **Throw explicitly when the token is absent.** A 200 response with no token
  otherwise produces a "logged in" state that 401s on every subsequent request.
- **`logout` resets dependent stores.** Without that, logging out and back in as a
  different user shows the previous user's data for a frame — occasionally a real
  data-exposure bug, not just a cosmetic one.

## Session restore on reload

There is nothing to do. `persist` rehydrates `token` and `isAuthenticated` from
`localStorage` synchronously before the first render, the guard route reads
`isAuthenticated`, and the axios interceptor reads the same persisted key.

Do **not** write a `useEffect` in `App.jsx` that re-reads the token and calls
`setState`. It runs after first paint, so the app flashes the login screen and
then jumps to the dashboard.

If the app must validate the token against the server on boot, do it *without*
gating first paint: render the app optimistically from the persisted session, fire
a `GET /me`, and let the ordinary 401 path handle rejection.

## Token storage

`localStorage` via `persist` is the pragmatic default for a token-auth SPA, and
what this family assumes. Understand the trade: any XSS on the origin can read it.

- If the threat model does not accept that, the answer is **httpOnly cookies**,
  which changes the whole stack: `withCredentials: true`, CSRF tokens, backend CORS
  credentials. Do not half-migrate.
- `sessionStorage` narrows exposure to one tab and drops the session on tab close.
  Choose it only if that behavior is actually desired.
- **Never store a password, a PIN, or a full card number.** Only the token and
  non-sensitive profile fields.

## The login page

```jsx
const Login = () => {
  const { login, isLoading, error, clearError } = useAuthStore(
    useShallow((s) => ({ login: s.login, isLoading: s.isLoading, error: s.error, clearError: s.clearError }))
  );
  const navigate = useNavigate();
  const location = useLocation();
  const [fieldErrors, setFieldErrors] = useState({});

  const handleSubmit = async (e) => {
    e.preventDefault();
    clearError();
    const result = await login(email, password);
    if (result.success) {
      navigate(location.state?.from?.pathname || '/', { replace: true });
    } else {
      setFieldErrors(extractFieldErrors(result.errors));
    }
  };
};
```

- **Honour `location.state.from`** — the guard stored where the user was headed.
- **`replace: true`** so Back does not return to the login form.
- The password field is `type="password"` with `autoComplete="current-password"`;
  the email field `autoComplete="username"`. Password managers depend on both.

## Logout

Client-side only when the backend uses stateless bearer tokens: clear the store,
clear persisted storage, reset dependents, navigate to `/login`.

Call the server's logout endpoint only if it actually revokes the token
server-side. If it does, **do not block the UI on it** — clear local state first,
fire the request, and ignore its failure. A user clicking Logout on a dead network
must still end up logged out.

## Global 401

Owned entirely by the axios response interceptor (see `react-zustand-networking`).
Never handle 401 in a store action or a page — you would be writing the fourth
copy of it.

```js
if (status === 401 && !window.location.pathname.includes('/login')) {
  toast.error('Session expired. Please login again.');
  localStorage.removeItem('auth-storage');
  setTimeout(() => { window.location.href = '/login'; }, 1000);
}
```

- **Guard against re-entry.** A dashboard firing six parallel requests against an
  expired token otherwise produces six toasts and six navigations. The path check
  is the minimum; a module-level `isHandling401` flag is better.
- **A 401 from the login request itself is not a session expiry.** It is wrong
  credentials, and it must render inline on the form. Exclude the login endpoint
  explicitly — either by the path check above or by checking whether the failed
  request carried an `Authorization` header. A pre-auth 401 never triggers the
  global logout.
- **Hard-navigate.** The interceptor is outside the router, and discarding all
  in-memory state along with the dead session is correct.

## Roles

Role lives on `user.role` and drives three things, each in exactly one place:

1. **Which routes exist** — guard routes in `App.jsx` (`react-zustand-routing`).
2. **Where `/` lands** — one `RedirectBasedOnRole` component.
3. **Which API prefix a service uses** — resolved inside the service
   (`react-zustand-networking`).

Fine-grained per-action rights are a separate concern; see
`react-zustand-permissions`.

## Refresh tokens

Only if the backend issues them. The shape is a response interceptor that, on 401,
queues the failed request, calls the refresh endpoint **once**, and replays the
queue.

Two rules make it work: the refresh call must not go through the same interceptor
(infinite recursion), and concurrent 401s must share one in-flight refresh promise
rather than each firing their own. Without a shared promise, six parallel 401s fire
six refreshes and five of them invalidate the token the sixth just issued.

If the backend has no refresh endpoint, do not simulate one. Expiry → logout.

## Pitfalls

- **A `useEffect` restoring the session** — flash of the login screen. `persist`
  already did it.
- **Persisting `isLoading`** — reloads into a stuck spinner.
- **A 401 handler in a store or page** — duplicate logouts.
- **The login 401 hitting the global handler** — the user gets "session expired"
  instead of "wrong password".
- **No re-entry guard on 401** — a toast storm.
- **`logout` that only clears the auth store** — previous user's data still on screen.
- **Renaming the `persist` name without updating the interceptor** — every request
  silently unauthenticated.
- **Reading `role` before hydration with a bare `!==`** — redirects the user out of
  their own app on first paint. Use `user?.role && !allowed.includes(user.role)`.

## Related skills

- `react-zustand-networking` — the interceptor that owns the 401 path.
- `react-zustand-state` — `persist`, `partialize`, cross-store reset.
- `react-zustand-routing` — guard routes and role-based landing.
- `react-zustand-permissions` — per-action rights within an allowed route.
- `react-zustand-forms-validation` — rendering the login field errors.
