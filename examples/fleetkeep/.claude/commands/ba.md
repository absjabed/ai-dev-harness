---
description: BA Studio — interview a business analyst and generate branded requirement + user-story artifacts (single feature or epic)
argument-hint: <feature-name> [rough requirement or issue key]
allowed-tools: Read, Write, Edit, Bash, mcp__atlassian
---
@.ai/agents/ba-studio-agent.md
@.ai/config/branding.md
@.ai/templates/artifact-header.md
@.ai/templates/user-story.md

**Scope determination (do this first):**
1. Read `.ai/config/current-scope.md` — if it starts with `# Forced scope:`, use that scope and skip to step 3.
2. Otherwise infer scope from "$ARGUMENTS":
   - server-side keywords (APIs, services, data access, jobs, auth) → **backend**
   - UI keywords (screens, components, forms, styling, client state) → **frontend**
   - both / ambiguous → **fullstack**
   > FleetKeep signals — **backend:** endpoint, API, migration, EF Core, job, worker, scan,
   > escalation, tenant, role/permission, audit, export. **frontend:** screen, page, dashboard,
   > table, form, filter, chip/badge, Mantine, mobile/walkaround, dark mode.
3. Load the matching context:
   - **backend**: `.ai/config/backend/project-config.md`, `.ai/context/backend/project-overview.md`, `.ai/context/backend/business-rules.md`
   - **frontend**: `.ai/config/frontend/project-config.md`, `.ai/context/frontend/project-overview.md`, `.ai/context/frontend/business-rules.md`
   - **fullstack**: both sets
   - **single-project repos**: `.ai/config/project-config.md`, `.ai/context/project-overview.md`, `.ai/context/business-rules.md`

Feature/Epic: $ARGUMENTS

If "$ARGUMENTS" references an issue-tracker key (e.g. `ABC-123`), follow the BA Studio agent's
**issue-tracker intake** protocol before the interview.

Operate as the **BA Studio agent**. Interview the BA interactively (follow the interaction protocol),
**decide whether this is a single feature or an epic**, and confirm the outline. Then write the branded
artifacts under `.ai/features/<slug>/`, creating folders as needed:

- **Single feature** → `requirement-spec.md` and `user-stories.md`.
- **Epic** → `epic-breakdown.md`, plus `requirement-spec.md` and `user-stories.md` under each
  `<sub-feature>/` sub-folder.

Each artifact must begin with the rendered branded header from `.ai/templates/artifact-header.md`.
`/workflows:feature` consumes these and never regenerates them.
