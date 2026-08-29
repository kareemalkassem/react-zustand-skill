---
name: react-zustand-gotchas
description: Use when designing, reviewing, or refactoring React+Zustand code and you want the consolidated anti-pattern list — boundary violations, selector bugs, styling drift, error-handling holes, form and effect traps. Read it before a code review, before a large refactor, or when something works but feels wrong.
---

# Anti-Patterns

Each entry: the mistake, why it bites, the fix. Ordered roughly by how expensive it
is to discover late.

Several are not hypothetical — they were found in a shipped production React
dashboard during the extraction that produced this skill family, and are marked
**[observed]**.

---

## Architecture

### 1. Two styling systems in one project **[observed]**

CSS Modules with a full token file *and* Tailwind with an empty `theme.extend`,
used ad hoc in a few components. The Tailwind classes could not reference the
tokens, so each hardcoded `text-gray-900`, `bg-red-50`.

**Why it bites:** a token change updates half the app. There is no longer a source
of truth, and no reviewer can tell which system a new component should use.

**Fix:** one system. Pick CSS Modules + `variables.css`, remove the other, and
state it in the repo's CLAUDE.md. `react-zustand-design-tokens`

### 2. Design docs quoting literal values **[observed]**

Docs stated primary `#4f46e5` and Inter; `variables.css` had `#f59f00` and Space
Grotesk. Anything generated from the docs shipped the wrong brand.

**Fix:** docs name the token (`--color-primary`), never the hex. The token file is
the answer.

### 3. `axios` imported outside `services/`

Bypasses every interceptor: no auth header, no progress bar, no global 401.

**Fix:** all HTTP through a service, all services through the one instance.
`react-zustand-networking`

### 4. Unwrapping the response envelope in the store **[observed]**

A store reaching into `response.data.data`, with a comment citing a backend PHP
class, has leaked transport into state. Every store then re-derives the same
knowledge.

**Fix:** unwrap in the service. The store receives domain data.

### 5. A second axios instance

The second one has no interceptors. Requests through it are unauthenticated and
invisible to global error handling.

### 6. `toast` in a store or service

`api.js` already toasts global failures. Two toasts for one failure.

**Fix:** global errors → interceptor. Module errors → `error` in the store, or a
`catch` in the page for a write.

### 7. Fat pages **[observed]**

Pages of 1,100 and 1,000 lines; one custom hook across 55 pages. Derived data,
FormData assembly, and debounce logic re-implemented per page.

**Fix:** past ~300 lines, extract. Derived data → a `useMemo` hook. Repeated
subcomponents → `components/`. `react-zustand-data-tables`

---

## Zustand

### 8. Multi-field select without `useShallow`

```js
const { items, isLoading } = useProductStore((s) => ({ items: s.items, isLoading: s.isLoading }));
```

New object every call → reference comparison always "changed" → re-render on every
write to any part of the store.

**Fix:** `useShallow`. `react-zustand-state`

### 9. Deriving inside a selector

```js
const active = useProductStore((s) => s.items.filter((i) => i.active));
```

Same bug, harder to see. Select `items`, derive with `useMemo`.

### 10. Selecting the whole store

`const store = useProductStore()` subscribes to everything.

### 11. Inconsistent action error contract **[observed]**

One store where `fetchProducts` swallowed into `error` and `addProduct` rethrew,
with no stated rule. Every call site had to read the store source to know which.

**Fix:** reads swallow, writes throw. Write the rule down. `react-zustand-core`

### 12. Persisting `isLoading` or `error`

Missing `partialize`, so the app reloads into a permanent spinner showing a stale
error.

### 13. Persisting server data

A cache with no invalidation. Persist the session and preferences only.

### 14. `logout` that clears only the auth store

The next user sees the previous user's rows for a frame — sometimes a real data
exposure, not a cosmetic glitch.

**Fix:** every domain store exposes `reset()`; `logout` calls them all.

### 15. Renaming the `persist` name without updating the interceptor

The axios request interceptor reads that `localStorage` key directly (to avoid a
circular import). A rename silently unauthenticates every request.

**Fix:** comment the coupling in both files.

### 16. Mutating store state in place

`state.items.push(x)` does not notify. Return new arrays and objects from `set`.

### 17. `getState()` where a subscription was needed

A snapshot. It never updates. Use the hook inside components.

### 18. Circular store imports

Two stores importing each other deadlock at module init in Vite. Keep the direction
one-way: domain stores may read the session store, never the reverse.

---

## Routing

### 19. A guard redirect without `replace`

The blocked URL stays in history; Back bounces forever.

### 20. Role checks that run before hydration

`user.role !== 'admin'` is true while `role` is `undefined`, redirecting the user
out of their own app on first paint.

**Fix:** `user?.role && !allowed.includes(user.role)`.

### 21. A page not `lazy()`-imported

Silently drags its whole import graph into the entry bundle. Nothing fails; the app
is just slower to start.

### 22. Filter state in `useState` only

Reload loses the view, links are not shareable. Mirror to `useSearchParams`.

### 23. `setSearchParams` without `{ replace: true }`

Every keystroke becomes a history entry; Back is character-by-character undo.

### 24. `useParams` string vs numeric id

