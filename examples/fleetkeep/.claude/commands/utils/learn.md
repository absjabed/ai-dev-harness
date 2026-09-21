---
description: Record a one-line project learning in the append-only learnings log
allowed-tools: Read, Edit, Bash
---

Record this learning: **$ARGUMENTS**

1. If "$ARGUMENTS" is empty, ask the user one short question — "What did we learn?" — and use
   their answer.
2. Distill it to one line: a short context plus the learning itself (what worked, what to avoid,
   or what was tried and abandoned — and why). Record only non-obvious, reusable learnings —
   not routine work.
3. If the learning is about design taste (visual patterns, UX choices, approved/rejected styles),
   offer to record it in `.ai/memory/design-taste.md` (in that file's entry format) instead.
4. Otherwise, append a single entry under `## Learnings` in `.ai/memory/learnings.md`:
   `- YYYY-MM-DD | Context | Learning | human`
   Use today's real date at runtime (e.g. from `date +%F`) — never a hardcoded or guessed date.
5. Never rewrite, reorder, or delete existing entries — append only.

After appending, confirm by showing the entry you added.
