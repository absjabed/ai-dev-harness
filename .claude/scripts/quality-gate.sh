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
#   mutation     MUTATION_CMD with {files}, {base} and {each:…} filled in (only with --mutation)
#
# Prints one line per check, the tail of each failure, and a final verdict. "PASS (partial ...)"
# means the build or the tests are not configured, so the gate did not run them: verify those
# by hand. Full
# logs go under .git/quality-gate/, so nothing new needs gitignoring.
# Exit 0 = PASS, PASS (partial), NOT CONFIGURED or a written baseline; 1 = FAIL or no baseline
# written; 2 = usage error.

set -o pipefail   # no -u: macOS ships bash 3.2, where empty arrays trip it

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
[[ -f "$SCRIPT_DIR/../hooks/hooks.env" ]] && source "$SCRIPT_DIR/../hooks/hooks.env"

BASE="HEAD"
MUTATION=0
BASELINE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --base) BASE="${2:-}"; shift 2 ;;
    --mutation) MUTATION=1; shift ;;
    --baseline) BASELINE=1; shift ;;
    -h|--help) sed -n '2,38p' "${BASH_SOURCE[0]}"; exit 0 ;;
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
  [[ $MUTATION -eq 0 && "$f" == */mutation.log ]] && continue  # keep the recorded mutation run
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

# expand_each <cmd>: replaces one {each:TEMPLATE} with TEMPLATE once per changed source file,
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
  for f in "${SOURCES[@]}"; do
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

