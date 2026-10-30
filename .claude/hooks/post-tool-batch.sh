#!/usr/bin/env bash
# PostToolBatch hook — runs a full-project type-check after a batch of parallel tool
# calls, catching cross-file errors that per-file checks miss.
# Config-driven: reads .claude/hooks/hooks.env. Fires only when 2+ files from the same
# sub-project (PACKAGE_DIRS) changed AND TYPECHECK_CMD is set. Non-blocking (exit 0). A failing
# type-check goes to stderr and, as hookSpecificOutput.additionalContext JSON on stdout, to
# Claude, which never sees the stderr of a hook that exits 0.

set -euo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
[[ -f "$HOOK_DIR/hooks.env" ]] && source "$HOOK_DIR/hooks.env"

PACKAGE_DIRS="${PACKAGE_DIRS:-}"
TYPECHECK_CMD="${TYPECHECK_CMD:-}"

# Nothing configured ⇒ nothing to do.
[[ -z "$PACKAGE_DIRS" || -z "$TYPECHECK_CMD" ]] && exit 0

payload="$(cat)"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo '.')"

FILES="$(printf '%s' "$payload" | node -e '
let raw = "";
process.stdin.on("data", c => raw += c).on("end", () => {
  try {
    const j = JSON.parse(raw);
    const results = j.tool_calls || j.tool_results || j.results || [];
    const files = results.map(r => {
      const ti = r.tool_input || r.input || {};
      return ti.file_path || ti.path || ti.notebook_path || "";
    }).filter(Boolean);
    process.stdout.write(files.join("\n"));
  } catch (_) { process.stdout.write(""); }
});
' 2>/dev/null || echo "")"

[[ -z "$FILES" ]] && exit 0

CONTEXT=""
for d in $PACKAGE_DIRS; do
  # Paths arrive with backslashes on Windows; match on forward slashes.
  COUNT=$(echo "$FILES" | tr '\\' '/' | grep -cE "(^|/)${d}/" || true)
  if [[ "$COUNT" -ge 2 && -d "${REPO_ROOT}/${d}" ]]; then
    echo "[PostToolBatch] $COUNT files changed in ${d}/ — running full type-check..." >&2
    if ! OUT="$(cd "${REPO_ROOT}/${d}" && eval "$TYPECHECK_CMD" 2>&1)"; then
      MSG="Full type-check failed in ${d}/ after this batch of edits:"$'\n'"$(printf '%s\n' "$OUT" | tail -30)"
      printf '%s\n' "$MSG" >&2
      CONTEXT+="$MSG"$'\n'
    fi
  fi
done

if [[ -n "$CONTEXT" ]]; then
  printf '%s' "$CONTEXT" | node -e '
let r = "";
process.stdin.on("data", c => r += c).on("end", () => process.stdout.write(JSON.stringify(
  { hookSpecificOutput: { hookEventName: "PostToolBatch", additionalContext: r.trim() } })));
' 2>/dev/null || true
fi

exit 0
