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
