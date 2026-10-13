---
description: Full end-to-end feature workflow — consumes BA/QA specs, handles single feature or epic, parallelises where possible
allowed-tools: Read, Write, Edit, Bash, Task
---
@.ai/agents/developer-agent.md
@.ai/agents/designer-agent.md
@.ai/agents/qa-agent.md
@.ai/standards/universal/coding-principles.md
@.ai/standards/universal/security-baseline.md
@.ai/workflows/feature-development.md
@.ai/config/branding.md
@.ai/templates/artifact-header.md
@.ai/templates/technical-spec.md
@.ai/templates/design-spec.md
@.ai/templates/deploy-notes.md

**Scope determination (do this first, before any other action):**
1. Read `.ai/config/current-scope.md` — if it starts with `# Forced scope:`, use that scope and skip to step 3.
2. Otherwise, analyze "$ARGUMENTS" to determine scope. Features often span both layers — when in doubt, pick fullstack:
   - **backend** — a data-layer change, a migration, a new/changed API endpoint, a background service, and (where the backend renders its own UI) a **server-rendered feature** end to end: view + controller/handler + service + data access. A server-rendered feature is **backend**, NOT fullstack.
   - **frontend** — work inside `{{FRONTEND_DIR}}`: a screen redesign, a styling fix, client-side validation, or porting a server-rendered screen into the {{FRONTEND_FRAMEWORK}} app.
   - **fullstack** — a change spanning the {{FRONTEND_FRAMEWORK}} app **and** a new/changed API together.
   - If unsure → ask the user.
   > [FILL IN: replace the examples above with signals specific to your stack — e.g. **backend:**
   > {{BACKEND_LANGUAGE}} file extensions, {{BACKEND_FRAMEWORK}} controllers/handlers, server-rendered
   > view files, {{ORM}} migrations, DI wiring, anything under `{{BACKEND_DIR}}`; **frontend:**
   > {{FRONTEND_LANGUAGE}} extensions, {{FRONTEND_FRAMEWORK}} components, {{COMPONENT_LIBRARY}},
   > anything under `{{FRONTEND_DIR}}`. If the project is mid-migration between two UI stacks, state
   > the rule for which one a new feature belongs to.]
3. Load only the files for the determined scope using the Read tool:
   - **backend**: `.ai/config/backend/project-config.md`, `.ai/context/backend/architecture.md`,
     `.ai/context/backend/project-overview.md`, `.ai/context/backend/business-rules.md`,
     `.ai/standards/project/backend/tech-specific.md`.
     **If the backend renders its own UI, for UI work also load** `.ai/standards/universal/ui-ux-standards.md`,
     `.ai/standards/universal/accessibility.md`, `.ai/standards/universal/frontend-design.md`, and
     `.ai/standards/project/frontend/design/` (`palette.md`, `design-tokens.md`, `component-specs.md`) —
     the design docs govern whatever UI the project has, server-rendered included. (Skip these for non-UI backend work.)
   - **frontend**: `.ai/config/frontend/project-config.md`, `.ai/context/frontend/architecture.md`,
     `.ai/context/frontend/project-overview.md`, `.ai/context/frontend/business-rules.md`,
     `.ai/standards/project/frontend/tech-specific.md`, `.ai/standards/universal/ui-ux-standards.md`,
     `.ai/standards/universal/accessibility.md`, `.ai/standards/universal/frontend-design.md`,
     `.ai/standards/project/frontend/design/` (`palette.md`, `design-tokens.md`, `component-specs.md`)
   - **fullstack**: all the files above
   - **single-project repos**: load `.ai/config/project-config.md`, `.ai/context/{architecture,project-overview,business-rules}.md`, `.ai/standards/project/tech-specific.md`

---

> **Branding:** every spec/report this workflow writes must begin with the branded header from
> `.ai/templates/artifact-header.md` (values from `.ai/config/branding.md`).

Feature/Epic: $ARGUMENTS

## Step 0 — Workflow state & resume

This workflow keeps machine-maintained state at `.ai/features/$ARGUMENTS/STATE.md` (template:
`.ai/templates/feature-state.md`). It is internal working state, **not** a deliverable — never
prepend the branded artifact header to it.

- **`STATE.md` exists → this is a RESUME.** Announce that to the user. **Trust but verify**: for
  each phase marked done under `## Phases`, confirm its artifact actually exists on disk — the
  technical spec(s) under `technical-specs/`, `design/design-spec.md` (if the design gate ran),
  `test-specs/test-report.md`, `review-report.md`, `security-report.md`, `deploy-notes.md` — as
  applicable to that phase. Re-run any phase whose artifact is missing (uncheck it first). Then
  continue from
  `## Next action`.
