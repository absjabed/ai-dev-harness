#!/usr/bin/env bash
# PostToolUse hook — runs after Claude edits a file.
# Claude Code delivers the hook payload as JSON on stdin (NOT positional args).
# Registered in .claude/settings.json for matcher "Edit|Write|MultiEdit".
# Config-driven: reads .claude/hooks/hooks.env. Every check is opt-in — blank value or
# *_CHECK="off" ⇒ skipped. Non-blocking (exit 0 always). Findings go to stderr AND, as
# hookSpecificOutput.additionalContext JSON on stdout, to Claude: Claude never sees the
# stderr of a hook that exits 0, so without the JSON the feedback reaches nobody.

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
SUPPRESSION_CHECK="${SUPPRESSION_CHECK:-off}"
SUPPRESSION_PATTERNS="${SUPPRESSION_PATTERNS:-}"

payload="$(cat)"

# The edit's new and old text, for the suppression check (written only when it is on).
TEXT_DIR=""
if [[ "$SUPPRESSION_CHECK" == "warn" && -n "$SUPPRESSION_PATTERNS" ]]; then
  TEXT_DIR="$(mktemp -d 2>/dev/null || echo '')"
  trap '[[ -n "$TEXT_DIR" ]] && rm -rf "$TEXT_DIR"' EXIT
fi

FILE="$(printf '%s' "$payload" | node -e '
let raw = "";
process.stdin.on("data", c => raw += c).on("end", () => {
  try {
    const j = JSON.parse(raw);
    const ti = j.tool_input || {};
    const dir = process.argv[1];
    if (dir) {
      const pick = k => [ti[k], ...(ti.edits || []).map(e => e[k])].filter(s => typeof s === "string").join("\n");
      require("fs").writeFileSync(dir + "/new", pick("new_string") + "\n" + (ti.content || ""));
      require("fs").writeFileSync(dir + "/old", pick("old_string"));
    }
    process.stdout.write(ti.file_path || ti.path || ti.notebook_path || "");
  } catch (_) { process.stdout.write(""); }
});
' "$TEXT_DIR" 2>/dev/null || echo "")"

[[ -z "$FILE" ]] && exit 0
FILE="$(printf '%s' "$FILE" | tr '\\' '/')"   # Windows paths arrive with backslashes; the checks below match on "/"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo '')"

# note <text>: record a finding for both the user (stderr) and Claude (JSON at exit).
CONTEXT=""
note() { printf '%s\n' "$1" >&2; CONTEXT+="$1"$'\n'; }
emit_context() {
  [[ -z "$CONTEXT" ]] && return 0
  printf '%s' "$CONTEXT" | node -e '
let r = "";
process.stdin.on("data", c => r += c).on("end", () => process.stdout.write(JSON.stringify(
  { hookSpecificOutput: { hookEventName: "PostToolUse", additionalContext: r.trim() } })));
' 2>/dev/null || true
}
trap 'emit_context; [[ -n "$TEXT_DIR" ]] && rm -rf "$TEXT_DIR"' EXIT

# helper: is $FILE inside sub-project dir $1 ?
in_dir() { [[ "$1" == "." || "$FILE" == */"$1"/* || "$FILE" == "$1"/* ]]; }

# ── Type-check / lint the changed sub-project (config-driven) ────────────────
if [[ -n "$PACKAGE_DIRS" && -n "$REPO_ROOT" ]]; then
  for d in $PACKAGE_DIRS; do
    if in_dir "$d"; then
      # Only a failing run is reported, capped at 20 lines, so a clean edit costs no context.
      if [[ -n "$TYPECHECK_CMD" && -d "${REPO_ROOT}/${d}" ]]; then
        OUT="$(cd "${REPO_ROOT}/${d}" && eval "$TYPECHECK_CMD" 2>&1)" \
          || note "Type-check failed in ${d}/ after editing $FILE:"$'\n'"$(printf '%s\n' "$OUT" | head -20)"
      fi
      if [[ -n "$LINT_CMD" && -d "${REPO_ROOT}/${d}" ]]; then
        OUT="$(cd "${REPO_ROOT}/${d}" && eval "$LINT_CMD \"$FILE\"" 2>&1)" \
          || note "Lint failed on $FILE:"$'\n'"$(printf '%s\n' "$OUT" | head -20)"
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
        note "WARNING: $FILE adds query patterns with no '$TENANT_KEY' in the diff. Verify tenant isolation."
      fi
    fi
  fi
fi

# ── Optional: frontend env-accessor check ────────────────────────────────────
if [[ "$FRONTEND_ENV_CHECK" == "on" && -n "$FRONTEND_ENV_BAD_PATTERN" ]]; then
  if [[ -z "$FRONTEND_DIR" ]] || in_dir "$FRONTEND_DIR"; then
    if grep -qE "$FRONTEND_ENV_BAD_PATTERN" "$FILE" 2>/dev/null; then
      note "WARNING: $FILE uses a disallowed env accessor (/$FRONTEND_ENV_BAD_PATTERN/).${FRONTEND_ENV_GOOD_HINT:+ Use $FRONTEND_ENV_GOOD_HINT instead.}"
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
          note "WARNING: $FILE introduces raw hex color(s). Map to a design token${DESIGN_TOKEN_DOC:+ (see $DESIGN_TOKEN_DOC)}."
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
      note "WARNING: $FILE changed with no test changes in the working tree. Write the failing test first."
    fi
  fi
  set +f
fi

# ── Optional: suppression / skipped-test guard (warn mode) ───────────────────
# Warn when the edit adds a lint/type/coverage suppression or a skipped/focused test — the
# shortcut an agent under a failing gate reaches for. Block mode lives in pre-tool-use.sh.
IS_SOURCE=1   # SOURCE_GLOBS (blank ⇒ every file): docs that mention a suppression are not one
if [[ -n "${SOURCE_GLOBS:-}" ]]; then
  IS_SOURCE=0
  set -f
  for g in $SOURCE_GLOBS; do [[ "$FILE" == $g ]] && IS_SOURCE=1 && break; done
  set +f
fi
if [[ -n "$TEXT_DIR" && -f "$TEXT_DIR/new" && "$IS_SOURCE" -eq 1 ]]; then
  # A Write replaces the whole file, so the old text is the committed copy, if any.
  TRACKED="$(git ls-files --full-name -- "$FILE" 2>/dev/null || true)"
  if [[ ! -s "$TEXT_DIR/old" && -n "$TRACKED" ]]; then
    git show "HEAD:$TRACKED" > "$TEXT_DIR/old" 2>/dev/null || : > "$TEXT_DIR/old"
  fi
  NEW_HITS="$(grep -E -- "$SUPPRESSION_PATTERNS" "$TEXT_DIR/new" 2>/dev/null || true)"
  if [[ -n "$NEW_HITS" ]]; then
    NEW_COUNT="$(printf '%s\n' "$NEW_HITS" | wc -l | tr -d ' ')"
    OLD_COUNT="$(grep -cE -- "$SUPPRESSION_PATTERNS" "$TEXT_DIR/old" 2>/dev/null || true)"
    if [[ "$NEW_COUNT" -gt "${OLD_COUNT:-0}" ]]; then
      note "WARNING: $FILE gains a suppression or skipped test:"$'\n'"$(printf '%s\n' "$NEW_HITS" | head -5)"$'\n'"Fix the cause instead. If it must stay, state why in the test report; the reviewer treats an unexplained one as a BLOCKER."
    fi
  fi
fi

exit 0
