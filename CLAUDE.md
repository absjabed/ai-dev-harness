<!-- TEMPLATE FILE — replace {{TOKENS}} and [FILL IN] blocks. See .ai/CUSTOMIZATION.md or run /init-project. -->
# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

{{PROJECT_NAME}} is {{PROJECT_TAGLINE}}.

> [FILL IN: 1–2 sentences describing what the project does and who it is for.]

The repository is a {{REPO_TOPOLOGY}} with the following sub-projects:

- `{{BACKEND_DIR}}/` — > [FILL IN: backend responsibility, language/runtime]
- `{{FRONTEND_DIR}}/` — > [FILL IN: frontend responsibility, framework]
- `{{SOURCE_DIR}}/` — > [FILL IN: optional AI/ML or additional service dir; remove if not applicable]
- `{{IAC_DIR}}/` — > [FILL IN: infrastructure-as-code responsibility]

## Commands

### Backend (`{{BACKEND_DIR}}`)

```bash
{{INSTALL_CMD}}      # Install dependencies
{{DEV_CMD}}          # Local dev server
{{BUILD_CMD}}        # Build
{{TYPECHECK_CMD}}    # Type-check
{{LINT_CMD}}         # Lint
{{TEST_CMD}}         # Test
{{MIGRATE_CMD}}      # Run DB migrations
```

### Frontend (`{{FRONTEND_DIR}}`)

```bash
{{INSTALL_CMD}}   # Install dependencies
{{DEV_CMD}}       # Dev server
{{BUILD_CMD}}     # Production build
{{LINT_CMD}}      # Lint
{{TEST_CMD}}      # Test
```

### AI / ML or Additional Services (`{{SOURCE_DIR}}`)

```bash
# > [FILL IN: how to run each additional service locally; remove this section if not applicable]
```

### Infrastructure (`{{IAC_DIR}}`)

```bash
# > [FILL IN: build, deploy, diff/preview, and test commands for {{IAC_TOOL}}]
```

## Architecture

### Backend

> [FILL IN: high-level shape of the backend — entry points, how it is structured.]

**{{ROUTING_PATTERN}}**: > [FILL IN: how requests are routed to handlers.]

```
> [FILL IN: representative backend folder tree — routing layer, handlers, config]
```

Business logic lives in the service layer. Data access goes through {{DATA_ACCESS_LAYER}}:

- {{ORM}} for {{DATABASE}} (schema and {{MIGRATIONS_DIR}})
- > [FILL IN: any additional data stores and their access wrappers]

### Frontend

> [FILL IN: component organisation (e.g. atomic design), where route-level pages live.]

Shared state uses > [FILL IN: state approach]. API calls live in a single client layer. Imports use a path alias to the source root.

> [FILL IN: multi-brand / theming behaviour if applicable — otherwise remove this line.]

### AI / ML or Additional Services

> [FILL IN: describe additional services and the AI stack if applicable. Remove if not applicable.]

Stack: {{AI_STACK}}.

### Authentication Flow

1. User authenticates via {{AUTH_PROVIDER}}
2. A token is attached to all API requests ({{AUTH_MECHANISM}})
3. The backend validates the token
4. Authorization is enforced per handler

> [FILL IN: multi-tenancy model, if any — e.g. how tenant isolation is achieved.]
> See {{TENANT_ISOLATION_RULE}}.

### Infrastructure ({{IAC_TOOL}})

> [FILL IN: list the stacks/modules and the core resources each provisions.]

## Environment Variables

**Backend** (see `.env.example`):
```
# > [FILL IN: backend env vars — cloud credentials/region, DB connection, environment name.
#   Never commit secret values.]
```

**Frontend** (see `{{FRONTEND_DIR}}/.env.local.example`):
```
# > [FILL IN: client-exposed env vars using your framework's required prefix — API URL,
#   auth config, feature flags. Never commit secret values.]
```

## Agent System

This repo ships a full Claude Code agent system. See [`README.md`](README.md) for an overview and
[`CUSTOMIZATION.md`](.ai/CUSTOMIZATION.md) for how to tailor it to this project. The `.ai/` directory
contains the knowledge base: architecture context, agent role definitions, workflow playbooks, and
output templates. The `.claude/` directory contains slash commands, sub-agent definitions, and hooks.

First-time setup: run `/init-project` to fill in this template. Then invoke agents via slash commands —
`/ba`, `/qa`, `/agents:architect`, `/agents:dev`, `/agents:review`, `/agents:security`,
`/workflows:feature`, `/workflows:bugfix`, `/workflows:release`, etc.
