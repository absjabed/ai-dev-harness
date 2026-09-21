---
description: Run the Designer agent to produce UI/UX design + a Claude Artifact preview and run the user approval loop
allowed-tools: Read, Write, Edit, Bash
---
@.ai/agents/designer-agent.md
@.ai/standards/universal/ui-ux-standards.md
@.ai/standards/universal/accessibility.md
@.ai/standards/universal/frontend-design.md
@.ai/standards/project/frontend/design/README.md
@.ai/standards/project/frontend/design/palette.md
@.ai/standards/project/frontend/design/design-tokens.md
@.ai/standards/project/frontend/design/component-specs.md
@.ai/templates/design-spec.md

**Scope:** Design applies to any **UI surface** — a {{FRONTEND_FRAMEWORK}} screen (`frontend`) or, where the backend renders its own views, a server-rendered view (`backend`) — but **not** to non-UI backend work (pure API / data / migration / background services): if the task is non-UI backend, tell the user design doesn't apply and stop. Otherwise load the UI context for what you're designing — the **frontend** context for a {{FRONTEND_FRAMEWORK}} screen (`.ai/config/frontend/project-config.md`, `.ai/context/frontend/*`, `.ai/standards/project/frontend/tech-specific.md`), or the **backend** context for a server-rendered view (`.ai/config/backend/project-config.md`, `.ai/context/backend/*`, `.ai/standards/project/backend/tech-specific.md`). The design docs included above cover **every** UI stack the project has — see `.ai/standards/project/frontend/design/README.md`.

Your task: $ARGUMENTS

Run the Designer agent's phases (UX → visual design → Artifact preview → design-system & accessibility validation), then run the mandatory user review loop on the published Artifact until the user explicitly approves. Write the design to `.ai/features/<feature-slug>/design/design-spec.md` using the design-spec template, recording the Artifact URL and approved version. Never commit the preview HTML.
