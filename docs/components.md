# Component Reference

Every moving part of the harness: what it is, when it runs, and what you get back.

- [The two layers](#the-two-layers)
- [Commands](#commands)
- [Agent personas](#agent-personas-aiagents)
- [Sub-agents](#sub-agents-claudeagents)
- [Hooks](#hooks-claudehooks)
- [Workflows](#workflow-playbooks-aiworkflows)
- [Standards](#standards-aistandards)
- [Templates](#templates-aitemplates)
- [Config & context](#config--context)
- [Memory](#memory)
- [Scope model](#scope-model)
- [Where artifacts land](#where-artifacts-land)

---

## The two layers

| Layer | Path | Nature | Contains |
|---|---|---|---|
| Knowledge | `.ai/` | Markdown only — **nothing executes** | Agent personas, workflow playbooks, engineering standards, output templates, project config/context, memory logs |
| Execution | `.claude/` | What Claude Code actually runs | Slash commands, sub-agent definitions, eight hooks, `settings.json`, helper scripts |

A command in `.claude/` pulls personas and standards from `.ai/` with `@`-includes, so the same
command behaves differently — correctly — per project.

---

## Commands

26 commands in five families. Type them in Claude Code as `/<name> <arguments>`.

### Studios — human-in-the-loop, you drive these

| Command | Purpose | Produces |
|---|---|---|
| `/init-project` | Interviews you about stack, conventions, VCS and branding, then fills every skeleton and writes `hooks.env` | A configured harness; an entry in `.ai/memory/decisions.md` |
| `/ba <slug>` | BA Studio — interviews you as a business analyst | `requirement-spec.md` + `user-stories.md`; for an epic, `epic-breakdown.md` plus those two per sub-feature |
| `/qa <slug>` | QA Studio — turns the requirement + stories into a test specification | `test-specs.md` (per sub-feature for an epic) |

### Specialists — `/agents:*`

| Command | Runs | Produces |
|---|---|---|
| `/agents:architect` | Architect — solution design, technical decisions | Design notes; ADRs via the ADR template |
| `/agents:ba` | Business Analyst (non-interactive) | Requirements and stories |
| `/agents:design` | Designer — UX → visual design → **Artifact preview** → approval loop | `design/design-spec.md` with the approved Artifact URL |
| `/agents:dev` | Developer — end-to-end implementation | Code changes |
| `/agents:devops` | DevOps — CI/CD, deployment, infrastructure | Pipeline/IaC changes, deploy checklists |
| `/agents:pm` | Project Manager — status, planning, changelogs | Status reports |
| `/agents:qa` | QA — writes tests, finds bugs, validates quality | Tests and a verification report |
| `/agents:release-manager` | Release preparation | Release notes, migration plan, rollback plan, deployment checklist |
| `/agents:review` | Code Reviewer on recent changes or a target | `review-report.md` — BLOCKER / WARNING / SUGGESTION / PRAISE with file:line |
| `/agents:security` | Dedicated security audit | `security-report.md` with severities |

### Workflows — `/workflows:*`

| Command | Purpose | Gates |
|---|---|---|
| `/workflows:feature <slug>` | End-to-end feature or epic delivery; consumes BA/QA artifacts; parallelises where safe | **5 STOP gates**: technical spec, design, verification, commit, PR |
| `/workflows:bugfix "<symptom>"` | Reproduce → root cause → fix → verify → review → commit | Verification, then a **review gate** — BLOCKER findings block the commit |
| `/workflows:hotfix "<symptom>"` | Fast, minimal, safe production fix; forward-port required | Minimal-change discipline, plus a **review gate** before the PR — skippable only with explicit human approval, never silently |
| `/workflows:release <version>` | Security gate, release artifacts, changelog, version bump | Security findings block the release |

### Utilities — `/utils:*`

| Command | Purpose |
|---|---|
| `/utils:status` | Project health — tests, TODOs, outdated deps, git status |
| `/utils:standup` | Standup report from recent git activity |
| `/utils:changelog` | Changelog from git commits |
| `/utils:docs` | Generate or update documentation for a module or the project |
| `/utils:docs-serve` | Serve `.ai/` as a local MkDocs site on `http://localhost:8000` |
| `/utils:learn "<lesson>"` | Append a one-line learning to the append-only log |
| `/utils:scope <backend\|frontend\|fullstack\|auto>` | Force a scope for the session |

### Harness maintenance — `/harness:*`

| Command | Purpose |
|---|---|
| `/harness:ask "<question>"` | Read-only Q&A about the harness — usage, architecture, tuning, extension |
| `/harness:improve "<change>"` | Change the harness through an author → critic → revise → recheck loop with an integration audit and a commit gate |

---

## Agent personas (`.ai/agents/`)

Markdown role definitions — responsibilities, method, output format, and explicit "never do" lists.
Commands `@`-include them; they are not separately invocable.

| Persona | Role |
|---|---|
| `architect-agent` | System architecture and technical decisions |
| `ba-agent` | Requirements and user stories (non-interactive) |
| `ba-studio-agent` | Interactive BA, operated directly by a human analyst |
| `critic-agent` | Adversarial verifier — exists to **break** authored work |
| `designer-agent` | UI/UX design, Artifact previews, design-system and accessibility validation |
| `developer-agent` | Implementation against an approved spec |
| `devops-agent` | CI/CD, deployment surface, infrastructure |
| `harness-engineer-agent` | Authors changes to the harness itself |
| `harness-guide-agent` | Explains the harness (powers `/harness:ask`) |
| `orchestrator-agent` | Master coordinator; decomposes and delegates |
| `pm-agent` | Status, planning, reporting |
| `qa-agent` | Test strategy and execution |
| `qa-studio-agent` | Interactive test design, operated by a tester |
| `release-agent` | Release packaging and deployment checklists |
| `reviewer-agent` | Code review method and severity vocabulary |
| `security-agent` | Security review checklist and reporting |

---

## Sub-agents (`.claude/agents/`)

Spawned automatically by commands and workflows, each with its own context window and a **restricted
tool set** — least privilege is deliberate: a reviewer that cannot write cannot "helpfully" fix
things mid-review.

| Sub-agent | Tools | Model | Memory | Spawned by |
|---|---|---|---|---|
| `orchestrator` | delegates to developer, reviewer, security-scanner | inherit | — | Complex multi-part tasks |
| `developer` | Read, Write, Edit, Bash | inherit | — | Feature/bugfix implementation |
| `reviewer` | Read, Bash (**read-only**) | haiku | project | Review gates in `/workflows:feature`, `/workflows:bugfix` and `/workflows:hotfix` |
| `security-scanner` | Read, Bash, Write | sonnet | project | Feature and release gates |
| `qa-runner` | Read, Write, Edit, Bash, Playwright MCP | inherit | — | Test writing/running, live browser checks |
| `release-manager` | Read, Write, Edit, Bash | sonnet | — | `/workflows:release` |
| `critic` | Read, Bash (**read-only**) | inherit | project | `/harness:improve` |
| `harness-engineer` | Read, Write, Edit, Bash | inherit | project | `/harness:improve` work packages |

`memory: project` means Claude Code maintains a persistent `.claude/agent-memory/<agent>/` folder for
that sub-agent — it accumulates project-specific facts across sessions. It is runtime state and is
git-ignored.

---

## Hooks (`.claude/hooks/`)

Eight bash scripts wired through `.claude/settings.json`. They run automatically — this is the part
of the harness that works whether or not the model cooperates.

| Hook | Event | What it does |
|---|---|---|
| `pre-tool-use.sh` | PreToolUse (Edit/Write/MultiEdit) | Safety warnings and blocks before a file is edited — generated migrations, sensitive config |
| `git-guard.sh` | PreToolUse (Bash) | **Blocks** `git push --force`, `git reset --hard`, pushes to protected branches, and deploys to the production stage. The first two are **unconditional — there is no override flag**: a deliberate history rewrite has to be run from a terminal outside Claude Code |
| `post-tool-use.sh` | PostToolUse (Edit/Write/MultiEdit) | Runs type-check + lint for the edited package; runs the domain checks (tenant isolation, frontend env, design tokens, TDD nudge) |
| `post-tool-batch.sh` | PostToolBatch | Full-project type-check after a batch of parallel edits |
| `post-tool-failure.sh` | PostToolUseFailure | Classifies a failed tool call (type error, lint, test) and feeds back a hint |
| `stop-check.sh` | Stop | Reminds about uncommitted changes on feature/epic branches |
| `user-prompt-context.sh` | UserPromptSubmit | Injects current branch + active scope into context before each prompt |
| `compact-restore.sh` | SessionStart (compact) | Re-injects orientation after context compaction |

### `hooks.env` — the single config

Every hook sources it and **skips** a check whose value is empty or whose `*_CHECK` is `"off"`.
An un-customised file is inert-safe: nothing blocks, nothing warns.

| Group | Keys |
|---|---|
| Version control | `PROTECTED_BRANCHES`, `WORK_BRANCH_PREFIXES`, `VCS_CLI`, `PR_TERM` |
| Deploy guard | `DEPLOY_CMD`, `PROD_STAGE` |
| Repo layout | `PACKAGE_DIRS`, `BACKEND_DIR`, `FRONTEND_DIR` |
| Quality commands | `TYPECHECK_CMD`, `LINT_CMD` |
| Sensitive files | `MIGRATIONS_GLOB`, `MIGRATIONS_REGEN_CMD`, `SENSITIVE_CONFIG_GLOBS` |
| Tenant isolation | `TENANT_ISOLATION_CHECK`, `TENANT_KEY` |
| Frontend env | `FRONTEND_ENV_CHECK`, `FRONTEND_ENV_BAD_PATTERN`, `FRONTEND_ENV_GOOD_HINT` |
| Design tokens | `DESIGN_TOKEN_CHECK`, `DESIGN_TOKEN_DOC`, `DESIGN_TOKEN_EXEMPT_GLOBS` |
| TDD nudge | `TDD_CHECK`, `TEST_FILE_PATTERNS`, `TDD_EXEMPT_GLOBS` |

Warnings go to stderr and are non-blocking; only `git-guard.sh` and the sensitive-file rules hard-block.

---

## Workflow playbooks (`.ai/workflows/`)

Method documents the commands follow. Editing a playbook changes how the matching command behaves.

| Playbook | Covers |
|---|---|
| `feature-development.md` | The 9-step feature path, the epic path, and the gate definitions |
| `bug-fixing.md` | Reproduce → root cause → guard → fix → verify → blast radius → review → commit |
| `hotfix-process.md` | Branch from production, minimal change, review gate, land via PR, forward-port, post-mortem |
| `release-process.md` | Changelog, verification, dependency/secret check, version bump, tag, notes |
| `code-review.md` | Review order and the BLOCKER/WARNING/SUGGESTION/PRAISE vocabulary |
| `story-generation.md` | How requirements become stories |
| `harness-improvement.md` | The invariants any change to the harness must preserve |

### The epic path

When `/ba` produced an `epic-breakdown.md`, `/workflows:feature` switches to six phases:

**A** validate inputs → **B** UI/UX design gate → **C** create the epic branch →
**D** parallel implementation, dependency-aware, each sub-feature in its own **git worktree** under
`.worktrees/` → **E** sequential merge into the epic branch → **F** review + security on the full
epic diff, then one PR.

Worktrees only see committed files, which is why planning artifacts are committed onto the epic
branch first.

---

## Standards (`.ai/standards/`)

| Tree | Nature |
|---|---|
| `universal/` | Portable engineering principles — coding, API design, security baseline, testing, accessibility, UI/UX, frontend design craft, git workflow |
| `universal/vcs/` | Provider profiles (GitHub / GitLab / Bitbucket) — **reference-only**, copy values from them |
| `project/tech-specific.md` | Your stack's concrete rules — the file the agents actually read |
| `project/{backend,frontend}/tech-specific.md` | Per-scope versions when the repo has two scopes |
| `project/frontend/design/` | The closed design system: `palette.md`, `design-tokens.md`, `component-specs.md`, `README.md` |
| `project/**/<stack>/` | Per-stack worked examples (dotnet, node, react, angular) — **reference-only** |

The design subtree governs **whatever UI exists**, including a server-rendered one. Delete it only
for a headless project.

---

## Templates (`.ai/templates/`)

Output shapes every agent fills in, so artifacts look the same across people and projects.

| Template | Used for |
|---|---|
| `artifact-header.md` | The branded header prepended to every generated document |
| `technical-spec.md` | The spec approved at the first gate |
| `design-spec.md` | Design decisions + Artifact URL + approved version |
| `user-story.md` | Story format with acceptance criteria |
| `test-plan.md` | Test specification structure |
| `security-report.md` | Findings with severity |
| `pr-description.md` | Pull/merge request body |
| `release-checklist.md` | Deployment checklist |
| `adr.md` | Architecture Decision Record |
| `feature-state.md` | `STATE.md` — the workflow's resumable state file |

---

## Config & context

| File | Holds |
|---|---|
| `.ai/config/project-config.md` | Identity, stack, commands, structure, conventions, "never do" rules |
| `.ai/config/{backend,frontend}/project-config.md` | The per-scope versions |
| `.ai/config/current-scope.md` | Active scope (`auto` by default) — written by `/utils:scope` |
| `.ai/config/branding.md` | Company, product, logo, colour, footer for generated documents |
| `.ai/context/project-overview.md` | What the system is, who uses it, core journeys, definition of done |
| `.ai/context/architecture.md` | Request flow, layering, data stores, auth, async, infrastructure, known gaps |
| `.ai/context/business-rules.md` | Domain invariants, tenancy and authorization rules |

Each context file also exists per scope when the repo has two.

---

## Memory

| Location | Written by | Purpose |
|---|---|---|
| `.ai/memory/decisions.md` | Agents, `/init-project` | Precedent-setting or hard-to-reverse decisions, with the reason |
| `.ai/memory/learnings.md` | Agents, `/utils:learn` | Non-obvious, reusable lessons — pitfalls, approaches abandoned and why |
| `.ai/memory/design-taste.md` | Designer agent | Approved and rejected design choices, in the user's own words |
| `.claude/agent-memory/<agent>/` | Claude Code (runtime) | Per-sub-agent project facts; git-ignored, recreated automatically |

The first three are committed. They are the harness's institutional memory — the designer reads
design-taste before proposing, so a rejected pattern stays rejected.

---

## Scope model

Every context-loading command first resolves a scope:

1. If `.ai/config/current-scope.md` starts with `# Forced scope:`, that wins.
2. Otherwise the command infers **backend / frontend / fullstack** from your request using the
   stack-signal keywords filled in at init.
3. It then loads only that scope's config, context and standards.

This keeps context small and stops a backend task from dragging the whole design system into the
window. Force it for a session with `/utils:scope backend`; return with `/utils:scope auto`.

---

## Where artifacts land

```
.ai/features/<slug>/
├── requirement-spec.md          # /ba
├── user-stories.md              # /ba
├── epic-breakdown.md            # /ba, epics only
├── test-specs.md                # /qa
├── STATE.md                     # the workflow — resumable state, never branded
├── technical-specs/             # backend.md / frontend.md when fullstack
├── design/design-spec.md        # /agents:design
├── test-specs/test-report.md    # verification: what was and wasn't checked
├── review-report.md             # reviewer sub-agent
├── security-report.md           # security-scanner sub-agent
└── pr-description.md            # the final report
```

Standalone runs write to `.ai/reports/`; releases write to `.ai/releases/<version>/`. Every document
except `STATE.md` opens with your branded header.
