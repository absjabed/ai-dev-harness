---
description: Run the DevOps agent for CI/CD, deployment, and infrastructure tasks
allowed-tools: Read, Write, Edit
---
@.ai/agents/devops-agent.md
@.ai/standards/universal/security-baseline.md
@.ai/workflows/release-process.md

**Scope determination (do this first, before any other action):**
1. Read `.ai/config/current-scope.md` — if it starts with `# Forced scope:`, use that scope and skip to step 3.
2. Otherwise, analyze "$ARGUMENTS" to determine scope:
   - Backend signals: server-side infra/CI keywords — API/service deploy, database,
     migrations, infra-as-code, backend build/deploy > [FILL IN: your stack's backend infra keywords]
   - Frontend signals: client-side infra/CI keywords — frontend build, static site/CDN,
     frontend deploy > [FILL IN: your stack's frontend infra keywords]
   - Both or infrastructure affecting both → fullstack
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

## Execution mode (toggle with `.claude/scripts/devops-mode.sh`)
This command runs in one of two modes, controlled by whether `Bash` is in `allowed-tools` above:

- **Advise-only (OFF — current default):** `Bash` is absent, so you CANNOT run any command.
  Provide the exact commands to run, a runbook, and a rollback plan for the human to execute
  themselves. Do NOT claim anything was deployed, built, or run.
- **Execute (ON):** `Bash` is present. You MAY run commands, but every command still requires the
  user's explicit approval. Never deploy to production without explicit confirmation.

Switch modes from a terminal: `./.claude/scripts/devops-mode.sh on` / `off` / `status`.

Never modify production configs without explicit confirmation. Always provide a rollback plan.
