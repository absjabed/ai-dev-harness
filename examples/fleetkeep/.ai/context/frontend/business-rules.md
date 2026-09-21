# Frontend Business Rules

## Authentication

- Every route except `/login` requires an authenticated Entra ID session. `<RequireAuth>` sends
  unauthenticated users to `/login`, which starts the MSAL redirect and returns them to the
  original path afterwards.
- MSAL is the single source of truth for auth state and tokens. The app never stores a token in
  `localStorage`, never decodes one to make a decision, and never refreshes one by hand.
- **401** → the response interceptor triggers MSAL sign-out and redirects to `/login` (the session
  is genuinely gone). **403** → no redirect; the page renders an inline access-denied state, because
  the user is signed in and simply lacks the permission.
- Sign-out clears the TanStack Query cache, so a subsequent sign-in on a shared depot machine never
  shows the previous user's rows.

## Role-Based UI

- Roles come from `GET /api/v1/tenancy/me` into `TenantContext`, exposed through `usePermissions()`.
  They are never read from the token on the client.
- Privileged UI is hidden by conditional rendering — a nav item, button or column the user cannot
  use is not rendered at all, rather than rendered disabled. Route guards alone are not sufficient.
- The client never trusts itself for authorization. Hiding a control is a usability choice; the API
  enforces the rule (see backend business rules). A UI that "prevents" an action the API would
  allow is a bug in the same way as the reverse.
- Depot scoping applies in the UI too: the depot switcher lists only the user's assigned depots,
  and a `ComplianceOfficer` additionally gets an "All depots" option.

## Feature Flags / Branding

- No runtime flag service. Unfinished work sits behind a build-time constant in
  `src/config/features.ts`; a disabled feature must not render in nav or routing, not even greyed
  out, and the constant is deleted at release.
- Single brand, resolved at build time from the Mantine theme. Colour scheme (light/dark) is the
  only user-facing theming choice, applied once at the provider — never re-applied per component.

## Domain UI Rules

### Compliance dashboard

- Banding colour always ships with a text label ("Overdue", "Due in 9 days") and an icon — never
  colour alone. This is an accessibility rule, not a style preference.
- Banding is taken from the API response; the client never recomputes it from dates, so the
  dashboard, the worker and the exports cannot disagree.
- The list is paged (50 per page) and virtualised above 200 rows; there is no "show all".

### Walkaround check

- Mobile-first: usable one-handed at 360px, controls at least 44px tall, camera capture via
  `<input type="file" capture="environment">`.
- A submitted check is immutable — after submit the form is replaced by a read-only summary with a
  "report another defect" action, never an edit form.
- Submission is blocked offline with an explicit message; there is no silent local queue, because
  a check that never reaches the API is a compliance gap.

### Defects

- Category-A selection shows an inline warning that the vehicle will be immobilised before submit.
- The state machine is rendered as a stepper; only transitions the API permits for that role are
  offered as actions.
- A rejected defect always displays its rejection reason next to the state.

### Job cards

- Parts consumption fields validate against current stock client-side for fast feedback, but the
  closure result from the API is authoritative — a client-side pass never implies success.
- "Authorise return to service" is visible only to `TransportManager` and disabled with an
  explanatory tooltip while any category-A defect is open.

## File Uploads

Defect photos upload **direct to Azure Blob Storage**, never through the API:

1. Client requests an upload slot: `POST /api/v1/defects/{id}/photos/upload-url`.
2. API returns a short-lived user-delegation SAS URL plus the final blob path.
3. Client `PUT`s the file straight to blob storage with a progress indicator.
4. Client confirms with `POST /api/v1/defects/{id}/photos` so the API records the attachment.
5. On failure at step 3 the client retries once, then surfaces an error; the unconfirmed blob is
   cleaned up by lifecycle policy.

Client-side limits: JPEG/PNG/HEIC only, 10MB per file, 6 files per defect, downscaled to 2048px on
the long edge before upload.

## Error Handling

- API errors surface as a notification toast carrying the human-readable `message` and the
  `traceId` in small print — never a stack trace, never a raw exception string.
- Form validation renders inline beneath the field from the Zod schema; the form does not submit
  while invalid, and server-side field errors from `ApiResponse.error.details` map back onto the
  same fields.
- A failed background refetch shows a subtle non-blocking banner ("Last updated 4 minutes ago") and
  keeps the stale data on screen rather than blanking the page.
- An unexpected render error is caught by a route-level error boundary offering a retry.

## Performance

- Route-level code splitting: every route module is lazy-loaded.
- Every list is paged server-side; unbounded lists are never rendered. Grids above 200 rows use
  `@tanstack/react-virtual`.
- Expensive components (the audit timeline, the PDF preview) are lazy-loaded on interaction.
- Filter inputs debounce at 300ms before hitting the API, and `keepPreviousData` prevents the table
  from flashing empty between pages.
- Target: dashboard interactive in under 2.5s on a mid-range Android phone on depot 4G.
