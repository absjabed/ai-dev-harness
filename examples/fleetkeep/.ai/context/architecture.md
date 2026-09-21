# Architecture

> Technical architecture of FleetKeep. Read before designing changes.

## High-level shape

This is a monorepo with the following scopes: backend and frontend.

```
┌──────────────────────┐                    ┌──────────────────────────┐
│  React 18 + Vite 5   │  HTTPS / REST JSON │  ASP.NET Core 8 Web API  │
│  SPA (Static Web App)│───────────────────▶│  (App Service, Linux)    │
│  MSAL bearer token   │                    └────────────┬─────────────┘
└──────────────────────┘                                 │
          ▲                                              │ EF Core 8
          │ OIDC + PKCE                                  ▼
┌─────────┴────────────┐                    ┌──────────────────────────┐
│  Microsoft Entra ID  │                    │  Azure SQL Database      │
└──────────────────────┘                    │  (single shared DB,      │
                                            │   TenantId filtered)     │
┌──────────────────────┐                    └────────────┬─────────────┘
│  Azure Functions     │  shares Domain +                │
│  worker (timers)     │  Infrastructure ────────────────┘
└──────────┬───────────┘
           │ email
           ▼
  Azure Communication Services        Azure Blob Storage (defect photos, inspection PDFs)
```

Three deployables, one codebase. The API is the only writer of business data; the SPA holds no
business logic beyond presentation; the worker reuses the API's domain and infrastructure
assemblies rather than duplicating rules.

## Backend architecture

### Request flow

```
Azure Front Door / App Service
   ▼
JWT bearer authentication          ← Entra ID token validated (issuer, audience, signature)
   ▼
TenantContextFilter                ← resolves TenantId from the `tid` claim into ITenantContext
   ▼
attribute-routed controller        ← [ApiController], [Route("api/v1/[controller]")], [Authorize(policy)]
   ▼
FluentValidation request validator ← 400 with ApiResponse.error before any work happens
   ▼
application service                ← the use case; owns the transaction boundary
   ▼
repository over FleetKeepDbContext ← EF Core 8 / Azure SQL, TenantId filter always applied
```

Invariants:

- A controller never touches `FleetKeepDbContext` and never opens a transaction.
- An application service never returns an EF entity to the controller — it returns a DTO.
- `FleetKeep.Domain` references no EF Core, ASP.NET or Azure types, so domain rules are testable
  without a database.
- Nothing bypasses `TenantContextFilter`: an endpoint that legitimately needs cross-tenant access
  lives in the admin surface and is explicit about it.

### Code organization

- `src/Api/FleetKeep.Api/Controllers/` — one controller per aggregate root; HTTP concerns only.
- `src/Api/FleetKeep.Api/Filters/` — `TenantContextFilter`, `ApiResponseFilter`, exception mapping.
- `src/Api/FleetKeep.Api/Program.cs` — DI composition root; the authoritative middleware order.
- `src/Api/FleetKeep.Application/<Aggregate>/` — application services, DTOs, FluentValidation validators.
- `src/Api/FleetKeep.Domain/` — entities, value objects and pure rules (`Compliance/`, `Defects/`,
  `JobCards/`, `Parts/`).
- `src/Api/FleetKeep.Infrastructure/` — `FleetKeepDbContext`, entity configurations, repositories,
  `Migrations/`, blob and email clients, and `Admin/` (the only place the tenant filter may be bypassed).
- `src/Api/FleetKeep.Api.Tests/` — xUnit; unit tests for domain and services, Testcontainers-backed
  integration tests for repositories and the tenant filter.

### API modules

| Module | Domain |
|--------|--------|
| `Vehicles` | Vehicle register, depot assignment, VOR status, soft delete |
| `Inspections` | Frequencies, anchors, due-date computation, re-anchoring, completion |
| `Checks` | Driver walkaround checks (immutable once submitted) |
| `Defects` | Defect capture, categories A/B/C, triage and the defect state machine |
| `JobCards` | Workshop queue, labour and parts recording, return to service |
| `Parts` | Depot stock levels, consumption, reorder thresholds |
| `Compliance` | Dashboard projections and RAG banding (read-only) |
| `Exports` | Audit packs — PDF + CSV generation into Blob Storage |
| `Tenancy` | Users, roles, depots, tenant settings |
| `Meta` | `/health`, `/version` — the only unauthenticated endpoints |

### Data stores

- **Azure SQL Database (via EF Core 8)** — all business data: vehicles, depots, inspections,
  checks, defects, job cards, parts, users/roles and the append-only audit table. Single shared
  database; tenant rows are separated by the `TenantId` global query filter, not by schema.
- **Azure Blob Storage (defect photos and signed inspection PDFs)** — binary artifacts only, keyed
  `{tenantId}/defects/{defectId}/{blobId}`, served via short-lived user-delegation SAS URLs. No
  public containers.
- **No cache tier.** The compliance dashboard is a single indexed projection query; if it ever
  needs caching, that is a deliberate future change, not an ambient assumption.
- Every query is scoped to the caller's tenant by the `TenantId` global query filter on
  `FleetKeepDbContext`.

### Auth flow

