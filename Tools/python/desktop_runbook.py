#!/usr/bin/env python3
"""Deterministic, stdlib-only ledger for Claude Code *Desktop* sessions.

This module NEVER starts Claude, calls an LLM endpoint, or executes an AI agent.
Run it from the VisualCore repository root. The 33 preserved source documents are read from the archived
specification (the former root README.md, moved unchanged by ADR-0009).
"""
import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
import tempfile
import time

ROOT = Path.cwd()
# The former root README.md, byte-identical (ADR-0009). It embeds the 33 hash-checked source documents.
README = ROOT / "docs/archive/planning/root/README-2026-11-10-full-specification.md"
STATE_DIR = ROOT / ".autonomy"
STATE = STATE_DIR / "state.json"
EVIDENCE = STATE_DIR / "evidence"
CHECKS = STATE_DIR / "checks"
LOGS = STATE_DIR / "logs"
CONTEXT = STATE_DIR / "context"
LEASE = STATE_DIR / "desktop.lock"
MANIFEST = ROOT / "docs/verification/full-suite-implementation.json"

APPS = [
    "generative-art-studio", "fluid-art-playground", "fractal-explorer",
    "particle-universe", "infinite-geometry", "visualcore-music-lab",
    "audio-odyssey", "oscilloscope-studio", "digital-aquarium",
    "neon-arcade", "physics-playground", "tiny-worlds", "light-maze",
    "solar-system-explorer", "molecular-explorer", "simulation-lab",
    "interactive-anatomy", "ambient-clock", "living-wallpapers",
    "digital-zen-garden", "aurora", "shader-studio",
    "visual-programming-lab", "graphics-benchmark-lab", "effects-composer",
]
DEVICES = {
    "D1": {"product_type": "iPhone15,4", "baseline_os": "27.0.1", "name": "iPhone 15"},
    "D2": {"product_type": "iPad17,3", "baseline_os": "27.2", "name": "iPad Pro M5"},
    "D3": {"product_type": "iPad15,7", "baseline_os": "26.5", "name": "iPad A16"},
}
SOURCE_REGEX = re.compile(
    r"<!-- SOURCE-BEGIN: ([^\s]+) SHA256=([a-f0-9]{64}) -->\n"
    r"(.*?)"
    r"<!-- SOURCE-END: \1 -->", re.S
)


def clock():
    return dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds")


def stages():
    out = [f"F{i:02d}" for i in range(10)]
    out.extend(f"A{i:02d}-P{j:02d}" for i in range(1, 26) for j in range(7))
    out.append("IMPLEMENTATION-LOCK")
    out.extend(f"{role}-A{i:02d}" for role in DEVICES for i in range(1, 26))
    out.extend(("DEVICE-RECONCILE", "SUITE-FINAL"))
    assert len(out) == 263
    return out


def fail(message):
    raise SystemExit("ERROR: " + message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def all_sources():
    if not README.is_file():
        fail(f"archived specification missing: {README.relative_to(ROOT)} (run from the repository root)")
    doc = README.read_text(encoding="utf-8")
    matches = list(SOURCE_REGEX.finditer(doc))
    if len(matches) != 33:
        fail(f"expected 33 preserved sources, found {len(matches)}")
    names = set()
    for m in matches:
        name, expected, content = m.group(1), m.group(2), m.group(3)
        if name in names:
            fail(f"duplicate preserved source {name}")
        names.add(name)
        if name.startswith("/") or ".." in Path(name).parts:
            fail("unsafe archive path " + name)
        data = content.encode("utf-8")
        if digest(data) != expected:
            fail(f"source integrity violation for {name}")
        yield name, data
    for app in APPS:
        if not any(x.endswith(app + ".md") for x in names):
            fail(f"missing manual {app}")
    for must in ("sources/README.md", "sources/AppsBrainstorm.md",
                 "sources/ProjectM-iOS-CLAUDE.md", "sources/devices.md",
                 "sources/Previous-autopilot-runbook.md"):
        if must not in names:
            fail("required source missing " + must)


def atomic_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    raw = json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    fd, tmp = tempfile.mkstemp(prefix=".writing-", dir=str(path.parent))
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(raw)
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp, path)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


