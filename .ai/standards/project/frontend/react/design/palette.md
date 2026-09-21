# Palette — Approved Colors

**Source of truth:** `frontend/tailwind.config.ts` + `frontend/styles/globals.css`. Values copied
verbatim. **Never invent a color or use a raw hex that isn't here.** Semantic tokens are HSL
*channels* consumed as `hsl(var(--token))` (Tailwind class `bg-primary`, `text-muted-foreground`,
etc.). Brand colors are hex (Tailwind class `bg-brand-orange`, `text-brand-blue-dark`, …).

## Semantic tokens (light — `:root`)

| Token | HSL channels | Tailwind class | Use |
|-------|--------------|----------------|-----|
| `--background` | `0 0% 100%` | `bg-background` | App background |
| `--foreground` | `215 25% 27%` | `text-foreground` | Primary text |
| `--card` | `0 0% 100%` | `bg-card` | Card surface |
| `--card-foreground` | `215 25% 27%` | `text-card-foreground` | Text on cards |
| `--popover` | `0 0% 100%` | `bg-popover` | Popover/menu surface |
| `--popover-foreground` | `215 25% 27%` | `text-popover-foreground` | Text in popovers |
| `--primary` | `14 85% 60%` | `bg-primary` / `text-primary` | **Primary action** (brand orange) |
| `--primary-foreground` | `0 0% 100%` | `text-primary-foreground` | Text on primary |
| `--secondary` | `214 60% 25%` | `bg-secondary` | Secondary action (deep blue) |
| `--secondary-foreground` | `0 0% 100%` | `text-secondary-foreground` | Text on secondary |
| `--muted` | `210 20% 98%` | `bg-muted` | Muted surface |
| `--muted-foreground` | `215 25% 40%` | `text-muted-foreground` | Secondary / caption text |
| `--accent` | `210 30% 98%` | `bg-accent` | Hover/selected surface |
| `--accent-foreground` | `215 25% 27%` | `text-accent-foreground` | Text on accent |
| `--destructive` | `0 84.2% 60.2%` | `bg-destructive` | Danger / delete |
| `--destructive-foreground` | `0 0% 100%` | `text-destructive-foreground` | Text on destructive |
| `--border` | `214 32% 91%` | `border-border` | Borders |
| `--input` | `214 32% 91%` | `border-input` | Input borders |
| `--ring` | `14 75% 60%` | `ring-ring` | Focus ring |

## Semantic tokens (dark — `.dark`)

| Token | HSL channels |
|-------|--------------|
| `--background` | `215 30% 12%` |
| `--foreground` | `210 20% 98%` |
| `--card` | `215 30% 16%` |
| `--card-foreground` | `210 20% 98%` |
| `--popover` | `215 30% 16%` |
| `--popover-foreground` | `210 20% 98%` |
| `--primary` | `14 80% 60%` |
| `--primary-foreground` | `0 0% 100%` |
| `--secondary` | `214 50% 45%` |
| `--secondary-foreground` | `0 0% 100%` |
| `--muted` | `215 25% 20%` |
| `--muted-foreground` | `210 20% 80%` |
| `--accent` | `215 25% 22%` |
| `--accent-foreground` | `210 20% 98%` |
| `--destructive` | `0 62.8% 30.6%` |
| `--destructive-foreground` | `210 20% 98%` |
| `--border` | `215 25% 25%` |
| `--input` | `215 25% 25%` |
| `--ring` | `14 70% 55%` |

Dark mode is class-based (`darkMode: ["class"]`) — the `.dark` class on a root element swaps the
channels. Every design must be verified in both.

## Brand colors (hex — `theme.extend.colors.brand`)

| Token | Hex | Tailwind class | Note |
|-------|-----|----------------|------|
| `brand.orange.DEFAULT` | `#fa5c1d` | `bg-brand-orange` | Orange-Red (primary brand) |
| `brand.orange.light` | `#f99b20` | `bg-brand-orange-light` | Orange-Yellow |
| `brand.blue.DEFAULT` | `#1f76a7` | `bg-brand-blue` | Medium Blue |
| `brand.blue.dark` | `#0d3f5b` | `bg-brand-blue-dark` | Dark Blue |
| `brand.gray.DEFAULT` | `#747272` | `bg-brand-gray` | Medium Gray |
| `brand.gray.dark` | `#535150` | `bg-brand-gray-dark` | Dark Gray |

Prefer the **semantic** tokens for UI chrome (they theme automatically). Reach for brand hex only
for explicit brand moments (logos, marketing surfaces, the signature accent).

## Misc surface tokens

| Token | Value | Use |
|-------|-------|-----|
| `--main-header-height` | `52px` | App header height |
| `--footer-bg` | `rgb(2, 23, 46)` | Footer background |

## Governance RAG tokens (Governance page)

Status colors for governance — used as label-bearing pills, **never color-alone**.

| Status | bg | text | dot |
|--------|----|------|-----|
| Red | `--gov-rag-r-bg` `#faece7` | `--gov-rag-r-text` `#993c1d` | `--gov-rag-r-dot` `#d85a30` |
| Amber | `--gov-rag-a-bg` `#faeeda` | `--gov-rag-a-text` `#854f0b` | `--gov-rag-a-dot` `#ba7517` |
| Green | `--gov-rag-g-bg` `#e1f5ee` | `--gov-rag-g-text` `#0f6e56` | `--gov-rag-g-dot` `#1d9e75` |

Additional governance neutrals/pills exist in `globals.css` (`--gov-pill-blue-*`, `--gov-heading`,
`--gov-card-border`, `--gov-table-header-bg`, …). Use them only on governance surfaces; copy exact
values from `globals.css` — do not approximate.
