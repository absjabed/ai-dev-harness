# UI Design Source-of-Truth

> **UI-ONLY.** This entire `design/` subtree describes a closed design system for whatever UI the
> project has.
>
> **FleetKeep has exactly one UI stack:** the React 18 + Vite 5 SPA in `src/Web`, built on
> **Mantine v7** with CSS Modules. The API renders no views and serves no HTML, so there is no
> server-rendered surface to design for — a backend task touches this subtree only if it changes
> what the SPA displays. There is no legacy stack and no migration in progress.
>
> Source-of-truth styling files:
> - `src/Web/src/theme/theme.ts` — the Mantine theme object: `brand` colour scale, radius, spacing,
>   fonts, breakpoints, and per-component defaults. **Everything in this subtree is mirrored from here.**
> - `src/Web/src/styles/global.css` — the three keyframe animations and the `:root` status-token
>   custom properties.
> - `src/Web/src/features/<feature>/*.module.css` — per-screen styles; they consume tokens, they
>   never define new ones.

Every value in these files must be **derived from the real code** — the Mantine theme object and the
global stylesheet — and kept in sync with it, value-for-value. **Never invent or approximate a
color/token; copy exact values from those source files.** When `theme.ts` changes, update these
files in the same change so they never drift.

## Contents

- **`palette.md`** — every approved color: semantic Mantine tokens (light + dark), the brand scale,
  and the compliance RAG tokens, with intended use.
- **`design-tokens.md`** — radius, spacing, typography, breakpoints, shadows and the named
  animation tokens.
- **`component-specs.md`** — the Mantine v7 base primitives in use (variants, sizes, required
  states) and the small set of project components built on top.

## The mandate

UI must use **ONLY** this palette / these tokens — no new colors, no arbitrary hex values. Reference
tokens by semantic role (`var(--mantine-color-brand-6)`, `theme.radius.md`), never raw hex. If a
design genuinely needs something the tokens don't express, raise it as a design decision and add the
token to `theme.ts` first (and to `palette.md` / `design-tokens.md`) — do not hardcode it.

Status/RAG-style banding that the server computes must be rendered from the server value, and always
carries a text label or icon — **never colour alone** (accessibility). In FleetKeep this is the
compliance banding on the dashboard and the defect category chips; both ship colour + text + icon.

**How a change is made and shipped:** edit `src/Web/src/theme/theme.ts` (or `global.css` for
keyframes and the status custom properties), update the matching table in this subtree in the same
commit, and run `npm run build`. There is no separate CSS build step and no generated CSS committed
to the repo — Vite compiles CSS Modules at build time. Never edit anything under
`src/Web/dist/`, and never introduce a second theming mechanism (no Tailwind, no styled-components)
alongside Mantine.

For *how* to make distinctive, non-templated visual choices within these tokens, see
`.ai/standards/universal/frontend-design.md`.
