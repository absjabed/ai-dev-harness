# AI Harness

> Human-led. AI-powered. Governed by design.

AI Harness is an **AI-Driven Lifecycle (AI DLC)** framework that turns AI-assisted coding into a governed, repeatable software engineering process. It is a **template**: copy it into a repo, run `/init-project`, and the agents pick up that project's stack, standards and guardrails.

Instead of relying on ad-hoc prompts, AI Harness provides a structured delivery model where specialized AI agents collaborate throughout the Software Development Lifecycle (SDLC), following shared engineering standards, project knowledge, reusable workflows, and automated quality gates.

---

## Contents

- [Setup](#setup) — get the harness running in a repo
- [Vision](#vision)
- [Key Features](#key-features)
- [AI-Driven Lifecycle (AI DLC)](#ai-driven-lifecycle-ai-dlc)
- [Core Components](#core-components)
- [Repository Structure](#repository-structure)
- [Documentation](#documentation) — guides for each part of the system
- [Benefits](#benefits)
- [Guiding Principles](#guiding-principles)
- [Future Roadmap](#future-roadmap)
- [License](#license)

> **Start here:** **`docs/index.html`** *(template repo)* — the whole guide as one browsable page
> (setup, every component, troubleshooting, cheat sheet). Open it in a browser; no build step.
>
> **Or jump straight to a guide:** `docs/getting-started.md` *(template repo)* ·
> `docs/components.md` *(template repo)* · [`.ai/` Knowledge Layer](.ai/README.md) ·
> [`.claude/` Execution Layer](.claude/README.md) · [Command Reference](COMMANDS.md) ·
> [Customization Guide](.ai/CUSTOMIZATION.md)

---

## Setup

This repo ships as a **template**: every project-specific value is a `{{TOKEN}}` or a
`> [FILL IN: …]` block. Setup means filling those in once — `/init-project` does it by interview.

### Prerequisites

| Need | Why |
|---|---|
| **Claude Code** (CLI, desktop app, or IDE extension), opened at the repo root | The harness is a set of slash commands, sub-agents and hooks it loads per repo |
| **Bash** — Git Bash or WSL on Windows, on `PATH` | The 8 hooks in `.claude/hooks/` are `.sh` scripts. Without bash they fail silently and the guardrails don't run |
| **git** | Branch guards, changelog/release commands, and the epic workflow's worktrees |
| *(optional)* an MCP server connection | `.mcp.json` ships Atlassian (Jira/Confluence, OAuth). Authenticate once with `/mcp`. Everything degrades gracefully when not connected |

### 1. Put the harness in the repo

This repository **is** the template. Copy these into your project's repo root:

```
.ai/  .claude/  .mcp.json  CLAUDE.md  AGENTS.md  COMMANDS.md  README.md
```

`AGENTS.md` carries the same method for agents other than Claude Code — see
`docs/portability.md` *(template repo)*.

Optionally take `examples/fleetkeep/` along while you configure — `/init-project` offers to delete
it at the end. **Don't** copy this repo's `.gitignore`; it is written for the template itself. Your
project needs one line of its own — `.worktrees/` — because the epic path of `/workflows:feature`
builds each sub-feature in its own git worktree there. Do **not** ignore `.ai/features/`: that
workflow commits planning artifacts onto the epic branch, and worktrees only see committed files.

### 2. Fill the template

Run **`/init-project`** in Claude Code. It interviews you (identity & domain, repo topology, stack,
commands, conventions, version control, security, design system, branding, risk profile), substitutes
every token, replaces every `[FILL IN]` block, writes `.claude/hooks/hooks.env`, and records the
initialization in `.ai/memory/decisions.md`.

Prefer to do it by hand, or tweaking afterwards? [`.ai/CUSTOMIZATION.md`](.ai/CUSTOMIZATION.md) lists
all 12 variability axes — which files each touches and which tokens it owns. For a worked answer to
"what should this file actually look like when filled?", open the matching file under
`examples/fleetkeep/` *(template repo)*.

**Shape the tree to the project while you're there:**

- **Single-project repo** → delete the `backend/` and `frontend/` subfolders under `.ai/config/`,
  `.ai/context/` and `.ai/standards/project/`; scope detection collapses to one scope.
- **No UI at all** (headless / API-only) → delete `.ai/standards/project/frontend/design/`.
- The per-stack folders (`standards/project/backend/{dotnet,node}`,
  `standards/project/frontend/{react,angular}`) and `standards/universal/vcs/*` are **reference-only**
  — the agents never read them. Copy what fits into the `tech-specific.md` template file, then delete
  the stacks you don't use.

### 3. Verify

```bash
grep -rn '{{' .ai CLAUDE.md .claude/hooks/hooks.env | grep -vE 'CUSTOMIZATION.md|agents/harness-|workflows/harness-improvement|templates/artifact-header|standards/project/[a-z]+/(dotnet|node|react|angular)/|standards/universal/vcs/|examples/'
```

Nothing returned means no unfilled tokens are left. (The excluded paths are reference-only by design:
`CUSTOMIZATION.md` documents token *names*, and the per-stack / VCS-provider files are examples you
copy from.)

Check the guardrails are live too: `.claude/hooks/hooks.env` is the single config for all hook
behavior, and it is **inert-safe** — a blank value or `*_CHECK="off"` skips that check. An
un-customized file blocks nothing, so set `PROTECTED_BRANCHES`, `TYPECHECK_CMD` / `LINT_CMD` and the
domain checks you want enforced.

### 4. Start working

`/ba <feature>` → `/qa <feature>` → `/workflows:feature <feature>`. See
[`COMMANDS.md`](COMMANDS.md) for every command and [Typical flows](COMMANDS.md#typical-flows) — or
`docs/index.html` *(template repo)* for the same ground with the gates and expectations spelled out.

> **Working in this template repo itself** (rather than in a project you copied it into)? Then the
> `{{TOKEN}}` and `[FILL IN]` blocks are the product, not a to-do list — leave them. Change the
> harness with `/harness:improve`, and keep `examples/fleetkeep/` in step: portable files there are
> verbatim copies, so the eight `hooks/*.sh`, `settings.json` and `scripts/` must stay
> byte-identical to the root (invariant 6 in `.ai/workflows/harness-improvement.md`).

---

## Vision

Build enterprise software faster, safer, and more consistently by combining the expertise of engineers with the capabilities of AI.

---

## Key Features

- 🤖 Multi-Agent Software Engineering
- 📚 Shared Project Knowledge Base
- 📐 Engineering Standards & Best Practices
- 🔄 Standardized Delivery Workflows
- 📝 Reusable Templates
- 🛡️ Automated Quality & Security Guardrails
- 🚀 AI-Native Software Delivery
- 🔍 Architecture & Business Context Awareness

---

## AI-Driven Lifecycle (AI DLC)

AI Harness orchestrates specialist AI agents across the complete software delivery lifecycle.

```
Business Need
      │
      ▼
Business Analyst Agent
      │
      ▼
Architect Agent
      │
      ▼
Developer Agent
      │
      ▼
QA Agent
      │
      ▼
Reviewer Agent
      │
      ▼
Production Ready
```

At every stage, engineers remain in control while AI accelerates execution and governance ensures quality.

---

## Core Components

### Knowledge Base

A portable Markdown-based knowledge repository containing:

- Architecture
- Business Rules
- Coding Standards
- Security Standards
- API Standards
- Decision Records
- Templates
- Workflows

---

### AI Agents

AI Harness includes specialist AI agents such as:

- Business Analyst
- Solution Architect
- UI/UX Designer
- Software Developer
- QA Engineer
- Code Reviewer
- DevOps Engineer
- Project Manager

Each agent has clearly defined responsibilities, workflows, and guardrails.

---

### Engineering Standards

Every generated artifact follows predefined standards including:

- Coding Standards
- API Standards
- Security Guidelines
- Testing Standards
- Git Standards
- Documentation Standards

---

### Automated Guardrails

AI Harness automatically prevents unsafe operations including:

- Force pushes
- Direct production deployments
- Invalid migrations
- Security violations
- Missing test coverage
- Low-quality pull requests

---

## Repository Structure

```
.ai/                      → see .ai/README.md   (Knowledge Layer)
 ├── agents/
 ├── config/
 ├── context/
 ├── standards/
 ├── workflows/
 ├── templates/
 ├── memory/
 └── features/

.claude/                  → see .claude/README.md   (Execution Layer)
 ├── agents/
 ├── commands/
 ├── hooks/
 └── scripts/

examples/fleetkeep/       → a fully configured copy of both layers (worked reference)
```

- **[`.ai/`](.ai/README.md)** — the **Knowledge Layer**: everything the agents read (config, context,
  standards, workflows, templates, decisions). Markdown only; nothing here executes.
- **[`.claude/`](.claude/README.md)** — the **Execution Layer**: everything Claude Code runs (slash
  commands, sub-agents, hooks, settings).
- **`examples/fleetkeep/` *(template repo)*** — the same two layers, **filled in** for a sample
  project: FleetKeep, a multi-tenant fleet-compliance SaaS (.NET 8 API + React/Mantine SPA + Azure
  Functions worker + Bicep, on GitHub). Every token substituted, every `[FILL IN]` answered, and
  `hooks.env` configured with the tenant-isolation, design-token and TDD checks switched on. Read it
  beside the skeletons; `/init-project` offers to delete it once your own project is configured.

---

## Documentation

AI Harness is documented in layered guides. Start here and drill into whichever part you need.

| Document | Read it when you want to… |
|----------|----------------------------|
| **`docs/index.html`** *(template repo)* | Read everything as one browsable page — the fastest way in, and the one to hand someone new |
| `docs/getting-started.md` *(template repo)* | Go from clone to a configured harness and a first feature, with troubleshooting |
| `docs/components.md` *(template repo)* | Look up any single component — command, persona, sub-agent, hook, template — and what it produces |
| **README.md** (this file) | Understand the whole system — and [set it up](#setup) in a repo |
| [`.ai/README.md`](.ai/README.md) | Understand the **Knowledge Layer** — what lives in `.ai/` and what to fill in |
| [`.claude/README.md`](.claude/README.md) | Understand the **Execution Layer** — commands, sub-agents, and hooks in `.claude/` |
| [`COMMANDS.md`](COMMANDS.md) | Know exactly what to type — every `/command`, who uses it, and what it produces |
| [`.ai/CUSTOMIZATION.md`](.ai/CUSTOMIZATION.md) | Tailor the template to your project, organized by axis |
| [`CLAUDE.md`](CLAUDE.md) | See the per-repo guidance Claude Code auto-loads each session |
| `examples/fleetkeep/` *(template repo)* | See a complete, filled-in configuration end to end |
| [`AGENTS.md`](AGENTS.md) · `docs/portability.md` *(template repo)* | Run the harness on Codex, Cursor, Gemini or another agent |

---

## Benefits

- Faster software delivery
- Higher code quality
- Consistent engineering practices
- Reduced onboarding time
- Lower key-person dependency
- Improved governance
- Better documentation
- Safer AI adoption

---

## Guiding Principles

- Human-led decision making
- AI-assisted execution
- Standards by default
- Security first
- Reusable knowledge
- Governance built in
- Continuous improvement

---

## Future Roadmap

- Multi-model AI support
- Multi-agent orchestration
- Enterprise governance dashboards
- Automated architecture validation
- AI performance analytics
- Organizational knowledge graph
- Cross-project learning
- Intelligent delivery insights

---

## License

Private repository — **all rights reserved**.

Not licensed for distribution, publication, or use outside the organisations that hold rights to it.
Portions derive from an internal base template; that prior work's terms continue to apply.

If you are unsure whether you may use or share this, ask the repository owner before doing either.

> **Adopting the harness into a project?** This section describes *this template repo*. Replace it
> with your project's own licence when you copy `README.md` across — the harness makes no claim over
> the code you build with it.
