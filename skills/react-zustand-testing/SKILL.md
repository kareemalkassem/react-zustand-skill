---
name: react-zustand-testing
description: Use when writing or running tests for a React app — setting up Vitest and React Testing Library, testing a Zustand store's actions, mocking the axios instance, testing a component's loading/empty/error states, testing a form submit and its 422 path, or deciding what is worth testing at all. Trigger on "test", "vitest", "jest", "RTL", "mock", "coverage" in a React context.
---

# Testing

A test that passes whether or not the code is correct is worse than no test — it
costs maintenance and buys false confidence. Before writing one, know what change
would make it fail.

## Setup

```
npm i -D vitest @vitest/ui jsdom @testing-library/react @testing-library/user-event @testing-library/jest-dom axios-mock-adapter
```

```js
// vite.config.js
export default defineConfig({
  plugins: [react()],
  test: {
    environment: 'jsdom',
    globals: true,
    setupFiles: './src/test/setup.js',
    css: true,                    // CSS Modules resolve; styles.x is a string, not undefined
  },
});
```

```js
// src/test/setup.js
import '@testing-library/jest-dom';
import { afterEach, vi } from 'vitest';
import { cleanup } from '@testing-library/react';

afterEach(() => {
  cleanup();
  localStorage.clear();
  vi.clearAllMocks();
});
```

```json
"scripts": { "test": "vitest run", "test:watch": "vitest", "test:ui": "vitest --ui" }
```

`css: true` matters: without it every `styles.foo` is `undefined`, so class-based
queries silently match nothing.

## What is worth testing

| Priority | Target | Why |
|---|---|---|
| High | Store actions | Pure logic, no DOM, fast, and where the bugs are |
| High | Utils (`apiError`, `validation`, formatters) | Pure functions, cheapest tests in the repo |
| High | Form submit paths, including the 422 branch | Highest-consequence user flow |
| Medium | Components with branching states | Loading, empty, error, permission-denied |
| Low | Services | Nearly all pass-through; test only real transformation |
| Skip | Presentational components with no logic | Asserting a `<div>` renders proves nothing |

## Testing a store

Zustand stores are plain functions — no React needed.

```js
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { useProductStore } from '../store/productStore';
import productService from '../services/productService';

vi.mock('../services/productService');

const initial = useProductStore.getState();

describe('productStore', () => {
  beforeEach(() => {
    useProductStore.setState(initial, true);   // `true` REPLACES — a merge leaks state between tests
    vi.clearAllMocks();
  });

  it('stores items and pagination on a successful fetch', async () => {
    productService.getAll.mockResolvedValue({
      items: [{ id: 1, name: 'Widget' }],
      pagination: { current_page: 1, last_page: 3 },
    });

    await useProductStore.getState().fetchAll({ page: 1 });

    const state = useProductStore.getState();
    expect(state.items).toHaveLength(1);
    expect(state.pagination.last_page).toBe(3);
    expect(state.isLoading).toBe(false);
    expect(state.error).toBeNull();
  });

  it('swallows a read failure into error and clears loading', async () => {
    productService.getAll.mockRejectedValue({
      response: { data: { message: 'Server exploded' } },
    });

    await expect(useProductStore.getState().fetchAll({})).resolves.toBeUndefined();

    expect(useProductStore.getState().error).toBe('Server exploded');
    expect(useProductStore.getState().isLoading).toBe(false);
  });

  it('rethrows a write failure so the page can render it', async () => {
    productService.create.mockRejectedValue(new Error('nope'));
    await expect(useProductStore.getState().create({})).rejects.toThrow('nope');
  });
});
```

Those last two tests are the ones that earn their keep: they pin the read/write
error contract, and they fail the moment someone adds a `try`/`catch` to a write
action or a `throw` to a read.

**`setState(initial, true)` with the replace flag.** Without `true` it merges, so a
store polluted by an earlier test keeps its rows and the next test passes for the
wrong reason.

## Mocking the axios instance

Two levels. Prefer the first.

**Mock the service** when testing a store — you are testing state transitions, not
HTTP.

**Mock the instance** when testing the interceptors themselves:

