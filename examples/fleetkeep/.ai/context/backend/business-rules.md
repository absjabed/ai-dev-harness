# Backend Business Rules

## Authentication & Authorization

- Every endpoint requires a valid Entra ID bearer token except `GET /health` and
  `GET /api/v1/meta/version`.
- Trusted caller context comes **only** from the validated token: `tid` (tenant) and `oid` (user).
  Tenant, user identity and depot must never be read from the request body, route or query string —
  a request that supplies `tenantId` in its payload is a bug, and the property should not exist on
  the DTO.
- FleetKeep roles are loaded per request from the database for that tenant+user, not taken from
  token claims, so revoking a role takes effect immediately.
- RBAC gates (policy names in `Policies`):
  - `CanReportDefect` — Driver, Technician, TransportManager, DepotAdmin
  - `CanProgressJobCard` — Technician, TransportManager
  - `CanAuthoriseReturnToService` — TransportManager only
  - `CanRescheduleInspection` — TransportManager only
  - `CanExportAudit` — ComplianceOfficer, TransportManager
  - `CanManageVehicles` — DepotAdmin
  - `CanManageUsers` — TenantAdmin
- Depot scoping applies inside the tenant: a user sees only their assigned depots unless they hold
  `ComplianceOfficer` (tenant-wide read).

## Multi-Tenancy

Every query is scoped to the caller's tenant by the `TenantId` global query filter on
`FleetKeepDbContext`.

- Every tenant-owned entity has a non-nullable `TenantId`; `SaveChangesAsync` stamps it from
  `ITenantContext` so a client-supplied value cannot cross tenants.
- Blob paths are tenant-prefixed and served via short-lived user-delegation SAS URLs.
- `IgnoreQueryFilters()` is allowed only inside `FleetKeep.Infrastructure.Admin`; a test asserts no
  other namespace references it.
- A data access that escapes tenant scoping is a **BLOCKER-severity security bug** — it ships
  nothing, and any existing instance is treated as an incident, not a backlog item.

## Domain Rules

### Inspection scheduling

- Due dates are computed forward from the vehicle's anchor date and frequency (4/6/8/10/13 weeks),
  never from the completion date, so a late inspection does not slide the whole schedule.
- Completing early does not move the next due date; re-anchoring is explicit, requires
  `CanRescheduleInspection`, and demands a reason that is audited.
- Banding is derived, never persisted: green > 14 days, amber ≤ 14 days, red past due. One
  implementation (`ComplianceBanding`) serves the API, the worker and the exports.
- A VOR vehicle keeps accruing due dates but is excluded from red-band alerting, and cannot return
  to service while an inspection is overdue.

### Walkaround checks

- A submitted check is immutable. Corrections are new checks; both remain in the audit trail.
- A check must reference a vehicle in the driver's own tenant and assigned depot; anything else is
  403, not 404-by-filter.

### Defects

- Categories: **A** immobilising, **B** repair within 48 hours, **C** monitor.
- Reporting a category-A defect sets the vehicle VOR in the same transaction as the defect insert.
- State machine: `Reported → Triaged → JobCardRaised → InProgress → Resolved → Closed`, with
  `Triaged → Rejected` (reason required). No state may be skipped; `Closed` and `Rejected` are
  terminal. An illegal transition is a 409, not a silent no-op.
- Escalation is time-based and handled by the worker: category-A after 4 hours unactioned,
  category-B after 36.

### Job cards

- A job card covers one vehicle and one depot, and may bundle several defects.
- Closure requires labour time, every linked defect resolved or deferred with a reason, and the
  technician's authenticated user id as signature.
- Closure is one transaction: resolve defects → decrement parts → close card → recompute vehicle
  roadworthiness. A failure anywhere rolls back all of it.
- Return to service requires `CanAuthoriseReturnToService` **and** zero open category-A defects.

### Parts

- Stock decrements at closure, not allocation. Stock may not go negative — closure fails with a
  validation error naming the part.
- Falling below the reorder threshold raises an alert on the next worker pass; alerts are
  idempotent per part per day.

### Audit

- Every create/update/delete of a vehicle, check, defect or job card writes an append-only audit
  row: who, when, what changed, and why where a reason is mandatory.
- Nothing in the application may update or delete an audit row.
- Vehicles are soft-deleted; compliance history is retained for at least 15 months.

## API Contracts

**Success response**:
```json
{ "data": { "id": "…", "registration": "AB12 CDE" }, "error": null, "traceId": "00-…" }
```

**Error response**:
```json
{ "data": null, "error": { "message": "Vehicle is off-road with an open category-A defect.",
  "code": "VEHICLE_VOR_BLOCKED", "details": [] }, "traceId": "00-…" }
```

**Pagination** — every list endpoint is paged; there are no unbounded lists:
`GET /api/v1/vehicles?page=1&pageSize=50` (max `pageSize` 200), returning
`{ "data": { "items": [], "page": 1, "pageSize": 50, "totalCount": 412 } }`.

**HTTP status codes**: `200` read/update, `201` create (with `Location`), `204` delete,
`400` validation failure, `401` missing/invalid token or unresolvable tenant, `403` authenticated
but not permitted, `404` not found within the caller's tenant, `409` illegal state transition or
concurrency conflict, `422` domain rule rejection that is not a field-level validation error,
`500` unhandled — never leaks an exception message to the client.

## Rules Still To Be Defined

- Rate limiting and per-tenant quotas (vehicles, users, blob volume) — none enforced.
- Concurrency strategy on job cards: optimistic `rowversion` exists on `Vehicle` only; two
  technicians editing one card is currently last-write-wins.
- Retention beyond 15 months — archive to cool storage, or keep indefinitely.
- Whether tenants may define inspection frequencies outside the five presets.
- Bulk vehicle import format and partial-failure reporting.
- Whether audit exports move to the worker with a download link (currently synchronous and
  times out on large ranges).
