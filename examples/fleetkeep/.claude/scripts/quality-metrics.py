#!/usr/bin/env python3
"""quality-metrics.py: diff-scoped coverage, complexity and CRAP for the quality gate.

Called by .claude/scripts/quality-gate.sh; it can also be run on its own:

  python3 .claude/scripts/quality-metrics.py --base <sha> [--files-from <list>] [--report-glob <glob>]...
      [--fresh-after <file>] [--exempt <glob>]... [--coverage-min 80]
      [--complexity-max 15] [--crap-max 30] -- file...

With --baseline-out <path> in place of --base, it judges nothing: it writes coverage, complexity
and CRAP for every file given (the whole codebase) to that markdown file.

Judges only what the change touched:
  coverage    share of the changed, coverable lines that the tests ran (diff coverage)
  complexity  cyclomatic complexity of each function the change touched (needs `lizard`)
  CRAP        CC^2 * (1 - cov)^3 + CC per touched function: complex AND untested scores high

Ratchet: a touched function that was already over a limit before the change, and whose
complexity did not grow, is reported as WARN, not FAIL; for CRAP, only while every line the
change touched in it is tested. New code must meet the limits; old code must not get worse.
Renamed files and changed signatures keep their history; a new overload does not.

Several reports of the same file (one per test project) are merged, the highest hit count per
line winning.

When a limit is set, a changed file that no coverage report mentions counts as untested
(many tools leave unrun files out of the report). List files tests cannot reach in --exempt.

Coverage reports read: lcov (lcov.info), Cobertura XML (coverlet, coverage.py `coverage xml`,
many others), JaCoCo XML, and Go cover profiles. Standard library only, except `lizard`
(pip install lizard), which is needed only for complexity and CRAP.

Exit status: 0 = no FAIL, 1 = at least one FAIL (including a configured check that could not run).
"""
import argparse
import difflib
import fnmatch
import glob
import os
import posixpath
import re
import subprocess
import sys
import xml.etree.ElementTree as ET

TOP_N = 15
UNTRACKED_MOVES = set()  # current paths base_paths() paired with a deletion git did not pair
LIST_N = 10
TRIVIAL = re.compile(r"^\s*($|//|#|/\*|\*+(\s|/|$)|--(\s|$)|[{}()\[\];,]+\s*$)")
# Declaration-only rows (see declaration_rows): what may precede a type keyword, a header that
# opens a block no code can run in, lines that only name other code, and an enum member.
MODS = r"((export|declare|default|public|internal|private|protected|abstract|sealed|partial|static|pub(\([^)]*\))?|fun)\s+)*"
TYPE_HEAD = re.compile(r"^\s*" + MODS + r"(?P<kind>(interface|enum(\s+class)?|protocol|trait)\s+(?!class\b)[A-Za-z_]\w*\b(?!\s*[=.(])"  # whole name; "class" is none
                       r"|type\s+\w+(<[^>]*>)?\s*(=|(interface|struct)\b)|declare\s+(module|namespace|global)\b)")
NEUTRAL = re.compile(r"^\s*(import(\s+[\w{*]|\s*[{*\"'])|from\s+[\w.]+\s+import\s|package\s+[\w.]+\s*;?\s*$"
                     r"|(global\s+)?using\s+(static\s+)?[\w.]+(\s*=\s*[\w.<>, ]+)?\s*;\s*$"
                     r"|" + MODS + r"namespace\s+[\w.]+\s*[;{]?\s*$|export\s+(type\s+)?(\*|\{[^}]*\})(\s+from\s+\S+)?\s*;?\s*$|end\s*$)")
ENUM_MEMBER = re.compile(r"^\s*(\[[^\]]*\]\s*)*\w+\s*(=\s*[-\w'\" |&<>+~]+)?\s*,?\s*$")
ENUM_MEMBER_CS = re.compile(r"^\s*(\[[^\]]*\]\s*)*\w+\s*(=\s*[-\w.'\" |&<>+~]+)?\s*,?\s*$")  # C# constants may name others
# a line comment first (a /* inside one opens nothing), and only a /* that begins its
# line opens a block comment (not one in a regex literal, a glob or a mis-read string).
BLOCK = re.compile(r'//[^\n]*|#[^\n]*|"(\\.|[^"\\\n])*"|' + r"'(\\.|[^'\\\n])*'|`[^`]*`|(?<![^\n])[ \t]*/\*.*?(\*/|\Z)", re.S)
ACCESSORS = re.compile(r"\{\s*((get|set|init)\s*;?\s*)+\}")  # C# { get; set; }: no body


