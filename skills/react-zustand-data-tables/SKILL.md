---
name: react-zustand-data-tables
description: Use when building a list or index page in a React app — tables of server data, search-as-you-type, filter dropdowns, server or client pagination, sortable columns, row actions, bulk selection, skeleton/empty/error states, or a useMemo hook for derived list data. Trigger on "list page", "table", "search", "filter", "pagination", "sort", "skeleton", "empty state" in a React context.
---

# List Pages & Data Tables

The list page is the most repeated screen in an admin or catalog app, and the one
that most often grows to a thousand lines. This skill fixes its anatomy so every
list page in a codebase reads the same.

## Anatomy

```
PageHeader          title, subtitle, primary action
SearchFilter        search input + filter selects
Table               header row, body rows, row actions
Pagination          page numbers, prev/next, item range
```

Plus the five states from `react-zustand-ui-conventions`: loading, empty, error,
disabled-while-mutating, success confirmation.

## The reference shape

```jsx
const Products = () => {
  const navigate = useNavigate();
  const [searchParams, setSearchParams] = useSearchParams();

  const { items, pagination, isLoading, error, fetchAll, remove } = useProductStore(
    useShallow((s) => ({
      items: s.items, pagination: s.pagination, isLoading: s.isLoading,
      error: s.error, fetchAll: s.fetchAll, remove: s.remove,
    }))
  );

  // URL-seeded view state
  const [search, setSearch]     = useState(searchParams.get('search') || '');
  const [category, setCategory] = useState(searchParams.get('category') || 'All');
  const [page, setPage]         = useState(parseInt(searchParams.get('page')) || 1);

  // mutation-in-flight state, keyed by row
  const [deleteTarget, setDeleteTarget] = useState(null);
  const [deleting, setDeleting] = useState(false);

  // debounced fetch
  useEffect(() => {
    const timer = setTimeout(() => {
      fetchAll({
        page,
        per_page: 10,
        ...(search ? { search } : {}),
        ...(category !== 'All' ? { category_id: category } : {}),
      });
    }, 500);
    return () => clearTimeout(timer);
  }, [fetchAll, page, search, category]);

  // mirror view state into the URL
  useEffect(() => {
    const params = new URLSearchParams();
    if (search) params.set('search', search);
    if (category !== 'All') params.set('category', category);
    if (page > 1) params.set('page', page);
    setSearchParams(params, { replace: true });
  }, [search, category, page, setSearchParams]);

  if (error) return <ErrorState message={error} onRetry={() => fetchAll({ page })} />;

  return (
    <>
      <PageHeader title="Products" actions={<Button icon={Plus} onClick={() => navigate('/products/new')}>Add</Button>} />
      <SearchFilter value={search} onChange={(v) => { setSearch(v); setPage(1); }}>
        <Select value={category} onChange={(e) => { setCategory(e.target.value); setPage(1); }}>…</Select>
      </SearchFilter>

      <Table>
        <Thead><Tr><Th>Name</Th><Th>Price</Th><Th /></Tr></Thead>
        <Tbody>
          {isLoading
            ? <TableRowSkeleton columns={3} rows={8} />
            : items.map((p) => (
                <Tr key={p.id} onClick={() => navigate(`/products/${p.id}`)}>
                  <Td>{p.name}</Td>
                  <Td>{formatMoney(p.price)}</Td>
                  <Td><Button variant="ghost" icon={Trash2}
                        onClick={(e) => { e.stopPropagation(); setDeleteTarget(p.id); }} /></Td>
                </Tr>
              ))}
        </Tbody>
      </Table>

      {!isLoading && !items.length && <EmptyState title="No products found" />}

      <Pagination
        currentPage={pagination?.current_page ?? page}
        lastPage={pagination?.last_page ?? 1}
        total={pagination?.total}
        perPage={pagination?.per_page}
        onPageChange={(next) => { setPage(next); window.scrollTo({ top: 0, behavior: 'smooth' }); }}
      />
    </>
  );
};
```

### Why each piece is shaped that way

- **`setPage(1)` on every filter change.** Changing a filter while on page 4 of the
  old result set asks the server for page 4 of a set that may have one page, and
  the table renders empty.
- **Conditional spread for optional params** — `...(search ? { search } : {})`
  keeps `?search=` out of the request entirely rather than sending an empty string,
  which many backends treat as a filter rather than an absence.
- **The debounce cleanup is what makes it a debounce.** `clearTimeout` on dep
  change is the mechanism; without it every keystroke fires.
- **Error is checked before loading.** A failure that also cleared `isLoading`
  otherwise renders a blank page.
- **`e.stopPropagation()` on a row-action button** inside a clickable row, or
  clicking Delete also navigates to the detail page.
- **Row-scoped mutation state** (`deleteTarget`, `publishingId`) rather than one
  global `isSubmitting` — a single flag disables every row's button while one row
  is saving.

## Client-side vs server-side

| Rows | Approach |
|---|---|
| Bounded and small (< ~200, e.g. a category list) | Fetch all, filter and sort in `useMemo` |
| Unbounded or large | Server-side: `page`, `per_page`, `search`, `sort` as params |

