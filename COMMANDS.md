# Command Reference

This page lists every command you can run once the agent system is set up in your repo. Type a command
in Claude Code as `/command <arguments>`, and it loads the relevant project knowledge from `.ai/` and runs.

> If you are new to the repo, run `/init-project` once to fill in the template, then use the commands below.
> If the system is not set up yet, start at [README.md → Setup](README.md#setup) (prerequisites, install, verify).
> Commands live in `.claude/commands/`; the specialists they drive are defined in `.ai/agents/`.

---

## 1. Studios: human-in-the-loop (you drive these directly)

These are interactive: they interview you, then write branded artifacts into `.ai/features/<feature>/`.

| Command | Who uses it | What it does | Arguments |
|---------|-------------|--------------|-----------|
| `/init-project` | Whoever sets up the repo | Interviews you about stack, conventions, VCS, and branding, then fills every skeleton, writes `.claude/hooks/hooks.env`, and configures branding | `[one-line project description]` (optional) |
| `/ba` | Business Analyst | Interviews the BA, decides single feature vs epic, then writes `requirement-spec.md` + `user-stories.md` (and, for an epic, `epic-breakdown.md` + per-sub-feature specs); every spec records the release Fix version in its `## Source issue` block | `<feature-name> [rough requirement or issue key]` |
| `/qa` | QA / Tester | Reads the feature's requirement + user stories, interviews for gaps, writes `test-specs.md` (one per sub-feature for an epic) | `<feature-name>` |

**Example**
```
/ba checkout-flow  "users should be able to pay with saved cards"
/qa checkout-flow
/workflows:feature checkout-flow
```

---

## 2. Specialist agents: `/agents:*`

Single-specialist runs. Each loads the matching role from `.ai/agents/` plus the project context for the
detected scope (backend / frontend / fullstack).

| Command | Who uses it | What it does |
|---------|-------------|--------------|
| `/agents:ba` | BA | Generate user stories & requirements (lightweight, non-interactive counterpart to `/ba`) |
| `/agents:architect` | Architect / Lead | Design solutions and make technical decisions (writes ADRs / tech specs) |
| `/agents:dev` | Developer | Implement a feature end-to-end (code + tests + commit) |
| `/agents:design` | Designer / FE | Produce a UI/UX design + a Claude Artifact preview and run the approval loop |
| `/agents:qa` | QA | Write tests, find bugs, validate quality |
| `/agents:review` | Any dev | Read-only code review of recent changes or a specific file/module |
| `/agents:security` | Any dev / Security | Security audit of current changes, a path, or the full diff |
| `/agents:devops` | DevOps | CI/CD, deployment, infrastructure tasks (advise-only by default; see note) |
| `/agents:pm` | PM | Status reports, planning, changelogs |
| `/agents:release-manager` | Release owner | Prepare a release package (notes, migration, rollback, checklist) from the in-scope deploy notes, plus the deployment guide if switched on |

> **DevOps execute mode:** `/agents:devops` is advise-only (no shell) by default. Toggle execution with
> `.claude/scripts/devops-mode.sh on` (and `off` / `status`). It still asks before each command.

---

## 3. Workflows: `/workflows:*`

Multi-step pipelines that chain several agents with human approval gates.

| Command | Who uses it | What it does |
|---------|-------------|--------------|
| `/workflows:feature` | Lead / Dev | End-to-end feature build. Detects single feature vs epic (by whether `epic-breakdown.md` exists) and consumes the `/ba` + `/qa` artifacts. It does **not** generate stories, epic breakdowns, or test specs; if they're missing, it stops and asks you to run `/ba` / `/qa`. Then technical spec → design gate → implement → test → review + security gate (parallel) → document & deploy notes → runtime verification (API / UI / DB) → {PR}. Parallelises epic sub-features in isolated git worktrees. Keeps machine state at `.ai/features/<slug>/STATE.md` and resumes interrupted runs; offers opt-in per-task atomic commits at spec approval (default off). |
| `/workflows:bugfix` | Dev | Reproduce → root cause → fix → verify → deploy notes → review → runtime checks → commit |
| `/workflows:hotfix` | Dev / On-call | Emergency fix (fast, minimal, safe); writes deploy notes, then goes through review and a smoke check before it lands |
| `/workflows:verify` | Dev | Runtime verification on demand, for ad-hoc work, a `/agents:dev` change, or a re-check. Proposes API calls / a real-browser UI run (Claude in Chrome, else Playwright) / read-only DB checks from the change, confirms the plan with you, runs them against the test environment, and writes an e2e report. Never commits |
| `/workflows:release` | Release owner | Security gate + release artifacts (parallel) → changelog → version bump → deployment guide (+ `.docx`) if switched on |

**Example**
```
/workflows:feature ticket-management     # requires requirement-spec.md + user-stories.md + test-specs.md from /ba and /qa
/workflows:bugfix "login redirect loops on expired token"
```

---

## 4. Utilities: `/utils:*`

Everyday helpers. Most are read-only.

| Command | What it does |
|---------|--------------|
| `/utils:status` | Project health check: tests, TODOs, outdated deps, git status |
| `/utils:standup` | Standup report from recent git activity |
| `/utils:changelog` | Changelog from git commits |
| `/utils:docs` | Generate or update documentation for a module or the whole project |
| `/utils:docs-serve` | Serve the `.ai/` knowledge base as a local MkDocs site (http://localhost:8000) |
| `/utils:scope` | Force a session scope: `backend` / `frontend` / `fullstack` / `auto` (writes `.ai/config/current-scope.md`) |
| `/utils:learn` | Record a one-line project learning in the append-only `.ai/memory/learnings.md`, or as a path-scoped rule in `.claude/rules/` if it only applies to one area of the code |

---

## 5. Harness maintenance: `/harness:*`

These commands are for understanding and changing the harness itself (agents, commands, workflows, hooks,
docs). They are not for product code.

| Command | Who uses it | What it does |
|---------|-------------|--------------|
| `/harness:ask` | Anyone using the harness | Read-only Q&A about the harness: how to use, tune, or extend it. Answers from the repo's own docs and cites exact file paths; redirects product-code questions to the right specialist command. Persona: `.ai/agents/harness-guide-agent.md`. |
| `/harness:improve` | Whoever maintains the harness | Plans work packages, spawns `harness-engineer` authors and `critic` verifiers in an author → critic → revise → recheck loop, runs an integration audit, then stops for approval before committing on a `feature/*` branch. Process and invariants: `.ai/workflows/harness-improvement.md`. Works with or without `examples/` (mirror steps are skipped once the example folder is deleted). |

---

## 6. Sub-agents (`.claude/agents/`): spawned automatically

You don't usually type these; workflows and the orchestrator spawn them as Task agents. They are listed
here so you know what runs under the hood.

| Sub-agent | Role |
|-----------|------|
| `orchestrator` | Master coordinator that delegates to the specialists below |
| `developer` | Focused code-writing for implementation tasks |
| `reviewer` | Read-only code review |
| `qa-runner` | Test-running/writing with live browser access via Playwright (runtime verification itself runs in the orchestrating session) |
| `security-scanner` | Read-only security scan; the pre-commit / pre-release gate |
| `release-manager` | Generates release notes, migration plan, rollback plan, and checklist, plus the deployment guide on request |
| `harness-engineer` | Authors changes to the harness itself. Spawned per work package by `/harness:improve` |
| `critic` | Read-only adversarial verifier of authored work. Spawned by `/harness:improve`, and reusable anywhere a change set or spec needs breaking before it lands |

---

## Typical flows

- New feature (BA/QA hand-off is required): `/ba <feature>` → `/qa <feature>` → `/workflows:feature <feature>`. The workflow consumes those artifacts and won't regenerate them, so run the studios first.
- Quick change (no formal specs): use `/agents:dev "<change>"` for a direct implementation that doesn't need the studio artifacts.
- Bug: `/workflows:bugfix "<symptom>"`
- Release: `/agents:security` (or the workflow's gate) → `/workflows:release <version>`
- Check in: `/utils:status`, `/utils:standup`

## Where artifacts land

Everything the studios and workflows produce is written under `.ai/features/<feature>/`, for example
`requirement-spec.md`, `user-stories.md`, `test-specs.md`, `technical-specs/`, `design/design-spec.md`,
`review-report.md`, `security-report.md`, `deploy-notes.md`, `pr-description.md`, plus the workflow's
`STATE.md`. Every document starts with your branded header (configured in `.ai/config/branding.md`),
except the two unbranded internal files: `STATE.md` (workflow state) and `deploy-notes.md` (deploy
input the release path reads).

The release path writes outside that tree: `/workflows:release` puts its internal artifacts in
`.ai/releases/<version>/` and, if the deployment guide is switched on (`.ai/config/project-config.md`
→ Release deliverables), the human-facing guide in `docs/release/<version>/`.

## Notes for adopters

- Scope awareness: commands auto-detect backend / frontend / fullstack from your request and load
  only the relevant context. Force it for a session with `/utils:scope`.
- Model & effort: tune per-agent `model:` / effort in the frontmatter of `.claude/commands/**` and
  `.claude/agents/*`. Use cheaper models for mechanical work and stronger ones for review/architecture.
- Safety: destructive git/deploy commands and sensitive-file edits are guarded by `.claude/hooks/`
  (configured in `.claude/hooks/hooks.env`).
- Integrations: the template ships `.mcp.json` with Atlassian's remote MCP server (Jira/Confluence,
  OAuth, v2 endpoint; no secrets stored). Authenticate once via `/mcp` (again if you signed in to
  v1). When connected, `/ba` can ingest an issue
  key as the rough requirement, `/agents:pm` can enrich status from the board, and `/workflows:release`
  offers to transition released issues. Everything degrades gracefully when not connected, and every
  outward write is shown to you and confirmed first. If you don't use Jira, remove the server from
  `.mcp.json` (see CUSTOMIZATION.md axis 12).
- Full setup details are in [`README.md` → Setup](README.md#setup); the per-axis customization
  reference is [`CUSTOMIZATION.md`](.ai/CUSTOMIZATION.md).
