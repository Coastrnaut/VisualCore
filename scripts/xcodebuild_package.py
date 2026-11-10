#!/usr/bin/env python3
"""Build or test a VisualCore SwiftPM package scheme with xcodebuild, from the repository root.

  python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering \
      --scheme VisualCoreRendering-Package --destination sim-27.2 --action test

Destinations: `generic-sim`, `generic-ios`, or `sim-<runtime>` (first available iPhone on that iOS
runtime, chosen by runtime, never by a hard-coded name). Physical devices are refused (Constitution V).
Output goes straight to stdout/stderr (run-check writes it to a file); DerivedData lives in the
gitignored Build/DerivedData/<package>-<dest>; tests get a result bundle in .autonomy/xcresults/ and
explicit timeouts.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def simulator(runtime: str) -> str:
    data = json.loads(subprocess.run(["xcrun", "simctl", "list", "-j", "devices", "available"],
                                     capture_output=True, text=True, check=True).stdout)
    for key, devices in sorted(data["devices"].items()):
        m = re.search(r"SimRuntime\.iOS-(\d+)-(\d+)$", key)
        if m and f"{m.group(1)}.{m.group(2)}" == runtime:
            for d in devices:
                if d.get("isAvailable") and d["name"].startswith("iPhone"):
                    return d["udid"]
    raise SystemExit(f"no available iPhone simulator for iOS {runtime}")


def destination(name: str) -> str:
    if name == "generic-sim":
        return "generic/platform=iOS Simulator"
    if name == "generic-ios":
        return "generic/platform=iOS"
    if name.startswith("sim-"):
        return f"platform=iOS Simulator,id={simulator(name[4:])}"
    raise SystemExit("refused destination (simulator/generic only): " + name)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--package", required=True)
    ap.add_argument("--scheme", required=True)
    ap.add_argument("--destination", required=True)
    ap.add_argument("--action", choices=["build", "test"], default="build")
    ap.add_argument("--result-name", help="xcresult bundle name (test only)")
    args = ap.parse_args()
    pkg = (ROOT / args.package).resolve()
    if not (pkg / "Package.swift").is_file() or not pkg.is_relative_to(ROOT):
        raise SystemExit("not a package inside this repository: " + args.package)
    tag = f"{pkg.name}-{args.destination}"
    cmd = ["xcodebuild", args.action, "-scheme", args.scheme, "-destination", destination(args.destination),
           "-derivedDataPath", str(ROOT / "Build" / "DerivedData" / tag), "CODE_SIGNING_ALLOWED=NO"]
    if args.action == "test":
        name = args.result_name or f"{tag}-{dt.datetime.now().strftime('%Y%m%dT%H%M%S')}"
        bundle = ROOT / ".autonomy" / "xcresults" / f"{name}.xcresult"
        bundle.parent.mkdir(parents=True, exist_ok=True)
        cmd += ["-resultBundlePath", str(bundle), "-test-timeouts-enabled", "YES",
                "-default-test-execution-time-allowance", "180"]
    print("$ (cd", args.package, ")", " ".join(cmd), flush=True)
    return subprocess.run(cmd, cwd=pkg, check=False).returncode


if __name__ == "__main__":
    sys.exit(main())
