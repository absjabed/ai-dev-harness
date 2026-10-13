# Portability — running this harness on other AI agents

The harness splits cleanly into a **method** (portable) and an **enforcement mechanism** (Claude Code
specific). This document measures that split and gives recipes for closing the gap when you need to.

---

## The measured split

| Part | Size | Portable? |
|---|---|---|
| `.ai/` — personas, playbooks, standards, templates, config, context, memory | 82 files, ~4,400 lines | **Yes.** Plain markdown, no tool-specific syntax |
| `.claude/commands/` — 26 commands | 26 files | **No.** `allowed-tools` / `disallowed-tools` / `argument-hint` frontmatter, 73 `@file` includes, 108 `$ARGUMENTS` references |
| `.claude/agents/` — 8 sub-agents | 8 files | **No.** `tools` / `model` / `memory` / `effort` frontmatter; isolated-context spawning is a Claude Code feature |
| `.claude/hooks/` — 8 scripts | 8 scripts | **Partly.** Ordinary bash with no `CLAUDE_*` dependencies inside, but wired to Claude Code's seven hook events and fed a JSON payload on stdin |
| `.mcp.json` | 1 file | **Partly.** MCP is an open standard; clients differ on config location and format |
| `CLAUDE.md` | 1 file | Equivalent exists elsewhere: `AGENTS.md`, `GEMINI.md`, `.cursorrules` |

Roughly: the knowledge layer — where most of the thinking lives — travels intact. The parts that make
the method *unskippable* do not.

### What cannot be ported at all

- **Hard blocks at the tool call.** `git-guard.sh` refuses a force push before it happens. Nothing
  outside the agent's own tool loop can do that; the closest substitute is a git hook, which fires
  later and can be bypassed with `--no-verify`.
- **Read-only sub-agents.** A reviewer given only `Read` and `Bash` *cannot* edit the code it is
  reviewing. Elsewhere, a "reviewer" is the same agent with different instructions — and instructions
  are advisory.
- **Parallel isolated review.** Reviewer and security scanner run concurrently in separate context
  windows, neither seeing the other's reasoning.

Everything else has a workable substitute.

---

## Option 1 — `AGENTS.md` (done)

[`AGENTS.md`](../AGENTS.md) at the repo root carries the whole method as instructions: which `.ai/`
files to read for which task, how to resolve scope, which playbook to follow, the gates to stop at
(a review before any commit, then the five feature-path gates), the guardrails to self-enforce from
`hooks.env`, where artifacts go, and what to record in memory.

- **Cost:** none ongoing. It defers to `CLAUDE.md` and `.ai/` for every project specific, so it holds
  no tokens and cannot drift out of sync.
- **Works with:** Codex CLI, Cursor, Gemini CLI, Copilot and anything else honouring the
  `AGENTS.md` convention. For a tool that looks for a different filename, symlink or copy it.
- **You get:** the method, the standards, the artifact discipline, the memory logs.
- **You don't get:** anything automatic. Gates depend on the agent choosing to stop.

---

## Option 2 — move enforcement into git hooks + CI (recommended)

This is the highest-value step, and not only for other agents: guardrails in git hold regardless of
*who* made the edit — Claude, another agent, or a human in a hurry.

The idea is to re-use `hooks.env` verbatim, so there is exactly one place that configures behaviour.

### `.githooks/pre-push` — mirrors `git-guard.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail
source "$(git rev-parse --show-toplevel)/.claude/hooks/hooks.env"

branch="$(git rev-parse --abbrev-ref HEAD)"

for protected in $PROTECTED_BRANCHES; do
  if [[ "$branch" == "$protected" ]]; then
    echo "BLOCKED: direct push to protected branch '$branch'. Open a $PR_TERM instead." >&2
    exit 1
  fi
done

# Force push, in any of its spellings
if [[ "${*:-}" == *--force* || "${*:-}" == *"-f "* ]]; then
  echo "BLOCKED: force push. Use 'git revert' to undo commits safely." >&2
  exit 1
fi
```

### `.githooks/pre-commit` — mirrors `post-tool-use.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail
root="$(git rev-parse --show-toplevel)"
source "$root/.claude/hooks/hooks.env"

staged="$(git diff --cached --name-only --diff-filter=ACM)"
[[ -z "$staged" ]] && exit 0

# Generated migrations must not be hand-edited
if [[ -n "${MIGRATIONS_GLOB:-}" ]]; then
  while read -r f; do
    [[ -z "$f" ]] && continue
    # shellcheck disable=SC2053
    if [[ "$f" == $MIGRATIONS_GLOB ]]; then
      echo "BLOCKED: $f is generated. Regenerate with: $MIGRATIONS_REGEN_CMD" >&2
      exit 1
    fi
  done <<< "$staged"
