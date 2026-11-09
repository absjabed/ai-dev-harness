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
PACKAGE_CMDS="${PACKAGE_CMDS:-}"
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
# The file's repo, and its path inside it as the gate sees it, read from its nearest folder that
# exists (a Write may create the folder). Both are empty outside a repo; nothing here may fail,
# since an error exit would let the edit through unchecked. SOURCE_GLOBS are matched on REL.
near_dir() {
  local d="${FILE%/*}" rest="${FILE##*/}"
  [[ "$FILE" == */* ]] || d="."
  while [[ -n "$d" && ! -d "$d" ]]; do rest="${d##*/}/$rest"; [[ "$d" == */* ]] || { d=""; break; }; d="${d%/*}"; done
  [[ -n "$d" ]] && printf '%s\t%s' "$d" "$rest"
}
NEAR="$(near_dir || true)"
REL=""; FILE_TOP=""; FILE_COMMON=""
if [[ -n "$NEAR" ]]; then
  FILE_TOP="$(cd "${NEAR%%$'\t'*}" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null || true)"
  FILE_COMMON="$(cd "${NEAR%%$'\t'*}" 2>/dev/null && cd "$(git rev-parse --git-common-dir 2>/dev/null)" 2>/dev/null && pwd || true)"
  if [[ -n "$FILE_TOP" ]]; then
    REL="$(cd "${NEAR%%$'\t'*}" 2>/dev/null && git rev-parse --show-prefix 2>/dev/null || true)${NEAR#*$'\t'}"
  fi
fi
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
in_dir() {
  if [[ "$1" == "." ]]; then  # the whole repo, its worktrees included, never a file outside it
    [[ -n "$FILE_COMMON" && "$FILE_COMMON" -ef "$(git rev-parse --git-common-dir 2>/dev/null || true)" ]]  # -ef: the same folder, however spelled
    return
  fi
  [[ "$FILE" == */"$1"/* || "$FILE" == "$1"/* ]]
}
# helper: is $FILE inside any of the space-separated dirs in $1 ?
in_any() {
  local d
  for d in $1; do in_dir "$d" && return 0; done
  return 1
}

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

# ── Type-check / lint the changed sub-project (config-driven) ────────────────
PKG_ROOT="${FILE_TOP:-$REPO_ROOT}"  # the edited file's checkout: an epic worktree has its own
if [[ -n "$PKG_DIRS" && -n "$REPO_ROOT" ]]; then
  for d in $PKG_DIRS; do
    if in_dir "$d"; then
      [[ -d "$PKG_ROOT/$d" ]] || PKG_ROOT="$REPO_ROOT"  # a nested repo: its root holds no $d
      TC="$(pkg_cmd "$PACKAGE_CMDS" "$d" 3 "$TYPECHECK_CMD")"
      LC="$(pkg_cmd "$PACKAGE_CMDS" "$d" 2 "$LINT_CMD")"
      # Only a failing run is reported, capped at 20 lines, so a clean edit costs no context.
      if [[ -n "$TC" && -d "${PKG_ROOT}/${d}" ]]; then
        OUT="$(cd "${PKG_ROOT}/${d}" && eval "$TC" 2>&1)" \
          || note "Type-check failed in ${d}/ after editing $FILE:"$'\n'"$(printf '%s\n' "$OUT" | head -20)"
      fi
      if [[ -n "$LC" && -d "${PKG_ROOT}/${d}" ]]; then
        OUT="$(cd "${PKG_ROOT}/${d}" && eval "$LC \"$FILE\"" 2>&1)" \
          || note "Lint failed on $FILE:"$'\n'"$(printf '%s\n' "$OUT" | head -20)"
      fi
      break
    fi
  done
fi

# ── Optional: multi-tenant isolation check ───────────────────────────────────
# Warn when a diff adds query patterns but no tenant key. Heuristic, not a gate.
# BACKEND_DIR and FRONTEND_DIR may each list several dirs (space-separated).
if [[ "$TENANT_ISOLATION_CHECK" == "on" && -n "$TENANT_KEY" ]]; then
  if [[ -z "$BACKEND_DIR" ]] || in_any "$BACKEND_DIR"; then
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
  if [[ -z "$FRONTEND_DIR" ]] || in_any "$FRONTEND_DIR"; then
    if grep -qE "$FRONTEND_ENV_BAD_PATTERN" "$FILE" 2>/dev/null; then
      note "WARNING: $FILE uses a disallowed env accessor (/$FRONTEND_ENV_BAD_PATTERN/).${FRONTEND_ENV_GOOD_HINT:+ Use $FRONTEND_ENV_GOOD_HINT instead.}"
    fi
  fi
fi

# ── Optional: raw-hex design-token check ─────────────────────────────────────
if [[ "$DESIGN_TOKEN_CHECK" == "on" ]]; then
  if [[ -z "$FRONTEND_DIR" ]] || in_any "$FRONTEND_DIR"; then
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
  # When PACKAGE_DIRS (or PACKAGE_CMDS) is set, only nudge on files inside a sub-project.
  if [[ "$SKIP" -eq 0 && -n "$PKG_DIRS" ]]; then
    SKIP=1
    for d in $PKG_DIRS; do
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
# in_globs: does $FILE match one of SOURCE_GLOBS (blank: every file)? Matched on its path in
# the repo; when that is unknown, on any trailing part of the absolute path.
in_globs() {
  [[ -z "${SOURCE_GLOBS:-}" ]] && return 0
  local g
  set -f
  for g in $SOURCE_GLOBS; do
    if [[ -n "$REL" ]]; then [[ "$REL" == $g ]] && { set +f; return 0; }
    else [[ "$FILE" == $g || "$FILE" == */$g ]] && { set +f; return 0; }; fi
  done
  set +f
  return 1
}
IS_SOURCE=1   # SOURCE_GLOBS (blank ⇒ every file): docs that mention a suppression are not one
in_globs || IS_SOURCE=0
[[ "$REL" == .ai/* || "$REL" == .claude/* ]] && IS_SOURCE=0  # the harness is not the project's code
if [[ -n "$TEXT_DIR" && -f "$TEXT_DIR/new" && "$IS_SOURCE" -eq 1 ]]; then
  # A Write replaces the whole file, so the old text is the committed copy, if any, read from
  # the file's own repo (an epic worktree has its own HEAD).
  TRACKED=""
  if [[ -n "$FILE_TOP" && -n "$REL" ]]; then
    TRACKED="$(cd "$FILE_TOP" && git ls-files --full-name -- "$REL" 2>/dev/null || true)"
  fi
  if [[ ! -s "$TEXT_DIR/old" && -n "$TRACKED" ]]; then
    (cd "$FILE_TOP" && git show "HEAD:$TRACKED") > "$TEXT_DIR/old" 2>/dev/null || : > "$TEXT_DIR/old"
  fi
  NEW_HITS="$(grep -aE -- "$SUPPRESSION_PATTERNS" "$TEXT_DIR/new" 2>/dev/null || true)"
  if [[ -n "$NEW_HITS" ]]; then
    NEW_COUNT="$(printf '%s\n' "$NEW_HITS" | wc -l | tr -d ' ')"
    OLD_COUNT="$(grep -acE -- "$SUPPRESSION_PATTERNS" "$TEXT_DIR/old" 2>/dev/null || true)"
    if [[ "$NEW_COUNT" -gt "${OLD_COUNT:-0}" ]]; then
      note "WARNING: $FILE gains a suppression or skipped test:"$'\n'"$(printf '%s\n' "$NEW_HITS" | head -5)"$'\n'"Fix the cause instead. If it must stay, state why in the test report; the reviewer treats an unexplained one as a BLOCKER."
    fi
  fi
fi

exit 0
