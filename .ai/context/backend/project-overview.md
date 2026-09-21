<!-- TEMPLATE FILE — replace {{TOKENS}} and [FILL IN] blocks. See .ai/CUSTOMIZATION.md or run /init-project. -->
# Backend Project Overview

## What It Does

> [FILL IN: 2-4 sentences on what the {{PROJECT_NAME}} backend does, who/what consumes it
> (e.g. the {{FRONTEND_FRAMEWORK}} app, other services), and its main responsibilities.
> The backend is written in {{BACKEND_LANGUAGE}} using {{BACKEND_FRAMEWORK}} and lives in
> {{BACKEND_DIR}}.]

## API Domains

> [FILL IN: table of the API domains/modules and their purpose — one row each. This is the map
> an engineer uses to locate where a feature lives on the backend.]
>
> | Domain | Purpose |
> |--------|---------|
> | ...    | ...     |

## Infrastructure

> [FILL IN: list the backend's runtime building blocks. Suggested items to cover:]
> - **Compute**: [how the backend runs — e.g. containers or managed functions on {{CLOUD_PROVIDER}}]
> - **API layer**: [gateway / router / server entry point]
> - **Databases**: {{DATABASE}} (via {{ORM}}) [and any secondary stores]
> - **Storage**: [object/file storage, if any]
> - **Auth**: {{AUTH_PROVIDER}}
> - **Async**: [queues, schedulers, workflow orchestration — if any]
> - **AI**: {{AI_STACK}} [if applicable]
> - **Real-time**: [WebSocket/streaming layer — if any]

## Multi-tenant Model

> [FILL IN: if multi-tenant, describe what isolated resources each tenant gets and how the caller's
> tenant scopes every read/write — see {{TENANT_ISOLATION_RULE}}. Delete this section if the
> product is single-tenant.]
