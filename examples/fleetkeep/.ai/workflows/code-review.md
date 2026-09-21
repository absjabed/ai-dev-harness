# Workflow: Code Review

1. **Read the context** — What problem does this change solve? What's the intended behavior?
2. **Check the diff** — Which files changed? Run `git diff` (or review the pull request). Understand
   the scope, and which scope(s) the changed files belong to.
3. **Review each change** — Correctness, edge cases, and compliance with the standards of the
   changed file's scope (layering, DI/wiring, error/response conventions, and its `tech-specific.md`
   rules). Read surrounding code, not just the diff lines.
4. **Check verification** — Confirm the change is verified appropriately for its scope: a test where
   the scope has a runner; a clean build plus a described manual/driven check where it has none (e.g.
   a legacy scope with no test project). The reviewer should be able to see what was and wasn't verified.
5. **Security scan** — Apply `.ai/standards/universal/security-baseline.md` (input validation, no
   secrets committed, no new raw/unparameterized SQL, no sensitive data in logs, authorization +
   audit on any protected-data path — see every query is scoped to the caller's tenant by the `TenantId` global query filter on `FleetKeepDbContext` and OIDC authorization-code + PKCE in the SPA (MSAL), JWT bearer validated by the API).
6. **Performance check** — N+1 queries, missing eager-loading/indexes, needless work on hot/request
   paths, per-call client instantiation, in-memory work that belongs in the query.
7. **Write the review** — Severity levels **BLOCKER / WARNING / SUGGESTION / PRAISE**, each with
   file:line and a concrete fix.
8. **Summarize** — Overall verdict (approve / request changes) with the key points.

Focus on bugs and security, not style — the scope's compiler/type-checker (a clean build/type-check)
and the "match existing style" rule handle formatting. Don't request drive-by renames or restyles.
