# Component Specs — base primitives

> **UI-ONLY.** Delete the `design/` subtree if the project has no UI.

The frontend uses **Mantine v7** base primitives. **Reuse these before building anything
new.** Style variations extend the existing primitive via Mantine props and theme `components`
defaults — never duplicate or fork a primitive. All values trace to `palette.md` +
`design-tokens.md`.

## Available primitives

From `@mantine/core`, `@mantine/dates`, `@mantine/notifications` and `@mantine/form`:

```
Accordion  ActionIcon  Alert  Anchor  AppShell  Avatar  Badge  Breadcrumbs  Button
Card  Checkbox  Chip  Divider  Drawer  FileButton  Group  Indicator  Loader  Menu
Modal  MultiSelect  NumberInput  Pagination  Paper  Popover  Progress  Radio
SegmentedControl  Select  Skeleton  Stack  Stepper  Switch  Table  Tabs  Textarea
TextInput  ThemeIcon  Timeline  Tooltip  notifications  DatePickerInput  DateTimePicker
```

Project components built on top (in `src/Web/src/components/`):

```
StatusBadge  DueDateChip  DefectCategoryChip  VehicleRegPlate  DepotSwitcher
EmptyState  PageHeader  ConfirmDialog  AuditTimeline  PhotoUploader
```

> Before creating a modal, drawer, dropdown, tabs, tooltip, or form control, **check this list
> first** — a primitive almost certainly already exists. (Mirrors the rule in `tech-specific.md`.)

## Required states for every interactive primitive

Each must implement the full state matrix from `ui-ux-standards.md`:
**Default · Hover · Active/pressed · Focus-visible · Disabled · Loading · Error · Empty ·
Selected/current · Read-only** (where applicable).

## Key primitives — at a glance

| Primitive | Variants / sizes | States to honor |
|-----------|------------------|-----------------|
| **Button** | `filled` (primary action), `light` (secondary), `outline` (tertiary), `subtle` (toolbar), `default`; `color="red"` for destructive. Sizes `xs`/`sm`/`md`; `md` minimum on the walkaround check (44px touch target) | hover, active, focus-visible, disabled, `loading` (spinner + disabled) |
| **TextInput / Textarea / NumberInput** | default; `error` prop carries the message | focus-visible, disabled, readOnly, error (red border + message + `aria-invalid`) |
| **Select / MultiSelect** | `searchable` on anything over 10 options | open/closed, highlighted option, disabled option, keyboard nav, `nothingFoundMessage` |
| **DatePickerInput / DateTimePicker** | inspection dates, audit range | min/max bounds, disabled dates, clearable, keyboard entry |
| **Modal / Drawer** | `Modal` for confirmations, `Drawer` (`position="bottom"`) for the mobile defect sheet | focus trap, Esc to close, scroll lock, `closeOnClickOutside={false}` for destructive confirms |
| **Badge / StatusBadge** | `light` variant; RAG colours from the status tokens | static — **always text + icon, never colour alone** |
| **Tabs / SegmentedControl** | vehicle detail sections; list filters | selected/current, focus-visible, disabled |
| **Checkbox / Radio / Switch** | form controls | checked/unchecked/indeterminate, focus-visible, disabled, error |
| **Tooltip / Popover** | floating help | opens on hover **and** focus, dismissible with Esc; never the only place information exists |
| **Skeleton** | loading placeholder | mirrors the final layout (row count, column widths); no spinner on first paint of a table |
| **notifications** | toast feedback | `aria-live` polite; success auto-dismiss 4s, errors persist until dismissed |
| **Table** | vehicle register, job-card queue, parts stock | sortable headers, sticky header, empty state, row hover, selected row |
| **Stepper** | defect state machine | completed / current / upcoming, only permitted transitions actionable |
| **Timeline / AuditTimeline** | vehicle audit trail | grouped by day, "who / when / what / why", empty state |
| **Card / Paper / Accordion** | content containers | expanded/collapsed, empty state |

## Project component notes

- **StatusBadge** — takes the server's banding value; renders pill + icon + text ("Overdue",
  "Due in 9 days"). The only approved way to display compliance state.
- **DueDateChip** — relative date with an absolute date in its tooltip; `tabular-nums`.
- **VehicleRegPlate** — monospace, uppercase, UK plate styling; never a free-text render.
- **PhotoUploader** — wraps `FileButton` + direct-to-blob upload with per-file progress, retry and
  the client-side limits (10MB, 6 files, downscale to 2048px).
- **EmptyState** — icon + one-line explanation + the primary action. Every list must use it; a bare
  "No data" string is a review comment.

## Rules

- **Don't strip Mantine's accessibility props/roles** when wrapping or restyling (see
  `accessibility.md`). If a wrapper swallows `aria-*` or the `ref`, it is wrong.
- **Don't hardcode hex.** Map every colour to a token — `var(--mantine-color-brand-6)`,
  `var(--mantine-color-dimmed)`, `var(--fk-status-red-bg)`.
- Set shared defaults in the theme's `components` block (e.g. `Button: { defaultProps: { radius:
  'md' } }`) rather than repeating props at every call site.
- A genuinely new primitive is a **design decision** — spec it here with its full state matrix
  before it is built, then add it to `src/Web/src/components/` with a Vitest test.