def load_state():
    if not STATE.is_file():
        fail("not bootstrapped: run bootstrap first")
    value = json.loads(STATE.read_text(encoding="utf-8"))
    if value.get("schema") != 1 or set(value.get("stages", {})) != set(stages()) or len(value.get("stages", {})) != len(stages()):
        fail("unexpected stage ledger version/order: refusing to corrupt state")
    return value


def check_safe_path(path_text):
    if not isinstance(path_text, str) or not path_text:
        fail("evidence path missing")
    path = (ROOT / path_text).resolve()
    if not path.is_relative_to(ROOT.resolve()):
        fail("evidence paths must stay inside this checkout: " + path_text)
    return path


def manifest_verified():
    if not MANIFEST.is_file():
        fail("implementation lock needs docs/verification/full-suite-implementation.json")
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    apps = manifest.get("apps", [])
    if not isinstance(apps, list) or len(apps) != 25:
        fail("implementation manifest must contain exactly 25 app rows")
    expected = {f"{i:02d}-{slug}" for i, slug in enumerate(APPS, 1)}
    seen = set()
    for row in apps:
        name = row.get("app_slug")
        if name not in expected or name in seen:
            fail("implementation manifest has missing or duplicated app slug " + str(name))
        seen.add(name)
        if row.get("status") != "pass":
            fail("implementation manifest includes an unverified app " + name)
        for attr in ("scheme", "bundle_id"):
            if not isinstance(row.get(attr), str) or not row[attr].strip():
                fail(f"{name} missing {attr}")
        for attr in ("build_log", "unit_log", "simulator_xcresult"):
            if not check_safe_path(row.get(attr, "")).exists():
                fail(f"{name} missing artifact {attr}")
    if seen != expected:
        fail("25-app manifest roster differs from the mandated roster")
    return manifest


def cmd_bootstrap(args):
    STATE_DIR.mkdir(exist_ok=True)
    EVIDENCE.mkdir(exist_ok=True)
    CHECKS.mkdir(exist_ok=True)
    LOGS.mkdir(exist_ok=True)
    source_count = 0
    for name, data in all_sources():
        path = CONTEXT / name
        path.parent.mkdir(parents=True, exist_ok=True)
        if path.exists():
            if path.read_bytes() != data:
                fail("refusing to overwrite modified extracted source: " + str(path))
        else:
            path.write_bytes(data)
        source_count += 1
    if STATE.exists():
        state = load_state()
    else:
        state = {"schema": 1, "created": clock(), "updated": clock(),
                 "stage_order": "foundation, apps, implementation-lock, D1, D2, D3, reconcile, final",
                 "order": stages(),
                 "stages": {s: {"status": "pending", "attempts": []} for s in stages()}}
        atomic_json(STATE, state)
    print(f"Validated and extracted {source_count} complete source files; {len(state['stages'])} tracked gates")
    cmd_status(args)


def cmd_validate(args):
    sources = list(all_sources())
    print(f"PASS: {len(sources)} source blocks hash-match; {len(APPS)} apps; {len(stages())} gates")


def cmd_status(args):
    state = load_state()
    counts = {k: sum(v["status"] == k for v in state["stages"].values())
              for k in ("pass", "pending", "blocked", "fail")}
    next_step = next(((name, state["stages"][name]["status"]) for name in stages()
                      if state["stages"][name]["status"] != "pass"), ("ALL GATES COMPLETE", "pass"))
    print(f"STATE {counts}; next={next_step[0]} [{next_step[1]}]")
    if next_step[0] in ("IMPLEMENTATION-LOCK", "DEVICE-RECONCILE", "SUITE-FINAL"):
        print("Important boundary gate: read canonical README acceptance contract")
    if next_step[1] == "blocked":
        print("Blocker:", state["stages"][next_step[0]].get("reason", "not recorded"))


def current_gate():
    state = load_state()
    return state, next((name for name in stages()
                        if state["stages"][name]["status"] != "pass"), None)


def cmd_next(args):
    state, gate = current_gate()
    if gate is None:
        print("COMPLETE (subject to final report verification)")
        return
    row = state["stages"][gate]
    print(gate, row["status"])
    if row["status"] in ("fail", "blocked"):
        print("Repair or unblock this gate before continuing:", row.get("reason", "see attempts"))
    if gate.startswith("D1-") or gate.startswith("D2-") or gate.startswith("D3-"):
        print("DEVICE CAMPAIGN: no parallel tests; implementation lock must already pass")


