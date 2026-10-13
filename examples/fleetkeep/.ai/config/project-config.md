# Project Configuration

> Single source of truth for project-specific configuration. To reuse this agent system on
> another project, this is the primary file to rewrite.

## Project Identity

- **Name:** FleetKeep (`fleetkeep` / `Northwind.FleetKeep`)
- **Type:** Multi-tenant B2B SaaS monorepo — ASP.NET Core API + React SPA + Azure Functions worker + Bicep IaC
- **Purpose:** keep commercial vehicle fleets road-legal and roadworthy: it tracks statutory
  inspection and MOT due dates, driver walkaround defect reports, workshop job cards, and parts
  stock, and warns operators before a compliance deadline is missed.
- **Target users:** transport managers, workshop technicians, compliance officers, depot
  administrators, and tenant admins at haulage and coach operators (multi-tenant B2B SaaS)

## Tech Stack

### Backend (`src/Api`)

- **Language:** C# 12
- **Runtime:** .NET 8 (LTS)
- **Framework:** ASP.NET Core 8 Web API
- **Relational DB:** Azure SQL Database via EF Core 8 (the injected repository layer over `FleetKeepDbContext`)
- **Blob storage:** Azure Blob Storage (defect photos and signed inspection PDFs)
- **Auth:** Microsoft Entra ID (OIDC authorization-code + PKCE in the SPA (MSAL), JWT bearer validated by the API)
- **Validation:** FluentValidation 11 (one validator per request DTO, auto-registered)
- **Logging:** Serilog → Application Insights
- **Cloud provider:** Azure
- **Package manager:** NuGet

### Frontend (`src/Web`)

- **Framework:** React 18 + Vite 5
- **Language:** TypeScript 5.5 (strict)
- **UI:** Mantine v7 theme tokens + CSS Modules; Mantine v7 components; `@tabler/icons-react`; no animation library — the three CSS keyframe tokens in `design-tokens.md` cover it
- **State / data:** TanStack Query v5 for all server state (no Redux); React context only for the
  session/tenant object; component-local `useState` for everything else
- **Routing:** React Router v6 (`createBrowserRouter`, route modules under `src/Web/src/routes/`)
- **Auth:** Microsoft Entra ID via `@azure/msal-react`
- **Validation:** Zod 3 + React Hook Form at form boundaries
- **Package manager:** npm

### Background Worker (`src/Worker`)

- **Stack:** not applicable — FleetKeep ships no AI/ML services; `src/Worker` is a plain .NET 8 isolated Azure Functions app
- **Notes:** two timer-triggered functions — `InspectionDueScan` (nightly 02:00 UTC, raises
  due/overdue notifications) and `DefectEscalation` (hourly, escalates unactioned category-A
  defects). Shares `FleetKeep.Infrastructure` with the API, so it uses the same `DbContext`,
  repositories and tenant filter. No HTTP triggers.

### DevOps (`infra`)

- **IaC:** Bicep
- **Notes:** one deployment per environment from `infra/main.bicep` with `infra/env/{dev,staging,prod}.bicepparam`.
  Modules: `app-service.bicep` (API), `static-web-app.bicep` (SPA), `sql.bicep` (Azure SQL + firewall),
  `storage.bicep` (blobs), `functions.bicep` (worker), `keyvault.bicep`, `monitoring.bicep`
  (App Insights + Log Analytics). Secrets live in Key Vault and reach the apps as Key Vault
  references in App Settings — never in `.bicepparam`, never in the repo.

## Development Commands

### Backend — run from the repo root

| Goal | Command |
|------|---------|
| Install dependencies | `dotnet restore` |
| Local API server | `dotnet watch run --project src/Api/FleetKeep.Api` |
| Build | `dotnet build -c Release` |
| Type-check (compiler is the type-check) | `dotnet build -warnaserror` |
| Lint / format check | `dotnet format --verify-no-changes` |
| Test | `dotnet test` |
| Add a migration | `dotnet ef migrations add <Name> --project src/Api/FleetKeep.Infrastructure` |
| Run migrations | `dotnet ef database update --project src/Api/FleetKeep.Infrastructure` |

