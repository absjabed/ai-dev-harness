<!-- TEMPLATE FILE — this is the branded header prepended to EVERY generated Markdown artifact.
     Values come from .ai/config/branding.md. Do not delete; edit branding.md to customize.

     Agents: when you generate an artifact (requirement spec, user story, test spec, tech spec,
     review/security/release report, etc.), emit this block FIRST, substituting:
       - {{...}} branding tokens from .ai/config/branding.md
       - DOC_TITLE  = the artifact's title
       - DOC_TYPE   = e.g. "Requirement Spec", "Test Spec", "Technical Spec"
       - DOC_DATE   = today's date (YYYY-MM-DD)
       - FEATURE    = the feature/epic slug, if applicable
     {{LOGO_PATH}} must be root-relative (leading slash) or an https URL: artifacts live at
     varying depths under .ai/features/<slug>/, so a path relative to the file itself breaks.
     If {{LOGO_PATH}} is unset, omit the image line. -->

![{{COMPANY_NAME}}]({{LOGO_PATH}})

# DOC_TITLE

> **{{PROJECT_NAME}}** · DOC_TYPE · FEATURE · DOC_DATE
> {{FOOTER_TEXT}}

---
