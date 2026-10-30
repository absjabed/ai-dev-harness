#!/usr/bin/env bash
# Stop hook — reminds you of uncommitted changes on feature/epic branches.
# Non-blocking (exit 0 always). The reminder goes to stderr and, as a JSON systemMessage on
# stdout, to the user: stderr of a hook that exits 0 is shown to nobody, and feeding it to
# Claude instead (additionalContext) would keep the turn going on every stop.

set -euo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
[[ -f "$HOOK_DIR/hooks.env" ]] && source "$HOOK_DIR/hooks.env"
PREFIX_RE="$(echo "${WORK_BRANCH_PREFIXES:-feature epic}" | tr ' ' '|')"

# Parse stop_hook_active to avoid infinite reminder loops
payload="$(cat)"
HOOK_ACTIVE="$(printf '%s' "$payload" | node -e '
let raw = "";
process.stdin.on("data", c => raw += c).on("end", () => {
  try {
    const j = JSON.parse(raw);
    process.stdout.write(j.stop_hook_active ? "true" : "false");
  } catch (_) { process.stdout.write("false"); }
});
')"

# Skip if we are already in a hook-triggered continuation
[[ "$HOOK_ACTIVE" == "true" ]] && exit 0

BRANCH="$(git branch --show-current 2>/dev/null || echo '')"

# Only relevant on configured work branches (default: feature/* or epic/*)
if ! echo "$BRANCH" | grep -qE "^(${PREFIX_RE})/"; then
  exit 0
fi

# Check for uncommitted tracked changes (ignore untracked files)
UNCOMMITTED="$(git status --porcelain 2>/dev/null | grep -v '^??' || true)"

if [[ -n "$UNCOMMITTED" ]]; then
  MSG="Reminder: uncommitted changes exist on branch '$BRANCH'. Commit before moving to the next phase."
  echo "$MSG" >&2
  printf '%s' "$MSG" | node -e '
let r = "";
process.stdin.on("data", c => r += c).on("end", () => process.stdout.write(JSON.stringify({ systemMessage: r })));
' 2>/dev/null || true
fi

exit 0