Do not mix. A page that paginates server-side but filters the *current page* in
JavaScript shows the user "3 results" out of a matching 400.

## Derived data belongs in a hook

Once mapping, filtering, and sorting exceed a few lines, move them out of the page:

```js
export const useFilteredCustomers = (customers, search, verified, sort) =>
  useMemo(() => {
    if (!Array.isArray(customers)) return [];

    let rows = customers.map((c) => ({
      ...c,
      name: c.name || c.full_name || '',
      hasOrders: (c.orders_count ?? 0) > 0,
    }));

    const q = (search || '').toLowerCase();
    rows = rows.filter((c) =>
      (c.name.toLowerCase().includes(q) || (c.phone ?? '').includes(q)) &&
      (verified === 'All' || (verified === 'Verified') === Boolean(c.verified))
    );

    if (sort.key) {
      rows.sort((a, b) => {
        const [x, y] = [a[sort.key] ?? '', b[sort.key] ?? ''];
        const cmp = typeof x === 'number' && typeof y === 'number'
          ? x - y
          : String(x).toLowerCase().localeCompare(String(y).toLowerCase());
        return sort.direction === 'ascending' ? cmp : -cmp;
      });
    }
    return rows;
  }, [customers, search, verified, sort]);
```

Map → filter → sort, in that order, one `useMemo`. Guard the input array — a store
that has not loaded yet holds `[]`, but a store mid-error may hold `undefined`.

**Never sort in place.** `customers.sort()` mutates the store's array; here `rows`
is already a fresh array from `.map()`, which is what makes the `.sort()` safe.
State that in a comment when it is not obvious.

## Pagination component

Controlled, dumb, no data access:

```jsx
<Pagination currentPage={n} lastPage={n} total={n} perPage={n} onPageChange={fn} />
```

Show the item range ("Showing 11–20 of 143") — it is the cheapest way for a user to
tell whether a filter did anything. Scroll to top on page change; leaving the user
mid-scroll on a fresh page is disorienting.

## Skeletons

Match the real row: same column count, same height.

```jsx
export const TableRowSkeleton = ({ columns = 4, rows = 5 }) =>
  Array.from({ length: rows }, (_, r) => (
    <Tr key={r}>
      {Array.from({ length: columns }, (_, c) => (
        <Td key={c}><div className={styles.skeleton} /></Td>
      ))}
    </Tr>
  ));
```

A spinner where a table will appear causes a layout jump when data lands; a
matched skeleton does not. Keep the shimmer subtle and honour
`prefers-reduced-motion`.

## Bulk selection

```jsx
const [selected, setSelected] = useState(() => new Set());

const toggle = (id) => setSelected((prev) => {
  const next = new Set(prev);
  next.has(id) ? next.delete(id) : next.add(id);
  return next;                     // new Set — mutating the old one will not re-render
});
```

Use a `Set`, always return a new one, and **clear the selection whenever the filter
or page changes** — otherwise a bulk delete silently acts on rows scrolled out of
view. Show the count in the action bar (`Delete 3 selected`) so the scope is never
ambiguous.

## Destructive actions

Always a confirmation modal, never `window.confirm` (unstyled, blocking, and it
freezes browser automation). Name the entity in the prompt, disable the confirm
button while the request is in flight, and `toast.success` after.

```jsx
<Modal isOpen={!!deleteTarget} onClose={() => setDeleteTarget(null)} title="Delete product?">
  <p>This cannot be undone.</p>
  <Button variant="danger" isLoading={deleting} onClick={handleDelete}>Delete</Button>
</Modal>
```

Since `remove` is a write action it throws, so the page owns the `try`/`catch`, the
toast, and resetting `deleting` in a `finally`.

## Exports

Generate the file in a util, not the page, and lazy-import the heavy library so it
stays out of the main bundle:

```js
const { utils, writeFile } = await import('xlsx');
```

Export what the user is *looking at* — the filtered set — or offer both and label
them. Silently exporting all 10,000 rows when the screen shows 12 is a surprise.

## Pitfalls

- **No `setPage(1)` on filter change** — empty table from an out-of-range page.
- **Missing debounce cleanup** — a request per keystroke.
- **Loading checked before error** — blank page on failure.
- **Client filtering over a server-paginated page** — wrong result counts.
- **One global `isSubmitting`** — every row's button disables at once.
- **No `stopPropagation` on row actions** — Delete navigates.
- **Sorting the store array in place** — mutation without a re-render.
- **Selection surviving a filter change** — bulk action hits invisible rows.
- **`window.confirm`** — unstyled and blocks automation.
- **A 1,000-line list page** — the derived data belongs in a hook, the rows in a
  component.

## Related skills

- `react-zustand-routing` — URL as filter state, `useSearchParams`.
- `react-zustand-ui-conventions` — `Table`, `Button`, `Modal`, the five states.
- `react-zustand-state` — the store shape backing the list.
- `react-zustand-performance` — long lists, virtualization, render cost.
- `react-zustand-forms-validation` — the create/edit page the Add button opens.
