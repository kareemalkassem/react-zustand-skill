import api from './api';

const BASE = '__BASE_PATH__';

const __ENTITY__Service = {
  getAll: async (params) => {
    const { data } = await api.get(`${BASE}/index`, { params });
    return data.data;
  },

  getById: async (id) => {
    const { data } = await api.get(`${BASE}/get/${id}`);
    return data.data;
  },

  create: async (payload) => {
    const isForm = payload instanceof FormData;
    const { data } = await api.post(
      `${BASE}/create`,
      payload,
      isForm ? { headers: { 'Content-Type': 'multipart/form-data' } } : {}
    );
    return data.data;
  },

  update: async (id, payload) => {
    const isForm = payload instanceof FormData;
    const { data } = await api.post(
      `${BASE}/update/${id}`,
      payload,
      isForm ? { headers: { 'Content-Type': 'multipart/form-data' } } : {}
    );
    return data.data;
  },

  remove: async (id) => {
    const { data } = await api.delete(`${BASE}/delete/${id}`);
    return data.data;
  },
};

export default __ENTITY__Service;
