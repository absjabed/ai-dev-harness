# Workflow: Release Process

1. **Generate the changelog** from commits since the last release/tag (`git log <lastTag>..HEAD`),
   grouped by {{COMMIT_CONVENTION}} type. If the history isn't conventional (e.g. provider-generated
   merge subjects), group by tracker ticket (`{{TICKET_PREFIX}}-####`) / merged {{PR_TERM}} instead.
2. **Verify** on the release branch — run each changed scope's gates: build always (`{{BUILD_CMD}}`
   per scope); plus lint/type-check/test where the scope defines them. Where a scope has no test
   runner, verification is build + manual/driven smoke checks of the key journeys.
3. **Check dependencies & secrets** for unresolved security warnings; address or document them.
   Never commit a secret — flag any committed ones for rotation to {{CLOUD_PROVIDER}}'s config /
   secret store.
4. **Bump the version** in the project's version manifest(s), semver-style (fix → patch, feat →
   minor, breaking → major) — see the release/DevOps standards for where each scope's version lives.
5. **Update `CHANGELOG.md`** (Keep a Changelog format: Added / Changed / Fixed / Security / Removed).
6. **Tag the release.**
7. **Prepare the internal release artifacts** — release notes (highlights, breaking changes),
   migration steps (DB schema changes ship via the schema owner's migration process; mirror any
   shared column change into the other models), the rollback plan and the deployment checklist,
   written to `.ai/releases/<version>/`. Feed them from every `.ai/features/**/deploy-notes.md`
   whose **fix version** matches this release — each feature, bugfix and hotfix recorded its deploy impact
   there while it was fresh.
8. **Publish the deployment guide** *(only if switched on in `project-config.md` → Release
   deliverables)* — the human-facing deliverable, produced after the internal artifacts exist
   (and, under `/workflows:release`, only after its confirmation gate). It is a **separate,
   on-request step**: an agent asked only for the internal artifacts stops at step 7 and writes
   nothing under `docs/release/`.
   1. create-or-**merge** `docs/release/<version>/deployment-guide-<version>.md` from
      `.ai/templates/deployment-guide.md`, filled from the internal artifacts plus every in-scope
      deploy note, placing each in the guide section it names — except a note marked
      **Deploy impact: no**, which contributes nothing. An update merges into the hand-maintained
      guide, never clobbers it; if it cannot merge cleanly, **STOP** and show the user.
   2. if the Word copy is on, regenerate it with `.claude/scripts/md-to-docx.py`. The Markdown is
      the single source of truth — the `.docx` is never hand-edited — and the converter's warnings
      are relayed to the user.
   3. refresh the release's row in the `## Guides` index of `docs/release/README.md`.

   Full method (version resolution, section mapping, merge rules, missing Python dependencies):
   `.ai/agents/release-agent.md` → *Deployment guide*.

When orchestrated by the release command, the security/dependency check (step 3) and the changelog/
release-notes generation (steps 1, 7) can run in parallel since they operate on independent data.
Step 8 consumes step 7's artifacts, so when it runs, it runs after them — never in parallel. Under
`/workflows:release` the guide is committed with the version bump, before the tag (step 6).

Coordinate the actual deploy with the DevOps agent (`.ai/agents/devops-agent.md`) and its checklist —
`{{DEFAULT_BRANCH}}` = production, across {{DEPLOY_STAGES}}. Note any per-tenant split
({{TENANT_ISOLATION_RULE}}).
