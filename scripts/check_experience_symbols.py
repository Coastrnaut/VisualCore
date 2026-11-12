#!/usr/bin/env python3
"""Automation-symbol check of the experience modules (feature UA-F02, research R9, T-U02-032): a release build of
VisualCoreExperience (`pure`) or VisualCoreExperienceHost (`host`) must contain no symbol that names
`ExperienceScenario`, because the scenario hooks are inside `#if DEBUG || VISUALCORE_AUTOMATION`. With --with-flag
the module is built for release with VISUALCORE_AUTOMATION and the check is inverted: at least one symbol is
required, which proves that the check can see them.

  python3 scripts/check_experience_symbols.py --module pure
  python3 scripts/check_experience_symbols.py --module pure --with-flag
  python3 scripts/check_experience_symbols.py --module host
  python3 scripts/check_experience_symbols.py --module host --with-flag

The pure module is built with `swift build` on the host, the host module with `xcodebuild` for the generic iOS
simulator; the destination is a constant, so the tool cannot name a physical device. Builds go to the gitignored
Build/experience-symbols/<module>[-flag]; the build output is captured and only shown when the build fails. The
symbols of the module's object files are listed with `xcrun nm` and demangled with `xcrun swift-demangle`, because
the Swift mangling abbreviates a word that the module name already contains (`ExperienceScenario` inside
`VisualCoreExperience` is written `0C8Scenario`), so the plain name is only reliable in the demangled text.

Exit codes: 0 pass, 1 fail, 2 when the build, nm or the demangler fails or no object file is found. Standard
library only.
"""
from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
NEEDLE = "ExperienceScenario"
FLAG = "VISUALCORE_AUTOMATION"
DESTINATION = "generic/platform=iOS Simulator"
TARGETS = {"pure": "VisualCoreExperience", "host": "VisualCoreExperienceHost"}


def symbol_lines(nm_output: str) -> list[str]:
    """The lines of (demangled) `nm` output that name an automation symbol."""
    return [line for line in nm_output.splitlines() if NEEDLE in line]


def count_symbols(nm_output: str) -> int:
    return len(symbol_lines(nm_output))


def verdict(count: int, with_flag: bool) -> bool:
    """Without the flag no symbol may exist; with the flag at least one must."""
    return count >= 1 if with_flag else count == 0


def build_command(module: str, with_flag: bool, root: Path) -> tuple[list[str], Path, Path]:
    """The build command, its working directory and the build directory that will hold the object files."""
    if module not in TARGETS:
        raise ValueError("unknown module: " + module)
    build_dir = root / "Build" / "experience-symbols" / (module + ("-flag" if with_flag else ""))
    if module == "pure":
        cmd = ["swift", "build", "--package-path", "Packages/VisualCore", "-c", "release",
               "--target", TARGETS[module], "--scratch-path", str(build_dir.relative_to(root))]
        if with_flag:
            cmd += ["-Xswiftc", "-D" + FLAG]
        return cmd, root, build_dir
    cmd = ["xcodebuild", "build", "-scheme", TARGETS[module], "-configuration", "Release",
           "-destination", DESTINATION, "-derivedDataPath", str(build_dir)]
    if with_flag:
        cmd.append("SWIFT_ACTIVE_COMPILATION_CONDITIONS=$(inherited) " + FLAG)
    return cmd, root / "Packages" / "VisualCoreRendering", build_dir


def object_files(build_dir: Path, module: str) -> list[Path]:
    """Every object file below a directory named `<Target>.build` inside the build directory."""
    marker = TARGETS[module] + ".build"
    if not build_dir.is_dir():
        return []
    return sorted(p for p in build_dir.rglob("*.o")
                  if p.is_file() and marker in p.relative_to(build_dir).parts[:-1])


def main(argv: list[str] | None = None, root: Path = ROOT, run=subprocess.run) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--module", required=True, choices=sorted(TARGETS))
    ap.add_argument("--with-flag", action="store_true", help="build with VISUALCORE_AUTOMATION and require symbols")
    a = ap.parse_args(argv)
    cmd, cwd, build_dir = build_command(a.module, a.with_flag, root)
    build = run(cmd, cwd=cwd, capture_output=True, text=True)
    if build.returncode != 0:
        tail = ((build.stdout or "") + (build.stderr or "")).splitlines()[-30:]
        print("\n".join(tail), file=sys.stderr)
        print(f"build failed ({build.returncode}): {' '.join(cmd)}", file=sys.stderr)
        return 2
    objects = object_files(build_dir, a.module)
    if not objects:
        print(f"no object file of {TARGETS[a.module]} found under {build_dir}", file=sys.stderr)
        return 2
    found: list[str] = []
    for obj in objects:
        nm = run(["xcrun", "nm", str(obj)], capture_output=True, text=True)
        if nm.returncode != 0:
            print(f"nm failed for {obj}: {(nm.stderr or '').strip()}", file=sys.stderr)
            return 2
        plain = run(["xcrun", "swift-demangle"], input=nm.stdout or "", capture_output=True, text=True)
        if plain.returncode != 0:
            print(f"swift-demangle failed for {obj}: {(plain.stderr or '').strip()}", file=sys.stderr)
            return 2
        found += symbol_lines(plain.stdout or "")
    ok = verdict(len(found), a.with_flag)
    kind = f"release with {FLAG}" if a.with_flag else "release"
    print(("PASS" if ok else "FAIL")
          + f": {a.module}, {kind}, {len(found)} automation symbols in {len(objects)} object files")
    if not ok and not a.with_flag:
        for line in found[:5]:
            print("   ", line)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
