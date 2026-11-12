#!/usr/bin/env python3
"""Run the tests of an app scheme on a simulator chosen by runtime and kind, then the enumeration guard
(feature UA-F04 T-U04-002; FR-U04-080; specs/190-ua-f04-app-shell/contracts/shell-api.md).

  python3 scripts/xcodebuild_app.py --scheme VisualCore --runtime 27.2 --kind phone
  python3 scripts/xcodebuild_app.py --scheme VisualCore --runtime 26.5 --kind tablet \
      --only-testing VisualCoreTests/CatalogTests --log-name catalog-26.5-tablet

The simulator is the first available iPhone (`--kind phone`) or iPad (`--kind tablet`) of that iOS runtime, taken
from `xcrun simctl list -j devices available`; it is chosen by runtime, never by a name or identifier copied from
somewhere. There is no destination option: a physical device cannot be named (constitution V). The identifier is
passed to xcodebuild only; the output names the device and the runtime.

The complete xcodebuild output goes to `.autonomy/logs/app-tests/<log-name>.log` (default name
`<scheme>-<runtime>-<kind>`); its last lines are repeated on stdout. Afterwards
`check_test_enumeration.py --sources <sources> --log <log>` proves that every declared test ran and passed.

Exit codes: 0 tests and guard passed; 1 tests or guard failed; 2 bad input or no simulator of that runtime and kind.
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
KINDS = {"phone": "iPhone", "tablet": "iPad"}
TAIL_LINES = 15
SAFE_NAME = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]*$")


def pick_simulator(devices_json: dict, runtime: str, kind: str) -> tuple[str, str] | None:
    """(identifier, name) of the first available simulator of iOS `runtime` whose name starts with the device family
    of `kind`, or None when there is none. `devices_json` is the output of `xcrun simctl list -j devices available`."""
    prefix = KINDS.get(kind)
    if prefix is None:
        return None
    for key, devices in sorted(devices_json.get("devices", {}).items()):
        m = re.search(r"SimRuntime\.iOS-(\d+)-(\d+)$", key)
        if not m or f"{m.group(1)}.{m.group(2)}" != runtime:
            continue
        for d in devices:
            if d.get("isAvailable") and str(d.get("name", "")).startswith(prefix) and d.get("udid"):
                return d["udid"], d["name"]
    return None


def test_command(project: str, scheme: str, udid: str, derived: str, only: list[str] | None) -> list[str]:
    """The exact `xcodebuild test` command: simulator destination, explicit timeouts, unsigned."""
    cmd = ["xcodebuild", "test", "-project", project, "-scheme", scheme,
           "-destination", f"platform=iOS Simulator,id={udid}",
           "-test-timeouts-enabled", "YES", "-default-test-execution-time-allowance", "180",
           "-derivedDataPath", derived, "CODE_SIGNING_ALLOWED=NO"]
    return cmd + [f"-only-testing:{t}" for t in (only or [])]


def guard_classes(only_testing: list[str]) -> list[str]:
    """The test classes named by `--only-testing` ids of the form `Target/Class[/method]`; empty when an id names a
    whole target or a single method, because the guard can then only be run for everything or not at all."""
    classes: list[str] = []
    for item in only_testing:
        parts = item.split("/")
        if len(parts) != 2 or not parts[1]:
            return []
        if parts[1] not in classes:
            classes.append(parts[1])
    return classes


def enumeration_guard(sources: Path, log: Path, classes: list[str] | None = None) -> int:
    """Runs scripts/check_test_enumeration.py in this process; returns its exit code. With `classes` the guard is
    limited to these test classes (a run in chunks, each chunk naming whole classes)."""
    here = str(Path(__file__).resolve().parent)
    if here not in sys.path:
        sys.path.insert(0, here)
    import check_test_enumeration
    argv = ["--sources", str(sources), "--log", str(log)]
    if classes:
        argv += ["--only", *classes]
    return check_test_enumeration.main(argv)


def main(argv: list[str] | None = None, root: Path = ROOT, run=subprocess.run, guard=enumeration_guard) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--scheme", required=True)
    ap.add_argument("--runtime", required=True, help="iOS runtime of the simulator, such as 27.2")
    ap.add_argument("--kind", required=True, choices=sorted(KINDS))
    ap.add_argument("--project", default="VisualCore.xcodeproj")
    ap.add_argument("--only-testing", action="append", nargs="+", default=[], metavar="ID",
                    help="test identifier (target, target/class or target/class/method); may be repeated")
    ap.add_argument("--sources", default="Apps/VisualCore/Tests", help="test sources read by the enumeration guard")
    ap.add_argument("--log-name", help="log file name without extension (default <scheme>-<runtime>-<kind>)")
    ap.add_argument("--derived-data", help="default Build/DerivedData/app-<scheme>-<runtime>-<kind>")
    try:
        a = ap.parse_args(argv)
    except SystemExit as e:
        return 0 if e.code == 0 else 2
    only = [t for group in a.only_testing for t in group]
    tag = f"{a.scheme}-{a.runtime}-{a.kind}"
    log_name = a.log_name or tag
    what = f"{a.scheme} on iOS {a.runtime} {a.kind}"
    problems = []
    if not re.fullmatch(r"\d+\.\d+", a.runtime):
        problems.append("--runtime is <major>.<minor>, such as 27.2")
    if not SAFE_NAME.match(a.scheme):
        problems.append("--scheme is a plain scheme name")
    if not SAFE_NAME.match(log_name):
        problems.append("--log-name is a plain file name without folders")
    if not a.project.endswith(".xcodeproj"):
        problems.append("--project is an .xcodeproj")
    if any(not t or t.startswith("-") or "=" in t or "," in t for t in only):
        problems.append("--only-testing takes test identifiers such as Target/Class/testMethod")
    sources = (root / a.sources).resolve()
    if not sources.is_dir():
        problems.append(f"--sources is not a directory: {a.sources}")
    if problems:
        print(f"FAIL: {what} — bad input: " + "; ".join(problems))
        return 2

    try:
        listing = run(["xcrun", "simctl", "list", "-j", "devices", "available"], capture_output=True, text=True)
        devices = json.loads(listing.stdout) if listing.returncode == 0 else None
    except (OSError, ValueError):
        devices = None
    if not isinstance(devices, dict):
        print(f"FAIL: {what} — the simulator list could not be read (xcrun simctl list -j devices available)")
        return 2
    chosen = pick_simulator(devices, a.runtime, a.kind)
    if chosen is None:
        print(f"FAIL: {what} — no available {KINDS[a.kind]} simulator of iOS {a.runtime}")
        return 2
    udid, name = chosen

    derived = a.derived_data or f"Build/DerivedData/app-{tag}"
    cmd = test_command(a.project, a.scheme, udid, derived, only)
    log = root / ".autonomy" / "logs" / "app-tests" / f"{log_name}.log"
    log.parent.mkdir(parents=True, exist_ok=True)
    try:
        shown = str(log.relative_to(root))
    except ValueError:
        shown = str(log)
    print(f"simulator: {name} (iOS {a.runtime})")
    print("$ " + " ".join(cmd).replace(udid, f"<{name}>"), flush=True)
    try:
        with open(log, "w") as out:
            code = run(cmd, cwd=root, stdout=out, stderr=subprocess.STDOUT).returncode
    except OSError as e:
        print(f"FAIL: {what} — xcodebuild could not be started: {e}")
        return 1
    tail = log.read_text(errors="replace").splitlines()[-TAIL_LINES:]
    for line in tail:
        print("  | " + line.replace(udid, f"<{name}>"))
    sys.stdout.flush()
    if code != 0:
        print(f"FAIL: {what} — tests failed, xcodebuild exit {code} ({shown})")
        return 1
    classes = guard_classes(only)
    guard_code = guard(sources, log, classes) if classes else guard(sources, log)
    if guard_code != 0:
        print(f"FAIL: {what} — tests passed but the enumeration guard failed, exit {guard_code} ({shown})")
        return 1
    print(f"PASS: {what} — tests and enumeration guard passed ({shown})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
