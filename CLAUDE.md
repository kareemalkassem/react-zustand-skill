# react-zustand-skill — repo rules

This repo IS a Claude Code plugin (`react-zustand`). Everything under `skills/`,
`agents/`, `commands/`, and `hooks/` ships to whoever installs it.

## Editing rules

- **Skills stay atomic.** One concern per skill directory. If a change spans two
  concerns, it belongs in two skills.
- **Edit the repo, never the installed copy.** The plugin cache and any
  `~/.claude/skills/` remnants are build artifacts, not sources.
- **Update the README skill table** whenever a skill is added, renamed, or removed —
  and the "family of N skills" count with it. `validate-skills.mjs` fails on drift.
- **Validate before committing:** `node scripts/validate-skills.mjs` and
  `claude plugin validate .` must both pass.
- **The hook script must never block.** `scripts/format-js.sh` exits 0 on every
  path. Keep it that way — a formatter that can fail a tool call turns a cosmetic
  problem into a stopped session.
- **Cite verification sources.** When a convention or gotcha comes from reviewing a
  real codebase rather than general React knowledge, say so in the skill text and
  add it to `skills/react-zustand-core/references/extraction-notes.md` under
  VERIFIED or CORRECTED. Unattributed assertions read as invented, and cannot be
  re-checked later. `react-zustand-gotchas` marks these **[observed]**.

## Layout

- `.claude-plugin/` — plugin + marketplace manifests
- `skills/` — the 17 `react-zustand-*` skills (a `SKILL.md` each)
- `skills/react-zustand-core/references/extraction-notes.md` — provenance ledger
- `agents/react-reviewer.md` — convention-review subagent
- `commands/react-feature.md` — `/react-feature` scaffolding command
- `hooks/hooks.json` + `scripts/format-js.sh` — eslint-fix-on-edit hook
- `scripts/validate-skills.mjs` — zero-dependency repo validator
- `docs/superpowers/specs/` — design docs

## The opinions this family encodes

These are settled. Changing one is a repo-wide decision, not a per-skill edit.

1. **Four boundaries**: `pages` render, `store` holds state, `services` transport,
   `api.js` owns every cross-cutting concern.
2. **One axios instance.** Nothing outside `services/` imports axios.
3. **Reads swallow into `error`; writes throw.** Stated explicitly, not implied.
4. **The envelope is unwrapped in the service**, never in a store.
5. **CSS Modules + `variables.css` only.** No Tailwind, no second styling system.
6. **Every page is `lazy()`.** Guards are routes rendering `<Outlet />`.
7. **Filter, sort, and page state live in the URL**, not `useState` alone.
8. **JavaScript + JSX**, not TypeScript — matching the source the family was
   extracted from. A TS variant would be a separate decision, applied to every
   skill at once.

## Writing a skill

- Frontmatter is flat: `name` (matching the directory) and `description` only. The
  description is what makes the skill trigger — make it specific about *when*, and
  include the words a user would actually type.
- Open with why the concern is hard, not with a definition of the library.
- Show the shape first, then the rules it encodes, then the pitfalls.
- Every pitfall names its consequence. "Do not do X" without "because Y breaks" is
  not actionable.
- End with a `## Related skills` list, and cross-reference by name in backticks so
  the validator can check it.
- Keep a skill under roughly 300 lines. Past that, it is two skills.
