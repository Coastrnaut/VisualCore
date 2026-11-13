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

With `--result-name NAME` xcodebuild also writes its result bundle to `.autonomy/xcresults/NAME.xcresult`
(feature UA-F09 T-U09-001, FR-U09-023); an older bundle of that name is removed first, because xcodebuild refuses to
write into an existing one. Without the option no result bundle path is passed.

Exit codes: 0 tests and guard passed; 1 tests or guard failed; 2 bad input or no simulator of that runtime and kind.
"""
from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
KINDS = {"phone": "iPhone", "tablet": "iPad"}
TAIL_LINES = 15
SAFE_NAME = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]*$")


def phone_widths(run=subprocess.run, load=None) -> dict[str, float]:
    """Screen width in points for every simulator device type that states one, by device type identifier. Read from
    `xcrun simctl list -j devicetypes` and each type's `capabilities.plist`; empty when that cannot be read."""
    import plistlib
    load = load or (lambda path: plistlib.loads(Path(path).read_bytes()))
    try:
        listing = run(["xcrun", "simctl", "list", "-j", "devicetypes"], capture_output=True, text=True)
        types = json.loads(listing.stdout).get("devicetypes", []) if listing.returncode == 0 else []
    except (OSError, ValueError):
        return {}
    widths: dict[str, float] = {}
    for t in types:
        try:
            data = load(str(Path(t["bundlePath"]) / "Contents" / "Resources" / "capabilities.plist"))
            screen = data.get("capabilities", data)["ScreenDimensionsCapability"]
            widths[t["identifier"]] = float(screen["main-screen-width"]) / float(screen["main-screen-scale"])
        except (OSError, ValueError, KeyError, TypeError, ZeroDivisionError):
            continue
    return widths


def pick_simulator(devices_json: dict, runtime: str, kind: str,
                   widths: dict[str, float] | None = None) -> tuple[str, str] | None:
    """(identifier, name) of an available simulator of iOS `runtime` whose name starts with the device family of
    `kind`, or None when there is none. A phone is the narrowest one whose device type has a width in `widths`
    (FR-U04-035 asks for the smallest phone; the first of equal width wins); without widths, and for a tablet, it is
    the first one. `devices_json` is the output of `xcrun simctl list -j devices available`."""
    prefix = KINDS.get(kind)
    if prefix is None:
        return None
    found = []
    for key, devices in sorted(devices_json.get("devices", {}).items()):
        m = re.search(r"SimRuntime\.iOS-(\d+)-(\d+)$", key)
        if not m or f"{m.group(1)}.{m.group(2)}" != runtime:
            continue
        for d in devices:
            if d.get("isAvailable") and str(d.get("name", "")).startswith(prefix) and d.get("udid"):
                found.append(d)
    if not found:
        return None
    if kind == "phone" and widths:
        found.sort(key=lambda d: widths.get(d.get("deviceTypeIdentifier", ""), float("inf")))   # stable
    return found[0]["udid"], found[0]["name"]


ACTIONS = ("test", "build-for-testing", "test-without-building")


def test_command(project: str, scheme: str, udid: str, derived: str, only: list[str] | None,
                 result_bundle: str | None = None, action: str = "test") -> list[str]:
    """The exact `xcodebuild <action>` command: simulator destination, explicit timeouts, unsigned; with
    `result_bundle` also `-resultBundlePath <result_bundle>`. `build-for-testing` once and then
    `test-without-building` per chunk, in the same DerivedData, saves the build and install of every chunk."""
    cmd = ["xcodebuild", action, "-project", project, "-scheme", scheme,
           "-destination", f"platform=iOS Simulator,id={udid}",
           "-test-timeouts-enabled", "YES", "-default-test-execution-time-allowance", "180",
           "-derivedDataPath", derived, "CODE_SIGNING_ALLOWED=NO"]
    if result_bundle:
        cmd += ["-resultBundlePath", result_bundle]
    return cmd + [f"-only-testing:{t}" for t in (only or [])]


