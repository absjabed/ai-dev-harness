<!-- The branded header prepended to EVERY generated Markdown artifact.
     Values come from .ai/config/branding.md. Do not delete; edit branding.md to customize.

     Agents: when you generate an artifact (requirement spec, user story, test spec, tech spec,
     review/security/release report, etc.), emit this block FIRST, substituting:
       - DOC_TITLE  = the artifact's title
       - DOC_TYPE   = e.g. "Requirement Spec", "Test Spec", "Technical Spec"
       - DOC_DATE   = today's date (YYYY-MM-DD)
       - FEATURE    = the feature/epic slug, if applicable
     The logo path is root-relative (leading slash) on purpose: artifacts live at varying depths
     under .ai/features/<slug>/, so a path relative to the file itself would break. If no logo is
     configured in branding.md, omit the image line. -->

![Northwind Systems](/.ai/branding/logo.svg)

# DOC_TITLE

> **FleetKeep** · DOC_TYPE · FEATURE · DOC_DATE
> © Northwind Systems — Confidential

---