def cmd_guard_device(args):
    state = load_state()
    if state["stages"]["IMPLEMENTATION-LOCK"]["status"] != "pass":
        fail("strict implementation-first policy: physical-device testing forbidden until implementation lock passes")
    manifest_verified()
    if not all(state["stages"][s]["status"] == "pass" for s in stages()[:185]):
        fail("a previously completed implementation stage was reopened")
    print("PASS: all 10 framework and all 175 app phases locked, 25-app manifest present")


def cmd_claim(args):
    STATE_DIR.mkdir(exist_ok=True)
    try:
        LEASE.mkdir()
        (LEASE / "owner.txt").write_text(args.owner + "\n" + clock() + "\n", encoding="utf-8")
        print("CLAIMED " + args.owner)
    except FileExistsError:
        fail("another Desktop session owns the integration lock; inspect " + str(LEASE))


def cmd_release(args):
    marker = LEASE / "owner.txt"
    if not marker.exists() or marker.read_text(encoding="utf-8").splitlines()[0] != args.owner:
        fail("integration lock belongs to a different owner; never clear it blindly")
    marker.unlink()
    LEASE.rmdir()
    print("RELEASED " + args.owner)


def cmd_run_check(args):
    """Execute a REAL command, capturing logs and an immutable-ish hash attestation.

    Commands are direct argv, NOT a shell string, to prevent invisible pipelines.
    """
    state, expected = current_gate()
    if expected != args.stage:
        fail(f"cannot run a check for future stage {args.stage}; expected {expected}")
    if not re.fullmatch(r"[a-zA-Z0-9_-]{1,64}", args.name):
        fail("check name must be alphanumeric/hyphen/underscore")
    argv = args.argv
    if argv and argv[0] == "--":
        argv = argv[1:]
    if not argv:
        fail("run-check requires a command after --")
    if Path(argv[0]).name.lower() in {"claude", "claude-code"}:
        fail("Claude Code CLI is prohibited: operate through Desktop Code")
    if re.fullmatch(r"D[123]-A\d{2}", args.stage):
        cmd_guard_device(None)
    label = f"{args.stage}.{args.name}"
    CHECKS.mkdir(parents=True, exist_ok=True)
    LOGS.mkdir(parents=True, exist_ok=True)
    log_path = LOGS / f"{label}.log"
    att_path = CHECKS / f"{label}.json"
    if att_path.exists():
        fail("check already recorded, choose a unique attempt name instead of overwriting: " + str(att_path))
    started = clock()
    t0 = time.monotonic()
    status = 124
    timed_out = False
    with log_path.open("wb") as log:
        log.write(("Command: " + shlex.join(argv) + "\nStarted: " + started + "\n").encode("utf-8"))
        log.flush()
        try:
            status = subprocess.run(argv, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT,
                                    timeout=args.timeout, check=False).returncode
        except subprocess.TimeoutExpired:
            timed_out = True
            log.write(b"\nTimed out; check did not complete.\n")
        except FileNotFoundError:
            status = 127
            log.write(b"\nExecutable not found.\n")
    record = {"stage": args.stage, "name": args.name, "argv": argv,
              "command": shlex.join(argv), "started": started, "finished": clock(),
              "elapsed_seconds": round(time.monotonic() - t0, 3),
              "exit_code": status, "timed_out": timed_out,
              "log": str(log_path.relative_to(ROOT)),
              "log_sha256": digest(log_path.read_bytes())}
    atomic_json(att_path, record)
    print(f"CHECK {args.stage}/{args.name}: exit={status}; attestation={att_path}")
    if status != 0:
        raise SystemExit(status or 1)


