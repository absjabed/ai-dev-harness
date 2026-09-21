<!-- Prepend the branded header from .ai/templates/artifact-header.md before this content. -->
# Deployment Checklist — v[VERSION]

**Environment:** [staging | production]
**Release date:** [YYYY-MM-DD]
**Deployer:** [name]
**Release notes:** `.ai/releases/v[VERSION]/release-notes.md`
**Rollback plan:** `.ai/releases/v[VERSION]/rollback-plan.md`

---

## Pre-deploy

- [ ] Merge freeze active — no new changes merged after this point
- [ ] Security scan passed (no CRITICAL/HIGH findings)
- [ ] All tests passing on release branch (`{{TEST_CMD}}`, `{{BUILD_CMD}}`)
- [ ] Staging deploy verified and smoke-tested
- [ ] Stakeholders notified of maintenance window (if applicable)
- [ ] Previous release version/artifact identifiers noted for rollback

---

## Database (run BEFORE application deployment)

_Fill in migration files from migration-plan.md_

- [ ] Migrations reviewed — no unexpected destructive changes
- [ ] Production database backup taken
- [ ] Run migrations: `{{MIGRATE_CMD}}` from `{{BACKEND_DIR}}/`
- [ ] Migration output verified — no errors, row counts as expected
- [ ] Verify application still connects after migration

**Migrations in this release:**
- [ ] `[migration filename]` — [what it does]

---

## Additional Services (remove if not applicable)

- [ ] Artifacts/images built for changed services
- [ ] Artifacts published to the registry/store
- [ ] Deployment targets updated to the new versions
- [ ] Health checks passing on all updated services
- [ ] Previous versions noted (for rollback)

---

## Backend

- [ ] Deploy executed from `{{BACKEND_DIR}}/`
- [ ] All components deployed successfully (check output for errors)
- [ ] Previous version identifiers noted: `[identifier]`
- [ ] API endpoints responding: `curl https://<api-host>/health`
- [ ] Logs show no errors on first requests

---

## Frontend

- [ ] `{{BUILD_CMD}}` passes with no errors (from `{{FRONTEND_DIR}}/`)
- [ ] Build artifacts present in the expected output directory
- [ ] Artifacts published/synced to the hosting target
- [ ] Cache invalidated at the CDN/edge (if applicable)
- [ ] App loads in browser — no blank screen, no console errors
- [ ] Auth flow works

---

## Infrastructure (only if infra changes exist)

- [ ] Infra diff/preview reviewed — no unexpected resource replacements or deletions
- [ ] No stateful resource replacements (databases, identity stores) without explicit approval
- [ ] Infra changes deployed
- [ ] Resources verified in the cloud console

---

## Post-deploy

- [ ] Health endpoints respond: `/health` on the backend
- [ ] Smoke test: login → core feature flow → verify (pick one key user journey)
- [ ] Error rates normal in monitoring (no spike in 5xx errors)
- [ ] Monitoring alerts re-enabled (if silenced during deploy)
- [ ] Release tag pushed: `git tag v[VERSION] && git push origin v[VERSION]`
- [ ] CHANGELOG.md updated and committed
- [ ] Team notified of successful deployment

---

## Rollback triggers

Initiate rollback if within 30 minutes of deploy:
- Error rate exceeds pre-deploy baseline by >5%
- Any CRITICAL user-facing feature broken
- Data integrity issues detected

See `rollback-plan.md` for step-by-step rollback instructions.