- **`STATE.md` does not exist →** create it from `.ai/templates/feature-state.md` right after
  Step 2, once the mode (single | epic) is known.

From then on, update `STATE.md` after **every numbered step**, at **every STOP gate** (record the
gate outcome under `## Decisions`), and **before spawning any Task agent** — so a fresh session
can always resume from it.

## Step 1 — Require BA/QA inputs (this workflow consumes them; it does not generate them)

This workflow **does not create user stories, epic breakdowns, or test specs** — the `/ba` and `/qa`
studio agents own those. Check `.ai/features/$ARGUMENTS/` and confirm the required artifacts exist:

- `requirement-spec.md` — the authoritative requirement (from `/ba`).
- `user-stories.md` — the user stories (from `/ba`).
- `test-specs.md` — the test specification (from `/qa`).

**If any required artifact is missing, STOP** and tell the user to produce it first — e.g.
"Run `/ba $ARGUMENTS` and `/qa $ARGUMENTS` before this workflow; it consumes those artifacts and does
not generate them." Do not fall back to generating them yourself. (For epics the artifacts live per
sub-feature — see the Epic path's validation phase.)

## Step 2 — Single feature or epic? (read, don't re-derive)

Decide from what `/ba` already produced — do **not** re-analyse the request:

- **`.ai/features/$ARGUMENTS/epic-breakdown.md` exists → Epic** — follow the EPIC PATH.
- **Otherwise → Single feature** — follow the SINGLE-FEATURE PATH.

Once decided: if `.ai/features/$ARGUMENTS/STATE.md` does not exist, create it now from
`.ai/templates/feature-state.md` — set `## Mode`, keep the matching `## Phases` checklist
(single-feature phases or epic Phases A–F, delete the other), and set `## Next action`.

---

## ═══ SINGLE-FEATURE PATH ═══

Consumes `requirement-spec.md`, `user-stories.md`, and `test-specs.md` (Step 1). Follow these steps
completely, in order:

1. **Technical spec** — create it and store under `.ai/features/$ARGUMENTS/technical-specs/`.
   - If scope is fullstack: create `technical-specs/backend.md` and `technical-specs/frontend.md` separately.
2. **STOP** — show the user the technical spec alongside the consumed `requirement-spec.md`, `user-stories.md`, and `test-specs.md`. Get confirmation/feedback. Refine the technical spec if needed. Do not proceed without approval.
   At this gate, also ask the user **one** question: *enable per-task atomic commits for this run?*
   (the developer agent commits each completed task as `feat($ARGUMENTS): <task>` on the feature
   branch). Record the answer in `STATE.md` under `## Decisions`. **Default = off** — a single
   commit at the step 6 gate, exactly as before. If enabled, the step 6 STOP still happens: it
   shows the commit list for confirmation instead of creating one commit, and unresolved CRITICAL
   security findings still block proceeding.
2a. **UI/UX design gate** — *any feature with a UI surface — a {{FRONTEND_FRAMEWORK}} screen OR a server-rendered view; skip only non-UI backend features (pure API / data / migration / background services).* Run the Designer (`/agents:design`): UX → visual design → Artifact preview → design-system & accessibility validation.
   - **STOP** — show the user the Artifact URL; run the review loop until they **explicitly approve**. Record the approved Artifact URL + version in `.ai/features/$ARGUMENTS/design/design-spec.md` (use the `design-spec.md` template). Preview HTML is published as an Artifact, never committed.
   - Get **Architect** approval (`/agents:architect`); implementation (step 4) begins only after **both** approvals.
