#!/usr/bin/env python3
"""quality-metrics.py: diff-scoped coverage, complexity and CRAP for the quality gate.

Called by .claude/scripts/quality-gate.sh; it can also be run on its own:

  python3 .claude/scripts/quality-metrics.py --base <sha> [--report-glob <glob>]...
      [--fresh-after <file>] [--exempt <glob>]... [--coverage-min 80]
      [--complexity-max 15] [--crap-max 30] -- file...

Judges only what the change touched:
  coverage    share of the changed, coverable lines that the tests ran (diff coverage)
  complexity  cyclomatic complexity of each function the change touched (needs `lizard`)
  CRAP        CC^2 * (1 - cov)^3 + CC per touched function: complex AND untested scores high

Ratchet: a touched function that was already over a limit before the change, and whose
complexity did not grow, is reported as WARN, not FAIL. New code must meet the limits; old
code must not get worse. Renamed files and changed signatures keep their history.

When a limit is set, a changed file that no coverage report mentions counts as untested
(many tools leave unrun files out of the report). List files tests cannot reach in --exempt.

Coverage reports read: lcov (lcov.info), Cobertura XML (coverlet, coverage.py `coverage xml`,
many others), JaCoCo XML, and Go cover profiles. Standard library only, except `lizard`
(pip install lizard), which is needed only for complexity and CRAP.

Exit status: 0 = no FAIL, 1 = at least one FAIL (including a configured check that could not run).
"""
import argparse
import fnmatch
import glob
import os
import re
import subprocess
import sys
import xml.etree.ElementTree as ET

TOP_N = 15
LIST_N = 10
TRIVIAL = re.compile(r"^\s*($|//|#|/\*|\*|--|[{}()\[\];,]+\s*$)")


def git(*args):
    return subprocess.run(["git", *args], capture_output=True, text=True,
                          encoding="utf-8", errors="replace").stdout


def norm(path):
    path = path.replace("\\", "/")
    while path.startswith("./"):
        path = path[2:]
    return path


def short(items):
    return ", ".join(items[:LIST_N]) + (f" ... and {len(items) - LIST_N} more" if len(items) > LIST_N else "")


def changed_lines(base, rel, old):
    """Line numbers in the working-tree copy of `rel` that differ from `base` (`old` = its path there)."""
    if old is None:  # new file: every line is new
        try:
            with open(rel, encoding="utf-8", errors="replace") as fh:
                return set(range(1, sum(1 for _ in fh) + 1))
        except OSError:
            return set()
    # Name both paths so git pairs a rename; keep only the hunks of the new path.
    diff = git("diff", "-M", "-U0", base, "--", *sorted({old, rel}))
    sections = re.split(r"^diff --git ", diff, flags=re.M)
    diff = next((s for s in sections if re.search(r"^\+\+\+ b/" + re.escape(rel) + r"$", s, re.M)), "")
    lines = set()
    for hunk in re.finditer(r"^@@ -\S+ \+(\d+)(?:,(\d+))? @@", diff, re.M):
        start, count = int(hunk.group(1)), int(hunk.group(2) or 1)
        lines.update(range(start, start + count))
    return lines


def base_paths(base):
    """{current path: path at base} for every file that existed at base (renames followed)."""
    mapping = {}
    for raw in git("diff", "-M", "--name-status", base).splitlines():
        parts = raw.split("\t")
        if parts[0].startswith("R") and len(parts) == 3:
            mapping[norm(parts[2])] = norm(parts[1])
        elif parts[0] in ("M", "T") and len(parts) == 2:
            mapping[norm(parts[1])] = norm(parts[1])
    return mapping


# ── Coverage reports → {path: {line: hits}} ──────────────────────────────────

def merge(cov, path, line, hits):
    per_file = cov.setdefault(norm(path), {})
    per_file[line] = max(per_file.get(line, 0), hits)


def read_lcov(text, cov):
    current = None
    for raw in text.splitlines():
        if raw.startswith("SF:"):
            current = raw[3:].strip()
        elif raw.startswith("DA:") and current:
            parts = raw[3:].split(",")
            merge(cov, current, int(parts[0]), int(float(parts[1])))


def read_cobertura(root, cov):
    sources = [s.text.strip() for s in root.iter("source") if s.text and s.text.strip()]
    for cls in root.iter("class"):
        filename = cls.get("filename", "")
        lines = cls.find("lines")
        if lines is None:
            continue
        targets = [os.path.join(src, filename) for src in sources] or [filename]
        for line in lines.iter("line"):
            for target in targets:
                merge(cov, target, int(line.get("number")), int(float(line.get("hits", "0"))))


def read_jacoco(root, cov):
    for pkg in root.iter("package"):
        for sf in pkg.iter("sourcefile"):
            path = f"{pkg.get('name', '')}/{sf.get('name', '')}"
            for line in sf.iter("line"):
                missed, covered = int(line.get("mi", "0")), int(line.get("ci", "0"))
                if missed + covered:
                    merge(cov, path, int(line.get("nr")), covered)


