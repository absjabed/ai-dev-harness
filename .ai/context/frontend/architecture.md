<!-- TEMPLATE FILE — replace {{TOKENS}} and [FILL IN] blocks. See .ai/CUSTOMIZATION.md or run /init-project. -->
# Frontend Architecture

## Component Hierarchy

> [FILL IN: describe your component organization and layering convention ({{LAYERING_PATTERN}}) and
> the rules for dependencies between layers (e.g. lower layers must not import higher ones; extend
> shared primitives before creating new ones). A tiny generic skeleton to adapt:]
>
> ```mermaid
> graph TD
>     P[Pages<br/>route-level mount] --> O[Feature sections]
>     O --> M[Composed components]
>     M --> A[Base UI primitives]
>     P --> T[Layout templates]
> ```
>
> ```
> {{SOURCE_DIR}}/components/
> ├── ...   # [describe each layer directory and what belongs in it]
> ```

## Routing

> [FILL IN: which router you use and where routes are declared. List the route → page mapping and
> which routes are protected vs. public, and how unauthenticated users are handled.
> A small skeleton:]
>
> ```
> /            → HomePage (protected)
> /login       → LoginPage (public)
> ...
> ```

## Data Flow

> [FILL IN: how a screen gets its data — component → data hook → API client → backend — and how the
> auth token is attached. A tiny generic sequence skeleton to adapt:]
>
> ```mermaid
> sequenceDiagram
>     participant Page
>     participant Hook as Data hook
>     participant API as API client
>     participant BE as Backend
>     Page->>Hook: useResource()
>     Hook->>API: api.getResource()
>     API->>BE: request + auth header
>     BE-->>API: response
>     API-->>Hook: data
>     Hook-->>Page: { data, isLoading, error }
> ```

## State Management

> [FILL IN: table of state categories and the mechanism for each — auth state, cached server data,
> app-wide UI state, form state, real-time events. State the rule for when to reach for a global
> store vs. existing cache/context.]
>
> | Type | Mechanism |
> |------|-----------|
> | ...  | ...       |

## API Layer

> [FILL IN: describe the API client layer under {{SOURCE_DIR}} — one module per domain, a shared
> HTTP client that sets the base URL, injects the auth token from {{AUTH_PROVIDER}}, and handles
> auth failures (e.g. sign-out on 401). Describe how data hooks wrap these calls for caching.]

## Real-Time

> [FILL IN: if the app has real-time features, describe how the connection is established and
> shared (one connection, managed centrally), and list the events components subscribe to.
> Delete this section if there is no real-time layer.]

## Branding / Theming Implementation

> [FILL IN: how brand/theme values are resolved and applied (build-time vs. runtime), where the
> brand tokens live, and how feature gating is evaluated in code. Delete if single-theme.]

## Path Alias

> [FILL IN: your import alias convention (e.g. `@` → {{SOURCE_DIR}}) and where it is configured.
> Show a couple of example imports so contributors follow it consistently.]
