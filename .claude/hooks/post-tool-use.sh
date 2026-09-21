#!/usr/bin/env bash
# PostToolUse hook — runs after Claude edits a file.
# Claude Code delivers the hook payload as JSON on stdin (NOT positional args).
# Registered in .claude/settings.json for matcher "Edit|Write|MultiEdit".
# Config-driven: reads .claude/hooks/hooks.env. Every check is opt-in — blank value or
# *_CHECK="off" ⇒ skipped. Non-blocking (exit 0 always); output goes to stderr.

set -euo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
[[ -f "$HOOK_DIR/hooks.env" ]] && source "$HOOK_DIR/hooks.env"

PACKAGE_DIRS="${PACKAGE_DIRS:-}"
BACKEND_DIR="${BACKEND_DIR:-}"
FRONTEND_DIR="${FRONTEND_DIR:-}"
TYPECHECK_CMD="${TYPECHECK_CMD:-}"
LINT_CMD="${LINT_CMD:-}"
TENANT_ISOLATION_CHECK="${TENANT_ISOLATION_CHECK:-off}"
TENANT_KEY="${TENANT_KEY:-}"
FRONTEND_ENV_CHECK="${FRONTEND_ENV_CHECK:-off}"
FRONTEND_ENV_BAD_PATTERN="${FRONTEND_ENV_BAD_PATTERN:-}"
FRONTEND_ENV_GOOD_HINT="${FRONTEND_ENV_GOOD_HINT:-}"
DESIGN_TOKEN_CHECK="${DESIGN_TOKEN_CHECK:-off}"
DESIGN_TOKEN_DOC="${DESIGN_TOKEN_DOC:-}"
TDD_CHECK="${TDD_CHECK:-off}"
TEST_FILE_PATTERNS="${TEST_FILE_PATTERNS:-}"

payload="$(cat)"

FILE="$(printf '%s' "$payload" | node -e '
let raw = "";
process.stdin.on("data", c => raw += c).on("end", () => {
  try {
    const j = JSON.parse(raw);
    const ti = j.tool_input || {};
    process.stdout.write(ti.file_path || ti.path || ti.notebook_path || "");
  } catch (_) { process.stdout.write(""); }
});
' 2>/dev/null || echo "")"

[[ -z "$FILE" ]] && exit 0
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo '')"

