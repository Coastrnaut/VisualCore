#!/usr/bin/env python3
"""Check the performance documents (feature 192 UA-F06, FR-U06-060 to FR-U06-062).

Two rules, for every Markdown file of the directory (default docs/performance):

1. A file that mentions a simulator carries the notice
   "Simulator numbers are development signals, not device performance."
   and a line that gives a simulator number with a unit (ms, s, fps, MB, MiB, %) itself says "signal".
2. Every row of a budget table (a table whose header has the columns Budget, Proposal, Status, Confirmed by)
   has a proposal text, the status `proposal` or `confirmed`, and a confirming measurement: either one that
   names a device (D1, D2 or D3), its scenario and a number of samples, or one that starts with `tooling:` for
   a budget that no device measures (build time and app size). A row with the status `confirmed` must link the measurement (a Markdown link).

The directory must hold at least one budget table. Exit 0 when both rules hold, 1 with file and line otherwise,
2 for a missing directory.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
NOTICE = "Simulator numbers are development signals, not device performance."
COLUMNS = ["budget", "proposal", "status", "confirmed by"]
DEVICE = re.compile(r"\bD[123]\b")
SAMPLES = re.compile(r"\b\d[\d,]*\s+samples\b")
LINK = re.compile(r"\[[^\]]+\]\([^)]+\)")
MEASURE = re.compile(r"\b\d[\d.,]*\s?(ms|s|fps|MB|MiB|%)(?![A-Za-z])")


def cells(line: str) -> list[str]:
    return [c.strip() for c in line.strip().strip("|").split("|")]


def check_file(path: Path, shown: str) -> tuple[list[str], int]:
    """(problems, number of budget rows) of one Markdown file."""
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()
    problems: list[str] = []
    if "simulator" in text.lower() and NOTICE not in text:
        first = next(i for i, l in enumerate(lines, 1) if "simulator" in l.lower())
        problems.append(f"{shown}:{first}: a simulator is mentioned without the notice \"{NOTICE}\"")
    if "simulator" in text.lower():
        for number, line in enumerate(lines, 1):
            lowered = line.lower()
            if "simulator" in lowered and MEASURE.search(line) and "signal" not in lowered:
                problems.append(f"{shown}:{number}: a simulator number is given without calling it a development signal")
    rows = 0
    in_table = False
    for number, line in enumerate(lines, 1):
        if not line.lstrip().startswith("|"):
            in_table = False
            continue
        parts = cells(line)
        if [p.lower() for p in parts] == COLUMNS:
            in_table = True
            continue
        if not in_table or all(set(p) <= set("-: ") for p in parts):
            continue
        rows += 1
        if len(parts) != 4:
            problems.append(f"{shown}:{number}: a budget row has {len(parts)} cells, not 4")
            continue
        budget, proposal, status, confirmed = parts
        if not budget or not proposal:
            problems.append(f"{shown}:{number}: a budget row needs a budget and a proposal")
        if status not in ("proposal", "confirmed"):
            problems.append(f"{shown}:{number}: status '{status}' is neither proposal nor confirmed")
        tooling = confirmed.lower().startswith("tooling:") and len(confirmed) > len("tooling:") + 3
        measured = bool(DEVICE.search(confirmed) and SAMPLES.search(confirmed) and "scenario" in confirmed.lower())
        if not (tooling or measured):
            problems.append(f"{shown}:{number}: '{budget}' lacks its confirming measurement "
                            "(a device D1, D2 or D3 with its scenario and a number of samples, or 'tooling: …')")
        if status == "confirmed" and not LINK.search(confirmed):
            problems.append(f"{shown}:{number}: '{budget}' is confirmed without a link to the measurement")
    return problems, rows


def check(directory: Path, root: Path = ROOT) -> tuple[list[str], int, int]:
    """(problems, files, budget rows) of every Markdown file of `directory`."""
    problems: list[str] = []
    files = rows = 0
    for path in sorted(directory.glob("*.md")):
        try:
            shown = str(path.relative_to(root))
        except ValueError:
            shown = str(path)
        found, count = check_file(path, shown)
        problems += found
        files += 1
        rows += count
    if rows == 0:
        problems.append(f"{directory}: no budget table (columns Budget, Proposal, Status, Confirmed by)")
    return problems, files, rows


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dir", default="docs/performance")
    a = ap.parse_args(argv)
    directory = Path(a.dir) if Path(a.dir).is_absolute() else ROOT / a.dir
    if not directory.is_dir():
        print(f"FAIL: not a directory: {a.dir}")
        return 2
    problems, files, rows = check(directory)
    for p in problems:
        print("  " + p)
    if problems:
        print(f"FAIL: {len(problems)} problems in {files} performance documents")
        return 1
    print(f"PASS: {files} performance documents, {rows} budget rows, each a proposal with its confirming measurement")
    return 0


if __name__ == "__main__":
    sys.exit(main())
