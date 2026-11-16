#!/usr/bin/env bash
# PostToolUseFailure hook — fires when a tool call returns a non-zero exit or error.
# Emits a structured, actionable hint based on the error text (the payload's `error` field).
# Stack-neutral: hints trigger on the error output itself, not on any assumed stack.
# Config-driven extras come from .claude/hooks/hooks.env. Non-blocking (exit 0 always).
# The hint goes to stderr AND, as hookSpecificOutput.additionalContext JSON on stdout, to Claude:
# Claude never sees the stderr of a hook that exits 0, so without the JSON the hint reaches nobody.

set -euo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
[[ -f "$HOOK_DIR/hooks.env" ]] && source "$HOOK_DIR/hooks.env"

MIGRATIONS_REGEN_CMD="${MIGRATIONS_REGEN_CMD:-}"

payload="$(cat)"

field() {  # $1 = JS expression over the parsed payload j
  printf '%s' "$payload" | node -e '
let raw="";process.stdin.on("data",c=>raw+=c).on("end",()=>{try{const j=JSON.parse(raw);const v=('"$1"');process.stdout.write(typeof v==="string"?v:"");}catch(_){process.stdout.write("");}});
' 2>/dev/null || echo ""
}

TOOL_NAME="$(field 'j.tool_name||j.tool')"
ERROR_OUTPUT="$(field 'j.error||j.output||j.stderr')"
COMMAND="$(field '(j.tool_input||{}).command')"

# Print the hint to stderr and hand it to Claude as additionalContext, then stop.
hint() {
  local text
  text="$(printf '%s\n' "$@")"
  printf '%s\n' "$text" >&2
  printf '%s' "$text" | node -e '
let r="";process.stdin.on("data",c=>r+=c).on("end",()=>process.stdout.write(JSON.stringify(
  { hookSpecificOutput: { hookEventName: "PostToolUseFailure", additionalContext: r.trim() } })));
' 2>/dev/null || true
  exit 0
}

# grep / rg exiting 1 = "no match", not a real failure worth surfacing. A shell command's error
# text starts with "Exit code 1"; match only search commands, so a failing test run (also exit 1)
# still gets its hint.
if echo "$TOOL_NAME" | grep -qiE "^(bash|powershell)$" \
   && echo "$ERROR_OUTPUT" | head -n 1 | grep -qi "^exit code 1$" \
   && echo "$COMMAND" | grep -qE '^[[:space:]]*(grep|egrep|fgrep|rg)([[:space:]]|$)'; then
  exit 0
fi

# Type errors (TypeScript, mypy, tsc, etc.)
if echo "$ERROR_OUTPUT" | grep -qE "TS[0-9]+:|error TS|error: .*type|mypy"; then
  hint "HOOK [failure] Type error detected." \
       "  → Run your type-check command in the affected package to see the full list (see hooks.env TYPECHECK_CMD)."
fi

# Lint errors
if echo "$ERROR_OUTPUT" | grep -qiE "eslint|Parsing error|no-unused|ruff|flake8|golangci"; then
  hint "HOOK [failure] Lint error detected." \
       "  → Run your linter with --fix where supported (see hooks.env LINT_CMD)."
fi

# Migration failures (config-driven regen hint)
if echo "$ERROR_OUTPUT" | grep -qiE "migration|migrate"; then
  if [[ -n "$MIGRATIONS_REGEN_CMD" ]]; then
    hint "HOOK [failure] Migration issue detected." \
         "  → Do not hand-edit generated migrations — run '$MIGRATIONS_REGEN_CMD' instead." \
         "  → Verify your database connection settings if running locally."
  fi
  hint "HOOK [failure] Migration issue detected." \
       "  → Verify your database connection settings if running locally."
fi

# Dependency / module resolution failures
if echo "$ERROR_OUTPUT" | grep -qiE "npm ERR!|ENOENT|cannot find module|module not found|ModuleNotFound|no module named"; then
  hint "HOOK [failure] Dependency/module resolution error." \
       "  → Install dependencies in the relevant sub-project and retry."
fi

exit 0
