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
#   gate-config  the hooks.env values it changes, since loosening them needs a person (always on, WARN only)
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
# The diff calls also pass --no-ext-diff --no-textconv for the same reason.
git() { command git -c core.quotePath=false -c color.ui=false -c color.diff=false -c diff.noprefix=false -c diff.mnemonicPrefix=false -c diff.srcPrefix=a/ -c diff.dstPrefix=b/ "$@"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
[[ -f "$SCRIPT_DIR/../hooks/hooks.env" ]] && source "$SCRIPT_DIR/../hooks/hooks.env"

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
  [[ -z "$PY" ]] && { echo "quality-gate: python 3 not found; the baseline needs it" >&2; exit 2; }
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

# ── The suppression guard's own settings ─────────────────────────────────────
# A change must not loosen the guard that judges it. The guard runs at the stricter of the base
# commit's and the working tree's SUPPRESSION_CHECK, and with the base's patterns as well as the
# working tree's, so turning it off, or blanking or narrowing a pattern, in the same change hides
# nothing. (The gate-config check lists every other value a change alters.)
BASE_CFG="$(git show "$MERGE_BASE:.claude/hooks/hooks.env" 2>/dev/null)"
# base_value <KEY>: KEY as the base commit's hooks.env sets it (empty when it has none).
base_value() { ( unset "$1"; eval "$BASE_CFG" >/dev/null 2>&1; printf '%s' "${!1:-}" ); }
mode_rank() { case "$1" in block) echo 2 ;; warn) echo 1 ;; *) echo 0 ;; esac; }
if [[ -n "$BASE_CFG" ]]; then
  b="$(base_value SUPPRESSION_CHECK)"
  [[ $(mode_rank "$b") -gt $(mode_rank "${SUPPRESSION_CHECK:-off}") ]] && SUPPRESSION_CHECK="$b"
  for k in SUPPRESSION_PATTERNS TEST_ASSERTION_PATTERNS; do
    b="$(base_value "$k")"
    w="${!k:-}"
    if [[ -n "$b" && "$b" != "$w" ]]; then
      if [[ -z "$w" ]]; then printf -v "$k" '%s' "$b"; else printf -v "$k" '%s' "($w)|($b)"; fi
    fi
  done
  b="$(base_value TEST_FILE_PATTERNS)"
  [[ -n "$b" && "$b" != "${TEST_FILE_PATTERNS:-}" ]] && TEST_FILE_PATTERNS="${TEST_FILE_PATTERNS:+$TEST_FILE_PATTERNS }$b"
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
if [[ "$MODE" != "off" && -n "${SUPPRESSION_PATTERNS:-}" ]]; then
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
    git diff --no-ext-diff --no-textconv -M -U0 "$MERGE_BASE" -- 2>/dev/null | diff_records "$in_scope" "$old_scope"
    untracked_records "${SOURCES[@]}" "${TESTS[@]}"
  )"
  add_recs="$(printf '%s\n' "$hits" | grep '^+')"
  rem_recs="$(printf '%s\n' "$hits" | grep '^-')"
  # Each line's suppression, from where the pattern first matches to the end of the line (so
  # its rule list and scope count: "# noqa" is not "# noqa: F401"), as row:text, the row of its
  # line in the records. Matched on the line's text only, never on its path.
  add_tok="$(printf '%s\n' "$add_recs" | cut -f3- | grep -noE -- "($SUPPRESSION_PATTERNS).*")"
  rem_tok="$(printf '%s\n' "$rem_recs" | cut -f3- | grep -noE -- "($SUPPRESSION_PATTERNS).*")"
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
                         toks[k, row] = toks[k, row] SUBSEP trim(t); has[k, row] = 1; next }
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
  skip suppressions "SUPPRESSION_CHECK off"
fi

# ── removed tests (part of the suppression guard) ────────────────────────────
# Lists the test-case and assertion lines the change removes from test files without re-adding
# the same line elsewhere: a moved test passes, a deleted or rewritten one (a changed expected
# value included) is listed. Deleting or loosening a test is a way to get past the gate too.
if [[ "$MODE" == "off" || -z "${TEST_ASSERTION_PATTERNS:-}" ]]; then
  skip test-removal "SUPPRESSION_CHECK off or TEST_ASSERTION_PATTERNS not set"
elif [[ -z "${TEST_FILE_PATTERNS:-}" ]]; then
  skip test-removal "TEST_FILE_PATTERNS not set"
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
  old_tests="$(git diff --no-ext-diff -M --name-status "$MERGE_BASE" 2>/dev/null | while IFS=$'\t' read -r st p _; do is_test_path "$p" && printf '%s\n' "$p"; done)"
  # One record per changed line: sign TAB file TAB text (untracked test files count as added).
  records="$(
    git diff --no-ext-diff --no-textconv -M -U0 "$MERGE_BASE" -- 2>/dev/null | diff_records "$(printf '%s\n' "${TESTS[@]}")" "$old_tests"
    untracked_records "${TESTS[@]}"
  )"
  removed_recs="$(printf '%s\n' "$records" | grep '^-')"
  # Match the pattern on the line's text only, never on its path.
  hit_rows="$(printf '%s\n' "$removed_recs" | cut -f3- | grep -nE -- "$TEST_ASSERTION_PATTERNS" | cut -d: -f1)"
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

# ── gate config ──────────────────────────────────────────────────────────────
# A change can loosen the gate that judges it, and the gate reads hooks.env from the working
# tree: list every value the change sets differently from the base, for the person approving
# it. Always on, and only ever a WARN: tightening a value is free, and a FAIL here could never
# clear on the branch that makes the change.
CFG=".claude/hooks/hooks.env"
if [[ -f "$CFG" ]] && ! git cat-file -e "$MERGE_BASE:$CFG" 2>/dev/null \
   && [[ -n "$(git ls-files --cached --others --exclude-standard -- "$CFG")" ]]; then
  printf '%-12s WARN  %s is not in the base commit: every value in it is new (expected only at setup)\n' gate-config "$CFG"
else
  cfg_keys="$(git diff --no-ext-diff --no-textconv -U0 "$MERGE_BASE" -- "$CFG" 2>/dev/null \
    | grep -E '^[+-][A-Z][A-Z0-9_]*=' | sed -E 's/^[+-]([A-Z0-9_]+)=.*/\1/' | sort -u | tr '\n' ' ')"
  cfg_keys="${cfg_keys% }"
  if [[ -z "$cfg_keys" ]]; then
    printf '%-12s PASS  hooks.env unchanged\n' gate-config
  else
    printf '%-12s WARN  hooks.env changes %s: loosening a value needs the user'"'"'s own words and a decisions.md entry\n' gate-config "$cfg_keys"
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
