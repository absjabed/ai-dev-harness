---
description: Generate a changelog from git commits
allowed-tools: Read, Bash
---

**Scope determination (do this first):**
1. Read `.ai/config/current-scope.md` — if it starts with `# Forced scope:`, use that scope.
2. Otherwise: no argument signals → default to fullstack (changelog covers all commits).
   If "$ARGUMENTS" mentions backend or frontend explicitly, scope to that directory.

Generate a changelog from git log since: $ARGUMENTS (default: last tag)

Format as Keep a Changelog (keepachangelog.com). Group by: Added, Changed, Fixed, Security, Removed.
Focus git log on the `{{BACKEND_DIR}}/` or `{{FRONTEND_DIR}}/` directory if scoped, otherwise all commits.
