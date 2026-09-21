# Backend Tech-Specific Standards

Concrete rules for the backend stack: C# 12 / ASP.NET Core 8 Web API / EF Core 8 /
Azure SQL Database on Azure.

## Language & typing (C# 12)

- Nullable reference types are enabled solution-wide and warnings are errors
  (`Directory.Build.props`). A `!` null-forgiving operator needs a comment saying why it is safe.
- Never widen to `object` or `dynamic`. If a type is awkward, define one — strongly-typed ids
  (`readonly record struct VehicleId(Guid Value)`) instead of bare `Guid`s, so a defect id cannot
  be passed where a vehicle id belongs.
- `sealed` by default; `record` for DTOs and value objects; file-scoped namespaces; `var` only when
  the type is obvious from the right-hand side.
- Depend on the narrow interface (`IVehicleRepository`), never on a concrete service or the
  `DbContext`, so tests can substitute.
- Enums that persist are explicit-valued and never renumbered; adding a member appends.
- `async` all the way down, always with a `CancellationToken` parameter threaded from the action.
  No `.Result`, no `.Wait()`, no `async void`.

## Module / build system

- One solution, `FleetKeep.sln`, four API projects (`Api`, `Application`, `Domain`,
  `Infrastructure`) plus test projects. Project references point downward only; `Domain` references
  nothing.
- Shared build settings (nullable, warnings-as-errors, language version, analyzers) live in
  `Directory.Build.props` — never per-project.
- Package versions are pinned centrally in `Directory.Packages.props` (central package management).
  A `PackageReference` with an inline `Version` in a `.csproj` fails review.
- `dotnet build -c Release` must be warning-free; CI builds with `-warnaserror`.

## ASP.NET Core 8 Web API

- Routes are declared **only** as attributes on controllers under
  `FleetKeep.Api/Controllers/`, prefixed `api/v1/[controller]`. There is no central route table,
  and no route is declared in `Program.cs`.
- Every action needs an explicit HTTP verb attribute, an explicit route suffix when it is not the
  collection root, and a `ProducesResponseType` for each status it can return — the OpenAPI document
  is generated from these and the frontend client is generated from that.
- `Program.cs` is the only composition root. **Middleware order is load-bearing:** exception
  handler → HTTPS redirect → authentication → authorization → `TenantContextFilter` → endpoints.
  Inserting middleware in the wrong place is how tenant scoping silently stops applying.
- **Gotcha — new configuration in three places.** A new setting must be added to (1) the typed
  options class, (2) the App Service module in `infra/modules/app-service.bicep`, and (3)
  `src/Worker`'s Bicep module if the worker reads it. Options are validated with `ValidateOnStart`,
  so a missing setting fails the deploy rather than the first request that needs it.
- **Gotcha — a new endpoint is not reachable from the SPA until the client is regenerated**
  (`npm run api:generate` in `src/Web`). Ship both in the same change.
- Test a new endpoint locally against Swagger UI (`/swagger`) before opening a pull request.

## EF Core 8 (Azure SQL Database)

- The scoped `FleetKeepDbContext` is injected into repositories only. Never `new` a context, never
  resolve one in a controller, never hold one in a static or singleton.
- Schema lives in `FleetKeep.Infrastructure/Configurations/`, one `IEntityTypeConfiguration<T>` per
  entity, applied by assembly scan. No data annotations on domain entities — `FleetKeep.Domain`
  stays EF-free.
- Generate migrations with `dotnet ef migrations add <Name> --project src/Api/FleetKeep.Infrastructure`
  and apply with `dotnet ef database update --project src/Api/FleetKeep.Infrastructure`. Never
  hand-write or edit a generated migration; if it is wrong, delete and regenerate.
- Every migration is backward-compatible with the previously deployed API for one release
  (expand → migrate → contract): add nullable, backfill, switch the code, drop in a later release.
  Rolling deploys mean both versions run simultaneously.
- **Tenant isolation:** every tenant-owned entity has a non-nullable `TenantId`, is registered in
  the global query filter, and is stamped in `SaveChangesAsync` from `ITenantContext`. A query that
  escapes that filter is a tenant-isolation **security bug**, not a defect.
