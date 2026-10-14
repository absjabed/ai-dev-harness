# AGENTS.md

Instructions for any AI coding agent working in this repository: Codex CLI, Cursor, Gemini CLI,
Copilot, or any other tool that reads an `AGENTS.md`.

> **Using Claude Code?** Read [`CLAUDE.md`](CLAUDE.md) instead and use the slash commands in
> [`COMMANDS.md`](COMMANDS.md). This file carries the same method to other agents. Claude Code
> enforces the method automatically; every other agent has to follow it deliberately.

---

## 1. Read before you act

This repo has a knowledge base at `.ai/`, written in plain markdown for you to read. Never start a
task from the code alone. Load the files for the task first.

| Task | Read first |
|---|---|
| Anything at all | [`CLAUDE.md`](CLAUDE.md): stack, commands, architecture, non-negotiables |
| Any change | `.ai/config/project-config.md` and `.ai/context/project-overview.md` |
| Backend work | `.ai/config/backend/project-config.md`, `.ai/context/backend/*`, `.ai/standards/project/backend/tech-specific.md` |
| Frontend work | `.ai/config/frontend/project-config.md`, `.ai/context/frontend/*`, `.ai/standards/project/frontend/tech-specific.md`, `.ai/standards/project/frontend/design/*` |
| Any UI surface | `.ai/standards/universal/{ui-ux-standards,accessibility,frontend-design}.md` + the `design/` subtree |
| Architecture decisions | `.ai/context/architecture.md`, then write an ADR from `.ai/templates/adr.md` |
| Domain rules | `.ai/context/business-rules.md`: authorization, tenancy, state machines |
| Files in an area with its own rules | Any `.claude/rules/**/*.md` whose `paths:` globs match the files you touch. Claude Code loads these automatically; you must read them yourself |
| Always | `.ai/standards/universal/coding-principles.md` and `.ai/standards/universal/security-baseline.md` |

Single-scope repos have only the top-level `config/`, `context/` and `standards/project/` files.
Use those.

**Before proposing a design, read `.ai/memory/`:** `decisions.md` (what was already decided and
why), `learnings.md` (what has already gone wrong), `design-taste.md` (patterns already approved or
rejected). Re-proposing something recorded as rejected counts as a failure.

## 2. Pick a scope, then load only that scope

1. If `.ai/config/current-scope.md` begins with `# Forced scope:`, obey it.
2. Otherwise infer the scope (backend, frontend or fullstack) from the request, using the stack
   signals in `.ai/config/project-config.md`.
3. Load only that scope's files. Loading everything wastes context and makes it harder to tell
   which rules apply.

## 3. Follow the workflow for the task

The method is written down in `.ai/workflows/`. Follow the matching playbook step by step:

| Task | Playbook |
|---|---|
| Feature | `.ai/workflows/feature-development.md` |
| Bug | `.ai/workflows/bug-fixing.md` |
| Urgent production fix | `.ai/workflows/hotfix-process.md` |
| Release | `.ai/workflows/release-process.md` |
| Reviewing a diff | `.ai/workflows/code-review.md` |
| Proving a change against a running system | `.ai/workflows/runtime-verification.md` |
| Changing this harness | `.ai/workflows/harness-improvement.md` |

While you work, adopt the matching persona from `.ai/agents/`, such as `developer-agent.md`,
`reviewer-agent.md`, `security-agent.md` or `designer-agent.md`. Each persona defines its method,
its output format and an explicit "never do" list.

## 4. Stop at the gates: ask, don't assume

Claude Code halts at these points automatically. **You must stop and ask the human instead.** Do not
continue past a gate on your own judgement.

0. **Review before you commit.** This applies on *any* path that changes code, including a bug fix
   or a hotfix. The playbooks include an explicit review step. You have no reviewer sub-agent, so
   review the diff yourself against the scope's standards and report the findings before you ask
   to commit.
1. **Technical spec approved:** before writing any implementation code.
2. **Design approved:** for any UI surface, before building it.
3. **Verification reported.** State plainly what you verified and what you did not. After the review
   and the security check, confirm the plan with the human, then run the runtime checks in
   `.ai/workflows/runtime-verification.md` that the change needs (API calls, a browser run of the UI
   journeys, read-only DB checks). A failed or skipped planned check blocks the commit unless the
   human explicitly accepts it.
