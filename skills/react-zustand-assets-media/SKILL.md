---
name: react-zustand-assets-media
description: Use when handling images or files in a React app — resolving a server image path to a URL, validating an upload before sending it, building FormData for a multipart request, image preview and gallery components, drag-and-drop uploads, blob downloads, or static assets in a Vite project. Trigger on "image", "upload", "file", "avatar", "photo", "download", "thumbnail" in a React context.
---

# Assets & Media

Two problems, both solved once in `utils/` rather than per page: **turning a stored
path into a URL** and **rejecting a bad file before it costs a request**.

## Image URL resolution

An API returns image paths in inconsistent forms — sometimes absolute, sometimes
`storage/products/x.jpg`, sometimes `/public/products/x.jpg`. Normalize in one
place:

```js
export const getImageUrl = (path) => {
  if (!path) return null;
  if (path.startsWith('http')) return path;        // already absolute

  const apiUrl = import.meta.env.VITE_API_URL || 'http://localhost:8000/api';
  const serverUrl = apiUrl.replace(/\/api\/?$/, '');

  let normalized = path.startsWith('/') ? path.slice(1) : path;
  if (normalized.startsWith('storage/')) normalized = normalized.slice('storage/'.length);
  if (!normalized.startsWith('public/')) normalized = `public/${normalized}`;

  return `${serverUrl}/api/file/${encodeURI(normalized)}`;
};
```

- **Return `null`, not `''`, for a missing path** — `<img src="">` re-requests the
  current page in some browsers.
- **Pass absolute URLs through untouched** so CDN and third-party images survive.
- **`encodeURI`** — filenames contain spaces and non-ASCII characters.
- **Derive the server root from the API base**, never a second env var. Two
  variables drift between environments.

## The image component

Every rendered server image goes through one component so the fallback and the
error path are uniform:

```jsx
export const ProductImage = ({ src, alt, className, onClick }) => {
  const [failed, setFailed] = useState(false);
  const url = getImageUrl(src);

  if (!url || failed) {
    return <div className={clsx(styles.fallback, className)} aria-hidden="true"><ImageIcon size={20} /></div>;
  }

  return (
    <img
      src={url}
      alt={alt}
      loading="lazy"
      className={clsx(styles.image, className)}
      onError={() => setFailed(true)}
      onClick={onClick}
    />
  );
};
```

- **`onError` → fallback.** A broken-image glyph in a table looks like a crash.
- **`loading="lazy"`** on anything below the fold — free, one attribute.
- **`alt` is required.** Decorative images get `alt=""` plus `aria-hidden`, never a
  missing attribute.
- Give the container fixed dimensions or an `aspect-ratio` in CSS so the row does
  not jump when the image lands.

## Upload validation

Validate before the request. A 6 MB rejected upload wastes the user's bandwidth and
gives a slower, vaguer error.

```js
export const IMAGE_EXTENSIONS = ['jpg', 'jpeg', 'png', 'webp', 'gif'];
export const IMAGE_MIME_TYPES = ['image/jpeg', 'image/png', 'image/webp', 'image/gif'];
export const IMAGE_ACCEPT = '.jpg,.jpeg,.png,.webp,.gif';

export const validateImageFile = (file, options = {}) => {
  if (!file) return { valid: false, error: 'No file selected.' };

  const {
    maxSizeMB = null,
    allowedMimeTypes = IMAGE_MIME_TYPES,
    allowedExtensions = IMAGE_EXTENSIONS,
    label = 'Image',
  } = options;

  const name = String(file.name ?? '');
  const ext = name.includes('.') ? name.split('.').pop().toLowerCase() : '';
  const mime = String(file.type ?? '').toLowerCase();

  const mimeOk = !allowedMimeTypes.length || (mime && allowedMimeTypes.includes(mime));
  const extOk  = !allowedExtensions.length || (ext && allowedExtensions.includes(ext));

  if (!mimeOk && !extOk) {
    return { valid: false, error: `${label} "${name}" is unsupported. Use ${allowedExtensions.join(', ').toUpperCase()}.` };
  }
  if (Number.isFinite(maxSizeMB) && file.size > maxSizeMB * 1024 * 1024) {
    return { valid: false, error: `${label} "${name}" is larger than ${maxSizeMB} MB.` };
  }
  return { valid: true };
};
```

- **Accept on MIME *or* extension, not both.** Some browsers report an empty
  `file.type` for `.webp` and for files dragged from certain apps; requiring both
  rejects valid files.
- **Return `{ valid, error }`**, not a boolean — the caller needs the message.
- **Name the file in the error.** In a multi-file upload, "unsupported file" without
  a name is useless.
