#!/usr/bin/env python3
"""Check the VisualCore build host against the reference toolchain in Configs/toolchain.json.

Exit 0 when every pinned tool matches, 1 otherwise. On non-macOS hosts it prints
"macOS required for build tasks" and exits 0 (docs/scripts work only).
Writes a machine-readable report with --json <path>. Standard library only. Never installs
or upgrades anything (CLAUDE.md §8: pins are references, not a licence to upgrade).
"""
from __future__ import annotations

import argparse
import json
import platform
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PINS = ROOT / "Configs" / "toolchain.json"

TOOLS: dict[str, tuple[list[str], str]] = {
    "Xcode": (["xcodebuild", "-version"], r"Xcode\s+([\d.]+)"),
    "XcodeBuild": (["xcodebuild", "-version"], r"Build version\s+(\S+)"),
    "SDK": (["xcrun", "--sdk", "iphoneos", "--show-sdk-version"], r"([\d.]+)"),
    "Swift": (["xcrun", "swift", "--version"], r"Swift version\s+([\d.]+)"),
    "XcodeGen": (["xcodegen", "--version"], r"([\d.]+)"),
    "CMake": (["cmake", "--version"], r"cmake version\s+([\d.]+)"),
}


def run(cmd: list[str]) -> str:
    try:
        out = subprocess.run(cmd, capture_output=True, text=True, timeout=120, check=False)
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return ""
    return out.stdout + out.stderr


def observe() -> dict[str, str | None]:
    found: dict[str, str | None] = {}
    for name, (cmd, pattern) in TOOLS.items():
        m = re.search(pattern, run(cmd))
        found[name] = m.group(1) if m else None
    return found


def runtimes() -> list[str]:
    raw = run(["xcrun", "simctl", "list", "-j", "runtimes"])
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        return []
    return sorted({f"{r['platform']} {r['version']} ({r['buildversion']})"
                   for r in data.get("runtimes", []) if r.get("isAvailable")})


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--json", help="write report JSON here")
    args = ap.parse_args()
    if platform.system() != "Darwin":
        print("macOS required for build tasks")
        return 0
    pins = json.loads(PINS.read_text(encoding="utf-8"))
    found = observe()
    problems = []
    for name, value in found.items():
        want = pins.get(name)
        status = "ok" if value == want else ("missing" if value is None else "mismatch")
        if status != "ok":
            problems.append(name)
        print(f"{name:10} pinned={want!s:8} found={value!s:8} {status}")
    py = sys.version_info[:2]
    min_py = tuple(int(x) for x in pins["MinPython"].split("."))
    if py < min_py:
        problems.append("Python")
    print(f"Python     min={pins['MinPython']} found={platform.python_version()} {'ok' if py >= min_py else 'too old'}")
    rts = runtimes()
    for want in pins.get("SimulatorRuntimes", []):
        ok = any(r.startswith(want + " ") or r.startswith(want + ".") for r in rts)
        print(f"Runtime    {want:20} {'ok' if ok else 'missing'}")
        if not ok:
            problems.append(want)
    report = {"pins": pins, "found": found, "python": platform.python_version(),
              "runtimes": rts, "problems": problems, "ok": not problems}
    if args.json:
        Path(args.json).parent.mkdir(parents=True, exist_ok=True)
        Path(args.json).write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print("PASS" if not problems else "FAIL: " + ", ".join(problems))
    return 0 if not problems else 1


if __name__ == "__main__":
    sys.exit(main())
