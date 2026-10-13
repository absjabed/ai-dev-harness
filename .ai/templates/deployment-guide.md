<!-- Skeleton for the human-facing release deployment guide. Used only when the project has the
     deployment guide switched on (.ai/config/project-config.md → Release deliverables).
     The release agent copies it to docs/release/<version>/deployment-guide-<version>.md, fills it
     from the internal release artifacts plus every in-scope .ai/features/**/deploy-notes.md, and
     removes this comment and the guidance blockquote below — no template instruction survives into
     a real guide. Full method: .ai/agents/release-agent.md → "Deployment guide".
     Not branded with .ai/templates/artifact-header.md: the guide carries its own title and revision
     table, and its Word rendering gets a generated title page.
     Section meanings are fixed; numbers may shift if a project adds or drops a section — deploy
     notes target a section by its meaning (Database, Configuration & infrastructure,
     Application: <unit>, Other deployments), never by number. -->
# <Product> Release <version> — Deployment Guide

> Guidance for the author — replace this blockquote with the guide's own audience note.
> Write for the audience named in project-config.md → Release deliverables, in the tools they
> actually use (cloud console, CI/CD web UI, admin screens). Every step gets a **Verify** sub-step
> saying what to look at. Command lines belong only in the last appendix, as reference. Screenshots
> are committed image files in `docs/release/<version>/img/`, referenced from this Markdown
> (`![alt text](img/step.png)`). **Never paste a secret** — use `<placeholders>`.

## Document revisions

| Date | Version | Description | Author |
|------|---------|-------------|--------|
| <YYYY-MM-DD> | 0.1 | Initial draft | <name> |

## 1. Introduction
- **1.1 Purpose** — what this release deploys and why (from the release notes).
- **1.2 Audience** — who follows this guide and what access they need.
- **1.3 Environments and rollout order** — which environments (and tenants, regions or customers, if
  deployed more than once), in order. Take one target end to end and verify it before the rest.

## 2. Pre-deployment preparation
- **2.1 Prerequisites** — code merged to the release branch; pipeline access and approval rights;
  console access; any build agents, SDKs or credentials ready.
- **2.2 Backups and freeze** — what to back up or snapshot first; any change freeze.

## 3. Database updates
Migrations to run, in order, and when relative to the application deploy — or
"No database migration in this release."

## 4. Configuration & infrastructure
Settings, secrets-store entries, feature flags and infrastructure changes — each with where to set
it, the `<placeholder>` value, and whether it must be in place before or after the deploy.

## 5. Application deployment
One subsection per deployable unit, in deploy order (units listed in project-config.md → Release
deliverables). Mark each *(Required)* or *(Required if changed)*.
- **5.1 <Deployable unit>** — the pipeline run or release steps (point to its appendix) and any
  unit-specific configuration.

## 6. Other deployments  *(as needed)*
Feature-specific steps that fit none of the sections above — in order, per environment, each with a
**Verify** sub-step.

## 7. Verification and sign-off
Post-deploy checks across the whole release (health checks, smoke journeys, logs/monitoring), and
who signs off. Include any release page or status update to publish.

## 8. Rollback
Exact steps to revert each part — previous artifact, previous configuration values, database
down-migration or restore — in reverse deploy order.

## 9. Environment matrix (tick as it rolls out)

| Environment / target | <Unit 1> | <Unit 2> | Database | Verified |
|----------------------|:---:|:---:|:---:|:---:|
| <environment> | ☐ | ☐ | ☐ | ☐ |

## Appendices — step-by-step
- **Appendix A — <Deployable unit> deployment** (e.g. CI: Run pipeline → select branch → Run → Approve).
- **Appendix B … —** further units, and any feature-specific pipelines or console steps.
- **Appendix (last) — command-line equivalents** (reference only), linking the relevant runbook(s).
