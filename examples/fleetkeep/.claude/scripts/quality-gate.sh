#!/usr/bin/env bash
# Quality gate: one deterministic pass/fail for the current change, with the numbers.
#
#   .claude/scripts/quality-gate.sh [--base <ref>] [--mutation]
#   .claude/scripts/quality-gate.sh --baseline
#
#   --base <ref>   what the change is measured against: the branch the work started from
#                  (default HEAD = uncommitted changes only). Committed and uncommitted work
#                  since the merge-base both count, untracked files included.
#   --mutation     also run MUTATION_CMD (slow). It runs only when every other check passed,
#                  and its result is recorded for this exact change: a later run without
#                  --mutation on unchanged code reports it instead of running it again.
#   --baseline     measure the whole codebase instead of a change: run GATE_TEST_CMD, then write
#                  coverage, complexity and CRAP for every tracked source file (the harness's own
#                  .ai/ and .claude/ left out) to .ai/reports/quality-baseline.md. A snapshot for
#                  choosing the limits and seeing the trend: it judges nothing, and no other run
#                  reads it. It exits non-zero only when it could not write the file.
#
# The first line names a change id (a hash of the changed source and test files): two runs with
# the same id measured the same code.
#
# Checks, each skipped while its hooks.env value is blank:
#   build        GATE_BUILD_CMD, from the repo root
#   typecheck    TYPECHECK_CMD, inside each PACKAGE_DIRS dir the change touched
#   lint         LINT_CMD on the changed source files, inside their package dir
#   test         GATE_TEST_CMD, from the repo root; it should also write COVERAGE_REPORTS
#   metrics      diff coverage (COVERAGE_MIN), complexity (COMPLEXITY_MAX) and CRAP (CRAP_MAX)
#                on the functions the change touched, via quality-metrics.py
#   suppressions lint/coverage suppressions and skipped tests the change adds (SUPPRESSION_CHECK)
#   test-removal test cases and assertions it removes or changes (SUPPRESSION_CHECK)
#   gate-config  the hooks.env values and gate files it changes, since loosening them needs a person
#                (always on; a WARN, or a FAIL when a check could not run or a command changed the tree)
#   mutation     MUTATION_CMD with {files}, {base} and {each:…} filled in, over the changed files
#                that match MUTATION_GLOBS (only with --mutation)
#
# Prints one line per check, the tail of each failure, and a final verdict. "PASS (partial ...)"
# means the build or the tests are not configured, so the gate did not run them: verify those
# by hand. Full
# logs go under .git/quality-gate/, so nothing new needs gitignoring.
# Exit 0 = PASS, PASS (partial), NOT CONFIGURED or a written baseline; 1 = FAIL or no baseline
# written; 2 = usage error.

set -o pipefail   # no -u: macOS ships bash 3.2, where empty arrays trip it
shopt -u patsub_replacement 2>/dev/null  # bash 5.2+: keep a & in a file name literal in ${var//x/y}

