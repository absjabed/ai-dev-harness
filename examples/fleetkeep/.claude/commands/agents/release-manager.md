---
description: Prepare a complete release package — release notes, migration plan, rollback plan, deployment checklist, and (if switched on) the deployment guide
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
4. Resolve the target version and collect the in-scope deploy notes, per the persona's *Target
   version* and *Deploy notes in scope*
5. Generate all four internal release artifacts and write them to `.ai/releases/<version>/`, using
   the version resolved in step 4 (not the raw arguments, which may also carry a scope word):
   - `release-notes.md`
   - `migration-plan.md`
   - `rollback-plan.md`
   - `deployment-checklist.md`
6. **Only if the deployment guide is switched on** (`project-config.md` → Release deliverables),
   produce the fifth, human-facing output for the release version, as described in
   `.ai/agents/release-agent.md` → *Deployment guide*:
   - `docs/release/<version>/deployment-guide-<version>.md` (created from
     `.ai/templates/deployment-guide.md`, or merged into the existing guide)
   - its `.docx`, if the Word copy is on, produced by
     `python .claude/scripts/md-to-docx.py docs/release/<version>/deployment-guide-<version>.md --org "<company>" --color "<#primary>"` (company name and primary colour from `.ai/config/branding.md`)
   - the `## Guides` row in `docs/release/README.md`

   **If the guide already exists, show the user your proposed changes and get confirmation before
   writing** — guides are hand-updated during rollout (ticked matrix cells, corrected steps, added
   screenshots), and the `.docx` is overwritten wholesale by the converter.

Report the path to each file, the converter's output (including any `warning:` lines), and a
one-paragraph summary of the release content.
