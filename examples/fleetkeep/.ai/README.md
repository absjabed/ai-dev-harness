# `.ai/` — Knowledge Layer

> The **what and why** of your project, written once and read by every agent.

Everything in `.ai/` is **Markdown only**. Nothing here executes — it is *read*. Commands and
sub-agents in [`.claude/`](../.claude/README.md) pull these files in at run time via `@.ai/...`
includes, so all project-specific knowledge lives here and the execution layer stays generic.

> ~70% of this layer is portable as-is. You fill in the ~30% that is truly project-specific
> (stack, conventions, domain, branding). See the [Customization Guide](CUSTOMIZATION.md) or run
> `/init-project` to fill every skeleton automatically.

← Back to the [main README](../README.md) · Command list in [`COMMANDS.md`](../COMMANDS.md)

---

## Directory map

| Path | What it holds | Fill in? |
|------|---------------|----------|
| [`config/`](config) | Project identity, tech stack, commands, conventions, and **branding**. Split per scope (`backend/`, `frontend/`) plus a shared `project-config.md`, `branding.md`, and `current-scope.md`. | ✅ yes |
| [`context/`](context) | The product *what/why*: `project-overview.md`, `architecture.md`, `business-rules.md` — per scope (`backend/`, `frontend/`) and shared. | ✅ yes |
| [`standards/universal/`](standards/universal) | Language-agnostic principles: coding, git-workflow, testing, security-baseline, api-design, accessibility, ui/ux, frontend-design — plus `vcs/` provider profiles (`github`, `gitlab`, `bitbucket`). | portable |
| [`standards/project/`](standards/project) | Your stack's concrete rules: `backend/` (+ `node/`, `dotnet/`) and `frontend/` (+ `react/`, `angular/`, and a `design/` system). | ✅ yes |
| [`agents/`](agents) | Agent **role definitions** — persona + instructions for each specialist (BA, architect, developer, designer, QA, reviewer, security, devops, PM, release, orchestrator, the BA/QA studios, plus the meta-roles: harness-engineer, critic, and harness-guide). Pure knowledge; runs nothing. | portable |
| [`workflows/`](workflows) | Process playbooks: feature-development, bug-fixing, hotfix-process, runtime-verification, release-process, code-review, story-generation, harness-improvement. | portable |
| [`templates/`](templates) | Output shapes: user-story, technical-spec, adr, test-plan, design-spec, pr-description, deploy-notes (per-feature deploy impact, unbranded), release-checklist, deployment-guide + release-guides-index (the optional human-facing release guide), security-report, e2e-report (runtime verification results), feature-state (machine-maintained workflow state, unbranded), and the shared `artifact-header.md`. | portable |
| [`branding/`](branding) | Your logo and branding assets, prepended to every generated document — except the unbranded internal ones (`STATE.md`, `deploy-notes.md`). | ✅ yes |
| [`features/`](features) | Where feature artifacts land (`requirement-spec.md`, `user-stories.md`, `test-specs.md`, `epic-breakdown.md`, `deploy-notes.md`, …). Seeded from `TEMPLATE.md`. | generated |
| [`memory/`](memory) | Append-only logs: `decisions.md` (non-obvious, precedent-setting decisions), `learnings.md` (reusable project learnings), `design-taste.md` (approved/rejected design patterns). | grows over time |
| [`CUSTOMIZATION.md`](CUSTOMIZATION.md) | How to tailor the template, organized by axis. | reference |

---

## Key concepts

- **Scope model** — `config/current-scope.md` holds `auto` (detect per request) or a forced scope.
  Set it for a session with `/utils:scope`. Single-project repos collapse to one scope.
- **Universal vs project standards** — universal principles (`standards/universal/`) are portable and
  rarely change; project standards (`standards/project/`) capture *your* stack's concrete rules.
- **Template vs reference files** — the system reads only the **template** files
  (e.g. `standards/project/backend/tech-specific.md`). The per-stack subfolders (`node/`, `dotnet/`,
  `react/`, `angular/`) are **reference-only**: copy the rules for your stack into the template file.
- **Feature artifacts** — the studios author everything for a feature under `features/<slug>/`; the
  workflows consume it. This is the shared hand-off surface between BA → QA → dev.
- **Branding** — `config/branding.md` + `templates/artifact-header.md` prepend your logo/name/footer
  to every generated document — except the two unbranded internal files under `features/<slug>/`,
  `STATE.md` and `deploy-notes.md`.
- **Release flow** — `/ba` records each spec's fix version; each feature, bugfix and hotfix writes
  `deploy-notes.md`; the release path collects notes by fix version into its artifacts and, if
  switched on in `config/project-config.md`, a deployment guide under `docs/release/`.
- **Decision memory** — `memory/decisions.md` records decisions worth remembering across sessions;
  `memory/learnings.md` records reusable, non-obvious learnings (add one with `/utils:learn`); and
  `memory/design-taste.md` records approved/rejected design patterns the Designer reads and appends to.
