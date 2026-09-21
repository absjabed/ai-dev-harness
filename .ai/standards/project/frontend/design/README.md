<!-- TEMPLATE FILE — replace {{TOKENS}} and [FILL IN] blocks. See .ai/CUSTOMIZATION.md or run /init-project. -->
# UI Design Source-of-Truth

> **UI-ONLY.** This entire `design/` subtree describes a closed design system for whatever UI the
> project has. **If the project has no UI at all (headless / API-only), delete the whole `design/`
> directory.**
>
> **It is not limited to an SPA.** If the backend renders its own views (server-side templates), this
> subtree governs that UI too — load it for any UI work in **either** scope, and skip it only for
> non-UI backend work (API, data, migration, background services). If the project has two UI stacks
> (e.g. a legacy server-rendered UI plus an SPA it is being migrated into), describe **both** below
> and say which one new work belongs to.
>
> [FILL IN: which UI stack(s) exist, which is mainline, and the source-of-truth styling files for
> each — e.g. the theme/variable file per stack and where per-screen styles live.]

Every value in these files must be **derived from the real code** — your project's theme/token
source (e.g. {{STYLING_SYSTEM}} theme config and global stylesheet) — and kept in sync with it,
value-for-value. **Never invent or approximate a color/token; copy exact values from those source
files.** When the theme config changes, update these files in the same change so they never drift.

> [FILL IN: name the exact source-of-truth files these tokens are synced from — e.g. your theme
> config file and your global CSS/variables file.]

## Contents

- **`palette.md`** — every approved color: semantic tokens (light + dark themes), brand colors, and
  any status/RAG tokens, with intended use.
- **`design-tokens.md`** — radius, spacing/container, typography, breakpoints, and named animation
  tokens.
- **`component-specs.md`** — the {{COMPONENT_LIBRARY}} base primitives (variants, sizes, required
  states).

## The mandate

UI must use **ONLY** this palette / these tokens — no new colors, no arbitrary hex values. Reference
tokens by semantic role (utility class → token variable), never raw hex. If a design genuinely needs
something the tokens don't express, raise it as a design decision and add the token to your theme
source first (and to `palette.md` / `design-tokens.md`) — do not hardcode it.

Status/RAG-style banding that the server computes must be rendered from the server value, and always
carries a text label or icon — **never colour alone** (accessibility). This holds in every UI stack
the project has.

> [FILL IN: per UI stack, how a change is actually made and shipped — which file to edit, whether a
> compile/build step is required, whether generated CSS is committed, and any file that must never be
> hand-edited. Delete if the single stack above already covers it.]

For *how* to make distinctive, non-templated visual choices within these tokens, see
`.ai/standards/universal/frontend-design.md`.
