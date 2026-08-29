---
name: react-zustand-ui-conventions
description: Use when writing or editing React components — deciding whether something belongs in components/ui/ or components/ or a page, building or reusing a primitive (Button, Input, Modal, Table, Badge, Card), wiring variants with clsx and CSS Modules, composing loading/empty/error states, or choosing between a div and a real button/link. Trigger on any task touching components/, pages/, or *.module.css.
---

# UI Conventions

Two rules carry most of the value here:

1. **Reach for an existing primitive before writing a `<button>`.**
2. **A variant is a CSS-Module class name looked up by prop, never a conditional
   class string.**

Everything below is those two rules applied.

## Where a component goes

| Location | Contains | Test |
|---|---|---|
| `components/ui/` | Domain-agnostic primitives: `Button`, `Input`, `Select`, `Textarea`, `Checkbox`, `Card`, `Badge`, `Modal`, `Table`, `SearchFilter` | Could it ship in an unrelated app unchanged? |
| `components/` | App composites: `PageHeader`, `Pagination`, `Sidebar`, `Header`, `Layout`, `ErrorState`, `Skeletons`, `Avatar` | Reused across pages, but knows this app |
| `components/<feature>/` | Pieces used by one feature across several of its pages | Only that feature imports it |
| `pages/` | Route components | Rendered by exactly one route |

If a page defines a subcomponent used twice in that same file, leave it in the
page. Promote it to `components/` on the *second* page that needs it, not in
anticipation.

## The `ui/` barrel

`components/ui/index.js` is the only barrel in the project:

```js
export { default as Button } from './Button';
export { Input, Textarea, Select } from './Input';
export { default as Card } from './Card';
export { default as Badge } from './Badge';
export { default as Modal } from './Modal';
export { Table, Thead, Tbody, Tr, Th, Td } from './Table';
```

```jsx
import { Button, Card, Badge } from '../components/ui';
```

Do not add barrels for `pages/`, `store/`, or `services/`. A barrel over a large
directory defeats tree-shaking and creates import cycles; over ten small
co-designed primitives it is a genuine ergonomic win.

## The variant pattern

Every primitive with visual variants uses the same shape: `clsx` plus a CSS-Module
class lookup.

```jsx
import clsx from 'clsx';
import { Loader2 } from 'lucide-react';
import styles from './Button.module.css';

const Button = ({
  children,
  variant = 'primary',   // primary | secondary | danger | ghost
  size = 'md',           // sm | md | lg
  fullWidth = false,
  isLoading = false,
  icon: Icon,
  className,
  disabled,
  type = 'button',
  ...props
}) => (
  <button
    type={type}
    className={clsx(
      styles.button,
      styles[variant],
      styles[size],
      fullWidth && styles.fullWidth,
      isLoading && styles.loading,
      className
    )}
    disabled={disabled || isLoading}
    {...props}
  >
    {isLoading ? <Loader2 className={styles.spinner} size={16} />
               : Icon ? <Icon size={16} /> : null}
    {children}
  </button>
);

export default Button;
```

```css
/* Button.module.css */
.button { display: inline-flex; align-items: center; gap: var(--space-2);
          border-radius: var(--radius-button); transition: var(--transition-fast); }
.primary   { background: var(--color-primary); color: var(--color-text-inverse); }
.primary:hover:not(:disabled) { background: var(--color-primary-hover); }
.secondary { background: var(--color-surface); border: 1px solid var(--color-border); }
.danger    { background: var(--color-danger); color: var(--color-text-inverse); }
.ghost     { background: transparent; color: var(--color-text-secondary); }
.sm { padding: var(--space-1-5) var(--space-3); font-size: var(--text-xs); }
.md { padding: var(--space-2) var(--space-4);   font-size: var(--text-sm); }
.lg { padding: var(--space-3) var(--space-6);   font-size: var(--text-base); }
```

Why `styles[variant]` and not `variant === 'primary' && styles.primary`: adding a
variant becomes one CSS rule with zero JSX change, and the prop value and the class
name cannot drift apart.

Non-negotiables for every primitive:

- **`className` last in `clsx`** so a caller can override.
- **`...props` spread onto the DOM node** so `aria-*`, `onBlur`, `data-*`, and
  `ref`-adjacent attributes pass through without editing the primitive.
- **`type="button"` default on `Button`.** The HTML default is `submit`; a toolbar
  button inside a form that silently submits it is a real and frequent bug.
