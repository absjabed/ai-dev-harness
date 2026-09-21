<!-- TEMPLATE FILE — replace {{TOKENS}} and [FILL IN] blocks. See .ai/CUSTOMIZATION.md or run /init-project. -->
# Frontend Business Rules

## Authentication

> [FILL IN: the frontend auth rules. Suggested items to cover:]
> - Which routes require an authenticated session ({{AUTH_PROVIDER}}) and where unauthenticated
>   users are redirected.
> - The single source of truth for auth state (do not hand-manage tokens).
> - How the app reacts to 401 (sign out + redirect) vs. 403 (inline access-denied, no redirect).

## Role-Based UI

> [FILL IN: how roles are read on the client, and the rule that privileged UI must be hidden via
> conditional rendering — not route guards alone. State that the client never trusts itself for
> authorization: the server is authoritative (see backend business rules).]

## Feature Flags / Branding

> [FILL IN: rules for feature/brand gating — a feature not enabled must not render; brand/theme is
> resolved per your chosen mechanism and not re-applied inconsistently at runtime.
> Delete if not applicable.]

## Domain UI Rules

> [FILL IN: capture per-feature UI rules grouped by area (one `###` sub-heading each). Examples of
> the kind of rule to record: ownership/visibility constraints, how real-time updates render,
> which controls are role-gated, and any progressive/streaming UI behavior.]

## File Uploads

> [FILL IN: if the app uploads files, the rule for how (e.g. direct-to-storage via presigned URLs,
> never streaming file content through the backend) and the upload workflow steps.
> Delete this section if there are no uploads.]

## Error Handling

> [FILL IN: how errors surface to users — API errors (toast), form validation (inline), real-time
> disconnects (non-blocking banner). State the rule that raw error messages/stack traces are never
> shown to users.]

## Performance

> [FILL IN: frontend performance rules — route-level code splitting, pagination for large lists
> (never render unbounded lists), and lazy-loading of expensive components.]
