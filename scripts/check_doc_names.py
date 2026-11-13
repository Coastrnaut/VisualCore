#!/usr/bin/env python3
"""Check that every public name a document cites exists in the VisualCore public API baseline.

Feature R02-F03 (T-R02F03-019, FR-R02F03-062). A cited name is a backticked code span that looks like a public type
or member: ``Type``, ``Type.member`` or either followed by call parentheses, matching
``^[A-Z][A-Za-z0-9]*(\\.[a-z][A-Za-z0-9]*)?(\\(.*\\))?$``. Other spans (paths, file names, numbers, operators,
lower-case words and multi-word snippets) are ignored. Each identifier part of a name (the type, and the member when
present) must occur as a whole word in the baseline file.

Usage::

    python3 scripts/check_doc_names.py DOC [--baseline docs/api/visualcore-public-api.txt]

Exit codes: 0 PASS (every cited name found), 1 FAIL (missing names are printed), 2 unusable input (a missing or
unreadable document or baseline). The last line printed is ``PASS ...`` or ``FAIL ...``. Standard library only.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
DEFAULT_BASELINE = Path("docs/api/visualcore-public-api.txt")

SPAN = re.compile(r"(`+)(.+?)\1", re.DOTALL)
NAME = re.compile(r"^[A-Z][A-Za-z0-9]*(\.[a-z][A-Za-z0-9]*)?(\(.*\))?$")
FILE_SUFFIX = re.compile(r"\.(md|swift|py|json|glsl|txt|ya?ml|csv|sh|xcconfig|plist|h|c|m|metal|html)$")


def cited_names(text: str) -> list[str]:
    """Return the backticked spans of ``text`` that look like public names, in order of first appearance."""
    names: list[str] = []
    for match in SPAN.finditer(text):
        span = match.group(2).strip()
        if "/" in span or FILE_SUFFIX.search(span) or not NAME.match(span):
            continue
        if span not in names:
            names.append(span)
    return names


def identifier_parts(name: str) -> list[str]:
    """Split ``Type.member(args)`` into its identifier parts ``["Type", "member"]``."""
    return name.split("(", 1)[0].split(".")


def missing_parts(names: list[str], baseline_text: str) -> list[tuple[str, str]]:
    """Return ``(name, part)`` for every identifier part that is not a whole word of the baseline."""
    missing = []
    for name in names:
        for part in identifier_parts(name):
            if not re.search(r"(?<![A-Za-z0-9_])" + re.escape(part) + r"(?![A-Za-z0-9_])", baseline_text):
                missing.append((name, part))
    return missing


def _resolve(path: Path) -> Path:
    """Use ``path`` as given when it exists; otherwise resolve a relative path against the repository root."""
    if path.exists() or path.is_absolute():
        return path
    return REPO / path


def main(argv: list[str] | None = None) -> int:
    """Run the check; returns the exit code."""
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("doc", type=Path, help="Markdown document to check")
    parser.add_argument("--baseline", type=Path, default=DEFAULT_BASELINE, help="public API baseline file")
    args = parser.parse_args(argv)

    doc, baseline = _resolve(args.doc), _resolve(args.baseline)
    try:
        doc_text = doc.read_text(encoding="utf-8")
        baseline_text = baseline.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as error:
        print(f"error: {error}", file=sys.stderr)
        print("FAIL unusable input")
        return 2

    names = cited_names(doc_text)
    missing = missing_parts(names, baseline_text)
    for name, part in missing:
        print(f"missing: `{name}` ({part} not in {args.baseline})")
    if missing:
        unknown = sorted({name for name, _ in missing})
        print(f"FAIL {len(unknown)} of {len(names)} cited names not in the public API: {', '.join(unknown)}")
        return 1
    print(f"PASS {len(names)} cited names found in the public API")
    return 0


if __name__ == "__main__":
    sys.exit(main())
