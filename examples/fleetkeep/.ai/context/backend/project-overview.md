# Backend Project Overview

## What It Does

The FleetKeep backend is the system of record for fleet compliance. It owns every business rule —
when an inspection is due, whether a vehicle may be driven, what a defect may transition to — and
is the only component that writes to the database. Its consumers are the React 18 + Vite 5 SPA and
the Azure Functions worker, which reuses its domain and infrastructure assemblies rather than
calling over HTTP. The backend is written in C# 12 using ASP.NET Core 8 Web API and lives in
`src/Api`.

## API Domains

| Domain | Purpose |
|--------|---------|
| `Vehicles` | Vehicle register, depot assignment, VOR status, soft delete |
| `Inspections` | Frequencies, anchor dates, due-date computation, re-anchoring, completion |
| `Checks` | Driver walkaround checks — immutable once submitted |
| `Defects` | Defect capture, A/B/C categorisation, triage, the defect state machine |
| `JobCards` | Workshop queue, labour and parts recording, return to service |
| `Parts` | Depot stock levels, consumption at job-card closure, reorder thresholds |
| `Compliance` | Read-only dashboard projections and RAG banding |
| `Exports` | Audit packs — PDF + CSV written to Blob Storage |
| `Tenancy` | Users, roles, depots, tenant settings |
| `Meta` | `/health` and `/version` — the only unauthenticated endpoints |

## Infrastructure

- **Compute**: Azure App Service (Linux, P1v3) running the ASP.NET Core process; rolling deploys,
  no slot swap.
- **API layer**: Kestrel behind App Service; attribute-routed controllers under `api/v1/`.
- **Databases**: Azure SQL Database (via EF Core 8) — one shared database, `TenantId`-filtered.
- **Storage**: Azure Blob Storage for defect photos and signed inspection PDFs, accessed with
  managed identity and served via short-lived user-delegation SAS URLs.
- **Auth**: Microsoft Entra ID — JWT bearer validated against the Entra JWKS.
- **Async**: two timer-triggered Azure Functions in `src/Worker` (nightly due-date scan, hourly
  defect escalation). No queue, no orchestrator.
- **Email**: Azure Communication Services, fire-and-forget from the worker.
- **AI**: not applicable — FleetKeep ships no AI/ML services.
- **Real-time**: none — the dashboard polls every 60 seconds.
- **Observability**: Serilog → Application Insights; Log Analytics workspace per environment.

## Multi-tenant Model

One operator organisation = one tenant, sharing a single database and schema.

- Each tenant gets: rows tagged with its `TenantId`, a blob prefix (`{tenantId}/…`), its own users
  and roles, and its own depots. It does **not** get separate infrastructure, a separate database,
  or a separate app registration.
- The caller's tenant is resolved from the JWT `tid` claim into `ITenantContext`, and
  `FleetKeepDbContext` applies the `TenantId` global query filter to every read while stamping it
  on every insert.
- Because isolation is a code invariant rather than an infrastructure boundary, a query that
  escapes the filter is a BLOCKER-severity security bug, not a cosmetic issue.
