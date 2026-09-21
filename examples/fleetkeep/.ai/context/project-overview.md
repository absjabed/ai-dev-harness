# Project Overview

> Read this first to understand *what* this system is and *who* it serves, before touching code.

## What this system does

**FleetKeep** — a multi-tenant compliance and maintenance platform for commercial vehicle fleets.

Operators of HGVs, coaches and vans are legally required to inspect each vehicle on a fixed
interval, record every driver walkaround check, and act on reported defects within defined
timescales. Missing one of those deadlines risks the operator's licence. FleetKeep is the system of
record for that obligation: it holds the fleet, computes what is due and when, captures defects from
the depot floor, turns them into workshop job cards, and escalates anything that slips.

- **Never miss a statutory date** — inspection, MOT and tachograph calibration due dates are
  computed per vehicle and surfaced on a red/amber/green compliance dashboard.
- **Close the defect loop** — a driver reports a defect, it becomes a job card, a technician
  completes it, and the vehicle's roadworthy status updates automatically.
- **Prove it later** — every state change is audited, so an operator can reconstruct the full
  history of a vehicle for a DVSA audit.
- **Keep the workshop stocked** — parts consumed by job cards decrement stock and raise reorder
  alerts before a repair is blocked.

This repository is a monorepo. Its scopes are: backend and frontend.

- `src/Api` — the ASP.NET Core API and all domain logic; the only writer to the database.
- `src/Web` — the React SPA used by every persona; talks only to the API.
- `src/Worker` — timer-triggered Azure Functions for nightly due-date scans and defect escalation.
- `infra` — Bicep templates defining every Azure resource, per environment.

## Who uses it

- **Transport manager** — accountable for the operator's licence. Lives on the compliance
  dashboard, schedules inspections, signs off returns to service.
- **Workshop technician** — works the job-card queue, records work done and parts used, marks a
  vehicle roadworthy.
- **Driver** — submits the daily walkaround check and reports defects from a phone.
- **Compliance officer** — runs audit exports and reviews overdue/escalated items across depots.
- **Depot administrator** — maintains the vehicle register, depots and driver assignments.
- **Tenant admin** — manages users and roles inside their own operator organisation.
- **Vendor support** — cross-tenant read access for support cases, via a separate admin surface.

FleetKeep is multi-tenant: one operator = one tenant. Isolation is shared-database, shared-schema —
every query is scoped to the caller's tenant by the `TenantId` global query filter on
`FleetKeepDbContext`, resolved from the `tid` claim on the validated JWT.

## Core user journeys

1. Transport manager opens the compliance dashboard → sees every vehicle banded red/amber/green by
   its nearest due date, filtered to their depot.
2. Driver submits a walkaround check with a defect and a photo → the vehicle's status updates and
   the workshop queue gains an item.
3. Workshop technician picks up a job card → records labour, parts and outcome → the vehicle
   returns to service and its roadworthy flag flips back.
4. System scans nightly for due and overdue inspections → notifies the transport manager and
   escalates category-A defects left unactioned.
5. Depot administrator adds a vehicle → chooses its inspection frequency → the first due date is
   computed and the vehicle joins the dashboard.
6. Transport manager reschedules an inspection → the system recomputes the following dates from the
   new anchor and records who changed it and why.
7. Compliance officer exports a date-ranged audit pack for a vehicle or depot → receives a PDF plus
   CSV of every check, defect and job card.
8. Tenant admin invites a user and assigns a role → the user signs in with Entra ID and sees only
   their tenant's data.

## Most important modules

- `src/Api/FleetKeep.Domain/Compliance/InspectionSchedule.cs` — the due-date engine; pure logic, no I/O.
- `src/Api/FleetKeep.Domain/Defects/Defect.cs` — the defect state machine and its category rules.
- `src/Api/FleetKeep.Infrastructure/FleetKeepDbContext.cs` — every entity plus the `TenantId` global query filter.
- `src/Api/FleetKeep.Api/Filters/TenantContextFilter.cs` — resolves the tenant from the JWT; the isolation entry point.
- `src/Api/FleetKeep.Application/JobCards/JobCardService.cs` — the defect → job card → return-to-service transaction.
- `src/Api/FleetKeep.Api/Program.cs` — DI composition root, auth and middleware order.
- `src/Worker/FleetKeep.Worker/InspectionDueScan.cs` — the nightly scan that drives notifications.
- `src/Web/src/features/compliance/ComplianceDashboard.tsx` — the highest-traffic screen in the product.
- `src/Web/src/api/client.ts` — the axios instance and MSAL token interceptor every request passes through.
- `src/Web/src/theme/theme.ts` — the Mantine theme; the source of truth for every design token.

## What "done" looks like for a change here

- The change respects scope boundaries and existing patterns (Controller → application service →
  repository → EF Core `DbContext`, attribute-routed controllers, the injected repository layer
  over `FleetKeepDbContext`).
- Security invariants are preserved: auth enforced via OIDC authorization-code + PKCE in the SPA
  (MSAL) with JWT bearer validated by the API, and isolation via the `TenantId` global query filter.
  A new tenant-owned entity carries `TenantId` and is added to the filter in the same change.
- Schema/data changes go through `dotnet ef migrations add`, are backward-compatible for one
  release (expand → migrate → contract), and are never hand-edited.
- Tests are written for the change: xUnit for API and domain, Vitest + React Testing Library for
  web. `dotnet test`, `npm run test`, `npm run lint` and `npm run typecheck` all pass.
- The changed flow is manually verified against the dev environment for anything user-facing.
- No PII appears in logs, and no secret appears in the diff.
