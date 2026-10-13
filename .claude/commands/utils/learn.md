---
description: Record a project learning — a line in the append-only learnings log, or an area-specific path-scoped rule
allowed-tools: Read, Write, Edit, Bash
---

Record this learning: **$ARGUMENTS**

1. If "$ARGUMENTS" is empty, ask the user one short question — "What did we learn?" — and use
   their answer.
2. Distill it to one line: a short context plus the learning itself (what worked, what to avoid,
   or what was tried and abandoned — and why). Record only non-obvious, reusable learnings —
   not routine work.
3. If the learning is about design taste (visual patterns, UX choices, approved/rejected styles),
   offer to record it in `.ai/memory/design-taste.md` (in that file's entry format) instead.
4. If the learning only matters inside one area of the code (a screen, a module, a generated
   folder) and is more than a one-liner, offer to record it as a **path-scoped rule** instead:
   add it to the `.claude/rules/**/*.md` file whose `paths:` globs already cover that area, or
   create `.claude/rules/<area>.md` with `paths:` frontmatter listing the area's globs (the format
   is shown in `.claude/rules/_example-area.md`, if present). Claude Code loads a rule only when it
   reads or edits a matching file, so it costs no context elsewhere. Show the user the rule text and
   globs first; write it only on confirmation.
5. Otherwise, append a single entry under `## Learnings` in `.ai/memory/learnings.md`:
   `- YYYY-MM-DD | Context | Learning | human`
   Use today's real date at runtime (e.g. from `date +%F`) — never a hardcoded or guessed date.
6. Never rewrite, reorder, or delete existing log entries — append only. (A rule file is not a log:
   edit it in place when a rule changes.)

After appending, confirm by showing the entry you added.
