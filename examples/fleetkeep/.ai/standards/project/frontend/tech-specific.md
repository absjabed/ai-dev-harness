# Frontend Tech-Specific Standards

Concrete rules for the frontend stack: TypeScript 5.5 / React 18 + Vite 5 /
Mantine v7 theme tokens + CSS Modules / Mantine v7.

## Language / React 18 + Vite 5

- `strict: true` plus `noUncheckedIndexedAccess` and `exactOptionalPropertyTypes`. `any` is banned
  by ESLint; use `unknown` and narrow. A `@ts-expect-error` needs a comment and a follow-up issue.
- Functional components only. No class components, no `React.FC` (it obscures children typing) —
  type the props object directly.
- Named exports for everything, including components and hooks. No default exports.
- Props interfaces are named `<Component>Props` and colocated in the same file.
- Explicit return types on exported functions and hooks; inference is fine for local helpers.
- `import type { … }` for type-only imports, enforced by `verbatimModuleSyntax`.

## Component placement

Feature-first, not atomic design. A feature folder owns everything it alone uses; promotion to
`src/components/` happens when a second feature needs it, not in anticipation.

| What you're building | Where it goes |
|----------------------|--------------|
| Single-purpose primitive (Button, Icon, Input) | Use Mantine's — do not build one |
| Small composition of primitives (StatusBadge, DueDateChip) | `src/components/` |
| Feature section with business logic (DefectTriagePanel) | `src/features/<feature>/components/` |
| Full page / route component | `src/features/<feature>/pages/`, mounted from `src/routes/` |
| Layout shell (AppShell, nav, depot switcher) | `src/components/layout/` |
| Mantine primitive wrapper (themed defaults) | `src/theme/components/` + theme `components` overrides |

Layering rules: `src/components/` must never import from `src/features/`; a feature must never
import another feature's internals (promote the shared piece instead); pages hold data hooks,
presentational components receive props. If a shared component starts taking a `variant` prop that
encodes one feature's business case, that logic belongs back in the feature.

## Styling (Mantine v7 theme tokens + CSS Modules)

- Mantine props (`p`, `gap`, `c`, `bg`, `radius`) for layout and spacing; CSS Modules
  (`Component.module.css`) for anything structural or repeated. No CSS-in-JS runtime, no Tailwind.
- Inline `style` is allowed only for genuinely dynamic values (a computed bar width, a transform
  during drag) — never for static colour or spacing.
- **No hardcoded hex, rgb or px for colour/spacing/radius.** Use theme tokens:
  `var(--mantine-color-brand-6)`, `var(--mantine-spacing-md)`, `theme.radius.md`. The token
  inventory is `design/palette.md` and `design/design-tokens.md`, both mirrored from
  `src/theme/theme.ts`.
- Conditional classes use `clsx`; concatenating class strings by hand is a review comment.
- Dark mode comes free from Mantine tokens. A colour written as a raw hex will not adapt — that is
  the practical reason the rule exists, not just consistency.

## Mantine v7 primitives

Mantine is the component library: reach for `Button`, `Table`, `Modal`, `Select`, `DatePickerInput`,
`Notification` before writing anything. Project-wide defaults (sizes, radius, variants) are set once
in the theme's `components` block rather than repeated per call site. A genuinely new primitive goes
in `src/components/` with a Vitest test and an entry in `design/component-specs.md` — see that file
for the primitive inventory and required state matrix (default / hover / focus-visible / active /
disabled / loading / error).

## Data fetching

TanStack Query v5 owns server state. One hook per endpoint in `src/api/hooks/`, wrapping the
generated client; components use hooks only. Query keys are
`['resource', tenantId, ...params]` so a tenant switch cannot serve stale rows. Mutations invalidate
by key — never refetch by hand, never write server data into `useState`.

```ts
// ✅ In a component
const { data, isLoading, error } = useDefects({ depotId, state: 'Reported' })

// ✅ In a mutation
const { mutateAsync } = useTriageDefect() // invalidates ['defects', tenantId] on success

// ❌ In a component
const defects = await api.defects.list({ depotId })
```