# Plain git output whatever the user's config or attributes: prefixes, colour, quoted paths,
# external diffs, merged hunks, a -diff or binary attribute.
GIT = ["git", "-c", "core.quotePath=false", "-c", "color.ui=false", "-c", "color.diff=false",
       "-c", "diff.noprefix=false", "-c", "diff.mnemonicPrefix=false",
       "-c", "diff.srcPrefix=a/", "-c", "diff.dstPrefix=b/", "-c", "diff.interHunkContext=0"]
if os.environ.get("GATE_ATTR_SOURCE"):  # the base commit's .gitattributes, set by the gate
    GIT = [GIT[0], "--attr-source=" + os.environ["GATE_ATTR_SOURCE"], *GIT[1:]]


def git(*args):
    if args and args[0] == "diff":
        args = ("diff", "--no-ext-diff", "--no-textconv", "--text", *args[1:])
    return subprocess.run([*GIT, *args], capture_output=True, text=True,
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
    if rel in UNTRACKED_MOVES:  # git cannot diff an untracked file against the base: compare directly
        before = git("show", f"{base}:{old}").splitlines()
        try:
            with open(rel, encoding="utf-8", errors="replace") as fh:
                now = fh.read().splitlines()
        except OSError:
            return set()
        lines = set()
        for tag, _, _, j1, j2 in difflib.SequenceMatcher(None, before, now, autojunk=False).get_opcodes():
            if tag in ("replace", "insert"):
                lines.update(range(j1 + 1, j2 + 1))
        return lines
    # Name both paths so git pairs a rename; keep only the hunks of the new path.
    diff = git("diff", "-M", "-U0", base, "--", *sorted({old, rel}))
    sections = re.split(r"^diff --git ", diff, flags=re.M)
    diff = next((s for s in sections if re.search(r"^\+\+\+ b/" + re.escape(rel) + r"\t?$", s, re.M)), "")
    # only the "+" lines count, so no context setting (GIT_DIFF_OPTS, diff.context) can
    # add unchanged lines; the hunk header gives each hunk's first new line number.
    lines, n, body = set(), None, False
    for row in diff.split("\n"):
        m = re.match(r"@@ -\S+ \+(\d+)(?:,\d+)? @@", row)
        if m:
            n, body = int(m.group(1)), True
        elif not body or row.startswith("\\"):
            continue  # file headers; "\ No newline at end of file"
        elif row.startswith("+"):
            lines.add(n)
            n += 1
        elif row.startswith(" "):
            n += 1
    return lines


def similar(before, path):
    """True when the file at `path` keeps at least half of `before`, git's own rename threshold."""
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            now = fh.read().splitlines()
    except OSError:
        return False
    return difflib.SequenceMatcher(None, before.splitlines(), now, autojunk=False).ratio() >= 0.5


def base_paths(base):
    """{current path: path at base} for every file that existed at base (renames followed)."""
    mapping, deleted = {}, []
    for raw in git("diff", "-M", "--name-status", base).splitlines():
        parts = raw.split("\t")
        if parts[0].startswith("R") and len(parts) == 3:
            mapping[norm(parts[2])] = norm(parts[1])
        elif parts[0] in ("M", "T") and len(parts) == 2:
            mapping[norm(parts[1])] = norm(parts[1])
        elif parts[0] == "D" and len(parts) == 2:
            deleted.append(norm(parts[1]))
    # A file moved without `git add` (mv, or delete + write) is a deletion plus an untracked file,
    # which git's rename detection never pairs: pair them here, by identical content, else by a
    # file name only one deleted and one untracked file share.
    untracked = [norm(f) for f in git("ls-files", "--others", "--exclude-standard").splitlines()]
    if deleted and untracked:
        blob = {git("rev-parse", f"{base}:{d}").strip(): d for d in deleted}
        left = list(untracked)
        for f in untracked:
            d = blob.get(git("hash-object", "--", f).strip())
            if d and d in deleted:
                mapping[f] = d
                UNTRACKED_MOVES.add(f)
                deleted.remove(d)
                left.remove(f)
        for f in left:
            name = f.rsplit("/", 1)[-1]
            old = [d for d in deleted if d.rsplit("/", 1)[-1] == name]
            if (len(old) == 1 and sum(1 for g in left if g.rsplit("/", 1)[-1] == name) == 1
                    and similar(git("show", f"{base}:{old[0]}"), f)):
                mapping[f] = old[0]
                UNTRACKED_MOVES.add(f)
                deleted.remove(old[0])
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
            cov.setdefault(norm(current), {})  # listed with no lines: measured, nothing to cover
        elif raw.startswith("DA:") and current:
            parts = raw[3:].split(",")
            merge(cov, current, int(parts[0]), int(float(parts[1])))


def exists_near(path, report_dir):
    """`path` names a file, read from the report's folder or a folder above it."""
    d = report_dir
    while True:
        if os.path.isfile(os.path.join(d, path)):
            return True
        parent = os.path.dirname(d)
        if parent == d:
            return False
        d = parent


def read_cobertura(root, cov, report_dir):
    sources = [s.text.strip() for s in root.iter("source") if s.text and s.text.strip()]
    for cls in root.iter("class"):
        filename = cls.get("filename", "")
        lines = cls.find("lines")
        targets = list(dict.fromkeys(os.path.join(src, filename) for src in sources)) or [filename]
        if len(targets) > 1:
            # Several source roots: when one of them holds the file, the class is that file; when
            # two do (models.py in two apps), it cannot be told apart and counts for neither. When
            # none is found here (a container or CI path), each is left to the path resolution.
            here = [t for t in targets if exists_near(t, report_dir)]
            if len(here) > 1:
                continue
            targets = here or targets
        for target in targets:
            cov.setdefault(norm(target), {})  # listed with no lines: measured, nothing to cover
        for line in (lines.iter("line") if lines is not None else ()):
            for target in targets:
                merge(cov, target, int(line.get("number")), int(float(line.get("hits", "0"))))


def read_jacoco(root, cov):
    for pkg in root.iter("package"):
        for sf in pkg.iter("sourcefile"):
            name = pkg.get("name", "")
            path = f"{name}/{sf.get('name', '')}" if name else sf.get("name", "")  # default package
            cov.setdefault(norm(path), {})  # listed with no lines: measured, nothing to cover
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
    with open(path, encoding="utf-8-sig", errors="replace") as fh:  # coverlet writes a BOM
        text = fh.read()
    if text.lstrip().startswith("mode:"):
        read_go(text, cov)
    elif text.lstrip().startswith("<"):
        root = ET.fromstring(text)
        if root.tag == "report":
            read_jacoco(root, cov)
        else:
            read_cobertura(root, cov, os.path.dirname(path))
    else:
        read_lcov(text, cov)
    return cov


class Coverage:
    """All reports. Each file entry in a report is credited to at most one file in the repo: the
    one it names, read relative to the report's folder or a folder above it, else the only repo
    file whose path it can be. An entry no file can be told apart for counts for none."""

    def __init__(self, repo_root):
        self.root = norm(repo_root).rstrip("/").lower() + "/"
        self.entries = []  # (key relative to repo where possible, lowercased; report dir, lowercased; data)
        self.by_file = None

    def add(self, report_path, cov):
        report_dir = norm(os.path.dirname(os.path.relpath(report_path))).lower()
        if report_dir == ".":
            report_dir = ""
        for key, data in cov.items():
            k = key.lower()
            if k.startswith(self.root):
                k = k[len(self.root):]
            self.entries.append((k, report_dir, data))
        self.by_file = None

    def resolve(self, key, report_dir, files, by_base):
        parts = report_dir.split("/") if report_dir else []
        if key.startswith("../") or "/../" in key:  # relative to the report's project (istanbul)
            for i in range(len(parts), -1, -1):
                path = posixpath.normpath("/".join(parts[:i] + [key]))
                if path in files:
                    return path
            if key.startswith("../"):
                return None
            key = posixpath.normpath(key)  # web/../shared/x.ts, or an absolute path with ".."
        for i in range(len(parts), -1, -1):  # the report's folder first, the repo root last
            path = "/".join(parts[:i] + [key])
            if path in files:
                return path
        same_base = by_base.get(key.rsplit("/", 1)[-1], [])
        # A key relative to some sub-project names the one repo file that ends with it.
        ending = [f for f in same_base if f.endswith("/" + key)]
        if ending:
            return ending[0] if len(ending) == 1 else None
        # A longer key (an absolute or CI path, a Go import path) names its longest repo suffix.
        longer = sorted((f for f in same_base if key.endswith("/" + f)), key=len, reverse=True)
        if longer and (len(longer) == 1 or len(longer[0]) > len(longer[1])):
            return longer[0]
        return None

    def lookup(self, rel):
        """Line hits for repo-relative `rel`, merged over every report entry credited to it.
        Several test projects often each report the same shared file, every one with only the
        lines its own tests ran."""
        if self.by_file is None:
            listed = git("ls-files", "--cached", "--others", "--exclude-standard").splitlines()
            files = {norm(f).lower() for f in listed}
            by_base = {}
            for f in files:
                by_base.setdefault(f.rsplit("/", 1)[-1], []).append(f)
            self.by_file = {}
            for key, report_dir, data in self.entries:
                target = self.resolve(key, report_dir, files, by_base)
                if target is not None:
                    self.by_file.setdefault(target, []).append(data)
        found = self.by_file.get(rel.lower())
        return merged(found) if found else None


def merged(datas):
    if len(datas) == 1:
        return datas[0]
    out = {}
    for data in datas:
        for line, hits in data.items():
            out[line] = max(out.get(line, 0), hits)
    return out


# ── Complexity ───────────────────────────────────────────────────────────────

def functions(lizard, filename, code):
    try:
        info = lizard.analyze_file.analyze_source_code(filename, code)
    except Exception:  # an unparsable file must not crash the gate
        return []
    return [f for f in info.function_list if f.name != "*global*"]  # lizard's code-outside-functions bucket


def scrub(row):
    """The row without string literals, comments, and balanced (...) / <...> groups."""
    row = re.sub(r'"(\\.|[^"\\])*"|' + r"'(\\.|[^'\\])*'|`[^`]*`", '""', row)
    row = re.sub(r"//.*|/\*.*?\*/|#.*", "", row)
    prev = None
    while prev != row:
        prev, row = row, re.sub(r"\([^()]*\)|<[^<>=]*>", "", row)
    return row


def declaration_rows(rows, nested_ok=False, cs=False, blocks=True):
    """The 1-based rows that cannot run: import/using/package lines and the inside of interface,
    enum, Go struct, protocol, trait, type-alias and ambient `declare` blocks. A brace block
    inside one (a getter or a default body) is code, unless nested_ok (TS and Go types). Anything
    else, a class body included, is code: this lists what is safe, not what runs."""
    ok, depth, kind, code_at, pending = set(), 0, None, None, None
    nl = chr(10)
    # A /* ... */ comment, across lines too, is blanked (its newlines kept); strings are skipped over.
    text, cut = nl.join(rows), []

    def blank(m):
        s = m.group(0)
        if not blocks or not s.lstrip(" \t").startswith("/*"):
            return s
        if not s.endswith("*/"):  # never closed: no row from it on is safe
            cut.append(text.count(nl, 0, m.start()) + 1)
        return re.sub(r"[^\n]", " ", s)
    rows = BLOCK.sub(blank, text).split(nl)
    for i, raw in enumerate(rows, 1):
        row = scrub(raw)
        if depth == 0:
            if pending and row.strip() == "{":  # Allman: the header's brace on its own line
                kind, pending, depth, code_at = pending, None, 1, None
                ok.add(i)
                continue
            if row.strip():
                pending = None
            if TRIVIAL.match(raw) or (NEUTRAL.match(raw) and not re.search(r";\s*\S", row)):
                ok.add(i)  # an import line, but not "import os; run()"
                continue
            m = TYPE_HEAD.match(raw)
            if not m:
                continue
            kind = "enum" if m.group("kind").startswith("enum") else "type"
            depth = row.count("{") - row.count("}")
            rest = row.split("{", 1)[1] if "{" in row else ""
            if depth < 0 or (depth == 0 and "{" in row and rest.rsplit("}", 1)[-1].strip(" ;,")):
                depth = 0  # something follows the block on its line
                continue
            if depth == 0 and re.search(r"=(?!>)", re.sub(r"^[^=]*=", "", row, count=1)):
                continue  # type T = ... with a second "=": not a plain alias
            ok.add(i)
            code_at = None
            if "{" not in row and "=" not in row and not row.rstrip().endswith(";"):
                pending = kind  # the block may open on the next line
            continue
        member = ACCESSORS.sub("", row)
        d = member.count("{") - member.count("}")
        if "{" in member and d == 0 and not nested_ok:
            continue  # a one-line body (static { }, init { }, get() { }): may run
        if depth + d <= 0:
            depth = 0
            if row.strip().strip("};,") == "" and code_at is None:
                ok.add(i)
            continue
        if code_at is None and d > 0 and not nested_ok:
            code_at = depth  # a body opens: this row and everything until it closes may run
        depth += d
        if code_at is not None:
            if depth <= code_at:
                code_at = None
            continue
        if kind == "enum":
            if "(" not in raw and ((ENUM_MEMBER_CS if cs else ENUM_MEMBER).match(row) or TRIVIAL.match(raw)):
                ok.add(i)
        elif not re.search(r"=(?!>)" if nested_ok else "=", row):  # TS/Go: a function type's => is no code
            ok.add(i)
    return {i for i in ok if i < cut[0]} if cut else ok


def declarations_only(rel, lines):
    """Every changed line of `rel` is a declaration_rows row, and lizard reads the file and finds
    no function in it: an interface, enum or type a test cannot run. An unknown language or a
    parse error is not this."""
    try:
        with open(rel, encoding="utf-8", errors="replace") as fh:
            text = fh.read()
    except OSError:
        return False
    rows = text.splitlines()
    safe = declaration_rows(rows, rel.endswith((".ts", ".tsx", ".mts", ".cts", ".go")), rel.endswith(".cs"),
                            not rel.endswith((".py", ".pyi", ".rb")))  # no /* comments there
    if any(n not in safe for n in lines if n <= len(rows)):
        return False
    try:
        import lizard
    except ImportError:
        return False
    if lizard.get_reader_for(rel) is None:
        return False
    try:
        info = lizard.analyze_file.analyze_source_code(rel, text)
    except Exception:
        return False
    return not [f for f in info.function_list if f.name != "*global*"]


def function_history(before, current):
    """{id(current function): its complexity at the base}, for the functions that existed there.

    Matched by signature. lizard leaves the class out of a method's signature, and names every
    anonymous function alike, so a signature that occurs more than once is paired in file order,
    and only when it occurs as often at the base as now; otherwise those functions count as new.
    A changed signature keeps its history only when it is the one function of its name on both
    sides, so a new overload is new code, not an old function touched."""
    by_long, now_long = {}, {}
    for f in before:
        by_long.setdefault(f.long_name, []).append(f)
    for f in current:
        now_long.setdefault(f.long_name, []).append(f)
    history = {}
    for long_name, now in now_long.items():
        old = by_long.get(long_name, [])
        if len(old) == len(now):
            for o, n in zip(old, now):
                history[id(n)] = o.cyclomatic_complexity
    by_name, now_name = {}, {}
    for f in before:
        by_name.setdefault(f.name, []).append(f)
    for f in current:
        now_name.setdefault(f.name, []).append(f)
    for name, now in now_name.items():
        old = by_name.get(name, [])
        if (len(old) == 1 and len(now) == 1 and id(now[0]) not in history
                and old[0].long_name not in now_long and "anonymous" not in name):
            history[id(now[0])] = old[0].cyclomatic_complexity
    return history


def crap(cc, covered):
    return cc * cc * (1 - covered) ** 3 + cc


def load_coverage(args, repo_root, say):
    """The reports that count: with --fresh-after, only those this run's tests wrote; otherwise
    the newest match of each glob. Returns (Coverage, report paths)."""
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
            if len(matches) > 1:
                say("WARN", "coverage", f"{pattern} matches {len(matches)} reports; with no gate test run only the "
                    f"newest ({matches[-1]}) is read. Set GATE_TEST_CMD so every report its run writes counts")
    for path in reports:
        try:
            data = load_report(path)
        except (OSError, ET.ParseError, ValueError, IndexError) as exc:
            say("FAIL", "coverage", f"cannot read coverage report {path}: {exc}")
            continue
        if not data:
            say("WARN", "coverage", f"report {path} lists no files (unrecognised format, or nothing was measured)")
        cov.add(path, data)
    return cov, reports


def write_baseline(args, files, cov, notes):
    """Whole-codebase snapshot: never a verdict, only numbers to choose limits and see the trend."""
    try:
        import lizard
    except ImportError:
        lizard = None
    measured = bool(cov.entries)  # configured but nothing loaded is "not measured", never 0%
    rows, unmeasured = [], []
    hit = total = 0
    for rel in files:
        exempt = any(fnmatch.fnmatch(rel, g) for g in args.exempt)
        data = cov.lookup(rel) if measured else None
        with open(rel, encoding="utf-8", errors="replace") as fh:
            code = fh.read()
        if measured and data is None and not exempt:
            unmeasured.append(rel)  # the tests never loaded it: its lines count as untested
            total += sum(1 for line in code.splitlines() if not TRIVIAL.match(line))
        if data is not None and not exempt:
            total += len(data)
            hit += sum(1 for h in data.values() if h > 0)
        if lizard is None:
            continue
        found = functions(lizard, rel, code)
        for fn in found:
            covered = None
            if data is not None:
                coverable = [n for n in range(fn.start_line, fn.end_line + 1) if n in data]
                if coverable:
                    covered = sum(1 for n in coverable if data[n] > 0) / len(coverable)
            elif measured and not exempt:
                covered = 0.0  # in no report: untested, as the gate counts it
            cc = fn.cyclomatic_complexity
            rows.append((rel, fn, cc, covered, crap(cc, covered) if covered is not None else None))

    if measured:
        coverage_gap = "no coverable lines"
    elif args.report_glob:
        coverage_gap = "not measured: no coverage report loaded (see Notes; fix the report path or the tests)"
    else:
        coverage_gap = "not measured (COVERAGE_REPORTS not set)"
    head = git("log", "-1", "--format=%h %cs").split() or ["-", "-"]
    branch = git("rev-parse", "--abbrev-ref", "HEAD").strip()
    pct = lambda n, d: f"{100.0 * n / d:.1f}%" if d else "-"
    out = ["# Quality baseline", "",
           f"Measured on `{branch}` at `{head[0]}` (committed {head[1]}) by `.claude/scripts/quality-gate.sh --baseline`.",
           "",
           "A snapshot of the whole codebase. No gate reads it and nothing here fails a change: the",
           "gate judges only the code a change touches, so these numbers show how much old code a",
           "change may meet, not what it must fix. Re-run it to see the trend.", "",
           "| Measure | Value |", "|---|---|",
           f"| Source files | {len(files)} (test files excluded) |",
           f"| Tests | {args.tests or 'not run'} |",
           f"| Line coverage | {pct(hit, total) + f' ({hit}/{total} lines)' if total else coverage_gap} |"]
    if lizard is None:
        out += ["", "Complexity and CRAP not measured: `pip install lizard`."]
    else:
        out.append(f"| Functions | {len(rows)} |")
        if args.complexity_max is not None:
            n = sum(1 for r in rows if r[2] > args.complexity_max)
            out.append(f"| Over COMPLEXITY_MAX ({args.complexity_max}) | {n} ({pct(n, len(rows))}) |")
        if args.crap_max is not None and measured:
            n = sum(1 for r in rows if r[4] is not None and r[4] > args.crap_max)
            out.append(f"| Over CRAP_MAX ({args.crap_max:g}) | {n} ({pct(n, len(rows))}) |")
        buckets = [("1-5", 1, 5), ("6-10", 6, 10), ("11-15", 11, 15), ("16-20", 16, 20), ("21+", 21, 10 ** 9)]
        out += ["", "## Complexity spread", "", "| Cyclomatic complexity | Functions |", "|---|---|"]
        out += [f"| {label} | {sum(1 for r in rows if lo <= r[2] <= hi)} |" for label, lo, hi in buckets]
        worst = sorted(rows, key=lambda r: (r[4] if r[4] is not None else -1, r[2]), reverse=True)[:20]
        if worst:
            out += ["", "## Worst 20 functions", "", "| CRAP | CC | Coverage | Function |", "|---|---|---|---|"]
            for rel, fn, cc, covered, score in worst:
                out.append(f"| {f'{score:.1f}' if score is not None else '-'} | {cc} | "
                           f"{f'{covered:.0%}' if covered is not None else '-'} | `{fn.name}` ({rel}:{fn.start_line}) |")
    if unmeasured:
        out += ["", f"## In no coverage report ({len(unmeasured)})", "",
                "Counted as untested above. Exempt the ones tests cannot reach with `COVERAGE_EXEMPT_GLOBS`.", ""]
        out += [f"- {rel}" for rel in unmeasured[:50]]
        if len(unmeasured) > 50:
            out.append(f"- ... and {len(unmeasured) - 50} more")
    if notes:
        out += ["", "## Notes", ""] + [f"- {n}" for n in notes]
    os.makedirs(os.path.dirname(args.baseline_out) or ".", exist_ok=True)
    with open(args.baseline_out, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(out) + "\n")
    print("\n".join(out))
    print(f"\nBaseline written to {args.baseline_out}")


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--base")
    ap.add_argument("--baseline-out", help="write a whole-codebase snapshot here instead of judging a change")
    ap.add_argument("--tests", help="the baseline run's test result, for the report")
    ap.add_argument("--files-from", help="read the file list from this file, one path per line")
    ap.add_argument("--tests-from", help="the change's test files, one per line: a report older than them is stale")
    ap.add_argument("--report-glob", action="append", default=[])
    ap.add_argument("--fresh-after")
    ap.add_argument("--exempt", action="append", default=[])
    ap.add_argument("--coverage-min", type=float)
    ap.add_argument("--complexity-max", type=int)
    ap.add_argument("--crap-max", type=float)
    ap.add_argument("files", nargs="*")
    args = ap.parse_args()
    if not args.base and not args.baseline_out:
        ap.error("--base is required (or --baseline-out)")

    repo_root = git("rev-parse", "--show-toplevel").strip()
    os.chdir(repo_root)
    if args.files_from:
        with open(args.files_from, encoding="utf-8", errors="replace") as fh:
            args.files += [line.rstrip("\r\n") for line in fh if line.strip()]
    files = [norm(f) for f in args.files if os.path.isfile(f)]
    failed = False

    if args.baseline_out:
        notes = []
        cov, _ = load_coverage(args, repo_root, lambda status, check, text: notes.append(text))
        write_baseline(args, files, cov, notes)
        return 0

    def say(status, check, text):
        nonlocal failed
        failed = failed or status == "FAIL"
        print(f"{check:<12} {status:<5} {text}")

    cov, reports = load_coverage(args, repo_root, say)
    fresh_after = os.path.getmtime(args.fresh_after) if args.fresh_after else None
    if fresh_after is None and reports and files:
        tests = []
        if args.tests_from:
            with open(args.tests_from, encoding="utf-8", errors="replace") as fh:
                tests = [norm(line.strip()) for line in fh if line.strip()]
        newest_change = max((os.path.getmtime(f) for f in files + tests if os.path.isfile(f)), default=0)
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
        declarations = []
        for rel, lines in changed.items():
            if rel in exempt or not lines:
                continue
            data = file_cov[rel]
            if data is None:
                if strict and declarations_only(rel, lines):  # e.g. a type-only module the tests never load
                    declarations.append(rel)
                    continue
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
                + ("" if not strict else " (if tests cannot reach them, exempt them with COVERAGE_EXEMPT_GLOBS; a new"
                   " exemption counts once merged, so land that hooks.env change on its own first)"))
        if declarations:
            say("WARN", "coverage", "in no coverage report, declarations only (interface, enum, type or import lines, no function), not counted: " + short(declarations))
    elif args.coverage_min is not None:
        say("FAIL", "coverage", "COVERAGE_MIN is set but no coverage report is configured (COVERAGE_REPORTS)")

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
        before = []
        if rel in old_path:
            src = subprocess.run([*GIT, "show", f"{args.base}:{old_path[rel]}"], capture_output=True,
                                 text=True, encoding="utf-8", errors="replace")
            before = functions(lizard, old_path[rel], src.stdout) if src.returncode == 0 else []
        history = function_history(before, current)
        data = file_cov.get(rel)
        for fn in current:
            span = set(range(fn.start_line, fn.end_line + 1))
            if not span & lines:
                continue
            cc = fn.cyclomatic_complexity
            was = history.get(id(fn))
            state = "new" if was is None else "grew" if cc > was else "touched"
            covered = None
            # Changed lines the tests did not run: a touched function over CRAP_MAX may keep its
            # old score only while every line the change touched in it is tested.
            untested_change = False
            if rel in exempt:
                pass  # exempt from coverage, so from CRAP too, whether or not a report lists it
            elif data is not None:
                coverable = [n for n in span if n in data]
                if coverable:
                    covered = sum(1 for n in coverable if data[n] > 0) / len(coverable)
                untested_change = any(n in data and data[n] == 0 for n in span & lines)
            elif args.report_glob and strict:
                covered = 0.0  # in no report: untested
                untested_change = True
            score = crap(cc, covered) if covered is not None else None
            rows.append((rel, fn, cc, covered, score, state, untested_change))

    def judge(check, over, excused):
        offenders = [r for r in rows if over(r)]
        hard = [r for r in offenders if not excused(r)]
        if hard:
            older = len(offenders) - len(hard)
            say("FAIL", check, f"{len(hard)} function(s) over the limit: {reason[check]}"
                + (f" (+{older} more excused by the ratchet)" if older else ""))
        elif offenders:
            say("WARN", check, f"{len(offenders)} touched function(s) over the limit, excused by the ratchet: "
                + ("complexity did not grow and every changed line in them is tested (their coverage before "
                   "this change is not measured)" if check == "crap" else "complexity did not grow"))
        else:
            say("PASS", check, f"all {len(rows)} touched function(s) within the limit")
        return {id(r) for r in hard}, {id(r) for r in offenders}

    reason = {"complexity": "new, or more complex than before",
              "crap": "new, more complex than before, or with changed lines the tests do not run"}
    hard, soft = set(), set()
    if args.complexity_max is not None:
        h, s = judge("complexity", lambda r: r[2] > args.complexity_max, lambda r: r[5] == "touched")
        hard |= h
        soft |= s
    if args.crap_max is not None:
        if not args.report_glob:
            say("FAIL", "crap", "CRAP_MAX is set but no coverage report is configured (COVERAGE_REPORTS)")
        else:
            h, s = judge("crap", lambda r: r[4] is not None and r[4] > args.crap_max,
                         lambda r: r[5] == "touched" and not r[6])
            hard |= h
            soft |= s

    if rows:
        rows.sort(key=lambda r: (r[4] if r[4] is not None else -1, r[2]), reverse=True)
        print(f"\nTouched functions (worst first, {min(TOP_N, len(rows))} of {len(rows)}):")
        print(f"  {'CRAP':>6} {'CC':>3} {'cov':>5}  {'state':<7} {'verdict':<7} function")
        for row in rows[:TOP_N]:
            rel, fn, cc, covered, score, state, _ = row
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