4. **Commit.** Show the message and the change list, and get a yes.
5. **Pull request.** Show the description, and get a yes before opening anything.

Each gate is a question you put to a human. You cannot pass one by ticking it off yourself.

## 5. Enforce the guardrails yourself

This repo's automated guardrails are in `.claude/hooks/` and **only run under Claude Code**. On
another agent they do not exist, so treat the following as hard rules that you enforce:

- **Never** `git push --force`, `git reset --hard`, or push directly to a protected branch. The
  protected list is `PROTECTED_BRANCHES` in `.claude/hooks/hooks.env`.
- **Never** run the deploy command against the production stage (`DEPLOY_CMD` / `PROD_STAGE` in the
  same file). Deploys belong to CI.
- **Never** hand-edit generated migrations (`MIGRATIONS_GLOB`); regenerate with `MIGRATIONS_REGEN_CMD`.
- **Warn and confirm** before editing anything matching `SENSITIVE_CONFIG_GLOBS`. Those files hold
  secrets or load-bearing config.
- **After editing code, run the checks yourself**: `TYPECHECK_CMD` and `LINT_CMD` inside the
  matching `PACKAGE_DIRS` entry, plus the project's test command.
- If `TENANT_ISOLATION_CHECK` is on, every data-access change must be scoped by `TENANT_KEY`.
  Crossing that boundary is a CRITICAL security bug.
- If `FRONTEND_ENV_CHECK` is on, obey `FRONTEND_ENV_GOOD_HINT` for environment access.
- If `DESIGN_TOKEN_CHECK` is on, never hardcode a colour. Use the tokens in `DESIGN_TOKEN_DOC`.
- If `TDD_CHECK` is on, write the failing test before the implementation.
- **Never** send a request to, or open in a browser, any host matching `E2E_FORBIDDEN_HOSTS`.
  Runtime checks use only the Test environments URLs in `.ai/config/project-config.md`. Never
  write to a database while checking, and never print or store a token or password.

`hooks.env` is the single source for all of these values. Read it at the start of a session. It is
short, and it tells you what this project enforces.

## 6. Write artifacts where they belong

Feature work produces documents as well as code. Use the templates in `.ai/templates/` and write to:

```
.ai/features/<slug>/
├── requirement-spec.md     user-stories.md      test-specs.md
├── technical-specs/        design/design-spec.md
├── review-report.md        security-report.md   pr-description.md
├── test-specs/e2e-report.md   # runtime verification: API / UI / DB checks
├── deploy-notes.md         # deploy impact + fix version; unbranded, read by the release path
└── STATE.md                # your own progress: phase, tasks, decisions, next action
```

Every document except `STATE.md` and `deploy-notes.md` opens with the branded header from
`.ai/templates/artifact-header.md`, using the values in `.ai/config/branding.md`.

**Keep `STATE.md` current.** Update it after each step and at each gate. The next session (or the
next agent) uses it to resume without re-deriving your work.

## 7. Record what was learned

- A precedent-setting or hard-to-reverse decision → append one line to `.ai/memory/decisions.md`.
- A non-obvious, reusable lesson → append to `.ai/memory/learnings.md`.
- A design choice approved or rejected by the human → append to `.ai/memory/design-taste.md`,
  quoting their words where you have them.

These logs are append-only. The next agent reads them so that it does not repeat this session's
mistakes.

## 8. Never

- Never skip a gate because the change "looks small".
- Never claim something is tested or verified when it was not. Say which parts you checked and how.
- Never commit a secret, or log personal data.
- Never bypass the layering or data-access rules in the project's `tech-specific.md`.
- Never edit files under `.claude/` casually. Those files are the harness itself; follow
  `.ai/workflows/harness-improvement.md`.
- Never invent project facts. If `.ai/` does not answer a question, ask the human.

---

## Capability gap

Under Claude Code this repo also has hard blocks at the tool call, automatic type-check and lint
after every edit, tool-restricted reviewers spawned in parallel, and resumable workflow state. None
of that exists on other agents. The method above is the same, but **you** are the enforcement.

To close the gap with tool-independent guardrails (git hooks and CI), see
[`docs/portability.md`](docs/portability.md).
