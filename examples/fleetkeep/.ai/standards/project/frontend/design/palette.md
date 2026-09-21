# Palette — Approved Colors

> **UI-ONLY.** Delete the `design/` subtree if the project has no UI.

**Source of truth:** `src/Web/src/theme/theme.ts` (the Mantine theme object) and the `:root` block
in `src/Web/src/styles/global.css` (status tokens only). **Copy values verbatim from there; never
invent a color or use a raw hex that isn't in that source.** Reference tokens by semantic role, not
raw hex.

When you need an exact value from the design source (a colour or token) and its MCP (e.g. Figma)
returns null/empty, times out, or won't return it, **STOP and ask the user for the exact value** —
never guess a hex that "looks close"; a near-miss silently causes design mismatches.

**How tokens are consumed.** Mantine generates CSS custom properties from the theme at runtime:
a colour is `var(--mantine-color-<name>-<shade>)`, spacing is `var(--mantine-spacing-md)`, radius is
`var(--mantine-radius-md)`. In TSX, prefer Mantine props (`c="brand.6"`, `bg="gray.0"`) or
`theme.colors.brand[6]`; in CSS Modules, use the custom property. There is no utility-class layer —
FleetKeep has no Tailwind.

## Brand scale (`brand`)

The primary scale, defined in `theme.ts` as `colors.brand` with `primaryShade: { light: 6, dark: 4 }`.

| Shade | Value | Use |
|-------|-------|-----|
| `brand.0` | `#E6F4F1` | Tinted surface, selected table row |
| `brand.1` | `#C2E4DD` | Hover on tinted surface |
| `brand.2` | `#9AD3C8` | Disabled primary fill |
| `brand.3` | `#6FC1B1` | Chart series 2 |
| `brand.4` | `#45AF9B` | **Primary shade in dark mode** |
| `brand.5` | `#26957F` | Hover on primary (dark mode) |
| `brand.6` | `#0B5D51` | **Primary shade in light mode** — primary buttons, active nav, focus ring |
| `brand.7` | `#094E44` | Hover on primary (light mode) |
| `brand.8` | `#073F37` | Active/pressed primary |
| `brand.9` | `#05302A` | Headings on tinted surfaces |

## Semantic tokens (light theme)

| Token | Value | How to reference | Use |
|-------|-------|------------------|-----|
| Body background | `#FFFFFF` | `var(--mantine-color-body)` | App background |
| Primary text | `#0F172A` | `var(--mantine-color-text)` | Primary text |
| Card surface | `#FFFFFF` | `var(--mantine-color-default)` | `Card`, `Paper` surface |
| Text on cards | `#0F172A` | `var(--mantine-color-text)` | Text on cards |
| Popover surface | `#FFFFFF` | `var(--mantine-color-default)` | `Menu`, `Popover`, `Modal` |
| Popover text | `#0F172A` | `var(--mantine-color-text)` | Text in popovers |
| Primary | `#0B5D51` | `var(--mantine-color-brand-6)` | **Primary action** |
| Text on primary | `#F8FAFC` | `var(--mantine-color-white)` | Label on a filled primary button |
| Secondary surface | `#F1F5F9` | `var(--mantine-color-gray-1)` | Secondary/default button, table header |
| Text on secondary | `#0F172A` | `var(--mantine-color-text)` | Label on secondary |
| Muted surface | `#F1F5F9` | `var(--mantine-color-gray-1)` | Empty states, disabled rows |
| Muted text | `#64748B` | `var(--mantine-color-dimmed)` | Captions, helper text, timestamps |
| Accent | `#F2A007` | `var(--mantine-color-amber-5)` | Attention accent — overdue counters, unread markers |
| Text on accent | `#1C1917` | `var(--mantine-color-dark-9)` | Label on an accent fill |
| Destructive | `#B91C1C` | `var(--mantine-color-red-7)` | Danger / delete / immobilised |
| Text on destructive | `#F8FAFC` | `var(--mantine-color-white)` | Label on destructive |
| Border | `#E2E8F0` | `var(--mantine-color-gray-3)` | Card and table borders |
| Input border | `#E2E8F0` | `var(--mantine-color-gray-3)` | Input outline |
| Focus ring | `#0B5D51` | `var(--mantine-color-brand-6)` | `:focus-visible` outline (2px, 2px offset) |

## Semantic tokens (dark theme)

| Token | Value |
|-------|-------|
| Body background | `#0B1120` |
| Primary text | `#E2E8F0` |
| Card / popover surface | `#111C33` |
| Primary | `#14B8A6` (`brand.4` rendered on dark) |
| Secondary / muted surface | `#1E293B` |
| Muted text | `#94A3B8` |
| Accent | `#FBBF24` |
| Destructive | `#F87171` |
| Border / input border | `#334155` |
| Focus ring | `#14B8A6` |

Theme switching is Mantine's: `ColorSchemeScript` sets `data-mantine-color-scheme` on `<html>` from
the OS preference, and `useMantineColorScheme()` lets the user override it (persisted in
`localStorage`). Because every value above is a token, components adapt automatically — which is
exactly why a raw hex is forbidden. **Every design must be verified in both themes** before the
design gate passes.

## Compliance status (RAG) tokens

Defined as `:root` custom properties in `global.css` because they are used by both Mantine
components and CSS Modules. Rule: always render as a **label-bearing pill or chip with an icon —
never colour alone**. Values come from the server (`ComplianceBanding`); the client never recomputes
them.

| Status | Meaning | bg | text | dot |
|--------|---------|----|------|-----|
| Red | Overdue | `#FEE2E2` | `#991B1B` | `#DC2626` |
| Amber | Due within 14 days | `#FEF3C7` | `#92400E` | `#D97706` |
| Green | More than 14 days | `#DCFCE7` | `#166534` | `#16A34A` |

Custom property names: `--fk-status-{red,amber,green}-{bg,text,dot}`.

Defect categories reuse the same three values so the visual language stays consistent: category A →
red, B → amber, C → green, each rendered with its letter and an icon.

## Contrast

All pairs above meet WCAG 2.2 AA (4.5:1 for body text, 3:1 for large text and UI boundaries) in both
themes. Two pairings are deliberately excluded because they fail: `amber-5` (`#F2A007`) with white
text, and `brand.4` (`#45AF9B`) with white text in light mode. Use the dark foreground on amber, and
`brand.6` for any filled surface carrying white text.
