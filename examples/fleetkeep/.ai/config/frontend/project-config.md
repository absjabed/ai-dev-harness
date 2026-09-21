# Frontend Project Config

## Identity
**Project**: FleetKeep — Frontend
**Root directory**: `src/Web`
**Framework**: React 18 + Vite 5
**Language**: TypeScript 5.5 (strict; `noUncheckedIndexedAccess` on)
**Dev server**: Vite on port **5173** (`npm run dev`), proxying `/api` to `https://localhost:7241`
**Backend API**: `VITE_API_BASE_URL` — set per environment; the dev proxy is used locally so the
browser never sees a cross-origin API

## Tech Stack
| Layer | Technology |
|-------|-----------|
| Framework | React 18 + Vite 5 |
| Build tool | Vite 5 (esbuild dev, Rollup build) |
| Routing | React Router v6 (`createBrowserRouter`, lazy route modules) |
| Auth | Microsoft Entra ID via `@azure/msal-react` |
| Styling | Mantine v7 theme tokens + CSS Modules |
| UI primitives | Mantine v7 (`@mantine/core`, `@mantine/dates`, `@mantine/notifications`) |
| Icons | `@tabler/icons-react` |
| Forms / validation | React Hook Form + Zod 3 (`zodResolver`) |
| Data fetching | TanStack Query v5 over an axios instance (`src/api/client.ts`) |
| Tables | Mantine `Table` + TanStack Table v8 for the sortable/filterable fleet grids |
| Real-time | none — the compliance dashboard polls with a 60s `refetchInterval` |
| Testing | Vitest + React Testing Library; Playwright for end-to-end |

## Development Commands
```bash
npm ci             # Install dependencies
npm run dev        # Dev server → http://localhost:5173
npm run build      # Production build (tsc --noEmit && vite build)
npm run typecheck  # tsc --noEmit
npm run lint       # ESLint 9 flat config
npm run test       # Vitest + React Testing Library
npm run test:e2e   # Playwright (requires the API running)
```

## Project Structure
```
src/Web/
└── src/
    ├── main.tsx        # app entry: MSAL provider, MantineProvider, QueryClientProvider, router
    ├── routes/         # one lazy-loaded module per route; the router is declared here
    ├── features/       # feature folders (vehicles, inspections, defects, jobcards, parts)
    ├── components/     # shared presentational components (no data fetching)
    ├── hooks/          # cross-feature hooks (useTenant, useDebouncedFilter, usePermissions)
    ├── api/            # generated OpenAPI client, axios instance, one query hook per endpoint
    ├── theme/          # Mantine theme object — the design-token source of truth
    └── test/           # test setup, MSW handlers, render helpers
```

## Environment Variables
```bash
VITE_API_BASE_URL=https://api-fleetkeep-dev.azurewebsites.net  # API origin (dev uses the Vite proxy)
VITE_ENTRA_CLIENT_ID=<spa app registration client id>          # public by design
VITE_ENTRA_TENANT_ID=<entra directory id>                      # public by design
VITE_APP_ENV=dev                                               # dev | staging | production — drives the env badge
# Only VITE_-prefixed variables reach the browser bundle. Never put a secret behind VITE_.
```

## Conventions
- **Component organisation**: feature-first. A feature folder owns its route pages, components,
  hooks and tests; anything used by two or more features moves to `src/components/` or `src/hooks/`.
  Files are `PascalCase.tsx` for components, `useThing.ts` for hooks, and colocated
  `Thing.test.tsx` / `Thing.module.css` next to the component.
- **Path alias**: `@` → `src/Web/src` (configured in both `vite.config.ts` and `tsconfig.json`).
  No `../../..` imports.
- **All API calls go through a single client layer**: never call `fetch()` / the HTTP client directly in components
- **Server state**: TanStack Query owns it. One hook per endpoint in `src/api/hooks/`, query keys
  `['resource', tenantId, ...params]`, mutations invalidate by key. Never mirror server data into
  `useState`.
- **App state**: cross-component state lives in a shared store/context — avoid prop-drilling more than a couple of levels
  > In practice that is only `TenantContext` (session, tenant, permissions). There is no Redux.
- **Auth tokens**: MSAL owns them. An axios request interceptor calls
  `acquireTokenSilent` and attaches the bearer token — components never read, store or refresh a
  token themselves.
- **Env vars**: access via your framework's client-safe mechanism — never read server-only secrets in the browser
  > Read `import.meta.env.VITE_*` only. `process.env` does not exist in the browser bundle, and the
  > `FRONTEND_ENV_CHECK` hook warns when it appears.
- **Dates**: all timestamps cross the wire as UTC ISO-8601 and render in the depot's local timezone
  via `formatInDepotTz()` — never `new Date().toLocaleString()` directly in a component.

## Never Do
- Call `fetch()` / the raw HTTP client directly in components — use the API layer
- Read `process.env` in browser code, or put a secret behind `VITE_`
- Hardcode API URLs — use configuration / env vars
- Manage auth tokens manually when the auth provider handles them
- Put business logic or API calls inside component files — use hooks / services
- Use default exports for components (prefer named exports)
- Hand-roll a component Mantine already provides, or hardcode a hex that isn't a theme token
