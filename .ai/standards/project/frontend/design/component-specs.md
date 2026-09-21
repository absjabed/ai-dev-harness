<!-- TEMPLATE FILE — replace {{TOKENS}} and [FILL IN] blocks. See .ai/CUSTOMIZATION.md or run /init-project. -->
# Component Specs — base primitives

> **FRONTEND-ONLY.** Delete the `design/` subtree if the project has no frontend.

The frontend uses **{{COMPONENT_LIBRARY}}** base primitives. **Reuse these before building anything
new.** Style variations extend the existing primitive (via a `cn()`-style class merge + variant
props) — never duplicate or fork a primitive. All values trace to `palette.md` + `design-tokens.md`.

## Available primitives

> [FILL IN: list your actual base primitives here — sync this list from where your reusable UI
> primitives live in the codebase. Replace the placeholder list below.]

```
[FILL IN: e.g. accordion  alert  avatar  badge  button  card  checkbox
 dialog  dropdown  form  input  label  popover  select  switch  table
 tabs  textarea  toast  tooltip  … ]
```

> Before creating a modal, drawer, dropdown, tabs, tooltip, or form control, **check this list
> first** — a primitive almost certainly already exists. (Mirrors the rule in `tech-specific.md`.)

## Required states for every interactive primitive

Each must implement the full state matrix from `ui-ux-standards.md`:
**Default · Hover · Active/pressed · Focus-visible · Disabled · Loading · Error · Empty ·
Selected/current · Read-only** (where applicable).

## Key primitives — at a glance

> [FILL IN: keep this table structure; replace rows with YOUR primitives and their real variants/sizes.
> The rows below are examples — sync variant names and sizes from your component source.]

| Primitive | Variants / sizes | States to honor |
|-----------|------------------|-----------------|
| **button** | `[FILL IN: e.g. default / secondary / outline / ghost / link / destructive]`; sizes `[FILL IN: sm / default / lg / icon]` | hover, active, focus-visible, disabled, loading (spinner + disabled) |
| **input** / **textarea** | default; error styling (e.g. via `aria-invalid`) | focus-visible, disabled, read-only, error |
| **select** / **dropdown** / **command** | menu primitives | open/closed, highlighted item, disabled item, keyboard nav |
| **dialog** / **sheet** / **drawer** | overlay surfaces | open/close focus trap, Esc to close, scroll lock |
| **badge** | `[FILL IN: default / secondary / outline / destructive]` | static; carry text, not color-alone |
| **tabs** / **toggle** | selectable | selected/current, focus-visible, disabled |
| **checkbox** / **radio-group** / **switch** | form controls | checked/unchecked, focus-visible, disabled, error |
| **tooltip** / **hover-card** / **popover** | floating | open on hover/focus, keyboard-dismissible |
| **skeleton** | loading placeholder | mirrors final layout; pair with a shimmer/pulse animation token |
| **toast** / **notifications** | notifications | use `aria-live`; auto-dismiss + manual dismiss |
| **table** / **card** / **accordion** | content containers | empty state, expanded/collapsed |
| `[FILL IN: remaining primitives]` | — | per library's accessible defaults |

## Rules

- **Don't strip {{COMPONENT_LIBRARY}} accessibility props/roles** when wrapping or restyling (see
  `accessibility.md`).
- **Don't hardcode hex.** Map every color to a token class (e.g. `bg-primary`, `text-muted-foreground`,
  `border-border`, `ring-ring` — use your project's token class names).
- A genuinely new primitive (one not in the list above) is a **design decision** — spec it here with
  its full state matrix before it's built, and add it to your shared primitives location.
