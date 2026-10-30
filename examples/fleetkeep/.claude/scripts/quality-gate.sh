#!/usr/bin/env bash
# Quality gate: one deterministic pass/fail for the current change, with the numbers.
#
#   .claude/scripts/quality-gate.sh [--base <ref>] [--mutation]
#
#   --base <ref>   what the change is measured against: the branch the work started from
#                  (default HEAD = uncommitted changes only). Committed and uncommitted work
#                  since the merge-base both count, untracked files included.
#   --mutation     also run MUTATION_CMD (slow). It runs only when every other check passed,
#                  and its result is recorded for this exact change: a later run without
#                  --mutation on unchanged code reports it instead of running it again.
#
# Checks, each skipped while its hooks.env value is blank:
#   build        GATE_BUILD_CMD, from the repo root
#   typecheck    TYPECHECK_CMD, inside each PACKAGE_DIRS dir the change touched
#   lint         LINT_CMD on the changed source files, inside their package dir
#   test         GATE_TEST_CMD, from the repo root; it should also write COVERAGE_REPORTS
#   metrics      diff coverage (COVERAGE_MIN), complexity (COMPLEXITY_MAX) and CRAP (CRAP_MAX)
#                on the functions the change touched, via quality-metrics.py
#   suppressions lint/coverage suppressions and skipped tests the change adds (SUPPRESSION_CHECK)
#   mutation     MUTATION_CMD with {files} and {base} filled in (only with --mutation)
#
# Prints one line per check, the tail of each failure, and a final verdict. "PASS (partial ...)"
# means the build or the tests are not configured, so the gate did not run them: verify those
# by hand. Full
# logs go under .git/quality-gate/, so nothing new needs gitignoring.
# Exit 0 = PASS, PASS (partial) or NOT CONFIGURED; 1 = FAIL; 2 = usage error.

set -o pipefail   # no -u: macOS ships bash 3.2, where empty arrays trip it

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
[[ -f "$SCRIPT_DIR/../hooks/hooks.env" ]] && source "$SCRIPT_DIR/../hooks/hooks.env"

BASE="HEAD"
MUTATION=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --base) BASE="${2:-}"; shift 2 ;;
    --mutation) MUTATION=1; shift ;;
    -h|--help) sed -n '2,26p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "quality-gate: unknown argument '$1' (see --help)" >&2; exit 2 ;;
  esac
done

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "quality-gate: not inside a git repository" >&2; exit 2; }
cd "$REPO_ROOT" || exit 2
MERGE_BASE="$(git merge-base "$BASE" HEAD 2>/dev/null)" || { echo "quality-gate: cannot find a merge-base with '$BASE' (a repo with one commit has no HEAD~1)" >&2; exit 2; }
LOG_DIR="$(git rev-parse --absolute-git-dir)/quality-gate"
mkdir -p "$LOG_DIR"
for f in "$LOG_DIR"/*.log; do
  [[ -e "$f" ]] || continue
  [[ $MUTATION -eq 0 && "$f" == */mutation.log ]] && continue  # keep the recorded mutation run
  rm -f "$f"
done

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

echo "Quality gate: ${#CHANGED[@]} changed and ${#DELETED[@]} deleted file(s) vs $BASE (${MERGE_BASE:0:10}); ${#SOURCES[@]} source, ${#TESTS[@]} test"
if [[ ${#CHANGED[@]} -eq 0 && ${#DELETED[@]} -eq 0 ]]; then
  echo "QUALITY GATE: PASS (nothing changed)"
  exit 0
fi

# The change's fingerprint: identical source and tests ⇒ identical value. Ties a mutation result
# to it. Only SOURCES and TESTS count, so a report a tool writes into the tree does not move it.
FINGERPRINT="none"
if [[ ${#SOURCES[@]} -gt 0 || ${#TESTS[@]} -gt 0 ]]; then
  FINGERPRINT="$( { git diff "$MERGE_BASE" -- "${SOURCES[@]}" "${TESTS[@]}" 2>/dev/null
                    for f in "${SOURCES[@]}" "${TESTS[@]}"; do printf '%s ' "$f"; git hash-object -- "$f"; done; } | git hash-object --stdin)"
fi

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
  PY=""
  for p in python3 python; do
    if command -v "$p" >/dev/null 2>&1 && "$p" -c 'import sys' >/dev/null 2>&1; then PY="$p"; break; fi
  done
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
      /^\+\+\+ / { file = substr($0, 7); next }
      /^--- /   { old = substr($0, 7); next }
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
