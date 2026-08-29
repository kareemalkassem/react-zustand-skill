---
name: react-zustand-forms-validation
description: Use when building a create/edit form in a React app — controlled inputs, client-side validators, submit and error state, mapping a backend 422 validation response to per-field errors, dirty-state guards, or multi-step and nested forms. Trigger on "form", "validation", "422", "field error", "required", "submit", "input" in a React context.
---

# Forms & Validation

Two error sources, two display channels:

- **Client validation** catches shape errors before the request. Renders under the
  field.
- **Server validation (422)** is the authority. Renders under the field too, mapped
  from the response body.

Anything that is neither (a 500, a network drop) is the axios interceptor's job.
The form never toasts a network failure.

## The reference form

```jsx
const AddProduct = () => {
  const navigate = useNavigate();
  const create = useProductStore((s) => s.create);

  const [values, setValues] = useState({ name: '', price: '', description: '' });
  const [errors, setErrors] = useState({});
  const [submitting, setSubmitting] = useState(false);

  const setField = (field) => (e) => {
    const value = e?.target ? e.target.value : e;
    setValues((v) => ({ ...v, [field]: value }));
    setErrors((prev) => (prev[field] ? { ...prev, [field]: undefined } : prev));
  };

  const validate = () => {
    const next = {};
    if (!isRequired(values.name)) next.name = 'Name is required';
    if (!isValidPrice(values.price)) next.price = 'Enter a valid price';
    setErrors(next);
    return Object.keys(next).length === 0;
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!validate()) return;

    try {
      setSubmitting(true);
      await create(values);
      toast.success('Product created');
      navigate('/products', { replace: true });
    } catch (error) {
      const fieldErrors = extractFieldErrors(error);
      if (Object.keys(fieldErrors).length) setErrors(fieldErrors);
      else toast.error(extractApiErrorMessage(error, 'Could not save product'));
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <form onSubmit={handleSubmit} noValidate>
      <Input label="Name" required value={values.name}
             onChange={setField('name')} error={errors.name} />
      <Input label="Price" type="number" required value={values.price}
             onChange={setField('price')} error={errors.price} />
      <Textarea label="Description" value={values.description}
                onChange={setField('description')} helperText="Shown on the product page" />
      <Button type="submit" isLoading={submitting}>Save</Button>
    </form>
  );
};
```

Details that carry weight:

- **One `values` object, one `setField` factory.** A `useState` per field means N
  handlers and N stale-closure opportunities.
- **Clear a field's error as the user edits it.** Leaving a stale error under a
  field the user just fixed reads as a broken form. The conditional inside `setErrors`
  avoids a re-render when there was no error.
- **`e?.target ? e.target.value : e`** so `setField` accepts both a DOM event and a
  raw value from a custom control (date picker, image upload).
- **`noValidate` on the form.** Browser-native bubbles cannot be styled, are
  inconsistent across browsers, and duplicate messages you already render.
- **`type="submit"` plus `onSubmit`,** not `onClick` — Enter in a text field must
  submit the form.
- **`submitting` in `finally`.** A `catch` that returns early without resetting it
  leaves the button spinning forever.
- **`replace: true` after a successful create** so Back does not return to a form
  that would submit a duplicate.

## Client validators

Pure functions in `utils/validation.js`. No React, no store.

```js
export const isRequired = (v) => {
  if (v === null || v === undefined) return false;
  if (typeof v === 'string') return v.trim().length > 0;
  if (Array.isArray(v)) return v.length > 0;
  return true;
};

export const isValidEmail = (v) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v);
export const isValidPrice = (v) => !Number.isNaN(Number(v)) && parseFloat(v) >= 0;
export const isValidUrl = (v) => { try { new URL(v); return true; } catch { return false; } };
```

Validate **shape**, not business rules. "Is this a well-formed email" is the
client's job; "is this email already taken" is the server's, and the answer arrives
as a 422.

Keep the client rules a strict subset of the server's. A client rule the server
does not have blocks a submission the backend would have accepted.

## Mapping a 422

Backends nest validation errors as `{ errors: { field: ["message"] } }`, often with
dotted keys for nested and array fields (`variants.0.price`). Flatten to the top
key so the message lands on a rendered input:

```js
export const extractFieldErrors = (errorOrErrors = {}) => {
  const errors = errorOrErrors?.response?.data?.errors ?? errorOrErrors ?? {};
  if (!errors || typeof errors !== 'object') return {};

  return Object.entries(errors).reduce((acc, [key, value]) => {
    const field = key.split('.')[0];
    acc[field] = Array.isArray(value) ? String(value[0] ?? '') : String(value ?? '');
    return acc;
  }, {});
};
```

