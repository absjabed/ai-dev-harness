---
description: Emergency hotfix — fast, minimal, safe, reviewed before it lands
allowed-tools: Read, Write, Edit, Bash, Task
---
@.ai/workflows/hotfix-process.md
@.ai/standards/universal/security-baseline.md

**Scope determination (do this first, before any other action):**
1. Read `.ai/config/current-scope.md` — if it starts with `# Forced scope:`, use that scope and skip to step 3.
2. Otherwise, analyze "$ARGUMENTS" to determine scope:
   - Backend signals: server-side keywords — API endpoints, services, data access,
     migrations, auth, background jobs > [FILL IN: your stack's backend keywords]
   - Frontend signals: UI keywords — components, pages, styling, forms, client state,
     routing > [FILL IN: your stack's frontend keywords]
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
Guard the fix, then verify against the affected scope's gates.

**Review gate (step 5) — before opening the {{PR_TERM}}:** spawn a `reviewer` Task agent:
> "Review this hotfix diff (`git diff {{DEFAULT_BRANCH}}...HEAD`) for: `$ARGUMENTS`. This is going
> straight to production. Confirm the change is minimal and reversible, addresses the root cause,
> and carries no unrelated edits. Flag anything that could make the incident worse. Apply the full
> reviewer checklist. Output BLOCKER/WARNING/SUGGESTION/PRAISE findings and an overall verdict."

Show the verdict in chat. **BLOCKER findings must be resolved before the {{PR_TERM}} is opened.**
If the outage is actively burning and the fix is a trivial revert, you may ask the user to approve
skipping this gate — state that you are asking, and record the skip in the {{PR_TERM}}. Never skip
it silently. Then land it via {{PR_TERM}} and forward-port.