1. The SPA redirects to Microsoft Entra ID (authorization code + PKCE) via `@azure/msal-react`.
2. Entra ID returns an ID token and an access token scoped to the API's app registration.
3. Every API call carries `Authorization: Bearer <access token>`, attached by an axios interceptor
   that calls `acquireTokenSilent`.
4. The API validates issuer, audience and signature against Entra ID's JWKS (cached).
5. `TenantContextFilter` reads `tid` (tenant) and `oid` (user) into the scoped `ITenantContext`.
   A missing or unmapped tenant is a 401 — there is no default tenant.
6. Policy-based `[Authorize]` checks the user's FleetKeep roles, which are stored per tenant in the
   database and loaded per request (not carried in the token).
7. `FleetKeepDbContext` applies the `TenantId` filter from `ITenantContext` to every query, and
   stamps it on every insert.

### Async processing

- `src/Worker/FleetKeep.Worker` runs two timer triggers: `InspectionDueScan` (02:00 UTC daily) and
  `DefectEscalation` (hourly).
- The worker constructs a tenant context per tenant it processes and reuses the same repositories,
  so the same isolation rules apply — there is no privileged "scan everything" query path.
- Notifications are fire-and-forget email through Azure Communication Services. A failed send is
  not retried inline; the next pass picks it up, because the scan is idempotent.
- There is no queue and no orchestration framework. If a workload ever needs one, that is an ADR,
  not an incremental addition.

## Frontend architecture

### Code organization

- `src/Web/src/main.tsx` — entry point: MSAL provider, `MantineProvider`, `QueryClientProvider`, router.
- `src/Web/src/routes/` — one lazy-loaded module per route; the router is declared here.
- `src/Web/src/features/<feature>/` — feature-owned pages, components, hooks and tests.
- `src/Web/src/components/` — shared presentational components; no data fetching.
- `src/Web/src/hooks/` — cross-feature hooks (`useTenant`, `usePermissions`, `useDebouncedFilter`).
- `src/Web/src/api/` — generated OpenAPI client, the axios instance with the MSAL interceptor, and
  one TanStack Query hook per endpoint.
- `src/Web/src/theme/` — the Mantine theme object; the source of truth for the design docs.
- `src/Web/src/test/` — Vitest setup, MSW handlers, render helpers.

### Data flow

1. A route module renders a feature page.
2. The page calls a TanStack Query hook from `src/api/hooks/` — never axios directly.
3. The hook calls the generated client; the axios interceptor attaches the MSAL bearer token.
4. The API responds with `ApiResponse<T>`; the client unwraps `data` or throws a typed `ApiError`.
5. Query keys are `['resource', tenantId, ...params]`, so switching tenant (support scenario)
   cannot serve another tenant's cached rows.
6. Mutations invalidate by key; the compliance dashboard additionally polls on a 60s
   `refetchInterval` — there is no websocket.

## AI architecture

Not applicable — FleetKeep ships no AI/ML services. `src/Worker` is a plain .NET 8 isolated Azure
Functions app.

## Infrastructure

Provisioned with Bicep from `infra/main.bicep`, one resource group per environment, deployed by
GitHub Actions. Environments: dev → staging → production, all in `uksouth`.

| Module | Resources |
|--------|-----------|
| `app-service.bicep` | Linux App Service plan + web app for the API, managed identity, App Settings |
| `static-web-app.bicep` | Static Web App for the SPA, custom domain, route config |
| `functions.bicep` | Function App (isolated .NET 8) for the worker, managed identity |
| `sql.bicep` | Azure SQL server + database, firewall rules, Entra-only admin |
| `storage.bicep` | Storage account + private blob containers |
| `keyvault.bicep` | Key Vault, access via managed identity, no access policies for humans in prod |
| `monitoring.bicep` | Application Insights + Log Analytics workspace, alert rules |

All three apps authenticate to SQL, Blob and Key Vault with **managed identity** — there are no
connection-string secrets for those resources.

### Secrets and config

- Secrets live in Key Vault and reach the apps as Key Vault references in App Settings; the apps
  read them as ordinary configuration and bind to typed options classes.
- Local development uses `dotnet user-secrets` for the API and `.env.local` (gitignored) for the SPA.
- `.bicepparam` files hold no secrets — only resource names, SKUs and non-sensitive settings.
- **No secrets in source, in `VITE_` variables, or in logs.** A committed secret must be rotated,
  not merely deleted.

## Notable gaps / future work

- **No load testing.** The compliance dashboard query is indexed but unproven beyond ~2,000
  vehicles per tenant.
- **Audit export is synchronous** and times out on very large date ranges; it should move to the
  worker with a download link.
- **No rate limiting** on the API; currently mitigated only by Entra ID authentication.
- **Worker has no dead-letter path** — a tenant that throws mid-scan is logged and skipped until
  the next run.
- **Playwright coverage is thin** — happy paths only for the dashboard and the defect journey.
- **No blue/green or slot swap.** Deploys are rolling, which is exactly why the expand → migrate →
  contract migration rule exists; a slot-based deploy would relax it.
- **Driver offline mode** is unsolved; depot connectivity is known to be poor.