### Frontend — run from `src/Web`

| Goal | Command |
|------|---------|
| Install dependencies | `npm ci` |
| Dev server | `npm run dev` → http://localhost:5173 |
| Production build | `npm run build` |
| Type-check | `npm run typecheck` (`tsc --noEmit`) |
| Lint | `npm run lint` (ESLint 9 flat config) |
| Unit / component tests | `npm run test` (Vitest + React Testing Library) |
| End-to-end tests | `npm run test:e2e` (Playwright, needs the API running) |

### Background Worker — run from the repo root

| Goal | Command |
|------|---------|
| Run locally | `func start --csharp` from `src/Worker/FleetKeep.Worker` |
| Test | `dotnet test src/Worker/FleetKeep.Worker.Tests` |

### DevOps — run from `infra`

| Goal | Command |
|------|---------|
| Lint the templates | `az bicep build --file main.bicep` |
| Preview a change | `az deployment group what-if -g rg-fleetkeep-dev -f main.bicep -p env/dev.bicepparam` |
| Deploy | `az deployment group create -g rg-fleetkeep-dev -f main.bicep -p env/dev.bicepparam` |

> Deploys run in GitHub Actions, not from a developer machine. `az deployment group create` against
> `rg-fleetkeep-prod` is guarded by `.claude/hooks/git-guard.sh`.

## Project Structure

```
FleetKeep/
├── src/Api/
│   ├── FleetKeep.Api/              # controllers, filters, DI composition root, Program.cs
│   ├── FleetKeep.Application/      # application services, DTOs, FluentValidation validators
│   ├── FleetKeep.Domain/           # entities, value objects, domain rules (no EF references)
│   └── FleetKeep.Infrastructure/   # DbContext, repositories, Migrations/, blob + email clients
├── src/Web/
│   ├── src/routes/                 # one module per route, lazy-loaded
│   ├── src/features/               # feature folders (vehicles, inspections, defects, jobcards)
│   ├── src/components/             # shared presentational components
│   ├── src/api/                    # generated OpenAPI client + TanStack Query hooks
│   └── src/theme/                  # Mantine theme object — the design-token source of truth
├── src/Worker/
│   └── FleetKeep.Worker/           # timer-triggered Azure Functions
├── infra/                          # main.bicep, modules/, env/*.bicepparam
└── .github/workflows/              # ci.yml, deploy-dev.yml, deploy-staging.yml, deploy-prod.yml
```

**Key files to know:**

| File | Why it matters |
|------|----------------|
| `src/Api/FleetKeep.Api/Program.cs` | Composition root — DI registrations, auth, middleware order |
| `src/Api/FleetKeep.Infrastructure/FleetKeepDbContext.cs` | Every entity, and the `TenantId` global query filter that enforces isolation |
| `src/Api/FleetKeep.Api/Filters/TenantContextFilter.cs` | Resolves `TenantId` from the JWT and populates `ITenantContext` |
| `src/Api/FleetKeep.Domain/Compliance/InspectionSchedule.cs` | The due-date engine — the heart of the product |
| `src/Web/src/theme/theme.ts` | Mantine theme object; the source for `.ai/standards/project/frontend/design/*` |
| `src/Web/src/api/client.ts` | Generated API client + the axios instance that attaches the MSAL token |
| `infra/main.bicep` | What actually exists in Azure, per environment |

## Conventions

- **Backend layering:** Controller → application service → repository → EF Core `DbContext`.
  > Controllers do HTTP only: model binding, `[Authorize]`, and mapping a result to `ApiResponse<T>`.
  > Application services hold the use case and own the transaction boundary. Repositories own
  > queries and return domain entities or projections — never `IQueryable` across a layer boundary.
  > `FleetKeep.Domain` references no EF Core types, so domain rules stay unit-testable.
