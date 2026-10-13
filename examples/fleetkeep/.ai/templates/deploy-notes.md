<!-- Internal working input — NOT a deliverable. Written by /workflows:feature (command step 5a
     "Document & deploy notes" = playbook step 7 "Document" in feature-development.md) or
     /workflows:hotfix (playbook step 4a, "Deploy notes") to .ai/features/<slug>/deploy-notes.md,
     while the deploy knowledge is still fresh. The release path reads every note carrying a given
     fix version: it always feeds the internal migration plan, rollback plan and deployment
     checklist, and — when the project has the deployment guide switched on (project-config.md →
     Release deliverables) — the human-facing guide docs/release/<version>/deployment-guide-<version>.md.
     Unbranded — same convention as .ai/templates/feature-state.md: do NOT prepend the branded
     header from .ai/templates/artifact-header.md and do not polish it for presentation. The release
     assembler rewrites this material in the guide's voice.
     One file per feature. For an epic, one per sub-feature at
     .ai/features/<epic>/<sub-feature>/deploy-notes.md, written inside that sub-feature's worktree
     so it commits on the sub-feature branch. -->
# Deploy Notes: [feature-or-hotfix slug]

> **Never paste a secret** — no connection strings, keys, passwords, tokens, or personal data. Use
> `<placeholders>` and name the setting / secret-store entry the real value belongs in. This file
> is committed to the repo.

- **Slug:** [the `.ai/features/<slug>/` folder name — for a hotfix, the branch slug, e.g.
  `fix/PROJ-1234-slug` → `PROJ-1234-slug`]
- **Ticket:** [issue key, or `none`]
- **Fix version:** [copy verbatim from **Fix version** in the sibling `requirement-spec.md`
  "Source issue" block, e.g. `1.4`. If it reads `unknown — to be confirmed`, or the field (or the
  spec itself — hotfixes often have none) is absent, write `unknown — to be confirmed`.
  **Never guess a version:** a wrong one files this change into the wrong release.]
- **Captured:** [YYYY-MM-DD] · by [/workflows:feature | /workflows:hotfix]
- **Deploy impact:** [yes | no]
- **Guide target section:** [Database | Configuration & infrastructure | Application: <deployable
  unit> | Other deployments] — which section of `.ai/templates/deployment-guide.md` this change
  belongs in; deployable-unit names come from project-config.md → Release deliverables. Name more
  than one only if it genuinely spans them, most specific first.
- **Appendix needed:** [no | yes — <the click-through an engineer needs, e.g. "run the infra
  pipeline with the new region parameter">]

<!-- Fill every section below that applies; replace the body of the rest with `None.` — an empty
     section reads as "not captured yet", which is exactly the ambiguity this file exists to remove.
     If Deploy impact = no, keep only the "No deploy impact" section and delete the others. -->

## No deploy impact

<!-- Keep this section ONLY when Deploy impact = no; then delete every section below it. Saying it
     explicitly is load-bearing: release assembly must be able to tell "nothing to do" from
     "never captured". -->

**No deploy impact** — ships with the standard pipeline run for this release: no setting change, no
migration, no scripts to run, no manual steps, no per-tenant or per-environment sequencing. [One line
of why, e.g. "presentation-only change inside an existing page; no config or schema surface."]

## App settings / configuration

<!-- Environment variables, app settings, config files, feature flags, and any settings stored as
     data. Copy key names verbatim — including any that are misspelled in the code. -->

| App / resource | Setting key | New or changed | Value | Required? |
|---|---|---|---|---|
| [deployable unit or resource] | [`ExactKeyName`] | [new \| changed] | `<placeholder>` | [required — <what breaks without it> \| optional — defaults to <x>] |

- **Set before or after the deploy:** [before — the app reads it at startup | after | either]
- **Holds a secret:** [no | yes — `<KeyName>`; set it in the secret store, never in a committed file]

## Database

<!-- Name migrations exactly as generated. If the schema is mapped in more than one place (a second
     service, a second ORM), say whether the change was mirrored there. -->

- **Migration(s):** [`<MigrationName>`, in apply order | none]
- **Additive or destructive:** [additive — safe while the previous app version still serves traffic |
  destructive — <what is dropped/renamed/narrowed/made NOT NULL>, and what breaks if the old app is still live]
- **Mirrored into other models:** [n/a | <where> — done]
- **Order vs the app deploy:** [DB first (default) | app first — <why>]
- **Data backfill:** [none | <what it does, roughly how long, whether it is safe to re-run>]

## Scripts an engineer must run

<!-- Anything a human runs by hand outside the normal migration step. Give the repo path so the
     release assembler can snapshot it next to the guide, and say where it sits in the deploy order. -->

| Script (repo path) | Run when | Run against | Safe to re-run? | Notes |
|---|---|---|---|---|
| [`scripts/<file>`] | [before the migration \| after the app deploy \| …] | [which database / environment] | [yes \| no — <why>] | [what it changes; expected results] |

## Manual console steps

<!-- Steps done by hand in a cloud console, admin UI, or CI web UI. Give real screen names and click
     paths; command-line equivalents belong in the guide's last appendix, not here as the primary
     instruction. -->

1. [Console → <resource> → <screen> → <action>] — [why, and what you should see afterwards]

## Pipeline / stage changes

- **Pipeline(s) touched:** [path(s) to the pipeline definition(s) | none]
- **New or changed stages / variables / parameters:** [...]
- **Approvals, credentials, agent or SDK requirements:** [...]
- **Run order:** [e.g. infra pipeline first, then the app pipeline | unchanged]

## Per-tenant / per-environment notes

<!-- Only if the product is deployed more than once (per tenant, region or customer) or rolls out in
     stages. Delete the body and write `None.` if it is a single deployment. -->

- **Affected:** [all | <list>]
- **Order:** [<which goes first, and why> | any]
- **Differences:** [none | <tenant/environment> needs <what> — e.g. a different setting value]

## Verify (after deploy)

<!-- Checks a deployment engineer can make without a debugger: a console reading, a page that must
     render, a log entry, a health endpoint, a row count. -->

- [ ] [what to do] → expected: [the observable result]

## Rollback

<!-- How to undo THIS change's deploy actions specifically; the release rollback plan aggregates them. -->

- [step — e.g. redeploy the previous artifact / set `<Key>` back to `<previous placeholder>` /
  revert the schema with the down-migration to `<PriorMigration>`]
- **Irreversible parts:** [none | <what, why, and the compensating action>]

## Screenshots needed

<!-- Only when the deployment guide is on. Images are committed files a HUMAN captures and adds under
     `docs/release/<version>/img/`, referenced as `![alt](img/<name>.png)`; no agent can produce
     them. Flag exactly what is needed so the release assembler can ask for it. -->

- [ ] [what to capture, and where in the guide it goes] → suggested file: `img/<name>.png`
