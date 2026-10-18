---
name: react-zustand-i18n-rtl
description: Use when a React+Zustand app must support more than one language or a right-to-left language — adding Arabic/Hebrew, a language switcher, translation keys, RTL layout, mirrored icons, locale-aware dates/numbers/currency, a locale header to the API, or fixing a layout that breaks in RTL. Trigger on "translation", "i18n", "localization", "Arabic", "RTL", "dir=rtl", "language switch", "locale".
---

# i18n and RTL

Bilingual support added late costs a rewrite: every hardcoded string, every
`margin-left`, every left-pointing chevron, and every `toLocaleDateString()` with
no locale. Added in M1, it costs almost nothing.

Three separate concerns, each with one owner:

| Concern | Owner |
|---|---|
| Current locale + persistence | `store/localeStore.js` (or the auth store's `locale`) |
| Direction and `lang` on `<html>` | `utils/i18n.js` → `applyDocumentDirection()` |
| Strings | `locales/<lang>.js` dictionaries + `t()` — or `{ en, ar }` fields from the API |
| Dates, numbers, money | `utils/format.js` with `Intl.*` |
| Telling the API | `api.js` request interceptor header |

## Locale state

```js
// src/store/localeStore.js
import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import { applyDocumentDirection, normalizeLocale } from '../utils/i18n';

export const useLocaleStore = create(persist(
  (set) => ({
    locale: 'en',
    setLocale: (next) => {
      const locale = normalizeLocale(next);
      applyDocumentDirection(locale);
      set({ locale });
    },
  }),
  { name: 'locale', onRehydrateStorage: () => (s) => applyDocumentDirection(s?.locale) },
));
```

`onRehydrateStorage` sets `dir` before first paint after reload, so the layout
never flashes LTR first.

## Direction

```js
// src/utils/i18n.js
export const SUPPORTED_LOCALES = ['en', 'ar'];
export const RTL_LOCALES = ['ar'];

export const normalizeLocale = (l) => (SUPPORTED_LOCALES.includes(l) ? l : 'en');
export const getDirection = (l) => (RTL_LOCALES.includes(normalizeLocale(l)) ? 'rtl' : 'ltr');

export function applyDocumentDirection(locale) {
  const l = normalizeLocale(locale);
  document.documentElement.lang = l;
  document.documentElement.dir = getDirection(l);
}
```

Direction lives on `<html>` only. Components never take a `dir` prop; CSS reads
it through logical properties and `:dir(rtl)` / `[dir='rtl']`.

## Strings

Two sources, two tools:

```js
// UI chrome: dictionaries + t()
// src/locales/en.js  export default { 'orders.title': 'Orders', 'orders.empty': 'No orders yet' };
// src/locales/ar.js  export default { 'orders.title': 'الطلبات', 'orders.empty': 'لا توجد طلبات بعد' };

import en from '../locales/en';
import ar from '../locales/ar';
const dictionaries = { en, ar };

export const useT = () => {
  const locale = useLocaleStore((s) => s.locale);
  return (key, vars = {}) =>
    (dictionaries[locale][key] ?? dictionaries.en[key] ?? key)
      .replace(/\{(\w+)\}/g, (_, k) => vars[k] ?? '');
};
```

```js
// Content from the API or seed: bilingual fields
export const pickLocalized = (value, locale) =>
  typeof value === 'string' ? value : value?.[locale] ?? value?.en ?? '';
// <h2>{pickLocalized(room.name, locale)}</h2>   room.name = { en: 'Deluxe', ar: 'ديلوكس' }
```

Rules:

- Every user-visible string goes through `t()` or `pickLocalized` — including
  `aria-label`, `placeholder`, toast messages, and empty-state text.
- Add a key to **every** dictionary in the same commit. A missing key falls back
  to English, which hides the gap; a quick script that diffs dictionary keys
  catches it in CI.
- Keys name meaning (`orders.empty`), not wording (`no_orders_yet`).
- Interpolate with placeholders, never string concatenation — Arabic word order
  differs.
- For plurals use `Intl.PluralRules(locale).select(n)` to pick a key suffix;
  Arabic has six plural forms.

## CSS: logical properties only

```css
/* Bad: breaks in RTL */
.card { margin-left: var(--space-4); padding-right: var(--space-2); text-align: left; }
.badge { position: absolute; right: 8px; }

/* Good: mirrors automatically */
.card { margin-inline-start: var(--space-4); padding-inline-end: var(--space-2); text-align: start; }
.badge { position: absolute; inset-inline-end: 8px; }
```

- `left/right` → `inline-start/inline-end`; `border-left` →
  `border-inline-start`; `float: left` → `float: inline-start`.
- Flex and grid follow `dir` already — do not reverse them with
  `flex-direction: row-reverse` for RTL.
- Fonts: switch the stack under `:root[dir='rtl']` in `variables.css`
  (`--font-body: 'Tajawal', 'Noto Sans Arabic', sans-serif`). Arabic needs a
  slightly larger size and line-height for the same legibility.
- Directional icons (chevrons, back arrows, "send") flip with
  `[dir='rtl'] .icon-directional { transform: scaleX(-1); }`. Non-directional ones
  (search, user, check) never flip.
- Numbers, phone numbers, codes, and emails inside RTL text: wrap in
  `<bdi>` or `dir="ltr"` so `+963 11 …` does not reorder.

## Dates, numbers, money

```js
// src/utils/format.js
const intlLocale = (l) => (l === 'ar' ? 'ar-SY' : 'en-GB');   // pick the region the product targets

export const formatDate = (iso, locale, opts = { dateStyle: 'medium' }) =>
  new Intl.DateTimeFormat(intlLocale(locale), { timeZone: 'UTC', ...opts }).format(new Date(iso));

export const formatMoney = (amount, currency, locale) =>
  new Intl.NumberFormat(intlLocale(locale), { style: 'currency', currency }).format(amount);
```

- Store and transmit UTC ISO strings; format only at render.
- Decide once whether Arabic UI shows Arabic-Indic digits (`ar-SY`) or Latin
  digits (`ar-SY-u-nu-latn`) and write it in FOUNDATION. Mixing both in one
  screen reads as broken.

## Telling the API

```js
// in api.js request interceptor
config.headers['Accept-Language'] = useLocaleStore.getState().locale;
```

Use the header the backend reads (`Accept-Language` or a custom `X-Locale`) —
one header, set in the interceptor, never per service. Changing locale should
refetch the current page's data if the backend localizes responses.

## Verifying

- Switch to Arabic and walk every changed screen: nothing overlaps, nothing is
  clipped, icons point the right way, tables align to `start`.
- Add an Arabic persona to the smoke run and screenshot both directions
  (`react-zustand-e2e-playwright`).
- Test the longest string: German-length English labels and Arabic with
  diacritics both overflow fixed widths.

## Pitfalls

- **`margin-left` / `left:` / `text-align: left`** — layout mirrors wrongly in RTL;
  every one is a bug report.
- **Setting `dir` on a wrapper div instead of `<html>`** — portals (modals,
  toasts, dropdowns) render outside it and stay LTR.
- **Concatenated sentences** — `'Showing ' + n + ' of ' + total` cannot be
  reordered for Arabic grammar.
- **`toLocaleDateString()` with no locale or time zone** — output depends on the
  user's machine, and UTC dates shift a day.
- **Flipping every icon** — a mirrored search or checkmark icon looks wrong.
- **Translating in services or stores** — strings belong to render; the store
  holds keys or bilingual objects, not translated text.

## Related skills

- `react-zustand-design-tokens` — font and spacing tokens per direction.
- `react-zustand-networking` — the locale header in the interceptor.
- `react-zustand-state` — `persist` for the locale store.
- `react-zustand-forms-validation` — localized validation messages.
- `react-zustand-e2e-playwright` — screenshot both directions.
