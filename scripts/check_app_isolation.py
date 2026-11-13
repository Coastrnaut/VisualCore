#!/usr/bin/env python3
"""App and experience isolation check (feature 019 T-A02-115; FR-A02-106, analyze C1; constitution I and A02
"consumer, not fork"; feature UA-F03 T-U03-012, FR-U03-090 and FR-U03-091; feature UA-F05 T-U05-001, FR-U05-006 and
FR-U05-071).

  python3 scripts/check_app_isolation.py --app Apps/VisualCore [--built-app path/To.app] [--allow-network]
                                         [--allow-usage KEY ...] [--require-sources]
  python3 scripts/check_app_isolation.py --experiences <folder> [<folder> ...] [--allow-network] [--require-sources]
  python3 scripts/check_app_isolation.py --no-direct-storage <path> [<path> ...]
  python3 scripts/check_app_isolation.py --no-crash-on-stored-data <path> [<path> ...]

Every app is a VisualCore consumer: its Swift sources must not import the EGL shim or call EGL (only VisualCore's
audited RenderHost owns the context). Unless `--allow-network` is given (an app with a justified networking need),
the sources must not use networking APIs, and a built app must declare no NS*UsageDescription key unless listed with
`--allow-usage`. `--experiences` checks each folder with the same patterns and also refuses direct GL calls
(`gl…(` and `vcgl…(`); it prints one summary line per folder with the number of test files left out. At least one of
`--app`, `--experiences`, `--no-direct-storage` and `--no-crash-on-stored-data` is required; all may be given
together. Sources under `Tests` and `Generated` are not scanned and
comments are ignored. Every problem is one line `  FAIL <file>:<line>: <match>`. A folder that does not exist or
holds no Swift source to scan prints `PASS: <path> — nothing checked (no Swift sources yet)` and passes, unless
`--require-sources` is given (then `FAIL: <path> — no Swift sources found`).

`--no-direct-storage` and `--no-crash-on-stored-data` take Swift files and folders (a folder is searched recursively
for `*.swift`, test and generated files included). Comments and the text of string literals are not code; the code
inside a string interpolation is. The first refuses the names `UserDefaults`, `FileManager`, `NSHomeDirectory`,
`NSTemporaryDirectory`, `applicationSupportDirectory`, `documentDirectory` and `cachesDirectory` (only the
experience storage may touch the disk and the defaults). The second refuses a deliberate crash in a source that reads
stored data: `try!`, `fatalError(`, `preconditionFailure(`, `precondition(`, `assertionFailure(`, `assert(`, a
forced cast (`as!`) and a forced unwrap (a `!` right after an identifier character, `)` or `]` that is not followed
by `=`; this includes implicitly unwrapped declarations such as `var x: Int!`). Each ends with one line
`PASS: <n> Swift files use no storage directly` / `FAIL: <k> direct uses of storage in <n> Swift files` or
`PASS: <n> Swift files read stored data without a deliberate crash` / `FAIL: <k> deliberate crashes in <n> Swift
files`. A path that does not exist or a folder without a Swift file always fails with
`FAIL: <path> — no Swift sources found`.
Exit 0 = clean, 1 = violations (or no sources with `--require-sources` or for the two storage options), 2 = bad input.
"""
from __future__ import annotations

import argparse
import plistlib
import re
import sys
from pathlib import Path

EGL = [r"\bimport\s+CVisualCoreEGL\b", r"\bimport\s+CVisualCoreGL\b", r"\begl[A-Z]\w*\s*\("]
NETWORK = [r"\bURLSession\b", r"\bNWConnection\b", r"\bNWPathMonitor\b", r"\bimport\s+Network\b", r"\bCFSocket\w*"]


GL = [r"\bvcgl[A-Z]\w*\s*\(", r"\bgl[A-Z]\w*\s*\("]


def strip_comments(text: str) -> str:
    """Removes comments; block comments keep their line breaks so that line numbers stay true."""
    text = re.sub(r"/\*.*?\*/", lambda m: "\n" * m.group(0).count("\n"), text, flags=re.S)
    return re.sub(r"//[^\n]*", "", text)


STORAGE = ["UserDefaults", "FileManager", "NSHomeDirectory", "NSTemporaryDirectory", "applicationSupportDirectory",
           "documentDirectory", "cachesDirectory", "AppStorage", "SceneStorage", "FileHandle", "documentsDirectory",
           "libraryDirectory", "homeDirectory", "temporaryDirectory"]
# Ways to read or write a file that need none of the names above: the pattern and the name a finding carries.
STORAGE_CALLS = [(r"\bData\s*\(\s*contentsOf\b", "Data(contentsOf"), (r"\bString\s*\(\s*contentsOf\b", "String(contentsOf"),
                 (r"\.write\s*\(\s*to\s*:", ".write(to:")]
CRASH_CALLS = ["fatalError", "preconditionFailure", "precondition", "assertionFailure", "assert"]
_STRING_OPEN = re.compile(r'(#*)("""|")')
_BANG = re.compile(r"(?<=[\w)\]])!(?!=)")
_WORD_BEFORE = re.compile(r"\w+\Z")