def cmd_seal(args):
    state, expected = current_gate()
    if expected != args.stage:
        fail(f"cannot seal out-of-order {args.stage}; expected {expected}")
    check_files = sorted(CHECKS.glob(args.stage + ".*.json"))
    if not check_files:
        fail("no independently executed run-check attestations for this gate")
    checks = []
    for p in check_files:
        a = json.loads(p.read_text(encoding="utf-8"))
        if a.get("stage") != args.stage:
            fail("check stage metadata mismatch: " + str(p))
        if a.get("exit_code") != 0 or a.get("timed_out"):
            print("SKIP FAILED ATTEMPT: " + str(p), file=sys.stderr)
            continue
        log = check_safe_path(a.get("log", ""))
        if not log.is_file() or digest(log.read_bytes()) != a.get("log_sha256"):
            fail("check log missing or changed since command executed: " + str(p))
        checks.append({"command": a["command"], "exit_code": 0, "log": a["log"],
                       "attestation": str(p.relative_to(ROOT))})
    if not checks:
        fail("no successful independently executed checks for this gate")
    evidence = {"stage": args.stage, "status": "pass", "checks": checks,
                "generated": clock(), "method": "deterministic-run-check"}
    if re.fullmatch(r"D[123]-A\d{2}", args.stage):
        cmd_guard_device(None)
        if not args.device_report:
            fail("device seal requires a verified device report")
        raw = check_safe_path(args.device_report)
        if not raw.is_file():
            fail("device report is missing")
        device_data = json.loads(raw.read_text(encoding="utf-8"))
        for key in ("device", "xcresult", "modes", "measurement", "metadata"):
            if key in device_data:
                evidence[key] = device_data[key]
        if not isinstance(evidence.get("device"), dict):
            fail("device report missing device model/OS/UDID data")
        xcresult = check_safe_path(evidence.get("xcresult", ""))
        if not xcresult.exists() or xcresult.suffix != ".xcresult":
            fail("device report lacks an actual .xcresult bundle")
        try:
            checked = subprocess.run(
                ["xcrun", "xcresulttool", "get", "test-results", "summary", "--path", str(xcresult), "--format", "json"],
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=120, check=False)
        except (FileNotFoundError, subprocess.TimeoutExpired) as exc:
            fail("unable to independently query actual xcresulttool: " + str(exc))
        if checked.returncode:
            fail("xcresulttool verification failed: " + checked.stderr[:300])
        summary = json.loads(checked.stdout)
        result = str(summary.get("result", "")).lower()
        if result != "passed":
            fail("xcresulttool did not report a Passed result (got " + result + ")")
        evidence["xcresult_summary"] = "Passed"
    if args.stage == "IMPLEMENTATION-LOCK":
        manifest_verified()
    EVIDENCE.mkdir(exist_ok=True)
    dest = EVIDENCE / (args.stage + ".json")
    if dest.exists():
        fail("evidence already sealed; preserve past evidence and use a unique repair attempt")
    atomic_json(dest, evidence)
    print("SEALED " + str(dest.relative_to(ROOT)))


def validate_evidence(gate, path):
    if not path.is_file():
        fail("missing evidence JSON at " + str(path))
    record = json.loads(path.read_text(encoding="utf-8"))
    if record.get("stage") != gate or record.get("status") != "pass":
        fail("evidence stage or status doesn't match gate")
    checks = record.get("checks")
    if not isinstance(checks, list) or not checks:
        fail("pass evidence needs real command checks")
    for item in checks:
        if not isinstance(item.get("command"), str) or not item["command"].strip():
            fail("missing evidence command")
        if item.get("exit_code") != 0:
            fail("test/check command did not exit 0")
        log = check_safe_path(item.get("log", ""))
        if not log.is_file() or log.stat().st_size == 0:
            fail("pass evidence log missing or empty: " + str(log))
        if not item.get("attestation"):
            fail("a stage cannot pass without a real run-check attestation")
        att_path = check_safe_path(item["attestation"])
        if not att_path.is_file():
            fail("missing deterministic command attestation")
        att = json.loads(att_path.read_text(encoding="utf-8"))
        if att.get("stage") != gate or att.get("command") != item["command"] or att.get("exit_code") != 0:
            fail("evidence does not match executed command")
        if att.get("log") != item["log"] or digest(log.read_bytes()) != att.get("log_sha256"):
            fail("command log hash or path changed after execution")
    if gate == "IMPLEMENTATION-LOCK":
        manifest_verified()
    if re.fullmatch(r"D[123]-A\d{2}", gate):
        cmd_guard_device(None)
        role = gate[:2]
        device = record.get("device", {})
        if device.get("role") != role or device.get("product_type") != DEVICES[role]["product_type"]:
            fail("device evidence lacks a matching physical-device product type")
        if not device.get("hardware_udid") or not device.get("os_version"):
            fail("device evidence missing actual hardware UDID or observed OS")
        if role == "D3" and device["os_version"] != "26.5":
            fail("D3 changed off iPadOS 26.5; blocked: preserve the fallback test environment")
        if device.get("is_simulator") is not False:
            fail("physical device evidence must explicitly say is_simulator=false")
        xcresult = check_safe_path(record.get("xcresult", ""))
        if not xcresult.exists() or xcresult.suffix != ".xcresult":
            fail("physical-device test requires a real .xcresult path")
        if record.get("xcresult_summary") != "Passed":
            fail("physical-device XCTest summary must be independently verified Passed")
    return record


