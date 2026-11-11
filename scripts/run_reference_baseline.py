#!/usr/bin/env python3
"""Ordered, reproducible baseline of the unmodified reference External/projectm-ios (T-F013; FR-F008/FR-F009).

  --list         print the steps and their exact commands
  --step NAME    execute one step (stdout/stderr pass straight through, so `desktop_runbook.py
                 run-check` writes the full log to a file; no tail/sort pipelines)

Rules: only `generic/platform=iOS`, `generic/platform=iOS Simulator` or a CoreSimulator UDID are
accepted as destinations; `devicectl` is never invoked; code signing is disabled; DerivedData and
result bundles live in VisualCore's gitignored Build/ and .autonomy/xcresults/. The reference is used
read-only except for its own gitignored outputs (Build/, generated .xcodeproj, Info.plists) produced
by its own scripts and XcodeGen specs.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REF = ROOT / "External" / "projectm-ios"
DERIVED = ROOT / "Build" / "DerivedData" / "reference"
RESULTS = ROOT / ".autonomy" / "xcresults"
TEST_FLAGS = ["-test-timeouts-enabled", "YES", "-default-test-execution-time-allowance", "180"]
# Unique per run: earlier result bundles are evidence and are never overwritten.
STAMP = __import__("datetime").datetime.now().strftime("%Y%m%dT%H%M%S")
ALLOWED_GENERIC = {"generic/platform=iOS", "generic/platform=iOS Simulator"}


def simulator_udid(runtime_prefix: str) -> str:
    """First available iPhone simulator on a runtime whose version starts with runtime_prefix."""
    data = json.loads(subprocess.run(["xcrun", "simctl", "list", "-j", "devices", "available"],
                                     capture_output=True, text=True, check=True).stdout)
    for runtime, devices in sorted(data["devices"].items()):
        m = re.search(r"SimRuntime\.iOS-(\d+)-(\d+)$", runtime)
        if not m or f"{m.group(1)}.{m.group(2)}" != runtime_prefix:
            continue
        for d in devices:
            if d.get("isAvailable") and d["name"].startswith("iPhone"):
                return d["udid"]
    raise SystemExit(f"no available iPhone simulator for iOS {runtime_prefix}")


def destination(dest: str) -> str:
    if dest in ALLOWED_GENERIC:
        return dest
    if re.fullmatch(r"[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}", dest):
        return f"platform=iOS Simulator,id={dest}"
    raise SystemExit("refused destination (FR-F009: simulator/generic only): " + dest)


def xcodebuild_project(project: str, scheme: str, dest: str, action: str = "build") -> list[str]:
    return ["xcodebuild", "-project", str(REF / project), "-scheme", scheme, "-configuration", "Debug",
            "-destination", destination(dest), "-derivedDataPath", str(DERIVED), "CODE_SIGNING_ALLOWED=NO", action]


def steps() -> dict[str, tuple[list[str], Path]]:
    pkg = REF / "Packages" / "ANGLERendering"
    def pkg_test(runtime: str, tag: str) -> list[str]:
        return ["xcodebuild", "test", "-scheme", "ANGLERendering", "-destination", destination(simulator_udid(runtime)),
                "-derivedDataPath", str(DERIVED / f"pkg-{tag}"), "-resultBundlePath", str(RESULTS / f"reference-anglerendering-{tag}-{STAMP}.xcresult"),
                "CODE_SIGNING_ALLOWED=NO", *TEST_FLAGS]
    return {
        "engine-xcframework": (["python3", "scripts/build_projectm_xcframework.py"], REF),
        "xcodegen-main": (["xcodegen", "generate", "--spec", "project.yml"], REF),
        "xcodegen-rendererlab": (["xcodegen", "generate", "--spec", "RendererLab.yml"], REF),
        "build-projectm-ios-sim": (xcodebuild_project("ProjectM-iOS.xcodeproj", "projectM-iOS", "generic/platform=iOS Simulator"), REF),
        "build-capturelab-sim": (xcodebuild_project("ProjectM-iOS.xcodeproj", "CaptureLab", "generic/platform=iOS Simulator"), REF),
        # RendererLab.yml defines no shared scheme; Xcode autocreates one named after the target.
        # (Attempt 1 used -target with SYMROOT/OBJROOT, which broke Xcode's index-store path: exit 65.)
        "build-rendererlab-sim": (xcodebuild_project("RendererLab.xcodeproj", "RendererLab", "generic/platform=iOS Simulator"), REF),
        "build-projectm-ios-generic": (xcodebuild_project("ProjectM-iOS.xcodeproj", "projectM-iOS", "generic/platform=iOS"), REF),
        "test-anglerendering-ios27": (pkg_test("27.2", "ios27"), pkg),
        "test-anglerendering-ios26": (pkg_test("26.5", "ios26"), pkg),
    }


# XcodeGen spec that generates each reference project. The generated .xcodeproj is gitignored, so a fresh clone has
# none (setup.md §6, found on the Mac Studio 2026-11-11: build-projectm-ios-sim failed in 0.6 s).
PROJECT_SPECS = {"ProjectM-iOS.xcodeproj": "project.yml", "RendererLab.xcodeproj": "RendererLab.yml"}


def missing_project_generation(cmd: list[str]) -> list[str] | None:
    """The `xcodegen generate` command to run first when `cmd` builds a reference project that does not exist yet."""
    if "-project" not in cmd:
        return None
    project = Path(cmd[cmd.index("-project") + 1])
    spec = PROJECT_SPECS.get(project.name)
    if spec is None or project.exists():
        return None
    return ["xcodegen", "generate", "--spec", spec]


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--list", action="store_true")
    g.add_argument("--step")
    args = ap.parse_args()
    if args.list:
        for name, (cmd, cwd) in steps().items():
            print(f"{name}: (cd {cwd.relative_to(ROOT)}) {' '.join(cmd)}")
        return 0
    table = steps()
    if args.step not in table:
        print("unknown step; use --list")
        return 2
    cmd, cwd = table[args.step]
    if any("devicectl" in c for c in cmd):
        raise SystemExit("devicectl is forbidden in the baseline")
    for p in (DERIVED, RESULTS):
        p.mkdir(parents=True, exist_ok=True)
    generate = missing_project_generation(cmd)
    if generate:
        print("Project missing; generating it first:\n$", " ".join(generate), flush=True)
        code = subprocess.run(generate, cwd=REF, check=False).returncode
        if code != 0:
            return code
    print("Step:", args.step, "| cwd:", cwd, "\n$", " ".join(cmd), flush=True)
    return subprocess.run(cmd, cwd=cwd, env={**os.environ, "NSUnbufferedIO": "YES"}, check=False).returncode


if __name__ == "__main__":
    sys.exit(main())
