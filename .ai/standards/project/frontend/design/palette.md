<!-- TEMPLATE FILE — replace {{TOKENS}} and [FILL IN] blocks. See .ai/CUSTOMIZATION.md or run /init-project. -->
# Palette — Approved Colors

> **FRONTEND-ONLY.** Delete the `design/` subtree if the project has no frontend.

**Source of truth:** your project's theme source (e.g. {{STYLING_SYSTEM}} theme config + global
stylesheet). **Copy values verbatim from there; never invent a color or use a raw hex that isn't in
that source.** Reference tokens by semantic role (utility class → token variable), not raw hex.
**Every value below is a placeholder — sync from your actual theme config.**

When you need an exact value from the design source (a colour or token) and its MCP (e.g. Figma)
returns null/empty, times out, or won't return it, **STOP and ask the user for the exact value** —
never guess a hex that "looks close"; a near-miss silently causes design mismatches.

> [FILL IN: name the exact source-of-truth files, and note how tokens are consumed — e.g. HSL channels
> via `hsl(var(--token))`, or hex, and the utility-class prefix (`bg-*`, `text-*`, `border-*`, …).]

## Semantic tokens (light theme)

> [FILL IN: keep this table structure; sync token names, values, class names, and uses from your theme.
> Rows below are the canonical semantic roles most design systems have — replace the placeholder
> values.]

| Token | Value | Utility class | Use |
|-------|-------|---------------|-----|
| `--background` | `{{COLOR_BACKGROUND}}` | `bg-background` | App background |
| `--foreground` | `{{COLOR_FOREGROUND}}` | `text-foreground` | Primary text |
| `--card` | `{{COLOR_CARD}}` | `bg-card` | Card surface |
| `--card-foreground` | `{{COLOR_CARD_FOREGROUND}}` | `text-card-foreground` | Text on cards |
| `--popover` | `{{COLOR_POPOVER}}` | `bg-popover` | Popover/menu surface |
| `--popover-foreground` | `{{COLOR_POPOVER_FOREGROUND}}` | `text-popover-foreground` | Text in popovers |
| `--primary` | `{{PRIMARY_COLOR}}` | `bg-primary` / `text-primary` | **Primary action** |
| `--primary-foreground` | `{{COLOR_PRIMARY_FOREGROUND}}` | `text-primary-foreground` | Text on primary |
| `--secondary` | `{{COLOR_SECONDARY}}` | `bg-secondary` | Secondary action |
| `--secondary-foreground` | `{{COLOR_SECONDARY_FOREGROUND}}` | `text-secondary-foreground` | Text on secondary |
| `--muted` | `{{COLOR_MUTED}}` | `bg-muted` | Muted surface |
| `--muted-foreground` | `{{COLOR_MUTED_FOREGROUND}}` | `text-muted-foreground` | Secondary / caption text |
| `--accent` | `{{COLOR_ACCENT}}` | `bg-accent` | Hover/selected surface |
| `--accent-foreground` | `{{COLOR_ACCENT_FOREGROUND}}` | `text-accent-foreground` | Text on accent |
| `--destructive` | `{{COLOR_DESTRUCTIVE}}` | `bg-destructive` | Danger / delete |
| `--destructive-foreground` | `{{COLOR_DESTRUCTIVE_FOREGROUND}}` | `text-destructive-foreground` | Text on destructive |
| `--border` | `{{COLOR_BORDER}}` | `border-border` | Borders |
| `--input` | `{{COLOR_INPUT}}` | `border-input` | Input borders |
| `--ring` | `{{COLOR_RING}}` | `ring-ring` | Focus ring |

## Semantic tokens (dark theme)

> [FILL IN: dark-theme values for the same tokens. Delete this section if the project has no dark mode.]

| Token | Value |
|-------|-------|
| `--background` | `{{COLOR_BACKGROUND_DARK}}` |
| `--foreground` | `{{COLOR_FOREGROUND_DARK}}` |
| `--primary` | `{{PRIMARY_COLOR_DARK}}` |
| `--secondary` | `{{COLOR_SECONDARY_DARK}}` |
| `--muted` | `{{COLOR_MUTED_DARK}}` |
| `--accent` | `{{COLOR_ACCENT_DARK}}` |
| `--destructive` | `{{COLOR_DESTRUCTIVE_DARK}}` |
| `--border` | `{{COLOR_BORDER_DARK}}` |
| `--ring` | `{{COLOR_RING_DARK}}` |
| `[FILL IN: remaining tokens]` | `[FILL IN]` |

> [FILL IN: how theme switching works — e.g. class-based `.dark` on a root element swaps channels.
> Every design must be verified in both themes.]

## Brand colors

> [FILL IN: your explicit brand colors (usually hex). Prefer the **semantic** tokens above for UI
> chrome (they theme automatically); reach for brand hex only for explicit brand moments (logos,
> marketing surfaces, the signature accent). Replace the placeholder rows. Delete if you have no
> separate brand palette.]

| Token | Value | Utility class | Note |
|-------|-------|---------------|------|
| `brand.primary` | `{{BRAND_COLOR_PRIMARY}}` | `bg-brand-primary` | Primary brand color |
| `brand.secondary` | `{{BRAND_COLOR_SECONDARY}}` | `bg-brand-secondary` | Secondary brand color |
| `[FILL IN]` | `[FILL IN]` | `[FILL IN]` | `[FILL IN]` |

## Misc surface tokens

> [FILL IN: any one-off layout/surface tokens (header height, footer bg, etc.). Delete if none.]

| Token | Value | Use |
|-------|-------|-----|
| `[FILL IN]` | `[FILL IN]` | `[FILL IN]` |

## Status / RAG tokens (optional)

> [FILL IN: status color sets (e.g. red/amber/green) if your app uses them. Rule: use as
> label-bearing pills, **never color-alone** (accessibility). Sync exact values from your stylesheet.
> Delete this section if you have no status color system.]

| Status | bg | text | dot |
|--------|----|------|-----|
| Red | `{{STATUS_RED_BG}}` | `{{STATUS_RED_TEXT}}` | `{{STATUS_RED_DOT}}` |
| Amber | `{{STATUS_AMBER_BG}}` | `{{STATUS_AMBER_TEXT}}` | `{{STATUS_AMBER_DOT}}` |
| Green | `{{STATUS_GREEN_BG}}` | `{{STATUS_GREEN_TEXT}}` | `{{STATUS_GREEN_DOT}}` |