def cmd_record(args):
    state, expected = current_gate()
    if expected != args.stage:
        fail(f"sequential gating: expected {expected}, got {args.stage}")
    evidence = check_safe_path(args.evidence)
    validate_evidence(args.stage, evidence)
    relative_evidence = str(evidence.relative_to(ROOT.resolve()))
    state["stages"][args.stage]["attempts"].append({"at": clock(), "result": "pass", "evidence": relative_evidence})
    state["stages"][args.stage]["status"] = "pass"
    state["stages"][args.stage].pop("reason", None)
    state["updated"] = clock()
    atomic_json(STATE, state)
    print("VERIFIED-GATE " + args.stage)
    cmd_status(args)


def cmd_block(args):
    state, expected = current_gate()
    if expected != args.stage:
        fail(f"cannot block out-of-order stage, expected {expected}")
    if not args.reason.strip():
        fail("provide an actionable blocker explanation")
    row = state["stages"][args.stage]
    row["status"] = "blocked"
    row["reason"] = args.reason
    row["attempts"].append({"at": clock(), "result": "blocked", "reason": args.reason})
    state["updated"] = clock()
    atomic_json(STATE, state)
    print("BLOCKED " + args.stage + " — " + args.reason)


def cmd_retry(args):
    state, expected = current_gate()
    if expected != args.stage:
        fail(f"cannot retry out-of-order stage, expected {expected}")
    row = state["stages"][args.stage]
    if row["status"] not in ("fail", "blocked"):
        fail("only blocked/failed stages are eligible to retry")
    row["status"] = "pending"
    row.pop("reason", None)
    state["updated"] = clock()
    atomic_json(STATE, state)
    print("RETRY ENABLED " + args.stage)


def cmd_audit(args):
    cmd_validate(args)
    state = load_state()
    missing = [name for name in stages() if state["stages"][name]["status"] != "pass"]
    for name in stages():
        val = state["stages"][name]
        if val["status"] == "pass":
            attempt = val["attempts"][-1]
            validate_evidence(name, check_safe_path(attempt["evidence"]))
    if missing:
        print("INCOMPLETE: " + ", ".join(missing[:12]))
        raise SystemExit(2)
    print("ALL 263 GATES HAVE FILE-BACKED EVIDENCE. Further independent test review still recommended.")


def main():
    p = argparse.ArgumentParser(description=__doc__)
    sp = p.add_subparsers(dest="command", required=True)
    for name, fn in (("bootstrap", cmd_bootstrap), ("validate", cmd_validate),
                     ("status", cmd_status), ("next", cmd_next),
                     ("guard-device", cmd_guard_device), ("audit", cmd_audit)):
        a = sp.add_parser(name)
        a.set_defaults(func=fn)
    a = sp.add_parser("claim")
    a.add_argument("--owner", required=True)
    a.set_defaults(func=cmd_claim)
    a = sp.add_parser("release")
    a.add_argument("--owner", required=True)
    a.set_defaults(func=cmd_release)
    a = sp.add_parser("run-check")
    a.add_argument("--stage", required=True)
    a.add_argument("--name", required=True)
    a.add_argument("--timeout", type=int, default=1800)
    a.add_argument("argv", nargs=argparse.REMAINDER)
    a.set_defaults(func=cmd_run_check)
    a = sp.add_parser("seal")
    a.add_argument("--stage", required=True)
    a.add_argument("--device-report")
    a.set_defaults(func=cmd_seal)
    a = sp.add_parser("record")
    a.add_argument("--stage", required=True)
    a.add_argument("--evidence", required=True)
    a.set_defaults(func=cmd_record)
    a = sp.add_parser("block")
    a.add_argument("--stage", required=True)
    a.add_argument("--reason", required=True)
    a.set_defaults(func=cmd_block)
    a = sp.add_parser("retry")
    a.add_argument("--stage", required=True)
    a.set_defaults(func=cmd_retry)
    args = p.parse_args()
    args.func(args)

if __name__ == "__main__":
    main()
