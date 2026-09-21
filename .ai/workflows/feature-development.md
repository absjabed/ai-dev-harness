# Workflow: Feature Development

End-to-end workflow for delivering a feature. This mirrors `/workflows:feature`. Do not skip steps.

**Inputs come from the studio agents — this workflow does not generate them.** Before implementing,
the requirement, user stories, and test spec must already exist under `.ai/features/<slug>/`
(`requirement-spec.md`, `user-stories.md`, `test-specs.md`), produced by `/ba` and `/qa`. For an
epic: `.ai/features/<slug>/epic-breakdown.md` plus those same three files under each `<sub-feature>/`.
**If any are missing, stop and run `/ba <slug>` and `/qa <slug>` first.**

**State file:** the workflow keeps machine-maintained state at `.ai/features/<slug>/STATE.md`
(from `.ai/templates/feature-state.md`) — mode, phase checklist, task checklist, decisions,
blockers, next action. It is internal state, never a branded deliverable. Create it once
single-vs-epic is known; update it after every step, at every gate (record the outcome), and
before delegating any work.

**Resume rule (trust but verify):** if `STATE.md` already exists, this is a resume. For every
phase it marks done, verify the phase's artifact actually exists on disk (technical spec, design
spec, test report, review report, security report as applicable); re-run any phase whose artifact
is missing, then continue from the recorded next action.

1. **Understand** — Read the consumed `requirement-spec.md`, `user-stories.md`, and `test-specs.md`.
   Confirm the acceptance criteria. Ask clarifying questions if needed. (Single feature vs epic is
   decided by whether `epic-breakdown.md` exists — don't re-derive it.)
2. **Analyze** — Read the relevant existing code. Map the impact area across the layering of the
   feature's scope(s) (see each scope's `tech-specific.md`). Find reusable utilities (validation
   helpers, error types, mappers, the scope's data-access). Watch for cross-layer contracts the
   scope standards flag — e.g. a shared DB schema change must be mirrored wherever else it's mapped.
3. **Technical spec** — Write the technical spec under `.ai/features/<slug>/technical-specs/`
   (split `backend.md` / `frontend.md` if fullstack) and get it approved before touching code. For
   architectural changes, update `.ai/context/architecture.md` and write an ADR for notable decisions.
   At the approval gate, ask once whether to enable **per-task atomic commits** for the run (each
   completed task committed as `feat(<slug>): <task>`); record the decision in `STATE.md`.
   Default is off — a single commit at step 8.
4. **Implement** — Delegate implementation to a developer agent with a **fresh context**: it reads
   `STATE.md`, the approved technical spec, and the BA/QA artifacts (plus the approved design spec
   if one exists), works through the task checklist in `STATE.md` (ticking tasks off as they
   complete), and follows the recorded atomic-commit decision. The orchestrating session keeps
   ownership of every gate. Code follows all standards of the feature's scope(s) — layering,
   DI/wiring, error/response conventions, validation, and that scope's `tech-specific.md` rules.
5. **Verify** — Verify the cases in `test-specs.md` using the feature's scope gates: where a scope
   has a test runner, the delegated agent writes and runs those tests; where a scope has **none**
   (e.g. a legacy scope with no test project), it confirms a clean build and drives the affected
   flow manually (per-tenant/per-env impact noted). It records exactly what was and wasn't verified at
   `.ai/features/<slug>/test-specs/test-report.md`. Adding automated tests where a scope lacks them
   is welcome — but only counts once wired into CI.
6. **Review & security gate (parallel)** — Spawn the Reviewer and security scanner concurrently
   on the same diff; reviewer saves to `.ai/features/<slug>/review-report.md`, security saves to
   `.ai/features/<slug>/security-report.md`. CRITICAL findings block the commit step.
7. **Document** — Update the relevant README/docs if the public behavior/API changed.
8. **Commit** — A clear {{COMMIT_CONVENTION}} message referencing the tracker ticket (e.g.
   `{{TICKET_PREFIX}}-1234: <summary>`) after user confirmation. If atomic commits were enabled,
   present the per-task commit list for confirmation instead of creating a single commit. CRITICAL
   security findings block this step either way.
9. **Report** — Generate the {{PR_TERM}} description at `.ai/features/<slug>/pr-description.md`;
    summarize what was done, test results, and any follow-up items.

**Epics:** read `epic-breakdown.md`, validate each sub-feature's artifacts exist, then run the
implement → test → review loop per sub-feature on `feature/<epic>/<sub-feature>` branches (parallel
within a dependency group), merge each into `epic/<epic>` in dependency order, and open one
{{PR_TERM}} for the epic. Isolate parallel work with **git worktrees**: first commit the epic's
planning artifacts (everything under `.ai/features/<slug>/`) onto `epic/<slug>` — worktrees are
fresh checkouts that only see committed files — then each sub-feature builds in its own checkout
under `.worktrees/<sub-feature>` (ensure `.worktrees/` is in the project's `.gitignore`), so
delegated agents never share a working tree; agents commit their outputs (code, specs, test
report) on their branch, and each worktree is removed after its branch merges. Phase F runs
the reviewer and security scanner in parallel on the full epic diff before the {{PR_TERM}}.
Track sub-feature status and dependency groups in the epic's `STATE.md`, updated per phase,
per group, and per merge.

**Gate:** each touched scope's gates must pass before step 8 — build always, plus lint/type-check/
test where the scope defines them; where a scope has no test runner, a clean build plus the
documented manual verification stands in.
