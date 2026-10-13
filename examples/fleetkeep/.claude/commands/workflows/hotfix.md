---
description: Emergency hotfix — fast, minimal, safe, reviewed before it lands
allowed-tools: Read, Write, Edit, Bash, Task
---
@.ai/workflows/hotfix-process.md
@.ai/standards/universal/security-baseline.md
@.ai/templates/deploy-notes.md

**Scope determination (do this first, before any other action):**
1. Read `.ai/config/current-scope.md` — if it starts with `# Forced scope:`, use that scope and skip to step 3.
2. Otherwise, analyze "$ARGUMENTS" to determine scope:
   - Backend signals: server-side keywords — API endpoints, services, data access,
     migrations, auth, background jobs — C#/`.cs`, ASP.NET Core controllers, application services, EF Core entities and migrations, `FleetKeepDbContext`, FluentValidation validators, the Azure Functions worker, Bicep/infra, anything under `src/Api` or `src/Worker`
   - Frontend signals: UI keywords — components, pages, styling, forms, client state,
     routing — `.tsx`/`.ts`, React components and hooks, Mantine v7, TanStack Query, React Router, CSS Modules, MSAL, `import.meta.env`, anything under `src/Web`
   - Both signal types or a feature spanning API+UI → fullstack
   - Truly ambiguous → ask the user before loading
3. Load only the files for the determined scope using the Read tool:
   - **backend**: `.ai/config/backend/project-config.md`, `.ai/context/backend/architecture.md`,
     `.ai/context/backend/project-overview.md`, `.ai/context/backend/business-rules.md`,
     `.ai/standards/project/backend/tech-specific.md`
   - **frontend**: `.ai/config/frontend/project-config.md`, `.ai/context/frontend/architecture.md`,
     `.ai/context/frontend/project-overview.md`, `.ai/context/frontend/business-rules.md`,
     `.ai/standards/project/frontend/tech-specific.md`
   - **fullstack**: all ten files above

Issue to hotfix: $ARGUMENTS

Follow the hotfix-process workflow. Minimal change only — no refactors, no unrelated cleanup.
Guard the fix, then verify against the affected scope's gates. Do not skip step 4a (deploy notes):
write `.ai/features/<slug>/deploy-notes.md` and commit it with the fix before the review gate, so it
is part of the reviewed diff.

**Review gate (step 5) — before opening the pull request:** spawn a `reviewer` Task agent:
> "Review this hotfix diff (`git diff main...HEAD`) for: `$ARGUMENTS`. This is going straight to
> production. Confirm the change is minimal and reversible, addresses the root cause, and carries
> no unrelated edits (its `.ai/features/<slug>/deploy-notes.md` belongs to the fix — check it
> matches the change and holds no secret). Flag anything that could make the incident worse. Apply the full reviewer
> checklist. Output BLOCKER/WARNING/SUGGESTION/PRAISE findings and an overall verdict."

Show the verdict in chat. **BLOCKER findings must be resolved before the pull request is opened.**
If the outage is actively burning and the fix is a trivial revert, you may ask the user to approve
skipping this gate — state that you are asking, and record the skip in the pull request. Never skip
it silently. Then land it via pull request and forward-port.