def code_only(text: str) -> str:
    """The source with comments and the text of string literals replaced by spaces, line breaks kept.

    Understands nested block comments, multi-line strings, raw strings (`#"…"#`) and string interpolation: the
    code inside `\\(…)` stays, the string around it goes. The quotation marks themselves stay.
    """
    out = list(text)
    n = len(text)

    def blank(start: int, end: int) -> None:
        for k in range(start, min(end, n)):
            if out[k] != "\n":
                out[k] = " "

    stack: list[list] = []  # ["interp", open parentheses] or ["str", number of #, is multi-line]
    i = 0
    while i < n:
        top = stack[-1] if stack else None
        if top is None or top[0] == "interp":
            if text.startswith("//", i):
                end = text.find("\n", i)
                end = n if end < 0 else end
                blank(i, end)
                i = end
                continue
            if text.startswith("/*", i):
                depth, j = 1, i + 2
                while j < n and depth:
                    if text.startswith("/*", j):
                        depth, j = depth + 1, j + 2
                    elif text.startswith("*/", j):
                        depth, j = depth - 1, j + 2
                    else:
                        j += 1
                blank(i, j)
                i = j
                continue
            m = _STRING_OPEN.match(text, i)
            if m:
                stack.append(["str", len(m.group(1)), m.group(2) == '"""'])
                i = m.end()
                continue
            if top is not None:
                if text[i] == "(":
                    top[1] += 1
                elif text[i] == ")":
                    top[1] -= 1
                    if top[1] == 0:
                        stack.pop()
                        blank(i, i + 1)
            i += 1
            continue
        hashes, multi = top[1], top[2]
        escape = "\\" + "#" * hashes
        if text.startswith(escape, i):
            j = i + len(escape)
            blank(i, j + 1)
            if j < n and text[j] == "(":
                stack.append(["interp", 1])
            i = j + 1
            continue
        close = ('"""' if multi else '"') + "#" * hashes
        if text.startswith(close, i):
            stack.pop()
            i += len(close)
            continue
        if not multi and text[i] == "\n":  # an unterminated literal ends with its line
            stack.pop()
        blank(i, i + 1)
        i += 1
    return "".join(out)


def swift_files(paths: list[Path]) -> tuple[list[Path], list[Path]]:
    """(the Swift files of `paths`, the paths that give none): a file is taken as it is, a folder recursively."""
    files, empty, seen = [], [], set()
    for path in paths:
        found = sorted(path.rglob("*.swift")) if path.is_dir() else ([path] if path.is_file() else [])
        if not found:
            empty.append(path)
        for f in found:
            if f.resolve() not in seen:
                seen.add(f.resolve())
                files.append(f)
    return files, empty


def storage_uses(text: str) -> list[tuple[int, str]]:
    """Every direct use of storage in Swift source as (1-based line, name), ordered by line and column."""
    code = code_only(text)
    hits = [(m.start(), m.group(0)) for m in re.finditer(r"\b(?:" + "|".join(STORAGE) + r")\b", code)]
    for pattern, name in STORAGE_CALLS:
        hits += [(m.start(), name) for m in re.finditer(pattern, code)]
    return [(code.count("\n", 0, pos) + 1, name) for pos, name in sorted(hits)]


def crash_uses(text: str) -> list[tuple[int, str]]:
    """Every deliberate crash in Swift source as (1-based line, what), ordered by line and column.

    `what` is `try!`, `forced cast` (`as!`), `forced unwrap` or the call with its parenthesis (`fatalError(`).
    """
    code = code_only(text)
    hits = [(m.start(), m.group(1) + "(")
            for m in re.finditer(r"\b(" + "|".join(CRASH_CALLS) + r")\s*\(", code)]
    for m in _BANG.finditer(code):
        word = _WORD_BEFORE.search(code, max(0, m.start() - 8), m.start())
        word = word.group(0) if word else ""
        hits.append((m.start(), {"try": "try!", "as": "forced cast"}.get(word, "forced unwrap")))
    return [(code.count("\n", 0, pos) + 1, what) for pos, what in sorted(hits)]


def check_sources(paths: list[Path], finder, passed: str, failed: str) -> bool:
    """Prints the findings of `finder` in the Swift files of `paths` and the summary line; True when it fails."""
    files, empty = swift_files(paths)
    for path in empty:
        print(f"FAIL: {path} — no Swift sources found")
    count = 0
    for path in files:
        for line, what in finder(path.read_text(encoding="utf-8", errors="replace")):
            print(f"  FAIL {path}:{line}: {what}")
            count += 1
    if files:
        print(f"PASS: {len(files)} Swift files {passed}" if not count
              else f"FAIL: {count} {failed} in {len(files)} Swift files")
    return bool(empty) or bool(count)


def sources(folder: Path, include_tests: bool = False) -> list[Path]:
    """The Swift files that are scanned: everything outside `Generated` and (by default) outside `Tests`."""
    found = []
    if not folder.is_dir():
        return found
    for path in sorted(folder.rglob("*.swift")):
        parts = set(path.relative_to(folder).parts)
        if "Generated" in parts or (not include_tests and "Tests" in parts):
            continue
        found.append(path)
    return found


