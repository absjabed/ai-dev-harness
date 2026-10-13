# Branding

Controls the branded header that every artifact-generating agent prepends to the Markdown
documents it produces — requirement specs, user stories, test specs, technical specs, and
review / security / release reports. Not prepended to the unbranded internal files
(`STATE.md`, `deploy-notes.md`) or to the deployment guide under `docs/release/`, which has its own
title, and whose Word copy takes the company name and primary colour from here. The header
template lives at
`.ai/templates/artifact-header.md`; this file supplies its values.

## Values

| Setting | Value |
|---------|-------|
| Company name | **Northwind Systems** |
| Product name | **FleetKeep** |
| Logo | `/.ai/branding/logo.svg` — the FleetKeep lockup. **Leading slash matters:** artifacts live at varying depths under `.ai/features/<slug>/`, so the path must be root-relative or the image breaks |
| Primary color | `#0B5D51` (FleetKeep deep teal — matches the Mantine `brand` scale in `src/Web/src/theme/theme.ts`) |
| Footer | `© Northwind Systems — Confidential` |

## Notes

- Artifacts carry **both** the vendor brand (Northwind Systems) and the product name (FleetKeep),
  because FleetKeep artifacts are shared with tenant stakeholders during UAT.
- Markdown renders `![alt](path)` in GitHub, GitLab, and MkDocs. PNG is the most portable
  format; SVG renders in MkDocs and locally (GitHub may sanitize inline SVG in some views).
- These values are text/branding only. Behavioral toggles (type-check, lint, protected
  branches, design-token checks) live in `.claude/hooks/hooks.env`.
- To change branding, edit this file and `.ai/templates/artifact-header.md`.
