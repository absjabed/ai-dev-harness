---
description: Project health check — tests, TODOs, outdated deps, git status
allowed-tools: Read, Bash
disallowed-tools: Write, Edit, MultiEdit, NotebookEdit
---

**Scope determination (do this first):**
1. Read `.ai/config/current-scope.md` — if it starts with `# Forced scope:`, scope the health check to that sub-project.
2. Otherwise, analyze "$ARGUMENTS":
   - "backend" → check only `{{BACKEND_DIR}}/`
   - "frontend" → check only `{{FRONTEND_DIR}}/`
   - No argument or "all" → check both (fullstack)
3. Load the project-config for the determined scope to get the exact test and lint commands:
   - **backend**: `.ai/config/backend/project-config.md`
   - **frontend**: `.ai/config/frontend/project-config.md`
   - **fullstack**: both

Run a complete project health check for the determined scope:
1. Run the test suite and report results
2. Show git status (uncommitted changes, recent commits)
3. List all TODO/FIXME/HACK comments in source files (scoped to the active directory)
4. Check for any obvious security issues (hardcoded secrets)
5. Report any lint/type errors
6. Summarize overall project health in 3 bullet points