- **`disabled || isLoading`.** A loading button that is still clickable
  double-submits.

## Compound components

Tables and other structural primitives export named parts rather than taking a
`columns` config:

```jsx
export const Table = ({ children, className, ...props }) => (
  <div className={styles.container}>
    <table className={clsx(styles.table, className)} {...props}>{children}</table>
  </div>
);
export const Tr = ({ children, className, onClick, ...props }) => (
  <tr className={clsx(styles.tr, onClick && styles.trClickable, className)}
      onClick={onClick} {...props}>{children}</tr>
);
```

```jsx
<Table>
  <Thead><Tr><Th>Name</Th><Th>Price</Th></Tr></Thead>
  <Tbody>
    {items.map((p) => (
      <Tr key={p.id} onClick={() => navigate(`/products/${p.id}`)}>
        <Td>{p.name}</Td><Td>{formatMoney(p.price)}</Td>
      </Tr>
    ))}
  </Tbody>
</Table>
```

The `<div className={styles.container}>` wrapper with `overflow-x: auto` lives
*inside* `Table` so no caller can forget it. Config-object tables collapse the
moment one cell needs custom JSX.

## Choosing the element

| Intent | Element |
|---|---|
| Performs an action | `<button>` — via the `Button` primitive |
| Goes somewhere | `<Link>` / `<NavLink>` |
| A whole row is clickable | `<tr onClick>` **plus** a real link or button inside for keyboard users |
| Purely decorative | `<div>` / `<span>` |

A `<div onClick>` is not focusable, not keyboard-activatable, and invisible to
screen readers. When a clickable card is genuinely needed, add
`role="button"`, `tabIndex={0}`, and an `onKeyDown` for Enter and Space — or use a
`Button` styled with the `ghost` variant instead.

## The five states every data surface needs

Before a list or detail view is done, all five are handled:

```jsx
if (error)              return <ErrorState message={error} onRetry={refetch} />;
if (isLoading)          return <TableRowSkeleton columns={5} rows={8} />;
if (!items.length)      return <EmptyState title="No products yet" action={<Button …/>} />;
return <ProductTable items={items} />;
```

Plus: **disabled** while a mutation is in flight, and **success** confirmation
after one (`toast.success`).

- **Error before loading.** A failed fetch that also left `isLoading` false renders
  a blank page if the loading check comes first.
- **Skeletons, not spinners, for lists.** A skeleton matching the real row height
  keeps the layout from jumping when data lands.
- **Empty state is not an error.** Give it an action that resolves it.

## Icons

One icon library (`lucide-react`), imported per icon so tree-shaking works:

```jsx
import { Plus, Trash2, Search } from 'lucide-react';
```

Size icons with the numeric `size` prop, matched to the text they sit beside — 14
for `sm`, 16 for `md`, 20 for `lg`. An icon-only button needs `aria-label`.

## Formatting and props

- Function components as arrow consts, `export default` at the bottom of the file
  for a single-export component, named exports for compound sets.
- Destructure props in the signature with defaults inline. No `props.x`.
- Optional: `prop-types` on `components/ui/` primitives only — they are the shared
  contract. Do not spread `prop-types` across pages; it is noise there.
- Keep component files under ~200 lines. A primitive that needs more than that is
  two primitives.
- No inline `style={{}}` for anything a token covers. The one legitimate use is a
  genuinely dynamic value (`style={{ width: `${percent}%` }}`).

## Pitfalls

- **A raw `<button className="...">` when `Button` exists** — bypasses loading,
  disabled, and focus styling.
- **Conditional class strings** — `clsx('btn', variant === 'primary' && 'btn-primary')`
  drifts from the CSS the first time a variant is renamed.
- **Missing `type="button"`** — silent form submits.
- **`className` first in `clsx`** — callers cannot override.
- **Not spreading `...props`** — every new attribute needs a primitive edit.
- **`<div onClick>`** — inaccessible.
- **Loading state that is still clickable** — double submit.
- **Hardcoded colors** — see `react-zustand-design-tokens`.
- **A component reaching into a store** — primitives take props. Only pages and
  app composites subscribe.

## Related skills

- `react-zustand-design-tokens` — the CSS variables these modules consume.
- `react-zustand-data-tables` — assembling primitives into a list page.
- `react-zustand-forms-validation` — `Input`/`Select` error and helper text.
- `react-zustand-assets-media` — `ImageUpload` and `ImagePreview`.
- `react-zustand-core` — why components never import services.
