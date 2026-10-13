---
description: Full bug fix workflow — reproduce → root cause → fix → verify → review → commit
allowed-tools: Read, Write, Edit, Bash, Task
---
@.ai/agents/developer-agent.md
@.ai/agents/qa-agent.md
@.ai/workflows/bug-fixing.md
@.ai/standards/universal/testing-principles.md

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

Bug to fix: $ARGUMENTS

Follow the bug-fixing workflow completely. Guard the fix first — a failing test where the scope has
a test runner, a documented manual reproduction where it has none. Fix the root cause. Verify.

**Review gate (step 7) — before committing:** spawn a `reviewer` Task agent:
> "Review the current fix diff (`git diff HEAD`) for: `$ARGUMENTS`. Confirm it addresses the root
> cause rather than a symptom, follows the loaded scope's standards, and introduces no regression
> in the surrounding code. Apply the full reviewer checklist. Output BLOCKER/WARNING/SUGGESTION/
> PRAISE findings and an overall verdict."

Show the verdict in chat. **BLOCKER findings must be resolved before you commit** — re-run the
reviewer after fixing them. Then commit with a "fix:" prefix.
