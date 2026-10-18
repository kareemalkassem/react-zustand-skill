# {{App}} Foundation

Date: {{YYYY-MM-DD}}
Status: source of truth. Code follows this file; when they disagree, fix one of them the same day.

## Product

- Users: {{who logs in, e.g. front-desk staff, sellers, admins}}
- Jobs (3–5): {{the tasks the app must make fast}}
- Out of scope: {{what this app will not do}}

## Roles and permissions

- Roles: `super_admin` (bypasses every check) + `staff` (checked per permission).
- Permission names: `domain.action` — {{products.view, products.create, orders.confirm, ...}}
- The UI never branches on a role name other than the super-admin bypass.

## API contract

```json
{ "success": true, "message": "", "data": {}, "request_id": "uuid", "error_code": null, "errors": {} }
```

- Lists: `data.items` + `data.meta` ({{page, per_page, total, last_page}})
- Auth: {{Bearer token from POST /auth/login; GET /auth/me restores the session}}
- Locale header: {{Accept-Language | X-Locale}}
- Errors: 401 → login, 403 → hide/disable, 422 → `errors` per field, 5xx → toast + request id
- Timestamps: UTC ISO 8601; formatted in the browser

## Brand tokens

| Token | Value | Use |
| --- | --- | --- |
| `--color-primary` | {{#hex}} | primary buttons, active nav |
| `--color-bg` | {{#hex}} | page background |

Fonts: {{latin display / body}}; {{arabic display / body}} if bilingual.

## Locales

{{en only | en + ar (RTL)}} — default {{en}}.

## Real-time surfaces

{{which lists update live; transport: mock timer → WebSocket/Reverb/Firebase}}. REST stays authoritative.

## 3D surfaces

{{none | which screens show a 3D view, target device, size/fps budget}}
