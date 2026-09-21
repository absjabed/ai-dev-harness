<!-- TEMPLATE FILE — replace {{TOKENS}} and [FILL IN] blocks. See .ai/CUSTOMIZATION.md or run /init-project. -->
# Design Tokens — Non-Color

> **FRONTEND-ONLY.** Delete the `design/` subtree if the project has no frontend.

**Source of truth:** your project's theme source (e.g. {{STYLING_SYSTEM}} theme config + global
stylesheet). Use your scale classes/tokens; don't invent sizes. **Sync every value below from that
source — the values shown are placeholders.**

> [FILL IN: name the exact theme/config files these tokens are synced from.]

## Radius

Base `--radius: {{RADIUS_BASE}}`. The radius scale derives from it:

| Class | Value | Resolves to |
|-------|-------|-------------|
| `rounded-lg` | `var(--radius)` | `{{RADIUS_LG}}` |
| `rounded-md` | `calc(var(--radius) - 2px)` | `{{RADIUS_MD}}` |
| `rounded-sm` | `calc(var(--radius) - 4px)` | `{{RADIUS_SM}}` |

> [FILL IN: which radius each element class uses — e.g. cards/dialogs `lg`, inputs/buttons `md`, chips
> `sm`. Don't hardcode `border-radius` in px.]

## Typography

> [FILL IN: your font stack(s). If you use a system stack, paste it verbatim; if you use custom
> typefaces, list them and how they're loaded.]

```
{{FONT_FAMILY_SANS}}
```

- [FILL IN: whether custom typefaces are allowed. If not, note that distinctiveness comes from the
  **scale** (weights, sizes, tracking), not new families. See `frontend-design.md`.]
- Use your type scale (e.g. `text-sm` … `text-4xl`) and weights. Establish a clear hierarchy:
  page title → section heading → body → caption.

## Spacing & container

- **Spacing:** [FILL IN: your spacing scale — e.g. a 4px base / 8px step scale.]
- **Container:** [FILL IN: container behavior — centered?, padding, max width / cap at which
  breakpoint.]

## Breakpoints

> [FILL IN: your breakpoints. Design **mobile-first**, enhance upward. Replace the placeholder rows.]

| Prefix | Min width |
|--------|-----------|
| `sm` | `{{BP_SM}}` |
| `md` | `{{BP_MD}}` |
| `lg` | `{{BP_LG}}` |
| `xl` | `{{BP_XL}}` |
| `2xl` | `{{BP_2XL}}` |

## Dark mode

> [FILL IN: your dark-mode strategy — e.g. class-based (`.dark` on a root element swaps semantic
> channels) vs. media-query, and where it's configured. Build and verify every design in both themes.
> Delete this section if the project has no dark mode.]

## Animation tokens

> [FILL IN: your named animation set — sync from the theme config. **Reuse these** rather than
> authoring one-off keyframes; gate decorative ones behind `prefers-reduced-motion`. Replace the
> placeholder rows below.]

| Class | Timing |
|-------|--------|
| `{{ANIMATION_CLASS_1}}` | `{{ANIMATION_TIMING_1}}` |
| `{{ANIMATION_CLASS_2}}` | `{{ANIMATION_TIMING_2}}` |
| `{{ANIMATION_CLASS_3}}` | `{{ANIMATION_TIMING_3}}` |

## Plugins & safelist

> [FILL IN: any styling plugins in use, and any safelisted/always-preserved utility classes that
> runtime-generated markup depends on (so contributors don't remove them). Delete if not applicable.]
