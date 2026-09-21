---
description: Run the Project Manager agent for status reports, planning, and changelogs
allowed-tools: Read, Write, Edit, Bash, mcp__atlassian
---
@.ai/agents/pm-agent.md
@.ai/memory/decisions.md

**Scope determination (do this first, before any other action):**
1. Read `.ai/config/current-scope.md` — if it starts with `# Forced scope:`, use that scope and skip to step 3.
2. Otherwise, analyze "$ARGUMENTS" to determine scope:
   - Backend signals: API, backend, data access, migration, server-side > [FILL IN: your stack's backend keywords]
   - Frontend signals: UI, frontend, component, page, browser-side > [FILL IN: your stack's frontend keywords]
   - Both or no clear signal → fullstack (PM tasks often span both)
   - Truly ambiguous → default to fullstack for status/standup tasks
3. Load only the files for the determined scope using the Read tool:
   - **backend**: `.ai/config/backend/project-config.md`, `.ai/context/backend/project-overview.md`
   - **frontend**: `.ai/config/frontend/project-config.md`, `.ai/context/frontend/project-overview.md`
   - **fullstack**: all four files above

Your task: $ARGUMENTS

Examples: "generate sprint summary", "create changelog since last tag", "list all TODOs in the codebase", "generate standup report"
