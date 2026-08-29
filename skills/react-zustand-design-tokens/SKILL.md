---
name: react-zustand-design-tokens
description: Use when touching styling in a React app — creating or editing a .module.css file, adding a color/spacing/radius/shadow value, setting up variables.css, theming or dark mode, or deciding between CSS Modules and a utility framework. Trigger on "color", "theme", "spacing", "CSS", "styling", "dark mode", "design system", "token" in a React context.
---

# Design Tokens & CSS Modules

**One styling system per project. It is CSS Modules plus CSS custom properties.**

No Tailwind, no styled-components, no inline style objects for anything a token
covers. Not because utility CSS is bad, but because a codebase running two systems
has no source of truth: a token change updates half the app, and the other half
keeps its hardcoded hex.

That failure is real and expensive. A production dashboard extracted for this skill
family had 37 CSS modules plus a full `variables.css`, **and** Tailwind installed
with an empty `theme.extend` — so every Tailwind class in the app hardcoded
`text-gray-900`, `bg-red-50`, unreachable by any token. Meanwhile its design docs
documented an indigo primary while the tokens had long since moved to amber, so
anything generated from the docs shipped the wrong brand.

## `styles/variables.css` — the single source

One `:root` block, imported once in `main.jsx`, before everything else.

```css
:root {
  /* Brand */
  --color-primary: #f59f00;
  --color-primary-hover: #e08c00;
  --color-primary-light: #fff3bf;
  --color-primary-subtle: #fff9db;

  /* Surfaces */
  --color-bg: #f8f9fa;
  --color-surface: #ffffff;
  --color-surface-subtle: #f1f3f5;
  --color-surface-hover: #e9ecef;
  --color-border: #dee2e6;
  --color-border-hover: #ced4da;

  /* Text */
  --color-text-main: #212529;
  --color-text-secondary: #495057;
  --color-text-muted: #868e96;
  --color-text-inverse: #ffffff;

  /* Status — each gets fg / bg / border so badges and banners compose */
  --color-success: #2f9e44;  --color-success-bg: #ebfbee;  --color-success-border: #b7e4c7;
  --color-warning: #e67700;  --color-warning-bg: #fff4e6;  --color-warning-border: #ffa94d;
  --color-danger:  #c92a2a;  --color-danger-bg:  #fff5f5;  --color-danger-border:  #ffa8a8;
  --color-info:    #1971c2;  --color-info-bg:    #e7f5ff;  --color-info-border:    #74c0fc;

  /* Typography */
  --font-sans: 'Space Grotesk', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
  --font-mono: 'DM Mono', 'Fira Code', monospace;

  --text-xs: 0.75rem;  --text-sm: 0.875rem; --text-base: 1rem;
  --text-lg: 1.125rem; --text-xl: 1.25rem;  --text-2xl: 1.5rem; --text-3xl: 1.875rem;

  --font-weight-regular: 400; --font-weight-medium: 500;
  --font-weight-semibold: 600; --font-weight-bold: 700;

  --leading-tight: 1.25; --leading-normal: 1.5; --leading-relaxed: 1.625;

  /* Spacing — 4px base */
  --space-1: 0.25rem;  --space-2: 0.5rem;  --space-3: 0.75rem;  --space-4: 1rem;
  --space-5: 1.25rem;  --space-6: 1.5rem;  --space-8: 2rem;     --space-12: 3rem;

  /* Radius */
  --radius-sm: 0.25rem; --radius-md: 0.375rem; --radius-lg: 0.5rem;
  --radius-xl: 0.75rem; --radius-full: 9999px;
  --radius-button: var(--radius-lg);
  --radius-card: var(--radius-xl);

  /* Elevation */
  --shadow-xs: 0 1px 2px rgba(0,0,0,.05);
  --shadow-sm: 0 1px 3px rgba(0,0,0,.08);
  --shadow-md: 0 4px 10px rgba(0,0,0,.10);
  --shadow-lg: 0 12px 24px rgba(0,0,0,.12);

  /* Motion */
  --transition-fast: 150ms cubic-bezier(.4,0,.2,1);
  --transition-base: 250ms cubic-bezier(.4,0,.2,1);

  /* Focus */
  --focus-ring: 0 0 0 2px var(--color-surface), 0 0 0 4px var(--color-primary);

  /* Layout */
  --header-height: 4rem;
  --sidebar-width: 16rem;

  /* Layering — every z-index in the app is one of these */
  --z-index-header: 40;
  --z-index-sidebar: 50;
  --z-index-dropdown: 60;
  --z-index-modal: 100;
}
```

