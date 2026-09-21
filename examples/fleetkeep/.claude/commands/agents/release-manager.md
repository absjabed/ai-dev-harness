---
description: Prepare a complete release package — release notes, migration plan, rollback plan, and deployment checklist
allowed-tools: Read, Write, Edit, Bash
---
@.ai/agents/release-agent.md
@.ai/workflows/release-process.md
@.ai/templates/release-checklist.md

**Scope determination (do this first, before any other action):**
1. Read `.ai/config/current-scope.md` — if it starts with `# Forced scope:`, use that scope and skip to step 3.
2. Otherwise, analyze "$ARGUMENTS":
   - "backend" explicitly in version string or args → backend
   - "frontend" explicitly → frontend
   - A version number alone (e.g. `v1.2.3`) or no qualifier → fullstack
3. Load scope-specific config:
   - **backend**: `.ai/config/backend/project-config.md`
   - **frontend**: `.ai/config/frontend/project-config.md`
   - **fullstack**: both config files

Release version: $ARGUMENTS

Follow the release-agent methodology:
1. Find the last git tag and enumerate commits since then
2. Run your package manager's audit command (NuGet (.NET) and npm (web)) at high severity in relevant sub-projects
3. Check the EF Core 8 migrations directory (see src/Api) for new migrations
4. Generate all four release artifacts and write them to `.ai/releases/$ARGUMENTS/`:
   - `release-notes.md`
   - `migration-plan.md`
   - `rollback-plan.md`
   - `deployment-checklist.md`

Report the path to each file and a one-paragraph summary of the release content.
