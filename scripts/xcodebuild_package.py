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


ONLY_TESTING = re.compile(r"[A-Za-z_][A-Za-z0-9_]*(/[A-Za-z_][A-Za-z0-9_]*){0,2}$")


def test_options(language: str | None, region: str | None, only: list[str] | None = None) -> list[str]:
    """The xcodebuild options of a test run: explicit timeouts, the language and region when they are given
    (feature 187: the catalog search must give the same results under another language setting), and one
    `-only-testing:` per id of `only` (feature 192: a single test class, such as the endurance run, in one short
    command). An id is `Target`, `Target/Class` or `Target/Class/method`."""
    options = ["-test-timeouts-enabled", "YES", "-default-test-execution-time-allowance", "180"]
    for item in only or []:
        if not ONLY_TESTING.match(item):
            raise SystemExit("--only-testing takes ids such as Target/Class: " + item)
        options.append("-only-testing:" + item)
    if language:
        if not (len(language) in (2, 3) and language.isalpha() and language.islower()):
            raise SystemExit("--test-language is an ISO 639 code such as tr")
        options += ["-testLanguage", language]
    if region:
        if not (len(region) == 2 and region.isalpha() and region.isupper()):
            raise SystemExit("--test-region is an ISO 3166-1 code such as TR")
        options += ["-testRegion", region]
    return options


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--package", required=True)
    ap.add_argument("--scheme", required=True)
    ap.add_argument("--destination", required=True)
    ap.add_argument("--action", choices=["build", "test"], default="build")
    ap.add_argument("--result-name", help="xcresult bundle name (test only)")
    ap.add_argument("--test-language", help="ISO 639-1 language to run the tests in (test only; xcodebuild -testLanguage)")
    ap.add_argument("--test-region", help="ISO 3166-1 region to run the tests in (test only; xcodebuild -testRegion)")
    ap.add_argument("--only-testing", nargs="+", default=[], metavar="ID",
                    help="run only these tests (test only): Target, Target/Class or Target/Class/method")
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
        cmd += ["-resultBundlePath", str(bundle)] + test_options(args.test_language, args.test_region,
                                                                 args.only_testing)
    elif args.test_language or args.test_region or args.only_testing:
        raise SystemExit("--test-language, --test-region and --only-testing need --action test")
    print("$ (cd", args.package, ")", " ".join(cmd), flush=True)
    return subprocess.run(cmd, cwd=pkg, check=False).returncode


if __name__ == "__main__":
    sys.exit(main())
