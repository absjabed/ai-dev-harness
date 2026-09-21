# Frontend Project Overview

## What It Does

The FleetKeep frontend is the single interface every persona uses: transport managers watching the
compliance dashboard, technicians working the job-card queue, drivers submitting walkaround checks
from a phone, and compliance officers pulling audit packs. It renders state the API owns and
enforces nothing itself — role gating in the UI is presentation, and the API remains the security
boundary. The frontend is built with React 18 + Vite 5, lives in `src/Web`, and talks only to the
FleetKeep API.

## Pages & Routes

| Page (route) | Purpose |
|--------------|---------|
| `/` | Compliance dashboard — fleet banded red/amber/green by nearest due date (protected) |
| `/vehicles` | Vehicle register with filters; add/edit for `DepotAdmin` |
| `/vehicles/:id` | Vehicle detail — schedule, defect history, job cards, audit timeline |
| `/inspections` | Upcoming and overdue inspections; reschedule (TransportManager) |
| `/checks/new` | Driver walkaround check — mobile-first, photo capture |
| `/defects` | Defect list with category and state filters |
| `/defects/:id` | Defect detail, triage actions, linked job card |
| `/jobcards` | Workshop queue for the user's depot |
| `/jobcards/:id` | Job card — labour, parts, closure and return-to-service |
| `/parts` | Depot stock levels and reorder alerts |
| `/exports` | Audit pack generation (ComplianceOfficer, TransportManager) |
| `/admin/users` | Users and roles within the tenant (TenantAdmin) |
| `/login` | MSAL redirect landing (public) |
| `/forbidden` | Inline access-denied page for 403 responses (protected) |

## Branding / Theming

Single brand. Light and dark colour schemes both ship, resolved by Mantine's `ColorSchemeScript`
from the user's OS preference with a manual override persisted in `localStorage`. There is no
per-tenant white-labelling: a tenant cannot change the logo, palette or product name. Adding
white-labelling would be an ADR, not an incremental change, because every design token currently
resolves at build time from `src/Web/src/theme/theme.ts`.

## Feature Flags / Tabs

No runtime feature-flag service. Navigation is gated by **role**, not by flags: `usePermissions()`
returns the caller's capabilities, and a nav item or route the user cannot use is not rendered.
Anything genuinely unfinished ships behind a build-time constant in `src/Web/src/config/features.ts`
and is removed once released.

## Key Integrations

- **Backend API** — a generated OpenAPI client over a shared axios instance (`src/api/client.ts`)
  for all CRUD; wrapped by TanStack Query v5 hooks.
- **Microsoft Entra ID** — `@azure/msal-react` for sign-in, silent token acquisition and sign-out.
- **Azure Blob Storage** — defect photos upload **direct to blob** using a short-lived SAS URL the
  API issues; file bytes never pass through the API.
- **Application Insights** — browser SDK for page views and unhandled errors, with the trace id
  from `ApiResponse` correlated to the server side.
- **Real-time** — none. The dashboard uses a 60s `refetchInterval`.
