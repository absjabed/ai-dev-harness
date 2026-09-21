     Values come from .ai/config/branding.md. Do not delete; edit branding.md to customize.

     Agents: when you generate an artifact (requirement spec, user story, test spec, tech spec,
     review/security/release report, etc.), emit this block FIRST, substituting:
       - {{...}} branding tokens from .ai/config/branding.md
       - DOC_TITLE  = the artifact's title
       - DOC_TYPE   = e.g. "Requirement Spec", "Test Spec", "Technical Spec"
       - DOC_DATE   = today's date (YYYY-MM-DD)
       - FEATURE    = the feature/epic slug, if applicable
     If .ai/branding/logo.svg is unset, omit the image line. -->

![Northwind Systems](.ai/branding/logo.svg)

# DOC_TITLE

> **FleetKeep** · DOC_TYPE · FEATURE · DOC_DATE
> © Northwind Systems — Confidential

---