# ── What changed ─────────────────────────────────────────────────────────────
CHANGED=()   # present now (added, modified, renamed, untracked)
DELETED=()
while IFS= read -r f; do CHANGED+=("$f"); done < <( { git diff --name-only --diff-filter=d -M "$MERGE_BASE" 2>/dev/null; git ls-files --others --exclude-standard; } | sort -u)
while IFS= read -r f; do DELETED+=("$f"); done < <(git diff --name-only --diff-filter=D -M "$MERGE_BASE" 2>/dev/null)
SOURCES=()
TESTS=()
set -f  # keep the configured globs literal while word-splitting them
for f in "${CHANGED[@]}"; do
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
      for d in $PACKAGE_DIRS; do [[ "$f" == "$d"/* ]] && inside=1 && break; done
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
if [[ -n "${COVERAGE_REPORTS:-}${COMPLEXITY_MAX:-}${CRAP_MAX:-}" ]]; then
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
    out="$("$PY" "$SCRIPT_DIR/quality-metrics.py" "${args[@]}" -- "${SOURCES[@]}" 2>&1)"
    rc=$?
    printf '%s\n' "$out" | tee "$LOG_DIR/metrics.log"
    [[ $rc -ne 0 ]] && { FAILED=1; OTHERS_OK=0; }
  fi
else
  skip metrics "COVERAGE_REPORTS, COMPLEXITY_MAX and CRAP_MAX not set"
fi

# ── suppressions and skipped tests the change adds ───────────────────────────
# Net count across the whole change with rename detection, so moving a file, or a line,
# that already carried a suppression adds nothing.
MODE="${SUPPRESSION_CHECK:-off}"
if [[ "$MODE" != "off" && -n "${SUPPRESSION_PATTERNS:-}" ]]; then
  RAN=1
  in_scope="$(printf '%s\n' "${SOURCES[@]}" "${TESTS[@]}")"
  # Removed lines count only from source files too (their old paths, renames and deletions
  # included), so deleting a doc line that mentions a suppression hides nothing.
  old_scope="$(
    git diff -M --name-status "$MERGE_BASE" 2>/dev/null | while IFS=$'\t' read -r st p _; do
      set -f; keep=0   # $p: the path at the base (the first column, also for a rename)
      if [[ -z "${SOURCE_GLOBS:-}" ]]; then keep=1; else for g in $SOURCE_GLOBS; do [[ "$p" == $g ]] && keep=1 && break; done; fi
      set +f
      [[ $keep -eq 1 ]] && printf '%s\n' "$p"
    done
  )"
  hits="$(
    git diff -M -U0 "$MERGE_BASE" -- 2>/dev/null | awk -v scope="$in_scope" -v oldscope="$old_scope" '
      BEGIN { n = split(scope, s, "\n"); for (i = 1; i <= n; i++) if (s[i] != "") ok[s[i]] = 1
              n = split(oldscope, o, "\n"); for (i = 1; i <= n; i++) if (o[i] != "") was[o[i]] = 1 }
      /^diff --git / { file = ""; old = ""; next }
      /^\+\+\+ / { file = substr($0, 7); sub(/\t$/, "", file); next }  # a path with a space ends in a TAB
      /^--- /   { old = substr($0, 7); sub(/\t$/, "", old); next }
      /^\+/     { if (file in ok) print "+\t" file "\t" substr($0, 2); next }
      /^-/      { if (old in was) print "-\t\t" substr($0, 2) }'
    git ls-files --others --exclude-standard | while IFS= read -r f; do
      if printf '%s\n' "${SOURCES[@]}" "${TESTS[@]}" | grep -qxF -- "$f"; then
        awk -v f="$f" '{ print "+\t" f "\t" $0 }' "$f"
      fi
    done
  )"
  added="$(printf '%s\n' "$hits" | grep '^+' | cut -f2- | grep -E -- "$SUPPRESSION_PATTERNS" | awk -F'\t' '{ print $1 ": " $2 }')"
  n_added=0
  [[ -n "$added" ]] && n_added="$(printf '%s\n' "$added" | wc -l | tr -d ' ')"
  n_removed="$(printf '%s\n' "$hits" | grep '^-' | cut -f3- | grep -cE -- "$SUPPRESSION_PATTERNS" || true)"
  net=$((n_added - ${n_removed:-0}))
  if [[ $net -le 0 ]]; then
    printf '%-12s PASS  none added\n' suppressions
  else
    if [[ "$MODE" == "block" ]]; then
      FAILED=1; OTHERS_OK=0
      printf '%-12s FAIL  %s added (SUPPRESSION_CHECK=block): remove them or have a human add them\n' suppressions "$net"
    else
      printf '%-12s WARN  %s added: each needs a stated reason in the test report, or removal\n' suppressions "$net"
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
    set -f
    if [[ -z "${SOURCE_GLOBS:-}" ]]; then src=1; else for g in $SOURCE_GLOBS; do [[ "$1" == $g ]] && src=1 && break; done; fi
    if [[ $src -eq 1 ]]; then for g in $TEST_FILE_PATTERNS; do [[ "$1" == $g ]] && { set +f; return 0; }; done; fi
    set +f
    return 1
  }
  old_tests="$(git diff -M --name-status "$MERGE_BASE" 2>/dev/null | while IFS=$'\t' read -r st p _; do is_test_path "$p" && printf '%s\n' "$p"; done)"
  # One record per changed line: sign TAB file TAB text (untracked test files count as added).
  records="$(
    git diff -M -U0 "$MERGE_BASE" -- 2>/dev/null | awk -v scope="$(printf '%s\n' "${TESTS[@]}")" -v oldscope="$old_tests" '
      BEGIN { n = split(scope, s, "\n"); for (i = 1; i <= n; i++) if (s[i] != "") ok[s[i]] = 1
              n = split(oldscope, o, "\n"); for (i = 1; i <= n; i++) if (o[i] != "") was[o[i]] = 1 }
      /^diff --git / { file = ""; old = ""; next }
      /^\+\+\+ / { file = substr($0, 7); sub(/\t$/, "", file); next }
      /^--- /   { old = substr($0, 7); sub(/\t$/, "", old); next }
      /^\+/     { if (file in ok) print "+\t" file "\t" substr($0, 2); next }
      /^-/      { if (old in was) print "-\t" old "\t" substr($0, 2) }'
    git ls-files --others --exclude-standard | while IFS= read -r f; do
      if printf '%s\n' "${TESTS[@]}" | grep -qxF -- "$f"; then awk -v f="$f" '{ print "+\t" f "\t" $0 }' "$f"; fi
    done
  )"
  removed_recs="$(printf '%s\n' "$records" | grep '^-')"
  # Match the pattern on the line's text only, never on its path.
  hit_rows="$(printf '%s\n' "$removed_recs" | cut -f3- | grep -nE -- "$TEST_ASSERTION_PATTERNS" | cut -d: -f1)"
  lost="$(
    { printf '%s\n' "$records" | grep '^+' | cut -f3- | sed 's/^/A\t/'
      printf '%s\n' "$hit_rows" | sed 's/^/H\t/'
      printf '%s\n' "$removed_recs" | sed 's/^/R\t/'; } | awk -F'\t' '
      function trim(s) { gsub(/^[ \t\r]+|[ \t\r]+$/, "", s); return s }
      $1 == "A" { t = $0; sub(/^A\t/, "", t); added[trim(t)] = 1; next }
      $1 == "H" { hit[$2] = 1; next }
      $1 == "R" { r++; if (!(r in hit)) next
                  t = $0; sub(/^R\t-\t[^\t]*\t/, "", t); t = trim(t)
                  if (!(t in added)) print $3 ": " t }'
  )"
  n_lost=0
  [[ -n "$lost" ]] && n_lost="$(printf '%s\n' "$lost" | wc -l | tr -d ' ')"
  if [[ $n_lost -eq 0 ]]; then
    printf '%-12s PASS  none removed\n' test-removal
  else
    if [[ "$MODE" == "block" ]]; then
      FAILED=1
      printf '%-12s FAIL  %s test case/assertion line(s) removed or changed (SUPPRESSION_CHECK=block): restore them or have a human approve\n' test-removal "$n_lost"
    else
      printf '%-12s WARN  %s test case/assertion line(s) removed or changed: each needs a stated reason in the test report, or restoring\n' test-removal "$n_lost"
    fi
    printf '%s\n' "$lost" | head -n 20 | sed 's/^/    /'
  fi
fi

# ── mutation testing (opt-in, slowest, last) ─────────────────────────────────
RESULT_FILE="$LOG_DIR/mutation.result"
if [[ -z "${MUTATION_CMD:-}" ]]; then
  [[ $MUTATION -eq 1 ]] && skip mutation "MUTATION_CMD not set"
elif [[ $MUTATION -eq 0 ]]; then
  if [[ -f "$RESULT_FILE" && "$(cut -d' ' -f2 "$RESULT_FILE")" == "$FINGERPRINT" ]]; then
    RAN=1
    verdict="$(cut -d' ' -f1 "$RESULT_FILE")"
    printf '%-12s %-5s (recorded by an earlier --mutation run on this exact change)  log: %s\n' mutation "$verdict" "$LOG_DIR/mutation.log"
    [[ "$verdict" == "FAIL" ]] && FAILED=1
  else
    skip mutation "not run for this exact change (--mutation)"
  fi
elif [[ $OTHERS_OK -eq 0 ]]; then
  skip mutation "fix the failures above first"
elif [[ ${#SOURCES[@]} -eq 0 ]]; then
  skip mutation "no changed source files"
else
  files="$(IFS=,; echo "${SOURCES[*]}")"
  cmd="${MUTATION_CMD//\{files\}/$files}"
  cmd="${cmd//\{base\}/$MERGE_BASE}"
  cmd="$(expand_each "$cmd")"
  if run_step mutation . "$cmd" "${#SOURCES[@]} file(s)"; then
    echo "PASS $FINGERPRINT" > "$RESULT_FILE"
  else
    echo "FAIL $FINGERPRINT" > "$RESULT_FILE"
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