fi

# Sensitive config — warn, don't block
for glob in ${SENSITIVE_CONFIG_GLOBS:-}; do
  while read -r f; do
    # shellcheck disable=SC2053
    [[ -n "$f" && "$f" == $glob ]] && echo "WARNING: $f carries secrets or load-bearing config." >&2
  done <<< "$staged"
done

# Type-check and lint, scoped to the package that changed
for dir in ${PACKAGE_DIRS:-}; do
  if echo "$staged" | grep -q "^$dir/" && [[ -d "$root/$dir" ]]; then
    ( cd "$root/$dir"
      [[ -n "${TYPECHECK_CMD:-}" ]] && eval "$TYPECHECK_CMD"
      [[ -n "${LINT_CMD:-}" ]] && eval "$LINT_CMD ." ) || exit 1
  fi
done
```

### Install

```bash
chmod +x .githooks/*
git config core.hooksPath .githooks
```

`core.hooksPath` is per-clone, so add that line to your project's onboarding docs — or run it from a
bootstrap script.

### The backstop

Git hooks are local and `--no-verify` skips them. **CI is the real boundary**: run the same
type-check, lint, test and security checks on every pull request, and protect the branch server-side
in GitHub/GitLab so the rules cannot be pushed around. Treat the git hooks as fast feedback and CI
as enforcement.

### What this buys you

| Guardrail | Claude Code hook | Git hook + CI equivalent |
|---|---|---|
| Force push / protected branch | Blocked at the tool call | `pre-push` + server-side branch protection |
| Prod deploy from a laptop | Blocked at the tool call | Deploy only from CI with environment approval |
| Type-check + lint after edit | Automatic, per package | `pre-commit` + CI job |
| Hand-edited migrations | Blocked | `pre-commit` |
| Sensitive config warning | stderr warning | `pre-commit` warning |
| Tenant isolation / env / design tokens | Heuristic warnings | Lint rules or a CI grep step |
| TDD nudge | Prompt-time nudge | Coverage gate in CI (a blunter instrument) |

---

## Option 3 — per-tool command generators

Only worth it if a team lives in one specific non-Claude tool daily.

Write a script (say `.claude/scripts/sync-<tool>.mjs`) that reads `.claude/commands/**/*.md` and
`.claude/agents/*.md` and emits that tool's format. This harness's upstream ancestor did exactly
that for Codex — a generator produced agent definitions, a skills subset and most of the hooks — so
the translation is known to be tractable.

### The mapping

| Claude Code | Translate to |
|---|---|
| `description:` frontmatter | The tool's command description field |
| `@file` include (73 of them) | Inline the file's contents, or the tool's own include syntax |
| `$ARGUMENTS` (108 refs) | The tool's argument placeholder |
| `allowed-tools:` | The tool's permission list — or, failing that, a prose constraint in the prompt |
| Sub-agent `tools:` / `model:` | Usually no equivalent; degrade to a single agent following the persona |
| Hook events | Nothing direct — cover with Option 2 |

### Cost, honestly

Generated output must be regenerated on every harness change, or it silently rots — and a stale
generated command is worse than no command, because it looks authoritative. If you take this route,
generate in CI and fail the build when the output is out of date. Keep `.claude/**` as the single
source; never hand-edit the generated files.

---

## Support matrix

| Agent | `.ai/` knowledge | Instructions file | Commands | Sub-agents | Hooks |
|---|---|---|---|---|---|
| **Claude Code** | Native | `CLAUDE.md` | 26, native | 8, isolated + tool-restricted | 8, enforced |
| **Codex CLI** | Read via `AGENTS.md` | `AGENTS.md` | Option 3 | No equivalent | Option 2 |
| **Cursor** | Read via rules pointing at `.ai/` | `AGENTS.md` / `.cursorrules` | Option 3 | No equivalent | Option 2 |
| **Gemini CLI** | Read via instructions file | `GEMINI.md` | Option 3 | No equivalent | Option 2 |
| **Copilot / other** | Read via `AGENTS.md` | `AGENTS.md` | Varies | No equivalent | Option 2 |

> Agent tooling moves quickly and the columns above reflect what was true when this was written.
> Check the current capabilities of your tool before investing in Option 3 — command and hook
> support is exactly the area that changes.

---

## Recommended order

1. **`AGENTS.md`** — already in place. Every agent gets the method for free.
2. **Git hooks + CI** — do this when a second agent or a mixed human/AI team starts committing. It
   is the only way the guardrails become genuinely tool-independent.
3. **Command generators** — only if a team standardises on one non-Claude tool and misses the
   ergonomics of the slash commands.
