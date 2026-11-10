#!/usr/bin/env python3
"""F00: read-only audit of the pinned External/projectm-ios reference checkout.

Records (never changes) the reference pins, fork remotes, licenses, prebuilt ANGLE XCFramework
slices and exported symbol counts, build scripts and rendering-bridge sources, then writes
docs/architecture/projectm-reference-audit.json. Exits 1 if a hard rule is violated:
  * the projectM / ANGLE submodules must point at the owner's forks (Coastrnaut, branch ios);
  * the reference checkout must be clean (we never mutate it);
  * the ANGLE EGL/GLES XCFrameworks must contain device and simulator slices;
  * prebuilt ANGLE and ProjectM engine frameworks must come from the pinned commits (FR-F001).
No Claude/LLM call; uses git, nm, plutil and du only. Standard library only.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import plistlib
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REF = ROOT / "External" / "projectm-ios"
OUT = ROOT / "docs" / "architecture" / "projectm-reference-audit.json"


def sh(cmd: list[str], cwd: Path = ROOT, timeout: int = 600) -> str:
    out = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, timeout=timeout, check=False)
    return out.stdout.strip()


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def gitmodules(path: Path) -> dict[str, dict[str, str]]:
    mods: dict[str, dict[str, str]] = {}
    current = None
    for line in path.read_text(encoding="utf-8").splitlines():
        m = re.match(r'\s*\[submodule "(.+)"\]', line)
        if m:
            current = mods.setdefault(m.group(1), {})
            continue
        if current is not None and "=" in line:
            k, v = (x.strip() for x in line.split("=", 1))
            current[k] = v
    return mods


def xcframework(path: Path) -> dict:
    info = plistlib.loads((path / "Info.plist").read_bytes())
    slices = []
    for lib in info.get("AvailableLibraries", []):
        ident = lib["LibraryIdentifier"]
        fw = path / ident / lib["LibraryPath"]
        binary = fw / fw.stem
        fw_info = plistlib.loads((fw / "Info.plist").read_bytes()) if (fw / "Info.plist").exists() else {}
        symbols = sh(["nm", "-gU", str(binary)]).splitlines()
        slices.append({
            "identifier": ident,
            "platform": lib.get("SupportedPlatform"),
            "variant": lib.get("SupportedPlatformVariant", "device"),
            "archs": lib.get("SupportedArchitectures"),
            "binary_sha256": sha256(binary),
            "exported_gl": sum(1 for s in symbols if re.search(r" T _gl[A-Z]", s)),
            "exported_egl": sum(1 for s in symbols if re.search(r" T _egl[A-Z]", s)),
            "CFBundleShortVersionString": fw_info.get("CFBundleShortVersionString"),
            "MinimumOSVersion": fw_info.get("MinimumOSVersion"),
        })
    return {"path": str(path.relative_to(ROOT)), "slices": slices}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--output", default=str(OUT))
    args = ap.parse_args()
    problems: list[str] = []
    if not (REF / ".git").exists():
        print("reference checkout missing: git submodule update --init External/projectm-ios")
        return 1
    dirty = sh(["git", "status", "--porcelain", "--ignore-submodules=untracked"], cwd=REF)
    if dirty:
        problems.append("reference checkout has local modifications: " + dirty[:200])
    mods = gitmodules(REF / ".gitmodules")
    for name, want in (("Vendor/projectM", "Coastrnaut/projectm"), ("Vendor/angle", "Coastrnaut/angle")):
        mod = mods.get(name, {})
        if want not in mod.get("url", "") or mod.get("branch") != "ios":
            problems.append(f"{name} is not the owner's fork on branch ios: {mod}")
    pins = {}
    for line in sh(["git", "submodule", "status"], cwd=REF).splitlines():
        parts = line.strip().split()
        if len(parts) >= 2:
            pins[parts[1]] = {"commit": parts[0].lstrip("-+U"), "described": " ".join(parts[2:])}
    angle_dir = REF / "Build" / "ANGLEFrameworks"
    frameworks = {}
    for fw in ("libEGL.xcframework", "libGLESv2.xcframework"):
        if (angle_dir / fw).exists():
            frameworks[fw] = xcframework(angle_dir / fw)
            kinds = {(s["platform"], s["variant"]) for s in frameworks[fw]["slices"]}
            if ("ios", "device") not in kinds or ("ios", "simulator") not in kinds:
                problems.append(f"{fw} lacks a device or simulator slice: {kinds}")
        else:
            problems.append(f"missing {fw}: run scripts/build_angle_xcframework.py inside the reference")
    angle_json = angle_dir / "ANGLE.json"
    angle_meta = json.loads(angle_json.read_text(encoding="utf-8")) if angle_json.exists() else None
    if angle_meta and angle_meta.get("angleCommit") != pins.get("Vendor/angle", {}).get("commit"):
        problems.append("prebuilt ANGLE frameworks were built from a different commit than the pin")
    engine_json = REF / "Build" / "ProjectM.xcframework.json"
    engine_meta = json.loads(engine_json.read_text(encoding="utf-8")) if engine_json.exists() else None
    if engine_meta is None:
        problems.append("missing Build/ProjectM.xcframework(.json): run the reference's scripts/build_projectm_xcframework.py")
    elif engine_meta.get("engineCommit") != pins.get("Vendor/projectM", {}).get("commit"):
        problems.append("prebuilt ProjectM.xcframework was built from a different engine commit than the pin")
    licenses = {}
    for rel in ("LICENSE", "Vendor/projectM/COPYING", "Vendor/projectM/LICENSE.txt", "Vendor/angle/LICENSE"):
        p = REF / rel
        if p.exists():
            licenses[rel] = {"sha256": sha256(p), "first_line": p.read_text(errors="replace").strip().splitlines()[0][:80]}
    bridge = {}
    for rel in sorted((REF / "Packages" / "ANGLERendering").rglob("*")):
        if rel.is_file() and rel.suffix in {".swift", ".c", ".h"}:
            bridge[str(rel.relative_to(REF))] = sha256(rel)
    scripts = {s: (REF / "scripts" / s).exists() for s in (
        "build_angle_xcframework.py", "build_projectm_xcframework.py", "check_compliance.py",
        "verify_environment.py", "run_device_tests.py", "validate_docs.py", "test_scripts.py",
        "check_privacy_manifest.py", "generate_gles_loader.py")}
    size_kb = sh(["du", "-sk", str(REF / "Vendor" / "angle")], timeout=900).split()
    report = {
        "reference": {"path": "External/projectm-ios",
                      "commit": sh(["git", "rev-parse", "HEAD"], cwd=REF),
                      "superproject_pin": sh(["git", "ls-tree", "HEAD", "External/projectm-ios"]).split()[2]
                      if sh(["git", "ls-tree", "HEAD", "External/projectm-ios"]) else None,
                      "clean": not dirty},
        "submodules": {k: {**mods.get(k, {}), **pins.get(k, {})} for k in sorted(set(mods) | set(pins))},
        "historical_projectm_commit_c88894e_matches": pins.get("Vendor/projectM", {}).get("commit", "").startswith("c88894e"),
        "angle_build": angle_meta,
        "angle_frameworks": frameworks,
        "projectm_xcframework_present": (REF / "Build" / "ProjectM.xcframework").exists(),
        "engine_build": {k: engine_meta.get(k) for k in ("engineCommit", "engineVersion", "deploymentTarget")} if engine_meta else None,
        "angle_tree_kilobytes": int(size_kb[0]) if size_kb else None,
        "licenses": licenses,
        "bridge_sources_sha256": bridge,
        "packages": sorted(p.name for p in (REF / "Packages").iterdir() if p.is_dir()),
        "apps": sorted(p.name for p in (REF / "Apps").iterdir() if p.is_dir()),
        "build_scripts": scripts,
        "problems": problems,
    }
    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({k: report[k] for k in ("reference", "historical_projectm_commit_c88894e_matches",
                                              "projectm_xcframework_present", "engine_build", "angle_tree_kilobytes", "problems")}, indent=2))
    print("PASS" if not problems else "FAIL")
    return 0 if not problems else 1


if __name__ == "__main__":
    sys.exit(main())
