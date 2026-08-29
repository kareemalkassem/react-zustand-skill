---
name: react-zustand-debugging
description: Use when diagnosing a bug in a React+Zustand app — infinite re-render loops, a component not updating when the store changes, requests firing repeatedly, a 401 redirect loop, blank screens, hydration and reload bugs, or a build that works in dev but breaks in production. Trigger on "not updating", "infinite loop", "too many renders", "blank page", "works in dev but not prod", "why is this firing twice".
---

# Debugging

Form a hypothesis before changing anything. "What would have to be true for this
symptom to appear?" narrows the search far faster than editing and re-running.

Each section below is a symptom, its likely causes ordered by frequency, and the
observation that distinguishes them.

---

## "Too many re-renders" / the page freezes

**Almost always `setState` during render, or an unstable effect dependency.**

1. **`setState` called in the render body**, not in a handler or effect. Look for a
   bare `setX(...)` at the top level of the component.
2. **An effect that sets state it also depends on:**
   ```js
   useEffect(() => { setCount(count + 1); }, [count]);   // loop
   ```
3. **An unstable value in a dependency array** — an inline object, array, or arrow:
   ```js
   const load = () => fetchAll({ page });
   useEffect(() => { load(); }, [load]);                 // new identity each render
   ```
   Zustand actions are stable, so `[fetchAll]` is safe; a wrapper around one is not.
4. **A selector returning a new reference** (see below) combined with an effect on
   that value.

**Distinguish:** comment out the effect. Loop stops → it is the effect. Loop
continues → it is a render-body `setState`.

---

## A component does not update when the store changes

1. **`getState()` where a subscription was needed.** `useProductStore.getState().items`
   is a snapshot read at render time; it never re-runs. Use the hook form.
2. **State mutated in place.** `state.items.push(x)` inside `set` changes the array
   without changing its reference, so no subscriber is notified. Return a new array.
3. **The selector reads a different field than the action writes** — a typo like
   `s.item` vs `s.items` returns `undefined` silently and forever.
4. **Two store instances.** A duplicated `create()` call, or the same store imported
   through two different paths (`../store/x` and `../../store/x` resolving
   differently, or a case mismatch on a case-insensitive filesystem).

**Distinguish:** in the browser console, `useProductStore.getState()` after the
action. Data present but UI stale → subscription problem (1, 2, or 4). Data absent
→ the action failed; check the network tab.

---

## Everything re-renders on any store write

The multi-field selector without `useShallow`. See `react-zustand-performance` §1.

**Confirm:** React DevTools Profiler → "why did this render" shows *hook changed*
on a component whose displayed data did not change.

---

## The same request fires repeatedly

1. **Missing debounce cleanup** — no `clearTimeout` in the effect's return.
2. **An unstable dependency** re-running the effect every render (see above).
3. **React 18 Strict Mode** double-invokes effects in development. Exactly two
   requests in dev and one in a production build is expected, not a bug.
4. **An effect depending on a value the effect itself changes.**

**Distinguish:** exactly 2 in dev / 1 in prod → Strict Mode, ignore. Unbounded →
dependency or cleanup problem.

---

## 401 redirect loop, or a toast storm on login

1. **The login request's own 401 hitting the global handler.** Wrong credentials
   are not an expired session. Exclude the login endpoint — by path, or by checking
   whether the failed request carried an `Authorization` header. A pre-auth 401
   must render inline on the form.
2. **No re-entry guard.** Six parallel requests against a dead token produce six
   toasts and six navigations. Guard with a path check or a module-level flag.
3. **The token is being sent but rejected** — check the base URL. A token issued by
   staging sent to production 401s forever.
4. **`persist` key mismatch.** The store persists under one name and the request
   interceptor reads another, so every request goes out unauthenticated and every
   response is a 401.

**Distinguish:** network tab. `Authorization` header absent → (4). Present but
rejected → (3). Present and only on the login call → (1).

---

## Logged out after a reload