- **Client validation is UX, not security.** The server re-validates type and size.
  A renamed `.exe` passes every check here.
- Set `accept` on the input too, so the OS picker filters first.

## Preview before upload

```jsx
const [previews, setPreviews] = useState([]);

const handleFiles = (fileList) => {
  const files = Array.from(fileList);
  const rejected = files.map((f) => validateImageFile(f, { maxSizeMB: 5 })).find((r) => !r.valid);
  if (rejected) return toast.error(rejected.error);

  setPreviews((prev) => [...prev, ...files.map((file) => ({
    file, url: URL.createObjectURL(file), key: crypto.randomUUID(),
  }))]);
};

useEffect(() => () => previews.forEach((p) => URL.revokeObjectURL(p.url)), []);
```

**`URL.createObjectURL` leaks until revoked.** A gallery page where the user swaps
images twenty times holds twenty full-size blobs in memory. Revoke on unmount, and
on individual removal.

Never use `FileReader` + data URL for previews. It base64-encodes the whole file
into a string — roughly 33% larger and synchronous work on the main thread — where
an object URL is a pointer.

## FormData

Built in the page or a util, never in the service — the service stays shape-agnostic.

```js
const form = new FormData();
form.append('name', values.name);
form.append('price', values.price);
files.forEach((file) => form.append('photos[]', file));   // backend's array convention
await updateProduct(id, form);
```

- **Match the backend's array convention exactly** — `photos[]` for PHP-style,
  repeated `photos` for others. Guessing produces a silent "no files received".
- **`FormData` stringifies everything.** A boolean becomes `"false"`, which many
  backends read as truthy. Send `1`/`0`.
- **Omit a key entirely** to mean "unchanged". Appending an empty string usually
  means "clear this field".
- **Never set the `Content-Type` boundary yourself.** Set the bare
  `multipart/form-data` and let axios fill in the boundary.

## Drag and drop

```jsx
<div
  onDragOver={(e) => { e.preventDefault(); setDragging(true); }}
  onDragLeave={() => setDragging(false)}
  onDrop={(e) => { e.preventDefault(); setDragging(false); handleFiles(e.dataTransfer.files); }}
  className={clsx(styles.dropzone, dragging && styles.dragging)}
>
  <input type="file" accept={IMAGE_ACCEPT} multiple hidden ref={inputRef}
         onChange={(e) => handleFiles(e.target.files)} />
  <Button variant="secondary" onClick={() => inputRef.current?.click()}>Choose files</Button>
</div>
```

`preventDefault` on **both** `dragOver` and `drop`, or the browser navigates away
to open the dropped file. Always keep a click path beside the drop zone —
drag-and-drop alone is unusable by keyboard.

To let the same file be re-selected after removal, reset the input:
`e.target.value = ''` after reading `files`.

## Downloads

```js
const blob = await productService.downloadTemplate();
const url = URL.createObjectURL(blob);
const a = Object.assign(document.createElement('a'), { href: url, download: 'template.xlsx' });
a.click();
URL.revokeObjectURL(url);
```

Revoke immediately after the click. Remember from `react-zustand-networking` that
with `responseType: 'blob'` an *error* response is also a blob, so read it back as
text before trying to extract a message.

## Static assets in Vite

- Imported assets (`import logo from './logo.svg'`) are hashed and bundled — use
  these for anything the app ships.
- `public/` is copied verbatim and referenced by absolute path (`/favicon.ico`) —
  use it only for files that must keep a fixed name.
- **Never `src={'/src/assets/' + name}`.** Vite cannot see a runtime-built path, so
  the asset is not emitted and the URL 404s in production while working in dev.
  Use `new URL('./assets/x.png', import.meta.url).href` for a dynamic case.

## Pitfalls

- **`<img src="">`** — re-requests the page.
- **Two env vars for API and assets** — they drift.
- **Requiring both MIME and extension** — rejects valid `.webp`.
- **No `onError` fallback** — broken glyphs look like a crash.
- **Object URLs never revoked** — memory grows with every preview.
- **`FileReader` data URLs for previews** — 33% larger, main-thread work.
- **Hand-written multipart boundary** — malformed body.
- **Booleans in `FormData`** — `"false"` is truthy server-side.
- **Missing `preventDefault` on drop** — browser navigates away.
- **Runtime-concatenated asset paths** — 404 in production only.

## Related skills

- `react-zustand-networking` — multipart requests, upload progress, blob responses.
- `react-zustand-forms-validation` — file inputs inside a form.
- `react-zustand-ui-conventions` — `ImageUpload` / `ImagePreview` primitives.
- `react-zustand-performance` — image sizing, lazy loading, bundle impact.