def test_files(folder: Path) -> list[Path]:
    """The Swift files under a `Tests` folder, which the scan leaves out."""
    if not folder.is_dir():
        return []
    return [p for p in sorted(folder.rglob("*.swift")) if "Tests" in p.relative_to(folder).parts]


def scan_lines(app: Path, allow_network: bool = False, include_tests: bool = False,
               extra_patterns: list[str] | None = None) -> list[tuple[Path, int, str]]:
    """Every match as (file, 1-based line, matched text), ordered by file, line and column."""
    patterns = EGL + ([] if allow_network else NETWORK) + list(extra_patterns or [])
    problems = []
    for path in sources(app, include_tests):
        text = strip_comments(path.read_text(encoding="utf-8", errors="replace"))
        hits = set()
        for pattern in patterns:
            for m in re.finditer(pattern, text):
                hits.add((text.count("\n", 0, m.start()) + 1, m.start(), m.group(0).strip()))
        problems += [(path, line, match) for line, _, match in sorted(hits)]
    return problems


def scan(app: Path, allow_network: bool = False, include_tests: bool = False,
         extra_patterns: list[str] | None = None) -> list[str]:
    """One text `<file>:<line>: <match>` per problem; `extra_patterns` adds patterns (for example `GL`)."""
    return [f"{path}:{line}: {match}"
            for path, line, match in scan_lines(app, allow_network, include_tests, extra_patterns)]


def usage_problems(built: Path, allowed: list[str]) -> list[str]:
    with open(built / "Info.plist", "rb") as f:
        info = plistlib.load(f)
    found = sorted(k for k in info if re.fullmatch(r"NS\w+UsageDescription", k))
    return [f"{built.name}: undeclared usage description {k}" for k in found if k not in allowed]


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--app", type=Path, help="app folder, e.g. Apps/VisualCore")
    ap.add_argument("--experiences", type=Path, nargs="+", default=[], metavar="FOLDER",
                    help="experience source folders; also refuses direct gl…( and vcgl…( calls")
    ap.add_argument("--built-app", type=Path)
    ap.add_argument("--allow-network", action="store_true")
    ap.add_argument("--allow-usage", nargs="*", default=[])
    ap.add_argument("--require-sources", action="store_true",
                    help="a folder without Swift sources fails instead of passing as 'nothing checked'")
    ap.add_argument("--no-direct-storage", type=Path, nargs="+", default=[], metavar="PATH",
                    help="Swift files or folders that must not name UserDefaults, FileManager or a storage folder")
    ap.add_argument("--no-crash-on-stored-data", type=Path, nargs="+", default=[], metavar="PATH",
                    help="Swift files or folders without try!, fatalError, precondition, assert or a forced unwrap")
    a = ap.parse_args(argv)
    if a.app is None and not a.experiences and not a.no_direct_storage and not a.no_crash_on_stored_data:
        print("ERROR: give --app, --experiences, --no-direct-storage or --no-crash-on-stored-data",
              file=sys.stderr)
        return 2
    if a.built_app and (a.app is None or not (a.built_app / "Info.plist").is_file()):
        print("ERROR: --built-app must be a built .app and needs --app", file=sys.stderr)
        return 2
    for folder in ([a.app] if a.app is not None else []) + a.experiences:
        if folder.exists() and not folder.is_dir():
            print(f"ERROR: {folder} is not a folder", file=sys.stderr)
            return 2
    failed = False

    def no_sources(folder: Path) -> bool:
        if a.require_sources:
            print(f"FAIL: {folder} — no Swift sources found")
            return True
        print(f"PASS: {folder} — nothing checked (no Swift sources yet)")
        return False

    if a.app is not None:
        usage = usage_problems(a.built_app, a.allow_usage) if a.built_app else []
        if not sources(a.app):
            for p in usage:
                print(f"  FAIL {p}")
            failed |= no_sources(a.app) or bool(usage)
        else:
            problems = scan(a.app, a.allow_network) + usage
            for p in problems:
                print(f"  FAIL {p}")
            files = sum(1 for p in a.app.rglob("*.swift") if "Tests" not in p.relative_to(a.app).parts)
            print(f"{'PASS' if not problems else 'FAIL'}: {a.app} — {files} app Swift files, "
                  f"{len(problems)} isolation problems")
            failed |= bool(problems)
    for folder in a.experiences:
        files = sources(folder)
        if not files:
            failed |= no_sources(folder)
            continue
        problems = scan(folder, a.allow_network, extra_patterns=GL)
        for p in problems:
            print(f"  FAIL {p}")
        print(f"{'PASS' if not problems else 'FAIL'}: {folder} — {len(files)} Swift files, "
              f"{len(problems)} isolation problems, {len(test_files(folder))} test files left out")
        failed |= bool(problems)
    if a.no_direct_storage:
        failed |= check_sources(a.no_direct_storage, storage_uses, "use no storage directly",
                                "direct uses of storage")
    if a.no_crash_on_stored_data:
        failed |= check_sources(a.no_crash_on_stored_data, crash_uses,
                                "read stored data without a deliberate crash", "deliberate crashes")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
