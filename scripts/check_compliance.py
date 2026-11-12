#!/usr/bin/env python3
"""VisualCore compliance scanner (T-F005; Constitution I, II, VIII; README §8.4).

Ported from the owner's ProjectM-iOS scripts/check_compliance.py, keeping the rules that apply to the
whole suite and dropping the suite-wide networking ban (README §14.7: networking is allowed only
where an app's spec justifies it — such apps must be listed in Configs/network-allowlist.json).

Scanned: Swift/C/ObjC/Metal/GLSL sources, project yml files and plists under Packages/, Apps/,
Showcase/, Harnesses/, Bridging/ (never External/ or Build/). Comments are stripped before matching.
Exit 1 on any violation.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCAN_DIRS = ("Packages", "Apps", "Showcase", "Harnesses", "Bridging")
SOURCE_EXT = {".swift", ".c", ".h", ".m", ".mm", ".cpp", ".glsl", ".vsh", ".fsh", ".frag", ".vert"}
CONFIG_EXT = {".yml", ".yaml", ".plist", ".xcconfig", ".entitlements"}
REFERENCE_HARNESS = "Harnesses/ProjectMReference/"


def swift_import(module: str) -> str:
    return rf"\bimport\s+(?:(?:typealias|struct|class|enum|protocol|let|var|func)\s+)?{module}\b"


RULES = [
    ("ReplayKit is excluded (VC-017)", re.compile(swift_import("ReplayKit") + r"|<ReplayKit/")),
    ("private framework path", re.compile(r"PrivateFrameworks")),
    ("dynamic symbol lookup (dlopen/dlsym)", re.compile(r"\b(dlsym|dlopen)\s*\(")),
    ("Objective-C runtime string dispatch", re.compile(r"\b(NSClassFromString|NSSelectorFromString|performSelector)\b")),
    ("direct Metal renderer (Constitution I: ANGLE only)", re.compile(r"\bMTLCreateSystemDefaultDevice\b|\bMTKView\b|\bimport\s+MetalKit\b")),
]
PROJECTM = re.compile(swift_import(r"(?:ProjectMBridge|ANGLERendering|Rendering|PresetLibrary|CaptureKit)")
                      + r"|projectM-4|libprojectM|ProjectM\.xcframework")
NETWORK = re.compile(r"\bURLSession\b|\bimport\s+Network\b|\bNWConnection\b|\bimport\s+WebKit\b|\bWKWebView\b|<sys/socket\.h>")
SIGNING = re.compile(r"^\s*(DEVELOPMENT_TEAM|PROVISIONING_PROFILE(?:_SPECIFIER)?|CODE_SIGN_IDENTITY)\s*[:=]\s*\S", re.M)
BACKGROUND = re.compile(r"UIBackgroundModes")


def strip_comments(text: str, suffix: str) -> str:
    if suffix in {".yml", ".yaml", ".xcconfig"}:
        return re.sub(r"(^|\s)(#|//)[^\n]*", r"\1", text)
    if suffix in {".plist", ".entitlements"}:
        return re.sub(r"<!--.*?-->", "", text, flags=re.S)
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    return re.sub(r"//[^\n]*", "", text)


def files(root: Path):
    for d in SCAN_DIRS:
        base = root / d
        if not base.exists():
            continue
        for p in sorted(base.rglob("*")):
            if p.is_file() and not any(part in {".build", "Build", ".swiftpm", "DerivedData"} for part in p.parts):
                yield p
    for p in sorted(root.glob("*.yml")):
        yield p


def scan(root: Path = ROOT) -> list[str]:
    allow = root / "Configs" / "network-allowlist.json"
    network_ok = set(json.loads(allow.read_text())["paths"]) if allow.exists() else set()
    problems = []
    for path in files(root):
        rel = path.relative_to(root).as_posix()
        suffix = path.suffix.lower()
        if suffix not in SOURCE_EXT | CONFIG_EXT:
            continue
        text = strip_comments(path.read_text(encoding="utf-8", errors="replace"), suffix)
        if suffix in SOURCE_EXT:
            for label, rx in RULES:
                if rx.search(text):
                    problems.append(f"{rel}: {label}")
            if not rel.startswith(REFERENCE_HARNESS) and PROJECTM.search(text):
                problems.append(f"{rel}: ProjectM engine/reference module outside the reference harness (Constitution II)")
            if NETWORK.search(text) and not any(rel.startswith(p) for p in network_ok):
                problems.append(f"{rel}: networking API without an allowlisted spec justification")
        else:
            if SIGNING.search(text):
                problems.append(f"{rel}: committed signing identity/team (owner-only)")
            if BACKGROUND.search(text):
                problems.append(f"{rel}: background mode declared (needs an ADR and allowlist; none approved)")
            if not rel.startswith(REFERENCE_HARNESS) and PROJECTM.search(text):
                problems.append(f"{rel}: ProjectM dependency outside the reference harness")
    return problems


def scanned(root: Path = ROOT) -> dict[str, int]:
    """Number of scanned files per area: `Apps/<name>` for each app, the first folder otherwise."""
    counts: dict[str, int] = {}
    for path in files(root):
        if path.suffix.lower() not in SOURCE_EXT | CONFIG_EXT:
            continue
        parts = path.relative_to(root).parts
        area = "/".join(parts[:2]) if parts[0] == "Apps" and len(parts) > 2 else (parts[0] if len(parts) > 1 else ".")
        counts[area] = counts.get(area, 0) + 1
    return counts


def main() -> int:
    problems = scan()
    for area, count in sorted(scanned().items()):
        print(f"scanned {area}: {count} files")
    for p in problems:
        print("VIOLATION:", p)
    print("PASS: no compliance violations" if not problems else f"FAIL: {len(problems)} violations")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
