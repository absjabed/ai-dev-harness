# Tech-Specific Standards — FleetKeep

Concrete rules for *this* stack. Pairs with the universal standards in `.ai/standards/universal/`.

> This is the top-level, cross-cutting tech standard. Backend-only and frontend-only rules live in
> `backend/tech-specific.md` and `frontend/tech-specific.md`.

## Backend — C# 12 / ASP.NET Core 8 Web API / EF Core 8 / Azure SQL Database

### Language & typing

- `<Nullable>enable</Nullable>` and `<TreatWarningsAsErrors>true</TreatWarningsAsErrors>` in
  `Directory.Build.props` — a nullability warning fails the build. `!` (null-forgiving) requires a
  comment justifying it.
- Entities and value objects live in `FleetKeep.Domain`; DTOs live beside their service in
  `FleetKeep.Application/<Aggregate>/`. A domain entity is never serialized to a client.
- Prefer `sealed` classes, `record` for DTOs and value objects, and file-scoped namespaces.
- Enums are explicit-valued (`Reported = 1`) because they persist to the database; never renumber.
- No `dynamic`, no `object` parameters, no stringly-typed ids — use `VehicleId`/`DefectId` wrappers.

### ASP.NET Core 8 Web API handlers / entrypoints

- One controller per aggregate root under `FleetKeep.Api/Controllers/`, attribute-routed as
  `api/v1/[controller]`. No minimal APIs.
- Controllers are thin: model binding + FluentValidation, one service call, wrap in
  `ApiResponse<T>` — `{ data, error, traceId }`. No data access, no transactions, no business branches.
- Everything is registered in `Program.cs`, the single composition root. Middleware order is
  load-bearing: exception handler → auth → `TenantContextFilter` → endpoints.
- Local dev: `dotnet watch run --project src/Api/FleetKeep.Api` (see `project-config.md`).

### Service layer

- All business logic lives in application services; controllers never call repositories or
  `FleetKeepDbContext` directly.
- The service owns the transaction boundary and resolves tenant scope from `ITenantContext` before
  any read or write — never from the request payload.
- Services throw typed domain exceptions (`DomainRuleViolationException`,
  `IllegalStateTransitionException`, `NotFoundInTenantException`) that the exception-mapping
  middleware turns into 422/409/404. A service never returns an `ActionResult`.
- Cross-aggregate work is composed in the owning service inside one transaction — no distributed
  coordination, no partial commits.

### Azure SQL Database / EF Core 8

- Schema is defined by entity configurations in `FleetKeep.Infrastructure/Configurations/`, one per
  entity. Generate migrations with `dotnet ef migrations add <Name>` and apply with
  `dotnet ef database update` — never hand-write or hand-edit a migration file.
- Every tenant-owned entity has a non-nullable `TenantId` and is covered by the global query filter
  in the same change that adds it. A tenant-scoped query that escapes the filter is a security bug.
- Access the database only through the scoped `FleetKeepDbContext` injected into a repository.
  Never `new` a context, never open a second connection, never share one across requests.
- Reads that do not mutate use `AsNoTracking()`. Projections use `Select` into a DTO rather than
  loading whole entities.
- Migrations must be backward-compatible with the currently deployed API for one release
  (expand → migrate → contract), because deploys are rolling.
- No raw SQL outside a migration; `FromSqlRaw` with interpolation is forbidden outright.

### Auth

- Requests carry an Entra ID bearer token, validated for issuer, audience and signature against the
  cached JWKS. Tenant (`tid`) and user (`oid`) come **only** from the validated token.
- The server never trusts client-supplied identity: a `tenantId` or `userId` in a request body is a
  design error, and the property should not exist on the DTO.
- FleetKeep roles are loaded per request from the database, not read from token claims, so a
  revocation applies immediately.

### Anti-patterns (backend)

- Calling a repository or `FleetKeepDbContext` from a controller.
- `IgnoreQueryFilters()` outside `FleetKeep.Infrastructure.Admin`.
- Hand-editing a generated migration, or shipping one that breaks the previous API version.
- Returning an EF entity (or an `IQueryable`) across a layer boundary.
- Referencing EF Core, ASP.NET or Azure SDK types from `FleetKeep.Domain`.
- Logging PII — driver names, licence numbers, registrations. Log the entity id.
- `AutoMapper` or any reflection-based mapper; mappers are hand-written and explicit.

## Frontend — React 18 + Vite 5 / Mantine v7 theme tokens + CSS Modules

