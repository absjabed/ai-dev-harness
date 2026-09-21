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
7. **Prepare release notes** — highlights, breaking changes, migration steps (DB schema changes ship
   via the schema owner's migration process; mirror any shared column change into the other models),
   and the rollback plan.

When orchestrated by the release command, the security/dependency check (step 3) and the changelog/
release-notes generation (steps 1, 7) can run in parallel since they operate on independent data.

Coordinate the actual deploy with the DevOps agent (`.ai/agents/devops-agent.md`) and its checklist —
`{{DEFAULT_BRANCH}}` = production, across {{DEPLOY_STAGES}}. Note any per-tenant split
({{TENANT_ISOLATION_RULE}}).
