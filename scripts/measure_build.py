#!/usr/bin/env python3
"""Build-time and app-size measurement for the unified VisualCore app. Deterministic, standard library only.

Feature UA-F10, task T-U10-020, requirement FR-U10-050. This tool NEVER starts Claude, calls a model or runs an
agent. It is the only writer of `docs/performance/build-measurements.json` (schema 1, append only, one record per
commit). Each record holds the wall-clock seconds of a clean Debug simulator build, of an incremental build after
touching one source file (its mtime only; contents are never modified), and the byte size of the Release
simulator app bundle. The file is written only after all three measurements succeed.

    python3 scripts/measure_build.py --milestone UA-F10        # measure and append one record
    python3 scripts/measure_build.py --check                   # validate the file only
    python3 scripts/measure_build.py --milestone M --dry-run   # print the commands, run nothing
    python3 scripts/measure_build.py ... [--root DIR] [--max-seconds 590]

Exit codes: 0 success (or already measured), 1 a build failed or timed out, 2 the file is damaged, of a newer
schema or malformed (nothing is written).
"""
from __future__ import annotations

import argparse
import datetime as _dt
import json
import os
import shlex
import subprocess
import sys
import time
from pathlib import Path

SCHEMA = 1
MEASUREMENTS = Path("docs/performance/build-measurements.json")
TOUCH_DIR = Path("Packages/ExperiencesCreative/GenerativeArtStudio/Core")
DESTINATION = "generic/platform=iOS Simulator"
CLEAN_DD = "Build/DerivedData/measure-clean"
RELEASE_DD = "Build/DerivedData/measure-release"
APP_REL = "Build/Products/Release-iphonesimulator/VisualCore.app"
FIELDS = {
    "commit": str,
    "date": str,
    "xcode_build": str,
    "clean_build_s": (int, float),
    "incremental_build_s": (int, float),
    "release_app_bytes": int,
    "milestone": str,
}


class FileError(Exception):
    """The measurements file is damaged, of another schema or malformed."""


def _build(actions: list[str], configuration: str, derived: str) -> list[str]:
    return ["xcodebuild", *actions, "-project", "VisualCore.xcodeproj", "-scheme", "VisualCore",
            "-configuration", configuration, "-destination", DESTINATION,
            "-derivedDataPath", derived, "CODE_SIGNING_ALLOWED=NO"]


def commands() -> dict[str, list[str]]:
    """Return the three build commands by name."""
    return {
        "clean build": _build(["clean", "build"], "Debug", CLEAN_DD),
        "incremental build": _build(["build"], "Debug", CLEAN_DD),
        "release build": _build(["build"], "Release", RELEASE_DD),
    }


def load(path: Path) -> dict:
    """Load and validate the measurements file; raise FileError on any defect."""
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        raise FileError(f"{path} is missing")
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise FileError(f"{path} is damaged: {exc}")
    if not isinstance(data, dict):
        raise FileError(f"{path}: top level is not an object")
    if data.get("schema") != SCHEMA:
        raise FileError(f"{path}: schema {data.get('schema')!r} is not {SCHEMA}")
    records = data.get("records")
    if not isinstance(records, list):
        raise FileError(f"{path}: records is not a list")
    for index, record in enumerate(records):
        if not isinstance(record, dict):
            raise FileError(f"{path}: record {index} is not an object")
        for field, kind in FIELDS.items():
            if field not in record:
                raise FileError(f"{path}: record {index} lacks {field}")
            value = record[field]
            if isinstance(value, bool) or not isinstance(value, kind):
                raise FileError(f"{path}: record {index} field {field} has type {type(value).__name__}")
    return data


def _output(result) -> str:
    out = getattr(result, "stdout", "") or ""
    return out.decode() if isinstance(out, bytes) else out


def _timed(name, argv, root, run, clock, max_seconds):
    start = clock()
    try:
        result = run(argv, cwd=str(root), timeout=max_seconds, capture_output=True, text=True)
    except subprocess.TimeoutExpired:
        raise RuntimeError(f"{name} timed out after {max_seconds} s")
    except OSError as exc:
        raise RuntimeError(f"{name} could not start: {exc}")
    elapsed = clock() - start
    if result.returncode != 0:
        raise RuntimeError(f"{name} failed with exit code {result.returncode}")
    return round(elapsed, 1)


def _query(argv, root, run, max_seconds) -> str:
    try:
        result = run(argv, cwd=str(root), timeout=max_seconds, capture_output=True, text=True)
    except (subprocess.TimeoutExpired, OSError) as exc:
        raise RuntimeError(f"{' '.join(argv)} failed: {exc}")
    if result.returncode != 0:
        raise RuntimeError(f"{' '.join(argv)} failed with exit code {result.returncode}")
    return _output(result)


def touch_file(root: Path) -> Path:
    """Return the first Swift file (sorted) of the touch directory."""
    files = sorted(p for p in (root / TOUCH_DIR).glob("*.swift") if p.is_file())
    if not files:
        raise RuntimeError(f"no Swift file under {TOUCH_DIR}")
    return files[0]


def app_bytes(root: Path) -> int:
    """Sum the bytes of every file in the Release simulator app bundle."""
    app = root / RELEASE_DD / APP_REL
    if not app.is_dir():
        raise RuntimeError(f"release app not found at {app}")
    return sum(p.stat().st_size for p in app.rglob("*") if p.is_file() and not p.is_symlink())


def main(argv=None, run=subprocess.run, clock=time.monotonic) -> int:
    """Entry point; `run` and `clock` are injectable for tests."""
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--milestone")
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--root", default=str(Path(__file__).resolve().parents[1]))
    parser.add_argument("--max-seconds", type=float, default=590)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args(argv)
    root = Path(args.root).resolve()
    path = root / MEASUREMENTS

    if not args.check and not args.milestone:
        parser.error("--milestone is required unless --check")
    try:
        data = load(path)
    except FileError as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 2
    if args.check:
        print(f"PASS: {len(data['records'])} records")
        return 0
    if args.dry_run:
        for name, cmd in commands().items():
            print(f"{name}: {shlex.join(cmd)}")
        print(f"touch: {TOUCH_DIR}/<first .swift>; size: {RELEASE_DD}/{APP_REL}")
        return 0

    try:
        commit = _query(["git", "rev-parse", "HEAD"], root, run, args.max_seconds).strip()
        if any(r["commit"] == commit for r in data["records"]):
            print(f"already measured: {commit}")
            return 0
        version = _query(["xcodebuild", "-version"], root, run, args.max_seconds)
        xcode_build = next((line.split("Build version", 1)[1].strip() for line in version.splitlines()
                            if "Build version" in line), "")
        if not xcode_build:
            raise RuntimeError("xcodebuild -version printed no build version")
        cmds = commands()
        clean_s = _timed("clean build", cmds["clean build"], root, run, clock, args.max_seconds)
        target = touch_file(root)
        now = time.time()
        os.utime(target, (now, now))
        incremental_s = _timed("incremental build", cmds["incremental build"], root, run, clock, args.max_seconds)
        _timed("release build", cmds["release build"], root, run, clock, args.max_seconds)
        size = app_bytes(root)
    except RuntimeError as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 1

    record = {"commit": commit, "date": _dt.date.today().isoformat(), "xcode_build": xcode_build,
              "clean_build_s": clean_s, "incremental_build_s": incremental_s, "release_app_bytes": size,
              "milestone": args.milestone}
    data["records"].append(record)
    tmp = path.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    os.replace(tmp, path)
    print(json.dumps(record))
    return 0


if __name__ == "__main__":
    sys.exit(main())
