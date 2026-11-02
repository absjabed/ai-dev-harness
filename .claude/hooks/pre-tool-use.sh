#!/usr/bin/env bash
# PreToolUse hook — safety warnings/blocks before Claude edits a file.
# Claude Code delivers the hook payload as JSON on stdin (NOT positional args).
# Registered in .claude/settings.json for matcher "Edit|Write|MultiEdit".
# Config-driven: reads .claude/hooks/hooks.env. Blank values ⇒ that guard is skipped.
#
# Behavior: non-blocking except the migrations guard and SUPPRESSION_CHECK="block". Warnings go
# to stderr and, as hookSpecificOutput.additionalContext JSON on stdout, to Claude (Claude never
# sees the stderr of a hook that exits 0). exit 2 = hard block; Claude sees its stderr as the reason.

set -euo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
[[ -f "$HOOK_DIR/hooks.env" ]] && source "$HOOK_DIR/hooks.env"

MIGRATIONS_GLOB="${MIGRATIONS_GLOB:-}"
MIGRATIONS_REGEN_CMD="${MIGRATIONS_REGEN_CMD:-}"
SENSITIVE_CONFIG_GLOBS="${SENSITIVE_CONFIG_GLOBS:-}"
SUPPRESSION_CHECK="${SUPPRESSION_CHECK:-off}"
SUPPRESSION_PATTERNS="${SUPPRESSION_PATTERNS:-}"

payload="$(cat)"

# The edit's new and old text, for the suppression check (written only in block mode).
TEXT_DIR=""
if [[ "$SUPPRESSION_CHECK" == "block" && -n "$SUPPRESSION_PATTERNS" ]]; then
  TEXT_DIR="$(mktemp -d 2>/dev/null || echo '')"
  trap '[[ -n "$TEXT_DIR" ]] && rm -rf "$TEXT_DIR"' EXIT
fi

read -r TOOL FILE <<EOF
$(printf '%s' "$payload" | node -e '
let raw = "";
process.stdin.on("data", c => raw += c).on("end", () => {
  try {
    const j = JSON.parse(raw);
    const ti = j.tool_input || {};
    const file = ti.file_path || ti.path || ti.notebook_path || "";
    const dir = process.argv[1];
    if (dir) {
      const pick = k => [ti[k], ...(ti.edits || []).map(e => e[k])].filter(s => typeof s === "string").join("\n");
      require("fs").writeFileSync(dir + "/new", pick("new_string") + "\n" + (ti.content || ""));
      require("fs").writeFileSync(dir + "/old", pick("old_string"));
    }
    process.stdout.write(`${j.tool_name || ""} ${file}`);
  } catch (_) {
    process.stdout.write(" ");
  }
});
' "$TEXT_DIR" 2>/dev/null || echo " ")
EOF
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
REL=""; FILE_TOP=""
if [[ -n "$NEAR" ]]; then
  FILE_TOP="$(cd "${NEAR%%$'\t'*}" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null || true)"
  if [[ -n "$FILE_TOP" ]]; then
    REL="$(cd "${NEAR%%$'\t'*}" 2>/dev/null && git rev-parse --show-prefix 2>/dev/null || true)${NEAR#*$'\t'}"
  fi
fi

# note <text>: record a warning for both the user (stderr) and Claude (JSON at exit).
CONTEXT=""
note() { printf '%s\n' "$1" >&2; CONTEXT+="$1"$'\n'; }
emit_context() {
  [[ -z "$CONTEXT" ]] && return 0
  printf '%s' "$CONTEXT" | node -e '
let r = "";
process.stdin.on("data", c => r += c).on("end", () => process.stdout.write(JSON.stringify(
  { hookSpecificOutput: { hookEventName: "PreToolUse", additionalContext: r.trim() } })));
' 2>/dev/null || true
}

# in_source_globs: is $FILE source code (SOURCE_GLOBS; blank ⇒ every file)? Docs that merely
# mention a suppression are not suppressions.
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
in_source_globs() { in_globs; }

# Warn when editing a real .env file (but allow .env.example). (Always on — universal.)
if [[ "$FILE" == */.claude/hooks/hooks.env || "$FILE" == .claude/hooks/hooks.env ]]; then
  note "NOTE: $TOOL is editing the harness config ($FILE), which sets the quality gate's limits. Tightening a value is free; loosening one (a lower COVERAGE_MIN, a blank gate command, SUPPRESSION_CHECK=off) needs the user's own words and a .ai/memory/decisions.md entry. The gate lists every value the change alters, and keeps the base commit's stricter value until the change is merged."
elif [[ "$FILE" == *.env && "$FILE" != *.env.example ]]; then
  note "WARNING: $TOOL is about to modify an .env file ($FILE). Confirm this is intentional and contains no committed secrets."
fi

# Warn when editing production configuration. (Always on — universal.)
if [[ "$FILE" == *production* || "$FILE" == *prod.* || "$FILE" == *.prod.* ]]; then
  note "WARNING: $TOOL is editing a production configuration file ($FILE)."
fi

# Block direct edits to generated migration files (config-driven).
if [[ -n "$MIGRATIONS_GLOB" && "$FILE" == $MIGRATIONS_GLOB ]]; then
  echo "BLOCKED: Generated migration files must not be edited directly." >&2
  [[ -n "$MIGRATIONS_REGEN_CMD" ]] && echo "Run '$MIGRATIONS_REGEN_CMD' to regenerate migrations instead." >&2
  exit 2
fi

# Warn when editing configured sensitive config files (config-driven, space-separated globs).
if [[ -n "$SENSITIVE_CONFIG_GLOBS" ]]; then
  for glob in $SENSITIVE_CONFIG_GLOBS; do
    if [[ "$FILE" == $glob ]]; then
      note "WARNING: Editing sensitive config ($FILE). Verify permissions, names, and environment values are correct."
      break
    fi
  done
fi

# Block an edit that adds a lint/type/coverage suppression or a skipped/focused test
# (SUPPRESSION_CHECK="block"; warn mode lives in post-tool-use.sh). A human can still add one.
if [[ -n "$TEXT_DIR" && -f "$TEXT_DIR/new" ]] && in_source_globs; then
  # A Write replaces the whole file, so the old text is what is on disk now.
  if [[ ! -s "$TEXT_DIR/old" && -f "$FILE" ]]; then cat -- "$FILE" > "$TEXT_DIR/old" 2>/dev/null || true; fi
  NEW_HITS="$(grep -E -- "$SUPPRESSION_PATTERNS" "$TEXT_DIR/new" 2>/dev/null || true)"
  NEW_COUNT=0
  [[ -n "$NEW_HITS" ]] && NEW_COUNT="$(printf '%s\n' "$NEW_HITS" | wc -l | tr -d ' ')"
  OLD_COUNT="$(grep -cE -- "$SUPPRESSION_PATTERNS" "$TEXT_DIR/old" 2>/dev/null || true)"
  if [[ "$NEW_COUNT" -gt "${OLD_COUNT:-0}" ]]; then
    echo "BLOCKED: this edit adds a suppression or skipped test to $FILE:" >&2
    printf '%s\n' "$NEW_HITS" | head -5 >&2
    echo "Fix the cause (refactor, add the missing test) instead. If it is truly needed, ask the user to add it themselves." >&2
    exit 2
  fi
fi

emit_context
exit 0
