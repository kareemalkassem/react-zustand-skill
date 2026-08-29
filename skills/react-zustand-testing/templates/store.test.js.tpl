import { describe, it, expect, vi, beforeEach } from 'vitest';
import { use__Entity__Store } from '../store/__ENTITY__Store';
import __ENTITY__Service from '../services/__ENTITY__Service';

vi.mock('../services/__ENTITY__Service');

const initialState = use__Entity__Store.getState();

describe('__ENTITY__Store', () => {
  beforeEach(() => {
    // `true` REPLACES the state. Without it Zustand merges and one test's
    // leftovers make the next test pass for the wrong reason.
    use__Entity__Store.setState(initialState, true);
    vi.clearAllMocks();
  });

  describe('fetchAll', () => {
    it('stores items and pagination on success', async () => {
      __ENTITY__Service.getAll.mockResolvedValue({
        items: [{ id: 1, name: 'First' }],
        pagination: { current_page: 1, last_page: 2, total: 15 },
      });

      await use__Entity__Store.getState().fetchAll({ page: 1 });

      const state = use__Entity__Store.getState();
      expect(state.items).toHaveLength(1);
      expect(state.pagination.total).toBe(15);
      expect(state.isLoading).toBe(false);
      expect(state.error).toBeNull();
    });

    it('accepts a bare array envelope', async () => {
      __ENTITY__Service.getAll.mockResolvedValue([{ id: 1 }, { id: 2 }]);

      await use__Entity__Store.getState().fetchAll();

      expect(use__Entity__Store.getState().items).toHaveLength(2);
      expect(use__Entity__Store.getState().pagination).toBeNull();
    });

    // Pins the read half of the error contract: reads SWALLOW.
    it('writes the message into error and clears loading, without throwing', async () => {
      __ENTITY__Service.getAll.mockRejectedValue({
        response: { data: { message: 'Server unavailable' } },
      });

      await expect(use__Entity__Store.getState().fetchAll()).resolves.toBeUndefined();

      expect(use__Entity__Store.getState().error).toBe('Server unavailable');
      expect(use__Entity__Store.getState().isLoading).toBe(false);
      expect(use__Entity__Store.getState().items).toEqual([]);
    });

    it('ignores a cancelled request instead of rendering it as an error', async () => {
      __ENTITY__Service.getAll.mockRejectedValue({ code: 'ERR_CANCELED' });

      await use__Entity__Store.getState().fetchAll();

      expect(use__Entity__Store.getState().error).toBeNull();
    });
  });

  describe('create', () => {
    it('appends the created entity to items', async () => {
      use__Entity__Store.setState({ items: [{ id: 1, name: 'First' }] });
      __ENTITY__Service.create.mockResolvedValue({ id: 2, name: 'Second' });

      const created = await use__Entity__Store.getState().create({ name: 'Second' });

      expect(created.id).toBe(2);
      expect(use__Entity__Store.getState().items).toHaveLength(2);
    });

    // Pins the write half of the error contract: writes THROW.
    it('rethrows so the calling page can show the failure', async () => {
      __ENTITY__Service.create.mockRejectedValue(new Error('Validation failed'));

      await expect(use__Entity__Store.getState().create({})).rejects.toThrow('Validation failed');
    });
  });

  describe('remove', () => {
    it('drops the entity from items', async () => {
      use__Entity__Store.setState({ items: [{ id: 1 }, { id: 2 }] });
      __ENTITY__Service.remove.mockResolvedValue(true);

      await use__Entity__Store.getState().remove(1);

      expect(use__Entity__Store.getState().items).toEqual([{ id: 2 }]);
    });
  });

  describe('reset', () => {
    it('clears everything so the next user sees no stale rows', () => {
      use__Entity__Store.setState({ items: [{ id: 1 }], current: { id: 1 }, error: 'x' });

      use__Entity__Store.getState().reset();

      const state = use__Entity__Store.getState();
      expect(state.items).toEqual([]);
      expect(state.current).toBeNull();
      expect(state.error).toBeNull();
    });
  });
});
