# Architectural Decisions Log

This file is maintained automatically. Agents append decisions here.
Format each entry: `Date | Decision | Reason | Agent`

Record only non-obvious, precedent-setting, or hard-to-reverse decisions — not routine steps.

## Decisions

<!-- Example (delete once you have real entries):
- 2026-01-01 | Adopted this agent-system template | Reusable, project-aware agent framework | initializer
-->
- 2026-02-03 | Initialized agent system for FleetKeep | via /init-project | initializer
- 2026-02-11 | Shared-database, shared-schema multi-tenancy with a TenantId global query filter, rather than a database per tenant | Tenants are small (10-400 vehicles) and numerous; per-tenant databases would multiply migration and cost overhead. Accepted trade-off: isolation becomes a code invariant, so it is enforced by a query filter, a banned-API test, and a CRITICAL security-scanner check | architect
- 2026-02-18 | Mantine v7 as the component library over MUI and a hand-rolled system | Mantine's theme tokens generate CSS custom properties, giving dark mode and a token discipline for free; MUI's emotion runtime was unnecessary weight for a data-dense internal tool | designer
- 2026-03-04 | Migrations must be backward-compatible for one release (expand -> migrate -> contract) | App Service deploys are rolling with no slot swap, so the old and new API versions run simultaneously against one database | architect
- 2026-03-22 | Defect photos upload direct-to-blob via short-lived user-delegation SAS, not through the API | Depot uploads over 4G were timing out App Service requests and burning API memory; direct upload also keeps PII images off the app tier | developer
- 2026-04-09 | Compliance banding (red/amber/green) is computed server-side only and never recomputed on the client | The dashboard, the nightly worker and the audit exports were producing different bands from the same data | developer