def read_go(text, cov):
    for raw in text.splitlines()[1:]:
        m = re.match(r"(.+):(\d+)\.\d+,(\d+)\.\d+ \d+ (\d+)$", raw.strip())
        if m:
            for line in range(int(m.group(2)), int(m.group(3)) + 1):
                merge(cov, m.group(1), line, int(m.group(4)))


def load_report(path):
    cov = {}
    with open(path, encoding="utf-8", errors="replace") as fh:
        text = fh.read()
    if text.lstrip().startswith("mode:"):
        read_go(text, cov)
    elif text.lstrip().startswith("<"):
        root = ET.fromstring(text)
        (read_jacoco if root.tag == "report" else read_cobertura)(root, cov)
    else:
        read_lcov(text, cov)
    return cov


class Coverage:
    """All reports, with each file entry remembered alongside the report it came from."""

    def __init__(self, repo_root):
        self.root = norm(repo_root).rstrip("/").lower() + "/"
        self.entries = []  # (key relative to repo where possible, lowercased; report dir; data)

    def add(self, report_path, cov):
        report_dir = norm(os.path.dirname(os.path.relpath(report_path))).lower()
        for key, data in cov.items():
            k = key.lower()
            if k.startswith(self.root):
                k = k[len(self.root):]
            self.entries.append((k, report_dir, data))

    def lookup(self, rel):
        """Best entry for repo-relative `rel`: exact, then the longest believable suffix match."""
        rel_l = rel.lower()
        best, best_len = None, -1
        for key, report_dir, data in self.entries:
            if key == rel_l:
                return data
            if key.endswith("/" + rel_l):          # report path is longer (e.g. a Go import path)
                score = len(rel_l)
            elif rel_l.endswith("/" + key):        # report path is relative to some sub-project
                prefix = rel_l[: -len(key) - 1]
                # Believe it only if that sub-project is where the report lives.
                if report_dir and not (report_dir + "/").startswith(prefix.split("/")[0] + "/"):
                    continue
                score = len(key)
            else:
                continue
            if score > best_len:
                best, best_len = data, score
        return best


# ── Complexity ───────────────────────────────────────────────────────────────

def functions(lizard, filename, code):
    try:
        info = lizard.analyze_file.analyze_source_code(filename, code)
    except Exception:  # an unparsable file must not crash the gate
        return []
    return info.function_list


