# Branding assets

Drop your organisation's logo in this folder and point `{{LOGO_PATH}}` in
[`../config/branding.md`](../config/branding.md) at it.

- **File:** replace `logo.svg` with your own (`logo.png` recommended for broadest rendering).
- **Referenced by:** `.ai/templates/artifact-header.md`, which every artifact-generating agent
  prepends to the Markdown documents it produces.
- **Path or URL:** `{{LOGO_PATH}}` accepts a repo-relative path (e.g. `.ai/branding/logo.png`)
  or a public `https://` URL.

`logo.svg` here is a placeholder — replace it.
