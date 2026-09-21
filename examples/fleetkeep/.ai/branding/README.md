# Branding assets

Drop your organisation's logo in this folder and point `.ai/branding/logo.svg` in
[`../config/branding.md`](../config/branding.md) at it.

- **File:** replace `logo.svg` with your own (`logo.png` recommended for broadest rendering).
- **Referenced by:** `.ai/templates/artifact-header.md`, which every artifact-generating agent
  prepends to the Markdown documents it produces.
- **Path or URL:** `.ai/branding/logo.svg` accepts a repo-relative path (e.g. `.ai/branding/logo.png`)
  or a public `https://` URL.

`logo.svg` here is the FleetKeep lockup (Northwind Systems vendor brand + product name) in the
brand teal `#0B5D51` with the `#F2A007` accent. Keep any replacement to 220x64 so the artifact
header stays aligned.
