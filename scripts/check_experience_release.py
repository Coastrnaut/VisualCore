#!/usr/bin/env python3
"""Release-document check for one experience of the one app (feature 038 T-A04-614; A04-P06 research D4).

  python3 scripts/check_experience_release.py --config docs/apps/particle-universe/release.json [--root DIR]

The config (schema 1, data-model "Experience release config") names the experience id, the repo-relative
`requiredDocs` and the `checklist` path. Every required document must exist, and every row of the checklist's first
table with a Status column must carry a known status (`verified`, `pending-campaign-ii`, `owner-action`) and
non-empty evidence or owner steps; the checklist rules are those of `check_app_release.py` (`checklist_problems`).
The app-level checks (manifest, tracking, licenses, usage strings) stay in the release check of the one app.

Prints `PASS: experience release <id>, N documents, M checklist rows` and exits 0, or one `PROBLEM: ...` line per
problem and `FAIL: experience release <id>, K problems`, exit 1. Exit 2 on unreadable input.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from check_app_release import checklist_problems  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
SCHEMA = 1


def checklist_rows(text: str) -> int:
    """Data rows of the first markdown table (the header and separator rows are not counted)."""
    rows = [line for line in text.splitlines() if line.startswith("|")]
    return max(len(rows) - 2, 0)


def check(config: dict, root: Path = ROOT) -> tuple[list[str], int, int]:
    """Problems, number of required documents and number of checklist rows for one release config."""
    problems: list[str] = []
    if config.get("schema") != SCHEMA:
        problems.append(f"schema is {config.get('schema')!r}, expected {SCHEMA}")
    docs = config.get("requiredDocs", [])
    if not isinstance(docs, list) or not docs:
        problems.append("requiredDocs is empty or not a list")
        docs = []
    for doc in docs:
        if not (root / doc).is_file():
            problems.append(f"missing document {doc}")
    rows = 0
    checklist = config.get("checklist")
    if not checklist:
        problems.append("no checklist path")
    elif not (root / checklist).is_file():
        problems.append(f"missing checklist {checklist}")
    else:
        text = (root / checklist).read_text(encoding="utf-8")
        rows = checklist_rows(text)
        problems.extend(f"{checklist}: {p}" for p in checklist_problems(text))
    return problems, len(docs), rows


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--config", type=Path, required=True, help="experience release.json (schema 1)")
    ap.add_argument("--root", type=Path, default=ROOT, help="repository root the paths are relative to")
    a = ap.parse_args(argv)
    try:
        config = json.loads(a.config.read_text(encoding="utf-8"))
    except (OSError, ValueError) as e:
        print(f"ERROR: cannot read {a.config}: {e}", file=sys.stderr)
        return 2
    if not isinstance(config, dict):
        print(f"ERROR: {a.config} is not a JSON object", file=sys.stderr)
        return 2
    experience = config.get("experience", "?")
    problems, docs, rows = check(config, a.root)
    if problems:
        for p in problems:
            print("PROBLEM:", p)
        print(f"FAIL: experience release {experience}, {len(problems)} problems")
        return 1
    print(f"PASS: experience release {experience}, {docs} documents, {rows} checklist rows")
    return 0


if __name__ == "__main__":
    sys.exit(main())