### Token rules

- **Semantic names, not literal ones.** `--color-danger`, never `--color-red`. When
  the brand changes, a semantic token is re-pointed; a literal one has to be renamed
  everywhere.
- **Semantic aliases point at primitives** — `--radius-button: var(--radius-lg)`.
  Components use the alias, so "make buttons rounder" is one line.
- **Every z-index is a token.** The moment one `z-index: 9999` appears inline, the
  stacking order is no longer knowable from one file.
- **Status colors come in threes** (`fg` / `bg` / `border`) so a badge, a banner,
  and an outline all compose without inventing new values.
- **Docs quote the token name, never the hex.** A design doc that repeats
  `#4f46e5` is stale the first time the token changes. Write "primary is
  `--color-primary`" and let the file be the answer.

## File layout

```
src/styles/
├── variables.css            :root tokens — imported once in main.jsx
├── global.css               reset, html/body, font-face, focus-visible
├── <Page>.module.css        one per page in pages/
└── (primitives keep their .module.css beside the .jsx in components/ui/)
```

Co-locate a primitive's CSS with its JSX (`ui/Button.jsx` + `ui/Button.module.css`).
Page CSS lives in `styles/` mirroring the page name.

## Using tokens

```css
/* Products.module.css */
.card {
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-card);
  box-shadow: var(--shadow-sm);
  padding: var(--space-6);
  transition: box-shadow var(--transition-fast);
}
.card:hover { box-shadow: var(--shadow-md); }

.title {
  font-size: var(--text-lg);
  font-weight: var(--font-weight-semibold);
  color: var(--color-text-main);
}
```

**Any literal colour, radius, or shadow in a module file is a bug.** If no token
fits, add the token — do not inline the value. The only literals that belong in a
module are layout numbers with no design meaning: `grid-template-columns`,
`flex-basis`, a one-off `max-width`.

Composition across modules uses `composes`, not copy-paste:

```css
.dangerCard { composes: card; border-color: var(--color-danger-border); }
```

## Naming inside a module

`camelCase` class names, because they are read from JS as `styles.cardHeader`.
Kebab-case works but forces `styles['card-header']` at every call site.

Scope is per file, so names can be short and semantic — `.card`, `.title`, `.row`.
No BEM, no file-name prefixes; the module already namespaces them.

## Theming and dark mode

Tokens are runtime values, which is the whole reason to use custom properties:

```css
:root { color-scheme: light; }

[data-theme='dark'] {
  --color-bg: #121417;
  --color-surface: #1a1d21;
  --color-border: #2c3036;
  --color-text-main: #e9ecef;
  --color-text-secondary: #adb5bd;
}
```

```js
document.documentElement.dataset.theme = theme;   // 'light' | 'dark'
```

Only the palette is redefined. Spacing, radius, and typography are theme-invariant.
Because components reference tokens and never literals, a theme switch needs zero
component changes — that is the payoff for the "no hardcoded values" rule.

Store the choice in a preferences util backed by `localStorage`, and apply it in
`main.jsx` before first paint to avoid a flash of the wrong theme.

## Accessibility floors

- Body text meets 4.5:1 against its background; large text and UI borders meet 3:1.
  Check `--color-text-muted` specifically — muted greys are where contrast fails.
- Never remove a focus outline. Use `:focus-visible { box-shadow: var(--focus-ring); }`.
- Respect motion preferences:

```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after { animation-duration: .01ms !important; transition-duration: .01ms !important; }
}
```

## Pitfalls

- **Two styling systems at once** — the failure this skill exists to prevent.
- **A hardcoded hex in a module** — invisible until a rebrand.
- **Design docs quoting literal values** — they go stale silently.
- **Literal names (`--color-blue`)** — cannot be re-pointed.
- **`z-index: 9999`** — stacking order becomes unknowable.
- **A global (non-module) stylesheet per page** — class names collide across pages.
- **`!important`** — almost always a specificity problem caused by a global leak.
- **Tokens defined in more than one file** — there is one `:root` block.

## Related skills

- `react-zustand-ui-conventions` — the `clsx(styles[variant])` pattern consuming these.
- `react-zustand-performance` — CSS delivery and avoiding layout thrash.
- `react-zustand-core` — where `styles/` sits in the layout.
