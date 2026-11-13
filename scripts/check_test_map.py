#!/usr/bin/env python3
"""Fail when an interface test of a standalone app is lost on its way into the unified app (feature UA-F07 T-U07-002).

The map is a CSV with the header `app,old_class,old_method,new_class,new_method,note`, one row per old test method.
`new_method` may name several methods of `new_class`, separated by `;`. A `new_method` of `-` means "no direct
counterpart": the `note` must then name the covering test as `Class.testMethod`, and that test must exist under
`--new`. The XCTest classes and `func test…()` methods are read exactly the way `check_test_enumeration.py` reads them
(FR-U07-031).

Checks:
  - every old test under `--old` appears exactly once in the map (rows limited to `--app` when given);
  - every mapped old test exists under `--old`;
  - every mapped new test (and every covering test named in a note) exists under `--new`;
  - with `--log`: every mapped new test and covering test passed in at least one of the logs.

  python3 scripts/check_test_map.py --map specs/193-ua-f07-legacy-adoption/test-map.csv \\
      --old Apps/<App>/Tests/UI --new Apps/VisualCore/Tests/UI/<Name> [--log <xcodebuild log>…] [--app <name>…]

The output ends with `PASS: <n> old tests mapped to <m> new tests` (exit 0) or `FAIL: <k> problems` (exit 1).
Bad input (a missing file or directory, a wrong header) exits 2.
"""
from __future__ import annotations

import argparse
import csv
import importlib.util
import re
import sys
from pathlib import Path

HEADER = ["app", "old_class", "old_method", "new_class", "new_method", "note"]
COVERING = re.compile(r"\b(\w+)\.(test\w*)\b")


def _enumeration():
    """The parser of `check_test_enumeration.py`, loaded from this directory so both tools read tests identically."""
    name = "check_test_enumeration"
    if name in sys.modules:
        return sys.modules[name]
    spec = importlib.util.spec_from_file_location(name, Path(__file__).resolve().parent / f"{name}.py")
    mod = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod


def declared_in(dirs: list[Path]) -> set[tuple[str, str]]:
    """(class, method) pairs of the XCTest methods declared under all of `dirs`."""
    enum = _enumeration()
    found: set[tuple[str, str]] = set()
    for d in dirs:
        found |= enum.declared(d)
    return found


def read_map(path: Path) -> list[dict[str, str]]:
    """The map rows; raises ValueError on a wrong header."""
    with path.open(newline="", encoding="utf-8") as f:
        reader = csv.reader(f)
        header = next(reader, None)
        if header is None or [h.strip() for h in header] != HEADER:
            raise ValueError(f"bad header in {path}: expected {','.join(HEADER)}")
        rows = []
        for record in reader:
            if not any(cell.strip() for cell in record):
                continue
            record = (record + [""] * len(HEADER))[: len(HEADER)]
            rows.append({k: v.strip() for k, v in zip(HEADER, record)})
        return rows


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--map", type=Path, required=True)
    ap.add_argument("--old", type=Path, nargs="+", required=True)
    ap.add_argument("--new", type=Path, nargs="+", required=True)
    ap.add_argument("--log", type=Path, nargs="*", default=[])
    ap.add_argument("--app", nargs="*", help="limit the map rows to these apps")
    a = ap.parse_args(argv)

    bad = [str(p) for p in a.old + a.new if not p.is_dir()]
    bad += [str(p) for p in [a.map, *a.log] if not p.is_file()]
    if bad:
        print(f"ERROR: not found: {', '.join(bad)}", file=sys.stderr)
        return 2
    try:
        rows = read_map(a.map)
    except (ValueError, UnicodeDecodeError, csv.Error) as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 2
    if a.app:
        rows = [r for r in rows if r["app"] in set(a.app)]

    old = declared_in(a.old)
    new = declared_in(a.new)
    problems: list[str] = []
    seen: dict[tuple[str, str], int] = {}
    targets: set[tuple[str, str]] = set()

    for r in rows:
        key = (r["old_class"], r["old_method"])
        seen[key] = seen.get(key, 0) + 1
        if key not in old:
            problems.append(f"not an old test: {key[0]}.{key[1]}")
        if r["new_method"] == "-":
            covering = [(m.group(1), m.group(2)) for m in COVERING.finditer(r["note"])]
            if not covering:
                problems.append(f"no counterpart and no covering Class.method in the note: {key[0]}.{key[1]}")
            for c in covering:
                targets.add(c)
                if c not in new:
                    problems.append(f"no such new test: {c[0]}.{c[1]} (named in the note of {key[0]}.{key[1]})")
            continue
        methods = [m.strip() for m in r["new_method"].split(";") if m.strip()]
        if not r["new_class"] or not methods:
            problems.append(f"no new test given for: {key[0]}.{key[1]}")
        for m in methods:
            t = (r["new_class"], m)
            targets.add(t)
            if t not in new:
                problems.append(f"no such new test: {t[0]}.{t[1]}")

    for (cls, name), n in sorted(seen.items()):
        if n > 1:
            problems.append(f"mapped {n} times: {cls}.{name}")
    for cls, name in sorted(old - set(seen)):
        problems.append(f"missing from the map: {cls}.{name}")

    if a.log:
        enum = _enumeration()
        ok: set[tuple[str, str]] = set()
        for log in a.log:
            ok |= enum.passed(log)
        for cls, name in sorted(targets & new - ok):
            problems.append(f"did not pass: {cls}.{name}")

    for p in problems:
        print(f"FAIL: {p}")
    if problems:
        print(f"FAIL: {len(problems)} problems")
        return 1
    print(f"PASS: {len(seen)} old tests mapped to {len(targets)} new tests")
    return 0


if __name__ == "__main__":
    sys.exit(main())
