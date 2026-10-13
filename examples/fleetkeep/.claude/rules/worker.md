---
paths:
  - "src/Worker/**"
---

# Worker (`src/Worker`) — .NET 8 isolated Azure Functions, timer-triggered

- A function body builds a tenant context and calls the **same application services the API
  uses**. Never re-implement a domain rule here, and never call the API over HTTP — if the worker
  needs new behaviour, add it to `FleetKeep.Application` and its tests.
- It shares `FleetKeep.Application` and `FleetKeep.Infrastructure` with the API, so an entity or
  schema change made for the API ships to the worker in the same release — run
  `dotnet test src/Worker/FleetKeep.Worker.Tests` whenever you touch either shared project.
- There is no HTTP request, so no caller tenant: each pass iterates tenants and scopes every unit of
  work to one `TenantId`. Never reach for `IgnoreQueryFilters()` to "see everything" — it is banned
  outside `FleetKeep.Infrastructure.Admin`, and crossing tenants is a CRITICAL defect.
- Every pass is **idempotent**, and a tenant that throws is logged and skipped. Keep both true: a
  rerun must not double-send a notification or double-create a record, and one tenant's failure
  must never abort the others.
