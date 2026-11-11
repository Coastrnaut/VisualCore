#!/usr/bin/env python3
"""Simulator performance baselines (feature 010 T-F909; FR-F905; research R6): runs the Showcase AutomationRunner
`smoke` and `launch` modes repeatedly on each simulator runtime via run_automation_sim.py and writes medians with the
environment to docs/performance/baselines-simulator.json. Simulator numbers are NOT device evidence (constitution V).

  python3 scripts/simulator_baselines.py --app <measurement Showcase.app> --runtimes 27.2 26.5 --launches 10
"""
from __future__ import annotations

import argparse
import json
import platform
import statistics
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(HERE))
import run_automation_sim  # noqa: E402


def aggregate(smoke: list[dict], launch: list[dict]) -> dict:
    def med(values):
        return round(statistics.median(values), 3) if values else None
    return {
        "smoke": {"runs": len(smoke), "framesPerRun": smoke[0]["frames"] if smoke else 0,
                  "frameTimeMedianMs": med([r["frameTimeMs"]["median"] for r in smoke]),
                  "frameTimeP95Ms": med([r["frameTimeMs"]["p95"] for r in smoke]),
                  "allPassed": all(r["result"] == "pass" for r in smoke)},
        "launch": {"runs": len(launch), "timeToFirstFrameMedianMs": med([r["timeToFirstFrameMs"] for r in launch]),
                   "timeToFirstFrameMaxMs": round(max(r["timeToFirstFrameMs"] for r in launch), 3) if launch else None,
                   "allPassed": all(r["result"] == "pass" for r in launch)},
        "model": (smoke or launch or [{}])[0].get("deviceModel"),
        "osVersion": (smoke or launch or [{}])[0].get("osVersion"),
    }


def collect(app: Path, runtime: str, mode: str, runs: int, out: Path, frames: int | None) -> list[dict]:
    reports = []
    for i in range(runs):
        d = out / f"{runtime}-{mode}-{i:02d}"
        args = ["--app", str(app), "--runtime", runtime, "--mode", mode, "--out", str(d)]
        if frames:
            args += ["--frames", str(frames)]
        if run_automation_sim.main(args) != 0:
            raise SystemExit(f"{mode} run {i} on iOS {runtime} failed")
        reports.append(json.loads(next(d.glob("*.json")).read_text()))
    return reports


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--app", required=True, type=Path)
    ap.add_argument("--runtimes", nargs="+", default=["27.2", "26.5"])
    ap.add_argument("--smoke-runs", type=int, default=3)
    ap.add_argument("--frames", type=int, default=300)
    ap.add_argument("--launches", type=int, default=10)
    ap.add_argument("--work", type=Path, default=ROOT / ".autonomy" / "logs" / "simulator-baselines")
    ap.add_argument("--output", type=Path, default=ROOT / "docs" / "performance" / "baselines-simulator.json")
    a = ap.parse_args(argv)
    xcode = subprocess.run(["xcodebuild", "-version"], capture_output=True, text=True).stdout.split()
    result = {"schema": 1, "evidence": "simulator baseline — not device evidence (constitution V)",
              "app": "Showcase measurement build (Release + VISUALCORE_AUTOMATION)",
              "host": {"macOS": platform.mac_ver()[0], "machine": platform.machine(),
                       "xcode": " ".join(xcode[:2] + xcode[-1:]) if xcode else "unknown"},
              "runtimes": {}}
    for rt in a.runtimes:
        smoke = collect(a.app, rt, "smoke", a.smoke_runs, a.work, a.frames)
        launch = collect(a.app, rt, "launch", a.launches, a.work, None)
        result["runtimes"][rt] = aggregate(smoke, launch)
        print(rt, json.dumps(result["runtimes"][rt]))
    a.output.parent.mkdir(parents=True, exist_ok=True)
    a.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print("wrote", a.output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