- **Routing pattern:** attribute-routed controllers
  > `[ApiController]` + `[Route("api/v1/[controller]")]`, one controller per aggregate. Versioning is
  > in the path (`v1`); a breaking change means `v2`, never a silent change to `v1`.
- **Data access:** All persistence goes through the injected repository layer over `FleetKeepDbContext`.
  > One repository interface per aggregate root (`IVehicleRepository`), registered scoped. Reads that
  > cross aggregates use a projection in a query service, not a repository. No raw SQL except in a
  > migration; `FromSqlRaw` with string interpolation is forbidden outright.
- **Tenant isolation:** every query is scoped to the caller's tenant by the `TenantId` global query filter on `FleetKeepDbContext`
  > `IgnoreQueryFilters()` is banned outside `FleetKeep.Infrastructure.Admin` (the tenant-provisioning
  > path), and that folder is covered by a dedicated test. Every new entity carries `TenantId` and is
  > added to the filter in the same change.
- **Schema changes:** author the entity + configuration, then
  `dotnet ef migrations add <Name> --project src/Api/FleetKeep.Infrastructure` and
  `dotnet ef database update --project src/Api/FleetKeep.Infrastructure`. Never hand-edit a generated
  migration; regenerate it. Every migration must be backward-compatible with the currently deployed
  API for one release (expand → migrate → contract), because deploys are rolling.
- **Frontend data fetching:** one TanStack Query hook per endpoint in `src/Web/src/api/hooks/`,
  keyed `['vehicles', tenantId, filters]`. Components never call axios directly, and mutations
  invalidate by key rather than refetching manually.
- **Frontend validation:** Zod 3 at form boundaries.
  > The Zod schema is the single source of truth for a form: it types the payload and drives the
  > error messages. Client validation is UX only — the API re-validates everything with
  > FluentValidation and is the security boundary.
- **Environment variables:** API config comes from App Settings (Key Vault references in Azure,
  user-secrets locally) and binds to strongly-typed options classes. Client-exposed values must use
  the `VITE_` prefix (`VITE_API_BASE_URL`, `VITE_ENTRA_CLIENT_ID`) — anything without it is absent
  from the browser bundle. Never put a secret behind `VITE_`; it ships to the client.
- **Branding / theming:** single brand. Light and dark both ship, driven by Mantine's
  `ColorSchemeScript`; there is no per-tenant white-labelling.

**Never do in this project:**

> - Never bypass the application-service layer by putting logic in a controller.
> - Never call `IgnoreQueryFilters()` outside `FleetKeep.Infrastructure.Admin` — it silently
>   crosses the tenant boundary.
> - Never hand-edit a generated EF migration; regenerate it instead.
> - Never write a migration that is not backward-compatible for one release (rolling deploys).
> - Never log PII (driver names, licence numbers, vehicle registrations) — log the entity id.
> - Never commit a secret; Key Vault + App Settings only. A committed secret must be rotated, not
>   just deleted.
> - Never add a `VITE_`-prefixed variable that holds anything sensitive.
> - Never deploy to `rg-fleetkeep-prod` from a developer machine — production deploys run only
>   from the `deploy-prod` workflow on `main`.

## Test environments

Read by runtime verification (`.ai/workflows/runtime-verification.md`) — the API, UI and DB checks
run after review and the security scan. **Never list a production URL here**; production is
hard-blocked by `E2E_FORBIDDEN_HOSTS` in `.claude/hooks/hooks.env`.

- **API base URL:** local `https://localhost:7241` (default); dev
  `https://api-fleetkeep-dev.azurewebsites.net` when a change needs Entra or Blob behaviour the
  local run fakes.
- **UI URL:** local `http://localhost:5173`, pointed at the local API.
- **Start / health:** API `dotnet watch run --project src/Api/FleetKeep.Api`, health
  `GET /health` → 200; SPA `npm run dev` in `src/Web`.