1. **A `useEffect` "restoring" the session.** It runs after first paint, so the
   guard has already redirected. `persist` rehydrates synchronously — delete the
   effect.
2. **`partialize` omitting `token` or `isAuthenticated`.**
3. **The token stored in memory only** — an `api.defaults.headers` assignment with
   no persistence.

**Distinguish:** check `localStorage['auth-storage']` after a reload. Present but
logged out → (1). Absent or incomplete → (2) or (3).

---

## Blank page, no error

1. **`error` checked after `isLoading`.** A failure that also cleared `isLoading`
   renders neither branch.
2. **A render threw** and no `ErrorBoundary` caught it. Check the console; add a
   boundary at the layout level.
3. **A guard redirected to a route that redirects back** — an empty render between
   two `<Navigate>`s.
4. **A lazy chunk failed to load** (deploy replaced the file the open tab was
   pointing at). Console shows a dynamic-import error; reload fixes it. Catch it
   with an error boundary that offers a reload.

---

## Data is there but renders empty

1. **Field name mismatch** after a backend rename — `full_name` vs `name`. See
   `react-zustand-api-contract`.
2. **The envelope shape changed** and the unwrap now returns `undefined`. Log the
   raw `response.data` in the service.
3. **A mirrored enum drifted** — an unknown status maps to `undefined` in the label
   table and renders blank.
4. **`useParams` id is a string** and the comparison against a numeric id is always
   false.

---

## Works in dev, breaks in production

1. **Runtime-concatenated asset paths.** Vite cannot see them, so the asset is
   never emitted.
2. **An env var without the `VITE_` prefix.** Only `VITE_*` is exposed to client
   code; anything else is `undefined` in the build.
3. **Case-sensitive imports.** `./components/button` resolves on Windows and macOS,
   404s on a Linux host.
4. **`manualChunks` path checks failing on Windows separators**, so the chunk config
   silently no-ops.
5. **A dev-only proxy** in `vite.config.js` that production does not have — the app
   calls a relative path that only existed behind the dev server.

**Distinguish:** run `npm run build && npm run preview` locally. It reproduces
almost all of these.

---

## Form silently does nothing on submit

1. **`onClick` instead of `onSubmit`,** so Enter does nothing.
2. **Missing `type="submit"`** on the button.
3. **A validation failure with no visible message** — the error landed under a
   field scrolled off-screen, or on a key that does not match a rendered input.
4. **A 422 with no field map and no fallback toast.**
5. **`submitting` never reset,** so the button is permanently disabled after the
   first failure.

---

## Tooling

- **React DevTools → Components**: inspect props and hook values live.
- **React DevTools → Profiler**, with "record why each component rendered" on: the
  fastest way to separate a selector problem from a memo problem.
- **Network tab**: the authority on what was actually sent. Check the URL, the
  method, the `Authorization` header, and the raw response body — not what the
  service *should* have sent.
- **Console `useXStore.getState()`**: stores are module singletons and readable
  from the console at any time.
- **`useXStore.subscribe(console.log)`** temporarily, to see every write.
- **`npm run build && npm run preview`**: reproduces production-only failures.
- **`git bisect`** when a regression's origin is unclear and the symptom is
  reproducible.

## Method

1. **Reproduce reliably.** An intermittent bug you cannot trigger cannot be
   verified as fixed.
2. **State the hypothesis** — one sentence: "the selector returns a new object, so
   the component re-renders on every write."
3. **Find the cheapest observation that falsifies it** — a console log, a profiler
   flag, one network request.
4. **Change one thing.** Two changes and a fix means you do not know which worked.
5. **Write the failing test**, watch it fail, then fix. `react-zustand-testing`
6. **Remove the debugging scaffolding** before committing.

## Related skills

- `react-zustand-gotchas` — the anti-pattern list most of these map to.
- `react-zustand-performance` — profiling and selector scope.
- `react-zustand-state` — subscription semantics.
- `react-zustand-networking` — interceptors and the 401 path.
- `react-zustand-api-contract` — endpoint and shape mismatches.
- `react-zustand-testing` — pinning the fix.
