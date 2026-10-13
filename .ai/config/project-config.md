<!-- TEMPLATE FILE — replace {{TOKENS}} and [FILL IN] blocks. See .ai/CUSTOMIZATION.md or run /init-project. -->
# Project Configuration

> Single source of truth for project-specific configuration. To reuse this agent system on
> another project, this is the primary file to rewrite.

## Project Identity

- **Name:** {{PROJECT_NAME}}
- **Type:** {{PROJECT_TYPE}}
- **Purpose:** {{PROJECT_PURPOSE}}
- **Target users:** {{TARGET_USERS}}

## Tech Stack

### Backend (`{{BACKEND_DIR}}`)

- **Language:** {{BACKEND_LANGUAGE}}
- **Runtime:** {{BACKEND_RUNTIME}}
- **Framework:** {{BACKEND_FRAMEWORK}}
- **Relational DB:** {{DATABASE}} via {{ORM}} ({{DATA_ACCESS_LAYER}})
- **Auth:** {{AUTH_PROVIDER}} ({{AUTH_MECHANISM}})
- **Cloud provider:** {{CLOUD_PROVIDER}}
- **Package manager:** {{PACKAGE_MANAGER}}

### Frontend (`{{FRONTEND_DIR}}`)

- **Framework:** {{FRONTEND_FRAMEWORK}}
- **Language:** {{FRONTEND_LANGUAGE}}
- **UI:** > [FILL IN: styling system, component library, animation libs]
- **State / data:** > [FILL IN: state management + data-fetching approach]
- **Routing:** > [FILL IN: router library and version]
- **Auth:** {{AUTH_PROVIDER}}
- **Validation:** {{VALIDATION_LIB}}

### AI / ML Services (optional — remove if not applicable)

- **Stack:** {{AI_STACK}}
- **Notes:** > [FILL IN: LLM provider, orchestration framework, vector store, tracing, real-time transport]

### DevOps (`{{IAC_DIR}}`)

- **IaC:** {{IAC_TOOL}}
- **Notes:** > [FILL IN: stacks/modules, core resources, secrets strategy]

## Development Commands

### Backend — run from `{{BACKEND_DIR}}`

| Goal | Command |
|------|---------|
| Install dependencies | `{{INSTALL_CMD}}` |
| Local API server | `{{DEV_CMD}}` |
| Build | `{{BUILD_CMD}}` |
| Type-check | `{{TYPECHECK_CMD}}` |
| Lint | `{{LINT_CMD}}` |
| Test | `{{TEST_CMD}}` |
| Run migrations | `{{MIGRATE_CMD}}` |

### Frontend — run from `{{FRONTEND_DIR}}`

| Goal | Command |
|------|---------|
| Install dependencies | `{{INSTALL_CMD}}` |
| Dev server | `{{DEV_CMD}}` |
| Production build | `{{BUILD_CMD}}` |
| Lint | `{{LINT_CMD}}` |
| Test | `{{TEST_CMD}}` |

### AI / ML Services — run from `{{SOURCE_DIR}}` (optional)

> [FILL IN: how to install deps and run each service locally; remove this section if not applicable]

### DevOps — run from `{{IAC_DIR}}`

> [FILL IN: build, diff/preview, deploy, and test commands for your IaC tool]

## Project Structure

```
{{PROJECT_NAME}}/
├── {{BACKEND_DIR}}/
│   └── {{SOURCE_DIR}}/          # > [FILL IN: key backend subfolders]
├── {{FRONTEND_DIR}}/
│   └── {{SOURCE_DIR}}/          # > [FILL IN: key frontend subfolders]
└── {{IAC_DIR}}/                 # > [FILL IN: infrastructure entry + modules]
```

**Key files to know:** > [FILL IN: 4–8 files a new contributor should read first, with a one-line purpose each]

## Conventions

- **Backend layering:** {{LAYERING_PATTERN}} — describe what each layer is responsible for.
  > [FILL IN: responsibilities per layer]
- **Routing pattern:** {{ROUTING_PATTERN}}
  > [FILL IN: how routes/endpoints are declared and registered]
- **Data access:** All persistence goes through {{DATA_ACCESS_LAYER}}.
  > [FILL IN: naming rules, isolation rules, forbidden shortcuts]
- **Tenant isolation:** {{TENANT_ISOLATION_RULE}}
- **Schema changes:** > [FILL IN: how to change the DB schema safely (e.g. edit schema then run `{{MIGRATE_CMD}}`)]
- **Frontend data fetching:** > [FILL IN: preferred data-fetching pattern and where it lives]
- **Frontend validation:** {{VALIDATION_LIB}} at form boundaries.
  > [FILL IN: where validation is/ isn't applied]
- **Environment variables:** > [FILL IN: naming prefix and how secrets are supplied in each environment]
- **Branding / theming:** > [FILL IN: how brand/theme is selected, if applicable — otherwise remove]

**Never do in this project:**

> [FILL IN: hard rules — e.g. don't bypass the service layer, don't hardcode resource names,
> don't hand-write migrations, don't assume tooling exists that hasn't been set up]

## Release deliverables

Read by the release agent (`.ai/agents/release-agent.md`). Every feature, bugfix and hotfix writes
`.ai/features/<slug>/deploy-notes.md` regardless; these settings decide what the release path builds
from them beyond the internal artifacts in `.ai/releases/<version>/`.

- **Deployment guide:** > [FILL IN: `on` — `/workflows:release` also writes a human-facing guide at
  `docs/release/<version>/deployment-guide-<version>.md`, assembled from the deploy notes; or `off`
  — internal release artifacts only. Choose `on` when someone outside the dev team performs or
  approves deployments (an ops team, customer IT, a hosting partner).]
- **Guide audience:** > [FILL IN: who follows the guide and what they work in — e.g. "customer IT
  administrators; cloud console and CI web UI only, no command line". Delete if the guide is off.]
- **Word copy:** > [FILL IN: `on` — also generate a `.docx` with `.claude/scripts/md-to-docx.py`
  (needs Python 3 + `python-docx` + `markdown-it-py`); or `off` — Markdown only.]
- **Deployable units:** > [FILL IN: each separately deployed unit, in deploy order — they become
  the guide's "Application deployment" subsections, the environment-matrix columns, and the
  `Application: <unit>` targets in deploy notes. E.g. "API (container app) → web SPA (static
  hosting) → worker (functions)".]
- **Environments & rollout order:** > [FILL IN: e.g. "staging → production"; if deployed per tenant,
  region or customer, say which goes first and how far one is taken before the rest.]

## Architecture Notes

> [FILL IN: 3–6 bullets on the big-picture shape — independent subsystems, data stores,
> async workflows, real-time transport, deployment model. Point to
> `.ai/context/architecture.md` for the full write-up and `.ai/context/business-rules.md`
> for domain rules.]
