---
paths:
  - "path/to/your/area/**"
---

# Example path-scoped rule — copy, rename, then delete this file

Claude Code loads every `.md` file under `.claude/rules/` (subfolders too). A rule **with** `paths:`
frontmatter loads only when Claude reads or edits a file matching one of the globs; a rule
**without** it loads in every session, like `CLAUDE.md`. This file's glob matches nothing, so it
never loads until you point it at real code.

Use a rule for knowledge that only matters inside one area of the codebase — a screen, a legacy
module, a generated folder — so it costs no context anywhere else. Project-wide rules belong in
`.ai/standards/project/**/tech-specific.md`; one-line lessons in `.ai/memory/learnings.md`.
`/utils:learn` offers to write a rule when a lesson is specific to one area.

To make one:

1. Copy this file to `.claude/rules/<area>.md` (or `.claude/rules/<scope>/<area>.md`).
2. Set `paths:` to the globs for that area, e.g. `"src/web/screens/billing/**"`.
3. Replace this text with the area's rules: where the source of truth is, traps that cost someone
   time, conventions that differ from the rest of the codebase. Short, imperative, verifiable —
   and say how to re-check a rule before relying on it if it may go stale.

Other agents (Codex, Cursor, Gemini) don't read `.claude/rules/`; `AGENTS.md` tells them to.
