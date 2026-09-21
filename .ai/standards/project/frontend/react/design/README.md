<!-- STACK REFERENCE — example design system (React frontend). Reference only: the system does NOT
     read this folder. It reads the TEMPLATE at .ai/standards/project/frontend/design/*. These files
     are a fully-worked example (a React + Tailwind app) showing the SHAPE of a filled design
     system. SMEs: replace the example values (palette, tokens, component list) with your own brand's,
     then keep the TEMPLATE design/* files in sync with your real theme file. -->

# Frontend Design Source-of-Truth (example)

The closed design system for the **frontend** scope. Every value here should be **derived from the
real code** — your `tailwind.config.ts` and `styles/globals.css` — and kept in sync with it,
value-for-value. **Never invent or approximate a color/token; copy exact values from those files.**
When the config/styles change, update these files in the same change so they never drift.

## Contents

- **`palette.md`** — every approved color: semantic HSL tokens (light + dark), brand colors, and
  governance RAG tokens, with intended use.
- **`design-tokens.md`** — radius, spacing/container, typography (system font stack), breakpoints,
  and the named animation tokens.
- **`component-specs.md`** — the shadcn/`components/ui/*` base primitives (variants, sizes, required
  states).

## The mandate

UI must use **ONLY** this palette / these tokens — no new colors, no arbitrary hex values. Reference
tokens by semantic role (Tailwind classes → CSS variables), never raw hex. If a design genuinely
needs something the tokens don't express, raise it as a design decision and add the token to
`globals.css`/`tailwind.config.ts` (and to `palette.md`/`design-tokens.md`) first — do not hardcode it.

For *how* to make distinctive, non-templated visual choices within these tokens, see
`.ai/standards/universal/frontend-design.md`.
