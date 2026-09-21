# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

FleetKeep is a multi-tenant compliance and maintenance platform for commercial vehicle fleets.

It is the system of record operators rely on to keep their licence: statutory inspection and MOT due
dates, driver walkaround checks, defect reports, workshop job cards and parts stock. Its users are
transport managers, workshop technicians, drivers, compliance officers and depot admins at haulage
and coach operators.

The repository is a monorepo with the following sub-projects:

- `src/Api/` — ASP.NET Core 8 Web API (C# 12, .NET 8). Owns every business rule and is the only
  writer to the database. Projects: `FleetKeep.Api`, `.Application`, `.Domain`, `.Infrastructure`.
- `src/Web/` — React 18 + Vite 5 SPA (TypeScript 5.5, Mantine v7). Every persona's interface.
- `src/Worker/` — .NET 8 isolated Azure Functions: nightly inspection-due scan, hourly defect
  escalation. Shares `.Application` / `.Infrastructure` with the API.
- `infra/` — Bicep templates for every Azure resource, one resource group per environment.

## Commands

### Backend (`src/Api`)

```bash
dotnet restore                                                        # Install dependencies
dotnet watch run --project src/Api/FleetKeep.Api                      # Local dev server → https://localhost:7241
dotnet build -c Release                                               # Build
dotnet build -warnaserror                                             # Type-check (the compiler is the type-check)
dotnet format --verify-no-changes                                     # Lint / format check
dotnet test                                                           # Test (xUnit + FluentAssertions + Testcontainers)
dotnet ef database update --project src/Api/FleetKeep.Infrastructure  # Run DB migrations
```

### Frontend (`src/Web`)

```bash
npm ci             # Install dependencies
npm run dev        # Dev server → http://localhost:5173
npm run build      # Production build
npm run typecheck  # tsc --noEmit
npm run lint       # ESLint 9
npm run test       # Vitest + React Testing Library
npm run test:e2e   # Playwright (API must be running)
```

### Worker (`src/Worker`)

```bash
func start --csharp                              # Run the Functions host locally (from src/Worker/FleetKeep.Worker)
dotnet test src/Worker/FleetKeep.Worker.Tests    # Test
```

### Infrastructure (`infra`)

```bash
az bicep build --file main.bicep                                                          # Lint
az deployment group what-if -g rg-fleetkeep-dev -f main.bicep -p env/dev.bicepparam       # Preview
az deployment group create  -g rg-fleetkeep-dev -f main.bicep -p env/dev.bicepparam       # Deploy (CI does this)
```

## Architecture

### Backend

A layered ASP.NET Core API. `Program.cs` is the single composition root, and its middleware order is
load-bearing: exception handler → auth → `TenantContextFilter` → endpoints.

**Attribute-routed controllers**: `[ApiController]` + `[Route("api/v1/[controller]")]`, one
controller per aggregate root. No minimal APIs, no central route table. Versioning is in the path.

```
src/Api/
├── FleetKeep.Api/              # controllers, filters, middleware, Program.cs
├── FleetKeep.Application/      # application services, DTOs, FluentValidation validators
├── FleetKeep.Domain/           # entities, value objects, pure rules — no EF Core reference
└── FleetKeep.Infrastructure/   # DbContext, repositories, Migrations/, blob + email clients
```

Business logic lives in the service layer. Data access goes through the injected repository layer
over `FleetKeepDbContext`:

- EF Core 8 for Azure SQL Database (schema and `src/Api/FleetKeep.Infrastructure/Migrations`)
- Azure Blob Storage via `IBlobStore` for defect photos and signed inspection PDFs — tenant-prefixed
  paths, short-lived user-delegation SAS, managed identity, no public containers

### Frontend

Feature-first: `src/Web/src/features/<feature>/` owns its pages, components, hooks and tests;
`src/routes/` holds one lazy-loaded module per URL.

Shared state uses TanStack Query v5 for all server state, with a single `TenantContext` for the
session/tenant object — there is no Redux. API calls live in one client layer (`src/api/`) and
imports use the `@` path alias to `src/Web/src`.

Single brand; light and dark both ship via Mantine's `ColorSchemeScript`. No per-tenant
white-labelling.

### Worker

Two timer triggers. The function body builds a tenant context and calls the same application
services the API uses — it never duplicates a domain rule and never calls the API over HTTP. Every
pass is idempotent; a tenant that throws is logged and skipped.

### Authentication Flow

1. User authenticates via Microsoft Entra ID (authorization code + PKCE, `@azure/msal-react`)
2. A token is attached to all API requests (OIDC authorization-code + PKCE in the SPA (MSAL), JWT
   bearer validated by the API) by a single axios interceptor
3. The backend validates issuer, audience and signature against the Entra JWKS
4. Authorization is enforced per handler with policy-based `[Authorize]`; FleetKeep roles are loaded
   per request from the database, not read from token claims

Multi-tenancy is **shared-database, shared-schema**: one operator = one tenant, and every query is
scoped to the caller's tenant by the `TenantId` global query filter on `FleetKeepDbContext`, seeded
from the `tid` claim. `IgnoreQueryFilters()` is banned outside `FleetKeep.Infrastructure.Admin`.
Isolation is a code invariant, so breaking it is a CRITICAL security bug.

### Infrastructure (Bicep)

`infra/main.bicep` plus modules: `app-service` (API), `static-web-app` (SPA), `functions` (worker),
`sql`, `storage`, `keyvault`, `monitoring`. One resource group per environment
(dev → staging → production), all `uksouth`. All three apps reach SQL, Blob and Key Vault with
managed identity.

## Environment Variables

**Backend** (App Settings; `dotnet user-secrets` locally):
```
# ConnectionStrings__Sql            — Azure SQL, managed identity (no password)
# Storage__AccountUri               — blob account URI
# Entra__TenantId / Entra__Audience — token validation
# Acs__ConnectionString             — Key Vault reference (notification email)
# ApplicationInsights__ConnectionString
# Never commit secret values — Key Vault references only.
```

**Frontend** (see `src/Web/.env.example`):
```
VITE_API_BASE_URL=https://api-fleetkeep-dev.azurewebsites.net
VITE_ENTRA_CLIENT_ID=<spa app registration client id>
VITE_ENTRA_TENANT_ID=<entra directory id>
VITE_APP_ENV=dev
# Only VITE_-prefixed vars reach the browser. Never put a secret behind VITE_.
```

## Non-negotiables

- Never bypass the application-service layer, or call `IgnoreQueryFilters()` outside
  `FleetKeep.Infrastructure.Admin`.
- Never hand-edit a generated EF migration, and never ship one that is not backward-compatible for
  one release — deploys are rolling (expand → migrate → contract).
- Never log PII (driver names, licence numbers, registrations); log the entity id.
- Never read `tenantId` or `userId` from a request body — only from the validated token.
- Never hardcode a hex or px value in the SPA; use Mantine theme tokens.
- Never deploy to `rg-fleetkeep-prod` from a developer machine.

## Agent System

This repo ships a full Claude Code agent system. See [`README.md`](README.md) for an overview and
[`CUSTOMIZATION.md`](.ai/CUSTOMIZATION.md) for how to tailor it to this project. The `.ai/` directory
contains the knowledge base: architecture context, agent role definitions, workflow playbooks, and
output templates. The `.claude/` directory contains slash commands, sub-agent definitions, and hooks.

Invoke agents via slash commands — `/ba`, `/qa`, `/agents:architect`, `/agents:dev`,
`/agents:review`, `/agents:security`, `/workflows:feature`, `/workflows:bugfix`,
`/workflows:release`, etc.
