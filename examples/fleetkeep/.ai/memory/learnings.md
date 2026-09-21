# Project Learnings Log

This file is append-only and maintained automatically. Agents append learnings here; humans add
theirs via `/utils:learn`.
Format each entry: `YYYY-MM-DD | Context | Learning | Agent`

Record only non-obvious, reusable learnings — patterns that worked, pitfalls hit, approaches
tried and abandoned (and why) — not routine work.

## Learnings

<!-- Example (delete once you have real entries):
- 2026-01-01 | Service-layer tests | Fake repositories beat DB mocks — faster and no teardown flakes | developer
-->
- 2026-07-15 | harness-improvement | Extend numbered invariant lists by appending only, then grep the repo for stale numeric references (docs cite invariants by number, e.g. "invariant 7/8") | harness-engineer
- 2026-07-16 | harness-improvement | When a persona gains an integration behavior, grep every command that @-includes it and grant the tool (or scope the promise) - shared personas are capability supersets of their commands | harness-engineer
- 2026-07-16 | harness-improvement | Read-only agents (reviewer, security-scanner) on the same diff are safe to parallelize — check output file paths don't collide and both must complete before any gate evaluates | harness-engineer
- 2026-07-16 | harness-improvement | For add-only packages git diff --stat shows nothing new - verify the footprint with git status --porcelain (untracked files) plus cmp for mirrors | harness-engineer
- 2026-02-25 | EF Core global query filters | A filter is silently skipped on a raw-SQL path and on `IgnoreQueryFilters()`; an integration test that asserts cross-tenant rows are invisible catches far more than code review does | developer
- 2026-03-12 | Rolling deploys | A `NOT NULL` column added without a default took production down for the 90 seconds both API versions overlapped — expand/contract is not theoretical here | developer
- 2026-03-28 | Mantine + CSS Modules | Raw hex values pass review easily and only break in dark mode, which nobody checks by default; turning on DESIGN_TOKEN_CHECK in hooks.env caught more than the review checklist did | developer
- 2026-04-15 | TanStack Query keys | Omitting tenantId from a query key leaked one tenant's cached rows into another after a support-user tenant switch; every key now starts ['resource', tenantId] | developer
- 2026-05-06 | Worker idempotency | The nightly scan double-sent notifications after a transient failure retriggered it; making each pass idempotent was simpler than adding a dead-letter queue | developer
