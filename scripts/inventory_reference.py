#!/usr/bin/env python3
"""Inventory the read-only reference External/projectm-ios (T-F005) and verify trace citations (T-F010).

Default: writes docs/architecture/reference-inventory.json with rows {path, kind, role, detail}
(contract specs/001-baseline-audit/contracts/audit-outputs.md). Exit 1 if a required kind is empty.

--check-citations DOC: every citation of the form ref:`<path>`#`<symbol>` in DOC must name an
existing file under the reference whose text contains <symbol>. Exit 1 listing unresolved ones.
Standard library only; never writes into the reference.
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REF = ROOT / "External" / "projectm-ios"
OUT = ROOT / "docs" / "architecture" / "reference-inventory.json"
CITATION = re.compile(r"ref:`([^`]+)`#`([^`]+)`")

# Classification with reasons (FR-F007). Anything not listed is reported as unclassified.
PACKAGE_ROLES = {
    "ANGLERendering": ("projectm-specific", "EGL/ANGLE lifecycle is reusable in principle but ANGLERenderer hard-wires ProjectMEngine, Preset, NormalizedPCMReader and PresetPrewarmer"),
    "Rendering": ("projectm-specific", "VisualizerRenderer protocol, preset repository and GLES (Apple OpenGLES) backend for the engine; QualityGovernor/FrameRateMeter/CFlashLimiter are reusable ideas"),
    "ProjectMBridge": ("projectm-specific", "Swift/ObjC bridge to the LGPL projectM engine"),
    "PresetLibrary": ("projectm-specific", "MilkDrop preset index, scopes, search"),
    "AudioCore": ("reusable-candidate", "PCM normalization, ring buffers and resampling are app-neutral; types are named for the visualizer"),
    "CaptureKit": ("projectm-specific", "System/App Capture + microphone + in-app playback drivers for CaptureLab; ScreenCaptureKit path is product-specific"),
    "CaptureUI": ("projectm-specific", "SwiftUI for CaptureLab source selection"),
    "Diagnostics": ("reusable-candidate", "session diagnostics/export primitives"),
}
APP_ROLES = {
    "projectM-iOS": ("projectm-specific", "shipping visualizer app"),
    "CaptureLab": ("projectm-specific", "tester-only capture diagnostics app"),
    "RendererLab": ("tooling", "renderer benchmark harness for ADR-0003"),
}


def git(args: list[str]) -> str:
    return subprocess.run(["git", *args], cwd=REF, capture_output=True, text=True, timeout=600, check=False).stdout


def package_rows() -> list[dict]:
    rows = []
    for pkg in sorted(p for p in (REF / "Packages").iterdir() if (p / "Package.swift").exists()):
        manifest = (pkg / "Package.swift").read_text(encoding="utf-8")
        targets = re.findall(r"\.(?:target|testTarget|binaryTarget)\(name:\s*\"([^\"]+)\"", manifest)
        deps = re.findall(r"\.package\(path:\s*\"([^\"]+)\"", manifest)
        role, reason = PACKAGE_ROLES.get(pkg.name, ("unclassified", ""))
        rows.append({"path": f"Packages/{pkg.name}/Package.swift", "kind": "package", "role": role,
                     "detail": {"targets": targets, "local_deps": deps, "reason": reason,
                                "platforms": re.findall(r"\.(iOS|macOS)\(", manifest)}})
        for test_dir in sorted((pkg / "Tests").glob("*")):
            if test_dir.is_dir():
                files = list(test_dir.rglob("*.swift"))
                rows.append({"path": str(test_dir.relative_to(REF)), "kind": "test-target", "role": role,
                             "detail": {"swift_files": len(files),
                                        "test_funcs": sum(len(re.findall(r"func test\w+|@Test", f.read_text(errors="replace"))) for f in files)}})
    return rows


def xcodegen_rows() -> list[dict]:
    rows = []
    for spec in ("project.yml", "RendererLab.yml"):
        text = (REF / spec).read_text(encoding="utf-8")
        targets = re.findall(r"^  ([A-Za-z][\w-]*):\n(?:    #[^\n]*\n)*    type: (\S+)", text, re.M)
        schemes = re.findall(r"^schemes:\n((?:  .*\n?)+)", text, re.M)
        scheme_names = re.findall(r"^  ([A-Za-z][\w-]*):$", schemes[0], re.M) if schemes else []
        rows.append({"path": spec, "kind": "xcodegen-spec", "role": "tooling",
                     "detail": {"targets": [{"name": n, "type": t} for n, t in targets], "schemes": scheme_names,
                                "deployment_target": re.search(r'IPHONEOS_DEPLOYMENT_TARGET: "([\d.]+)"', text).group(1)}})
        for name, typ in targets:
            if typ == "application":
                role, reason = APP_ROLES.get(name, ("unclassified", ""))
                rows.append({"path": f"Apps/{name}", "kind": "app", "role": role,
                             "detail": {"xcodegen_spec": spec, "reason": reason,
                                        "swift_files": len(list((REF / "Apps" / name).rglob("*.swift")))}})
    return rows


def other_rows() -> list[dict]:
    rows = []
    for s in sorted((REF / "scripts").glob("*.py")):
        doc = re.search(r'"""(.+?)(?:\n|""")', s.read_text(encoding="utf-8"), re.S)
        rows.append({"path": f"scripts/{s.name}", "kind": "script", "role": "tooling",
                     "detail": (doc.group(1).strip() if doc else "")[:160]})
    for wf in sorted((REF / ".github" / "workflows").glob("*.y*ml")):
        jobs = re.findall(r"^  ([\w-]+):\n", wf.read_text(encoding="utf-8").split("\njobs:", 1)[-1], re.M)
        rows.append({"path": str(wf.relative_to(REF)), "kind": "ci-workflow", "role": "tooling", "detail": {"jobs": jobs}})
    for line in git(["submodule", "status"]).splitlines():
        parts = line.split()
        if len(parts) >= 2:
            path = parts[1]
            role = "content" if path.startswith("Vendor/presets/") else "projectm-specific" if path.endswith("projectM") else "reusable-candidate"
            rows.append({"path": path, "kind": "dependency", "role": role, "detail": {"commit": parts[0].lstrip("-+U")}})
    for lic in ("LICENSE", "Vendor/projectM/COPYING", "Vendor/angle/LICENSE"):
        if (REF / lic).exists():
            rows.append({"path": lic, "kind": "license", "role": "content",
                         "detail": (REF / lic).read_text(errors="replace").strip().splitlines()[0][:80]})
    for lic in sorted((REF / "Build" / "ANGLEFrameworks" / "licenses").glob("*.txt")):
        rows.append({"path": str(lic.relative_to(REF)), "kind": "license", "role": "content", "detail": "ANGLE third-party notice (build output)"})
    for hist in ("specs", "docs"):
        if (REF / hist).is_dir():
            rows.append({"path": hist, "kind": "history", "role": "content",
                         "detail": {"files": sum(1 for _ in (REF / hist).rglob("*") if _.is_file()),
                                    "note": "historical context only (VC-016); never VisualCore evidence"}})
    return rows


def check_citations(doc: Path) -> list[str]:
    text = doc.read_text(encoding="utf-8")
    cites = CITATION.findall(text)
    bad = []
    for path, symbol in cites:
        target = REF / path
        if not target.is_file():
            bad.append(f"missing file: {path}")
        elif symbol not in target.read_text(encoding="utf-8", errors="replace"):
            bad.append(f"symbol not found: {path}#{symbol}")
    if not cites:
        bad.append("no citations found")
    print(f"{len(cites)} citations, {len(bad)} unresolved")
    return bad


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--output", default=str(OUT))
    ap.add_argument("--check-citations")
    args = ap.parse_args()
    if args.check_citations:
        bad = check_citations(Path(args.check_citations))
        for b in bad:
            print("UNRESOLVED:", b)
        return 1 if bad else 0
    rows = package_rows() + xcodegen_rows() + other_rows()
    kinds = {r["kind"] for r in rows}
    required = {"package", "app", "xcodegen-spec", "script", "test-target", "ci-workflow", "dependency", "license"}
    problems = [f"no rows of kind {k}" for k in sorted(required - kinds)]
    problems += [f"unclassified: {r['path']}" for r in rows if r["role"] == "unclassified"]
    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps({"reference_commit": git(["rev-parse", "HEAD"]).strip(), "rows": rows,
                               "problems": problems}, indent=2) + "\n", encoding="utf-8")
    counts = {k: sum(r["kind"] == k for r in rows) for k in sorted(kinds)}
    print(json.dumps(counts))
    for p in problems:
        print("PROBLEM:", p)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
