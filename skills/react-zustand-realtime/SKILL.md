---
name: react-zustand-realtime
description: Use when a React+Zustand screen must update live — an operations queue, notifications feed, chat, order or ticket board, dashboard counters — via WebSockets, Laravel Reverb/Echo, Pusher, Firebase, Server-Sent Events, polling, or a mock timer. Trigger on "real-time", "live updates", "websocket", "Reverb", "Echo", "Pusher", "Firebase listener", "SSE", "polling", "subscribe", "stale".
---

# Real-time Updates

Live data breaks the normal fetch-render cycle in three ways: subscriptions leak
when a page unmounts, two subscriptions for the same feed double every event, and
the user cannot tell when the connection dropped and the list went stale.

The pattern: **one subscription contract, owned by a store, started and stopped by
the page, with REST as the source of truth.**

## The shape

```
services/queueService.js   subscribe(onEvent) → unsubscribe        (transport)
store/queueStore.js        connect() / disconnect(), items, status  (state)
pages/OperationsQueue.jsx  useEffect(connect → disconnect)          (lifecycle)
components/RealtimeIndicator.jsx   connected | reconnecting | stale (UX)
```

The transport behind `subscribe` can be a mock timer today and Reverb tomorrow;
nothing above the service changes.

## The subscription contract

```js
// src/services/queueService.js
import api from './api';
import { echo } from './realtime';                 // the ONE socket client, like api.js

const queueService = {
  list: async (params) => (await api.get('/operations/queue', { params })).data.data,

  subscribe: (onEvent, onStatus) => {
    const channel = echo.private('operations.queue');
    channel.listen('.queue.item.updated', (e) => onEvent({ type: 'upsert', item: e.item }));
    channel.listen('.queue.item.removed', (e) => onEvent({ type: 'remove', id: e.id }));
    const conn = echo.connector.pusher.connection;
    const handler = ({ current }) => onStatus(current === 'connected' ? 'connected' : 'reconnecting');
    conn.bind('state_change', handler);
    return () => { conn.unbind('state_change', handler); echo.leave('operations.queue'); };
  },
};

export default queueService;
```

Rules:

- `subscribe` returns its own cleanup. Callers never reach into the socket client.
- Events are normalized here into `{ type, item | id }` — the same "unwrap in the
  service" rule as REST.
- One socket client module (`services/realtime.js`), created once, reading the
  auth token from the auth store — the same reasoning as one axios instance.

## The store

```js
// src/store/queueStore.js
const upsert = (items, item) => {
  const i = items.findIndex((x) => x.id === item.id);
  return i === -1 ? [item, ...items] : items.map((x) => (x.id === item.id ? item : x));
};

export const useQueueStore = create((set, get) => ({
  items: [], isLoading: false, error: null,
  status: 'idle',                       // idle | connected | reconnecting | stale
  lastEventAt: null,
  unsubscribe: null,

  fetchAll: async (params) => {        // REST is authoritative
    set({ isLoading: true, error: null });
    try {
      const { items } = await queueService.list(params);
      set({ items, isLoading: false });
    } catch (error) {
      set({ error: extractApiErrorMessage(error), isLoading: false });
    }
  },

  connect: () => {
    if (get().unsubscribe) return;      // idempotent: StrictMode mounts twice
    const unsubscribe = queueService.subscribe(
      (event) => set((s) => ({
        items: event.type === 'remove' ? s.items.filter((x) => x.id !== event.id) : upsert(s.items, event.item),
        lastEventAt: Date.now(),
      })),
      (status) => {
        set({ status });
        if (status === 'connected') get().fetchAll();   // resync after a gap
      },
    );
    set({ unsubscribe, status: 'connected' });
  },

  disconnect: () => {
    get().unsubscribe?.();
    set({ unsubscribe: null, status: 'idle' });
  },
}));
```

- **Idempotent `connect`.** React 19 StrictMode mounts effects twice in dev; the
  guard prevents a duplicate subscription that would double every event.
- **Resync on reconnect.** Events sent while disconnected are lost; a REST refetch
  on `connected` closes the gap.
- **Upsert by id**, never append blindly — the same item arrives from REST and the
  socket.
- Add `disconnect` to the store's `reset()` so logout closes the channel.

## The page

```jsx
const OperationsQueue = () => {
  const { items, status, fetchAll, connect, disconnect } = useQueueStore(useShallow((s) => ({
    items: s.items, status: s.status, fetchAll: s.fetchAll, connect: s.connect, disconnect: s.disconnect,
  })));

  useEffect(() => {
    fetchAll();
    connect();
    return disconnect;
  }, [fetchAll, connect, disconnect]);

  return (
    <>
      <PageHeader title="Operations queue" actions={<RealtimeIndicator status={status} />} />
      <QueueBoard items={items} />
    </>
  );
};
```

## Staleness

Mark the feed `stale` when no event or heartbeat has arrived for longer than the
expected interval. A small interval in the store
(`if (Date.now() - lastEventAt > STALE_MS) set({ status: 'stale' })`) is enough.
`RealtimeIndicator` shows the state with text, not only colour, and offers
"Refresh" when stale. Staff acting on a stale queue is the real failure mode, not
a dropped socket.

## Mock transport (mock-first projects)

```js
// src/mocks/realtime.js — same signature as the real subscribe
export const subscribeToQueueMock = (onEvent, onStatus) => {
  onStatus?.('connected');
  const timer = setInterval(() => onEvent({ type: 'upsert', item: makeFakeQueueItem() }), 18000);
  return () => clearInterval(timer);
};
```

The service picks the mock when `VITE_USE_MOCKS === 'true'`. Mock events should
mutate the same in-memory `db` the REST mock reads, so a refetch agrees with what
the socket showed. See `react-zustand-mock-api`.

## Polling as a fallback

When there is no socket, polling uses the same contract: `subscribe` starts a
`setInterval(fetch, 15000)` that emits `upsert` events and returns `clearInterval`.
Pause it when `document.visibilityState === 'hidden'`.

## Pitfalls

- **Subscribing in a component without cleanup** — the listener survives
  navigation; each visit adds another, and events multiply.
- **No idempotency guard** — StrictMode double-mount subscribes twice in dev and
  hides the bug until a real remount in production.
- **Trusting the socket as the source of truth** — missed events during a
  reconnect leave the list silently wrong. Refetch on reconnect.
- **Appending events** — duplicates when REST and socket both deliver the item.
- **Socket client per component** — N connections per tab, N auth handshakes.
- **No stale indicator** — users act on old data with no signal that it is old.
- **Forgetting logout** — the channel stays open under the next user's session.

## Related skills

- `react-zustand-state` — store shape and `reset()` on logout.
- `react-zustand-mock-api` — the mock transport and shared in-memory data.
- `react-zustand-auth-session` — token for private channels; closing on logout.
- `react-zustand-performance` — batching high-frequency events.
- `react-zustand-testing` — fake timers for subscription tests.
