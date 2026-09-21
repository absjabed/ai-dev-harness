# `.claude/` — Execution Layer

> The **how**: everything Claude Code actually runs — slash commands, spawnable sub-agents,
> safety/quality hooks, and settings.

Files here stay **generic**. They reference project knowledge in [`.ai/`](../.ai/README.md) with
`@.ai/...` includes, which Claude Code expands inline at run time. That is why the same commands work
for any project once `.ai/` is filled in.

← Back to the [main README](../README.md) · Full command reference in [`COMMANDS.md`](../COMMANDS.md)

---

## Directory map

| Path | What it holds |
|------|---------------|
| [`commands/`](commands) | The slash commands you type. Top-level studios (`init-project`, `ba`, `qa`) plus four families: [`agents/`](commands/agents), [`workflows/`](commands/workflows), [`utils/`](commands/utils), [`harness/`](commands/harness). |
| [`agents/`](agents) | Spawnable **sub-agents** — isolated workers with their own tool permissions: `developer`, `reviewer`, `qa-runner`, `security-scanner`, `release-manager`, `orchestrator`, `harness-engineer`, `critic`. Workflows spawn these behind the scenes. |
| [`hooks/`](hooks) | Safety/quality hooks (see below) plus **`hooks.env`** — the single config for all hook behavior. |
| [`scripts/`](scripts) | Helper scripts (e.g. `devops-mode.sh`). |
| `settings.json` | Hook registration (which script fires on which event). |
| `settings.local.json` | Local, machine-specific overrides (not committed conventions). |

---

## Commands at a glance

Full arguments, owners, and outputs live in [`COMMANDS.md`](../COMMANDS.md).

- **Studios** (human-in-the-loop): `/init-project`, `/ba`, `/qa`
- **Specialists** — `commands/agents/`: `/agents:architect`, `/agents:ba`, `/agents:design`,
  `/agents:dev`, `/agents:devops`, `/agents:pm`, `/agents:qa`, `/agents:review`, `/agents:security`,
  `/agents:release-manager`
- **Workflows** — `commands/workflows/`: `/workflows:feature`, `/workflows:bugfix`,
  `/workflows:hotfix`, `/workflows:release`
- **Utilities** — `commands/utils/`: `/utils:status`, `/utils:standup`, `/utils:changelog`,
  `/utils:docs`, `/utils:docs-serve`, `/utils:scope`, `/utils:learn`
- **Harness maintenance** — `commands/harness/`: `/harness:improve` (change the harness itself
  through an author → critic → revise → recheck loop; see `.ai/workflows/harness-improvement.md`)
  and `/harness:ask` (read-only Q&A about the harness — answers cite the exact files they came from)

> Each specialist command loads its matching **role definition** from
> [`.ai/agents/`](../.ai/agents) — the command is the button you press; the role is who the agent is.

---

## Hooks

All hooks are **config-driven via `hooks.env`** — a blank value means "skip," so the system is
inert-safe until you opt in. Registration is in `settings.json`:

| Hook script | Fires on | Purpose |
|-------------|----------|---------|
| `pre-tool-use.sh` | `PreToolUse` (Edit/Write/MultiEdit) | Guard edits to sensitive/protected files before they happen. |
| `git-guard.sh` | `PreToolUse` (Bash) | Block destructive git/deploy commands (e.g. `git push --force`). |
| `post-tool-use.sh` | `PostToolUse` (Edit/Write/MultiEdit) | React to individual edits. |
| `post-tool-batch.sh` | `PostToolBatch` | Run type-check / lint after a batch of edits. |
| `post-tool-failure.sh` | `PostToolUseFailure` (Edit/Write/Bash) | Handle a failed tool call. |
| `stop-check.sh` | `Stop` | Final checks when a turn ends. |
| `compact-restore.sh` | `SessionStart` (compact) | Restore working context after a context compaction. |
| `user-prompt-context.sh` | `UserPromptSubmit` | Inject session context (branch, scope) into each prompt. |

> Tune behavior in [`hooks/hooks.env`](hooks/hooks.env). Model/effort per command or sub-agent is set
> in each file's frontmatter.