- **Only the first message per field.** Stacking four messages under one input is
  noise; fixing the first usually clears the rest.
- **A 422 with no `errors` map** falls through to a toast — never leave the user
  with a form that did nothing and said nothing.
- **Focus and scroll to the first errored field** on a long form. An error
  off-screen looks identical to a dead button.

## Input primitives

`Input`, `Select`, and `Textarea` all take `label`, `required`, `error`,
`helperText`:

```jsx
const Input = ({ label, error, helperText, required, id, ...props }) => {
  const inputId = id ?? useId();
  return (
    <div className={styles.wrapper}>
      {label && (
        <label htmlFor={inputId} className={styles.label}>
          {label}{required && <span className={styles.required}>*</span>}
        </label>
      )}
      <input
        id={inputId}
        aria-invalid={!!error}
        aria-describedby={error ? `${inputId}-error` : helperText ? `${inputId}-help` : undefined}
        className={clsx(styles.input, error && styles.inputError)}
        {...props}
      />
      {error
        ? <p id={`${inputId}-error`} className={styles.error}>{error}</p>
        : helperText && <p id={`${inputId}-help`} className={styles.helper}>{helperText}</p>}
    </div>
  );
};
```

`htmlFor`/`id` pairing, `aria-invalid`, and `aria-describedby` are not optional —
without them a screen reader announces an unlabelled field with no error. Error
replaces helper text rather than stacking.

## Edit forms

Seed state from fetched data, and wait for it:

```jsx
useEffect(() => { fetchOne(id); }, [fetchOne, id]);

useEffect(() => {
  if (current) setValues({ name: current.name, price: String(current.price ?? '') });
}, [current]);

if (isLoading || !current) return <FormSkeleton />;
```

- **Coerce numbers to strings** for controlled inputs. A `value={undefined}` or a
  number flipping to a string switches the input between uncontrolled and
  controlled and React logs a warning.
- **Never seed with `||` defaults that erase legitimate falsy values** — `price: 0`
  must render as `0`, not blank. Use `??`.

## Unsaved-changes guard

```jsx
const isDirty = useMemo(
  () => JSON.stringify(values) !== JSON.stringify(initialValues),
  [values, initialValues]
);

useEffect(() => {
  if (!isDirty) return;
  const warn = (e) => { e.preventDefault(); e.returnValue = ''; };
  window.addEventListener('beforeunload', warn);
  return () => window.removeEventListener('beforeunload', warn);
}, [isDirty]);
```

`beforeunload` covers tab close and reload. In-app navigation needs the router's
own blocker; add it only where losing the work is genuinely costly, since an
over-eager guard trains users to dismiss it.

## Nested and repeating fields

Keep them in the same `values` object as an array, and give each row a **stable
key that is not the index** — an existing `id`, or a `crypto.randomUUID()` assigned
at creation. Index keys make React reuse the wrong DOM node when a middle row is
removed, so the user's typed value jumps to another row.

```jsx
const addVariant = () => setValues((v) => ({
  ...v, variants: [...v.variants, { key: crypto.randomUUID(), size: '', price: '' }],
}));
```

## When to reach for a form library

Hand-rolled is right up to roughly 15 fields with straightforward rules. Past that
— cross-field dependencies, arrays of arrays, wizard steps with per-step validation
— adopt `react-hook-form` (+ `zod`) rather than growing this pattern. Adopt it for
the whole project or not at all; two form systems is the same failure as two
styling systems.

## Pitfalls

- **A `useState` per field** — N handlers, stale closures.
- **Stale error left under a corrected field** — reads as broken.
- **No `noValidate`** — unstyled browser bubbles duplicate your messages.
- **`onClick` instead of `onSubmit`** — Enter does nothing.
- **`submitting` not reset in `finally`** — button spins forever.
- **Client rules stricter than the server's** — blocks valid submissions.
- **A 422 with no field map and no toast** — silent dead button.
- **`value={undefined}`** — controlled/uncontrolled warning and lost keystrokes.
- **`||` seeding that erases `0`** — use `??`.
- **Array index as key** — typed values jump rows on removal.
- **No `replace` after create** — Back re-submits.

## Related skills

- `react-zustand-networking` — `extractApiErrorMessage`, the shared error util.
- `react-zustand-ui-conventions` — the `Input`/`Select`/`Textarea` primitives.
- `react-zustand-core` — why write actions throw so the form can catch.
- `react-zustand-assets-media` — file inputs inside a form.
- `react-zustand-testing` — testing submit and error paths with RTL.