- Use the typed LINQ query builder. No raw SQL outside a migration, and `FromSqlRaw` with an
  interpolated string is forbidden — parameterise or use LINQ.
- `AsNoTracking()` on every read that does not mutate; `Select` into a DTO rather than materialising
  whole aggregates for a list view.
- Watch for N+1: a list endpoint uses a single projection, not a loop of lazy loads. Lazy loading
  proxies are disabled deliberately.

## Secondary datastore (Azure Blob Storage — defect photos and signed inspection PDFs)

- Access blobs only through `IBlobStore` in `FleetKeep.Infrastructure/Blobs/`. Never construct a
  `BlobServiceClient` elsewhere.
- Container names and path templates are centralised in `BlobPaths` — never a hardcoded string at
  a call site. Paths are always tenant-prefixed: `{tenantId}/defects/{defectId}/{blobId}`.
- Authentication is managed identity (`DefaultAzureCredential`); there is no account key in
  configuration.
- The API never streams file bytes. It issues a short-lived (15 minute) user-delegation SAS URL and
  the client uploads or downloads directly.
- Containers are private. A public container, or a SAS with a long expiry, is a review blocker.

## Error handling

- Services throw from a typed hierarchy in `FleetKeep.Application/Common/Errors/`:
  `NotFoundInTenantException`, `DomainRuleViolationException`, `IllegalStateTransitionException`,
  `ConcurrencyConflictException`. Never `throw new Exception("…")` in a service.
- A single exception-handling middleware maps them to status codes and to
  `ApiResponse<T>` — `{ data, error, traceId }`: not-found → 404, domain rule → 422, illegal
  transition → 409, concurrency → 409, validation → 400, everything else → 500.
- A 500 response carries a generic message plus the `traceId`. Stack traces, SQL text, connection
  strings and inner exception messages never reach a client.
- Log with Serilog structured properties — `{TenantId}`, `{UserId}`, `{VehicleId}`, `{TraceId}` —
  never string-concatenated messages. **No PII in logs:** no driver names, licence numbers or
  vehicle registrations; log the entity id and look it up if needed.

## Request validation

- One FluentValidation validator per request DTO, colocated with it in
  `FleetKeep.Application/<Aggregate>/`, auto-registered by assembly scan and executed by the
  validation filter before the action body runs.
- Validate everything that crosses the boundary: body, route and query parameters, including page
  size bounds on list endpoints.
- Failure returns `400` with field-level messages in `error.details` (`{ field, message }`), which
  the SPA maps back onto its form fields.
- Validators check shape and range only. A rule that needs the database (does this vehicle have an
  open category-A defect?) is a domain rule and belongs in the service, returning 422.

## Request/response payload casing

The wire format is `camelCase` in both directions — `System.Text.Json` with
`JsonNamingPolicy.CamelCase`, configured once in `Program.cs`. C# properties stay `PascalCase`; the
TypeScript client is generated from the OpenAPI document, so casing never has to be transformed by
hand on either side. Do not add `[JsonPropertyName]` to individual properties to "fix" a field —
that produces an inconsistent contract and a client that silently reads `undefined`.

## Anti-patterns

| Anti-pattern | Correct approach |
|-------------|-----------------|
| Injecting `FleetKeepDbContext` into a controller | Inject the application service; the repository owns the context |
| `IgnoreQueryFilters()` in application code | Only `FleetKeep.Infrastructure.Admin` may do this, and it is tested |
| Returning an EF entity or `IQueryable` from a service | Map to a DTO inside the service |
| Hand-editing a generated migration | Delete and regenerate with `dotnet ef migrations add` |
| A migration that breaks the previous API version | Expand → migrate → contract across two releases |
| `new BlobServiceClient(...)` at a call site | Use `IBlobStore`; paths come from `BlobPaths` |
| `throw new Exception("Not found")` | Throw `NotFoundInTenantException` so the middleware maps it |
| Reading `tenantId` from the request body | Read it from `ITenantContext` (populated from the token) |
| `.Result` / `.Wait()` on a task | `await`, with the `CancellationToken` threaded through |
| Logging a registration or driver name | Log the entity id |
| Business logic in a controller action | Move it into the application service |
