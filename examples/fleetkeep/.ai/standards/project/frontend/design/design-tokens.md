# Design Tokens — Non-Color

> **UI-ONLY.** Delete the `design/` subtree if the project has no UI.

**Source of truth:** `src/Web/src/theme/theme.ts` (Mantine theme object) and
`src/Web/src/styles/global.css` (keyframes). Use the scale tokens; don't invent sizes. Every value
below is synced from those two files.

## Radius

Mantine's `defaultRadius` is `md`. The scale in `theme.ts`:

| Token | Value | Reference as |
|-------|-------|--------------|
| `xs` | `2px` | `var(--mantine-radius-xs)` |
| `sm` | `4px` | `var(--mantine-radius-sm)` |
| `md` | `8px` | `var(--mantine-radius-md)` |
| `lg` | `12px` | `var(--mantine-radius-lg)` |
| `xl` | `16px` | `var(--mantine-radius-xl)` |

Usage: `Card`, `Paper`, `Modal` → `lg`. Buttons, inputs, selects → `md` (the default, so it needs no
prop). Badges, chips, status pills → `sm`. Avatars and the depot switcher → `xl`. Never write
`border-radius` in px in a CSS Module.

## Typography

```
'Inter', -apple-system, 'Segoe UI', Roboto, sans-serif
```

Inter is self-hosted (`@fontsource/inter`, weights 400/500/600/700) so depot tablets on poor
connections don't wait on a font CDN. Monospace (`ui-monospace, 'Cascadia Mono', monospace`) is used
only for vehicle registrations and trace ids.

**No additional typefaces.** Distinctiveness comes from the scale — weight, size and tracking — not
from new families. See `frontend-design.md`.

| Role | Token | Size / line-height | Weight |
|------|-------|--------------------|--------|
| Page title | `h1` | `2rem` / `1.2` | 700 |
| Section heading | `h2` | `1.5rem` / `1.3` | 600 |
| Card heading | `h3` | `1.125rem` / `1.4` | 600 |
| Body | `md` | `1rem` / `1.55` | 400 |
| Secondary body | `sm` | `0.875rem` / `1.5` | 400 |
| Caption / helper | `xs` | `0.75rem` / `1.45` | 400, `dimmed` |
| Table numerics | `sm` | `0.875rem` / `1.5` | 500, tabular-nums |

Hierarchy on every screen: page title → section heading → body → caption. Due dates and counts use
`font-variant-numeric: tabular-nums` so columns align.

## Spacing & container

- **Spacing:** Mantine's scale, 4px-based — `xs 10px`, `sm 12px`, `md 16px`, `lg 20px`, `xl 32px`,
  referenced as `var(--mantine-spacing-md)` or the `p`/`m`/`gap` props. Page gutters are `md` on
  mobile and `xl` from `md` upward.
- **Container:** `AppShell` with a fixed 260px navbar (collapsible to icons below `lg`) and a 60px
  header. Content is centred with `max-width: 1440px`; the compliance dashboard and the vehicle
  register opt out (`fluid`) because their tables benefit from the full width.

## Breakpoints

Mantine's defaults, unchanged. Design **mobile-first** — the walkaround check is used one-handed on
a phone in a depot.

| Token | Min width |
|-------|-----------|
| `xs` | `36em / 576px` |
| `sm` | `48em / 768px` |
| `md` | `62em / 992px` |
| `lg` | `75em / 1200px` |
| `xl` | `88em / 1408px` |

Reference in CSS Modules as `@media (min-width: $mantine-breakpoint-sm)`; never hardcode a px width.

## Dark mode

Mantine's `data-mantine-color-scheme` attribute on `<html>`, set by `ColorSchemeScript` from the OS
preference and overridable by the user (persisted in `localStorage`). There is no `.dark` class and
no media-query-only path. Because components use tokens, both schemes come free — which is why a raw
hex is a bug, not a style preference. Build and verify every design in both themes.

## Shadows

| Token | Use |
|-------|-----|
| `xs` | Table header on scroll |
| `sm` | `Card`, `Paper` at rest |
| `md` | `Menu`, `Popover`, `Tooltip` |
| `lg` | `Modal`, `Drawer` |

Nothing above `lg`. Elevation signals layering, not importance.

## Animation tokens

Defined as keyframes in `global.css`. **Reuse these** rather than authoring one-off keyframes.

| Class | Timing | Use |
|-------|--------|-----|
| `fk-fade-in` | `150ms ease-out` | Content appearing after a query resolves |
| `fk-slide-up` | `200ms cubic-bezier(0.4, 0, 0.2, 1)` | Drawers, the mobile defect sheet |
| `fk-pulse-overdue` | `1.6s ease-in-out infinite` | The overdue count badge in the header only |

All three sit inside `@media (prefers-reduced-motion: no-preference)`. `fk-pulse-overdue` is the one
decorative, attention-seeking animation in the product — do not add a second. Mantine's own
transitions (`Modal`, `Menu`) are left at their defaults.

## Plugins & safelist

No PostCSS plugins beyond `postcss-preset-mantine` and `postcss-simple-vars` (which supplies the
`$mantine-breakpoint-*` variables). Nothing is runtime-class-generated, so there is no safelist to
preserve — a class not referenced in source is genuinely dead and can be deleted.
