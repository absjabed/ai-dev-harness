<!-- TEMPLATE FILE — replace {{TOKENS}} and [FILL IN] blocks. See .ai/CUSTOMIZATION.md or run /init-project. -->
# Architecture

> Technical architecture of {{PROJECT_NAME}}. Read before designing changes.

## High-level shape

This is a {{REPO_TOPOLOGY}} with the following scopes: {{SCOPES}}.

> [FILL IN: your system-level architecture diagram — how the subsystems connect
> (e.g. client → API → service → data store, plus any async/AI/real-time paths).
> A tiny generic skeleton to adapt:]
>
> ```
> ┌────────────────────┐      ┌────────────────────┐
> │  {{FRONTEND_FRAMEWORK}} app   │──REST/WS──▶│  {{BACKEND_FRAMEWORK}} API │
> └────────────────────┘      └─────────┬──────────┘
>                                        ▼
>                              {{DATABASE}} ({{ORM}}) · {{AI_STACK}}
>                                        ▲
>                              {{CLOUD_PROVIDER}} infrastructure
> ```

## Backend architecture

### Request flow

> [FILL IN: your backend request flow. Describe how a request travels from the edge to the data
> store through your {{LAYERING_PATTERN}} and {{ROUTING_PATTERN}}. A generic skeleton:]
>
> ```
> edge / API layer
>    ▼
> {{ROUTING_PATTERN}}        ← dispatch to the right handler
>    ▼
> handler                    ← auth via {{AUTH_MECHANISM}}; thin, no business logic
>    ▼
> service layer              ← business logic; resolves caller context
>    ▼
> {{DATA_ACCESS_LAYER}}      ← {{ORM}} / {{DATABASE}} access
> ```
>
> State the invariants (e.g. "handlers never bypass the service layer").

### Code organization

> [FILL IN: describe the key backend directories under {{BACKEND_DIR}} and what lives in each —
> routing, handlers, services, {{DATA_ACCESS_LAYER}}, shared utils, enums/constants.
> One bullet per directory.]

### API modules

> [FILL IN: table of your API modules/domains and their purpose — one row each.
> This is the map an engineer uses to find where a feature lives.]
>
> | Module | Domain |
> |--------|--------|
> | ...    | ...    |

### Data stores

> [FILL IN: for each data store, list what it holds and the access rules.]
>
> - **{{DATABASE}} (via {{ORM}})** — [relational/primary data it holds].
> - [Any secondary stores: cache, object storage, search/vector index] — [what and why].
> - If multi-tenant, state the runtime naming/scoping scheme — see {{TENANT_ISOLATION_RULE}}.

### Auth flow

> [FILL IN: describe how authentication works end to end using {{AUTH_PROVIDER}} /
> {{AUTH_MECHANISM}} — token issuance, verification, and how caller/tenant context is resolved
> and scoped for data access. Numbered steps read well here.]

### Async processing

> [FILL IN: describe any async/background processing — queues, schedulers, workflow orchestration,
> event handlers. State how work is enqueued, how status is tracked, and where handlers live.
> Delete this subsection if the system is fully synchronous.]

## Frontend architecture

### Code organization

> [FILL IN: describe the key frontend directories under {{FRONTEND_DIR}} / {{SOURCE_DIR}} —
> routing entry point, component layering ({{LAYERING_PATTERN}}), hooks, state/contexts,
> API client layer, theming/config. One bullet per directory.]

### Data flow

> [FILL IN: how a screen gets its data — component → data hook → API client → backend, plus how
> the auth token is attached and how any real-time updates arrive. Numbered steps or a small
> sequence diagram work well.]

## AI architecture

> [FILL IN: if the product uses AI/ML, describe the {{AI_STACK}} — models, embeddings/vector store,
> orchestration framework, tracing/observability, and how the AI service is invoked from the
> backend/frontend. Delete this section if not applicable.]

## Infrastructure

> [FILL IN: describe how the system is provisioned and deployed on {{CLOUD_PROVIDER}} —
> IaC tool, the main stacks/modules and their resources, environments/stages, and the
> multi-tenant deployment model if any. A table of stacks → resources reads well.]

### Secrets and config

> [FILL IN: where secrets live and how runtime config is supplied (env vars, secret manager,
> parameter store). State the rule: no secrets in source or logs.]

## Notable gaps / future work

> [FILL IN: honestly list known gaps, missing test coverage, tech debt, and planned work.
> This tells agents and new engineers where the sharp edges are.]