3. Create and switch to branch `feature/$ARGUMENTS` (from the current base branch).
4. **Implementation & tests — spawned developer agent (fresh context).** Derive the
   implement-phase task checklist from the approved technical spec and write it under `## Tasks`
   in `STATE.md` (one checkbox per task; backend tasks before frontend tasks if fullstack).
   Update `STATE.md`, then spawn a `developer` Task agent — the parent session stays in charge
   of all gates; the agent only implements:

   > "You are a developer agent implementing the approved feature `$ARGUMENTS`.
   > 1. Read `.ai/features/$ARGUMENTS/STATE.md` — it holds your task checklist (`## Tasks`) and the recorded decisions (`## Decisions`).
   > 2. Read the approved technical spec(s) under `.ai/features/$ARGUMENTS/technical-specs/`, plus `requirement-spec.md`, `user-stories.md`, and `test-specs.md` — and `design/design-spec.md` if present (build the UI against it and its approved Artifact preview).
   > 3. Load the scope context files for [backend/frontend/fullstack as determined for this feature].
   > 4. Work through the `## Tasks` checklist in order, following all loaded standards; tick each task off in `STATE.md` as it completes.
   > 5. Follow the atomic-commit decision recorded in `STATE.md`: if **on**, commit each completed task on `feature/$ARGUMENTS` as `feat($ARGUMENTS): <task>`; if **off** (the default), do not commit — leave all changes in the working tree.
   > 6. Verify per the loaded scope: where the scope has a test runner, write comprehensive tests covering `test-specs.md`, run them, and confirm they pass; where the scope has none (e.g. a legacy scope with no test project), confirm a clean build and drive the affected flow manually.
   > 7. Generate the test/verification report at `.ai/features/$ARGUMENTS/test-specs/test-report.md`.
   > Return: the completed task list, test results, and a one-paragraph summary of what was built."

   When the agent returns, verify `## Tasks` is fully checked and the test report exists, then
   update `STATE.md`.
5. **Review & security gate (parallel)** — spawn both agents concurrently on the current
   feature diff (`git diff HEAD` when atomic commits are off; `git diff [base-branch]...HEAD`
   plus any uncommitted changes when they are on). Spawn both agents concurrently — they are
   read-only on the same diff and do not conflict.

   - **Reviewer** — spawn a `reviewer` Task agent:
     > "Review the current feature diff for `$ARGUMENTS` against the approved technical spec under `.ai/features/$ARGUMENTS/technical-specs/`. Apply the full reviewer checklist. Output a structured review with BLOCKER/WARNING/SUGGESTION/PRAISE findings and an overall verdict."
     Show the verdict in chat **and** ensure the review is saved to
     `.ai/features/$ARGUMENTS/review-report.md` — the reviewer persists the report itself via Bash,
     per its role definition (it is read-only for code, not for reports); verify the file exists
     when it returns.

   - **Security scanner** — spawn a `security-scanner` Task agent:
     > "Run a security scan on the current feature diff (`git diff HEAD`, or `git diff [base-branch]...HEAD` if per-task commits were made). Scope: [backend/frontend/fullstack as determined for this feature]. Apply the full security-agent checklist. Output a security report in chat **and** save it to `.ai/features/$ARGUMENTS/security-report.md`."

   Wait for both agents to complete. Include any CRITICAL or HIGH findings verbatim in the
   confirmation report shown in step 6. CRITICAL findings must be resolved before committing —
   do not proceed past step 6 with unresolved CRITICAL findings (whether or not atomic commits
   are enabled).
5a. **Document & deploy notes** — per step 7 of `feature-development.md`: update any README/docs
   the change affects, then write `.ai/features/$ARGUMENTS/deploy-notes.md` from
   `.ai/templates/deploy-notes.md` — **Fix version** copied from the Source issue block of
   `.ai/features/$ARGUMENTS/requirement-spec.md` (`unknown — to be confirmed` if that is what it
   says or the field is absent; never guess), the target deployment-guide section named, and an
   explicit *No deploy impact* line if the change needs nothing beyond the standard pipeline run.
   Never a secret — `<placeholders>` only. This is not a gate: the file is included in the step 6
   commit, so write it before that STOP.
6. **STOP** — get user confirmation before finalising. Show: test results, security scan summary (finding counts by severity), any CRITICAL/HIGH details, and the deploy notes from step 5a (fix version, deploy impact — and confirm they hold no secret, since they were written after the scan). Record the gate outcome in `STATE.md`.
   - Atomic commits **off** (default): create a single conventional commit after confirmation.
   - Atomic commits **on**: show the list of per-task commits already on `feature/$ARGUMENTS` (plus any uncommitted remainder) for confirmation instead of creating one commit; commit any remainder only after confirmation.
7. Generate the {{PR_TERM}} description at `.ai/features/$ARGUMENTS/pr-description.md`. Update
   `STATE.md`: mark all phases done and set `## Next action` to `None — workflow complete`.

---

## ═══ EPIC PATH ═══

The epic breakdown and every sub-feature's stories and test specs come from `/ba` and `/qa`. This
workflow **reads** them and orchestrates branching, implementation, and integration — it generates no
stories, breakdowns, or test specs.

### Phase A — Validate inputs

1. Read `.ai/features/$ARGUMENTS/epic-breakdown.md` — it lists the sub-features (each with a slug,
   scope, and dependencies) and the dependency groups (what can run in parallel vs sequentially).
