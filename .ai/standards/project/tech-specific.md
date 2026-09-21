<!-- TEMPLATE FILE — replace {{TOKENS}} and [FILL IN] blocks. See .ai/CUSTOMIZATION.md or run /init-project. -->
# Tech-Specific Standards — {{PROJECT_NAME}}

Concrete rules for *this* stack. Pairs with the universal standards in `.ai/standards/universal/`.

> This is the top-level, cross-cutting tech standard. Backend-only and frontend-only rules live in
> `backend/tech-specific.md` and `frontend/tech-specific.md`. Keep only the subsystems your project
> actually has — delete the rest.

## Backend — {{BACKEND_LANGUAGE}} / {{BACKEND_FRAMEWORK}} / {{ORM}} / {{DATABASE}}

### Language & typing

> [FILL IN: your backend language/typing rules — e.g. "strict typing on, no untyped escape hatches",
> "where domain types and enums live", module system expectations.]

- Example: strict typing preferred; avoid untyped escape hatches where a real type exists. *(replace)*
- Example: domain types/enums live in a shared module (e.g. `{{SOURCE_DIR}}/shared/`). *(replace)*

### {{BACKEND_FRAMEWORK}} handlers / entrypoints

> [FILL IN: how your service exposes endpoints/handlers and how routing is wired — e.g.
> "{{ROUTING_PATTERN}}: one module per resource", "where routes/functions are registered",
> "how to run the service locally".]

- Example: one module per domain under `{{BACKEND_DIR}}/<module>/`. *(replace)*
- Example: individual handlers extract the authenticated user, call service functions, and return via
  a shared response helper ({{RESPONSE_ENVELOPE}}). *(replace)*
- Example: local dev via {{TEST_CMD}}-adjacent command (see `project-config.md`). *(replace)*

### Service layer

> [FILL IN: how business logic is layered ({{LAYERING_PATTERN}}) and what handlers may/may not do —
> e.g. "all business logic in services", "handlers never touch the data layer directly", tenant
> scoping rules.]

- Example: all business logic lives in a service layer; handlers never call the {{DATA_ACCESS_LAYER}} directly. *(replace)*
- Example: every function that reads tenant data must resolve the tenant/resource scope first. *(replace)*
- Example: throw typed/status-tagged errors so handlers can map them to HTTP responses. *(replace)*

### {{DATABASE}} / {{ORM}}

> [FILL IN: how the {{DATA_ACCESS_LAYER}} is structured — where the schema lives, how migrations are
> generated/run ({{MIGRATE_CMD}}), tenant-isolation clauses, and the client-access rule.]

- Example: define schema in one place; generate migrations with {{MIGRATE_CMD}} — never hand-write migration files. *(replace)*
- Example: every tenant-scoped query must include the tenant filter, or it is a security bug. *(replace)*
- Example: access the DB only through a single shared client module — never instantiate a pool elsewhere. *(replace)*

### Auth

> [FILL IN: how requests are authenticated with {{AUTH_PROVIDER}} — token extraction/verification,
> and the rule that server never trusts client-supplied identity/tenant IDs.]

### Anti-patterns (backend)

> [FILL IN: your backend anti-patterns. Examples below — replace with real ones.]

- Example: calling the {{DATA_ACCESS_LAYER}} from a handler (skipping the service layer). *(replace)*
- Example: hardcoding tenant-specific resource names instead of resolving them at runtime. *(replace)*
- Example: hand-writing migrations. *(replace)*

## Frontend — {{FRONTEND_FRAMEWORK}} / {{STYLING_SYSTEM}}

> Delete this whole section if the project has no frontend. Detailed rules live in
> `frontend/tech-specific.md`.

### Component structure

> [FILL IN: your component organization convention — e.g. atomic design, feature folders — and where
> new pages/routes are registered.]

### Data fetching

> [FILL IN: how components fetch server data — the hook/client layer, and the rule that components
> never call the raw HTTP layer directly.]

### Routing

> [FILL IN: where routes are defined and the routing conventions to follow.]

### Branding / theming

> [FILL IN: multi-brand or theming approach, if any — config location and how to select a brand/theme.
> Delete if single-brand.]

### Validation

> [FILL IN: client-side validation approach using {{VALIDATION_LIB}} — and whether the backend also
> validates.]

### Real-time (if applicable)

> [FILL IN: real-time transport (WebSocket/SSE/etc.), which service it connects to, and connection
> lifecycle rules. Delete if not applicable.]

### Environment

> [FILL IN: env var conventions for the frontend — prefix, key vars, and dev server port.]

### Anti-patterns (frontend)

> [FILL IN: your frontend anti-patterns. Examples below — replace with real ones.]

- Example: raw HTTP calls in components when a shared hook/service exists. *(replace)*
- Example: hardcoding brand-specific colors/text instead of using config/tokens. *(replace)*

## Additional services

> [FILL IN: rules for any other subsystems your project ships — e.g. an AI/ML service, a worker
> service, a separate admin app. Give each its own subsection with Structure / Dependencies / usage
> conventions / Anti-patterns. Delete this section if you have none.]

## Infrastructure / IaC

> [FILL IN: your infrastructure conventions on {{CLOUD_PROVIDER}} — IaC tool and layout, deploy/preview
> commands, resource naming conventions, and secrets handling (prefer a managed secrets store; state
> what you use and what you deliberately do NOT use). Delete if IaC is out of scope for this repo.]

## Testing (current state)

> [FILL IN: the real current testing state per subsystem so the agent knows what exists vs. what to
> add. Update the table below to match reality.]

| Subsystem | Status |
|-----------|--------|
| Backend | [FILL IN: test runner + whether a suite exists] |
| Frontend | [FILL IN] |
| Other services | [FILL IN] |
| Infrastructure | [FILL IN] |

When adding tests, follow each subsystem's natural tooling and ensure a {{TEST_CMD}} entrypoint exists
in the relevant package/manifest so `.ai/config/*/project-config.md` commands work.
