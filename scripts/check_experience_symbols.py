#!/usr/bin/env python3
"""Automation-symbol check of the experience modules (feature UA-F02, research R9, T-U02-032): a release build of
VisualCoreExperience (`pure`) or VisualCoreExperienceHost (`host`) must contain no symbol that names
`ExperienceScenario` (or, since UA-F09, another name of NAMES for that module: `ScenarioManifest`,
`ScenarioManifestValidator`, `ScenarioEvaluator`, `ScenarioObservation`, `ScenarioRequest`, `EvidenceRecord`,
`FrameChecks` for `pure`, `ScenarioRunner` for `host`), because the scenario hooks are inside
`#if DEBUG || VISUALCORE_AUTOMATION`. With --with-flag the module is built for release with VISUALCORE_AUTOMATION
and the check is inverted: at least one symbol is required, which proves that the check can see them; with
--with-flag --require-each every name of the module must be found.

  python3 scripts/check_experience_symbols.py --module pure
  python3 scripts/check_experience_symbols.py --module pure --with-flag
  python3 scripts/check_experience_symbols.py --module host
  python3 scripts/check_experience_symbols.py --module host --with-flag
  python3 scripts/check_experience_symbols.py --module pure --with-flag --require-each

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
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
NEEDLE = "ExperienceScenario"
# The type names each module may contain only under DEBUG or VISUALCORE_AUTOMATION (UA-F02; UA-F09 T-U09-019,
# FR-U09-012, SC-U09-004). A symbol line naming any of them counts.
NAMES = {
    "pure": (NEEDLE, "ScenarioManifest", "ScenarioManifestValidator", "ScenarioEvaluator", "ScenarioObservation",
             "ScenarioRequest", "EvidenceRecord", "FrameChecks"),
    "host": (NEEDLE, "ScenarioRunner"),
}
FLAG = "VISUALCORE_AUTOMATION"
DESTINATION = "generic/platform=iOS Simulator"
TARGETS = {"pure": "VisualCoreExperience", "host": "VisualCoreExperienceHost"}


def names_of(module: str | None) -> tuple[str, ...]:
    """The names of one module, or of both when `module` is None."""
    if module is None:
        return tuple(dict.fromkeys(n for names in NAMES.values() for n in names))
    return NAMES[module]


def symbol_lines(nm_output: str, module: str | None = None) -> list[str]:
    """The lines of (demangled) `nm` output that name an automation symbol of `module` (of either module when None)."""
    names = names_of(module)
    return [line for line in nm_output.splitlines() if any(n in line for n in names)]


def count_symbols(nm_output: str, module: str | None = None) -> int:
    return len(symbol_lines(nm_output, module))


def missing_names(lines: list[str], module: str) -> list[str]:
    """The names of `module` that no line names (for --with-flag --require-each)."""
    return [n for n in NAMES[module] if not any(n in line for line in lines)]


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
    """Every object file below a directory named `<Target>.build` inside the build directory. The build system of
    the Swift toolchain 6.4 names the directory `<Target>-t.build`; both forms count, other targets never do."""
    marker = re.compile(r"^" + re.escape(TARGETS[module]) + r"(-[a-z])?\.build$")
    if not build_dir.is_dir():
        return []
    return sorted(p for p in build_dir.rglob("*.o")
                  if p.is_file() and any(marker.match(part) for part in p.relative_to(build_dir).parts[:-1]))


def main(argv: list[str] | None = None, root: Path = ROOT, run=subprocess.run) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--module", required=True, choices=sorted(TARGETS))
    ap.add_argument("--with-flag", action="store_true", help="build with VISUALCORE_AUTOMATION and require symbols")
    ap.add_argument("--require-each", action="store_true",
                    help="with --with-flag: every name of the module must be found, not only one")
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
        found += symbol_lines(plain.stdout or "", a.module)
    ok = verdict(len(found), a.with_flag)
    missing = missing_names(found, a.module) if a.with_flag and a.require_each else []
    ok = ok and not missing
    kind = f"release with {FLAG}" if a.with_flag else "release"
    print(("PASS" if ok else "FAIL")
          + f": {a.module}, {kind}, {len(found)} automation symbols in {len(objects)} object files")
    if not ok and not a.with_flag:
        for line in found[:5]:
            print("   ", line)
    for name in missing:
        print(f"    {name}: not found with {FLAG}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
