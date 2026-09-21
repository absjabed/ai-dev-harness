# Component Specs — `components/ui/*`

The frontend uses **shadcn-style Radix UI primitives** in `frontend/components/ui/`. **Reuse these
before building anything new.** Style variations extend the existing primitive (via `cn()` +
variant props) — never duplicate or fork a primitive. All values trace to `palette.md` +
`design-tokens.md`.

## Available primitives (verbatim from `frontend/components/ui/`)

```
accordion   alert        avatar       badge       breadcrumb   button
calendar    card         carousel     chart       checkbox     collapsible
command     dialog       drawer       dropdown-menu  form       hover-card
input       label        popover      progress    radio-group  resizable
scroll-area select       separator    sheet       sidebar      skeleton
slider      sonner       switch       table       tabs         textarea
toast       toaster      toggle       toggle-group tooltip
```

(plus `use-toast.ts` hook)

> Before creating a modal, drawer, dropdown, tabs, tooltip, or form control, **check this list
> first** — a primitive almost certainly already exists. (Mirrors the rule in `tech-specific.md`.)

## Required states for every interactive primitive

Each must implement the full state matrix from `ui-ux-standards.md`:
**Default · Hover · Active/pressed · Focus-visible (`--ring`) · Disabled · Loading · Error ·
Empty · Selected/current · Read-only** (where applicable).

## Key primitives — at a glance

| Primitive | Variants / sizes | States to honor |
|-----------|------------------|-----------------|
| **button** | `default` (primary orange), `secondary`, `outline`, `ghost`, `link`, `destructive`; sizes `sm`/`default`/`lg`/`icon` | hover, active, focus-visible, disabled, loading (spinner + disabled) |
| **input** / **textarea** | default; with `aria-invalid` error styling | focus-visible (`--ring`), disabled, read-only, error |
| **select** / **dropdown-menu** / **command** | Radix menu primitives | open/closed, highlighted item, disabled item, keyboard nav |
| **dialog** / **sheet** / **drawer** | overlay surfaces | open/close focus trap, Esc to close, scroll lock |
| **badge** | `default`, `secondary`, `outline`, `destructive` | static; carry text, not color-alone |
| **tabs** / **toggle** / **toggle-group** | selectable | selected/current, focus-visible, disabled |
| **checkbox** / **radio-group** / **switch** | form controls | checked/unchecked, focus-visible, disabled, error |
| **tooltip** / **hover-card** / **popover** | floating | open on hover/focus, keyboard-dismissible |
| **skeleton** | loading placeholder | mirrors final layout; pair with `animate-shimmer` |
| **toast** / **sonner** / **toaster** | notifications | use `aria-live`; auto-dismiss + manual dismiss |
| **table** / **card** / **accordion** / **collapsible** | content containers | empty state, expanded/collapsed |
| **avatar** / **progress** / **slider** / **separator** / **scroll-area** / **breadcrumb** / **calendar** / **carousel** / **chart** / **resizable** / **sidebar** | — | per Radix accessible defaults |

## Rules

- **Don't strip Radix accessibility props/roles** when wrapping or restyling (see
  `accessibility.md`).
- **Don't hardcode hex.** Map every color to a token class (`bg-primary`, `text-muted-foreground`,
  `border-border`, `ring-ring`).
- A genuinely new primitive (one not in the list above) is a **design decision** — spec it here
  with its full state matrix before it's built, and add it to `components/ui/`.