> Detailed rules live in `frontend/tech-specific.md`.

### Component structure

Feature-first: `src/features/<feature>/` owns its pages, components, hooks and tests. Anything used
by two features moves to `src/components/` or `src/hooks/`. Routes are registered only in
`src/routes/index.tsx`, lazy-loaded.

### Data fetching

TanStack Query v5 hooks in `src/api/hooks/`, one per endpoint, over the shared axios client.
Components never call `fetch()` or axios directly, and never mirror server data into `useState`.

### Routing

React Router v6 `createBrowserRouter` in `src/routes/index.tsx`. Protection via `<RequireAuth>`;
role-gated routes render `/forbidden` rather than redirecting.

### Branding / theming

Single brand. `src/theme/theme.ts` is the authoritative token source; light/dark resolves through
Mantine's `ColorSchemeScript`. No per-tenant white-labelling.

### Validation

Zod 3 + React Hook Form at form boundaries; the Zod schema types the payload and drives the error
messages. Client validation is UX only — the API re-validates everything with FluentValidation and
is the security boundary.

### Real-time

None. The dashboard polls with a 60s `refetchInterval`.

### Environment

Only `VITE_`-prefixed variables reach the browser: `VITE_API_BASE_URL`, `VITE_ENTRA_CLIENT_ID`,
`VITE_ENTRA_TENANT_ID`, `VITE_APP_ENV`. `process.env` does not exist in the bundle. Dev server runs
on port 5173 and proxies `/api`.

### Anti-patterns (frontend)

- Raw axios/`fetch` in a component instead of a query hook.
- A raw hex or px value where a Mantine token exists.
- Putting a secret behind a `VITE_` variable.
- Reading or refreshing an MSAL token by hand.
- Rendering a privileged control as disabled instead of not rendering it.
- Default-exported components.

## Additional services

### Worker (`src/Worker`) — .NET 8 isolated Azure Functions

- **Structure:** one file per trigger (`InspectionDueScan.cs`, `DefectEscalation.cs`); no business
  logic in the function body — it builds a tenant context and calls the same application services
  the API uses.
- **Dependencies:** references `FleetKeep.Application` and `FleetKeep.Infrastructure`. It must never
  duplicate a domain rule; if the worker needs new logic, it goes in the domain or a service.
- **Conventions:** every pass is idempotent (a re-run the same day produces no duplicate
  notifications); a tenant that throws is logged and skipped, never aborting the whole run;
  timer schedules live in configuration, not hardcoded CRON in an attribute string.
- **Anti-patterns:** calling the API over HTTP; a "scan all tenants" query that bypasses the tenant
  filter; long-running work without a cancellation token.

## Infrastructure / IaC

- Bicep in `infra/`: `main.bicep` plus `modules/*.bicep`, parameterised per environment with
  `env/{dev,staging,prod}.bicepparam`. One resource group per environment.
- Resource naming: `<resource-abbr>-fleetkeep-<env>` (`app-fleetkeep-dev`, `sql-fleetkeep-prod`,
  `kv-fleetkeep-staging`). Names are always derived in Bicep, never hardcoded in application code.
- Preview every change with `az deployment group what-if` before applying; deploys run from GitHub
  Actions, never a developer machine, and production deploys only from `main`.
- Secrets live in **Azure Key Vault** and reach apps as Key Vault references in App Settings,
  resolved by managed identity. We deliberately do **not** use connection strings in App Settings
  for SQL/Blob/Key Vault (managed identity instead), and never `.env` files or pipeline variables
  for secrets.

## Testing (current state)

| Subsystem | Status |
|-----------|--------|
| Backend | xUnit + FluentAssertions. Unit tests for `FleetKeep.Domain` and application services; Testcontainers-backed integration tests for repositories, migrations and the tenant filter. Runs in CI on every PR. |
| Frontend | Vitest + React Testing Library with MSW for API mocking; Playwright for end-to-end (happy paths for the dashboard and defect journey only). Runs in CI on every PR. |
| Worker | xUnit unit tests for the scan logic; no integration test — the timer itself is untested. |
| Infrastructure | `az bicep build` lint in CI plus a `what-if` on the dev resource group. No automated post-deploy verification. |

TDD is the default for backend domain and service work (`TDD_CHECK` is on in `hooks.env`): write the
failing test first. When adding tests, keep each subsystem's natural tooling and make sure the
`dotnet test` / `npm run test` entrypoints in `.ai/config/*/project-config.md` keep working.
