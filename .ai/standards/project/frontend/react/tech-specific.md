<!-- STACK REFERENCE — React / TypeScript frontend (Vite + Tailwind + Radix + SWR + Amplify).
     Reference only: the system does NOT read this file. It reads the TEMPLATE at
     .ai/standards/project/frontend/tech-specific.md. SMEs on a React frontend: copy the rules that
     fit into that template file and adapt the example libraries/paths to your project. The
     `design/` folder here is an example filled design system — replace the values with your brand. -->

# Frontend Tech-Specific Standards — React / TypeScript

## TypeScript / React

- Strict TypeScript — no `any`. Use `unknown` with narrowing or define the type.
- Functional components only. No class components.
- Use `import type` for type-only imports.
- Named exports for all components (not default exports) — makes refactoring and barrel exports cleaner.
- Prefer explicit return types on custom hooks and utility functions.

## Component Placement (Atomic Design)

| What you're building | Where it goes |
|----------------------|--------------|
| Single-purpose primitive (Button, Icon, Input) | `components/atoms/` |
| 2-3 atom combination (SearchBar, FormField) | `components/molecules/` |
| Feature section with business logic (ChatPanel, TicketCard) | `components/organisms/` |
| Full page / route component | `components/pages/` |
| Layout shell (header + sidebar + content area) | `components/templates/` |
| Radix UI primitive wrapper | `components/ui/` |

Never put organism-level complexity into atoms/molecules. Never import from pages in organisms.

## Tailwind CSS

- All styling via Tailwind utility classes — no inline `style={{}}` unless animating dynamic values.
- For conditional classes, use the `cn()` utility (clsx + tailwind-merge) to avoid class conflicts:
  ```typescript
  import { cn } from '@/lib/utils'
  <div className={cn('base-class', isActive && 'active-class', className)} />
  ```
- No CSS modules or custom `.css` files unless there is a clear reason.
- Design tokens (colors, spacing) are in `tailwind.config.ts` — don't hardcode hex values (see `design/`).

## Radix UI / `components/ui/`

- Before creating a new modal, dropdown, tabs, or tooltip, check if a Radix UI primitive already exists in `components/ui/`.
- Extend the `ui/` component if you need styling variations — don't duplicate the component.

## Data Fetching (SWR + Axios)

- All server data must go through SWR hooks defined in `hooks/`. Never call `lib/api/` functions directly in components.
  ```typescript
  // ✅ In a component
  const { data, error, isLoading } = useThreads()

  // ❌ In a component
  const threads = await chatApi.getThreads()
  ```
- The SWR key must be unique and stable — use the API path string: `useSWR('/chat/threads', ...)`
- Mutate SWR cache after write operations (`mutate('/chat/threads')`) rather than triggering a full page reload.

## API request casing (`fetchWithAuth` vs plain `fetch`)

If service helpers use two request paths with **different body-casing behavior**, getting it wrong
makes the backend silently see a missing field:

- A `fetchWithAuth`-style wrapper may convert an outgoing JSON body `{ documentIds }` to snake_case
  `{ document_ids }`, and convert responses back to camelCase.
- Plain `fetch(...)` sends the body **verbatim** (camelCase preserved); set `Content-Type` + auth
  headers manually.

When adding a write endpoint that sends a JSON body: match what the backend reads (camelCase → plain
`fetch`; snake_case → the wrapper, or read both casings server-side), and be consistent with sibling
methods in the same service. Casing mismatches here are a classic silent-400 bug.

## AWS Amplify 6 Auth

- Get current user: `import { getCurrentUser } from 'aws-amplify/auth'`
- Get tokens: `import { fetchAuthSession } from 'aws-amplify/auth'`
- Check sign-in state: `useAuthenticator()` hook
- Sign out: `import { signOut } from 'aws-amplify/auth'`
- Do NOT read JWT tokens from `localStorage` directly — use Amplify's API.
- Centralize token attachment (e.g. an Axios interceptor calling `fetchAuthSession()`) — don't duplicate it per API function.

## Environment Variables

- All frontend env vars must be prefixed `VITE_` to be bundled by Vite.
- Access: `import.meta.env.VITE_API_URL` — never `process.env`.
- Never hardcode API URLs, Cognito IDs, or bucket names in source code.
- For local dev: copy `.env.local.example` to `.env.local` and fill in values.

## Forms (React Hook Form + Zod)

- Define Zod schema first, then infer the form type: `type FormData = z.infer<typeof schema>`
- Use `zodResolver(schema)` with `useForm()`.
- Field-level error messages come from Zod — display via `formState.errors.<field>.message`.

## Socket.io

- A single Socket.io client instance is shared via Context (e.g., `contexts/SocketContext`).
- Subscribe to events in `useEffect` with proper cleanup: `socket.off('event', handler)`.
- Never create a new `io()` connection inside a component.

## Anti-Patterns

| Anti-pattern | Correct approach |
|-------------|-----------------|
| `fetch('/api/threads')` in component | Use `useThreads()` SWR hook |
| `process.env.REACT_APP_URL` | `import.meta.env.VITE_API_URL` |
| `localStorage.getItem('token')` | `fetchAuthSession()` from Amplify |
| `style={{ color: '#3b82f6' }}` | Tailwind class `text-blue-500` |
| `import Component from './Component'` | Named export: `import { Component } from './Component'` |
| `new io('http://...')` in a component | Use `SocketContext` |
