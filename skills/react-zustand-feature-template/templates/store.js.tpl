import { create } from 'zustand';
import __ENTITY__Service from '../services/__ENTITY__Service';
import { extractApiErrorMessage } from '../utils/apiError';

/**
 * Error contract (see react-zustand-core):
 *   reads  -> swallow, write the message into `error`
 *   writes -> throw, the calling page owns the toast and its own submitting state
 */
export const use__Entity__Store = create((set) => ({
  items: [],
  current: null,
  pagination: null,
  isLoading: false,
  error: null,

  fetchAll: async (params) => {
    set({ isLoading: true, error: null });
    try {
      const data = await __ENTITY__Service.getAll(params);
      const items = Array.isArray(data) ? data : (data?.items ?? []);
      set({ items, pagination: data?.pagination ?? null, isLoading: false });
    } catch (error) {
      if (error.code === 'ERR_CANCELED') return;
      set({ error: extractApiErrorMessage(error), isLoading: false });
    }
  },

  fetchOne: async (id) => {
    set({ isLoading: true, error: null });
    try {
      const data = await __ENTITY__Service.getById(id);
      set({ current: data, isLoading: false });
      return data;
    } catch (error) {
      set({ error: extractApiErrorMessage(error), isLoading: false });
    }
  },

  create: async (payload) => {
    const created = await __ENTITY__Service.create(payload);
    set((state) => ({ items: [...state.items, created] }));
    return created;
  },

  update: async (id, payload) => {
    const updated = await __ENTITY__Service.update(id, payload);
    set((state) => ({
      items: state.items.map((item) => (item.id === id ? updated : item)),
      current: state.current?.id === id ? updated : state.current,
    }));
    return updated;
  },

  remove: async (id) => {
    await __ENTITY__Service.remove(id);
    set((state) => ({ items: state.items.filter((item) => item.id !== id) }));
  },

  // Called from authStore.logout() so the next user never sees these rows.
  reset: () => set({ items: [], current: null, pagination: null, isLoading: false, error: null }),
}));
