# Workflow: Bug Fixing

Fix causes, not symptoms.

> [FILL IN: this codebase's risk profile in one line — e.g. "live software handling regulated
> personal data with thin safety nets, so keep every change small, convention-matching and
> reversible". Delete this block if the default posture is enough.]

1. **Reproduce** — Confirm you can reproduce the bug before changing anything. Capture the exact
   inputs and the wrong vs expected behavior.
2. **Find the root cause** — Trace it through the layering of the affected scope (see that scope's
   `tech-specific.md`) to the true source; don't patch a symptom.
3. **Guard the fix** — If the affected scope has a test runner, add a failing test that reproduces
   the bug (fails now, passes after). If the scope has **no** test runner (e.g. a legacy scope with
   no test project), capture a concrete manual/driven reproduction (steps, data, expected vs actual) you can re-run
   instead. Adding a genuine automated test where none exists is a net improvement — but it only
   counts once wired into CI.
4. **Fix** — Make the **minimal** change that addresses the root cause, following the affected
   scope's standards.
5. **Verify** — Run the affected scope's quality gates (build, plus lint/type-check/test where the
   scope defines them). Where a scope has no test runner, confirm a clean build and re-run your
   reproduction. State clearly what you verified and what you did not.
6. **Assess blast radius** — What else could this affect? Check callers, related endpoints/
   components, and any shared contract other layers or services depend on (a schema change in
   particular must be mirrored wherever else it is mapped — see the scope standards). Call out any
   per-tenant / per-environment impact ({{TENANT_ISOLATION_RULE}}).
7. **Review gate** — Spawn the Reviewer on the fix diff before committing. It is read-only, so it
   reports rather than edits. A fix is a change like any other: the smaller it looks, the less
   scrutiny it tends to get, which is exactly when a wrong root cause slips through. **BLOCKER
   findings must be resolved before step 8.** Keep it proportionate — this is one agent on a small
   diff, not the full feature gate.
8. **Commit** — Follow {{COMMIT_CONVENTION}} and reference the tracker ticket, e.g.
   `{{TICKET_PREFIX}}-1234: <what was broken and how it's now fixed>`.

**Report:** root cause, the fix, how it was verified, the review verdict, and any related risk you
found.
