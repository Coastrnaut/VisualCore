#!/usr/bin/env python3
"""Run a VisualCore AutomationRunner mode in an app on an iOS *simulator* and copy its JSON report out
(feature 010 T-F904/T-F909; FR-F914). Simulator results are rehearsal and environment data, never device
evidence (constitution V). Physical devices are refused here; the device campaign uses run_device_campaign.py.

  python3 scripts/run_automation_sim.py --app Build/.../Showcase.app --runtime 27.2 --mode smoke --out <dir>

Steps: pick the first available iPhone on the runtime (never a hard-coded name), boot it, install the app,
remove old reports, `simctl launch --terminate-running-process` with SIMCTL_CHILD_VISUALCORE_AUTORUN=<mode>,
wait for the report in the app's data container (timeout), copy it to --out and print its result.
Exit 0 when the report says `pass`, 1 for fail/error, 3 on timeout. `--dry-run` prints the commands.
"""
from __future__ import annotations

import argparse
import json
import plistlib
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

REPORT_PREFIX = "visualcore-automation-"


def pick_simulator(devices_json: dict, runtime: str) -> str:
    for key, devices in sorted(devices_json["devices"].items()):
        m = re.search(r"SimRuntime\.iOS-(\d+)-(\d+)$", key)
        if m and f"{m.group(1)}.{m.group(2)}" == runtime:
            for d in devices:
                if d.get("isAvailable") and d["name"].startswith("iPhone"):
                    return d["udid"]
    raise SystemExit(f"no available iPhone simulator for iOS {runtime}")


def bundle_id(app: Path) -> str:
    with open(app / "Info.plist", "rb") as f:
        return plistlib.load(f)["CFBundleIdentifier"]


def launch_command(udid: str, bundle: str) -> list[str]:
    return ["xcrun", "simctl", "launch", "--terminate-running-process", udid, bundle]


def launch_env(mode: str, frames: int | None) -> dict[str, str]:
    env = {"SIMCTL_CHILD_VISUALCORE_AUTORUN": mode}
    if frames:
        env["SIMCTL_CHILD_VISUALCORE_AUTORUN_FRAMES"] = str(frames)
    return env


def newest_report(documents: Path, mode: str) -> Path | None:
    found = sorted(documents.glob(f"{REPORT_PREFIX}{mode}-*.json")) if documents.is_dir() else []
    return found[-1] if found else None


def run(cmd: list[str], **kw) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, capture_output=True, text=True, **kw)


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--app", required=True, type=Path, help="built simulator .app")
    ap.add_argument("--runtime", required=True, help="iOS simulator runtime, e.g. 27.2")
    ap.add_argument("--mode", required=True)
    ap.add_argument("--frames", type=int)
    ap.add_argument("--out", required=True, type=Path)
    ap.add_argument("--timeout", type=float, default=120)
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args(argv)
    if a.dry_run:
        udid, bundle = "<SIMULATOR_UDID>", "<BUNDLE_ID>"
        try:
            bundle = bundle_id(a.app)
        except OSError:
            pass
        env = " ".join(f"{k}={v}" for k, v in launch_env(a.mode, a.frames).items())
        for c in (["xcrun", "simctl", "boot", udid], ["xcrun", "simctl", "install", udid, str(a.app)]):
            print("$", " ".join(c))
        print("$", env, " ".join(launch_command(udid, bundle)))
        print(f"# wait ≤{a.timeout:.0f}s for Documents/{REPORT_PREFIX}{a.mode}-*.json, copy to {a.out}")
        return 0
    udid = pick_simulator(json.loads(run(["xcrun", "simctl", "list", "-j", "devices", "available"], check=True).stdout), a.runtime)
    bundle = bundle_id(a.app)
    run(["xcrun", "simctl", "boot", udid])  # already booted is fine
    run(["xcrun", "simctl", "bootstatus", udid, "-b"], check=True, timeout=300)
    run(["xcrun", "simctl", "install", udid, str(a.app)], check=True)
    container = Path(run(["xcrun", "simctl", "get_app_container", udid, bundle, "data"], check=True).stdout.strip())
    documents = container / "Documents"
    for old in documents.glob(f"{REPORT_PREFIX}*.json") if documents.is_dir() else []:
        old.unlink()
    import os
    started = time.time()
    r = run(launch_command(udid, bundle), env={**os.environ, **launch_env(a.mode, a.frames)})
    if r.returncode != 0:
        print(r.stdout, r.stderr, file=sys.stderr)
        return 1
    print(f"launched {bundle} on iOS {a.runtime} simulator: mode={a.mode}")
    report = None
    while time.time() - started < a.timeout:
        report = newest_report(documents, a.mode)
        if report:
            time.sleep(0.5)  # let the write finish
            break
        time.sleep(0.5)
    if not report:
        print(f"TIMEOUT: no report after {a.timeout:.0f}s", file=sys.stderr)
        return 3
    a.out.mkdir(parents=True, exist_ok=True)
    dest = a.out / report.name
    shutil.copy2(report, dest)
    data = json.loads(dest.read_text())
    print(f"report {dest}: result={data.get('result')} frames={data.get('frames')} "
          f"frameTimeMs={data.get('frameTimeMs')} timeToFirstFrameMs={data.get('timeToFirstFrameMs')} message={data.get('message')}")
    return 0 if data.get("result") == "pass" else 1


if __name__ == "__main__":
    sys.exit(main())
