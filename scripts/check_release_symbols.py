#!/usr/bin/env python3
"""Shipping-build automation check (feature 010 T-F904; FR-F914; CLAUDE.md §9): the Release binary of an app
must contain zero automation symbols and no automation trigger strings. With --expect-present the check is
inverted, proving on a measurement build (Release + VISUALCORE_AUTOMATION) that the check can see them.

  python3 scripts/check_release_symbols.py --app Build/.../Release-iphoneos/Showcase.app

With --forbid <text> ... (feature UA-F04 T-U04-014; FR-U04-004) the check looks for these texts instead of the
automation patterns, in the symbols and in the raw bytes of every binary of the app (main executable and embedded
frameworks): a hit fails. --expect-present inverts it: every text must be found at least once.

  python3 scripts/check_release_symbols.py --app <release app> --forbid DebugLaunch DebugExperience
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
        found += sorted(fw.glob("*.dylib"))
    # Loose libraries beside the executable (a debug build keeps the app's code in `<name>.debug.dylib`).
    found += sorted(app.glob("*.dylib"))
    return found


def forbidden_hits(texts: list[str], nm_output: str, data: bytes) -> list[tuple[str, str]]:
    """(text, where) for every text found in the symbols and/or the raw bytes of one binary."""
    hits = []
    for text in texts:
        where = [label for label, found in (("symbols", text in nm_output), ("strings", text.encode() in data)) if found]
        if where:
            hits.append((text, " and ".join(where)))
    return hits


def check_forbidden(app: Path, texts: list[str], expect_present: bool) -> int:
    found: dict[str, list[str]] = {t: [] for t in texts}
    for binary in binaries(app):
        nm = subprocess.run(["xcrun", "nm", "-U", str(binary)], capture_output=True, text=True)
        if nm.returncode != 0:
            print(f"nm failed for {binary}: {nm.stderr.strip()}", file=sys.stderr)
            return 2
        name = str(binary.relative_to(app.parent))
        hits = forbidden_hits(texts, nm.stdout, binary.read_bytes())
        print(f"{name}: {len(hits)} of {len(texts)} texts found")
        for text, where in hits:
            print(f"    {text!r} found in {name} ({where})")
            found[text].append(name)
    if expect_present:
        missing = [t for t in texts if not found[t]]
        for t in missing:
            print(f"    {t!r} not found in any binary")
        ok = not missing
        print(("PASS" if ok else "FAIL") + f": {len(texts) - len(missing)} of {len(texts)} texts present (expected all)")
    else:
        hit = [t for t in texts if found[t]]
        ok = not hit
        print(("PASS" if ok else "FAIL") + f": {len(hit)} of {len(texts)} forbidden texts found (expected 0)"
              + ("" if ok else ": " + "; ".join(f"{t} in {', '.join(found[t])}" for t in hit)))
    return 0 if ok else 1


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--app", required=True, type=Path)
    ap.add_argument("--expect-present", action="store_true")
    ap.add_argument("--forbid", nargs="+", metavar="TEXT",
                    help="look for these texts (symbols and raw bytes of every binary) instead of the automation patterns")
    a = ap.parse_args(argv)
    if a.forbid:
        return check_forbidden(a.app, a.forbid, a.expect_present)
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
