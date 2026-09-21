---
description: Run the Business Analyst agent to generate user stories and requirements
allowed-tools: Read, Write, Edit
---
@.ai/agents/ba-agent.md
@.ai/workflows/story-generation.md
@.ai/templates/user-story.md

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

Your task: $ARGUMENTS

Follow the story-generation workflow. Load the project overview and business rules for the determined scope, then cross-check stories against those business rules. Ask clarifying questions if the request is ambiguous.
