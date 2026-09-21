# Business Rules

> Domain rules that govern this system. Capture rules that are enforced in code *and* rules that
> currently live in people's heads. Treat security/isolation rules as authoritative and testable.

## Multi-tenancy

One operator organisation = one tenant. Isolation is **shared-database, shared-schema**.

- The caller's tenant comes from the `tid` claim on the validated JWT, read by
  `TenantContextFilter` into the scoped `ITenantContext` before any action runs. A request with no
  resolvable tenant is rejected with 401 — never defaulted.
- Every tenant-owned entity carries a non-nullable `TenantId`, and `FleetKeepDbContext` applies a
  global query filter on it. Inserts stamp `TenantId` from `ITenantContext` in `SaveChangesAsync`,
  so a caller cannot write into another tenant by supplying an id.
- `IgnoreQueryFilters()` is permitted **only** inside `FleetKeep.Infrastructure.Admin` (tenant
  provisioning and vendor support read access). A test asserts that no other namespace references it.
- Blob paths are tenant-prefixed (`{tenantId}/defects/{defectId}/{blobId}`) and served through
  short-lived user-delegation SAS URLs, never public containers.
- Reference data (defect categories, inspection frequency presets) is global and has no `TenantId`.
  It is read-only at runtime; changes ship as migrations.

## Authentication & authorization

- Authentication is Microsoft Entra ID: OIDC authorization-code + PKCE in the SPA (MSAL), JWT
  bearer validated by the API. Tokens are never minted or stored by FleetKeep.
- Authorization is enforced **server-side** on every endpoint via policy-based `[Authorize]`.
  The SPA hides controls the user cannot use, but hiding is cosmetic — the API is the boundary.
- Roles (per tenant): `TransportManager`, `Technician`, `Driver`, `ComplianceOfficer`,
  `DepotAdmin`, `TenantAdmin`. A user may hold several.
- Role capabilities:
  - `Driver` — submit walkaround checks and defects for vehicles assigned to them; read nothing else.
  - `Technician` — read and progress job cards at their depot; record parts usage.
  - `TransportManager` — full read across their depots; schedule/reschedule inspections; authorise
    return to service.
  - `ComplianceOfficer` — tenant-wide read; run audit exports; cannot modify operational records.
  - `DepotAdmin` — manage vehicles, depots and driver assignments.
  - `TenantAdmin` — manage users and roles; no operational write access.
- Depot scoping is a second filter *inside* the tenant: a manager sees only their assigned depots
  unless they hold the tenant-wide `ComplianceOfficer` role.
- The only unauthenticated endpoints are `GET /health` and `GET /api/v1/meta/version`.

## Domain rules

### Inspection scheduling

- Every vehicle has an inspection frequency in weeks (4, 6, 8, 10, 13 are the presets) and an
  anchor date. Due dates are computed forward from the anchor, never from the completion date, so
  a late inspection does not shift the whole schedule.
- Completing an inspection early does **not** move the next due date unless the manager explicitly
  re-anchors; re-anchoring is an audited action with a mandatory reason.
- Compliance banding is derived, never stored: **green** more than 14 days to due, **amber** 14
  days or fewer, **red** past due. The thresholds live in `ComplianceBanding` and are the single
  definition used by the dashboard, the worker and the exports.
- A vehicle marked off-road (VOR) keeps accruing due dates but is excluded from red-banding alerts;
  it cannot be returned to service with an overdue inspection.

### Defects and walkaround checks

- A walkaround check is immutable once submitted. A correction is a new check, and both remain in
  the audit trail.
- Defect categories: **A** (immobilising — vehicle must not be driven), **B** (repair within 48
  hours), **C** (monitor, repair at next service).
- Reporting a category-A defect immediately sets the vehicle to VOR. Only a `TransportManager` can
  authorise return to service, and only once every category-A defect on the vehicle is closed.
- Defect state machine: `Reported → Triaged → JobCardRaised → InProgress → Resolved → Closed`, plus
  `Rejected` from `Triaged` (with a reason). No transition may skip a state, and `Closed` is terminal.
- A category-A defect still in `Reported` or `Triaged` after 4 hours is escalated by the worker to
  the transport manager; a category-B defect escalates at 36 hours.

### Job cards and parts

- A job card belongs to exactly one vehicle and may bundle several defects, all at the same depot.
- Closing a job card requires: labour time recorded, every linked defect resolved or explicitly
  deferred with a reason, and a technician signature (the authenticated user id).
- Parts consumed decrement depot stock at closure, not at allocation. Stock may not go negative;
  the closure fails with a validation error instead.
- A part falling below its reorder threshold raises a reorder alert on the next worker pass.

### Audit and retention

- Every create/update/delete of a vehicle, check, defect or job card writes an audit row
  (`who`, `when`, `what changed`, `why` where a reason is required).
- Audit rows are append-only; nothing in the application can update or delete them.
- Compliance records are retained for 15 months minimum (the DVSA requirement) — deletion of a
  vehicle is a soft delete that preserves its history.

## Rules still to be defined

- Per-tenant quotas (vehicles, users, blob storage) — none enforced today.
- API rate limiting — not implemented; assumed acceptable while FleetKeep is behind Entra ID.
- Retention beyond 15 months: whether records are archived to cool storage or kept indefinitely.
- Whether a tenant can define custom inspection frequencies outside the five presets.
- Bulk vehicle import: the file format and how partial failures are reported.
- Offline behaviour for the driver walkaround check on a poor depot connection.
