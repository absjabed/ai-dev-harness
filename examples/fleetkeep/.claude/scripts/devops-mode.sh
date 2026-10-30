#!/usr/bin/env bash
# Toggle whether the /agents:devops command may run shell commands.
#
#   ./.claude/scripts/devops-mode.sh off      → ADVISE-ONLY: removes Bash from the command's
#                                                allowed-tools. The agent physically cannot run
#                                                commands (harness-enforced); it only advises and
#                                                writes files/runbooks.
#   ./.claude/scripts/devops-mode.sh on       → EXECUTE: adds Bash back. The agent may run
#                                                commands, but EVERY command still requires your
#                                                explicit approval in Claude Code.
#   ./.claude/scripts/devops-mode.sh status   → print the current mode.
#
# The single source of truth is the `allowed-tools:` line in
# .claude/commands/agents/devops.md — this script just rewrites it.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CMD_FILE="$SCRIPT_DIR/../commands/agents/devops.md"

ADVISE_TOOLS="allowed-tools: Read, Write, Edit"
EXEC_TOOLS="allowed-tools: Read, Write, Edit, Bash"

if [[ ! -f "$CMD_FILE" ]]; then
  echo "error: cannot find $CMD_FILE" >&2
  exit 1
fi

current_mode() {
  if grep '^allowed-tools:' "$CMD_FILE" | grep -q 'Bash'; then
    echo "on"
  else
    echo "off"
  fi
}

set_tools_line() {
  # Replace ONLY the frontmatter line that begins with "allowed-tools:".
  awk -v repl="$1" '/^allowed-tools:/ {print repl; next} {print}' "$CMD_FILE" > "$CMD_FILE.tmp"
  mv "$CMD_FILE.tmp" "$CMD_FILE"
}

case "${1:-status}" in
  on)
    set_tools_line "$EXEC_TOOLS"
    echo "DevOps agent → ON (execute). Bash enabled. Commands still require your approval in Claude Code."
    ;;
  off)
    set_tools_line "$ADVISE_TOOLS"
    echo "DevOps agent → OFF (advise-only). Bash removed. The agent can only advise and write files."
    ;;
  status)
    echo "DevOps agent mode: $(current_mode)"
    ;;
  *)
    echo "Usage: $(basename "$0") [on|off|status]" >&2
    exit 1
    ;;
esac