def crap(cc, covered):
    return cc * cc * (1 - covered) ** 3 + cc


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--base", required=True)
    ap.add_argument("--report-glob", action="append", default=[])
    ap.add_argument("--fresh-after")
    ap.add_argument("--exempt", action="append", default=[])
    ap.add_argument("--coverage-min", type=float)
    ap.add_argument("--complexity-max", type=int)
    ap.add_argument("--crap-max", type=float)
    ap.add_argument("files", nargs="*")
    args = ap.parse_args()

    repo_root = git("rev-parse", "--show-toplevel").strip()
    os.chdir(repo_root)
    files = [norm(f) for f in args.files if os.path.isfile(f)]
    failed = False

    def say(status, check, text):
        nonlocal failed
        failed = failed or status == "FAIL"
        print(f"{check:<12} {status:<5} {text}")

    # Which reports count: with --fresh-after, only those written by this run's tests;
    # otherwise the newest match of each glob, which must not predate the code it describes.
    cov = Coverage(repo_root)
    reports = []
    fresh_after = os.path.getmtime(args.fresh_after) if args.fresh_after else None
    for pattern in args.report_glob:
        matches = sorted(glob.glob(pattern, recursive=True), key=os.path.getmtime)
        if not matches:
            say("FAIL", "coverage", f"no coverage report matches {pattern} (did the tests write one?)")
            continue
        if fresh_after is not None:
            fresh = [m for m in matches if os.path.getmtime(m) > fresh_after]
            if not fresh:
                say("FAIL", "coverage", f"no report matching {pattern} was written by this test run")
            reports += fresh
        else:
            reports.append(matches[-1])
    for path in reports:
        try:
            cov.add(path, load_report(path))
        except (OSError, ET.ParseError, ValueError, IndexError) as exc:
            say("FAIL", "coverage", f"cannot read coverage report {path}: {exc}")
    if fresh_after is None and reports:
        newest_change = max((os.path.getmtime(f) for f in files), default=0)
        for path in reports:
            if os.path.getmtime(path) < newest_change:
                say("FAIL", "coverage", f"stale report {path}: older than the latest code change; re-run the tests")

    old_path = base_paths(args.base)
    changed = {rel: changed_lines(args.base, rel, old_path.get(rel)) for rel in files}
    exempt = {rel for rel in files if any(fnmatch.fnmatch(rel, g) for g in args.exempt)}
    strict = args.coverage_min is not None or args.crap_max is not None
    file_cov = {rel: cov.lookup(rel) for rel in files} if args.report_glob else {}

    # Diff coverage
    if args.report_glob:
        hit = total = 0
        unmeasured = []
        for rel, lines in changed.items():
            if rel in exempt or not lines:
                continue
            data = file_cov[rel]
            if data is None:
                unmeasured.append(rel)
                if strict:  # no data means the tests never loaded it: count it as untested
                    try:
                        with open(rel, encoding="utf-8", errors="replace") as fh:
                            text = fh.read().splitlines()
                    except OSError:
                        text = []
                    total += sum(1 for n in lines if n <= len(text) and not TRIVIAL.match(text[n - 1]))
                continue
            coverable = [n for n in lines if n in data]
            total += len(coverable)
            hit += sum(1 for n in coverable if data[n] > 0)
        if total:
            pct = 100.0 * hit / total
            text = f"{pct:.1f}% of changed lines covered ({hit}/{total})"
            if args.coverage_min is not None:
                say("FAIL" if pct < args.coverage_min else "PASS", "coverage", f"{text}, min {args.coverage_min:g}%")
            else:
                say("INFO", "coverage", text)
        else:
            say("INFO", "coverage", "no changed coverable lines")
        if unmeasured:
            say("WARN", "coverage", ("in no coverage report, counted as untested: " if strict else
                                     "in no coverage report: ") + short(unmeasured)
                + ("" if not strict else " (exempt them with COVERAGE_EXEMPT_GLOBS if tests cannot reach them)"))

    # Complexity and CRAP
    want_metrics = args.complexity_max is not None or args.crap_max is not None
    try:
        import lizard
    except ImportError:
        if want_metrics:
            say("FAIL", "complexity", "lizard is not installed (pip install lizard); the configured complexity/CRAP checks could not run")
        else:
            say("INFO", "complexity", "lizard not installed: no per-function table (pip install lizard)")
        return 1 if failed else 0

    rows = []
    for rel, lines in changed.items():
        if not lines:
            continue
        with open(rel, encoding="utf-8", errors="replace") as fh:
            current = functions(lizard, rel, fh.read())
        before_long, before_name = {}, {}
        if rel in old_path:
            src = subprocess.run(["git", "show", f"{args.base}:{old_path[rel]}"], capture_output=True,
                                 text=True, encoding="utf-8", errors="replace")
            for f in functions(lizard, old_path[rel], src.stdout) if src.returncode == 0 else []:
                before_long[f.long_name] = f.cyclomatic_complexity
                before_name[f.name] = max(before_name.get(f.name, 0), f.cyclomatic_complexity)
        data = file_cov.get(rel)
        for fn in current:
            span = set(range(fn.start_line, fn.end_line + 1))
            if not span & lines:
                continue
            cc = fn.cyclomatic_complexity
            was = before_long.get(fn.long_name, before_name.get(fn.name))  # a new signature keeps its history
            state = "new" if was is None else "grew" if cc > was else "touched"
            covered = None
            if data is not None:
                coverable = [n for n in span if n in data]
                if coverable:
                    covered = sum(1 for n in coverable if data[n] > 0) / len(coverable)
            elif args.report_glob and strict and rel not in exempt:
                covered = 0.0  # in no report: untested
            score = crap(cc, covered) if covered is not None else None
            rows.append((rel, fn, cc, covered, score, state))

    def judge(check, over):
        offenders = [r for r in rows if over(r)]
        hard = [r for r in offenders if r[5] != "touched"]
        if hard:
            older = len(offenders) - len(hard)
            say("FAIL", check, f"{len(hard)} new or grown function(s) over the limit"
                + (f" (+{older} already over before this change)" if older else ""))
        elif offenders:
            say("WARN", check, f"{len(offenders)} touched function(s) already over the limit before this change, not made worse")
        else:
            say("PASS", check, f"all {len(rows)} touched function(s) within the limit")
        return {id(r) for r in hard}, {id(r) for r in offenders}

    hard, soft = set(), set()
    if args.complexity_max is not None:
        h, s = judge("complexity", lambda r: r[2] > args.complexity_max)
        hard |= h
        soft |= s
    if args.crap_max is not None:
        if not args.report_glob:
            say("FAIL", "crap", "CRAP_MAX is set but no coverage report is configured (COVERAGE_REPORTS)")
        else:
            h, s = judge("crap", lambda r: r[4] is not None and r[4] > args.crap_max)
            hard |= h
            soft |= s

    if rows:
        rows.sort(key=lambda r: (r[4] if r[4] is not None else -1, r[2]), reverse=True)
        print(f"\nTouched functions (worst first, {min(TOP_N, len(rows))} of {len(rows)}):")
        print(f"  {'CRAP':>6} {'CC':>3} {'cov':>5}  {'state':<7} {'verdict':<7} function")
        for row in rows[:TOP_N]:
            rel, fn, cc, covered, score, state = row
            verdict = "FAIL" if id(row) in hard else "WARN" if id(row) in soft else "ok"
            print(f"  {f'{score:.1f}' if score is not None else '-':>6} {cc:>3} "
                  f"{f'{covered:.0%}' if covered is not None else '-':>5}  {state:<7} {verdict:<7} "
                  f"{fn.name} ({rel}:{fn.start_line})")
        new = [f"{r[1].name} ({r[0]})" for r in rows if r[5] == "new"]
        if new:
            print(f"\nNew functions ({len(new)}): " + short(new))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
