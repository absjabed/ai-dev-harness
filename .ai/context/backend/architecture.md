<!-- TEMPLATE FILE — replace {{TOKENS}} and [FILL IN] blocks. See .ai/CUSTOMIZATION.md or run /init-project. -->
# Backend Architecture

## Request Flow

> [FILL IN: your backend request flow, from the edge through {{ROUTING_PATTERN}} → handler →
> service → {{DATA_ACCESS_LAYER}} → {{DATABASE}}. A tiny generic mermaid skeleton to adapt:]
>
> ```mermaid
> sequenceDiagram
>     participant C as Client ({{FRONTEND_FRAMEWORK}})
>     participant API as API layer
>     participant H as Handler
>     participant S as Service
>     participant DA as {{DATA_ACCESS_LAYER}}
>     participant DB as {{DATABASE}}
>
>     C->>API: request + auth token
>     API->>H: dispatch ({{ROUTING_PATTERN}})
>     H->>H: verify auth ({{AUTH_MECHANISM}}) → caller context
>     H->>S: service.method(context, args)
>     S->>DA: query (scoped by {{TENANT_ISOLATION_RULE}})
>     DA->>DB: parameterized query
>     DB-->>DA: result
>     DA-->>S: typed result
>     S-->>H: domain object
>     H-->>C: formatted response
> ```

## Layer Diagram

> [FILL IN: a diagram of your backend layers and their allowed dependencies. Generic skeleton:]
>
> ```mermaid
> graph TD
>     API[API layer] --> R[{{ROUTING_PATTERN}}]
>     R --> H[Handler<br/>validate · call · return]
>     H --> S[Service<br/>business logic]
>     S --> DA[{{DATA_ACCESS_LAYER}}]
>     DA --> DB[({{DATABASE}})]
> ```

## Routing Pattern

> [FILL IN: describe your {{ROUTING_PATTERN}} — how an incoming request is matched to a handler
> (framework router, a dispatch map, file-based routing, etc.). Include a short, real code snippet
> from your codebase so the pattern is unambiguous. State the invariant that all routes for a
> domain are registered in one place.]

## Handler Structure

> [FILL IN: describe what a handler is responsible for and what it must NOT do (no DB calls,
> no business logic). Keep handlers thin: extract caller context, validate input, call a service,
> return a formatted response. Include a short representative snippet.]

## Service Layer

> [FILL IN: describe the service layer under {{BACKEND_DIR}} — one service per domain, owns all
> business logic and orchestration, calls {{DATA_ACCESS_LAYER}} (never the DB directly), and may
> call other services for cross-domain operations. Show the directory shape if helpful.]

## Data Access Layer

> [FILL IN: describe {{DATA_ACCESS_LAYER}} — where {{ORM}} schema/migrations/client live, how to
> obtain a client (singleton vs. per-request), and the rules for each store. State: always scope
> queries per {{TENANT_ISOLATION_RULE}} where multi-tenant; migrations go through the {{ORM}}
> tooling, never hand-written. Show the directory shape if helpful.]

## Auth & Claims Extraction

> [FILL IN: describe how each request is authenticated ({{AUTH_PROVIDER}} / {{AUTH_MECHANISM}}),
> what caller context/claims are extracted, and how RBAC gates privileged routes.]

## Async Patterns

> [FILL IN: describe async/background patterns — queues, schedulers, workflow orchestration,
> real-time push — where their handlers live and how status is reported back to callers.
> Delete this section if the backend is fully synchronous.]

## Local Development & Configuration

> [FILL IN: how to run the backend locally, how config/env vars and secrets are supplied at
> deploy and dev time, and any IaC/deploy config the backend depends on.]