def guard_classes(only_testing: list[str]) -> list[str]:
    """The guard filter named by `--only-testing` ids: `Class` for `Target/Class`, `Class/method` for
    `Target/Class/method`; empty when an id names a whole target, because the guard then checks everything."""
    classes: list[str] = []
    for item in only_testing:
        parts = item.split("/")
        if len(parts) not in (2, 3) or not all(parts[1:]):
            return []
        key = "/".join(parts[1:])
        if key not in classes:
            classes.append(key)
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


def main(argv: list[str] | None = None, root: Path = ROOT, run=subprocess.run, guard=enumeration_guard,
         widths=phone_widths) -> int:
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
    ap.add_argument("--max-seconds", type=int, default=540,
                    help="stop the run after this many seconds and name the test it was on (default 540, below the "
                         "ten-minute limit of one foreground command); 0 disables the limit")
    ap.add_argument("--action", choices=ACTIONS, default="test",
                    help="test (default); build-for-testing builds once for later test-without-building chunks")
    ap.add_argument("--result-name", metavar="NAME",
                    help="also write the result bundle to .autonomy/xcresults/NAME.xcresult (an older one is removed)")
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
    if a.result_name is not None and not SAFE_NAME.match(a.result_name):
        problems.append("--result-name is a plain file name without folders")
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
    chosen = pick_simulator(devices, a.runtime, a.kind, widths() if a.kind == "phone" else None)
    if chosen is None:
        print(f"FAIL: {what} — no available {KINDS[a.kind]} simulator of iOS {a.runtime}")
        return 2
    udid, name = chosen

    derived = a.derived_data or f"Build/DerivedData/app-{tag}"
    bundle = None
    if a.result_name is not None:
        bundle = root / ".autonomy" / "xcresults" / f"{a.result_name}.xcresult"
        if bundle.is_dir() and not bundle.is_symlink():
            shutil.rmtree(bundle)
        elif bundle.exists() or bundle.is_symlink():
            bundle.unlink()
        bundle.parent.mkdir(parents=True, exist_ok=True)
    cmd = test_command(a.project, a.scheme, udid, derived, only, str(bundle) if bundle else None, a.action)
    log = root / ".autonomy" / "logs" / "app-tests" / f"{log_name}.log"
    log.parent.mkdir(parents=True, exist_ok=True)
    try:
        shown = str(log.relative_to(root))
    except ValueError:
        shown = str(log)
    print(f"simulator: {name} (iOS {a.runtime})")
    print("$ " + " ".join(cmd).replace(udid, f"<{name}>"), flush=True)
    limit = a.max_seconds if a.max_seconds and a.max_seconds > 0 else None
    try:
        with open(log, "w") as out:
            code = run(cmd, cwd=root, stdout=out, stderr=subprocess.STDOUT, timeout=limit).returncode
    except subprocess.TimeoutExpired:
        # The run did not end in time: a hung test, or more tests than fit. Say where it was and how to go on.
        started = re.findall(r"Test Case '-\[(\S+ \S+)\]' started", log.read_text(errors="replace"))
        where = f"the last test started was {started[-1]}" if started else "no test had started (still building)"
        print(f"FAIL: {what} — stopped after {limit} s: {where}. Split the run into smaller chunks with "
              f"--only-testing, or look for a test that never ends ({shown})")
        return 3
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
    if a.action == "build-for-testing":
        print(f"PASS: {what} — built for testing ({shown})")
        return 0
    classes = guard_classes(only)
    guard_code = guard(sources, log, classes) if classes else guard(sources, log)
    if guard_code != 0:
        print(f"FAIL: {what} — tests passed but the enumeration guard failed, exit {guard_code} ({shown})")
        return 1
    print(f"PASS: {what} — tests and enumeration guard passed ({shown})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
