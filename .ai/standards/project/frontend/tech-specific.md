<!-- TEMPLATE FILE — replace {{TOKENS}} and [FILL IN] blocks. See .ai/CUSTOMIZATION.md or run /init-project. -->
# Frontend Tech-Specific Standards

Concrete rules for the frontend stack: {{FRONTEND_LANGUAGE}} / {{FRONTEND_FRAMEWORK}} /
{{STYLING_SYSTEM}} / {{COMPONENT_LIBRARY}}.

> Delete this entire file (and the `design/` subtree) if the project has no frontend.

## Language / {{FRONTEND_FRAMEWORK}}

> [FILL IN: your frontend language/typing and component-authoring rules — strictness, function vs.
> class components, import/export conventions, explicit return types.]

- Example: strict typing — no untyped escape hatch; narrow or define the type. *(replace)*
- Example: functional components only. *(replace)*
- Example: named exports for components (cleaner refactors/barrels). *(replace)*

## Component placement

> [FILL IN: your component organization convention and a where-does-it-go table. The example below
> assumes atomic design — replace with whatever your project uses (feature folders, etc.).]

| What you're building | Where it goes |
|----------------------|--------------|
| Single-purpose primitive (Button, Icon, Input) | `[FILL IN]` |
| Small composition of primitives | `[FILL IN]` |
| Feature section with business logic | `[FILL IN]` |
| Full page / route component | `[FILL IN]` |
| Layout shell | `[FILL IN]` |
| {{COMPONENT_LIBRARY}} primitive wrapper | `[FILL IN]` |

> [FILL IN: your layering rules — e.g. "never put feature complexity into primitives", "never import
> from pages in lower layers".]

## Styling ({{STYLING_SYSTEM}})

> [FILL IN: your styling rules — utility-first vs. CSS modules vs. CSS-in-JS, the conditional-class
> helper, the "no hardcoded hex; use design tokens" rule, and where tokens are defined.]

- Example: style via {{STYLING_SYSTEM}}; avoid inline styles except for dynamic animated values. *(replace)*
- Example: use a `cn()`-style helper for conditional classes to avoid conflicts. *(replace)*
- Example: design tokens (colors/spacing) live in the theme config — don't hardcode hex values (see `design/`). *(replace)*

## {{COMPONENT_LIBRARY}} primitives

> [FILL IN: where reusable base primitives live, and the "reuse/extend before building new" rule. See
> `design/component-specs.md` for the primitive inventory and state matrix.]

## Data fetching

> [FILL IN: how components fetch server data — the hook/data layer, the raw HTTP client layer, and the
> hard rule that components use the hook layer (never the raw client directly). Cover cache
> keys/invalidation if your data layer caches.]

```
// Example — replace with your project's pattern
// ✅ In a component: const { data, error, isLoading } = useThreads()
// ❌ In a component: const threads = await api.getThreads()
```

## API request/response payload casing

> [FILL IN: if your HTTP client transforms request/response key casing (e.g. camelCase ⇆ snake_case),
> document the exact behavior of each request path so a body isn't silently misread by the backend.
> Keep each service's methods consistent with their siblings. Delete if your wire format is uniform.]

## Auth ({{AUTH_PROVIDER}})

> [FILL IN: how the frontend reads the current user/session and attaches tokens to requests — the
> supported API for current user, tokens, sign-in state, and sign-out; the rule to NOT read tokens
> from `localStorage` directly; and where the HTTP interceptor attaches the token (so it isn't
> duplicated per call).]

## Environment variables

> [FILL IN: env var conventions — the required prefix so the bundler exposes them, how to access them
> in code (not `process.env`), the "never hardcode API URLs / auth IDs / bucket names" rule, and the
> local `.env` setup step.]

- Example: all frontend env vars use the bundler's required prefix. *(replace)*
- Example: access via the bundler's env object, never `process.env`. *(replace)*
- Example: copy `.env.example` → local env file and fill values for dev. *(replace)*

## Forms ({{VALIDATION_LIB}})

> [FILL IN: your form + validation pattern — define a {{VALIDATION_LIB}} schema, infer the form type
> from it, wire it into the form library, and surface field-level errors from the schema.]

## Real-time (if applicable)

> [FILL IN: real-time transport and its lifecycle rules — a single shared client instance (via context
> or a module singleton), subscribe/unsubscribe with cleanup, and "never create a new connection inside
> a component". Delete if not applicable.]

## Anti-patterns

> [FILL IN: your frontend anti-patterns as a table. Examples below — replace with real ones.]

| Anti-pattern | Correct approach |
|-------------|-----------------|
| Raw HTTP call in a component | Use the shared data hook *(replace)* |
| Reading env via `process.env` | Use the bundler's env object *(replace)* |
| Reading auth token from `localStorage` | Use the {{AUTH_PROVIDER}} session API *(replace)* |
| Hardcoded hex in styles | Use a design-token class *(replace)* |
| Default export for a component | Named export *(replace)* |
| Creating a new real-time connection in a component | Use the shared client/context *(replace)* |
