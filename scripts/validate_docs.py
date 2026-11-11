#!/usr/bin/env python3
"""Validate VisualCore governance and Spec Kit documents (T-F003).

Checks:
  1. `.specify/memory/constitution.md` has no unresolved `[ALL_CAPS]` template tokens and a version line.
  2. Every `specs/*/spec.md` defines requirement/success IDs at most once across ALL features
     (FR-*, SC-*), and every ID is in its feature's namespace (001 → F, 0NN app → ANN).
  3. Every task ID in `specs/*/tasks.md` is unique across features and every ticked task `[X]`
     carries a `— Verified YYYY-MM-DD:` annotation (Constitution VI).
  4. Every ADR in docs/decisions has a Date and Status line.
  5. Every FR/SC referenced from plan.md/tasks.md/contracts exists in some spec.
  6. Every relative Markdown link in docs/, package READMEs and sample READMEs resolves (feature 010 T-F920).
Exit 1 on any problem. Standard library only.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEF = re.compile(r"\*\*((?:FR|SC)-[A-Z0-9]+-?\d{3})\*\*")
REF = re.compile(r"\b((?:FR|SC)-(?:F|A\d{2}-)\d{3})\b")
TASK = re.compile(r"^- \[( |x|X)\] (T-(?:F|A\d{2}-)\d{3})\b(.*)$", re.M)
TOKEN = re.compile(r"\[[A-Z][A-Z0-9_]{2,}\]")
LINK = re.compile(r"\]\(([^)\s]+)\)")
FENCE = re.compile(r"```.*?```", re.S)
LINKED_DOCS = ["docs/**/*.md", "Packages/*/README.md", "Showcase/README.md", "Harnesses/*/README.md"]


def broken_links(root: Path) -> list[str]:
    """Relative links (outside code fences) whose target file or directory does not exist."""
    problems = []
    for pattern in LINKED_DOCS:
        for doc in sorted(root.glob(pattern)):
            text = FENCE.sub("", doc.read_text(encoding="utf-8"))
            for target in LINK.findall(text):
                if re.match(r"^[a-z][a-z0-9+.-]*:", target) or target.startswith("#"):
                    continue
                path = target.split("#", 1)[0]
                if path and not (doc.parent / path).exists():
                    problems.append(f"{doc.relative_to(root)}: broken link {target}")
    return problems


def namespace(feature_dir: Path) -> str:
    """Feature numbering (ADR-0004): 001-010 = foundation phases F00-F09 (IDs F<phase>##);
    011-185 = app NN phase P, number 10 + (NN-1)*7 + P + 1 (IDs ANN-<P>##)."""
    num = int(feature_dir.name.split("-", 1)[0])
    if num <= 10:
        return f"F{num - 1}"
    idx = num - 11
    return f"A{idx // 7 + 1:02d}-{idx % 7}"


def validate(root: Path = ROOT) -> list[str]:
    problems: list[str] = []
    const = root / ".specify" / "memory" / "constitution.md"
    if const.exists():
        text = const.read_text(encoding="utf-8")
        body = re.sub(r"<!--.*?-->", "", text, flags=re.S)
        for tok in TOKEN.findall(body):
            problems.append(f"constitution: unresolved token {tok}")
        if not re.search(r"\*\*Version\*\*: \d+\.\d+\.\d+", text):
            problems.append("constitution: missing version line")
    else:
        problems.append("constitution missing")
    defined: dict[str, str] = {}
    tasks: dict[str, str] = {}
    referenced: list[tuple[str, str]] = []
    for feature in sorted((root / "specs").glob("[0-9][0-9][0-9]-*")):
        ns = namespace(feature)
        spec = feature / "spec.md"
        if spec.exists():
            for ident in DEF.findall(spec.read_text(encoding="utf-8")):
                if not ident.split("-", 1)[1].startswith(ns):
                    problems.append(f"{spec.relative_to(root)}: {ident} outside namespace {ns}")
                if ident in defined:
                    problems.append(f"{ident} defined in {defined[ident]} and {spec.relative_to(root)}")
                defined[ident] = str(spec.relative_to(root))
        tasks_md = feature / "tasks.md"
        if tasks_md.exists():
            text = tasks_md.read_text(encoding="utf-8")
            for mark, ident, rest in TASK.findall(text):
                if ident in tasks:
                    problems.append(f"task {ident} duplicated ({tasks[ident]})")
                tasks[ident] = str(tasks_md.relative_to(root))
                if mark in "xX" and not re.search(r"— Verified \d{4}-\d{2}-\d{2}:", rest):
                    problems.append(f"{ident} ticked without '— Verified YYYY-MM-DD:' annotation")
        for doc in [feature / "plan.md", tasks_md, *sorted((feature / "contracts").glob("*.md"))]:
            if doc.exists():
                referenced += [(r, str(doc.relative_to(root))) for r in REF.findall(doc.read_text(encoding="utf-8"))]
    for ref, where in referenced:
        if ref not in defined:
            problems.append(f"{where}: reference to undefined {ref}")
    for adr in sorted((root / "docs" / "decisions").glob("ADR-*.md")):
        text = adr.read_text(encoding="utf-8")
        if not re.search(r"\*\*Date:\*\* \d{4}-\d{2}-\d{2}", text) or "**Status:**" not in text:
            problems.append(f"{adr.name}: missing Date/Status")
    problems += broken_links(root)
    return problems


def main() -> int:
    problems = validate()
    for p in problems:
        print("PROBLEM:", p)
    specs = len(list((ROOT / "specs").glob("[0-9][0-9][0-9]-*")))
    print(f"{'PASS' if not problems else 'FAIL'}: {specs} feature dossiers checked, {len(problems)} problems")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
