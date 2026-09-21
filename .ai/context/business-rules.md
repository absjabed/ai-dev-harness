<!-- TEMPLATE FILE — replace {{TOKENS}} and [FILL IN] blocks. See .ai/CUSTOMIZATION.md or run /init-project. -->
# Business Rules

> Domain rules that govern this system. Capture rules that are enforced in code *and* rules that
> currently live in people's heads. Treat security/isolation rules as authoritative and testable.

## Multi-tenancy

> [FILL IN: if the product is multi-tenant, describe the isolation model and the non-negotiable
> rules — how the caller's tenant is resolved, how every data access is scoped
> (see {{TENANT_ISOLATION_RULE}}), and what isolated resources each tenant gets.
> Delete this section if the product is single-tenant.]

## Authentication & authorization

> [FILL IN: describe how requests are authenticated ({{AUTH_PROVIDER}} / {{AUTH_MECHANISM}}) and
> how authorization/RBAC is enforced — roles, feature access, and which routes are protected vs.
> public. State that authorization is enforced server-side, not just in the UI.]

## Domain rules

> [FILL IN: capture the core domain rules, grouped by feature area (one `###` sub-heading per
> area). For each, list the invariants: state machines and allowed transitions, ownership/access
> constraints, sync vs. async behavior, and any limits. These are the rules QA will verify.]

## Rules still to be defined

> [FILL IN: list rules the team knows it needs but has not decided/implemented yet — quotas, rate
> limits, retention policies, edge-case behavior. Naming them prevents silent assumptions.]
