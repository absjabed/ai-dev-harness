# Workflow: Hotfix Process

For urgent production fixes. Fast, minimal, safe. Production is the `{{DEFAULT_BRANCH}}` branch —
smallest reversible change wins.

> [FILL IN: this codebase's risk profile in one line, if it raises the bar — e.g. "live software
> handling regulated personal data". Delete if not applicable.]

1. **Branch from `{{DEFAULT_BRANCH}}`** (production) — **not** from a feature branch. Use
   `fix/{{TICKET_PREFIX}}-####-slug` or `hotfix/{{TICKET_PREFIX}}-####-slug` (see {{BRANCH_PREFIXES}}).
2. **Minimal change only** — fix the bug, nothing else. No refactors, no unrelated cleanup.
3. **Guard the fix** — reproduce it: a failing test where the affected scope has a test runner, or a
   concrete manual/driven reproduction where it has none, so the regression can't silently return.
4. **Verify** — run the affected scope's gates (build always; lint/type-check/test where defined) and
   re-run the reproduction. State what you verified.
5. **Review gate** — Spawn the Reviewer on the hotfix diff before opening the {{PR_TERM}}. It is
   read-only and runs on a deliberately tiny diff, so it costs little. **This is the step most
   likely to be skipped under time pressure and the one where skipping costs most** — the change is
   going straight to production, usually written fast, by someone who has been staring at the
   incident. **BLOCKER findings must be resolved before step 6.** If the outage is actively burning
   and the fix is a one-line revert, say so explicitly in the {{PR_TERM}} and have a human approve
   skipping — never skip it silently.
6. **Land it via {{PR_TERM}} and forward-port** — open a {{PR_TERM}} into `{{DEFAULT_BRANCH}}`, then
   forward-port to the active development and `release/*` branches so the fix isn't lost next
   release. Never push directly to {{PROTECTED_BRANCHES}}.
7. **Deploy with monitoring** — follow the DevOps deploy checklist (env vars / app config, any DB
   migration, rollback plan); watch {{CLOUD_PROVIDER}} logs/metrics after rollout. Call out
   per-tenant impact ({{TENANT_ISOLATION_RULE}}).
8. **Post-mortem within 48 hours** — root cause, why it wasn't caught, and the prevention action (a
   guardrail, a documented check, or a targeted test wired into CI). Include any review finding that
   the gate caught — or would have caught, if it was skipped.
