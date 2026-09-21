<!-- TEMPLATE FILE — replace {{TOKENS}} and [FILL IN] blocks. See .ai/CUSTOMIZATION.md or run /init-project. -->
# Branding

Controls the branded header that every artifact-generating agent prepends to the Markdown
documents it produces — requirement specs, user stories, test specs, technical specs, and
review / security / release reports. The header template lives at
`.ai/templates/artifact-header.md`; this file supplies its values.

## Values

| Token | Value | Notes |
|-------|-------|-------|
| `{{COMPANY_NAME}}` | > [FILL IN: e.g. "Acme Corp"] | Logo alt-text and byline |
| `{{PROJECT_NAME}}` | > [FILL IN: product/repo name] | Byline |
| `{{LOGO_PATH}}` | `.ai/branding/logo.svg` | Repo-relative path **or** a public https URL. Drop your logo at `.ai/branding/` and point here. Leave blank to omit the logo. |
| `{{PRIMARY_COLOR}}` | > [FILL IN: hex, e.g. #2D6CDF] | Optional accent for HTML/PDF exports |
| `{{FOOTER_TEXT}}` | > [FILL IN: e.g. "© {{COMPANY_NAME}} — Confidential"] | Footer line under the byline |

## Notes

- Markdown renders `![alt](path)` in GitHub, GitLab, and MkDocs. PNG is the most portable
  format; SVG renders in MkDocs and locally (GitHub may sanitize inline SVG in some views).
- These values are text/branding only. Behavioral toggles (type-check, lint, protected
  branches, design-token checks) live in `.claude/hooks/hooks.env`.
- `/init-project` fills this file for you.