2. For **each sub-feature**, confirm `.ai/features/$ARGUMENTS/$FEATURE/requirement-spec.md`,
   `user-stories.md`, and `test-specs.md` all exist.
3. **If the breakdown or any sub-feature's artifacts are missing, STOP** and tell the user to run
   `/ba $ARGUMENTS` (and `/qa $ARGUMENTS`) first. Do not generate them.
4. **STOP** — show the user the sub-feature list and dependency groups from the breakdown; get confirmation before proceeding.
5. Update `STATE.md`: mark Phase A done, record the gate outcome under `## Decisions`, list each
   sub-feature under `## Tasks` as `- [ ] <sub-feature> — group <n> — pending`, and set
   `## Next action`.

### Phase B — UI/UX design gate (sub-features with a UI surface — {{FRONTEND_FRAMEWORK}} or server-rendered)

For each sub-feature with a UI surface, run the Designer (`/agents:design`) and its Artifact preview
approval loop, and capture the approved design in `.ai/features/$ARGUMENTS/$FEATURE/design/design-spec.md`.
This needs human interaction, so it must complete **before** the autonomous Phase D (which builds
against the approved `design-spec.md`). Skip only non-UI backend sub-features (pure API / data / migration).

After **each** design approval, record it in `STATE.md` under `## Decisions`; mark Phase B done
once every UI sub-feature has an approved `design-spec.md`.

### Phase C — Create Epic Branch

Create branch `epic/$ARGUMENTS` from the current base branch.
Commit the epic's planning artifacts onto it — everything under `.ai/features/$ARGUMENTS/`
(the epic breakdown, each sub-feature's `requirement-spec.md`/`user-stories.md`/`test-specs.md`,
and every approved `design/design-spec.md`), e.g. `docs($ARGUMENTS): epic planning artifacts`.
This is required: the Phase D worktrees are fresh checkouts of `epic/$ARGUMENTS`, so spawned
agents can only read files **committed** on that branch — uncommitted specs in the main working
tree are invisible to them.
Push it to remote so sub-feature branches can track it.

### Phase D — Parallel Implementation (dependency-aware, worktree-isolated)

Process sub-features in dependency order. Each sub-feature is implemented in its **own git
worktree**, so parallel agents never share a working tree.

**One-time setup (before creating the first worktree):** ensure the project's `.gitignore`
contains a `.worktrees/` entry — add it if missing, so worktree checkouts never end up in
version control.

