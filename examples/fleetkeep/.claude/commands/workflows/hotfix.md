---
description: Emergency hotfix — fast, minimal, safe
allowed-tools: Read, Write, Edit, Bash
---
@.ai/workflows/hotfix-process.md
@.ai/standards/universal/security-baseline.md

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

Follow the hotfix-process workflow. Minimal change only. Test thoroughly. Merge to main and release branch.
