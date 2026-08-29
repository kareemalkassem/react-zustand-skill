---
name: react-zustand-performance
description: Use when a React app feels slow or a bundle is too large — diagnosing unnecessary re-renders, scoping Zustand selectors, memoizing, splitting vendor chunks in Vite, virtualizing long lists, optimizing images, or profiling. Trigger on "slow", "laggy", "re-render", "bundle size", "performance", "optimize", "janky scroll" in a React context.
---

# Performance

**Measure before you optimize.** `React.memo` sprinkled on a guess costs
readability and buys nothing; the actual cause is usually one of four things, and
the profiler will tell you which within a minute.

Order of investigation:

1. Selector scope (Zustand) — most React+Zustand slowness is here
2. Bundle size and initial load
3. List size
4. Images

## 1. Selector scope

```js
const store = useProductStore();                                  // WORST
const items = useProductStore((s) => s.items);                    // fine
const { items, isLoading } = useProductStore((s) => ({ ... }));   // BROKEN
const { items, isLoading } = useProductStore(useShallow((s) => ({ ... })));  // correct
```

The third line is the common bug. The selector builds a **new object every call**;
Zustand compares by reference, sees a change, and re-renders — on every write to
any part of the store, including state this component never reads. In an app where
a poll or a socket writes every few seconds, that is the whole page re-rendering
continuously.

Also broken for the same reason:

```js
const active = useProductStore((s) => s.items.filter((i) => i.active));  // new array every call
```

Select `items`, derive with `useMemo`.

**Diagnose it**: React DevTools → Profiler → "Record why each component rendered".
A component re-rendering with identical props on an unrelated store write is a
selector problem, not a memo problem.

## 2. Bundle size

Measure first:

```bash
npm run build          # Vite prints per-chunk gzip sizes
npx vite-bundle-visualizer
```

**Route splitting** is the biggest single win and is already the convention — every
page is `lazy()` (see `react-zustand-routing`). One eagerly imported page pulls its
whole import graph into the entry chunk.

**Vendor chunking** for large, rarely-used libraries:

```js
// vite.config.js
build: {
  rollupOptions: {
    output: {
      manualChunks(id) {
        const path = id.split('\\').join('/');            // Windows separators
        if (!path.includes('/node_modules/')) return;
        if (path.includes('/xlsx/'))         return 'spreadsheet';
        if (path.includes('/qrcode.react/')) return 'qr';
        if (path.includes('/date-fns/'))     return 'date-utils';
        return 'vendor';
      },
    },
  },
}
```

The path normalization is not cosmetic — on Windows `id` uses backslashes and every
`includes('/node_modules/')` check fails silently, so the whole config no-ops.

Split by **usage pattern**, not size: a heavy library used on one page belongs in
its own chunk that only that page loads. Splitting React itself out of `vendor`
achieves nothing, since every page needs it.

Better still, `await import()` the heavy library at the call site:

```js
const handleExport = async () => {
  const { utils, writeFile } = await import('xlsx');   // downloaded on click, not on load
};
```

**Common weight**: `xlsx` (~400 kB), `moment` (replace with `date-fns`), whole-icon-set
imports (`import * as Icons` pulls thousands — import each icon by name), `lodash`
(import `lodash/debounce`, not `lodash`).

## 3. Long lists

| Rows | Approach |
|---|---|
| < 100 | Render them all. No optimization. |
| 100–500 | Paginate — server-side if the endpoint supports it |
| > 500 in one scroll | Virtualize with `@tanstack/react-virtual` |

Reach for virtualization only after pagination has been ruled out. Pagination is
simpler, cheaper, and usually the better UX anyway.

Cheaper wins for a list that already renders:

- **Stable keys** — `key={item.id}`, never the array index. Index keys make React
  patch the wrong DOM nodes on reorder or removal, which is both a correctness and
  a performance problem.
- **`React.memo` on the row component**, but only once the row is genuinely
  expensive and its props are stable. Memoizing a row whose `onClick` is a fresh
  arrow every render does nothing.
- **`useCallback` for row handlers** so the memo above actually holds.

## 4. Images

- Fixed dimensions or `aspect-ratio` on the container — otherwise every image that
  loads reflows the page below it.
- `loading="lazy"` on anything below the fold.
- Request server-sized thumbnails for a table. A 3000×2000 product photo scaled to
  40×40 in CSS still downloads and decodes at full size.
- Prefer WebP where the backend can serve it.

## `useMemo` / `useCallback` / `memo` — when

They are not free: each adds a dependency array to keep correct and a comparison to
run. Use them when:

- **`useMemo`** — the computation is genuinely expensive (filter+sort over hundreds
  of rows), **or** the result is an object/array passed to a memoized child or used
  in a dependency array. Referential stability is the more common reason.
- **`useCallback`** — the function is passed to a `memo`ised child or lives in a
  dependency array. Otherwise skip it.
- **`React.memo`** — an expensive component that re-renders with identical props.
  Verify with the profiler first.

Not worth it: memoizing `a + b`, memoizing a component that renders one `<span>`,
`useCallback` on a handler passed to a plain DOM element.

## Rendering costs that are not React's fault

- **A store write on every keystroke.** Keep input state local; write to the store
  on blur or submit.
- **An undebounced search effect.** One request per keystroke, one re-render per
  response. See `react-zustand-data-tables`.
- **Layout thrash** — reading `offsetHeight` in a loop that also writes styles.
  Batch reads before writes.
- **A `<Toaster>` or portal re-mounted inside a page** instead of at the root.

## Profiling checklist

1. React DevTools Profiler, record the slow interaction.
2. Sort by render duration. One expensive component, or many cheap ones?
3. Turn on "why did this render" — props changed / hook changed / parent rendered.
4. "Hook changed" on an unrelated store write → **selector problem** (§1).
5. "Parent rendered" with unchanged props → memo boundary candidate.
6. Nothing obvious in React → Chrome Performance tab. Long tasks in a library, a
   layout storm, or an image decode will show there and not in the React profiler.

## Pitfalls

- **Optimizing before measuring** — the usual outcome is complexity with no gain.
- **Multi-field select without `useShallow`** — the number-one cause.
- **Deriving inside a selector** — same bug, harder to spot.
- **`manualChunks` with unnormalized Windows paths** — silently no-ops.
- **`import * as Icons`** — pulls the entire icon set into the bundle.
- **Array index as key** — wrong-node patches on reorder.
- **`React.memo` with unstable prop identities** — always re-renders anyway.
- **Virtualizing when pagination would do** — complexity for nothing.
- **Storing derived data to "avoid recomputation"** — two sources of truth to keep
  in sync; `useMemo` is cheaper than that bug.

## Related skills

- `react-zustand-state` — selector rules in full.
- `react-zustand-routing` — route-level code splitting.
- `react-zustand-data-tables` — debounce and pagination.
- `react-zustand-assets-media` — image sizing and lazy loading.
- `react-zustand-debugging` — when slowness is actually a render loop.
