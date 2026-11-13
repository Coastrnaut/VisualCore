#!/usr/bin/env python3
"""Prove that files moved without a changed line (feature 193, UA-F07 T-U07-014 and T-U07-017; FR-U07-001).

  python3 scripts/check_renames.py --base af887e3 [--head HEAD] -- <old path> <new path> ...

Runs `git diff -M --numstat <base> <head> -- <paths>` and passes only when at least one file is listed and every
listed file has 0 added and 0 removed lines (a pure rename). Prints the count, or each file with changed lines.
Exit codes: 0 pass, 1 a changed line or nothing listed, 2 bad input (git failed).
"""
from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def main(argv: list[str] | None = None, root: Path = ROOT) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--base", required=True)
    ap.add_argument("--head", default="HEAD")
    ap.add_argument("paths", nargs="+")
    args = ap.parse_args(argv)
    run = subprocess.run(["git", "diff", "-M", "--numstat", args.base, args.head, "--", *args.paths], cwd=root,
                         capture_output=True, text=True)
    if run.returncode != 0:
        print("ERROR: git diff failed: " + run.stderr.strip(), file=sys.stderr)
        return 2
    lines = [l for l in run.stdout.splitlines() if l.strip()]
    changed = [l for l in lines if not l.startswith("0\t0\t")]
    for line in changed:
        print("FAIL: changed lines: " + line)
    if not lines:
        print("FAIL: no file was moved or changed")
        return 1
    if changed:
        print(f"FAIL: {len(changed)} of {len(lines)} files have changed lines")
        return 1
    print(f"PASS: {len(lines)} files moved without a changed line")
    return 0


if __name__ == "__main__":
    sys.exit(main())
