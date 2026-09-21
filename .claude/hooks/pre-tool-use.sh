#!/usr/bin/env bash
# PreToolUse hook — safety warnings/blocks before Claude edits a file.
# Claude Code delivers the hook payload as JSON on stdin (NOT positional args).
# Registered in .claude/settings.json for matcher "Edit|Write|MultiEdit".
# Config-driven: reads .claude/hooks/hooks.env. Blank values ⇒ that guard is skipped.
#
# Behavior: non-blocking except the migrations guard. Warnings go to stderr; exit 2 = hard block.

set -euo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
[[ -f "$HOOK_DIR/hooks.env" ]] && source "$HOOK_DIR/hooks.env"

MIGRATIONS_GLOB="${MIGRATIONS_GLOB:-}"
MIGRATIONS_REGEN_CMD="${MIGRATIONS_REGEN_CMD:-}"
SENSITIVE_CONFIG_GLOBS="${SENSITIVE_CONFIG_GLOBS:-}"

payload="$(cat)"

read -r TOOL FILE <<EOF
$(printf '%s' "$payload" | node -e '
let raw = "";
process.stdin.on("data", c => raw += c).on("end", () => {
  try {
    const j = JSON.parse(raw);
    const ti = j.tool_input || {};
    const file = ti.file_path || ti.path || ti.notebook_path || "";
    process.stdout.write(`${j.tool_name || ""} ${file}`);
  } catch (_) {
    process.stdout.write(" ");
  }
});
' 2>/dev/null || echo " ")
EOF

# Warn when editing a real .env file (but allow .env.example). (Always on — universal.)
if [[ "$FILE" == *.env && "$FILE" != *.env.example ]]; then
  echo "WARNING: $TOOL is about to modify an .env file ($FILE). Confirm this is intentional and contains no committed secrets." >&2
fi

# Warn when editing production configuration. (Always on — universal.)
if [[ "$FILE" == *production* || "$FILE" == *prod.* || "$FILE" == *.prod.* ]]; then
  echo "WARNING: $TOOL is editing a production configuration file ($FILE)." >&2
fi

# Block direct edits to generated migration files (config-driven).
if [[ -n "$MIGRATIONS_GLOB" && "$FILE" == $MIGRATIONS_GLOB ]]; then
  echo "BLOCKED: Generated migration files must not be edited directly." >&2
  [[ -n "$MIGRATIONS_REGEN_CMD" ]] && echo "Run '$MIGRATIONS_REGEN_CMD' to regenerate migrations instead." >&2
  exit 2
fi

# Warn when editing configured sensitive config files (config-driven, space-separated globs).
if [[ -n "$SENSITIVE_CONFIG_GLOBS" ]]; then
  for glob in $SENSITIVE_CONFIG_GLOBS; do
    if [[ "$FILE" == $glob ]]; then
      echo "WARNING: Editing sensitive config ($FILE). Verify permissions, names, and environment values are correct." >&2
      break
    fi
  done
fi

exit 0
