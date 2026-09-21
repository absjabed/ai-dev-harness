---
description: Generate or update documentation for a module, function, or the whole project
allowed-tools: Read, Write, Edit
---

**Scope determination (do this first, before any other action):**
1. Read `.ai/config/current-scope.md` — if it starts with `# Forced scope:`, use that scope and skip to step 3.
2. Otherwise, analyze "$ARGUMENTS" to determine scope:
   - Backend signals: server-side keywords — services, API, endpoints, data access — C#/`.cs`, ASP.NET Core controllers, application services, EF Core entities and migrations, `FleetKeepDbContext`, FluentValidation validators, the Azure Functions worker, Bicep/infra, anything under `src/Api` or `src/Worker`
   - Frontend signals: UI keywords — components, pages, client state, styling — `.tsx`/`.ts`, React components and hooks, Mantine v7, TanStack Query, React Router, CSS Modules, MSAL, `import.meta.env`, anything under `src/Web`
   - No clear signal or "whole project" → fullstack
3. Load the architecture file for the determined scope using the Read tool:
   - **backend**: `.ai/context/backend/architecture.md`, `.ai/context/backend/project-overview.md`
   - **frontend**: `.ai/context/frontend/architecture.md`, `.ai/context/frontend/project-overview.md`
   - **fullstack**: all four files above

Generate documentation for: $ARGUMENTS

If no target given, update the README.md to reflect current project state. Keep docs accurate, concise, and developer-friendly.

**Mermaid diagrams:** Include a Mermaid diagram where it adds clarity:
- For a module/service: a sequence diagram showing the most common call pattern into it
- For a data model: an ER diagram of the relevant EF Core 8/Azure SQL Database schema tables
- For a UI component tree: a graph diagram showing the component hierarchy

Use ````mermaid` code blocks so GitHub and MkDocs render them visually. Keep diagrams concise — one diagram per key concept, not one per function.
