# Portability: running this harness on other AI agents

The harness has two parts: a method, which is portable, and an enforcement mechanism, which is
specific to Claude Code. This document measures that split and gives recipes for closing the gap
when you need to.

---

## The measured split

| Part | Size | Portable? |
|---|---|---|
| `.ai/`: personas, playbooks, standards, templates, config, context, memory | 87 files, ~5,300 lines | **Yes.** Plain markdown, no tool-specific syntax |
| `.claude/commands/` (27 commands) | 27 files | **No.** `allowed-tools` / `disallowed-tools` / `argument-hint` frontmatter, 77 `@file` includes, 121 `$ARGUMENTS` references |
| `.claude/agents/` (8 sub-agents) | 8 files | **No.** `tools` / `model` / `memory` / `effort` frontmatter; isolated-context spawning is a Claude Code feature |
| `.claude/hooks/` (9 scripts) | 9 scripts | **Partly.** Ordinary bash with no `CLAUDE_*` dependencies inside, but wired to Claude Code's seven hook events and fed a JSON payload on stdin |
| `.claude/rules/` (path-scoped rules) | 1 example | **Partly.** Plain markdown, but loading by `paths:` glob is Claude Code behaviour; `AGENTS.md` tells other agents to read matching rules themselves |
| `.mcp.json` | 1 file | **Partly.** MCP is an open standard; clients differ on config location and format |
| `CLAUDE.md` | 1 file | Equivalent exists elsewhere: `AGENTS.md`, `GEMINI.md`, `.cursorrules` |

Roughly, the knowledge layer, which holds most of the thinking, carries over intact. The parts that
make the method impossible to skip do not.

### What cannot be ported at all

- Hard blocks at the tool call. `git-guard.sh` refuses a force push before it happens. Nothing
  outside the agent's own tool loop can do that. The closest substitute is a git hook, which fires
  later and can be bypassed with `--no-verify`.
- Tool-restricted sub-agents. A reviewer spawned without `Write` or `Edit` has no direct way to
  edit the code it is reviewing. This is a narrower tool list, not a sandbox (the reviewer keeps
  `Bash`), but it is still more than instructions. On other agents, a "reviewer" is the same agent
  with different instructions, and instructions are advisory.
- Parallel isolated review. The reviewer and the security scanner run at the same time in separate
  context windows, and neither sees the other's reasoning.

Everything else has a workable substitute.

---

## Option 1: `AGENTS.md` (done)

[`AGENTS.md`](../AGENTS.md) at the repo root carries the whole method as instructions: which `.ai/`
files to read for which task, how to resolve scope, which playbook to follow, the gates to stop at
(a review before any commit, then the five feature-path gates), the guardrails to self-enforce from
`hooks.env`, where artifacts go, and what to record in memory.

- Cost: none ongoing. It defers to `CLAUDE.md` and `.ai/` for every project-specific detail, so it
  holds no tokens and cannot drift out of sync.
- Works with: Codex CLI, Cursor, Gemini CLI, Copilot and any other tool that follows the
  `AGENTS.md` convention. For a tool that looks for a different filename, symlink or copy it.
- You get: the method, the standards, the artifact discipline and the memory logs.
- You don't get: anything automatic. Gates depend on the agent choosing to stop.

---

## Option 2: move enforcement into git hooks + CI (recommended)

This step is worth the most, and it helps even if you never use another agent: guardrails in git
hold no matter who made the edit (Claude, another agent, or a human in a hurry).

The git hooks reuse `hooks.env` verbatim, so behaviour is configured in exactly one place.

### `.githooks/pre-push` (mirrors `git-guard.sh`)

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

### `.githooks/pre-commit` (mirrors `post-tool-use.sh`)

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

`core.hooksPath` is per-clone, so add that line to your project's onboarding docs or run it from a
bootstrap script.

### The backstop

Git hooks are local, and `--no-verify` skips them. CI is the boundary that holds: run the same
type-check, lint, test and security checks on every pull request, and protect the branch server-side
in GitHub/GitLab so nobody can push past the rules. Treat the git hooks as fast feedback and CI as
enforcement.

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

## Option 3: per-tool command generators

This is only worth doing if a team works in one specific non-Claude tool every day.

Write a script (say `.claude/scripts/sync-<tool>.mjs`) that reads `.claude/commands/**/*.md` and
`.claude/agents/*.md` and emits that tool's format. This harness's upstream ancestor did this for
Codex: a generator produced agent definitions, a skills subset and most of the hooks. The
translation is therefore known to be tractable.

### The mapping

| Claude Code | Translate to |
|---|---|
| `description:` frontmatter | The tool's command description field |
| `@file` include (77 of them) | Inline the file's contents, or the tool's own include syntax |
| `$ARGUMENTS` (121 refs) | The tool's argument placeholder |
| `allowed-tools:` | The tool's permission list or, failing that, a prose constraint in the prompt |
| Sub-agent `tools:` / `model:` | Usually no equivalent; degrade to a single agent following the persona |
| Hook events | Nothing direct; cover with Option 2 |

### Cost, honestly

Generated output must be regenerated on every harness change, or it silently goes out of date. A
stale generated command is worse than no command, because it looks authoritative. If you take this
route, generate in CI and fail the build when the output is out of date. Keep `.claude/**` as the
single source, and never hand-edit the generated files.

---

## Support matrix

| Agent | `.ai/` knowledge | Instructions file | Commands | Sub-agents | Hooks |
|---|---|---|---|---|---|
| **Claude Code** | Native | `CLAUDE.md` | 27, native | 8, isolated + tool-restricted | 9, enforced |
| **Codex CLI** | Read via `AGENTS.md` | `AGENTS.md` | Option 3 | No equivalent | Option 2 |
| **Cursor** | Read via rules pointing at `.ai/` | `AGENTS.md` / `.cursorrules` | Option 3 | No equivalent | Option 2 |
| **Gemini CLI** | Read via instructions file | `GEMINI.md` | Option 3 | No equivalent | Option 2 |
| **Copilot / other** | Read via `AGENTS.md` | `AGENTS.md` | Varies | No equivalent | Option 2 |

> Agent tooling changes quickly, and the columns above reflect what was true when this was written.
> Check your tool's current capabilities before investing in Option 3, because command and hook
> support is the area most likely to change.

---

## Recommended order

1. `AGENTS.md`: already in place. Every agent gets the method for free.
2. Git hooks + CI: do this when a second agent or a mixed human/AI team starts committing. It is the
   only way to make the guardrails independent of the tool.
3. Command generators: only if a team standardises on one non-Claude tool and misses the
   convenience of the slash commands.