```js
import MockAdapter from 'axios-mock-adapter';
import api from '../services/api';

const mock = new MockAdapter(api);
afterEach(() => mock.reset());

it('attaches the bearer token from persisted storage', async () => {
  localStorage.setItem('auth-storage', JSON.stringify({ state: { token: 'abc123' } }));
  mock.onGet('/products/index').reply((config) => {
    expect(config.headers.Authorization).toBe('Bearer abc123');
    return [200, { data: { items: [] } }];
  });

  await productService.getAll();
});
```

`new MockAdapter(api)` — the project instance, not `axios`. Mocking the default
export bypasses every interceptor, so the test proves nothing about the real path.

## Testing a component

```jsx
const renderPage = (ui, { route = '/' } = {}) =>
  render(<MemoryRouter initialEntries={[route]}>{ui}</MemoryRouter>);

it('renders the error state and retries on click', async () => {
  useProductStore.setState({ error: 'Network error', items: [] });
  const user = userEvent.setup();
  const fetchAll = vi.fn();
  useProductStore.setState({ fetchAll });

  renderPage(<Products />);

  expect(screen.getByText('Network error')).toBeInTheDocument();
  await user.click(screen.getByRole('button', { name: /retry/i }));
  expect(fetchAll).toHaveBeenCalled();
});
```

- **Query by role and accessible name**, not by class or `data-testid`. `getByRole('button', { name: /save/i })`
  fails when the button loses its label — which is also a real accessibility
  regression. A `testid` query passes right through that.
- **`userEvent`, not `fireEvent`.** `userEvent` fires the full sequence a real user
  produces (pointerdown, focus, keydown, input); `fireEvent` dispatches one
  synthetic event and misses focus and typing bugs.
- **`findBy*` for anything async.** `getBy*` throws immediately; `findBy*` retries.
- Wrap in `MemoryRouter` for anything using router hooks.
- Set store state directly with `setState` — do not render a login flow to reach a
  logged-in page.

## Testing a form's 422 path

The highest-value component test in a CRUD app:

```jsx
it('shows the server field error under the input', async () => {
  const user = userEvent.setup();
  const create = vi.fn().mockRejectedValue({
    response: { status: 422, data: { errors: { name: ['Name already taken'] } } },
  });
  useProductStore.setState({ create });

  renderPage(<ProductForm />);
  await user.type(screen.getByLabelText(/name/i), 'Widget');
  await user.click(screen.getByRole('button', { name: /save/i }));

  expect(await screen.findByText('Name already taken')).toBeInTheDocument();
  expect(screen.getByRole('button', { name: /save/i })).not.toBeDisabled();
});
```

The second assertion is the one that catches the real bug: a `catch` that returns
before resetting `submitting` leaves the button spinning forever.

## Timers

For debounced search, fake the clock — do not `await` a real 500 ms:

```js
vi.useFakeTimers();
await user.type(input, 'wid');
vi.advanceTimersByTime(500);
expect(fetchAll).toHaveBeenCalledTimes(1);
vi.useRealTimers();
```

Assert **once**, not just "called". The whole point of the debounce is that three
keystrokes produce one request.

## Prove the test fails first

For a bug fix, write the test, run it, watch it fail with the pre-fix code, then
fix. A test written after the fix and never seen red may be asserting nothing.

Same for a new feature's critical path: break the assertion deliberately once and
confirm the failure message names the real problem.

## Coverage

A number, not a goal. 90% coverage of getters proves nothing; 40% covering every
store action and every form's error path is real safety. Chase branches — the
`catch`, the empty list, the permission-denied render — not lines.

## Pitfalls

- **`setState` without the replace flag** — state leaks between tests.
- **Mocking `axios` instead of the project instance** — interceptors untested.
- **`fireEvent` where `userEvent` belongs** — misses focus and typing behavior.
- **`getBy*` for async content** — flaky failures.
- **Querying by class or `testid`** — passes through accessibility regressions.
- **Missing `css: true`** — every `styles.x` is `undefined`.
- **Real timers for a debounce** — slow and flaky.
- **A test that was never seen failing** — may assert nothing.
- **Testing implementation details** ("`fetchAll` was called with these exact args")
  — breaks on every harmless refactor. Assert what the user sees.

## Related skills

- `react-zustand-state` — the store shapes under test.
- `react-zustand-networking` — the instance being mocked.
- `react-zustand-forms-validation` — the 422 path.
- `react-zustand-data-tables` — list states worth covering.
- `react-zustand-debugging` — when a test failure is a real bug.
