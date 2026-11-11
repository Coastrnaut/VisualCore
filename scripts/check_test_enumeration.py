#!/usr/bin/env python3
"""Fail when an xcodebuild test log silently ran fewer tests than the target declares (feature 016 T-A01-507).

On the reference host, an iOS 26.5 simulator run that follows an iOS 27.2 run in the same DerivedData twice skipped
test classes added since the previous 26.5 run, with no skip reported (A01-P04 t409, A01-P05 t507). This guard compares
the XCTest methods declared in the sources (`func test…()` inside `XCTestCase` subclasses) with the test cases that
passed in the log, so a short enumeration is never taken as evidence.

  python3 scripts/check_test_enumeration.py --sources Apps/GenerativeArtStudio/Tests/UI --log <xcodebuild log> [--only Class]
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

CLASS = re.compile(r"^\s*(?:final\s+)?class\s+(\w+)\s*:\s*XCTestCase\b")
METHOD = re.compile(r"^\s*(?:@MainActor\s+)?func\s+(test\w*)\s*\(\s*\)")
PASSED = re.compile(r"Test Case '-\[[\w.]+\.(\w+) (test\w*)\]' passed")


def declared(sources: Path, only: set[str] | None = None) -> set[tuple[str, str]]:
    """(class, method) pairs for XCTest methods in Swift files under `sources`."""
    found: set[tuple[str, str]] = set()
    for path in sorted(sources.rglob("*.swift")):
        current = None
        for line in path.read_text(errors="replace").splitlines():
            if m := CLASS.match(line):
                current = m.group(1)
            elif current and (m := METHOD.match(line)):
                if not only or current in only:
                    found.add((current, m.group(1)))
    return found


def passed(log: Path) -> set[tuple[str, str]]:
    return {(m.group(1), m.group(2)) for m in PASSED.finditer(log.read_text(errors="replace"))}


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--sources", type=Path, required=True)
    ap.add_argument("--log", type=Path, required=True)
    ap.add_argument("--only", nargs="*", help="limit to these test classes")
    a = ap.parse_args(argv)
    if not a.sources.is_dir() or not a.log.is_file():
        print("ERROR: --sources must be a directory and --log a file", file=sys.stderr)
        return 2
    want = declared(a.sources, set(a.only) if a.only else None)
    got = passed(a.log)
    missing = sorted(want - got)
    for cls, name in missing:
        print(f"  NOT RUN or not passed: {cls}.{name}")
    print(f"{'FAIL' if missing or not want else 'PASS'}: {len(want & got)}/{len(want)} declared tests passed in {a.log.name}")
    return 1 if missing or not want else 0


if __name__ == "__main__":
    sys.exit(main())