For each **dependency group** (sub-features that can run in parallel):
  - For each sub-feature in the group, create its worktree from the epic branch:
    `git worktree add -b feature/$ARGUMENTS/$FEATURE .worktrees/$FEATURE epic/$ARGUMENTS`
    Crashed-run recovery:
    - `.worktrees/$FEATURE` already exists: reuse it only if it is a valid worktree checked out
      on `feature/$ARGUMENTS/$FEATURE` with a clean working tree
      (`git -C .worktrees/$FEATURE status --porcelain` prints nothing); otherwise **STOP and ask
      the user** before touching it.
    - Branch `feature/$ARGUMENTS/$FEATURE` already exists but the directory does not (worktree
      deleted, or removed before its branch merged): run `git worktree prune` to clear any stale
      registration, then attach to the existing branch **without `-b`**:
      `git worktree add .worktrees/$FEATURE feature/$ARGUMENTS/$FEATURE`.
      Never delete or `-B` an existing sub-feature branch — it may hold the crashed run's
      commits; if in doubt, **STOP and ask the user**.
  - Update `STATE.md` (mark the group's sub-features `in progress`), then spawn one developer
    Task agent per sub-feature in the group with this instruction:

> "You are a developer agent implementing the sub-feature `$FEATURE` as part of the epic `$ARGUMENTS`.
> 1. Your working directory is the git worktree `.worktrees/$FEATURE`, already checked out on branch `feature/$ARGUMENTS/$FEATURE`. Do **all** file operations inside that worktree — never touch the main working tree.
> 2. Load scope context files for [backend/frontend/fullstack]
> 3. Read the approved specs under `.ai/features/$ARGUMENTS/$FEATURE/` — `requirement-spec.md`, `user-stories.md`, `test-specs.md`, and `design/design-spec.md` if present (build the UI against it).
> 4. Read `.ai/features/$ARGUMENTS/epic-breakdown.md` to understand what other sub-features exist and avoid overlap
> 5. Create the technical spec under `.ai/features/$ARGUMENTS/$FEATURE/technical-specs/` (split backend.md / frontend.md if fullstack), then implement following all standards
> 6. Verify per the loaded scope — write & run tests where the scope has a runner, else confirm a clean build + drive the flow manually; generate a report at `.ai/features/$ARGUMENTS/$FEATURE/test-specs/test-report.md`
> 7. Write the deploy notes at `.ai/features/$ARGUMENTS/$FEATURE/deploy-notes.md` from `.ai/templates/deploy-notes.md` — **inside this worktree**, not the main working tree (a stray copy there is invisible from here and would block the Phase E merge as an untracked-file conflict). Stamp them with the **Fix version** from the Source issue block of `.ai/features/$ARGUMENTS/$FEATURE/requirement-spec.md` (`unknown — to be confirmed` if that is what it says or the field is absent — never guess a version), name the target deployment-guide section, and if this sub-feature needs nothing beyond the standard pipeline run still write the file with an explicit *No deploy impact* line. Never a secret — `<placeholders>` only.
> 8. Commit on `feature/$ARGUMENTS/$FEATURE` with message: `feat($FEATURE): [what was implemented]` — include the artifacts you wrote under `.ai/features/$ARGUMENTS/$FEATURE/` (technical specs, test report, deploy notes); the worktree is discarded after merge, so uncommitted work is lost.
> Return: branch name, commit hash, and a one-paragraph summary of what was built."

  - Wait for all agents in the group to complete before starting the next dependency group.
  - After each group completes, update `STATE.md`: mark the group's sub-features `implemented`
    and set `## Next action`. (The epic `STATE.md` lives in the **main** working tree and is
    maintained by the parent only — spawned agents never edit it.) Each sub-feature's outputs
    (technical specs, test report, deploy notes) live as commits on its branch — the parent
    reads them only after the Phase E merge brings them into `epic/$ARGUMENTS`.

### Phase E — Sequential Merge into Epic Branch

For each sub-feature branch (in dependency order):
1. Merge `feature/$ARGUMENTS/$FEATURE` into `epic/$ARGUMENTS`
2. Resolve any conflicts before merging the next branch
3. After each merge, re-verify integration — run tests where a scope has a runner, otherwise a clean build plus a manual/driven smoke of the affected journeys
4. Remove the sub-feature's worktree: `git worktree remove .worktrees/$FEATURE` (if removal fails
   because the worktree is dirty, STOP and ask the user — do not force-remove)
5. Update `STATE.md`: mark the sub-feature `merged` and set `## Next action`

After all merges, run `git worktree prune`.

### Phase F — Final Review and PR

0. **Review & security gate (parallel)** — spawn both agents concurrently on the full diff
   of `epic/$ARGUMENTS` vs base (`git diff origin/[base-branch]...epic/$ARGUMENTS`). They are
   read-only on the same diff and do not conflict.

   - **Security scanner** — spawn a `security-scanner` Task agent:
     > "Run a security scan on `git diff origin/[base-branch]...epic/$ARGUMENTS`. Scope: fullstack. Apply the full security-agent checklist. Output a security report."

   - **Reviewer** — spawn a `reviewer` Task agent:
     > "Review the full epic diff for `$ARGUMENTS` (`git diff origin/[base-branch]...epic/$ARGUMENTS`) against the sub-feature technical specs. Apply the full reviewer checklist. Output a structured review with BLOCKER/WARNING/SUGGESTION/PRAISE findings and an overall verdict."

   Wait for both agents to complete. Include CRITICAL and HIGH findings in the {{PR_TERM}}
   description (step 1 below). CRITICAL findings must be resolved before creating the {{PR_TERM}}.
1. Write `.ai/features/$ARGUMENTS/pr-description.md` — a comprehensive {{PR_TERM}} description covering:
   - What the epic delivers (user-facing summary)
   - List of sub-features included, each with a brief description
   - Testing summary (all sub-feature test reports)
   - Breaking changes (if any)
   - How to test end-to-end
2. **STOP** — show the {{PR_TERM}} description to the user. Get confirmation before creating it.
3. Create the {{PR_TERM}} for `epic/$ARGUMENTS` → base branch with the confirmed description.
4. Update `STATE.md`: mark Phase F (and all phases) done, record the {{PR_TERM}} gate outcome
   under `## Decisions`, and set `## Next action` to `None — epic complete`.

---

This workflow **generates no user stories, epic breakdowns, or test specs** — if they're missing,
STOP and direct the user to `/ba` and `/qa`. Do not stop or skip any phase otherwise. Do not start
implementation (Phase D) without explicit user approval (end of Phase A). Do not create the
{{PR_TERM}} without user approval of its description.
