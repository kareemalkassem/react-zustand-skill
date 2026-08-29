---
name: react-zustand-networking
description: Use when building or editing the axios layer of a React app — creating services/api.js, adding request/response interceptors, attaching auth or locale headers, handling global 401/403/5xx, extracting error messages from a response body, writing a service wrapper for a new endpoint, uploading FormData, or downloading a blob. Trigger on "axios", "interceptor", "API client", "base URL", "401", "error handling" in a React context.
---

# React + Zustand Networking

There is **one** axios instance in the project. Every cross-cutting network concern
lives on it, and nothing else in the codebase imports `axios`.

That constraint is what makes network behavior auditable: if a request lacks an
auth header, there is exactly one file to look at.

## The instance

`src/services/api.js` — created once, exported default, imported by every service.

```js
import axios from 'axios';
import NProgress from 'nprogress';
import { toast } from 'react-hot-toast';
import 'nprogress/nprogress.css';

NProgress.configure({ showSpinner: false, speed: 400, minimum: 0.2 });

const api = axios.create({
  baseURL: import.meta.env.VITE_API_URL || 'http://localhost:8000/api',
  headers: {
    'Content-Type': 'application/json',
    Accept: 'application/json',
  },
  withCredentials: false,
});

export default api;
```

- **Base URL comes from `import.meta.env.VITE_*`,** with a literal fallback for
  local dev. Never hardcode a production host in a service file.
- `withCredentials: false` for token auth. Only flip it for cookie/session auth,
  and then the backend must send matching CORS credentials headers.

## Request interceptor

Four jobs: start the progress bar, attach the token, attach ambient headers,
never throw.

```js
api.interceptors.request.use(
  (config) => {
    NProgress.start();
    try {
      const raw = localStorage.getItem('auth-storage');
      if (raw) {
        const { state } = JSON.parse(raw);
        if (state?.token) config.headers.Authorization = `Bearer ${state.token}`;
      }
      config.headers['X-Locale'] = localStorage.getItem('locale') || 'en';
    } catch (error) {
      console.error('Failed to read auth token', error);
    }
    return config;
  },
  (error) => {
    NProgress.done();
    return Promise.reject(error);
  }
);
```

**Read the token from persisted storage, not from the store module.** Importing the
auth store into `api.js` while the auth store imports `api.js` is a circular
import; in Vite it resolves to `undefined` at module-init time and the first
request of the session silently goes out unauthenticated. Reading the same
`localStorage` key that Zustand's `persist` writes breaks the cycle.

The key must match the store's `persist({ name })` exactly. If the store persists
under `auth-storage`, the interceptor reads `auth-storage`. Write that coupling as
a comment in both files — it is the one place a rename breaks auth silently.

**Wrap the body in `try`/`catch`.** A malformed `localStorage` value must not take
down every request in the app.

## Response interceptor

Owns every *global* failure. Module-specific failures belong to the store.

```js
api.interceptors.response.use(
  (response) => {
    NProgress.done();
    return response;
  },
  (error) => {
    NProgress.done();

    const status = error.response?.status;

    if (status === 401) {
      if (!window.location.pathname.includes('/login')) {
        toast.error('Session expired. Please login again.');
        localStorage.removeItem('auth-storage');
        setTimeout(() => { window.location.href = '/login'; }, 1000);
      }
    } else if (status >= 500) {
      toast.error('Server error. Please try again later.');
    } else if (error.code === 'ERR_NETWORK') {
      toast.error('Network error. Check your connection.');
    }

    return Promise.reject(error);
  }
);
```

Rules:

- **The interceptor always rethrows.** It handles presentation, never control flow.
  Swallowing here makes every awaiting store action resolve with `undefined`.
- **401 is the only status that navigates.** Guard it with a path check or a
  module-level flag, or a page firing five parallel requests produces five toasts
  and five redirects.
- **4xx other than 401/403 is not handled here.** A 422 is a form's business, a 404
  is a page's business. See `react-zustand-forms-validation`.
- **`window.location.href`, not `navigate()`.** The interceptor lives outside the
  router tree and has no access to its hooks. A hard navigation is also the correct
  behavior — it discards all in-memory state along with the dead session.

`NProgress.done()` must appear on all four interceptor paths. Miss one and the bar
sticks at 20% for the rest of the session.

## Service wrappers

One file per domain module. One function per endpoint. Nothing else.

```js
import api from './api';

const orderService = {
  getAll: async (params) => {
    const { data } = await api.get('/orders/index', { params });
    return data.data;
  },

  confirm: async (id) => {
    const { data } = await api.post(`/orders/${id}/confirm`);
    return data.data;
  },
};

export default orderService;
```

- **Unwrap the envelope here.** `data.data` for a `{ data, message, code }` API,
  plain `data` for a bare one. Whichever it is, the store never sees it.
- **No `try`/`catch`.** Rethrow by omission.
- **No `toast`.** No state. No JSX.
- **Params go through the `params` option,** never string-concatenated. axios
  encodes them and drops `undefined` keys.

### Role-aware base paths

When one resource is served under two role prefixes, resolve the prefix inside the
service rather than duplicating the file. This is the one sanctioned case of a
service reading a store:

