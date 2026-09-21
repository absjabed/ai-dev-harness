# Design Tokens — Non-Color

**Source of truth:** `frontend/tailwind.config.ts` + `frontend/styles/globals.css`. Use Tailwind's
scale classes; don't invent sizes.

## Radius

Base `--radius: 0.75rem` (12px). The Tailwind radius scale derives from it:

| Class | Value | Resolves to |
|-------|-------|-------------|
| `rounded-lg` | `var(--radius)` | 12px |
| `rounded-md` | `calc(var(--radius) - 2px)` | 10px |
| `rounded-sm` | `calc(var(--radius) - 4px)` | 8px |

Cards/dialogs use `lg`; inputs/buttons typically `md`; small chips/badges `sm`. Don't hardcode
`border-radius` in px.

## Typography

Single **system font stack** (`theme.extend.fontFamily.sans`), applied to `body` via
`@apply font-sans`:

```
system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto,
"Helvetica Neue", Arial, "Noto Sans", sans-serif,
"Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji"
```

- No custom/imported typefaces — distinctiveness comes from the **scale** (weights, sizes,
  tracking), not new families. See `frontend-design.md`.
- Use Tailwind's type scale (`text-sm` … `text-4xl`) and weights (`font-medium`/`semibold`/`bold`).
  Establish a clear hierarchy: page title → section heading → body → caption.

## Spacing & container

- **Spacing:** Tailwind's default 4px base / 8px step scale (`p-2` = 8px, `gap-4` = 16px, …).
- **Container:** centered, `2rem` padding, capped at `1400px` on `2xl`
  (`theme.container = { center: true, padding: "2rem", screens: { "2xl": "1400px" } }`).

## Breakpoints

Tailwind defaults — design **mobile-first**, enhance upward:

| Prefix | Min width |
|--------|-----------|
| `sm` | 640px |
| `md` | 768px |
| `lg` | 1024px |
| `xl` | 1280px |
| `2xl` | 1400px (overridden by container) |

## Dark mode

Class-based: `darkMode: ["class"]`. Toggling `.dark` on a root element swaps the semantic
channels (see `palette.md`). Build and verify every design in both themes.

## Animation tokens

The project ships a rich named-animation set (`theme.extend.animation`, via `tailwindcss-animate`).
**Reuse these** rather than authoring one-off keyframes; gate decorative ones behind
`prefers-reduced-motion`.

| Class | Timing |
|-------|--------|
| `animate-accordion-down` / `-up` | `0.2s ease-out` |
| `animate-heartbeat` | `1.2s ease-in-out infinite` |
| `animate-heartbeat-soft` | `1.6s ease-in-out infinite` |
| `animate-back-and-forth` | `1.5s ease-in-out infinite` |
| `animate-fade-in-up` | `0.6s ease-out` |
| `animate-fade-in` | `0.8s ease-out` |
| `animate-slide-in-left` / `-right` | `0.6s ease-out` |
| `animate-pulse-glow` | `2s ease-in-out infinite` (orange glow) |
| `animate-code-flow` | `8s ease-in-out infinite` |
| `animate-float` | `8s ease-in-out infinite` |
| `animate-float-slow` | `12s ease-in-out infinite` |
| `animate-glow-pulse` | `4s ease-in-out infinite` |
| `animate-shimmer` | `2s ease-in-out` (skeleton/loading sheen) |
| `animate-path-flow` | `2s ease-out forwards` (SVG stroke) |
| `animate-particle-flow` | `3s linear infinite` |
| `animate-scale-in` | `0.5s cubic-bezier(0.16, 1, 0.3, 1)` |
| `animate-ring-pulse` | `2s ease-in-out infinite` |

## Plugins & safelist

- Plugin: `tailwindcss-animate`.
- A `safelist` in `tailwind.config.ts` preserves a set of governance/annotation utility classes
  (`am-*`, emerald/orange status backgrounds, `box-decoration-break`). Don't remove safelisted
  classes — runtime-generated markup depends on them.