`id` is always a string. `item.id === id` against a numeric id is silently always
false.

### 25. Router hooks in an interceptor

They throw — the interceptor is outside the router tree. Use `window.location.href`.

---

## Data & effects

### 26. Missing debounce cleanup

```js
useEffect(() => { const t = setTimeout(fetch, 500); }, [search]);   // no clearTimeout
```

Every keystroke fires. The cleanup **is** the debounce.

### 27. Filter change without resetting the page

Still on page 4 while the new result set has one page → empty table.

### 28. Loading checked before error

A failure that also cleared `isLoading` renders a blank page. Check `error` first.

### 29. One global `isSubmitting` for a whole table

Every row's button disables while one row saves. Key mutation state by row id.

### 30. Missing `stopPropagation` on a row-action button

Clicking Delete inside a clickable row also navigates.

### 31. Sorting the store's array in place

`items.sort()` mutates state without notifying. Sort a copy.

### 32. Selection surviving a filter change

A bulk delete acts on rows no longer visible. Clear selection when filters or page
change.

### 33. `window.confirm`

Unstyled, blocking, inconsistent, and it freezes browser automation. Use a `Modal`.

---

## Forms

### 34. A `useState` per field

N handlers, N stale-closure opportunities. One `values` object, one `setField`
factory.

### 35. Stale error under a corrected field

Clear a field's error as the user edits it.

### 36. No `noValidate` on the form

Browser-native bubbles duplicate your messages and cannot be styled.

### 37. `onClick` instead of `onSubmit`

Enter in a text field does nothing.

### 38. `submitting` not reset in `finally`

A `catch` that returns early leaves the button spinning forever.

### 39. A 422 with no field map and no fallback toast

Silent dead button. Always fall back to a toast.

### 40. `value={undefined}`

Switches the input between uncontrolled and controlled; React warns and keystrokes
are lost. Coerce to `''` or a string.

### 41. `||` defaults erasing legitimate falsy values

`price || ''` turns `0` into blank. Use `??`.

### 42. Array index as a key in a repeating field set

Removing a middle row makes React reuse the wrong DOM node; the user's typed value
jumps rows.

---

## Components

### 43. A raw `<button>` where the `Button` primitive exists

Loses loading, disabled, and focus styling.

### 44. Missing `type="button"`

HTML defaults to `submit`; a toolbar button inside a form silently submits it.

### 45. A loading button that is still clickable

Double submit. `disabled={disabled || isLoading}`.

### 46. Conditional class strings instead of `styles[variant]`

Drifts from the CSS the first time a variant is renamed.

### 47. `className` first in `clsx`

Callers cannot override.

### 48. Not spreading `...props`

Every new `aria-*` or `data-*` attribute requires editing the primitive.

### 49. `<div onClick>`

Not focusable, not keyboard-activatable, invisible to screen readers.

### 50. A `ui/` primitive reaching into a store

Primitives take props. Only pages and app composites subscribe.

---

## Media

### 51. `<img src="">`

Some browsers re-request the current page. Return `null` for a missing path and
render a fallback.

### 52. Object URLs never revoked

`URL.createObjectURL` leaks the full blob until revoked. Revoke on unmount and on
removal.

### 53. Hand-written multipart boundary

Set the bare `multipart/form-data` and let axios fill in the boundary.

### 54. Booleans in `FormData`

Stringified to `"false"`, which is truthy server-side. Send `1`/`0`.

### 55. Runtime-concatenated asset paths

`src={'/src/assets/' + name}` — Vite cannot see it, so the asset is never emitted.
Works in dev, 404s in production.

---

## Permissions

### 56. Treating the frontend check as security

It is a UX affordance. The server enforces.

### 57. A two-state permission boolean

Everything unfetched reads as denied, blanking the UI for a frame after login. Use
`granted` / `missing` / `unknown`.

### 58. A hardcoded permission catalog with no drift note **[observed]**

44 permission strings mirroring a backend enum, discovered by probing. A backend
rename leaves the frontend permanently `unknown`, silently hiding a feature the
user has.

**Fix:** prefer permissions returned by login. If you must mirror, name the backend
file in a comment and diff it in CI. `react-zustand-api-contract`

### 59. A permission probe that fires writes

A probe that sends `DELETE` deletes something. Probe reads only.

### 60. Redirecting on permission denial

Reads as a bug, and loops if the destination is also gated. Explain instead.

---

## Testing

### 61. No tests at all **[observed]**

No test runner in `package.json` for 34,000 lines. Every refactor is a gamble.

### 62. `setState` without the replace flag

Zustand merges; one test's leftovers make the next pass for the wrong reason. Use
`setState(initial, true)`.

### 63. Mocking `axios` instead of the project instance

Bypasses the interceptors, so the test proves nothing about the real path.

### 64. A test never seen failing

It may assert nothing. Break it deliberately once.

---

## Related skills

Each section maps to a skill with the full treatment: `react-zustand-core`,
`-networking`, `-state`, `-routing`, `-ui-conventions`, `-design-tokens`,
`-auth-session`, `-permissions`, `-data-tables`, `-forms-validation`,
`-assets-media`, `-performance`, `-testing`, `-api-contract`, `-debugging`.