`staleTime` is 30s by default; the compliance dashboard adds `refetchInterval: 60_000`.

## API request/response payload casing

The wire format is `camelCase` in both directions and the client is generated from the API's OpenAPI
document, so no casing transform exists anywhere in `src/api/`. Do not add one, and do not
hand-write a request type — regenerate with `npm run api:generate` when the contract changes. A
field arriving as `undefined` is a contract mismatch to fix at the source, never something to patch
with a rename at the call site.

## Auth (Microsoft Entra ID)

- `@azure/msal-react` is the only owner of session and tokens. Read sign-in state with
  `useIsAuthenticated()` and the account with `useAccount()`.
- The bearer token is attached in **one** place — the axios request interceptor in
  `src/api/client.ts`, which calls `acquireTokenSilent` and falls back to a redirect. No call site
  ever sets an `Authorization` header.
- Never read a token from `localStorage`/`sessionStorage`, never decode one to make an authorization
  decision, never cache one in app state.
- Sign-out calls MSAL's `logoutRedirect` and clears the TanStack Query cache.
- App-level permissions come from `GET /api/v1/tenancy/me` via `usePermissions()` — not from token
  claims.

## Environment variables

- Only `VITE_`-prefixed variables are exposed by Vite: `VITE_API_BASE_URL`, `VITE_ENTRA_CLIENT_ID`,
  `VITE_ENTRA_TENANT_ID`, `VITE_APP_ENV`.
- Access them as `import.meta.env.VITE_*`. **`process.env` does not exist in the browser bundle** —
  the `FRONTEND_ENV_CHECK` hook warns when it appears in a `src/Web` edit.
- Values are read once in `src/config/env.ts`, validated with Zod at startup, and imported from
  there — no scattered `import.meta.env` reads.
- Never hardcode an API URL, client id or storage account name. Never put a secret behind `VITE_`;
  everything with that prefix ships to the browser.
- Local setup: copy `.env.example` → `.env.local` (gitignored) and fill it.

## Forms (Zod)

Define the Zod schema first, infer the type from it, and wire it through `zodResolver`:

```ts
const reportDefectSchema = z.object({
  vehicleId: z.string().uuid(),
  category: z.enum(['A', 'B', 'C']),
  description: z.string().min(10, 'Describe the defect in at least 10 characters'),
})
type ReportDefectForm = z.infer<typeof reportDefectSchema>

const form = useForm<ReportDefectForm>({ resolver: zodResolver(reportDefectSchema) })
```

The schema is the single source of truth for both the payload type and the messages. Field errors
render inline under the control. Server-side validation failures arrive in
`ApiResponse.error.details` and are mapped back onto the same fields with `setError`. Client
validation is UX only — the API re-validates and is the security boundary.

## Real-time

Not applicable. FleetKeep has no websocket or SSE layer; the dashboard polls. If real-time is ever
introduced it needs an ADR — it changes hosting, auth and the offline story.

## Anti-patterns

| Anti-pattern | Correct approach |
|-------------|-----------------|
| Raw axios/`fetch` in a component | Use the hook from `src/api/hooks/` |
| Mirroring server data into `useState` | Let TanStack Query own it |
| Reading env via `process.env` | `import.meta.env.VITE_*`, surfaced through `src/config/env.ts` |
| A secret behind a `VITE_` variable | Keep it server-side; the bundle is public |
| Reading or refreshing an MSAL token by hand | The axios interceptor does it once |
| Hardcoded hex/px in styles | Mantine theme tokens (`design/palette.md`) |
| Hand-rolling a component Mantine provides | Use Mantine; theme it in `src/theme/theme.ts` |
| Default export for a component | Named export |
| Rendering a privileged control disabled | Do not render it at all |
| Colour-only status indication | Always pair colour with a label or icon |
| `../../../` imports across folders | `@/` path alias |
