#!/usr/bin/env bash
# SessionStart/compact hook — re-injects orientation context after compaction.
# stdout is added to Claude's context automatically.
# Reads .claude/hooks/hooks.env for WORK_BRANCH_PREFIXES (defaults to feature|epic).

set -euo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
[[ -f "$HOOK_DIR/hooks.env" ]] && source "$HOOK_DIR/hooks.env"

# Build a regex alternation from WORK_BRANCH_PREFIXES ("feature epic fix" → "feature|epic|fix").
PREFIXES="${WORK_BRANCH_PREFIXES:-feature epic}"
PREFIX_RE="$(echo "$PREFIXES" | tr ' ' '|')"

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo '.')"
BRANCH="$(git branch --show-current 2>/dev/null || echo 'unknown')"
SCOPE="$(head -1 "${REPO_ROOT}/.ai/config/current-scope.md" 2>/dev/null | sed 's/^# //' || echo 'auto')"
COMMITS="$(git log --oneline -5 2>/dev/null || echo '(no commits found)')"

# Set dynamic session title (branch + scope shown in Claude Code tab)
SCOPE_SHORT="$(echo "$SCOPE" | sed 's/^Scope: //' | sed 's/^# Forced scope: //' | tr '[:upper:]' '[:lower:]')"
printf '{"hookSpecificOutput":{"sessionTitle":"%s | %s"}}\n' "$BRANCH" "$SCOPE_SHORT"

echo "=== Session resumed after compaction ==="
echo "Branch: $BRANCH"
echo "Scope: $SCOPE"

# Detect in-progress epic/feature from branch name
if echo "$BRANCH" | grep -qE "^(${PREFIX_RE})/"; then
  # <prefix>/EPIC/FEATURE → epic=EPIC, sub-feature=FEATURE
  EPIC_PART=$(echo "$BRANCH" | sed -E "s,^(${PREFIX_RE})/,," | cut -d'/' -f1)
  SUB_FEATURE=$(echo "$BRANCH" | sed -E "s,^(${PREFIX_RE})/,," | cut -s -d'/' -f2-)

  EPIC_BREAKDOWN="${REPO_ROOT}/.ai/features/${EPIC_PART}/epic-breakdown.md"
  if [[ -f "$EPIC_BREAKDOWN" ]]; then
    echo "In-progress epic: $EPIC_PART"
    [[ -n "$SUB_FEATURE" ]] && echo "Current sub-feature: $SUB_FEATURE"
    echo "Epic breakdown: .ai/features/${EPIC_PART}/epic-breakdown.md"
  else
    echo "In-progress feature: $EPIC_PART"
    [[ -n "$SUB_FEATURE" ]] && echo "Sub-feature: $SUB_FEATURE"
  fi

  # Machine-maintained workflow state, if the feature workflow keeps one
  STATE_FILE="${REPO_ROOT}/.ai/features/${EPIC_PART}/STATE.md"
  if [[ -f "$STATE_FILE" ]]; then
    echo "Workflow state: .ai/features/${EPIC_PART}/STATE.md"
    # Print each heading plus the first non-blank line after it (the template
    # separates headings from their value with a blank line).
    awk '/^## (Current phase|Next action)$/ {print; want=1; next} want && NF {print; want=0}' \
      "$STATE_FILE" 2>/dev/null | sed 's/^/  /' || true
  fi
fi

echo "Recent commits:"
echo "$COMMITS" | sed 's/^/  /'
echo "Action: Resume where you left off. Re-read the technical spec and epic breakdown if you need context."
