#!/usr/bin/env bash
# Stop hook — reminds Claude of uncommitted changes on feature/epic branches.
# Non-blocking (exit 0 always). Prints to stderr so the message appears in the transcript.

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
  echo "Reminder: uncommitted changes exist on branch '$BRANCH'. Commit before moving to the next phase." >&2
fi

exit 0
