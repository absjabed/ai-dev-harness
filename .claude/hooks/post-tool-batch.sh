#!/usr/bin/env bash
# PostToolBatch hook — runs a full-project type-check after a batch of parallel tool
# calls, catching cross-file errors that per-file checks miss.
# Config-driven: reads .claude/hooks/hooks.env. Fires only when 2+ files from the same
# sub-project (PACKAGE_DIRS) changed AND it has a type-check command (TYPECHECK_CMD, or its
# PACKAGE_CMDS entry). Non-blocking (exit 0). A failing type-check goes to stderr and, as hookSpecificOutput.additionalContext JSON on stdout, to
# Claude, which never sees the stderr of a hook that exits 0.

set -euo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
[[ -f "$HOOK_DIR/hooks.env" ]] && source "$HOOK_DIR/hooks.env"

PACKAGE_DIRS="${PACKAGE_DIRS:-}"
PACKAGE_CMDS="${PACKAGE_CMDS:-}"
TYPECHECK_CMD="${TYPECHECK_CMD:-}"

# PACKAGE_CMDS: optional per-folder commands, "dir|lint|typecheck" entries separated by ";".
trim() { local s="$1"; s="${s#"${s%%[![:space:]]*}"}"; printf '%s' "${s%"${s##*[![:space:]]}"}"; }
norm_dir() { local d; d="$(trim "$1")"; d="${d#./}"; [[ "$d" == "." ]] || d="${d%/}"; [[ -n "$d" || -z "$(trim "$1")" ]] || d="."; printf '%s' "$d"; }
# pkg_dirs <PACKAGE_DIRS> <PACKAGE_CMDS>: each PACKAGE_CMDS dir, then the PACKAGE_DIRS not among them.
pkg_dirs() {
  local out=" " d rest
  while IFS='|' read -r d rest; do
    d="$(norm_dir "$d")"
    if [[ -n "$d" && "$out" != *" $d "* ]]; then out+="$d "; fi
  done <<< "$(printf '%s' "$2" | tr ';' '\n')"
  for d in $1; do [[ "$out" == *" $(norm_dir "$d") "* ]] || out+="$d "; done
  trim "$out"
}
# pkg_cmd <PACKAGE_CMDS> <dir> <2 = lint | 3 = typecheck> <default>: the command for <dir>. An
# entry's blank field keeps <default>; "-" means none there (prints nothing).
pkg_cmd() {
  local out="$4" d l t c
  while IFS='|' read -r d l t; do
    [[ -n "$d" && "$(norm_dir "$d")" == "$(norm_dir "$2")" ]] || continue
    if [[ "$3" == 2 ]]; then c="$(trim "$l")"; else c="$(trim "$t")"; fi
    if [[ "$c" == "-" ]]; then out=""; elif [[ -n "$c" ]]; then out="$c"; fi
  done <<< "$(printf '%s' "$1" | tr ';' '\n')"
  printf '%s' "$out"
}
PKG_DIRS="$(pkg_dirs "$PACKAGE_DIRS" "$PACKAGE_CMDS")"

# Nothing configured ⇒ nothing to do.
[[ -z "$PKG_DIRS" || -z "$TYPECHECK_CMD$PACKAGE_CMDS" ]] && exit 0

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
for d in $PKG_DIRS; do
  TC="$(pkg_cmd "$PACKAGE_CMDS" "$d" 3 "$TYPECHECK_CMD")"
  [[ -z "$TC" ]] && continue
  # Paths arrive with backslashes on Windows; match on forward slashes.
  COUNT=$(echo "$FILES" | tr '\\' '/' | grep -cE "(^|/)${d}/" || true)
  if [[ "$COUNT" -ge 2 && -d "${REPO_ROOT}/${d}" ]]; then
    echo "[PostToolBatch] $COUNT files changed in ${d}/ — running full type-check..." >&2
    if ! OUT="$(cd "${REPO_ROOT}/${d}" && eval "$TC" 2>&1)"; then
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
