#!/usr/bin/env python3
"""VisualCore release check (feature 010 T-F908; FR-F908, SC-F908; contract
specs/010-stabilization-release/contracts/release-contract.md).

Runs every release gate in order and writes one log per step directly to a file (no pipes) plus a JSON summary:

  python3 scripts/release_check.py                 # everything
  python3 scripts/release_check.py --list          # steps and exact commands
  python3 scripts/release_check.py --only docs licenses
  python3 scripts/release_check.py --skip reference-baseline --json out.json

Steps cover: docs, compliance, dependency rules, public API, documented API (every consumer), licenses, script
tests, host Swift tests (VisualCore, GardenKit), rendering/effects/automation simulator tests on iOS 27.2 and 26.5,
Showcase / InteractiveDemo / SecondConsumer / ProjectMReference tests on both runtimes, the reference baseline
and the read-only check, the Release symbol check (zero automation symbols) and the ProjectM-independence
audit of the shipping Showcase. Simulators and generic iOS only;
physical devices are never used here (constitution V). Exit 0 only when every selected step passed.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import subprocess
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PY = sys.executable or "python3"
RUNTIMES = ["27.2", "26.5"]
STEP_TIMEOUT = 3600


@dataclass
class Step:
    name: str
    argv: list[str]
    cwd: Path = ROOT
    timeout: int = STEP_TIMEOUT
    needs_simulator: str | None = None   # runtime whose UDID replaces "{udid}" in argv


@dataclass
class Result:
    name: str
    status: str            # pass | fail | timeout | error
    exit_code: int | None
    seconds: float
    log: str
    command: list[str] = field(default_factory=list)


def simulator_udid(runtime: str) -> str:
    data = json.loads(subprocess.run(["xcrun", "simctl", "list", "-j", "devices", "available"],
                                     capture_output=True, text=True, check=True).stdout)
    for key, devices in sorted(data["devices"].items()):
        m = re.search(r"SimRuntime\.iOS-(\d+)-(\d+)$", key)
        if m and f"{m.group(1)}.{m.group(2)}" == runtime:
            for d in devices:
                if d.get("isAvailable") and d["name"].startswith("iPhone"):
                    return d["udid"]
    raise RuntimeError(f"no available iPhone simulator for iOS {runtime}")


def tag(runtime: str) -> str:
    return "ios" + runtime.split(".")[0]


def xcode_test(project: str, scheme: str, runtime: str, derived: str, stamp: str, name: str) -> Step:
    return Step(name, ["xcodebuild", "test", "-project", project, "-scheme", scheme,
                       "-destination", "platform=iOS Simulator,id={udid}",
                       "-derivedDataPath", f"Build/DerivedData/{derived}",
                       "-resultBundlePath", f".autonomy/xcresults/release-{name}-{stamp}.xcresult",
                       "-test-timeouts-enabled", "YES", "-default-test-execution-time-allowance", "180",
                       "CODE_SIGNING_ALLOWED=NO"], needs_simulator=runtime)


# Feature 191 (UA-F05). Experience sources: the debug experience and the sample core today; every experience
# module is added here when it is integrated.
STORAGE_RULE_SOURCES = ["Apps/VisualCore/App/DebugSupport/DebugExperience.swift",
                        "Packages/VisualCore/Sources/VisualCoreTestSupport/SampleExperienceCore.swift",
                        # The adapters of the adopted experiences (feature 193, UA-F07).
                        "Apps/GenerativeArtStudio/GenerativeArtStudioAdapter/Core", "Apps/GenerativeArtStudio/GenerativeArtStudioAdapter/Experience",
                       "Apps/FluidArtPlayground/FluidArtPlaygroundAdapter/Core",
                       "Apps/FluidArtPlayground/FluidArtPlaygroundAdapter/Experience"]
# The shipped sources that read stored data.
STORED_DATA_SOURCES = ["Packages/VisualCore/Sources/VisualCoreExperience/SavedStateStore.swift",
                       "Packages/VisualCore/Sources/VisualCoreExperience/ExperienceStorage.swift",
                       "Packages/VisualCore/Sources/VisualCoreExperience/ExperienceSnapshot.swift",
                       "Packages/VisualCore/Sources/VisualCoreExperience/ShellModel.swift",
                       "Packages/VisualCore/Sources/VisualCoreExperience/SnapshotMigrationCheck.swift",
                       "Packages/VisualCore/Sources/VisualCoreExperience/ContainerInventory.swift",
                       "Apps/VisualCore/App/PreferencesStore.swift", "Apps/VisualCore/App/AppModel.swift",
                       "Apps/VisualCore/App/ExperienceDataStore.swift",
                       "Apps/GenerativeArtStudio/GenerativeArtStudioAdapter/Core", "Apps/GenerativeArtStudio/GenerativeArtStudioAdapter/Experience",
                       "Apps/FluidArtPlayground/FluidArtPlaygroundAdapter/Core",
                       "Apps/FluidArtPlayground/FluidArtPlaygroundAdapter/Experience"]


def steps(stamp: str) -> list[Step]:
    s = [
        Step("docs", [PY, "scripts/validate_docs.py"]),
        Step("compliance", [PY, "scripts/check_compliance.py"]),
        # Feature 192 (UA-F06): budgets are proposals with their confirming device measurement; simulator numbers
        # carry the notice.
        Step("performance-docs", [PY, "scripts/check_performance_docs.py"]),
        # Feature 191 (UA-F05): experience sources reach storage only through their handle, and no shipped path
        # that reads stored data uses a deliberate crash.
        Step("storage-rule", [PY, "scripts/check_app_isolation.py", "--no-direct-storage", *STORAGE_RULE_SOURCES]),
        Step("stored-data-rule", [PY, "scripts/check_app_isolation.py", "--no-crash-on-stored-data",
                                  *STORED_DATA_SOURCES]),
        Step("dependencies", [PY, "scripts/check_dependencies.py"]),
        Step("public-api", [PY, "scripts/check_public_api.py"]),
        Step("documented-api-showcase", [PY, "scripts/check_documented_api.py", "--sources", "Showcase/App"]),
        Step("documented-api-interactive-demo", [PY, "scripts/check_documented_api.py", "--sources", "Harnesses/InteractiveDemo"]),
        Step("documented-api-second-consumer", [PY, "scripts/check_documented_api.py", "--sources", "Harnesses/SecondConsumer"]),
        Step("licenses", [PY, "scripts/check_licenses.py"]),
        # Every app's Phase 00 VisualCore contract (feature 011): all citations resolve, gaps owned, decision recorded.
        Step("app-contracts", [PY, "-c", "import pathlib,subprocess,sys;apps=sorted(p.parent.name for p in "
                               "pathlib.Path('docs/apps').glob('*/visualcore-contract.json'));"
                               "sys.exit(max([subprocess.run([sys.executable,'scripts/check_app_contract.py','--app',a]).returncode "
                               "for a in apps] or [0]))"]),
        Step("script-tests", [PY, "scripts/test_scripts.py"]),
        # Feature UA-F09 T-U09-026 (FR-U09-032, FR-U09-050 to FR-U09-055): the evidence validator's own cases, and the
        # audits of the shipped sources (markers, raster files, reducer bypass, content counts, direct GL, network).
        Step("evidence-self-test", [PY, "scripts/check_evidence.py", "--self-test"]),
        Step("verify-audits", [PY, "scripts/verify_experiences.py", "--audits"]),
        Step("host-visualcore", ["swift", "test", "--package-path", "Packages/VisualCore"]),
        Step("host-gardenkit", ["swift", "test", "--package-path", "Harnesses/SecondConsumer/GardenKit"]),
        Step("xcodegen", [PY, "-c", "import subprocess,sys;[subprocess.run(['xcodegen','generate','--spec',p],check=True) "
                                    "for p in sys.argv[1:]]", "project.yml", "Harnesses/InteractiveDemo/InteractiveDemo.yml",
                          "Harnesses/SecondConsumer/SecondConsumer.yml", "Harnesses/ProjectMReference/ProjectMReference.yml"]),
        # Feature UA-F04 T-U04-029 (FR-U04-002): the unified app builds unsigned for the generic simulator.
        Step("visualcore-app-build", ["xcodebuild", "build", "-project", "VisualCore.xcodeproj", "-scheme", "VisualCore",
                                      "-destination", "generic/platform=iOS Simulator",
                                      "-derivedDataPath", "Build/DerivedData/release-VisualCore-sim",
                                      "CODE_SIGNING_ALLOWED=NO"]),
    ]
    for rt in RUNTIMES:
        t = tag(rt)
        s.append(Step(f"rendering-sim-{t}", [PY, "scripts/xcodebuild_package.py", "--package", "Packages/VisualCoreRendering",
                                             "--scheme", "VisualCoreRendering-Package", "--destination", f"sim-{rt}",
                                             "--action", "test", "--result-name", f"release-rendering-{t}-{stamp}"]))
        s.append(xcode_test("VisualCore.xcodeproj", "Showcase", rt, "release-Showcase", stamp, f"showcase-{t}"))
        s.append(xcode_test("Harnesses/InteractiveDemo/InteractiveDemo.xcodeproj", "InteractiveDemo", rt,
                            "release-InteractiveDemo", stamp, f"interactive-demo-{t}"))
        s.append(xcode_test("Harnesses/SecondConsumer/SecondConsumer.xcodeproj", "SecondConsumer", rt,
                            "release-SecondConsumer", stamp, f"second-consumer-{t}"))
        s.append(xcode_test("Harnesses/ProjectMReference/ProjectMReference.xcodeproj", "ProjectMReference", rt,
                            "release-ProjectMReference", stamp, f"projectm-reference-{t}"))
    for step in ["engine-xcframework", "build-projectm-ios-sim", "test-anglerendering-ios27", "test-anglerendering-ios26"]:
        s.append(Step(f"reference-{step}", [PY, "scripts/run_reference_baseline.py", "--step", step]))
    s.append(Step("reference-clean", [PY, "scripts/check_reference_clean.py"]))
    release_app = "Build/DerivedData/release-Showcase-Release/Build/Products/Release-iphoneos/Showcase.app"
    s.append(Step("showcase-release-build", ["xcodebuild", "build", "-project", "VisualCore.xcodeproj", "-scheme", "Showcase",
                                             "-configuration", "Release", "-destination", "generic/platform=iOS",
                                             "-derivedDataPath", "Build/DerivedData/release-Showcase-Release",
                                             "CODE_SIGNING_ALLOWED=NO"]))
    s.append(Step("release-symbols", [PY, "scripts/check_release_symbols.py", "--app", release_app]))
    # FR-F904: explicit ProjectM-independence audit of the shipping Showcase (spec, packages, imports, binary).
    s.append(Step("projectm-independence", [PY, "scripts/audit_showcase_dependencies.py", "--root", ".", "--app", release_app]))
    s += app_domain_steps()
    for rt in RUNTIMES:
        s += app_test_steps(rt, stamp)
    s += app_release_steps()
    return s


def kebab(name: str) -> str:
    """`FluidArtPlayground` → `fluid-art-playground`."""
    return re.sub(r"(?<=[a-z0-9])(?=[A-Z])", "-", name).lower()


def app_dirs(root: Path = ROOT) -> list[Path]:
    """Every app under Apps/ that has an App/ source folder."""
    return sorted(p for p in root.glob("Apps/*") if (p / "App").is_dir())


def app_domain_steps(root: Path = ROOT) -> list[Step]:
    """Per app (feature 019 T-A02-115): the documented-API and isolation (no EGL, offline) checks over its sources, and
    host tests of every GPU-free
    domain package `Apps/<App>/<Name>Core` (packages are named `<App>Core` so SwiftPM identities never collide)."""
    out: list[Step] = []
    for app in app_dirs(root):
        rel = str(app.relative_to(root))
        out.append(Step(f"documented-api-{kebab(app.name)}", [PY, "scripts/check_documented_api.py", "--sources", rel]))
        out.append(Step(f"isolation-{kebab(app.name)}", [PY, "scripts/check_app_isolation.py", "--app", rel,
                                                        "--require-sources"]))
        for manifest in sorted(app.glob("*/Package.swift")):
            pkg = manifest.parent.name
            name = kebab(pkg) if pkg.startswith(app.name) else f"{kebab(app.name)}-{kebab(pkg)}"
            out.append(Step(f"host-{name}", ["swift", "test", "--package-path", str(manifest.parent.relative_to(root))]))
    return out


def app_test_steps(runtime: str, stamp: str, root: Path = ROOT) -> list[Step]:
    """Per app with a same-named scheme in project.yml (feature 019 T-A02-115): unit and UI tests on `runtime`."""
    spec = (root / "project.yml").read_text() if (root / "project.yml").is_file() else ""
    schemes = set(re.findall(r"^  ([A-Za-z0-9]+):\n    build:", spec, flags=re.M))
    return [xcode_test("VisualCore.xcodeproj", app.name, runtime, app.name, stamp, f"app-{kebab(app.name)}-{tag(runtime)}")
            for app in app_dirs(root) if app.name in schemes]


def app_release_steps(root: Path = ROOT) -> list[Step]:
    """Per app with docs/apps/<slug>/release.json (feature 017 T-A01-602): an unsigned generic-iOS Release build, then
    the shipping-symbol, privacy-manifest and release-readiness checks on the built app."""
    out: list[Step] = []
    for config in sorted(root.glob("docs/apps/*/release.json")):
        slug = config.parent.name
        try:
            data = json.loads(config.read_text())
            scheme = data["scheme"]
        except (ValueError, KeyError):
            continue
        derived = f"Build/DerivedData/release-{scheme}-Release"
        app = f"{derived}/Build/Products/Release-iphoneos/{scheme}.app"
        out.append(Step(f"app-release-{slug}", [PY, "-c",
            "import subprocess,sys;a=sys.argv[1:];"
            "steps=[['xcodebuild','build','-project','VisualCore.xcodeproj','-scheme',a[0],'-configuration','Release',"
            "'-destination','generic/platform=iOS','-derivedDataPath',a[1],'CODE_SIGNING_ALLOWED=NO'],"
            "[sys.executable,'scripts/check_release_symbols.py','--app',a[2]],"
            "[sys.executable,'scripts/check_privacy_manifest.py','--app',a[2]],"
            "[sys.executable,'scripts/check_app_release.py','--app',a[2],'--config',a[3]]];"
            "sys.exit(next((r for r in (subprocess.run(c).returncode for c in steps) if r),0))",
            scheme, derived, app, str(config.relative_to(root))]))
    return out


def missing_projects(argv: list[str], cwd: Path) -> list[tuple[Path, Path]]:
    """(project, XcodeGen spec) for every `.xcodeproj` named in `argv` that does not exist yet. Generated projects are
    gitignored, so a fresh clone has none (setup.md §8, Mac Studio 2026-11-11). The spec is `<dir>/<name>.yml`, or
    `<dir>/project.yml` for VisualCore.xcodeproj."""
    out: list[tuple[Path, Path]] = []
    for arg in argv:
        if not arg.endswith(".xcodeproj"):
            continue
        project = (cwd / arg) if not Path(arg).is_absolute() else Path(arg)
        if project.exists():
            continue
        for spec in (project.with_suffix(".yml"), project.parent / "project.yml"):
            if spec.is_file():
                if (project, spec) not in out:
                    out.append((project, spec))
                break
    return out


def run_step(step: Step, log_dir: Path, udids: dict[str, str]) -> Result:
    log = log_dir / f"{step.name}.log"
    argv = list(step.argv)
    start = time.time()
    with open(log, "w") as out:
        try:
            if step.needs_simulator:
                if step.needs_simulator not in udids:
                    udids[step.needs_simulator] = simulator_udid(step.needs_simulator)
                argv = [a.replace("{udid}", udids[step.needs_simulator]) for a in argv]
            code = 0
            for project, spec in missing_projects(argv, step.cwd):
                out.write(f"Project missing ({project.name}); generating it first:\n$ xcodegen generate --spec {spec}\n")
                out.flush()
                code = subprocess.run(["xcodegen", "generate", "--spec", str(spec)], cwd=spec.parent, stdout=out,
                                      stderr=subprocess.STDOUT, timeout=step.timeout).returncode
                if code != 0:
                    break
            if code == 0:
                out.write("$ " + " ".join(argv) + "\n")
                out.flush()
                code = subprocess.run(argv, cwd=step.cwd, stdout=out, stderr=subprocess.STDOUT, timeout=step.timeout).returncode
            status = "pass" if code == 0 else "fail"
        except subprocess.TimeoutExpired:
            code, status = None, "timeout"
            out.write(f"\nTIMEOUT after {step.timeout}s\n")
        except (OSError, RuntimeError) as e:
            code, status = None, "error"
            out.write(f"\nERROR: {e}\n")
    return Result(step.name, status, code, round(time.time() - start, 1), str(log), argv)


def select(all_steps: list[Step], only: list[str] | None, skip: list[str] | None) -> list[Step]:
    names = {s.name for s in all_steps}
    for n in (only or []) + (skip or []):
        if n not in names:
            raise SystemExit(f"unknown step: {n} (see --list)")
    chosen = [s for s in all_steps if not only or s.name in only]
    return [s for s in chosen if s.name not in (skip or [])]


def summarize(results: list[Result]) -> dict:
    passed = sum(r.status == "pass" for r in results)
    return {"schema": 1, "result": "pass" if results and passed == len(results) else "fail",
            "passed": passed, "total": len(results), "steps": [r.__dict__ for r in results]}


def main(argv: list[str] | None = None, step_factory=steps) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--only", nargs="+")
    ap.add_argument("--skip", nargs="+")
    ap.add_argument("--json", type=Path, help="summary path (default: the run's log directory)")
    ap.add_argument("--log-dir", type=Path)
    a = ap.parse_args(argv)
    stamp = dt.datetime.now().strftime("%Y%m%dT%H%M%S")
    chosen = select(step_factory(stamp), a.only, a.skip)
    if a.list:
        for s in chosen:
            print(f"{s.name}: {' '.join(s.argv)}")
        return 0
    log_dir = a.log_dir or ROOT / ".autonomy" / "logs" / f"release-check-{stamp}"
    log_dir.mkdir(parents=True, exist_ok=True)
    udids: dict[str, str] = {}
    results = []
    for s in chosen:
        print(f"[{len(results) + 1}/{len(chosen)}] {s.name} …", flush=True)
        r = run_step(s, log_dir, udids)
        results.append(r)
        print(f"    {r.status.upper()} ({r.seconds}s) {r.log}", flush=True)
    summary = summarize(results)
    path = a.json or log_dir / "summary.json"
    path.write_text(json.dumps(summary, indent=2) + "\n")
    print(f"\n{'step':42} {'status':8} seconds")
    for r in results:
        print(f"{r.name:42} {r.status:8} {r.seconds}")
    print(f"\n{summary['result'].upper()}: {summary['passed']}/{summary['total']} steps passed; summary {path}")
    return 0 if summary["result"] == "pass" else 1


if __name__ == "__main__":
    sys.exit(main())
