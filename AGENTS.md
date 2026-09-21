# AGENTS.md

Instructions for any AI coding agent working in this repository — Codex CLI, Cursor, Gemini CLI,
Copilot, or anything else that reads an `AGENTS.md`.

> **Using Claude Code?** Read [`CLAUDE.md`](CLAUDE.md) instead and use the slash commands in
> [`COMMANDS.md`](COMMANDS.md). This file exists so the same method survives on other agents; Claude
> Code enforces it automatically, everything else has to follow it deliberately.

---

## 1. Read before you act

This repo carries a knowledge base at **`.ai/`**. It is plain markdown, written for you. Never start
a task from the code alone — load the files for the task first.

| Task | Read first |
|---|---|
| Anything at all | [`CLAUDE.md`](CLAUDE.md) — stack, commands, architecture, non-negotiables |
| Any change | `.ai/config/project-config.md` and `.ai/context/project-overview.md` |
| Backend work | `.ai/config/backend/project-config.md`, `.ai/context/backend/*`, `.ai/standards/project/backend/tech-specific.md` |
| Frontend work | `.ai/config/frontend/project-config.md`, `.ai/context/frontend/*`, `.ai/standards/project/frontend/tech-specific.md`, `.ai/standards/project/frontend/design/*` |
| Any UI surface | `.ai/standards/universal/{ui-ux-standards,accessibility,frontend-design}.md` + the `design/` subtree |
| Architecture decisions | `.ai/context/architecture.md`, then write an ADR from `.ai/templates/adr.md` |
| Domain rules | `.ai/context/business-rules.md` — authorization, tenancy, state machines |
| Always | `.ai/standards/universal/coding-principles.md` and `.ai/standards/universal/security-baseline.md` |

Single-scope repos have only the top-level `config/`, `context/` and `standards/project/` files —
use those.

**Before proposing a design, read `.ai/memory/`:** `decisions.md` (what was already decided and
why), `learnings.md` (what has already gone wrong), `design-taste.md` (patterns already approved or
rejected). Re-proposing something recorded as rejected is a failure, not a fresh idea.

## 2. Pick a scope, then load only that scope

1. If `.ai/config/current-scope.md` begins with `# Forced scope:`, obey it.
2. Otherwise infer **backend / frontend / fullstack** from the request, using the stack signals in
   `.ai/config/project-config.md`.
3. Load only that scope's files. Loading everything wastes context and blurs the rules that apply.

## 3. Follow the workflow for the task

The method lives in `.ai/workflows/`. Follow the matching playbook step by step:

| Task | Playbook |
|---|---|
| Feature | `.ai/workflows/feature-development.md` |
| Bug | `.ai/workflows/bug-fixing.md` |
| Urgent production fix | `.ai/workflows/hotfix-process.md` |
| Release | `.ai/workflows/release-process.md` |
| Reviewing a diff | `.ai/workflows/code-review.md` |
| Changing this harness | `.ai/workflows/harness-improvement.md` |

Adopt the matching persona from `.ai/agents/` while you do it — `developer-agent.md`,
`reviewer-agent.md`, `security-agent.md`, `designer-agent.md`, and so on. Each defines the method,
the output format and an explicit "never do" list.

## 4. Stop at the gates — ask, don't assume

Claude Code halts at these points automatically. **You must stop and ask the human instead.** Do not
continue past one on your own judgement.

1. **Technical spec approved** — before writing any implementation code.
2. **Design approved** — for any UI surface, before building it.
3. **Verification reported** — state plainly what you verified and what you did not.
4. **Commit** — show the message and the change list; get a yes.
5. **Pull request** — show the description; get a yes before opening anything.

A gate is a question to a human, not a checkbox you tick.

## 5. Enforce the guardrails yourself

This repo's automated guardrails live in `.claude/hooks/` and **only run under Claude Code**. On
another agent they do not exist, so treat the following as hard rules you enforce:

- **Never** `git push --force`, `git reset --hard`, or push directly to a protected branch. The
  protected list is `PROTECTED_BRANCHES` in `.claude/hooks/hooks.env`.
- **Never** run the deploy command against the production stage (`DEPLOY_CMD` / `PROD_STAGE` in the
  same file). Deploys belong to CI.
- **Never** hand-edit generated migrations (`MIGRATIONS_GLOB`); regenerate with `MIGRATIONS_REGEN_CMD`.
- **Warn and confirm** before editing anything matching `SENSITIVE_CONFIG_GLOBS` — those files carry
  secrets or are load-bearing config.
- **After editing code, run the checks yourself**: `TYPECHECK_CMD` and `LINT_CMD` inside the
  matching `PACKAGE_DIRS` entry, plus the project's test command.
- If `TENANT_ISOLATION_CHECK` is on, every data-access change must be scoped by `TENANT_KEY`.
  Crossing that boundary is a CRITICAL security bug, not a style issue.
- If `FRONTEND_ENV_CHECK` is on, obey `FRONTEND_ENV_GOOD_HINT` for environment access.
- If `DESIGN_TOKEN_CHECK` is on, never hardcode a colour — use the tokens in `DESIGN_TOKEN_DOC`.
- If `TDD_CHECK` is on, write the failing test before the implementation.

`hooks.env` is the single source for all of these values. Read it at the start of a session; it is
short and it tells you what this project actually enforces.

## 6. Write artifacts where they belong

Feature work produces documents, not just code. Use the templates in `.ai/templates/` and write to:

```
.ai/features/<slug>/
├── requirement-spec.md     user-stories.md      test-specs.md
├── technical-specs/        design/design-spec.md
├── review-report.md        security-report.md   pr-description.md
└── STATE.md                # your own progress: phase, tasks, decisions, next action
```

Every document except `STATE.md` opens with the branded header from
`.ai/templates/artifact-header.md`, using the values in `.ai/config/branding.md`.

**Keep `STATE.md` current** — update it after each step and at each gate. It is how the next session
(or the next agent) resumes without re-deriving your work.

## 7. Record what was learned

- A precedent-setting or hard-to-reverse decision → append one line to `.ai/memory/decisions.md`.
- A non-obvious, reusable lesson → append to `.ai/memory/learnings.md`.
- A design choice approved or rejected by the human → append to `.ai/memory/design-taste.md`,
  quoting their words where you have them.

These logs are append-only. They are why the next agent does not repeat this session's mistakes.

## 8. Never

- Never skip a gate because the change "looks small".
- Never claim something is tested or verified when it was not — say which parts you checked and how.
- Never commit a secret, or log personal data.
- Never bypass the layering or data-access rules in the project's `tech-specific.md`.
- Never edit files under `.claude/` casually — that is the harness itself; follow
  `.ai/workflows/harness-improvement.md`.
- Never invent project facts. If `.ai/` does not answer a question, ask the human.

---

## Capability gap

Under Claude Code this repo also gets: hard blocks at the tool call, automatic type-check and lint
after every edit, read-only reviewers spawned in parallel, and resumable workflow state. None of
that exists on other agents — the method above is the same, but **you** are the enforcement.

To close the gap with tool-independent guardrails (git hooks and CI), see
[`docs/portability.md`](docs/portability.md).
