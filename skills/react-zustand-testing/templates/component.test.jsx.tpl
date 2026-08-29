import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router-dom';

import __Entities__ from '../pages/__Entities__';
import { use__Entity__Store } from '../store/__ENTITY__Store';
import { usePermissionStore } from '../store/permissionStore';
import { useAuthStore } from '../store/authStore';

const initialState = use__Entity__Store.getState();

const renderPage = (route = '/__ENTITIES__') =>
  render(
    <MemoryRouter initialEntries={[route]}>
      <__Entities__ />
    </MemoryRouter>
  );

describe('__Entities__ page', () => {
  beforeEach(() => {
    use__Entity__Store.setState(initialState, true);
    useAuthStore.setState({ user: { role: 'admin' }, isAuthenticated: true });
    usePermissionStore.setState({ permissions: {} });
    vi.clearAllMocks();
  });

  it('shows skeleton rows while loading', () => {
    use__Entity__Store.setState({ isLoading: true, fetchAll: vi.fn() });

    renderPage();

    expect(screen.queryByText(/no __ENTITIES__ found/i)).not.toBeInTheDocument();
  });

  it('renders rows once loaded', async () => {
    use__Entity__Store.setState({
      items: [{ id: 1, name: 'First', created_at: '2026-01-01' }],
      isLoading: false,
      fetchAll: vi.fn(),
    });

    renderPage();

    expect(await screen.findByText('First')).toBeInTheDocument();
  });

  it('shows the empty state when there are no rows', async () => {
    use__Entity__Store.setState({ items: [], isLoading: false, fetchAll: vi.fn() });

    renderPage();

    expect(await screen.findByText(/no __ENTITIES__ found/i)).toBeInTheDocument();
  });

  // Error must be checked BEFORE loading, or a failure that also cleared
  // isLoading renders a blank page.
  it('shows the error state and retries on click', async () => {
    const user = userEvent.setup();
    const fetchAll = vi.fn();
    use__Entity__Store.setState({ error: 'Network error', items: [], fetchAll });

    renderPage();

    expect(screen.getByText('Network error')).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: /retry/i }));
    expect(fetchAll).toHaveBeenCalled();
  });

  it('debounces search into a single request', async () => {
    vi.useFakeTimers();
    const user = userEvent.setup({ advanceTimers: vi.advanceTimersByTime });
    const fetchAll = vi.fn();
    use__Entity__Store.setState({ items: [], isLoading: false, fetchAll });

    renderPage();
    fetchAll.mockClear();

    await user.type(screen.getByPlaceholderText(/search/i), 'abc');
    vi.advanceTimersByTime(500);

    expect(fetchAll).toHaveBeenCalledTimes(1);
    vi.useRealTimers();
  });

  it('hides the create action without the permission', () => {
    useAuthStore.setState({ user: { role: 'employee' } });
    usePermissionStore.setState({ permissions: { '__PERMISSION__.create': 'missing' } });
    use__Entity__Store.setState({ items: [], isLoading: false, fetchAll: vi.fn() });

    renderPage();

    expect(screen.queryByRole('button', { name: /add __ENTITY__/i })).not.toBeInTheDocument();
  });
});
