<!-- TEMPLATE FILE — replace {{TOKENS}} and [FILL IN] blocks. See .ai/CUSTOMIZATION.md or run /init-project. -->
# Backend Tech-Specific Standards

Concrete rules for the backend stack: {{BACKEND_LANGUAGE}} / {{BACKEND_FRAMEWORK}} / {{ORM}} /
{{DATABASE}} on {{CLOUD_PROVIDER}}.

## Language & typing ({{BACKEND_LANGUAGE}})

> [FILL IN: your language/typing rules — strictness, forbidden escape hatches, import conventions,
> return-type expectations.]

- Example: strict mode on. Never use an untyped escape hatch — narrow to a real type or define one. *(replace)*
- Example: use type-only imports where the language supports them. *(replace)*
- Example: prefer narrow dependency types (interface/subset) over importing a whole concrete service. *(replace)*

## Module / build system

> [FILL IN: how the backend is built and packaged for {{BACKEND_RUNTIME}} — module format, build/output
> layout, and any import-resolution quirks a contributor must know before adding imports.]

## {{BACKEND_FRAMEWORK}}

> [FILL IN: where routes, environment variables, and permissions are declared, and the exact
> deployment routing mechanism ({{ROUTING_PATTERN}}). Call out the "gotchas" that have actually bitten
> your team — e.g. a route must be registered in two places, path+method uniqueness, adding env vars
> in more than one file.]

- Example: routes/permissions/env are declared in one manifest — do not scatter route definitions. *(replace)*
- Example: every route's `path` + `method` must be unique; grep before adding one. *(replace)*
- Example: add new environment variables to the deploy manifest (not only local `.env`) so they reach {{BACKEND_RUNTIME}}. *(replace)*
- Example: test new routes locally before deploying. *(replace)*

## {{ORM}} ({{DATABASE}})

> [FILL IN: how relational data access is layered — where the shared client lives, where the schema
> lives, how migrations are generated/applied ({{MIGRATE_CMD}}), the tenant-isolation clause, and the
> "use the typed query builder, avoid raw SQL" rule.]

- Example: import the DB client **only** from a single shared client module — never instantiate a pool elsewhere. *(replace)*
- Example: define all tables in one schema module. *(replace)*
- Example: generate migrations with {{MIGRATE_CMD}} after schema changes — never hand-write migration files. *(replace)*
- Example: every tenant-scoped query must include a `where(tenantId = …)` clause, or it is a tenant-isolation security bug. *(replace)*

## Secondary datastore ({{SECONDARY_DATASTORE}})

> [FILL IN: if you use a second datastore (key-value, document, cache), state the wrapper/client to
> import from, where resource/table names are centralized (never hardcode name strings), and how to
> design access patterns consistently with what already exists. Delete this section if you have only
> one datastore.]

## Error handling

> [FILL IN: your error model — a typed error hierarchy vs. plain errors, how handlers map errors to
> HTTP status codes and a {{RESPONSE_ENVELOPE}}, the "never leak stack traces/internals" rule, and the
> logging contract (structured logger + required metadata like tenant/user IDs).]

- Example: throw typed errors from a shared error hierarchy — not bare `Error('...')` in services. *(replace)*
- Example: handlers map typed errors to status codes + a `{ error: { message, code } }` envelope. *(replace)*
- Example: never expose stack traces or internal details in responses. *(replace)*
- Example: log with context via a shared logger; include tenant/user identifiers in metadata. *(replace)*

## Request validation

> [FILL IN: how inputs are validated at the boundary using {{VALIDATION_LIB}} — where schemas live, the
> helper used at the top of handlers, and the failure response (e.g. `400` with field-level messages).]

- Example: validate all request bodies and query params before calling services. *(replace)*
- Example: define {{VALIDATION_LIB}} schemas in a shared validations module; assert at handler entry. *(replace)*
- Example: return `400` with a clear field-level message on validation failure. *(replace)*

## Request/response payload casing

> [FILL IN: if the frontend and backend use different key casing on the wire (e.g. a client helper
> transforms body keys), document the exact contract so handlers read the casing that actually arrives.
> This is a common repeat-offender bug: the client sends one casing while the handler reads another and
> the field silently comes through empty. Pick one convention and keep client and handler consistent.
> Delete this section if your wire format is uniform.]

## Anti-patterns

> [FILL IN: your backend anti-patterns as a table. Examples below — replace with real ones.]

| Anti-pattern | Correct approach |
|-------------|-----------------|
| Instantiating a DB pool/client directly in a handler | Import from the shared {{DATA_ACCESS_LAYER}} client module *(replace)* |
| Returning raw ORM row objects | Map to typed response types *(replace)* |
| Hardcoding a resource/table name string | Use a centralized name constant *(replace)* |
| Business logic in the routing layer | Logic belongs in services ({{LAYERING_PATTERN}}) *(replace)* |
| `throw new Error('Not found')` | Throw a typed `NotFoundError` (or equivalent) *(replace)* |
