#!/usr/bin/env python3
"""License/notice check (feature 010 T-F907; FR-F909). Finds every binary target and external package dependency in
Package.swift files and XcodeGen specs, and requires each to map to an entry in docs/legal/third-party.json whose license
is allowed (LGPL only for harness scope) and whose license text file exists. Exit 0 ok, 1 unknown/unlicensed, 2 usage.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BINARY = re.compile(r'\.binaryTarget\(\s*name:\s*"([^"]+)"')
REMOTE = re.compile(r'\.package\(\s*url:\s*"([^"]+)"')
LOCAL = re.compile(r'\.package\(\s*path:\s*"([^"]+)"')
SPEC_PKG = re.compile(r"^  (\w+):\s*\n\s+(?:path|url):\s*(\S+)", re.M)
SKIP = {".build", "Build", "DerivedData", ".swiftpm", "External", "fixtures"}


def manifests(root: Path) -> list[Path]:
    return sorted(p for p in root.rglob("Package.swift") if not (SKIP & set(p.relative_to(root).parts)))


def specs(root: Path) -> list[Path]:
    out = [root / "project.yml"] if (root / "project.yml").exists() else []
    out += sorted(p for p in root.glob("Harnesses/*/*.yml"))
    return out


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--root", type=Path, default=ROOT)
    ap.add_argument("--inventory", type=Path, default=Path("docs/legal/third-party.json"))
    args = ap.parse_args(argv)
    root = args.root.resolve()
    inv_path = root / args.inventory
    if not inv_path.exists():
        print(f"error: {inv_path} missing", file=sys.stderr)
        return 2
    inv = json.loads(inv_path.read_text())
    allowed, harness_only = set(inv["allowedLicenses"]), set(inv["harnessOnlyLicenses"])
    by_binary = {b: c for c in inv["components"] for b in c.get("binaries", [])}
    by_package = {p: c for c in inv["components"] for p in c.get("packages", [])}
    problems: list[str] = []
    found: list[str] = []
    for c in inv["components"]:
        for lic in re.split(r",\s*", c["license"]):
            if lic not in allowed:
                problems.append(f"{c['id']}: license '{lic}' not in the allowed list")
            if lic in harness_only and c["scope"] != "harness":
                problems.append(f"{c['id']}: {lic} is allowed only for harness scope (is '{c['scope']}')")
        if not (root / c["text"]).exists():
            problems.append(f"{c['id']}: license text {c['text']} missing")
    for m in manifests(root):
        text = m.read_text()
        for b in BINARY.findall(text):
            found.append(f"binary {b} ({m.relative_to(root)})")
            if b not in by_binary:
                problems.append(f"binary target {b} in {m.relative_to(root)} has no inventory entry")
        for url in REMOTE.findall(text):
            found.append(f"remote package {url}")
            problems.append(f"remote package {url} in {m.relative_to(root)} has no inventory entry")
    for s in specs(root):
        for name, loc in SPEC_PKG.findall(s.read_text()):
            if "External/" in loc or loc.startswith("http"):
                found.append(f"spec package {name} -> {loc} ({s.relative_to(root)})")
                if name not in by_package:
                    problems.append(f"package {name} ({loc}) in {s.relative_to(root)} has no inventory entry")
                elif by_package[name]["scope"] == "harness" and not str(s.relative_to(root)).startswith("Harnesses/"):
                    problems.append(f"harness-only package {name} used by {s.relative_to(root)}")
    print(f"inventory components: {len(inv['components'])}; dependencies found: {len(found)}")
    for f in found:
        print(f"  {f}")
    for p in problems:
        print(f"PROBLEM {p}")
    if problems:
        print(f"FAIL: {len(problems)} license problem(s)")
        return 1
    print("PASS: every dependency is inventoried with an allowed license and its text")
    return 0


if __name__ == "__main__":
    sys.exit(main())
