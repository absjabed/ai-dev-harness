<!-- TEMPLATE FILE — replace {{TOKENS}} and [FILL IN] blocks. See .ai/CUSTOMIZATION.md or run /init-project. -->
# Branding

Controls the branded header that every artifact-generating agent prepends to the Markdown
documents it produces — requirement specs, user stories, test specs, technical specs, and
review / security / release reports. Not prepended to the unbranded internal files
(`STATE.md`, `deploy-notes.md`) or to the deployment guide under `docs/release/`, which has its own
title, and whose Word copy takes the company name and primary colour from here. The header
template lives at
`.ai/templates/artifact-header.md`; this file supplies its values.

## Values

| Token | Value | Notes |
|-------|-------|-------|
| `{{COMPANY_NAME}}` | > [FILL IN: e.g. "Acme Corp"] | Logo alt-text and byline |
| `{{PROJECT_NAME}}` | > [FILL IN: product/repo name] | Byline |
| `{{LOGO_PATH}}` | `/.ai/branding/logo.svg` | **Root-relative** path (leading slash) **or** a public https URL. The leading slash matters: artifacts are written at varying depths under `.ai/features/<slug>/`, so a path relative to the file itself breaks. Drop your logo at `.ai/branding/` and point here. Leave blank to omit the logo. |
| `{{PRIMARY_COLOR}}` | > [FILL IN: hex, e.g. #2D6CDF] | Optional accent for HTML/PDF exports |
| `{{FOOTER_TEXT}}` | > [FILL IN: e.g. "© {{COMPANY_NAME}} — Confidential"] | Footer line under the byline |

## Notes

- Markdown renders `![alt](path)` in GitHub, GitLab, and MkDocs. PNG is the most portable
  format; SVG renders in MkDocs and locally (GitHub may sanitize inline SVG in some views).
- These values are text/branding only. Behavioral toggles (type-check, lint, protected
  branches, design-token checks) live in `.claude/hooks/hooks.env`.
- `/init-project` fills this file for you.
