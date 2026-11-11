#!/usr/bin/env python3
"""Privacy-manifest check for any built app (feature 017 T-A01-601; FR-A01-601, FR-A01-602; CLAUDE.md §5).

Scans the main executable and every embedded framework of a built `.app` for Apple's required-reason API categories
(symbol references via `nm -u`/`nm -m`, plus Foundation key strings via `strings -a`) and compares the result with
the bundle's `PrivacyInfo.xcprivacy`:

  python3 scripts/check_privacy_manifest.py --app Build/.../GenerativeArtStudio.app [--json report.json]

Exit 0 when the declared categories equal the detected ones and the manifest declares no tracking, no tracking
domains and no collected data types; 1 when anything is undeclared, unused or violating; 2 on bad input. Detection is
deliberately conservative (it may over-report); a category with no truthful reason is a release blocker, never a
guessed declaration. Shared by every app (constitution II).
"""
from __future__ import annotations

import argparse
import json
import plistlib
import re
import subprocess
import sys
from pathlib import Path

PREFIX = "NSPrivacyAccessedAPICategory"

# Category → (symbol regexes matched against undefined/imported symbols, string regexes matched against binary strings).
TABLE: dict[str, tuple[list[str], list[str]]] = {
    "UserDefaults": ([r"_OBJC_CLASS_\$_NSUserDefaults$", r"^_?CFPreferences(Copy|Set|Get)"], [r"^NSUserDefaults$"]),
    "FileTimestamp": ([r"^_?(f|l)?stat(64)?(\$INODE64)?$", r"^_?f?getattrlist(bulk)?$", r"^_?getattrlistat$"],
                      [r"^NSFile(Creation|Modification)Date$", r"^NSURL(Creation|ContentModification|ContentAccess)DateKey$"]),
    "SystemBootTime": ([r"^_?mach_absolute_time$", r"^_?CACurrentMediaTime$", r"systemUptime"], [r"^systemUptime$"]),
    "DiskSpace": ([r"^_?f?statv?fs(64)?(\$INODE64)?$"],
                  [r"^NSURLVolume(Available|Total)Capacity(ForImportantUsage|ForOpportunisticUsage)?Key$",
                   r"^NSFileSystem(Free|Size)$"]),
    "ActiveKeyboards": ([r"activeInputModes"], [r"^activeInputModes$"]),
}


def scan(symbols: list[str], strings: list[str]) -> dict[str, list[str]]:
    """Detected categories → the evidence (symbols or strings) that triggered each."""
    found: dict[str, list[str]] = {}
    for category, (sym_patterns, str_patterns) in TABLE.items():
        hits = [s for s in symbols if any(re.search(p, s) for p in sym_patterns)]
        hits += [s for s in strings if any(re.search(p, s) for p in str_patterns)]
        if hits:
            found[f"{PREFIX}{category}"] = sorted(set(hits))[:8]
    return found


def compare(detected: dict[str, list[str]], manifest: dict) -> dict:
    """Undeclared/unused categories and manifest violations."""
    declared: dict[str, list[str]] = {}
    for entry in manifest.get("NSPrivacyAccessedAPITypes", []) or []:
        declared[entry.get("NSPrivacyAccessedAPIType", "")] = list(entry.get("NSPrivacyAccessedAPITypeReasons", []) or [])
    violations = []
    if manifest.get("NSPrivacyTracking") is not False:
        violations.append("NSPrivacyTracking must be present and false")
    if manifest.get("NSPrivacyTrackingDomains"):
        violations.append("NSPrivacyTrackingDomains must be empty")
    if manifest.get("NSPrivacyCollectedDataTypes"):
        violations.append("NSPrivacyCollectedDataTypes must be empty (the app collects no data)")
    for category, reasons in declared.items():
        if not reasons:
            violations.append(f"{category} has no reason")
    return {
        "detected": detected,
        "declared": declared,
        "undeclared": sorted(set(detected) - set(declared)),
        "unused": sorted(set(declared) - set(detected)),
        "violations": violations,
    }


def binaries(app: Path) -> list[Path]:
    with open(app / "Info.plist", "rb") as f:
        out = [app / plistlib.load(f)["CFBundleExecutable"]]
    for fw in sorted((app / "Frameworks").glob("*.framework")) if (app / "Frameworks").is_dir() else []:
        info = fw / "Info.plist"
        if info.is_file():
            with open(info, "rb") as f:
                out.append(fw / plistlib.load(f).get("CFBundleExecutable", fw.stem))
    # Loose dynamic libraries (for example Xcode's `<App>.debug.dylib` in Debug builds, Swift support libraries).
    out += sorted(app.glob("*.dylib")) + (sorted((app / "Frameworks").glob("*.dylib")) if (app / "Frameworks").is_dir() else [])
    return [b for b in out if b.is_file()]


def collect(binary: Path) -> tuple[list[str], list[str]]:
    nm = subprocess.run(["xcrun", "nm", "-u", "-arch", "all", str(binary)], capture_output=True, text=True)
    symbols = [line.strip() for line in nm.stdout.splitlines() if line.strip() and not line.endswith(":")]
    st = subprocess.run(["strings", "-a", str(binary)], capture_output=True, text=True)
    return symbols, [line.strip() for line in st.stdout.splitlines()]


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--app", type=Path, required=True)
    ap.add_argument("--json", type=Path)
    a = ap.parse_args(argv)
    manifest_path = a.app / "PrivacyInfo.xcprivacy"
    if not (a.app / "Info.plist").is_file() or not manifest_path.is_file():
        print(f"ERROR: {a.app} needs Info.plist and PrivacyInfo.xcprivacy", file=sys.stderr)
        return 2
    symbols: list[str] = []
    strings: list[str] = []
    scanned = binaries(a.app)
    for b in scanned:
        s, t = collect(b)
        symbols += s
        strings += t
    with open(manifest_path, "rb") as f:
        manifest = plistlib.load(f)
    report = compare(scan(symbols, strings), manifest)
    report["binaries"] = [str(b.relative_to(a.app)) for b in scanned]
    for c in report["undeclared"]:
        print(f"  UNDECLARED {c} ({', '.join(report['detected'][c][:3])})")
    for c in report["unused"]:
        print(f"  UNUSED {c}")
    for v in report["violations"]:
        print(f"  VIOLATION {v}")
    for c in sorted(report["detected"]):
        print(f"  detected {c}: {', '.join(report['detected'][c][:3])}")
    ok = not (report["undeclared"] or report["unused"] or report["violations"])
    if a.json:
        a.json.parent.mkdir(parents=True, exist_ok=True)
        a.json.write_text(json.dumps(report, indent=2) + "\n")
    print(f"{'PASS' if ok else 'FAIL'}: {len(report['detected'])} categories detected in {len(scanned)} binaries, "
          f"{len(report['declared'])} declared")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
