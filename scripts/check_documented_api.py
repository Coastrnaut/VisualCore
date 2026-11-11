#!/usr/bin/env python3
"""Documented-API check: every public VisualCore type or free function a consumer references must be named in the
VisualCore documentation (feature 009 T-F803; FR-F806, SC-F802; research R3 in specs/009-second-consumer).

Declarations: `public (final) class|struct|enum|protocol|actor|typealias Name` at any nesting, and unindented
`public func name` (free functions), in Swift sources under --packages. References: whole-word occurrences in the
consumer's Swift sources after stripping comments and string literals. Documentation: package READMEs and feature
contracts (`specs/*/contracts/*.md`). Exit 0 = all documented, 1 = undocumented use (names listed), 2 = usage error.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TYPE_DECL = re.compile(r"^\s*(?:@\w+(?:\([^)]*\))?\s+)*public\s+(?:final\s+)?(?:class|struct|enum|protocol|actor|typealias)\s+([A-Za-z_]\w*)", re.M)
FUNC_DECL = re.compile(r"^(?:@\w+(?:\([^)]*\))?\s+)*public\s+func\s+([A-Za-z_]\w*)", re.M)
SKIP_DIRS = {".build", "Build", "DerivedData", ".swiftpm", "Generated"}


def swift_files(base: Path) -> list[Path]:
    return sorted(p for p in base.rglob("*.swift")
                  if p.name != "Package.swift" and not (SKIP_DIRS & set(p.relative_to(base).parts)))


def strip(text: str) -> str:
    text = re.sub(r"/\*.*?\*/", " ", text, flags=re.S)
    text = re.sub(r'"""[\s\S]*?"""', '""', text)
    text = re.sub(r'"(?:\\.|[^"\\\n])*"', '""', text)
    return re.sub(r"//[^\n]*", " ", text)


def public_names(packages: Path) -> set[str]:
    names: set[str] = set()
    for f in swift_files(packages):
        if "Tests" in f.relative_to(packages).parts:
            continue
        text = f.read_text(errors="replace")
        names.update(TYPE_DECL.findall(text))
        names.update(FUNC_DECL.findall(text))
    return names


def referenced(names: set[str], sources: Path) -> set[str]:
    own: set[str] = set()
    used: set[str] = set()
    for f in swift_files(sources):
        text = strip(f.read_text(errors="replace"))
        own.update(TYPE_DECL.findall(text))
        own.update(re.findall(r"^\s*(?:final\s+)?(?:class|struct|enum|protocol|actor)\s+([A-Za-z_]\w*)", text, re.M))
        for name in names:
            if re.search(rf"\b{re.escape(name)}\b", text):
                used.add(name)
    return used - own   # a consumer's own type of the same name is not a VisualCore use


def documented(names: set[str], docs: list[Path]) -> set[str]:
    corpus = "\n".join(p.read_text(errors="replace") for p in docs)
    return {n for n in names if re.search(rf"\b{re.escape(n)}\b", corpus)}


def default_docs(root: Path) -> list[Path]:
    return sorted(root.glob("Packages/*/README.md")) + sorted(root.glob("specs/*/contracts/*.md"))


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--root", type=Path, default=ROOT)
    ap.add_argument("--sources", type=Path, required=True, help="consumer source directory")
    ap.add_argument("--packages", type=Path, default=Path("Packages"))
    ap.add_argument("--docs", type=Path, nargs="*", help="documentation files (default: package READMEs + feature contracts)")
    args = ap.parse_args(argv)
    root = args.root.resolve()
    sources, packages = root / args.sources, root / args.packages
    if not sources.is_dir() or not packages.is_dir():
        print(f"error: missing {sources if not sources.is_dir() else packages}", file=sys.stderr)
        return 2
    docs = [root / d for d in args.docs] if args.docs else default_docs(root)
    if not docs or any(not d.exists() for d in docs):
        print("error: documentation files missing", file=sys.stderr)
        return 2
    names = public_names(packages)
    used = referenced(names, sources)
    undocumented = sorted(used - documented(used, docs))
    print(f"public VisualCore names: {len(names)}; used by {args.sources}: {len(used)}; documented: {len(used) - len(undocumented)}")
    for n in sorted(used):
        print(f"  {'UNDOCUMENTED' if n in undocumented else 'ok'} {n}")
    if undocumented:
        print(f"FAIL: {len(undocumented)} undocumented VisualCore name(s): {', '.join(undocumented)}")
        return 1
    print("PASS: every VisualCore API the consumer uses is documented")
    return 0


if __name__ == "__main__":
    sys.exit(main())
