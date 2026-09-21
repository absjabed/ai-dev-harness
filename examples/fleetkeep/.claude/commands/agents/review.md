---
description: Run the Code Reviewer agent on recent changes or a specific file/module
allowed-tools: Read, Bash
disallowed-tools: Write, Edit, MultiEdit, NotebookEdit
---
@.ai/agents/reviewer-agent.md
@.ai/standards/universal/coding-principles.md
@.ai/standards/universal/security-baseline.md
@.ai/standards/universal/testing-principles.md
@.ai/workflows/code-review.md
@.ai/templates/pr-description.md

**Scope determination (do this first, before any other action):**
1. Read `.ai/config/current-scope.md` — if it starts with `# Forced scope:`, use that scope and skip to step 3.
2. Otherwise, analyze "$ARGUMENTS" (or the changed files if reviewing a diff) to determine scope:
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

Your task: $ARGUMENTS

If no specific target is given, review all uncommitted changes (run git diff). Load the tech-specific standards for the determined scope — violations are judged against those standards. Follow the code-review workflow. Use severity levels: BLOCKER, WARNING, SUGGESTION, PRAISE.
