#!/usr/bin/env bash
# PostToolUseFailure hook — fires when a tool call returns a non-zero exit or error.
# Emits a structured, actionable hint to stderr based on the error text.
# Stack-neutral: hints trigger on the error output itself, not on any assumed stack.
# Config-driven extras come from .claude/hooks/hooks.env. Non-blocking (exit 0 always).

set -euo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
[[ -f "$HOOK_DIR/hooks.env" ]] && source "$HOOK_DIR/hooks.env"

MIGRATIONS_REGEN_CMD="${MIGRATIONS_REGEN_CMD:-}"

payload="$(cat)"

TOOL_NAME="$(printf '%s' "$payload" | node -e '
let raw="";process.stdin.on("data",c=>raw+=c).on("end",()=>{try{const j=JSON.parse(raw);process.stdout.write(j.tool_name||j.tool||"");}catch(_){process.stdout.write("");}});
' 2>/dev/null || echo "")"

ERROR_OUTPUT="$(printf '%s' "$payload" | node -e '
let raw="";process.stdin.on("data",c=>raw+=c).on("end",()=>{try{const j=JSON.parse(raw);process.stdout.write(j.error||j.output||j.stderr||"");}catch(_){process.stdout.write("");}});
' 2>/dev/null || echo "")"

# grep returning 1 = "no match", not a real failure worth surfacing.
if echo "$ERROR_OUTPUT" | grep -q "exit code 1" 2>/dev/null; then
  if echo "$TOOL_NAME" | grep -qi "bash"; then exit 0; fi
fi

# Type errors (TypeScript, mypy, tsc, etc.)
if echo "$ERROR_OUTPUT" | grep -qE "TS[0-9]+:|error TS|error: .*type|mypy"; then
  echo "HOOK [failure] Type error detected." >&2
  echo "  → Run your type-check command in the affected package to see the full list (see hooks.env TYPECHECK_CMD)." >&2
  exit 0
fi

# Lint errors
if echo "$ERROR_OUTPUT" | grep -qiE "eslint|Parsing error|no-unused|ruff|flake8|golangci"; then
  echo "HOOK [failure] Lint error detected." >&2
  echo "  → Run your linter with --fix where supported (see hooks.env LINT_CMD)." >&2
  exit 0
fi

# Migration failures (config-driven regen hint)
if echo "$ERROR_OUTPUT" | grep -qiE "migration|migrate"; then
  echo "HOOK [failure] Migration issue detected." >&2
  [[ -n "$MIGRATIONS_REGEN_CMD" ]] && echo "  → Do not hand-edit generated migrations — run '$MIGRATIONS_REGEN_CMD' instead." >&2
  echo "  → Verify your database connection settings if running locally." >&2
  exit 0
fi

# Dependency / module resolution failures
if echo "$ERROR_OUTPUT" | grep -qiE "npm ERR!|ENOENT|cannot find module|module not found|ModuleNotFound|no module named"; then
  echo "HOOK [failure] Dependency/module resolution error." >&2
  echo "  → Install dependencies in the relevant sub-project and retry." >&2
  exit 0
fi

exit 0
