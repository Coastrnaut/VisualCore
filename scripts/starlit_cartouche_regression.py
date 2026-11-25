#!/usr/bin/env python3
"""Starlit Cartouche regression, one local command (feature 458, R02-G16-08, task T-R02G1608-006,
FR-R02G1608-006 and FR-R02G1608-007, SC-R02G1608-005, clarification Q5): runs the host part and then the simulator
part of the Starlit Cartouche regression and prints one summary line per part.

  python3 scripts/starlit_cartouche_regression.py                  # host part, then simulator part
  python3 scripts/starlit_cartouche_regression.py --skip-simulator   # host part only
  python3 scripts/starlit_cartouche_regression.py --dry-run          # print the commands, run nothing

The host part is `swift test --package-path Packages/ExperiencesRound02 --filter StarlitCartoucheRegression`
(solver regression and golden-frame descriptions). The simulator part runs the classes
StarlitCartoucheRegressionGoldenFrameTests and StarlitCartoucheRegressionMemoryTests of
StarlitCartoucheExperienceTests through `scripts/xcodebuild_package.py --only-testing` on `sim-27.2`; that
runner bounds every test with xcodebuild's per-test time allowance (180 s), the only time limit; nothing here is
timed against the wall clock. Both parts run from the repository root, and the child output streams to the terminal
while it is read, so nothing is hidden.

Each part prints `starlit-cartouche-regression <part>: PASS` or `starlit-cartouche-regression <part>: FAIL
(exit N; first failing: <name>)`, the name parsed from a swift-testing line `✘ Test <name>(` or an XCTest line
`Test Case '-[<Module.Class> <name>]' failed`; then `starlit-cartouche-regression: PASS|FAIL`. Exit code 0 only when
every part that ran passed, 1 otherwise. Never names a physical device. Standard library only.
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

PACKAGE = "Packages/ExperiencesRound02"
SCHEME = "ExperiencesRound02-Package"
DESTINATION = "sim-27.2"
HOST_FILTER = "StarlitCartoucheRegression"
SIMULATOR_TESTS = (
    "StarlitCartoucheExperienceTests/StarlitCartoucheRegressionGoldenFrameTests",
    "StarlitCartoucheExperienceTests/StarlitCartoucheRegressionMemoryTests",
)

SWIFT_TESTING_FAILURE = re.compile(r"✘ Test ([^\s(]+)\(")
XCTEST_FAILURE = re.compile(r"Test Case '-\[[^\]]*?(\w+)\]' failed")


def commands() -> list[tuple[str, list[str]]]:
    """The parts in run order, each as (name, argv); every argv runs from the repository root."""
    host = ["swift", "test", "--package-path", PACKAGE, "--filter", HOST_FILTER]
    # The memory class's footprint bound applies only in a process of its own (as for Aurora Loom, feature 309,
    # Colorfall Canyons, feature 348, Chrono Constellator, feature 358, Amethyst Escape, feature 368, Faceted
    # Forge, feature 378, Nocturne Garden, feature 388, Backwards Aurora, feature 398, Echo Cartographer,
    # feature 408, Harmonic Bridges, feature 418, Acoustic Constellator, feature 428, Moonlit Mechanism,
    # feature 438, and Voxel Origami, feature 448);
    # xcodebuild passes TEST_RUNNER_-prefixed variables to the test process without the prefix.
    simulator = ["env", "TEST_RUNNER_STARLIT_CARTOUCHE_MEMORY_ISOLATED=1", "python3",
                 "scripts/xcodebuild_package.py", "--package", PACKAGE, "--scheme", SCHEME, "--destination",
                 DESTINATION, "--action", "test", "--only-testing", *SIMULATOR_TESTS]
    return [("host", host), ("simulator", simulator)]


def first_failing(output: str) -> str | None:
    """The name of the first failing test in the output: swift-testing `✘ Test name(` or XCTest
    `Test Case '-[Module.Class name]' failed`, whichever comes first; None when no line matches."""
    for line in output.splitlines():
        for pattern in (SWIFT_TESTING_FAILURE, XCTEST_FAILURE):
            match = pattern.search(line)
            if match:
                return match.group(1)
    return None


def tee_run(cmd: list[str], cwd: Path) -> tuple[int, str]:
    """Runs cmd in cwd, streaming its combined output to stdout while collecting it; returns (exit code, output)."""
    lines: list[str] = []
    with subprocess.Popen(cmd, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                          encoding="utf-8", errors="replace", bufsize=1) as proc:
        assert proc.stdout is not None
        for line in proc.stdout:
            sys.stdout.write(line)
            sys.stdout.flush()
            lines.append(line)
        code = proc.wait()
    return code, "".join(lines)


def summary(part: str, code: int, output: str) -> str:
    """One summary line for a part."""
    if code == 0:
        return f"starlit-cartouche-regression {part}: PASS"
    name = first_failing(output) or "unknown"
    return f"starlit-cartouche-regression {part}: FAIL (exit {code}; first failing: {name})"


def main(argv: list[str] | None = None, root: Path = ROOT, run=tee_run) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dry-run", action="store_true", help="print the commands in order and run nothing")
    ap.add_argument("--skip-simulator", action="store_true", help="run only the host part")
    a = ap.parse_args(argv)
    parts = [p for p in commands() if not (a.skip_simulator and p[0] == "simulator")]
    if a.dry_run:
        for _, cmd in parts:
            print("$ " + " ".join(cmd))
        return 0
    ok = True
    lines = []
    for part, cmd in parts:
        print("$ " + " ".join(cmd), flush=True)
        code, output = run(cmd, root)
        ok = ok and code == 0
        lines.append(summary(part, code, output))
    for line in lines:
        print(line)
    print("starlit-cartouche-regression: " + ("PASS" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
