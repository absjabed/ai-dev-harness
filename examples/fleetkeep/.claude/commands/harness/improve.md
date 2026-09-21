---
description: Improve the harness itself via an author → critic → revise → recheck loop with an integration audit and a commit gate
argument-hint: <what to improve / add / fix in the harness>
allowed-tools: Read, Write, Edit, Bash, Task
---
@.ai/workflows/harness-improvement.md
@.ai/agents/harness-engineer-agent.md
@.ai/agents/critic-agent.md

Improvement requested: $ARGUMENTS

You are orchestrating a change to the **harness itself** (the `.ai/` and `.claude/`
trees). Follow the harness-improvement workflow above exactly. Its invariants are
binding for every agent you spawn.

## 1 — Plan

Restate the goal. Split it into work packages with **disjoint file sets** (merge packages
that touch the same file). For each package list: files to create/edit, intended
behavior, invariants touched, and whether it needs real execution tests (any shell/hook
change does). Note whether `examples/` exists — if not, drop every mirror step.

**STOP** — show the plan; get user confirmation before any edit.

## 2 — Author (parallel, one Task agent per package)

Spawn a `harness-engineer` Task agent per package with: its file list, the intended
behavior, the invariants it touches, and the instruction to smoke-test any shell change
in a throwaway git repo and report observed output. Packages are disjoint, so run each
group in parallel.

## 3 — Critique (one Task agent per package)

For each completed package, spawn a `critic` Task agent with the package's file list and
the author's claims. It verifies everything itself, read-only, and returns a verdict
with severity-tagged findings.

## 4 — Revise & recheck

For any package with CRITICAL or MAJOR findings: spawn a `harness-engineer` Task agent
with the findings to fix (it may rebut a finding only with evidence), then a fresh
`critic` to confirm the fixes. Maximum two revise→recheck rounds per package — if still
failing, **STOP** and surface the disagreement to the user.

## 5 — Integration audit

Spawn one final `critic` Task agent across the whole change: file ownership (`git status
--porcelain` — nothing touched that no package owns), cross-file contracts, the mirror
invariant (only if `examples/` exists), `bash -n` over all hooks, a broken-reference
sweep, and the doc inventories (COMMANDS.md, README.md, .ai/README.md, .claude/README.md,
.ai/CUSTOMIZATION.md). Fix anything it finds yourself, or loop back to step 4 for
anything substantial.

## 6 — Verify and land

Run the playbook's verification block yourself and show the user: `git diff --stat`, a
summary of what changed and what the critics caught, and any open questions.

**STOP** — get explicit confirmation, then commit as a conventional commit on a
`feature/<slug>` branch (create it if on the default branch). Never push without being
asked. Finally, append what the loop taught to `.ai/memory/learnings.md`
(`YYYY-MM-DD | harness-improvement | <learning> | harness-engineer`).
