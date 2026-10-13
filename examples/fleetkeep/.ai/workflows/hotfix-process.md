# Workflow: Hotfix Process

For urgent production fixes. Fast, minimal, safe. Production is the `main` branch —
smallest reversible change wins.

A hotfix here touches live compliance data for every tenant at once: the smallest reversible
change wins, and a migration in a hotfix must still be backward-compatible (rolling deploys).

1. **Branch from `main`** (production) — **not** from a feature branch. Use
   `fix/FK-####-slug` or `hotfix/FK-####-slug` (see `feature/`, `fix/`, `chore/`, `hotfix/`).
2. **Minimal change only** — fix the bug, nothing else. No refactors, no unrelated cleanup.
3. **Guard the fix** — reproduce it: a failing test where the affected scope has a test runner, or a
   concrete manual/driven reproduction where it has none, so the regression can't silently return.
4. **Verify** — run the affected scope's gates (build always; lint/type-check/test where defined) and
   re-run the reproduction. State what you verified.
5. **Review gate** — Spawn the Reviewer on the hotfix diff before opening the pull request. It is
   read-only and runs on a deliberately tiny diff, so it costs little. **This is the step most
   likely to be skipped under time pressure and the one where skipping costs most** — the change is
   going straight to production, usually written fast, by someone who has been staring at the
   incident. **BLOCKER findings must be resolved before step 6.** If the outage is actively burning
   and the fix is a one-line revert, say so explicitly in the pull request and have a human approve
   skipping — never skip it silently.
6. **Land it via pull request and forward-port** — open a pull request into `main`, then
   forward-port to the active development and `release/*` branches so the fix isn't lost next
   release. Never push directly to `main` and `develop`.
7. **Deploy with monitoring** — follow the DevOps deploy checklist (env vars / app config, any DB
   migration, rollback plan); watch Azure logs/metrics after rollout. Call out
   per-tenant impact (every query is scoped to the caller's tenant by the `TenantId` global query filter on `FleetKeepDbContext`).
8. **Post-mortem within 48 hours** — root cause, why it wasn't caught, and the prevention action (a
   guardrail, a documented check, or a targeted test wired into CI). Include any review finding that
   the gate caught — or would have caught, if it was skipped.
