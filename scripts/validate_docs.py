#!/usr/bin/env python3
"""Validate VisualCore governance and Spec Kit documents (T-F003).

Checks:
  1. `.specify/memory/constitution.md` has no unresolved `[ALL_CAPS]` template tokens and a version line.
  2. Every directory directly under `specs/` is inside the numbering map of ADR-0009 D-11 (001-010 F, 011-185 ANN-P,
     186-200 UKK, 201-234 R02FFF, 301-550 R02GGGFF, rNN-fFF-* RNNFFF and rNN-gGG-FF-* RNNGGGFF for rounds 03-12).
     Every `spec.md` defines requirement/success IDs at most once across ALL features (FR-*, SC-*), and every ID
     has the exact shape of its directory: `F<k>` + two digits, `A<nn>-<p>` + two digits, any other namespace +
     hyphen + three digits (feature 186, FR-U00-001 to FR-U00-005).
  3. Every task ID in `specs/*/tasks.md` has the same exact shape, is unique across features, and every ticked
     task `[X]` carries a `— Verified YYYY-MM-DD:` annotation (Constitution VI).
  4. Every ADR in docs/decisions has a Date and Status line.
  5. Every FR/SC referenced from plan.md/tasks.md/contracts exists in some spec.
  6. Every relative Markdown link in docs/, package READMEs and sample READMEs resolves (feature 010 T-F920).
     `docs/archive/` is excluded: it holds verbatim historical documents whose links refer to their old locations
     (ADR-0009).
Exit 1 on any problem. Standard library only.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEF = re.compile(r"\*\*((?:FR|SC)-[A-Z0-9]+-?\d{3})\*\*")
NAMESPACE = r"(?:F|A\d{2}-|U\d{2}-|R\d{2}[FG]\d{2,4}-)"
REF = re.compile(r"\b((?:FR|SC)-" + NAMESPACE + r"\d{3})\b")
TASK = re.compile(r"^- \[( |x|X)\] (T-[A-Z0-9]+(?:-[A-Z0-9]+)*)(.*)$", re.M)
NUMBERED_DIR = re.compile(r"^(\d{3})-.+")
# Rounds 03-12; shared features 01-99; games 01-25 with features 01-10 (data-model of feature 186, section 1).
ROUND_DIR = re.compile(r"^r(0[3-9]|1[0-2])-(?:f(0[1-9]|[1-9]\d)|g(0[1-9]|1\d|2[0-5])-(0[1-9]|10))-.+")
TOKEN = re.compile(r"\[[A-Z][A-Z0-9_]{2,}\]")
LINK = re.compile(r"\]\(([^)\s]+)\)")
FENCE = re.compile(r"```.*?```", re.S)
LINKED_DOCS = ["docs/**/*.md", "Packages/*/README.md", "Showcase/README.md", "Harnesses/*/README.md"]
UNCHECKED_LINK_DIRS = ("docs/archive/",)


def broken_links(root: Path) -> list[str]:
    """Relative links (outside code fences) whose target file or directory does not exist."""
    problems = []
    for pattern in LINKED_DOCS:
        for doc in sorted(root.glob(pattern)):
            if doc.relative_to(root).as_posix().startswith(UNCHECKED_LINK_DIRS):
                continue
            text = FENCE.sub("", doc.read_text(encoding="utf-8"))
            for target in LINK.findall(text):
                if re.match(r"^[a-z][a-z0-9+.-]*:", target) or target.startswith("#"):
                    continue
                path = target.split("#", 1)[0]
                if path and not (doc.parent / path).exists():
                    problems.append(f"{doc.relative_to(root)}: broken link {target}")
    return problems


def namespace(feature_dir: Path) -> str:
    """Feature numbering (ADR-0004, extended by ADR-0009 D-11).

    001-010 = foundation phases F00-F09 (IDs F<phase>##); 011-185 = app NN phase P, number 10 + (NN-1)*7 + P + 1
    (IDs ANN-<P>##); 186-200 = unified-app features UA-F00..F14 (IDs UKK-###); 201-234 = Round 2 shared features
    (IDs R02FFF-###); 301-550 = Round 2 game features, number 301 + (GG-1)*10 + (FF-1) (IDs R02GGGFF-###);
    rNN-fFF-* and rNN-gGG-FF-* = rounds 3-12 (IDs RNNFFF-### and RNNGGGFF-###). Returns "" for a directory
    outside the map: 000, 235-300, 551 and above, a round outside 03-12, a game outside 01-25, a game feature
    outside 01-10, a game directory without a feature number, and every other name."""
    later = ROUND_DIR.match(feature_dir.name)
    if later:
        rnd, shared, game, feature = later.groups()
        return f"R{rnd}F{shared}" if shared else f"R{rnd}G{game}{feature}"
    numbered = NUMBERED_DIR.match(feature_dir.name)
    if not numbered:
        return ""
    num = int(numbered.group(1))
    if 1 <= num <= 10:
        return f"F{num - 1}"
    if 11 <= num <= 185:
        idx = num - 11
        return f"A{idx // 7 + 1:02d}-{idx % 7}"
    if 186 <= num <= 200:
        return f"U{num - 186:02d}"
    if 201 <= num <= 234:
        return f"R02F{num - 200:02d}"
    if 301 <= num <= 550:
        idx = num - 301
        return f"R02G{idx // 10 + 1:02d}{idx % 10 + 1:02d}"
    return ""


def id_shape(feature_dir: Path) -> re.Pattern | None:
    """The exact shape of the part after `FR-`, `SC-` or `T-` for a feature directory, or None outside the map.

    Foundation and original-app namespaces are followed by two digits (F001, A04-301); every other namespace by a
    hyphen and three digits (U00-001, R02G0101-001). An id whose namespace only begins like the expected one does
    not match."""
    ns = namespace(feature_dir)
    if not ns:
        return None
    return re.compile(re.escape(ns) + (r"\d{2}" if ns[0] in "FA" else r"-\d{3}"))


def feature_dirs(root: Path) -> list[Path]:
    """Every dossier directory of the numbering map under specs/, sorted by name."""
    specs = root / "specs"
    return sorted(f for f in specs.iterdir() if f.is_dir() and namespace(f)) if specs.is_dir() else []


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
    specs = root / "specs"
    for feature in sorted(f for f in specs.iterdir() if f.is_dir()) if specs.is_dir() else []:
        ns, shape = namespace(feature), id_shape(feature)
        if not ns:
            problems.append(f"{feature.relative_to(root)}: feature directory outside the numbering map (ADR-0009 D-11)")
            continue
        spec = feature / "spec.md"
        if spec.exists():
            for ident in DEF.findall(spec.read_text(encoding="utf-8")):
                if not shape.fullmatch(ident.split("-", 1)[1]):
                    problems.append(f"{spec.relative_to(root)}: {ident} outside namespace {ns}")
                if ident in defined:
                    problems.append(f"{ident} defined in {defined[ident]} and {spec.relative_to(root)}")
                defined[ident] = str(spec.relative_to(root))
        tasks_md = feature / "tasks.md"
        if tasks_md.exists():
            text = tasks_md.read_text(encoding="utf-8")
            for mark, ident, rest in TASK.findall(text):
                if not shape.fullmatch(ident.split("-", 1)[1]):
                    problems.append(f"{tasks_md.relative_to(root)}: {ident} outside namespace {ns}")
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
    print(f"{'PASS' if not problems else 'FAIL'}: {len(feature_dirs(ROOT))} feature dossiers checked, {len(problems)} problems")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
