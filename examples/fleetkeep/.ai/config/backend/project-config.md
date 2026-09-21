# Backend Project Config

## Identity
**Project**: FleetKeep — Backend API
**Root directory**: `src/Api`
**Runtime**: .NET 8 (LTS)
**Language**: C# 12
**Framework**: ASP.NET Core 8 Web API
**Cloud provider**: Azure
**Runtime defaults**: App Service Linux P1v3, region `uksouth` (all environments), request timeout
230s (App Service default), always-on enabled, rolling deploys with no downtime window.

## Tech Stack
| Layer | Technology |
|-------|-----------|
| Language | C# 12 |
| API framework | ASP.NET Core 8 Web API |
| ORM | EF Core 8 |
| Database | Azure SQL Database (S2 in dev/staging, P1 in production) |
| Auth | Microsoft Entra ID (OIDC authorization-code + PKCE in the SPA (MSAL), JWT bearer validated by the API) |
| Validation | FluentValidation 11 |
| Logging | Serilog → Application Insights |
| Mapping | Explicit hand-written mappers (no AutoMapper) |
| Cloud services | Azure Blob Storage (defect photos, signed inspection PDFs), Azure Key Vault (secrets, surfaced as App Settings references), Azure Communication Services (notification email), Application Insights + Log Analytics |

## Development Commands
```bash
dotnet restore                                                            # Install dependencies
dotnet watch run --project src/Api/FleetKeep.Api                          # Local dev server
dotnet build -c Release                                                   # Build
dotnet build -warnaserror                                                 # Type-check (compiler is the type-check)
dotnet format --verify-no-changes                                         # Lint / format check
dotnet test                                                               # Test
dotnet ef migrations add <Name> --project src/Api/FleetKeep.Infrastructure  # Create a migration
dotnet ef database update --project src/Api/FleetKeep.Infrastructure      # Apply DB migrations
```

## Project Structure
```
src/Api/
├── FleetKeep.Api/              # request/route layer: controllers, filters, middleware, Program.cs
├── FleetKeep.Application/      # business logic: application services, DTOs, FluentValidation validators
├── FleetKeep.Infrastructure/   # data access: FleetKeepDbContext, repositories, Migrations/, blob + email clients
├── FleetKeep.Domain/           # entities, value objects, pure domain rules — no EF Core reference
└── FleetKeep.Api.Tests/        # xUnit + FluentAssertions; Testcontainers for SQL integration tests
```

## Conventions
- **Handlers are thin**: validate request → call service → return response. No business logic.
- **Service layer owns business logic**: application services live in
  `FleetKeep.Application/<Aggregate>/` named `<UseCase>Service` (e.g. `InspectionScheduleService`),
  registered scoped in `Program.cs`. A service owns the transaction boundary — a controller never
  opens one.
- **Data access is isolated**: only import persistence via the injected repository layer over `FleetKeepDbContext` — never from handlers or services directly
- **Routing pattern**: attribute-routed controllers
  > `[ApiController]` + `[Route("api/v1/[controller]")]`, one controller per aggregate root, one
  > action per use case. Minimal APIs are not used. Route parameters are typed; there are no
  > catch-all routes.
- **Tenant isolation**: every query is scoped to the caller's tenant by the `TenantId` global query filter on `FleetKeepDbContext`
  > `TenantContextFilter` reads the `tid` claim from the validated JWT into `ITenantContext` before
  > the action runs; `FleetKeepDbContext` applies the filter from that. `IgnoreQueryFilters()` is
  > banned outside `FleetKeep.Infrastructure.Admin`.
- **Response shape**: use `ApiResponse<T>` — `{ data, error, traceId }` for all responses; never construct raw error objects in handlers
- **Domain purity**: `FleetKeep.Domain` takes no dependency on EF Core, ASP.NET or Azure SDKs. If a
  rule needs I/O it belongs in an application service, not the domain.
- **Migrations are expand → migrate → contract**: every migration must run against the previously
  deployed API without breaking it, because deploys are rolling.

## Never Do
- Call the database / persistence layer directly from a handler file
- Return raw ORM / database objects to clients — map to response types
- Call `IgnoreQueryFilters()` outside `FleetKeep.Infrastructure.Admin`
- Hand-edit a generated EF Core migration — regenerate it
- Hardcode resource names or cloud service identifiers — use config / env vars
- Add business logic to the routing layer
- Log PII (driver names, licence numbers, registrations) — log the entity id instead
- Commit secrets or credentials