# Every git call gets plain output: a user's diff.noprefix, diff.mnemonicPrefix, colour or
# quoted non-ASCII paths would otherwise hide changed files and lines from the parsers below.
# diff.interHunkContext would merge hunks and count the unchanged lines between them as changed.
# The diff calls also pass --no-ext-diff --no-textconv for the same reason, and --text so a -diff
# or binary attribute cannot turn a source file's hunks into "Binary files differ".
ATTR_OPT=()  # --attr-source=<base> once the base is known
git() { command git "${ATTR_OPT[@]}" -c core.quotePath=false -c color.ui=false -c color.diff=false -c diff.noprefix=false -c diff.mnemonicPrefix=false -c diff.srcPrefix=a/ -c diff.dstPrefix=b/ -c diff.interHunkContext=0 "$@"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# The values the gate reads from hooks.env. The file is parsed, never run, so nothing in it (a
# function named like a command, a PATH change, a checkout) can reach the gate. A plain KEY=value
# line per key counts: '...' and "..." without $ or a backtick, joined segments, \x escapes, a
# bare word, a trailing # comment. A key on any other kind of line is left unset (the base's
# value applies where one is kept) and listed under gate-config.
CFG_KEYS="GATE_BUILD_CMD GATE_TEST_CMD TYPECHECK_CMD LINT_CMD PACKAGE_DIRS SOURCE_GLOBS TEST_FILE_PATTERNS COVERAGE_REPORTS COVERAGE_MIN COVERAGE_EXEMPT_GLOBS COMPLEXITY_MAX CRAP_MAX MUTATION_CMD MUTATION_GLOBS SUPPRESSION_CHECK SUPPRESSION_PATTERNS TEST_ASSERTION_PATTERNS"
CFG_BAD=""
cfg_value() {  # cfg_value <text after KEY=>: prints the value, or fails if bash would expand it
  local s="$1" out="" seg
  local re_sq="^'([^']*)'(.*)\$" re_dq='^"(([^"\\$`]|\\.)*)"(.*)$' re_esc='^\\(.)(.*)$'
  local re_end='^[[:space:]]+(#.*)?$' re_bare='^([-A-Za-z0-9_./:,=@%+*?!^]+)(.*)$' re_bs='^([^\\]*)\\(.)(.*)$'
  while [[ -n "$s" ]]; do
    if [[ "$s" =~ $re_sq ]]; then out+="${BASH_REMATCH[1]}"; s="${BASH_REMATCH[2]}"
    elif [[ "$s" =~ $re_dq ]]; then
      seg="${BASH_REMATCH[1]}"; s="${BASH_REMATCH[3]}"
      while [[ "$seg" =~ $re_bs ]]; do  # \" \\ \$ \` lose the backslash, as in bash
        case "${BASH_REMATCH[2]}" in '"'|'\'|'$'|'`') out+="${BASH_REMATCH[1]}${BASH_REMATCH[2]}" ;;
          *) out+="${BASH_REMATCH[1]}\\${BASH_REMATCH[2]}" ;; esac
        seg="${BASH_REMATCH[3]}"
      done
      out+="$seg"
    elif [[ "$s" =~ $re_esc ]]; then out+="${BASH_REMATCH[1]}"; s="${BASH_REMATCH[2]}"
    elif [[ "$s" =~ $re_end ]]; then break
    elif [[ "$s" =~ $re_bare ]]; then out+="${BASH_REMATCH[1]}"; s="${BASH_REMATCH[2]}"
    else return 1; fi
  done
  printf '%s' "$out"
}
read_cfg() {  # read_cfg <file>: sets each CFG_KEYS key it assigns on a plain line
  local line k v re_any re_cmt='^[[:space:]]*(#|$)' re_head='^[[:space:]]*((export|readonly|declare|typeset)([[:space:]]+-[A-Za-z]+)*[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*)=(.*)$'
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    if [[ "$line" =~ $re_head ]]; then
      k="${BASH_REMATCH[4]}"; v="${BASH_REMATCH[5]}"
      if v="$(cfg_value "$v")"; then  # a plain line: its key (when it is one of ours) is read
        case " $CFG_KEYS " in *" $k "*) printf -v "$k" '%s' "$v" ;; esac
        continue
      fi
    fi
    # a key set anywhere else on a line (after ; && then, a second NAME=, +=) is not read either
    [[ "$line" =~ $re_cmt ]] && continue
    for k in $CFG_KEYS; do
      re_any="(^|[^A-Za-z0-9_])$k[+]?="
      if [[ "$line" =~ $re_any ]]; then unset "$k"; case " $CFG_BAD " in *" $k "*) ;; *) CFG_BAD="$CFG_BAD $k" ;; esac; fi
    done
  done < "$1"
}
for k in $CFG_KEYS; do unset "$k"; done
[[ -f "$SCRIPT_DIR/../hooks/hooks.env" ]] && read_cfg "$SCRIPT_DIR/../hooks/hooks.env"
# git reads these from the environment; each changes what the diffs below show.
unset GREP_OPTIONS GIT_INDEX_FILE GIT_DIFF_OPTS GIT_EXTERNAL_DIFF GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT GIT_ATTR_SOURCE \
      GIT_GLOB_PATHSPECS GIT_NOGLOB_PATHSPECS GIT_ICASE_PATHSPECS GIT_LITERAL_PATHSPECS
# a replace ref (git replace <base> <commit>) would swap the base's content for any tree
export GIT_NO_REPLACE_OBJECTS=1

BASE="HEAD"
MUTATION=0
BASELINE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --base) [[ $# -ge 2 && -n "$2" ]] || { echo "quality-gate: --base needs a ref" >&2; exit 2; }; BASE="$2"; shift 2 ;;
    --mutation) MUTATION=1; shift ;;
    --baseline) BASELINE=1; shift ;;
    -h|--help) sed -n '2,40p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "quality-gate: unknown argument '$1' (see --help)" >&2; exit 2 ;;
  esac
done

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "quality-gate: not inside a git repository" >&2; exit 2; }
cd "$REPO_ROOT" || exit 2
LOG_DIR="$(git rev-parse --absolute-git-dir)/quality-gate"
if [[ $BASELINE -eq 1 ]]; then
  LOG_DIR="$LOG_DIR/baseline"  # its own logs, so a baseline never wipes the last gate run's
else
  MERGE_BASE="$(git merge-base "$BASE" HEAD 2>/dev/null)" || { echo "quality-gate: cannot find a merge-base with '$BASE' (a repo with one commit has no HEAD~1)" >&2; exit 2; }
  # the change's .gitattributes could filter or re-encode a file before git diffs it
  # (filter=lfs, working-tree-encoding): read attributes from the base commit (git 2.40+).
  if command git --attr-source="$MERGE_BASE" rev-parse HEAD >/dev/null 2>&1; then
    ATTR_OPT=(--attr-source="$MERGE_BASE"); export GATE_ATTR_SOURCE="$MERGE_BASE"
  fi
fi
mkdir -p "$LOG_DIR"
for f in "$LOG_DIR"/*.log; do
  [[ -e "$f" ]] || continue
  [[ "$f" == */mutation.log ]] && continue  # the recorded run's log; replaced only when mutation runs
  rm -f "$f"
done

FAILED=0
RAN=0
BUILD_OK=1
OTHERS_OK=1
NOT_SET=()

# run_step <name> <dir> <command> [note]: runs it, logs it, prints PASS/FAIL and a failure tail.
run_step() {
  local name="$1" dir="$2" cmd="$3" log="$LOG_DIR/$1.log" start=$SECONDS rc
  RAN=1
  (cd "$dir" && eval "$cmd") >>"$log" 2>&1
  rc=$?
  if [[ $rc -eq 0 ]]; then
    printf '%-12s PASS  (%ss)%s\n' "$name" "$((SECONDS - start))" "${4:+  $4}"
    return 0
  fi
  FAILED=1
  printf '%-12s FAIL  (%ss, exit %s)%s  log: %s\n' "$name" "$((SECONDS - start))" "$rc" "${4:+  $4}" "$log"
  tail -n 30 "$log" | sed 's/^/    /'
  return 1
}
skip() { printf '%-12s SKIP  %s\n' "$1" "$2"; }
not_set() { skip "$1" "$2 not set"; NOT_SET+=("$1"); }  # build and test only: a PASS without them is partial

# expand_each <cmd>: replaces one {each:TEMPLATE} with TEMPLATE once per file in MUT_SOURCES,
# each word shell-quoted; {file} = the file's path, {name} = its file name. For tools that take
# one flag per file, e.g. Stryker.NET's "-m".
expand_each() {
  local cmd="$1" rest tpl out="" depth=1 i c f w words
  if [[ "$cmd" != *"{each:"* ]]; then printf '%s' "$cmd"; return; fi
  rest="${cmd#*\{each:}"
  for ((i = 0; i < ${#rest}; i++)); do
    c="${rest:i:1}"
    if [[ "$c" == "{" ]]; then depth=$((depth + 1)); fi
    if [[ "$c" == "}" ]]; then depth=$((depth - 1)); [[ $depth -eq 0 ]] && break; fi
  done
  tpl="${rest:0:i}"
  read -r -a words <<< "$tpl"
  for f in "${MUT_SOURCES[@]}"; do
    for w in "${words[@]}"; do
      w="${w//\{file\}/$f}"; w="${w//\{name\}/${f##*/}}"
      out+="$(printf '%q' "$w") "
    done
  done
  printf '%s%s%s' "${cmd%%\{each:*}" "${out% }" "${rest:i+1}"
}

# find_python: sets PY to a working python 3, or leaves it empty.
find_python() {
  PY=""
  local p
  for p in python3 python; do
    if command -v "$p" >/dev/null 2>&1 && "$p" -c 'import sys' >/dev/null 2>&1; then PY="$p"; return; fi
  done
}

# ── --baseline: the whole codebase, written to a file, never a verdict ───────
if [[ $BASELINE -eq 1 ]]; then
  OUT=".ai/reports/quality-baseline.md"
  FILES=()
  set -f
  while IFS= read -r f; do
    [[ "$f" == .ai/* || "$f" == .claude/* ]] && continue  # the harness is not the project's code
    keep=1
    if [[ -n "${SOURCE_GLOBS:-}" ]]; then keep=0; for g in $SOURCE_GLOBS; do [[ "$f" == $g ]] && keep=1 && break; done; fi
    for g in ${TEST_FILE_PATTERNS:-}; do [[ "$f" == $g ]] && keep=0 && break; done
    [[ $keep -eq 1 && -f "$f" ]] && FILES+=("$f")
  done < <(git ls-files)
  set +f
  echo "Quality baseline: ${#FILES[@]} tracked source file(s)"
  find_python
  [[ -z "$PY" ]] && { echo "QUALITY BASELINE: NOT WRITTEN (python 3 not found; the baseline needs it)" >&2; exit 1; }
  args=(--baseline-out "$OUT")
  TEST_START="$LOG_DIR/.test-start"
  if [[ -z "${GATE_TEST_CMD:-}" ]]; then
    skip test "GATE_TEST_CMD not set: no coverage in the baseline"
    args+=(--tests "not run (GATE_TEST_CMD not set)")
  else
    : > "$TEST_START"
    sleep 1  # reports must be measurably newer than this marker on coarse-mtime filesystems
    if run_step test . "$GATE_TEST_CMD"; then args+=(--tests "PASS"); else args+=(--tests "FAIL (coverage may be incomplete)"); fi
    args+=(--fresh-after "$TEST_START")
  fi
  set -f
  for g in ${COVERAGE_REPORTS:-}; do args+=(--report-glob "$g"); done
  for g in ${COVERAGE_EXEMPT_GLOBS:-}; do args+=(--exempt "$g"); done
  set +f
  [[ -n "${COMPLEXITY_MAX:-}" ]] && args+=(--complexity-max "$COMPLEXITY_MAX")
  [[ -n "${CRAP_MAX:-}" ]] && args+=(--crap-max "$CRAP_MAX")
  # The file list goes through a file: thousands of paths overflow a Windows command line.
  printf '%s\n' "${FILES[@]}" > "$LOG_DIR/files.txt"
  "$PY" "$SCRIPT_DIR/quality-metrics.py" "${args[@]}" --files-from "$LOG_DIR/files.txt" 2>&1 | tee "$LOG_DIR/baseline.log"
  if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
    echo "QUALITY BASELINE: NOT WRITTEN (quality-metrics.py failed; see $LOG_DIR/baseline.log)" >&2
    exit 1
  fi
  exit 0
fi

# ── The base commit's settings ───────────────────────────────────────────────
# A change can tighten these values for itself but not loosen them: the gate reads the base
# commit's hooks.env too and keeps the stricter of the two. A loosening takes effect once the
# change is merged. Other values (the commands, PACKAGE_DIRS, MUTATION_GLOBS) are the working
# tree's, and the gate-config check lists every change to them, and to the gate's own files.
#   SUPPRESSION_CHECK                         the stricter mode
#   SUPPRESSION_PATTERNS, TEST_ASSERTION_PATTERNS  both patterns
#   SOURCE_GLOBS                              both lists (blank at the base = every file, kept)
#   TEST_FILE_PATTERNS, COVERAGE_EXEMPT_GLOBS the base's
#   (the file lists only once the base's gate is configured: setup reads the template as it is)
#   COVERAGE_MIN (higher), COMPLEXITY_MAX and CRAP_MAX (lower)
#   GATE_BUILD_CMD, GATE_TEST_CMD, TYPECHECK_CMD, LINT_CMD, MUTATION_CMD  the base's, if the change blanks one
#                                             (a changed command is used, and listed)
# Only keys the base's hooks.env sets count, so a new hooks.env (setup) is read as it is.
BASE_CFG="$(git show "$MERGE_BASE:.claude/hooks/hooks.env" 2>/dev/null | tr -d '\r')"
# base_has <KEY>: the base's hooks.env assigns KEY. base_value <KEY>: its value there.
# "set" after running the base's file, whatever the form (export, readonly, declare).
base_has() { ( for k in $CFG_KEYS; do unset "$k"; done; eval "$BASE_CFG" >/dev/null 2>&1; [[ -n "${!1+x}" ]] ); }
base_value() { ( for k in $CFG_KEYS; do unset "$k"; done; eval "$BASE_CFG" >/dev/null 2>&1; printf '%s' "${!1:-}" ); }
mode_rank() { case "$1" in block) echo 2 ;; warn) echo 1 ;; *) echo 0 ;; esac; }
# num_pick <higher|lower> <a> <b>: the stricter number; a blank one loses.
num_pick() {
  if [[ -z "$2" ]]; then printf '%s' "$3"; elif [[ -z "$3" ]]; then printf '%s' "$2"
  else awk -v w="$1" -v a="$2" -v b="$3" 'BEGIN { if ((w == "higher") == (a + 0 >= b + 0)) print a; else print b }'; fi
}
KEPT_KEYS="SUPPRESSION_CHECK SOURCE_GLOBS TEST_FILE_PATTERNS COVERAGE_EXEMPT_GLOBS COVERAGE_MIN COMPLEXITY_MAX CRAP_MAX GATE_BUILD_CMD GATE_TEST_CMD TYPECHECK_CMD LINT_CMD MUTATION_CMD"
for k in $KEPT_KEYS SUPPRESSION_PATTERNS TEST_ASSERTION_PATTERNS; do printf -v "WORK_$k" '%s' "${!k:-}"; done
if [[ -n "$BASE_CFG" ]]; then
  if base_has SUPPRESSION_CHECK; then
    b="$(base_value SUPPRESSION_CHECK)"
    [[ $(mode_rank "$b") -gt $(mode_rank "${SUPPRESSION_CHECK:-off}") ]] && SUPPRESSION_CHECK="$b"
  fi
  for k in SUPPRESSION_PATTERNS TEST_ASSERTION_PATTERNS; do
    base_has "$k" || continue
    b="$(base_value "$k")"
    w="${!k:-}"
    # kept as a second pattern, never spliced into one regex with the change's
    [[ -n "$b" && "$b" != "$w" ]] && printf -v "BASEPAT_$k" '%s' "$b"
  done
  # The file lists count once the base's gate judged anything; before that (setup, or an upgrade
  # from a harness without the gate) the base holds only the template's defaults.
  base_on=0
  for k in GATE_BUILD_CMD GATE_TEST_CMD COVERAGE_REPORTS COVERAGE_MIN COMPLEXITY_MAX CRAP_MAX MUTATION_CMD; do
    [[ -n "$(base_value "$k")" ]] && { base_on=1; break; }
  done
  [[ $(mode_rank "$(base_value SUPPRESSION_CHECK)") -gt 0 ]] && base_on=1
  # SOURCE_GLOBS also scopes typecheck and lint. Only a harness with the gate has the key, so an
  # upgrade from one without it still reads the change's lists.
  lint_on=$base_on
  [[ -n "$(base_value TYPECHECK_CMD)$(base_value LINT_CMD)" ]] && lint_on=1
  if [[ $lint_on -eq 1 ]] && base_has SOURCE_GLOBS; then  # may only grow: a narrower list judges less
    b="$(base_value SOURCE_GLOBS)"
    if [[ -z "$b" ]]; then SOURCE_GLOBS=""
    elif [[ -n "${SOURCE_GLOBS:-}" ]]; then  # add each base glob the change dropped
      set -f; for g in $b; do [[ " $SOURCE_GLOBS " == *" $g "* ]] || SOURCE_GLOBS="$SOURCE_GLOBS $g"; done; set +f
    fi
  fi
  if [[ $base_on -eq 1 ]]; then
    base_has TEST_FILE_PATTERNS && TEST_FILE_PATTERNS="$(base_value TEST_FILE_PATTERNS)"
    base_has COVERAGE_EXEMPT_GLOBS && COVERAGE_EXEMPT_GLOBS="$(base_value COVERAGE_EXEMPT_GLOBS)"
  fi
  if base_has COVERAGE_MIN; then COVERAGE_MIN="$(num_pick higher "${COVERAGE_MIN:-}" "$(base_value COVERAGE_MIN)")"; fi
  for k in COMPLEXITY_MAX CRAP_MAX; do
    if base_has "$k"; then printf -v "$k" '%s' "$(num_pick lower "${!k:-}" "$(base_value "$k")")"; fi
  done
  for k in GATE_BUILD_CMD GATE_TEST_CMD TYPECHECK_CMD LINT_CMD MUTATION_CMD; do
    if [[ -z "${!k:-}" ]] && base_has "$k"; then printf -v "$k" '%s' "$(base_value "$k")"; fi
  done
fi

# a value on a line the gate cannot read, with no base value standing in: its check
# would silently not run (or SKIP as "not set"), so it FAILs until the line is made plain.
UNREAD=""
for k in $CFG_BAD; do bp="BASEPAT_$k"; [[ -z "${!k:-}${!bp:-}" ]] && UNREAD="$UNREAD $k"; done

# A pattern grep cannot compile matches nothing, so every line would pass. Each value (the
# change's, and the base's when it differs) is checked on its own, in the exact form the check
# runs it, and run as its own grep, so one value cannot change what the other matches. A
# back-reference is refused (POSIX leaves it undefined in an ERE). Checked only when the check
# will run.
RULES='([[:alnum:]_:,=./@ -]|\[[^]]*\]|\(([^()"'\'']|"[^"]*"|'\''[^'\'']*'\''|\([^()]*\))*\)|\([^)]*\))*'
RE_BACKREF='(^|[^\\])(\\\\)*\\[1-9]'  # in a variable: bash 3.2 and 5 read an inline regex differently
compiles() { [[ "$1" =~ $RE_BACKREF ]] && return 1; printf 'x\n' | grep -E -- "$1" >/dev/null 2>&1; [[ $? -ne 2 ]]; }
PATTERN_NOTES=""; BAD_PATTERNS=""; SUPP_E=(); ASSERT_E=()
if [[ "${SUPPRESSION_CHECK:-off}" != "off" ]]; then
  for k in SUPPRESSION_PATTERNS TEST_ASSERTION_PATTERNS; do
    [[ $k == TEST_ASSERTION_PATTERNS && -z "${TEST_FILE_PATTERNS:-}" ]] && continue  # test-removal will not run
    bp="BASEPAT_$k"; n=0; any=0
    for v in "${!k:-}" "${!bp:-}"; do
      n=$((n + 1)); [[ -z "$v" ]] && continue; any=1
      if [[ $k == SUPPRESSION_PATTERNS ]]; then form="($v)$RULES"; else form="$v"; fi
      if compiles "$v" && compiles "$form"; then
        if [[ $k == SUPPRESSION_PATTERNS ]]; then SUPP_E+=(-e "$form"); else ASSERT_E+=(-e "$form"); fi
      else PATTERN_NOTES="$PATTERN_NOTES $k($([[ $n -eq 1 ]] && echo "the change's" || echo "the base's") value left out)"; fi
    done
    if [[ $any -eq 1 && $k == SUPPRESSION_PATTERNS && ${#SUPP_E[@]} -eq 0 ]] || [[ $any -eq 1 && $k == TEST_ASSERTION_PATTERNS && ${#ASSERT_E[@]} -eq 0 ]]; then
      BAD_PATTERNS="$BAD_PATTERNS $k"
    fi
  done
fi

# ── What changed ─────────────────────────────────────────────────────────────
CHANGED=()   # present now (added, modified, renamed, untracked)
DELETED=()
while IFS= read -r f; do CHANGED+=("$f"); done < <( { git diff --no-ext-diff --name-only --diff-filter=d -M "$MERGE_BASE" 2>/dev/null; git ls-files --others --exclude-standard; } | sort -u)
while IFS= read -r f; do DELETED+=("$f"); done < <(git diff --no-ext-diff --name-only --diff-filter=D -M "$MERGE_BASE" 2>/dev/null)
SOURCES=()
TESTS=()
set -f  # keep the configured globs literal while word-splitting them
for f in "${CHANGED[@]}"; do
  [[ "$f" == .ai/* || "$f" == .claude/* ]] && continue  # the harness is not the project's code
  is_source=1
  if [[ -n "${SOURCE_GLOBS:-}" ]]; then
    is_source=0
    for g in $SOURCE_GLOBS; do [[ "$f" == $g ]] && is_source=1 && break; done
  fi
  [[ $is_source -eq 0 ]] && continue
  is_test=0
  for g in ${TEST_FILE_PATTERNS:-}; do [[ "$f" == $g ]] && is_test=1 && break; done
  if [[ $is_test -eq 1 ]]; then TESTS+=("$f"); else SOURCES+=("$f"); fi
done
set +f

# The change's fingerprint: identical source and tests ⇒ identical value. Ties a mutation result
# to it, and is printed as the change id. Only SOURCES and TESTS count, so a report a tool
# writes into the tree does not move it.
# Content only (the base plus each file's path and blob hash), so committing the work, or a
# file going from untracked to tracked, does not change it.
FINGERPRINT="none"
if [[ ${#SOURCES[@]} -gt 0 || ${#TESTS[@]} -gt 0 ]]; then
  FINGERPRINT="$( { echo "$MERGE_BASE"
                    for f in "${SOURCES[@]}" "${TESTS[@]}"; do printf '%s ' "$f"; git hash-object -- "$f"; done
                    for f in "${DELETED[@]}"; do printf 'deleted %s\n' "$f"; done; } | git hash-object --stdin)"
fi

echo "Quality gate: ${#CHANGED[@]} changed and ${#DELETED[@]} deleted file(s) vs $BASE (${MERGE_BASE:0:10}); ${#SOURCES[@]} source, ${#TESTS[@]} test; change id ${FINGERPRINT:0:12}"
if [[ ${#CHANGED[@]} -eq 0 && ${#DELETED[@]} -eq 0 ]]; then
  echo "QUALITY GATE: PASS (nothing changed)"
  exit 0
fi

# ── gate config ──────────────────────────────────────────────────────────────
# The gate runs from the working tree, so a change can alter the gate that judges it: its
# hooks.env, its scripts, its hooks. Some loosenings are undone above (the base's stricter
# values); the rest only a person can judge. List every such change for the person approving
# it. Always on, and printed before any command runs. A changed value is only a WARN: tightening
# is free, and a FAIL could never clear on the branch that makes the change. What would leave a
# check blind (no pattern that compiles, .gitattributes on a git that cannot read the base's)
# FAILs.
CFG=".claude/hooks/hooks.env"
if [[ -f "$CFG" ]] && ! git cat-file -e "$MERGE_BASE:$CFG" 2>/dev/null \
   && [[ -n "$(git ls-files --cached --others --exclude-standard -- "$CFG")" ]]; then
  printf '%-12s WARN  %s is not in the base commit: every value in it is new (expected only at setup)\n' gate-config "$CFG"
else
  # Every changed line that is not a comment: assignments, exports, anything bash would run.
  cfg_lines="$(git diff --no-ext-diff --no-textconv --text -U0 "$MERGE_BASE" -- "$CFG" 2>/dev/null \
    | grep -E '^[+-]' | grep -vE '^(\+\+\+|---)' | grep -vE '^[+-][[:space:]]*(#|$)')"
  # Every NAME= on the line, not just the first (a second assignment would hide behind it).
  cfg_keys="$(printf '%s\n' "$cfg_lines" | grep -oE '(^[+-]|[;&|[:space:]])[[:space:]]*(export[[:space:]]+)?[A-Za-z_][A-Za-z0-9_]*=' \
    | sed -E 's/^[-+;&|[:space:]]*(export[[:space:]]+)?//; s/=$//' | sort -u | tr '\n' ' ')"
  cfg_keys="${cfg_keys% }"
  cfg_other="$(printf '%s\n' "$cfg_lines" | grep -vcE '^[+-][[:space:]]*(export[[:space:]]+)?[A-Za-z_][A-Za-z0-9_]*=' || true)"
  if [[ -z "$cfg_lines" ]]; then
    printf '%-12s PASS  hooks.env unchanged\n' gate-config
  else
    printf '%-12s WARN  hooks.env changes %s%s: loosening a value needs the user'"'"'s own words and a decisions.md entry\n' \
      gate-config "${cfg_keys:-no values}" "$([[ "${cfg_other:-0}" -gt 0 ]] && printf ' and %s other line(s)' "$cfg_other")"
  fi
fi
kept=""
for k in $KEPT_KEYS; do w="WORK_$k"; [[ "${!w}" != "${!k:-}" ]] && kept="$kept $k"; done
[[ -n "$kept" ]] && printf '%-12s WARN  the base commit'"'"'s value was kept for%s: the change'"'"'s counts once merged (land such a hooks.env change on its own first)\n' gate-config "$kept"
[[ -n "$PATTERN_NOTES" ]] && printf '%-12s WARN  a pattern does not compile as an extended regex; used instead:%s\n' gate-config "$PATTERN_NOTES"
[[ -n "$BAD_PATTERNS" ]] && { FAILED=1; printf '%-12s FAIL  no value of%s compiles as an extended regex, so its check could not run\n' gate-config "$BAD_PATTERNS"; }
GATE_FILES=()  # an array, so a path with a space or a * stays one path
while IFS= read -r f; do GATE_FILES+=("$f"); done < <( { git diff --no-ext-diff --name-only "$MERGE_BASE" -- .claude/scripts .claude/hooks .claude/settings.json 2>/dev/null
                 git ls-files --others --exclude-standard -- .claude/scripts .claude/hooks .claude/settings.json; } | grep -vxF "$CFG" | sort -u)
[[ ${#GATE_FILES[@]} -gt 0 ]] && printf '%-12s WARN  the change edits the gate itself: %s (this run used the edited copy)\n' gate-config "${GATE_FILES[*]}"
# hooks.env lines the gate could not read as plain values
[[ -n "$CFG_BAD" ]] && printf '%-12s WARN  hooks.env sets%s on a line that is not a plain value (a $, a backtick, a ;); not read: the base'"'"'s value applies where one is kept\n' gate-config "$CFG_BAD"
[[ -n "$UNREAD" ]] && { FAILED=1; printf '%-12s FAIL  hooks.env sets%s only on such a line and no base value applies, so the gate has none: write it as a plain KEY='"'"'value'"'"' line\n' gate-config "$UNREAD"; }
# the change's own .gitattributes (any folder) can filter or re-encode what git diffs
# (--no-renames: a renamed-away .gitattributes is listed by its old name too)
attr_files="$( { git diff --no-ext-diff --no-renames --name-only "$MERGE_BASE" 2>/dev/null; git ls-files --others --exclude-standard; } | grep -E '(^|/)\.gitattributes$' | sort -u | tr '\n' ' ')"
attr_files="${attr_files% }"
if [[ -n "$attr_files" ]]; then
  if [[ ${#ATTR_OPT[@]} -gt 0 ]]; then
    printf '%-12s WARN  the change edits %s; this run read the base commit'"'"'s attributes\n' gate-config "$attr_files"
  elif [[ ${#SOURCES[@]} -eq 0 && ${#TESTS[@]} -eq 0 ]]; then  # nothing it could hide
    printf '%-12s WARN  the change edits %s (and no source or test file); this git (older than 2.40) read the change'"'"'s attributes\n' gate-config "$attr_files"
  else
    FAILED=1
    printf '%-12s FAIL  the change edits %s and this git (older than 2.40) cannot read the base'"'"'s attributes instead: land the .gitattributes change on its own first (alone it is a WARN)\n' gate-config "$attr_files"
  fi
fi

# What the commands below must not change: HEAD, the base's tree, the content of the changed
# source, test and gate files, the deleted ones staying deleted, the untracked ones staying
# listed, and what git reads beside the tree (its config, info/attributes; .gitattributes on a git
# that reads the working tree's). A command that checks out the base, stashes the work, restores a
# deleted test or hides a file would otherwise leave every later check looking at another tree.
GONE=()  # base files the change deleted or renamed away, in source scope
set -f
while IFS= read -r f; do
  [[ "$f" == .ai/* || "$f" == .claude/* ]] && continue
  keep=1
  if [[ -n "${SOURCE_GLOBS:-}" ]]; then keep=0; for g in $SOURCE_GLOBS; do [[ "$f" == $g ]] && keep=1 && break; done; fi
  [[ $keep -eq 1 ]] && GONE+=("$f")
done < <(git diff --no-ext-diff --no-renames --name-only --diff-filter=D "$MERGE_BASE" 2>/dev/null)
set +f
printf '%s\n' "${SOURCES[@]}" "${TESTS[@]}" | grep -v '^$' > "$LOG_DIR/scope.txt"
state_lines() {  # one "name value" line per item
  printf 'HEAD %s\nbase-tree %s\n' "$(git rev-parse HEAD 2>/dev/null)" "$(git rev-parse "$MERGE_BASE^{tree}" 2>/dev/null)"
  for f in "${SOURCES[@]}" "${TESTS[@]}" "${GATE_FILES[@]}" .claude/hooks/hooks.env "${GONE[@]}"; do
    printf '%s %s\n' "$f" "$(git hash-object -- "$f" 2>/dev/null || echo gone)"
  done
  [[ -s "$LOG_DIR/scope.txt" ]] && git ls-files --others --exclude-standard | grep -xF -f "$LOG_DIR/scope.txt" | sed 's/$/ untracked/'
  printf 'git-config %s\n' "$(git config --list 2>/dev/null | git hash-object --stdin)"
  printf '%s %s\n' "$(git rev-parse --git-path info/attributes)" "$( (cat "$(git rev-parse --git-path info/attributes)" 2>/dev/null || true) | git hash-object --stdin)"
  if [[ ${#ATTR_OPT[@]} -eq 0 ]]; then
    { git ls-files; git ls-files --others --exclude-standard; } | grep -E '(^|/)\.gitattributes$' | sort -u | while IFS= read -r f; do
      printf '%s %s\n' "$f" "$(git hash-object -- "$f" 2>/dev/null || echo gone)"; done
  fi
}
STATE0="$(state_lines)"

# ── build ────────────────────────────────────────────────────────────────────
if [[ -n "${GATE_BUILD_CMD:-}" ]]; then
  run_step build . "$GATE_BUILD_CMD" || { BUILD_OK=0; OTHERS_OK=0; }
else
  not_set build GATE_BUILD_CMD
fi

# ── typecheck + lint, per package dir the change touched ─────────────────────
if [[ -n "${TYPECHECK_CMD:-}" || -n "${LINT_CMD:-}" ]]; then
  OUTSIDE=0
  if [[ -n "${PACKAGE_DIRS:-}" ]]; then
    for f in "${SOURCES[@]}" "${TESTS[@]}"; do
      inside=0
      for d in $PACKAGE_DIRS; do [[ "$d" == "." || "$f" == "$d"/* ]] && inside=1 && break; done
      [[ $inside -eq 0 ]] && OUTSIDE=$((OUTSIDE + 1))
    done
  fi
  for d in ${PACKAGE_DIRS:-.}; do
    lint_files=()
    touched=0
    for f in "${SOURCES[@]}" "${TESTS[@]}"; do
      if [[ "$d" == "." ]]; then lint_files+=("$f"); elif [[ "$f" == "$d"/* ]]; then lint_files+=("${f#"$d"/}"); fi
    done
    [[ ${#lint_files[@]} -gt 0 ]] && touched=1
    for f in "${DELETED[@]}"; do [[ "$d" == "." || "$f" == "$d"/* ]] && touched=1; done  # a deletion can break the build
    [[ $touched -eq 0 ]] && continue
    [[ -d "$d" ]] || { skip typecheck "$d no longer exists (the build covers what used it)"; continue; }
    if [[ -n "${TYPECHECK_CMD:-}" ]]; then
      run_step typecheck "$d" "$TYPECHECK_CMD" "$d" || OTHERS_OK=0
    else
      skip typecheck "TYPECHECK_CMD not set"
    fi
    if [[ -z "${LINT_CMD:-}" ]]; then
      skip lint "LINT_CMD not set"
    elif [[ ${#lint_files[@]} -gt 0 ]]; then
      quoted="$(printf '%q ' "${lint_files[@]}")"
      run_step lint "$d" "$LINT_CMD $quoted" "$d, ${#lint_files[@]} file(s)" || OTHERS_OK=0
    fi
  done
  [[ $OUTSIDE -gt 0 ]] && skip lint "$OUTSIDE changed file(s) outside PACKAGE_DIRS are not type-checked or linted here"
else
  skip typecheck "TYPECHECK_CMD not set"
  skip lint "LINT_CMD not set"
fi

# ── tests ────────────────────────────────────────────────────────────────────
TEST_START="$LOG_DIR/.test-start"
TESTS_RAN=0
if [[ -z "${GATE_TEST_CMD:-}" ]]; then
  not_set test GATE_TEST_CMD
elif [[ $BUILD_OK -eq 0 ]]; then
  skip test "build failed"
else
  : > "$TEST_START"
  sleep 1  # reports must be measurably newer than this marker on coarse-mtime filesystems
  TESTS_RAN=1
  run_step test . "$GATE_TEST_CMD" || OTHERS_OK=0
fi

# the build, lint and test commands left the change as it was
STATE1="$(state_lines)"
if [[ "$STATE1" != "$STATE0" ]]; then
  FAILED=1; OTHERS_OK=0
  # name what changed (each line's last word is its value)
  moved="$(printf '%s\n%s\n' "$STATE0" "$STATE1" | sort | uniq -u | sed 's/ [^ ]*$//' | sort -u | head -n 10 | tr '\n' ',' | sed 's/,$//; s/,/, /g')"
  printf '%-12s FAIL  a build, lint or test command changed %s; the checks below would judge another tree (a formatter or --fix: keep its edit and rerun)\n' gate-config "$moved"
fi

# ── coverage, complexity, CRAP ───────────────────────────────────────────────
if [[ -n "${COVERAGE_REPORTS:-}${COVERAGE_MIN:-}${COMPLEXITY_MAX:-}${CRAP_MAX:-}" ]]; then
  RAN=1
  find_python
  if [[ $BUILD_OK -eq 0 ]]; then
    skip metrics "build failed"
  elif [[ -z "$PY" ]]; then
    FAILED=1; OTHERS_OK=0
    printf '%-12s FAIL  python 3 not found; the configured coverage/complexity/CRAP checks could not run\n' metrics
  else
    args=(--base "$MERGE_BASE")
    set -f
    for g in ${COVERAGE_REPORTS:-}; do args+=(--report-glob "$g"); done
    for g in ${COVERAGE_EXEMPT_GLOBS:-}; do args+=(--exempt "$g"); done
    set +f
    [[ $TESTS_RAN -eq 1 ]] && args+=(--fresh-after "$TEST_START")
    [[ -n "${COVERAGE_MIN:-}" ]] && args+=(--coverage-min "$COVERAGE_MIN")
    [[ -n "${COMPLEXITY_MAX:-}" ]] && args+=(--complexity-max "$COMPLEXITY_MAX")
    [[ -n "${CRAP_MAX:-}" ]] && args+=(--crap-max "$CRAP_MAX")
    printf '%s\n' "${SOURCES[@]}" > "$LOG_DIR/sources.txt"
    printf '%s\n' "${TESTS[@]}" > "$LOG_DIR/tests.txt"
    out="$("$PY" "$SCRIPT_DIR/quality-metrics.py" "${args[@]}" --files-from "$LOG_DIR/sources.txt" --tests-from "$LOG_DIR/tests.txt" 2>&1)"
    rc=$?
    printf '%s\n' "$out" | tee "$LOG_DIR/metrics.log"
    [[ $rc -ne 0 ]] && { FAILED=1; OTHERS_OK=0; }
  fi
else
  skip metrics "COVERAGE_REPORTS, COVERAGE_MIN, COMPLEXITY_MAX and CRAP_MAX not set"
fi

# ── suppressions and skipped tests the change adds ───────────────────────────
# A suppression the change adds passes only when the same line was removed elsewhere in the
# change (rename detection on), or the identical suppression (rules and scope included) was
# removed from the same file: moving a file or a line that already carried one, or editing the
# code on such a line, adds nothing, while swapping one for another, or for a broader one, is
# still caught.
MODE="${SUPPRESSION_CHECK:-off}"
# Renamed files, as "new TAB old" lines: an edited suppression line in a renamed file is the
# same suppression.
RENAMES="$(git diff --no-ext-diff -M --name-status "$MERGE_BASE" 2>/dev/null | awk -F'\t' '$1 ~ /^R/ { print $3 "\t" $2 }')"
# diff_records <scope> <oldscope>: one record per changed line of the `git diff` on stdin, as
# sign TAB file TAB text: "+" lines only for paths in <scope>, "-" lines only for base paths in
# <oldscope> (both newline-separated, passed through the environment because macOS awk refuses
# a newline in -v). File headers are read only before a file's first hunk.
diff_records() {
  SCOPE="$1" OLDSCOPE="$2" awk '
    BEGIN { n = split(ENVIRON["SCOPE"], s, "\n"); for (i = 1; i <= n; i++) if (s[i] != "") ok[s[i]] = 1
            n = split(ENVIRON["OLDSCOPE"], o, "\n"); for (i = 1; i <= n; i++) if (o[i] != "") was[o[i]] = 1 }
    /^diff --git / { file = ""; old = ""; head = 1; next }
    head && /^\+\+\+ / { file = substr($0, 7); sub(/\t$/, "", file); next }  # a path with a space ends in a TAB
    head && /^--- /   { old = substr($0, 7); sub(/\t$/, "", old); next }
    /^@@/     { head = 0; next }
    head      { next }
    /^\+/     { if (file in ok) print "+\t" file "\t" substr($0, 2); next }
    /^-/      { if (old in was) print "-\t" old "\t" substr($0, 2) }'
}
# untracked_records <file>...: every line of the untracked ones among them, as added records.
untracked_records() {
  local f
  git ls-files --others --exclude-standard | while IFS= read -r f; do
    if printf '%s\n' "$@" | grep -qxF -- "$f"; then awk -v f="$f" '{ print "+\t" f "\t" $0 }' "$f"; fi
  done
}
# tag <letter>: prefixes each line of stdin with the letter and a TAB (BSD sed has no \t).
tag() { awk -v t="$1" '{ print t "\t" $0 }'; }
if [[ "$MODE" != "off" && -n "${SUPPRESSION_PATTERNS:-}${BASEPAT_SUPPRESSION_PATTERNS:-}" && ${#SUPP_E[@]} -eq 0 ]]; then
  RAN=1; FAILED=1; OTHERS_OK=0
  printf '%-12s FAIL  no SUPPRESSION_PATTERNS value compiles as an extended regex; the check could not run\n' suppressions
elif [[ "$MODE" != "off" && -n "${SUPPRESSION_PATTERNS:-}${BASEPAT_SUPPRESSION_PATTERNS:-}" ]]; then
  RAN=1
  in_scope="$(printf '%s\n' "${SOURCES[@]}" "${TESTS[@]}")"
  # Removed lines count only from source files too (their old paths, renames and deletions
  # included), so deleting a doc line that mentions a suppression hides nothing.
  old_scope="$(
    git diff --no-ext-diff -M --name-status "$MERGE_BASE" 2>/dev/null | while IFS=$'\t' read -r st p _; do
      [[ "$p" == .ai/* || "$p" == .claude/* ]] && continue
      set -f; keep=0   # $p: the path at the base (the first column, also for a rename)
      if [[ -z "${SOURCE_GLOBS:-}" ]]; then keep=1; else for g in $SOURCE_GLOBS; do [[ "$p" == $g ]] && keep=1 && break; done; fi
      set +f
      [[ $keep -eq 1 ]] && printf '%s\n' "$p"
    done
  )"
  hits="$(
    git diff --no-ext-diff --no-textconv --text -M -U0 "$MERGE_BASE" -- 2>/dev/null | diff_records "$in_scope" "$old_scope"
    untracked_records "${SOURCES[@]}" "${TESTS[@]}"
  )"
  add_recs="$(printf '%s\n' "$hits" | grep '^+')"
  rem_recs="$(printf '%s\n' "$hits" | grep '^-')"
  # Each line's suppression: the pattern's match and the rule list or scope right after it ("# noqa"
  # is not "# noqa: F401", "eslint-disable" not "eslint-disable-line no-console"), but not the
  # code around it, as row:text, the row of its line in the records. Matched on the line's text
  # only, never on its path.
  # Rule names (@typescript-eslint/no-explicit-any), bracketed codes (type: ignore[attr-defined])
  # and quoted argument lists (@SuppressWarnings("all"), SuppressMessage("Style", "IDE0001")) count;
  # a skipped test's name and body do not. A paren group may hold quoted text and one level of
  # nested parens (skipif(sys.version_info < (3, 8))).
  # each value on its own, as row:value:token. One grep with several -e prints only the
  # leftmost-longest match at each spot, so a broad value could swallow the other's match.
  supp_toks() {
    local text i=0 e
    text="$(cat)"
    for e in "${SUPP_E[@]}"; do
      [[ "$e" == "-e" ]] && continue
      i=$((i + 1))
      printf '%s\n' "$text" | grep -anoE -e "$e" | sed "s/:/:$i:/"
    done
  }
  add_tok="$(printf '%s\n' "$add_recs" | cut -f3- | supp_toks)"
  rem_tok="$(printf '%s\n' "$rem_recs" | cut -f3- | supp_toks)"
  # An added one is not new when the same line was removed anywhere (a move), or the same
  # suppression was removed from the same file, or from the file it was renamed from (an edit
  # to the code on a line that carries one).
  added="$(
    { printf '%s\n' "$rem_tok" | tag r
      printf '%s\n' "$add_tok" | tag a
      printf '%s\n' "$rem_recs" | tag R
      printf '%s\n' "$add_recs" | tag A; } | RENAMES="$RENAMES" awk '
      BEGIN { n = split(ENVIRON["RENAMES"], rl, "\n")
              for (i = 1; i <= n; i++) if (split(rl[i], pr, "\t") == 2) from[pr[1]] = pr[2] }
      function trim(s) { gsub(/^[ \t\r]+|[ \t\r]+$/, "", s); return s }
      function rec(kind,   t) { t = $0; sub(/^[RA]\t[-+]\t/, "", t); f = t; sub(/\t.*/, "", f); sub(/^[^\t]*\t/, "", t); return trim(t) }
      /^[ra]\t[0-9]+:/ { k = substr($0, 1, 1); t = substr($0, 3); row = t; sub(/:.*/, "", row); sub(/^[0-9]+:/, "", t)
                         v = t; sub(/:.*/, "", v); sub(/^[0-9]+:/, "", t)  # which value matched
                         sub(/[ \t]+(--|\/\/|#).*$/, "", t)  # a free-text reason after it is not part of it
                         toks[k, row] = toks[k, row] SUBSEP v ":" trim(t); has[k, row] = 1; next }
      /^R\t/ { nr++; rtext[nr] = rec(); rfile[nr] = f; next }
      /^A\t/ { na++; atext[na] = rec(); afile[na] = f; next }
      END {
        for (i = 1; i <= nr; i++) if (("r", i) in has) line[rtext[i]]++
        for (j = 1; j <= na; j++) if (("a", j) in has && line[atext[j]] > 0) { line[atext[j]]--; moved[j] = 1; used[atext[j]]++ }
        for (i = 1; i <= nr; i++) {
          if (!(("r", i) in has)) continue
          if (used[rtext[i]] > 0) { used[rtext[i]]--; continue }
          n = split(toks["r", i], tk, SUBSEP); for (x = 2; x <= n; x++) pool[rfile[i], tk[x]]++
        }
        for (j = 1; j <= na; j++) {
          if (!(("a", j) in has) || (j in moved)) continue
          n = split(toks["a", j], tk, SUBSEP); fresh = 0
          for (x = 2; x <= n; x++) {
            f = afile[j]
            if (!(pool[f, tk[x]] > 0) && (f in from)) f = from[f]
            if (pool[f, tk[x]] > 0) pool[f, tk[x]]--; else fresh = 1
          }
          if (fresh) print afile[j] ": " atext[j]
        }
      }'
  )"
  n_added=0
  [[ -n "$added" ]] && n_added="$(printf '%s\n' "$added" | wc -l | tr -d ' ')"
  if [[ $n_added -eq 0 ]]; then
    printf '%-12s PASS  none added\n' suppressions
  else
    if [[ "$MODE" == "block" ]]; then
      FAILED=1; OTHERS_OK=0
      printf '%-12s FAIL  %s added (SUPPRESSION_CHECK=block): remove them or have a human add them\n' suppressions "$n_added"
    else
      printf '%-12s WARN  %s added: each needs a stated reason in the test report, or removal\n' suppressions "$n_added"
    fi
    printf '%s\n' "$added" | head -n 20 | sed 's/^/    /'
  fi
else
  skip suppressions "$([[ "$MODE" == off ]] && echo "SUPPRESSION_CHECK off" || echo "SUPPRESSION_PATTERNS not set")"
fi

# ── removed tests (part of the suppression guard) ────────────────────────────
# Lists the test-case and assertion lines the change removes from test files without re-adding
# the same line elsewhere: a moved test passes, a deleted or rewritten one (a changed expected
# value included) is listed. Deleting or loosening a test is a way to get past the gate too.
if [[ "$MODE" == "off" || -z "${TEST_ASSERTION_PATTERNS:-}${BASEPAT_TEST_ASSERTION_PATTERNS:-}" ]]; then
  skip test-removal "SUPPRESSION_CHECK off or TEST_ASSERTION_PATTERNS not set"
elif [[ -z "${TEST_FILE_PATTERNS:-}" ]]; then
  skip test-removal "TEST_FILE_PATTERNS not set"
elif [[ ${#ASSERT_E[@]} -eq 0 ]]; then
  RAN=1; FAILED=1; OTHERS_OK=0
  printf '%-12s FAIL  no TEST_ASSERTION_PATTERNS value compiles as an extended regex; the check could not run\n' test-removal
else
  RAN=1
  # is_test_path <path>: a source file (SOURCE_GLOBS, when set) that is a test (TEST_FILE_PATTERNS)
  is_test_path() {
    local g src=0
    [[ "$1" == .ai/* || "$1" == .claude/* ]] && return 1
    set -f
    if [[ -z "${SOURCE_GLOBS:-}" ]]; then src=1; else for g in $SOURCE_GLOBS; do [[ "$1" == $g ]] && src=1 && break; done; fi
    if [[ $src -eq 1 ]]; then for g in $TEST_FILE_PATTERNS; do [[ "$1" == $g ]] && { set +f; return 0; }; done; fi
    set +f
    return 1
  }
  # A test file renamed to a name that is no test keeps none of its tests: all its lines are removed.
  gone_tests="$(printf '%s\n' "$RENAMES" | while IFS=$'\t' read -r new old; do
    [[ -n "$old" ]] && is_test_path "$old" && ! is_test_path "$new" && printf '%s\n' "$old"; done)"
  old_tests="$(git diff --no-ext-diff -M --name-status "$MERGE_BASE" 2>/dev/null | while IFS=$'\t' read -r st p _; do
    is_test_path "$p" && ! printf '%s\n' "$gone_tests" | grep -qxF -- "$p" && printf '%s\n' "$p"; done)"
  # One record per changed line: sign TAB file TAB text (untracked test files count as added).
  records="$(
    git diff --no-ext-diff --no-textconv --text -M -U0 "$MERGE_BASE" -- 2>/dev/null | diff_records "$(printf '%s\n' "${TESTS[@]}")" "$old_tests"
    untracked_records "${TESTS[@]}"
    printf '%s\n' "$gone_tests" | while IFS= read -r f; do
      [[ -n "$f" ]] && git show "$MERGE_BASE:$f" 2>/dev/null | F="$f" awk '{ print "-\t" ENVIRON["F"] "\t" $0 }'; done
  )"
  removed_recs="$(printf '%s\n' "$records" | grep '^-')"
  # Match the pattern on the line's text only, never on its path.
  hit_rows="$(printf '%s\n' "$removed_recs" | cut -f3- | grep -anE "${ASSERT_E[@]}" | cut -d: -f1)"
  lost="$(
    { printf '%s\n' "$records" | grep '^+' | cut -f3- | tag A
      printf '%s\n' "$hit_rows" | tag H
      printf '%s\n' "$removed_recs" | tag R; } | awk -F'\t' '
      function trim(s) { gsub(/^[ \t\r]+|[ \t\r]+$/, "", s); return s }
      $1 == "A" { t = $0; sub(/^A\t/, "", t); added[trim(t)]++; next }
      $1 == "H" { hit[$2] = 1; next }
      $1 == "R" { r++; if (!(r in hit)) next
                  t = $0; sub(/^R\t-\t[^\t]*\t/, "", t); t = trim(t)
                  if (added[t] > 0) added[t]--; else print $3 ": " t }'
  )"
  n_lost=0
  [[ -n "$lost" ]] && n_lost="$(printf '%s\n' "$lost" | wc -l | tr -d ' ')"
  if [[ $n_lost -eq 0 ]]; then
    printf '%-12s PASS  none removed\n' test-removal
  else
    if [[ "$MODE" == "block" ]]; then
      FAILED=1; OTHERS_OK=0
      printf '%-12s FAIL  %s test case/assertion line(s) removed or changed (SUPPRESSION_CHECK=block): restore them or have a human approve\n' test-removal "$n_lost"
    else
      printf '%-12s WARN  %s test case/assertion line(s) removed or changed: each needs a stated reason in the test report, or restoring\n' test-removal "$n_lost"
    fi
    printf '%s\n' "$lost" | head -n 20 | sed 's/^/    /'
  fi
fi

# ── mutation testing (opt-in, slowest, last) ─────────────────────────────────
# Only the changed source files the mutation tool covers (MUTATION_GLOBS; blank ⇒ all of them).
MUT_SOURCES=()
set -f
for f in "${SOURCES[@]}"; do
  if [[ -z "${MUTATION_GLOBS:-}" ]]; then MUT_SOURCES+=("$f"); continue; fi
  for g in $MUTATION_GLOBS; do [[ "$f" == $g ]] && { MUT_SOURCES+=("$f"); break; }; done
done
set +f
RESULT_FILE="$LOG_DIR/mutation.result"
# A recorded result counts only for the same change measured by the same command.
CMD_ID="$(printf '%s\n%s\n' "${MUTATION_CMD:-}" "${MUTATION_GLOBS:-}" | git hash-object --stdin)"
if [[ -z "${MUTATION_CMD:-}" ]]; then
  [[ $MUTATION -eq 1 ]] && skip mutation "MUTATION_CMD not set"
elif [[ ${#MUT_SOURCES[@]} -eq 0 ]]; then
  skip mutation "no changed source files${MUTATION_GLOBS:+ match MUTATION_GLOBS}"
elif [[ $MUTATION -eq 0 ]]; then
  r_verdict="" r_fp="" r_cmd=""
  [[ -f "$RESULT_FILE" ]] && read -r r_verdict r_fp r_cmd < "$RESULT_FILE"
  if [[ "$r_fp" == "$FINGERPRINT" && "$r_cmd" == "$CMD_ID" ]]; then
    RAN=1
    printf '%-12s %-5s (recorded by an earlier --mutation run on this exact change)  log: %s\n' mutation "$r_verdict" "$LOG_DIR/mutation.log"
    [[ "$r_verdict" == "FAIL" ]] && FAILED=1
  else
    skip mutation "not run for this exact change (--mutation)"
  fi
elif [[ $OTHERS_OK -eq 0 ]]; then
  skip mutation "fix the failures above first"
else
  files="$(printf '%q' "$(IFS=,; echo "${MUT_SOURCES[*]}")")"  # one shell word, already quoted
  cmd="${MUTATION_CMD//\{files\}/$files}"
  cmd="${cmd//\{base\}/$MERGE_BASE}"
  cmd="$(expand_each "$cmd")"
  rm -f "$LOG_DIR/mutation.log"
  if run_step mutation . "$cmd" "${#MUT_SOURCES[@]} file(s)"; then
    echo "PASS $FINGERPRINT $CMD_ID" > "$RESULT_FILE"
  else
    echo "FAIL $FINGERPRINT $CMD_ID" > "$RESULT_FILE"
  fi
fi

echo
if [[ $FAILED -ne 0 ]]; then
  echo "QUALITY GATE: FAIL"
  exit 1
elif [[ $RAN -eq 0 ]]; then
  echo "QUALITY GATE: NOT CONFIGURED (set the quality gate values in .claude/hooks/hooks.env; until then run the scope's gates by hand)"
  exit 0
elif [[ ${#NOT_SET[@]} -gt 0 ]]; then
  echo "QUALITY GATE: PASS (partial: $(IFS=,; echo "${NOT_SET[*]}" | sed "s/,/, /g") not configured; verify those by hand)"
  exit 0
fi
echo "QUALITY GATE: PASS"
exit 0