- **API test auth:** token command, run inline per request after `az login` as an E2E test user in
  the **dev** Entra tenant:
  `$(az account get-access-token --scope api://fleetkeep-api-dev/.default --query accessToken -o tsv)`.
  For the cross-tenant checks, export `FLEETKEEP_E2E_TOKEN_OTHER` (a token for a user in the other
  test tenant) **before** starting Claude Code. Tokens are never written down.
- **Test accounts:** two dev tenants, *Northwind Test Haulage* and *Contoso Test Coaches*, each with a
  transport manager, a technician and a driver — listed (without passwords) in the team vault entry
  *FleetKeep E2E accounts*. Cross-tenant checks sign in as one and request the other's records.
- **UI driver:** `chrome` — Claude in Chrome, so a developer can watch the journey in their own
  browser; Playwright MCP is the fallback.
- **E2E test command:** `npm run test:e2e` in `src/Web` (Playwright, needs the API running).
- **DB check:** none configured — FleetKeep's integration tests cover persistence against a
  Testcontainers SQL Server, and runtime checks confirm writes with a follow-up API `GET`. To enable
  DB checks, add a read-only SQL Server MCP server pointed at the local container (axis 14 of
  `.ai/CUSTOMIZATION.md`).
- **Seed / reset:** no seed script — each run creates the data it needs through the API under a
  test tenant and records the ids. Most of it cannot be removed (vehicle deletes are soft, audit rows
  are append-only), so list what was created in the report. Never reset a shared dev database.

## Release deliverables

Read by the release agent (`.ai/agents/release-agent.md`). Every feature, bugfix and hotfix writes
`.ai/features/<slug>/deploy-notes.md` regardless; these settings decide what the release path builds
from them beyond the internal artifacts in `.ai/releases/<version>/`.

- **Deployment guide:** `on` — Northwind's platform-operations rota runs production deploys and
  approves the `deploy-prod` environment gate, so each release gets a guide under
  `docs/release/<version>/`.
- **Guide audience:** Northwind platform operations (on-call). They work in the Azure Portal and
  the GitHub Actions web UI; command lines go in the last appendix only.
- **Word copy:** `off` — the guide is read in the repo; nobody outside Northwind receives it.
- **Deployable units:** in deploy order — database (EF Core migrations, applied by the deploy
  workflow) → API (`app-fleetkeep-<env>`, App Service) → worker (`func-fleetkeep-<env>`, Function
  App) → SPA (`swa-fleetkeep-<env>`, Static Web App). Bicep infrastructure changes run first, from
  the same workflow, when `infra/` changed.
- **Environments & rollout order:** dev → staging → production, one Azure deployment per
  environment. Tenants share one deployment, so there is no per-tenant rollout.

## Architecture Notes

> - Three deployables from one repo: the API (App Service), the SPA (Static Web App), and the
>   worker (Function App). They share `FleetKeep.Domain` and `FleetKeep.Infrastructure`, so a
>   change to an entity affects all three — check the worker when you touch the schema.
> - Multi-tenancy is **shared-database, shared-schema**: one Azure SQL database, a `TenantId`
>   column on every tenant-owned table, enforced by a global query filter. Isolation is a code
>   invariant, not an infrastructure boundary — which is why the security scanner treats it as a
>   CRITICAL-severity check.
> - The compliance due-date engine is pure domain code with no I/O, so it is fully unit-tested;
>   the worker only schedules it and persists the results.
> - Notifications are fire-and-forget through Azure Communication Services email; a failed send is
>   retried by the next worker pass rather than blocking a request.
> - Deploys are rolling with no downtime window, which is why the expand → migrate → contract rule
>   on migrations is non-negotiable.
>
> Full write-up: `.ai/context/architecture.md`. Domain rules: `.ai/context/business-rules.md`.
