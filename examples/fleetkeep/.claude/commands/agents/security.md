---
description: Run a dedicated security audit on current changes, a specific file/directory, or the full diff
allowed-tools: Read, Bash
disallowed-tools: Write, Edit, MultiEdit, NotebookEdit
---
@.ai/agents/security-agent.md
@.ai/standards/universal/security-baseline.md
@.ai/templates/security-report.md

**Scope determination (do this first, before any other action):**
1. Read `.ai/config/current-scope.md` — if it starts with `# Forced scope:`, use that scope and skip to step 3.
2. Otherwise, analyze "$ARGUMENTS" to determine scope:
   - Files/paths under `src/Api/` → backend
   - Files/paths under `src/Web/` → frontend
   - Both, or no specific target given → fullstack
3. Load only the files for the determined scope using the Read tool:
   - **backend**: `.ai/config/backend/project-config.md`, `.ai/context/backend/architecture.md`,
     `.ai/context/backend/project-overview.md`, `.ai/context/backend/business-rules.md`,
     `.ai/standards/project/backend/tech-specific.md`
   - **frontend**: `.ai/config/frontend/project-config.md`, `.ai/context/frontend/architecture.md`,
     `.ai/context/frontend/project-overview.md`, `.ai/context/frontend/business-rules.md`,
     `.ai/standards/project/frontend/tech-specific.md`
   - **fullstack**: all ten files above

Your target: $ARGUMENTS

If no target is given, audit all uncommitted changes (`git diff HEAD`). Run your package manager's dependency audit (NuGet (.NET) and npm (web)) at high severity in the relevant sub-project(s). Apply the full security checklist from the agent definition. Output a security report using the template — one finding per row, with file:line, severity, issue description, and recommended fix.
