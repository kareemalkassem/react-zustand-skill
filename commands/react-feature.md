---
description: Scaffold a complete React+Zustand feature — service, store, list page, form page, CSS module, and route entry — following the react-zustand conventions.
argument-hint: <entity-name> [--read-only]
---

# /react-feature

Scaffold the full module for `$ARGUMENTS` using the `react-zustand-feature-template`
skill.

## Steps

1. **Invoke `react-zustand-feature-template`** and follow it. Do not improvise a
   different layout.

2. **Gather the four inputs it requires.** Ask only for what you cannot determine
   from the repo:
   - entity singular and plural
   - real endpoint paths and methods — read the backend route file, a Postman
     export, or an OpenAPI spec. Never invent them.
   - the response envelope shape
   - read-only or full CRUD (`--read-only` skips the form page and write actions)

3. **Read one existing service, one store, and one page in this project** and match
   their shape. Local convention wins over the template where they differ.

4. **Generate bottom-up**: service → store → CSS module → list page → form page →
   route entry → nav entry → `logout` reset registration.

5. **Verify, do not assume.** Run `npm run lint`. Start the dev server, open the
   route, and confirm: rows render, the skeleton shows while loading, the empty
   state appears under an impossible filter, the error state appears with the API
   down, one filter change produces one request rather than one per keystroke, and
   a reload restores the filters from the URL.

6. **Write at least one store test** using the `react-zustand-testing` template —
   including the read-swallows and write-throws cases.

7. **Report what you actually observed**, endpoint by endpoint. If a step could not
   be run (no backend available, no dev server), say which and why. Never report
   "should work".

## Output

Then list:
- every file created, with its line count
- the exact route entries added to `App.jsx`
- the endpoints wired, and where you read them from
- what you verified and what you could not
