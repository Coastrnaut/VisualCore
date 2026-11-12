#!/usr/bin/env python3
"""App and experience isolation check (feature 019 T-A02-115; FR-A02-106, analyze C1; constitution I and A02
"consumer, not fork"; feature UA-F03 T-U03-012, FR-U03-090 and FR-U03-091).

  python3 scripts/check_app_isolation.py --app Apps/FluidArtPlayground [--built-app path/To.app] [--allow-network]
                                         [--allow-usage KEY ...] [--require-sources]
  python3 scripts/check_app_isolation.py --experiences <folder> [<folder> ...] [--allow-network] [--require-sources]

Every app is a VisualCore consumer: its Swift sources must not import the EGL shim or call EGL (only VisualCore's
audited RenderHost owns the context). Unless `--allow-network` is given (an app with a justified networking need),
the sources must not use networking APIs, and a built app must declare no NS*UsageDescription key unless listed with
`--allow-usage`. `--experiences` checks each folder with the same patterns and also refuses direct GL calls
(`gl…(` and `vcgl…(`); it prints one summary line per folder with the number of test files left out. At least one of
`--app` and `--experiences` is required; both may be given. Sources under `Tests` and `Generated` are not scanned and
comments are ignored. Every problem is one line `  FAIL <file>:<line>: <match>`. A folder that does not exist or
holds no Swift source to scan prints `PASS: <path> — nothing checked (no Swift sources yet)` and passes, unless
`--require-sources` is given (then `FAIL: <path> — no Swift sources found`).
Exit 0 = clean, 1 = violations (or no sources with `--require-sources`), 2 = bad input.
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
    ap.add_argument("--app", type=Path, help="app folder, e.g. Apps/FluidArtPlayground")
    ap.add_argument("--experiences", type=Path, nargs="+", default=[], metavar="FOLDER",
                    help="experience source folders; also refuses direct gl…( and vcgl…( calls")
    ap.add_argument("--built-app", type=Path)
    ap.add_argument("--allow-network", action="store_true")
    ap.add_argument("--allow-usage", nargs="*", default=[])
    ap.add_argument("--require-sources", action="store_true",
                    help="a folder without Swift sources fails instead of passing as 'nothing checked'")
    a = ap.parse_args(argv)
    if a.app is None and not a.experiences:
        print("ERROR: give --app, --experiences or both", file=sys.stderr)
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
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
