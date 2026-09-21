<!-- STACK REFERENCE — Node.js / TypeScript backend (Serverless + Drizzle/DynamoDB).
     Reference only: the system does NOT read this file. It reads the TEMPLATE at
     .ai/standards/project/backend/tech-specific.md. SMEs on a Node backend: copy the rules
     that fit into that template file and adapt the example paths/libraries to your project. -->

# Backend Tech-Specific Standards — Node.js / TypeScript

## TypeScript

- Strict mode is on. Never use `any` — use `unknown` with type narrowing, or define the type.
- Use `import type` for type-only imports: `import type { Handler } from './types.js'`
- No implicit returns in functions with a declared return type.
- Prefer `Pick<SomeService, 'methodA' | 'methodB'>` for dependency typing over importing the full service type.

## Module System

Compilation target (CommonJS vs ESM) determines import rules. Check `tsconfig.json` `module` before assuming behavior:
- **ESM:** relative imports **must** end in `.js` even though the source file is `.ts` (runtime resolves the compiled output).
- **CommonJS:** standard relative imports without extension work.

## Serverless Framework

- Routes, environment variables, and IAM permissions are defined in your `serverless.yml`. Do not put route definitions anywhere else.
- **Each route is its own `functions:` block** mapping `handler: <domain>/<file>.handler` to a single `http` event. This per-function mapping — **not** an in-code router — is the deployment routing mechanism. Adding a route only to an in-code router will **not** expose it.
- **Every `path` + `method` must be unique.** Before adding a route, grep `serverless.yml` for the path. Duplicate `http` events for the same path+method break local emulation and deploy with a "duplicate route" error.
- Add new environment variables to `serverless.yml` (not just `.env`) so they're available in Lambda.
- Override timeout or memory per-function only when truly needed — global defaults should already be generous.
- The offline emulator (e.g. `npm run offline`) emulates API Gateway + Lambda locally. Always test new routes locally before deploying.

## Drizzle ORM (PostgreSQL)

- Import the Drizzle client **only** from a single client module (e.g. `data-access/drizzle/client.ts`). Never instantiate `drizzle()` or a `pg` pool elsewhere.
- Define all new tables in one schema module (e.g. `data-access/drizzle/schema.ts`).
- Generate migrations with your migrate script after schema changes — never hand-write migration SQL.
- Every query that touches tenant data must include a tenant predicate (e.g. `where(eq(table.customerId, customerId))`). Forgetting this is a tenant-isolation security bug.
- Use Drizzle's typed query builder — avoid raw `db.execute(sql\`...\`)` unless absolutely necessary.

## DynamoDB

- Import only from a single client wrapper (e.g. `data-access/DynamoDbClient.ts`).
- All table names come from a constants module (e.g. `data-access/tables.ts`). Never hardcode a table name string.
- Design access patterns around the existing PK/SK structure per domain — check existing patterns before inventing new ones.

## Error Handling

- Throw typed errors from a shared error hierarchy. Do not `throw new Error('...')` directly in services.
- Handlers catch typed errors and map them to HTTP status codes + `{ error: { message, code } }` — via the handler or a shared `handleError` utility.
- Never expose stack traces or internal details in error responses.
- Log errors with context via a shared logger. Include `customerId` and `userId` in log metadata.

## Request Validation

- Validate all incoming request bodies and query parameters before passing to services.
- Use Zod schemas in a shared validations module and an `assertValid()` helper at the top of handlers.
- Return `400` with a clear field-level message on validation failure.

## Request body casing (client/server contract)

If the frontend transforms request bodies (e.g. a `fetchWithAuth` helper that converts keys to
**snake_case** on the way out and back to camelCase on responses), a handler reading the JSON body
receives **snake_case** keys, not the camelCase written in the frontend type. This is a classic
silent-400 bug.

- When a handler reads a JSON body, read the casing the client actually sends — or accept both
  defensively: `const ids = body.documentIds ?? body.document_ids;`
- Alternatively the caller sends the body verbatim with plain `fetch`. Pick one approach and keep the
  handler and its caller consistent.

## Anti-Patterns

| Anti-pattern | Correct approach |
|-------------|-----------------|
| `import { db } from 'drizzle-orm/pg'` in a handler | Import from the single `drizzle/client` module |
| `new DynamoDB()` in a service | Import from the `DynamoDbClient` wrapper |
| Returning ORM row objects directly | Map to typed response types |
| Hardcoding `"my-table-name"` | Use a `tables.*` constant |
| Business logic in the router | Logic belongs in services |
| `throw new Error('Not found')` | `throw new NotFoundError('...')` |
