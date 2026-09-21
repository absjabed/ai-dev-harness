<!-- TEMPLATE FILE — replace {{TOKENS}} and [FILL IN] blocks. See .ai/CUSTOMIZATION.md or run /init-project. -->
# Backend Business Rules

## Authentication & Authorization

> [FILL IN: the backend auth/authz rules. Suggested items to cover:]
> - Which routes require a valid token via {{AUTH_MECHANISM}} and which are public.
> - What claims/caller context are trusted (and which values must NOT be taken from the request
>   body — e.g. tenant/customer identity is the source of truth from the token).
> - Which roles gate which privileged operations (RBAC).

## Multi-Tenancy

> [FILL IN: if multi-tenant, the isolation rules — see {{TENANT_ISOLATION_RULE}}. State that every
> data access must be scoped to the caller's tenant across {{DATABASE}} and any other store, and
> that violating isolation is a BLOCKER-severity security bug. Delete if single-tenant.]

## Domain Rules

> [FILL IN: capture backend domain rules grouped by feature area (one `###` sub-heading each).
> For each area list the invariants: state machines and allowed transitions, ownership/access
> constraints, sync vs. async behavior, idempotency/locking, and limits. These become test cases.]

## API Contracts

> [FILL IN: your standard response envelope for success and error, pagination convention for list
> endpoints (never return unbounded lists), and the HTTP status code convention. Generic skeleton:]
>
> **Success response**:
> ```json
> { "data": { } }
> ```
>
> **Error response**:
> ```json
> { "error": { "message": "Human-readable message", "code": "MACHINE_CODE" } }
> ```
>
> **HTTP status codes**: [list the codes you use and their meaning — 200/201/400/401/403/404/409/500].

## Rules Still To Be Defined

> [FILL IN: backend rules the team knows it needs but has not decided/implemented — rate limits,
> quotas, concurrency limits, retention policies. Naming them prevents silent assumptions.]