```js
import { useAuthStore } from '../store/authStore';

const basePath = () =>
  useAuthStore.getState().user?.role === 'seller' ? '/seller/products' : '/admin/products';

const productService = {
  getAll: async (params) => {
    const { data } = await api.get(`${basePath()}/index`, { params });
    return data.data;
  },
};
```

Use `useAuthStore.getState()` — the non-reactive read. Calling the hook outside a
component is a hooks-rules violation and will throw.

Keep it to path selection. The moment role also changes the *shape* of the
response, split into two services.

## FormData and file uploads

```js
create: async (payload) => {
  const isForm = payload instanceof FormData;
  const { data } = await api.post('/products/create', payload,
    isForm ? { headers: { 'Content-Type': 'multipart/form-data' } } : {});
  return data.data;
},
```

- Build the `FormData` in the **page or a util**, not the service — the service
  stays shape-agnostic so it accepts JSON or multipart.
- Array fields use the backend's bracket convention: `formData.append('photos[]', file)`.
- Never set the multipart boundary yourself. Setting the header to the bare
  `multipart/form-data` string lets axios fill in the boundary; hand-writing the
  full value produces a malformed body.

Upload progress:

```js
importFile: async (file, { onUploadProgress } = {}) => {
  const form = new FormData();
  form.append('file', file);
  const { data } = await api.post('/products/import', form, {
    headers: { 'Content-Type': 'multipart/form-data' },
    onUploadProgress,
  });
  return data.data;
},
```

## Blob downloads

```js
downloadTemplate: async () => {
  const { data } = await api.get('/products/import-template', { responseType: 'blob' });
  return data;
},
```

`responseType: 'blob'` bypasses JSON parsing. Note the consequence: **an error
response is also a blob**, so `error.response.data.message` is unreadable. When a
download endpoint can fail meaningfully, read the blob back as text before
extracting the message.

The `URL.createObjectURL` / anchor-click / `revokeObjectURL` dance belongs in the
page, not the service. Services return data.

## Error extraction

One util, used by every store and form. Backends nest the useful message
differently per error class, so walk the shapes in priority order.

`src/utils/apiError.js`:

```js
export const extractApiErrorMessage = (error, fallback = 'Request failed') => {
  const data = error?.response?.data;

  if (data?.errors && typeof data.errors === 'object') {
    for (const value of Object.values(data.errors)) {
      if (Array.isArray(value) && value[0]) return String(value[0]);
      if (typeof value === 'string' && value.trim()) return value;
    }
  }
  if (typeof data?.error === 'string' && data.error.trim()) return data.error;
  if (typeof data?.message === 'string' && data.message.trim()) return data.message;
  if (typeof error?.message === 'string' && error.message.trim()) return error.message;

  return fallback;
};
```

Order matters: a validation `errors` map is more specific than the generic
`message` beside it, so it wins. The final `error.message` catches network errors,
which have no response at all.

For per-field form errors see `react-zustand-forms-validation`.

## Cancellation

React 18 Strict Mode double-invokes effects in dev. A page that fetches on mount
fires two requests; the slower one can land last and overwrite fresher state.

```js
useEffect(() => {
  const controller = new AbortController();
  fetchAll({ page }, { signal: controller.signal });
  return () => controller.abort();
}, [fetchAll, page]);
```

Thread the `signal` through the store action into the service's request config.
Then, in the store, ignore the resulting cancellation instead of rendering it as
an error:

```js
catch (error) {
  if (error.code === 'ERR_CANCELED') return;
  set({ error: extractApiErrorMessage(error), isLoading: false });
}
```

Add cancellation where a race actually exists — a search-as-you-type box, a filter
that refires on every keystroke. Do not thread signals through every call in the
app reflexively.

## Retry

Do not add a global retry interceptor. Retrying a non-idempotent POST duplicates
orders and payments, and axios interceptors cannot tell one POST from another.

If retry is genuinely needed, put it on the specific `GET` service function that
needs it, with a bounded attempt count and explicit backoff.

## Pitfalls

- **A second axios instance** — the second one has no interceptors and no auth.
- **Importing the auth store into `api.js`** — circular import, `undefined` token
  on the first request.
- **Swallowing in the response interceptor** — every awaiting caller resolves
  `undefined`.
- **Toasting in both the interceptor and the store** — two toasts, one failure.
- **`api.defaults.headers.common.Authorization` as the only token path** — it is
  lost on reload, so the interceptor must still read persisted storage. Setting it
  after login is a harmless optimization, not a substitute.
- **Forgetting `NProgress.done()` on an error path** — a permanently stuck bar.

## Related skills

- `react-zustand-core` — the four boundaries this layer sits at the bottom of.
- `react-zustand-auth-session` — what happens around the 401 path.
- `react-zustand-permissions` — deriving permission state from 403 responses.
- `react-zustand-forms-validation` — turning a 422 into field-level errors.
- `react-zustand-assets-media` — image upload validation before the request.
- `react-zustand-api-contract` — verifying service URLs against the backend.
- `react-zustand-testing` — mocking this instance with `axios-mock-adapter`.
