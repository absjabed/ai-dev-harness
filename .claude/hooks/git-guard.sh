#!/usr/bin/env bash
# PreToolUse/Bash hook — blocks dangerous version-control and deploy commands.
# Config-driven: reads .claude/hooks/hooks.env. Any check whose value is blank is skipped.
# Exit 2 = hard block (Claude sees the stderr message). Exit 0 = allow (optional warning).

set -euo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
[[ -f "$HOOK_DIR/hooks.env" ]] && source "$HOOK_DIR/hooks.env"

PROTECTED_BRANCHES="${PROTECTED_BRANCHES:-}"
WORK_BRANCH_PREFIXES="${WORK_BRANCH_PREFIXES:-}"
DEPLOY_CMD="${DEPLOY_CMD:-}"
PROD_STAGE="${PROD_STAGE:-}"
PR_TERM="${PR_TERM:-pull request}"

payload="$(cat)"

CMD="$(printf '%s' "$payload" | node -e '
let raw = "";
process.stdin.on("data", c => raw += c).on("end", () => {
  try {
    const j = JSON.parse(raw);
    process.stdout.write((j.tool_input || {}).command || "");
  } catch (_) { process.stdout.write(""); }
});
' 2>/dev/null || echo "")"

# Nothing to check unless this is a git command (or the configured deploy command).
IS_GIT=0; IS_DEPLOY=0
echo "$CMD" | grep -qE '(^|\s)git\s' && IS_GIT=1
if [[ -n "$DEPLOY_CMD" ]] && echo "$CMD" | grep -qF "$DEPLOY_CMD"; then IS_DEPLOY=1; fi
[[ "$IS_GIT" -eq 0 && "$IS_DEPLOY" -eq 0 ]] && exit 0

# ── HARD BLOCKS (git — always on; these are universally destructive) ─────────
if echo "$CMD" | grep -qE 'git\s+push\s.*(--force|-f\b)'; then
  echo "BLOCKED: Force push is not allowed. Use 'git revert' to undo commits safely." >&2
  exit 2
fi
if echo "$CMD" | grep -qE 'git\s+reset\s+--hard'; then
  echo "BLOCKED: 'git reset --hard' is not allowed. Use 'git revert' to undo committed changes, or 'git stash' to save uncommitted work." >&2
  exit 2
fi

# ── Direct push to a protected branch (config-driven) ────────────────────────
if [[ -n "$PROTECTED_BRANCHES" ]] && echo "$CMD" | grep -qE 'git\s+push'; then
  for b in $PROTECTED_BRANCHES; do
    if echo "$CMD" | grep -qE "git\s+push\s+(origin\s+)?${b}(\s|:|$)"; then
      echo "BLOCKED: Direct push to '$b' is not allowed. Open a ${PR_TERM} instead." >&2
      exit 2
    fi
  done
fi

# ── Deploy to production (config-driven) ─────────────────────────────────────
if [[ "$IS_DEPLOY" -eq 1 && -n "$PROD_STAGE" ]]; then
  if echo "$CMD" | grep -qE -- "(--stage|--env|-e)\s+${PROD_STAGE}\b" || echo "$CMD" | grep -qE "\b${PROD_STAGE}\b"; then
    echo "BLOCKED: Deploying to '${PROD_STAGE}' directly is not allowed. Use the release/hotfix workflow." >&2
    exit 2
  fi
fi

# ── WARNINGS (allow, but inform) ─────────────────────────────────────────────
# Push from a branch that isn't one of the allowed work-branch prefixes.
if [[ -n "$WORK_BRANCH_PREFIXES" ]] && echo "$CMD" | grep -qE 'git\s+push'; then
  CURRENT_BRANCH="$(git branch --show-current 2>/dev/null || echo '')"
  if [[ -n "$CURRENT_BRANCH" ]]; then
    ALLOWED=0
    for p in $WORK_BRANCH_PREFIXES; do
      echo "$CURRENT_BRANCH" | grep -qE "^${p}/" && ALLOWED=1
    done
    for b in ${PROTECTED_BRANCHES:-}; do [[ "$CURRENT_BRANCH" == "$b" ]] && ALLOWED=1; done
    [[ "$ALLOWED" -eq 0 ]] && echo "WARNING: Pushing from '$CURRENT_BRANCH', which is not one of the ${WORK_BRANCH_PREFIXES// //, } work-branch prefixes. Verify this is intentional." >&2
  fi
fi

exit 0
