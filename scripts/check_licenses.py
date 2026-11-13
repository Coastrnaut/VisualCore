#!/usr/bin/env python3
"""License/notice check (feature 010 T-F907; FR-F909; UA-F11 FR-U11-030, 031, 080). Finds every binary target and
external package dependency in Package.swift files and XcodeGen specs, and requires each to map to an entry in
docs/legal/third-party.json whose license is allowed (LGPL only for harness scope) and whose license text file exists.

  python3 scripts/check_licenses.py [--app APP] [--json REPORT]

The inventory checks always run. With --app, the built app's APP/Licenses folder must equal, file for file and byte
for byte (recursively), the bundle that bundle_licenses.bundle() produces for the shipped entries in a temporary
directory; every missing, extra or differing file is named. A missing Licenses folder is a finding (FAIL); an app path
that is not a usable bundle (missing, or without its main executable) is a usage error. --json writes the report
{"schema": 1, "check": "licenses" | "licenses-app", "meta", "findings", "verdict"} (data-model section 7).
Exit 0 ok, 1 unknown/unlicensed or bundle mismatch, 2 usage or unusable input.
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import os
import re
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPTS = Path(__file__).resolve().parent
BINARY = re.compile(r'\.binaryTarget\(\s*name:\s*"([^"]+)"')
REMOTE = re.compile(r'\.package\(\s*url:\s*"([^"]+)"')
LOCAL = re.compile(r'\.package\(\s*path:\s*"([^"]+)"')
SPEC_PKG = re.compile(r"^  (\w+):\s*\n\s+(?:path|url):\s*(\S+)", re.M)
SKIP = {".build", "Build", "DerivedData", ".swiftpm", "External", "fixtures"}


def manifests(root: Path) -> list[Path]:
    """Every Package.swift below `root` outside the SKIP folders (pruned during the walk, not filtered after it)."""
    found = []
    for folder, dirs, files in os.walk(root):
        dirs[:] = [d for d in dirs if d not in SKIP]
        if "Package.swift" in files:
            found.append(Path(folder) / "Package.swift")
    return sorted(found)


def specs(root: Path) -> list[Path]:
    out = [root / "project.yml"] if (root / "project.yml").exists() else []
    out += sorted(p for p in root.glob("Harnesses/*/*.yml"))
    return out


def _module(name: str):
    """Load a sibling script as a module (registered in sys.modules so it is loaded once)."""
    if name in sys.modules:
        return sys.modules[name]
    spec = importlib.util.spec_from_file_location(name, SCRIPTS / f"{name}.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def _files(folder: Path) -> dict[str, Path]:
    return {p.relative_to(folder).as_posix(): p for p in sorted(folder.rglob("*")) if p.is_file()}


def compare_bundle(inv: dict, app: Path, root: Path) -> list[dict]:
    """Findings for every file of APP/Licenses that is missing, extra or differs from a fresh bundle of `inv`."""
    actual_dir = app / "Licenses"
    if not actual_dir.is_dir():
        return [{"file": "Licenses", "kind": "missing", "text": f"missing Licenses folder in {app.name}"}]
    findings = []
    with tempfile.TemporaryDirectory() as tmp:
        expected_dir = Path(tmp) / "Licenses"
        for problem in _module("bundle_licenses").bundle(inv, expected_dir, root):
            findings.append({"file": "Licenses", "kind": "inventory", "text": problem})
        expected, actual = _files(expected_dir), _files(actual_dir)
        for rel in sorted(expected.keys() | actual.keys()):
            name = f"Licenses/{rel}"
            if rel not in actual:
                findings.append({"file": name, "kind": "missing", "text": f"missing {name} (shipped in the inventory)"})
            elif rel not in expected:
                findings.append({"file": name, "kind": "extra", "text": f"extra {name} (not produced from the inventory)"})
            elif expected[rel].read_bytes() != actual[rel].read_bytes():
                findings.append({"file": name, "kind": "differs", "text": f"differs {name} (bytes differ from the inventory)"})
    return findings


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--root", type=Path, default=ROOT)
    ap.add_argument("--inventory", type=Path, default=Path("docs/legal/third-party.json"))
    ap.add_argument("--app", type=Path, help="built .app whose Licenses folder must equal the shipped inventory")
    ap.add_argument("--json", type=Path, help="write the machine-readable report here")
    args = ap.parse_args(argv)
    root = args.root.resolve()
    report_meta = _module("report_meta")
    app = args.app.resolve() if args.app else None
    if app is not None and not app.is_dir():
        print(f"error: {app} is not an app bundle", file=sys.stderr)
        return 2
    try:
        meta = report_meta.meta(app, None)
    except report_meta.ReportError as error:
        print(f"error: {error}", file=sys.stderr)
        return 2
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
    findings = [{"file": str(args.inventory), "kind": "inventory", "text": p} for p in problems]
    if app is not None:
        findings += compare_bundle(inv, app, root)
    for f in findings:
        print(f"PROBLEM {f['text']}")
    verdict = "FAIL" if findings else "PASS"
    if args.json:
        report_meta.write_report(args.json, {"schema": 1, "check": "licenses-app" if app else "licenses",
                                             "meta": meta, "findings": findings, "verdict": verdict})
    if findings:
        print(f"FAIL: {len(findings)} license problem(s)")
        return 1
    suffix = f"; {app.name}/Licenses equals the shipped inventory" if app else ""
    print(f"PASS: every dependency is inventoried with an allowed license and its text{suffix}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
