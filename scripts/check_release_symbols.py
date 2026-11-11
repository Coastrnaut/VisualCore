#!/usr/bin/env python3
"""Shipping-build automation check (feature 010 T-F904; FR-F914; CLAUDE.md §9): the Release binary of an app
must contain zero automation symbols and no automation trigger strings. With --expect-present the check is
inverted, proving on a measurement build (Release + VISUALCORE_AUTOMATION) that the check can see them.

  python3 scripts/check_release_symbols.py --app Build/.../Release-iphoneos/Showcase.app
"""
from __future__ import annotations

import argparse
import plistlib
import re
import subprocess
import sys
from pathlib import Path

SYMBOL = re.compile(r"VisualCoreAutomation|AutomationRunner|AutomationReport|ShowcaseAutomation|AutomationRootView")
STRING = re.compile(rb"VISUALCORE_AUTORUN")


def executable(app: Path) -> Path:
    with open(app / "Info.plist", "rb") as f:
        return app / plistlib.load(f)["CFBundleExecutable"]


def automation_symbols(nm_output: str) -> list[str]:
    return [line for line in nm_output.splitlines() if SYMBOL.search(line)]


def binaries(app: Path) -> list[Path]:
    found = [executable(app)]
    fw = app / "Frameworks"
    if fw.is_dir():
        for f in sorted(fw.glob("*.framework")):
            try:
                found.append(executable(f))
            except (OSError, KeyError):
                pass
    return found


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--app", required=True, type=Path)
    ap.add_argument("--expect-present", action="store_true")
    a = ap.parse_args(argv)
    total_syms, total_strings = 0, 0
    for binary in binaries(a.app):
        nm = subprocess.run(["xcrun", "nm", "-U", str(binary)], capture_output=True, text=True)
        if nm.returncode != 0:
            print(f"nm failed for {binary}: {nm.stderr.strip()}", file=sys.stderr)
            return 2
        syms = automation_symbols(nm.stdout)
        strings = len(STRING.findall(binary.read_bytes()))
        print(f"{binary.relative_to(a.app.parent)}: {len(syms)} automation symbols, {strings} trigger strings")
        for s in syms[:5]:
            print("   ", s)
        total_syms += len(syms)
        total_strings += strings
    if a.expect_present:
        ok = total_syms > 0
        print(("PASS" if ok else "FAIL") + f": measurement build has {total_syms} automation symbols (expected > 0)")
    else:
        ok = total_syms == 0 and total_strings == 0
        print(("PASS" if ok else "FAIL") + f": {total_syms} automation symbols, {total_strings} trigger strings (expected 0)")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
