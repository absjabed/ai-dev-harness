<!-- Internal workflow state — machine-maintained by /workflows:feature. NOT a deliverable:
     do NOT prepend the branded header from .ai/templates/artifact-header.md, and do not polish
     it for presentation. The workflow creates this file at .ai/features/<slug>/STATE.md, updates
     it after every numbered step, at every STOP gate, and before spawning any Task agent, and
     reads it on re-entry to resume an interrupted run. -->
# Workflow State: [feature-or-epic slug]

Last updated: YYYY-MM-DD HH:MM

## Mode

[single | epic]

## Current phase

[Name of the phase currently in progress, from the checklist below.]

## Phases

<!-- Single feature — keep this checklist and delete the epic one. Check off each phase as it completes. -->
- [ ] Inputs validated (requirement-spec, user-stories, test-specs)
- [ ] Technical spec written
- [ ] Technical spec approved (STOP gate)
- [ ] Design gate (UI surface only — mark done with "skipped" for backend-only)
- [ ] Branch created
- [ ] Implementation & tests (developer agent)
- [ ] Review
- [ ] Security gate
- [ ] Runtime verification (API / UI / DB as planned)
- [ ] Deploy notes captured
- [ ] Commit confirmed (STOP gate)
- [ ] pull request description

<!-- Epic — keep this checklist and delete the single-feature one. -->
- [ ] Phase A — Validate inputs
- [ ] Phase B — Design gates
- [ ] Phase C — Epic branch
- [ ] Phase D — Parallel implementation
- [ ] Phase E — Sequential merge
- [ ] Phase F — Final review & pull request

## Tasks

<!-- Single feature: the implement-phase task checklist, derived from the approved technical spec
     before the developer agent is spawned. The developer agent ticks each task off as it completes. -->
- [ ] [task 1]
- [ ] [task 2]

<!-- Epic: one line per sub-feature with its status and dependency group, e.g.
- [ ] [sub-feature-slug] — group [n] — [pending | in progress | implemented | merged]
-->

## Decisions

<!-- Dated one-liners: gate outcomes and run-level choices. -->
- YYYY-MM-DD: Atomic commits: [on | off (default)].
- YYYY-MM-DD: [decision]

## Blockers

<!-- Anything preventing progress; "None" if clear. -->
- None

## Next action

[Single imperative line — the first thing a resumed session should do.]