# helper: is $FILE inside sub-project dir $1 ?
in_dir() { [[ "$FILE" == */"$1"/* || "$FILE" == "$1"/* ]]; }

# ── Type-check / lint the changed sub-project (config-driven) ────────────────
if [[ -n "$PACKAGE_DIRS" && -n "$REPO_ROOT" ]]; then
  for d in $PACKAGE_DIRS; do
    if in_dir "$d"; then
      if [[ -n "$TYPECHECK_CMD" && -d "${REPO_ROOT}/${d}" ]]; then
        (cd "${REPO_ROOT}/${d}" && eval "$TYPECHECK_CMD" 2>&1 | head -20) >&2 || true
      fi
      if [[ -n "$LINT_CMD" && -d "${REPO_ROOT}/${d}" ]]; then
        (cd "${REPO_ROOT}/${d}" && eval "$LINT_CMD \"$FILE\"" 2>&1 | head -20) >&2 || true
      fi
      break
    fi
  done
fi

# ── Optional: multi-tenant isolation check ───────────────────────────────────
# Warn when a diff adds query patterns but no tenant key. Heuristic, not a gate.
if [[ "$TENANT_ISOLATION_CHECK" == "on" && -n "$TENANT_KEY" ]]; then
  if [[ -z "$BACKEND_DIR" ]] || in_dir "$BACKEND_DIR"; then
    DIFF="$(git diff HEAD -- "$FILE" 2>/dev/null || true)"
    if [[ -n "$DIFF" ]]; then
      ADDED="$(echo "$DIFF" | grep '^+' | grep -v '^+++' || true)"
      # NB: grep -c prints "0" AND exits 1 on no match — "|| echo 0" would yield "0\n0".
      QUERY_LINES=$(echo "$ADDED" | grep -cE '\.(where|select|from|find|query|filter)\(' 2>/dev/null || true)
      QUERY_LINES="${QUERY_LINES:-0}"
      KEY_LINES=$(echo "$ADDED" | grep -cE "$TENANT_KEY" 2>/dev/null || true)
      KEY_LINES="${KEY_LINES:-0}"
      if [[ "$QUERY_LINES" -gt 0 && "$KEY_LINES" -eq 0 ]]; then
        echo "WARNING: $FILE adds query patterns with no '$TENANT_KEY' in the diff. Verify tenant isolation." >&2
      fi
    fi
  fi
fi

# ── Optional: frontend env-accessor check ────────────────────────────────────
if [[ "$FRONTEND_ENV_CHECK" == "on" && -n "$FRONTEND_ENV_BAD_PATTERN" ]]; then
  if [[ -z "$FRONTEND_DIR" ]] || in_dir "$FRONTEND_DIR"; then
    if grep -qE "$FRONTEND_ENV_BAD_PATTERN" "$FILE" 2>/dev/null; then
      echo "WARNING: $FILE uses a disallowed env accessor (/$FRONTEND_ENV_BAD_PATTERN/).${FRONTEND_ENV_GOOD_HINT:+ Use $FRONTEND_ENV_GOOD_HINT instead.}" >&2
    fi
  fi
fi

# ── Optional: raw-hex design-token check ─────────────────────────────────────
if [[ "$DESIGN_TOKEN_CHECK" == "on" ]]; then
  if [[ -z "$FRONTEND_DIR" ]] || in_dir "$FRONTEND_DIR"; then
    # Exempt token-source files (the theme/palette definitions) via DESIGN_TOKEN_EXEMPT_GLOBS.
    EXEMPT=0
    set -f  # keep the configured globs literal while word-splitting them below
    for g in ${DESIGN_TOKEN_EXEMPT_GLOBS:-}; do
      [[ "$FILE" == $g ]] && EXEMPT=1 && break
    done
    set +f
    if [[ "$EXEMPT" -eq 0 ]]; then
      DIFF="$(git diff HEAD -- "$FILE" 2>/dev/null || true)"
      if [[ -n "$DIFF" ]]; then
        HEX_LINES=$(echo "$DIFF" | grep '^+' | grep -v '^+++' | grep -cE '#[0-9a-fA-F]{3,8}\b' 2>/dev/null || true)
        HEX_LINES="${HEX_LINES:-0}"
        if [[ "$HEX_LINES" -gt 0 ]]; then
          echo "WARNING: $FILE introduces raw hex color(s). Map to a design token${DESIGN_TOKEN_DOC:+ (see $DESIGN_TOKEN_DOC)}." >&2
        fi
      fi
    fi
  fi
fi

# ── Optional: TDD nudge ──────────────────────────────────────────────────────
# Warn when a source edit lands with no test change in the working tree. Heuristic, not a gate.
if [[ "$TDD_CHECK" == "on" && -n "$TEST_FILE_PATTERNS" && -n "$REPO_ROOT" ]]; then
  set -f  # keep the configured globs literal while word-splitting them below
  # Never nudge on test files themselves, or on exempt files (docs, config, ...).
  SKIP=0
  for g in $TEST_FILE_PATTERNS ${TDD_EXEMPT_GLOBS:-}; do
    [[ "$FILE" == $g ]] && SKIP=1 && break
  done
  # When PACKAGE_DIRS is set, only nudge on files inside a sub-project.
  if [[ "$SKIP" -eq 0 && -n "$PACKAGE_DIRS" ]]; then
    SKIP=1
    for d in $PACKAGE_DIRS; do
      in_dir "$d" && SKIP=0 && break
    done
  fi
  if [[ "$SKIP" -eq 0 ]]; then
    # Include staged and untracked files — a brand-new test file counts as a test change.
    CHANGED="$( { git diff HEAD --name-only; git diff --cached --name-only; git ls-files --others --exclude-standard; } 2>/dev/null || true)"
    TEST_CHANGED=0
    for f in $CHANGED; do
      for g in $TEST_FILE_PATTERNS; do
        [[ "$f" == $g ]] && TEST_CHANGED=1 && break 2
      done
    done
    if [[ "$TEST_CHANGED" -eq 0 ]]; then
      echo "WARNING: $FILE changed with no test changes in the working tree. Write the failing test first." >&2
    fi
  fi
  set +f
fi

exit 0
