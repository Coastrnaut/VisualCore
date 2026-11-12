#!/usr/bin/env python3
"""Migration ledger for the unified VisualCore app (ADR-0009). Deterministic, standard library only.

This tool NEVER starts Claude, calls a model or runs an agent. It is the only writer of
`.autonomy/migration/ledger.json`. The legacy ledger `.autonomy/state.json` (35 gates passed before the
consolidation) is never written here: it stays the record of the foundation and original-app phase gates and is
operated with `Tools/python/desktop_runbook.py` as before.

    python3 scripts/migration_ledger.py init                 # create the ledger from the catalog and the feature briefs
    python3 scripts/migration_ledger.py status               # counts, legacy link, next actions
    python3 scripts/migration_ledger.py next [--kind K] [--limit N]
    python3 scripts/migration_ledger.py show --gate G
    python3 scripts/migration_ledger.py run-check --gate G --name N [--timeout S] [--reverify] -- <argv...>
    python3 scripts/migration_ledger.py seal --gate G [--allow-failures] [--reverify]
    python3 scripts/migration_ledger.py record --gate G [--result pass|fail] [--note TEXT] [--reverify]
    python3 scripts/migration_ledger.py block --gate G --reason TEXT
    python3 scripts/migration_ledger.py unblock --gate G --note TEXT
    python3 scripts/migration_ledger.py guard-device         # exit 0 only when ImplementationLock-100 is pass
    python3 scripts/migration_ledger.py add-round --round N  # after RELEASE-PREP: append the gates of backlog round 5..12
    python3 scripts/migration_ledger.py validate             # structure, dependencies, evidence hashes, legacy link

Gate kinds: milestone, governance, unified-feature, shared-round-feature, game-feature, experience (X-<code>),
lock, device-row (DEV<n>-<code>), device-campaign, release. The gates are stored in the intended execution order,
so the first line printed by `next` is the canonical next action. A gate is *ready* when it is pending (or a failed
device row), every dependency is satisfied (pass, or superseded by gates that are all pass) and every legacy gate
it requires is pass in the legacy ledger. Device gates are additionally guarded by ImplementationLock-100.

Evidence model (same as the legacy tool): `run-check` executes a real command (an argument list: never a shell
string, a shell wrapper or an inline script), writes
the full log and an attestation with the log's SHA-256; `seal` gathers the new attestations of a gate, re-hashes
their logs and writes an evidence file; `record` marks the gate from that evidence file. A gate that already passed
can be verified again after a later source change with `--reverify`: every revision keeps its own evidence file
(`<gate>.json`, `<gate>.r2.json`, ...) and its own entry in the gate's attempts.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import re
import shlex
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LEDGER = Path(".autonomy/migration/ledger.json")
CHECKS = Path(".autonomy/migration/checks")
EVIDENCE = Path(".autonomy/migration/evidence")
LOGS = Path(".autonomy/logs/migration")
LEGACY = Path(".autonomy/state.json")
CATALOG = Path("docs/catalog/experience-catalog.json")
FEATURES = Path("docs/catalog/feature-index.json")
BRIEFS = Path("docs/catalog/unified-app-features.json")
BASELINE = Path("docs/migration/pre-fable-baseline.json")
LOCK = "ImplementationLock-100"
STATUSES = ("pending", "pass", "fail", "blocked", "superseded")
SHELLS = {"sh", "bash", "zsh", "dash", "ksh", "csh", "tcsh", "fish"}
INLINE_FLAGS = {"-c", "-e", "--eval"}
DEVICES = {"DEV1": {"role": "D1", "product_type": "iPhone15,4", "name": "iPhone 15"},
           "DEV2": {"role": "D2", "product_type": "iPad17,3", "name": "iPad Pro 13-inch (M5)"},
           "DEV3": {"role": "D3", "product_type": "iPad15,7", "name": "iPad (A16), must stay on iPadOS 26.5"}}

# Round features whose contract is delivered by unified-app features (Auto-Creator.md section 13). They are not run
# separately; the specification of each absorbing feature imports their unique requirements.
SUPERSEDED_R02 = {"R02-F01": ["UA-F00"], "R02-F25": ["UA-F03", "UA-F04"], "R02-F27": ["UA-F08", "UA-F11"],
                  "R02-F28": ["UA-F05"], "R02-F29": ["UA-F09"], "R02-F30": ["UA-F10"], "R02-F31": ["UA-F09", "UA-F13"],
                  "R02-F32": ["UA-F06"], "R02-F33": ["UA-F11", "UA-F14"], "R02-F34": ["UA-F12"]}
SUPERSEDED_LATER = {1: ["UA-F00"], 9: ["UA-F06"], 10: ["UA-F10"], 11: ["UA-F09", "UA-F13"], 12: ["UA-F11", "UA-F12"]}
# Phase order that the feature briefs do not express: purchases after the free library is locked, the device lab
# after both libraries are locked, release preparation after the device campaigns.
PHASE_DEPENDS = {"UA-F08": ["LOCK-FREE-50"], "UA-F13": ["LOCK-PREMIUM-50"], "UA-F14": ["DEVICE-RECONCILE-100"]}
LATE_UNIFIED = ("UA-F08", "UA-F13", "UA-F14")
LEGACY_DISPOSITIONS = [
    {"legacy_gates": "F00 .. F09", "disposition": "historical: framework foundation, verified; no new gate. The "
     "ProjectM reference regression is rerun by every feature that changes VisualCore."},
    {"legacy_gates": "A01-P00 .. A25-P06", "disposition": "kept in the legacy ledger and operated with "
     "desktop_runbook.py in the original order; each X-A<nn> gate requires its seven legacy gates to be pass."},
    {"legacy_gates": "IMPLEMENTATION-LOCK", "disposition": "superseded by ImplementationLock-100; never recorded."},
    {"legacy_gates": "D1-A01 .. D3-A25", "disposition": "superseded by the DEV1-, DEV2- and DEV3- rows of the unified "
     "app (100 experiences per device); never recorded."},
    {"legacy_gates": "DEVICE-RECONCILE, SUITE-FINAL", "disposition": "superseded by DEVICE-RECONCILE-100 and RELEASE-PREP; never recorded."},
]


def fail(message: str) -> None:
    raise SystemExit("ERROR: " + message)


def clock() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds")


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def read_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def dump_ledger(ledger: dict) -> str:
    """One gate per line, so a recorded gate is a one-line diff."""
    head = {k: v for k, v in ledger.items() if k != "gates"}
    text = json.dumps(head, indent=1, ensure_ascii=False)
    rows = ",\n".join("  " + json.dumps(g, ensure_ascii=False, separators=(",", ":")) for g in ledger["gates"])
    return text[:-2] + ',\n "gates": [\n' + rows + "\n ]\n}\n"


def atomic_write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix=".writing-", dir=str(path.parent))
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(text)
            f.flush()
            os.fsync(f.fileno())
        os.chmod(tmp, 0o644)
        os.replace(tmp, path)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


def load(root: Path) -> dict:
    path = root / LEDGER
    if not path.is_file():
        fail("migration ledger missing: run `python3 scripts/migration_ledger.py init`")
    ledger = read_json(path)
    if ledger.get("schema") != 1:
        fail("unexpected migration ledger schema")
    return ledger


def save(root: Path, ledger: dict) -> None:
    ledger["updated"] = clock()
    atomic_write(root / LEDGER, dump_ledger(ledger))


def legacy_state(root: Path) -> dict:
    return read_json(root / LEGACY)


def gate(gid: str, kind: str, title: str, depends: list[str], **extra) -> dict:
    return {"id": gid, "kind": kind, "title": title, "depends": depends, "status": "pending", "attempts": [], **extra}


def round_gates(index: dict, experiences: list[dict], rnd: int, entry: list[str]) -> list[dict]:
    """Shared features, game features and experience gates of one round, in execution order."""
    out: list[dict] = []
    live_shared: list[str] = []
    previous = None
    for f in index["features"]:
        if f["kind"] != "shared-round-feature" or f["round"] != rnd:
            continue
        number = int(f["id"].rsplit("F", 1)[1])
        if rnd == 2:
            deps = ["UA-F02"] + entry + [d.replace("R2-", "R02-") for d in re.findall(r"R2-F\d\d", f["depends_on"])]
            superseded = SUPERSEDED_R02.get(f["id"])
        else:
            deps = ["UA-F02"] + entry + ([previous] if previous else [])
            superseded = SUPERSEDED_LATER.get(number)
        g = gate(f["id"], "shared-round-feature", f["title"], deps, spec_dir=f["spec_dir_proposed"])
        if superseded:
            g["status"], g["superseded_by"] = "superseded", superseded
        else:
            live_shared.append(f["id"])
        out.append(g)
        previous = f["id"]
    features: dict[str, list[dict]] = {}
    for f in index["features"]:
        if f["kind"] == "game-feature" and f["round"] == rnd:
            features.setdefault(f["experience"], []).append(f)
    for e in experiences:
        if e["collection"] != f"round-{rnd:02d}":
            continue
        code = e["code"]
        for f in features[code]:
            number = int(f["id"].rsplit("-", 1)[1])
            if number > 1:
                deps = [f"{code}-{number - 1:02d}"]
            else:
                named = e.get("shared_feature_dependencies")
                deps = ["UA-F03"] + [s for s in (named or live_shared) if s in live_shared]
            out.append(gate(f["id"], "game-feature", f"{e['name']}: {f['title']}", deps,
                            experience=code, spec_dir=f["spec_dir_proposed"]))
        deps = [f"{code}-{len(features[code]):02d}", "UA-F05", "UA-F06", "UA-F09"] + ([] if e["tier"] == "free" else ["UA-F08"])
        out.append(gate(f"X-{code}", "experience", f"{e['name']} complete in the unified app (simulator-verified)",
                        deps, experience=e["id"], tier=e["tier"]))
    return out


def device_gates(experiences: list[dict], lock: str, suffix: str = "") -> list[dict]:
    out: list[dict] = []
    previous = None
    for dev, info in DEVICES.items():
        rows = []
        for e in experiences:
            rows.append(f"{dev}-{e['code']}")
            deps = [lock, "UA-F13"] + ([previous] if previous else [])
            out.append(gate(rows[-1], "device-row", f"{e['name']} on {info['role']} ({info['name']})", deps,
                            experience=e["id"], device=info["role"]))
        previous = f"{dev}{suffix}-CAMPAIGN"
        out.append(gate(previous, "device-campaign", f"Every experience attempted on {info['role']} ({info['product_type']})",
                        [lock, "UA-F13"], rows=rows, device=info["role"]))
    return out


def build_gates(root: Path) -> list[dict]:
    catalog = read_json(root / CATALOG)
    index = read_json(root / FEATURES)
    briefs = read_json(root / BRIEFS)
    launch = [e for e in catalog["experiences"] if e["release"] == "launch"]
    unified = {b["id"]: gate(b["id"], "unified-feature", b["title"],
                             ["CONSTITUTION-2", *b["depends_on"], *PHASE_DEPENDS.get(b["id"], [])],
                             spec_dir=f"specs/{b['number']}-{b['slug']}") for b in briefs["features"]}
    gates = [gate("M0-CONSOLIDATION", "milestone", "Planning corpus consolidated: archive, catalog, Auto-Creator.md, validators", []),
             gate("CONSTITUTION-2", "governance", "Constitution amended to 2.0.0 for the single app (ADR-0009)", ["M0-CONSOLIDATION"])]
    gates += [g for gid, g in unified.items() if gid not in LATE_UNIFIED]
    for e in launch:
        if e["collection"] == "original":
            gates.append(gate(f"X-{e['code']}", "experience", f"{e['name']} complete in the unified app (simulator-verified)",
                              ["UA-F07", "UA-F05", "UA-F06", "UA-F09"], experience=e["id"], tier=e["tier"],
                              requires_legacy=[p["gate"] for p in e["design"]["phases"]]))
    gates += round_gates(index, launch, 2, [])
    free = [f"X-{e['code']}" for e in launch if e["tier"] == "free"]
    premium = [f"X-{e['code']}" for e in launch if e["tier"] == "premium"]
    gates.append(gate("LOCK-FREE-50", "lock", "All 50 free experiences simulator-verified by an independent rerun",
                      free + ["UA-F10", "UA-F11", "UA-F12"]))
    gates.append(unified["UA-F08"])
    gates += round_gates(index, launch, 3, ["UA-F08"])
    gates += round_gates(index, launch, 4, ["UA-F08"])
    gates.append(gate("LOCK-PREMIUM-50", "lock", "All 50 premium experiences simulator-verified; purchase flows verified",
                      premium + ["LOCK-FREE-50", "UA-F08"]))
    gates.append(unified["UA-F13"])
    gates.append(gate(LOCK, "lock", "Independent rerun confirms 100 of 100 experiences; source commit and tree hash locked",
                      ["LOCK-FREE-50", "LOCK-PREMIUM-50", "UA-F13"]))
    gates += device_gates(launch, LOCK)
    gates.append(gate("DEVICE-RECONCILE-100", "lock", "All 300 device rows pass on the final locked source after fixes and reruns",
                      [f"{d}-CAMPAIGN" for d in DEVICES]))
    gates.append(unified["UA-F14"])
    gates.append(gate("RELEASE-PREP", "release", "Release artifacts prepared; submission needs separate owner authorization",
                      ["DEVICE-RECONCILE-100", "UA-F14"]))
    return gates


def cmd_init(root: Path, args) -> int:
    path = root / LEDGER
    if path.exists() and not args.force:
        fail(f"{LEDGER} exists; it is created once (--force only replaces a ledger without any attempt)")
    if path.exists() and any(g["attempts"] for g in read_json(path)["gates"]):
        fail("refusing --force: the existing ledger has recorded attempts")
    legacy = legacy_state(root)
    passed = [s for s in legacy["order"] if legacy["stages"][s]["status"] == "pass"]
    ledger = {
        "schema": 1,
        "name": "VisualCore unified-app migration ledger (ADR-0009)",
        "created": clock(), "updated": clock(),
        "rules": [
            "Only scripts/migration_ledger.py writes this file.",
            "The legacy ledger .autonomy/state.json is never reset or rewritten by the migration; its passed gates stay passed.",
            "A gate is recorded only from sealed evidence of real commands (run-check, seal, record).",
            "No device gate may be attempted before ImplementationLock-100 is pass.",
            "Observations made in other repositories or on other builds never satisfy a gate here.",
        ],
        "legacy_ledger": {"path": LEGACY.as_posix(), "tool": "Tools/python/desktop_runbook.py",
                          "sha256_at_creation": digest((root / LEGACY).read_bytes()), "gates": len(legacy["stages"]),
                          "passed_at_creation": passed, "baseline": BASELINE.as_posix()},
        "legacy_dispositions": LEGACY_DISPOSITIONS,
        "gates": build_gates(root),
    }
    save(root, ledger)
    kinds: dict[str, int] = {}
    for g in ledger["gates"]:
        kinds[g["kind"]] = kinds.get(g["kind"], 0) + 1
    print(f"created {LEDGER}: {len(ledger['gates'])} gates {kinds}")
    return 0


def index_of(ledger: dict) -> dict[str, dict]:
    return {g["id"]: g for g in ledger["gates"]}


def satisfied(gid: str, gates: dict[str, dict]) -> bool:
    g = gates[gid]
    if g["status"] == "pass":
        return True
    if g["status"] == "superseded":
        return all(satisfied(s, gates) for s in g["superseded_by"])
    return False


def unmet(g: dict, gates: dict[str, dict], legacy: dict) -> list[str]:
    out = [d for d in g["depends"] if not satisfied(d, gates)]
    out += [f"legacy:{l}" for l in g.get("requires_legacy", []) if legacy.get(l, {}).get("status") != "pass"]
    if g["kind"] == "device-campaign":
        out += [r for r in g["rows"] if gates[r]["status"] in ("pending", "blocked")]
    if g["id"] == "DEVICE-RECONCILE-100":
        out += [r for d in DEVICES for r in gates[f"{d}-CAMPAIGN"]["rows"] if gates[r]["status"] != "pass"]
    return out


def next_actions(ledger: dict, legacy: dict, kind: str | None = None, limit: int = 20) -> list[tuple[dict, str]]:
    """Open gates whose migration dependencies are met, in execution order; at most one line waiting for the legacy ledger."""
    gates = index_of(ledger)
    stages = legacy["stages"]
    legacy_next = next((s for s in legacy["order"] if stages[s]["status"] != "pass"), None)
    out: list[tuple[dict, str]] = []
    noted = False
    for g in ledger["gates"]:
        if g["status"] not in ("pending", "fail") or (kind and g["kind"] != kind):
            continue
        missing = unmet(g, gates, stages)
        if any(not m.startswith("legacy:") for m in missing):
            continue
        if missing:
            if noted:
                continue
            noted = True
            out.append((g, f"waits for legacy gates; next legacy gate {legacy_next}: python3 Tools/python/desktop_runbook.py next"))
        else:
            out.append((g, "ready"))
        if len(out) >= limit:
            break
    return out


def cmd_status(root: Path, args) -> int:
    ledger = load(root)
    legacy = legacy_state(root)
    stages = legacy["stages"]
    counts: dict[str, dict[str, int]] = {}
    for g in ledger["gates"]:
        counts.setdefault(g["kind"], {}).setdefault(g["status"], 0)
        counts[g["kind"]][g["status"]] += 1
    lp = sum(v["status"] == "pass" for v in stages.values())
    lnext = next((s for s in legacy["order"] if stages[s]["status"] != "pass"), None)
    print(f"LEGACY {LEGACY}: {lp} of {len(stages)} pass; next legacy gate {lnext} (operate with Tools/python/desktop_runbook.py)")
    print(f"MIGRATION {LEDGER}: {len(ledger['gates'])} gates")
    for kind, c in counts.items():
        print(f"  {kind:22s} " + ", ".join(f"{k} {v}" for k, v in sorted(c.items())))
    blocked = [g["id"] for g in ledger["gates"] if g["status"] == "blocked"]
    if blocked:
        print("BLOCKED: " + ", ".join(blocked))
    actions = next_actions(ledger, legacy, limit=6)
    print("NEXT:" if actions else "NEXT: nothing is ready")
    for g, why in actions:
        print(f"  {g['id']:22s} {why}: {g['title']}")
    return 0


def cmd_next(root: Path, args) -> int:
    ledger = load(root)
    actions = next_actions(ledger, legacy_state(root), args.kind, args.limit)
    for g, why in actions:
        print("\t".join([g["id"], g["kind"], why, g["title"], g.get("spec_dir", "")]).rstrip())
    if not actions:
        print("no ready gate" + (f" of kind {args.kind}" if args.kind else ""))
    return 0


def cmd_show(root: Path, args) -> int:
    ledger = load(root)
    gates = index_of(ledger)
    if args.gate not in gates:
        fail(f"unknown gate {args.gate}")
    g = gates[args.gate]
    print(json.dumps(g, indent=2, ensure_ascii=False))
    missing = unmet(g, gates, legacy_state(root)["stages"])
    print("UNMET: " + (", ".join(missing) if missing else "none"))
    return 0


def require_open(root: Path, ledger: dict, gid: str, reverify: bool = False) -> dict:
    gates = index_of(ledger)
    if gid not in gates:
        fail(f"unknown gate {gid}")
    g = gates[gid]
    if g["status"] == "pass" and not reverify:
        fail(f"{gid} is already pass (use --reverify to verify it again after a source change)")
    if g["status"] == "superseded":
        fail(f"{gid} is superseded by {', '.join(g['superseded_by'])}; run those gates instead")
    if g["status"] == "blocked":
        fail(f"{gid} is blocked; clear it with `unblock` once the reason is resolved")
    missing = unmet(g, gates, legacy_state(root)["stages"])
    if missing:
        fail(f"{gid} is not ready; unmet: {', '.join(missing[:8])}" + (" ..." if len(missing) > 8 else ""))
    if g["kind"] in ("device-row", "device-campaign") and gates[LOCK]["status"] != "pass":
        fail("physical-device gates are forbidden until ImplementationLock-100 is pass")
    return g


def cmd_run_check(root: Path, args) -> int:
    ledger = load(root)
    require_open(root, ledger, args.gate, args.reverify)
    if not re.fullmatch(r"[a-zA-Z0-9_-]{1,64}", args.name):
        fail("check name must be alphanumeric, hyphen or underscore")
    argv = args.argv[1:] if args.argv and args.argv[0] == "--" else args.argv
    if not argv:
        fail("run-check requires a command after --")
    program = Path(argv[0]).name.lower()
    if program in {"claude", "claude-code"}:
        fail("the Claude CLI is prohibited: operate through Claude Desktop Code")
    if program in SHELLS:
        fail("an evidence command is an argument list: no shell wrapper")
    if len(argv) > 1 and argv[1] in INLINE_FLAGS and re.match(r"(python|ruby|perl|node|osascript|swift)", program):
        fail("no inline script as evidence: run a tracked script or tool instead")
    label = f"{args.gate}.{args.name}"
    att = root / CHECKS / f"{label}.json"
    log = root / LOGS / f"{label}.log"
    if att.exists():
        fail(f"check already recorded, choose a new attempt name: {att.relative_to(root)}")
    att.parent.mkdir(parents=True, exist_ok=True)
    log.parent.mkdir(parents=True, exist_ok=True)
    started, t0, status, timed_out = clock(), time.monotonic(), 124, False
    with log.open("wb") as out:
        out.write(("Command: " + shlex.join(argv) + "\nStarted: " + started + "\n").encode())
        out.flush()
        try:
            status = subprocess.run(argv, cwd=root, stdout=out, stderr=subprocess.STDOUT, timeout=args.timeout, check=False).returncode
        except subprocess.TimeoutExpired:
            timed_out = True
            out.write(b"\nTimed out; check did not complete.\n")
        except FileNotFoundError:
            status = 127
            out.write(b"\nExecutable not found.\n")
    record = {"ledger": "migration", "gate": args.gate, "name": args.name, "argv": argv, "command": shlex.join(argv),
              "started": started, "finished": clock(), "elapsed_seconds": round(time.monotonic() - t0, 3),
              "exit_code": status, "timed_out": timed_out, "log": log.relative_to(root).as_posix(),
              "log_sha256": digest(log.read_bytes())}
    atomic_write(att, json.dumps(record, indent=2, ensure_ascii=False, sort_keys=True) + "\n")
    print(f"CHECK {args.gate}/{args.name}: exit={status}; attestation={att.relative_to(root)}")
    return 0 if status == 0 and not timed_out else (status or 1)


def git(root: Path, *argv: str) -> str:
    return subprocess.run(["git", *argv], cwd=root, capture_output=True, text=True, check=False).stdout.strip()


def changed_paths(root: Path) -> list[str]:
    """Paths that differ from HEAD, without the ledger's own files (which a gate in progress always touches)."""
    out = subprocess.run(["git", "status", "--porcelain"], cwd=root, capture_output=True, text=True, check=False).stdout
    paths = [line[3:] for line in out.splitlines() if len(line) > 3]
    return [p for p in paths if not p.startswith(".autonomy/migration/")]


def evidence_files(root: Path, gid: str) -> list[Path]:
    """Evidence revisions of a gate, oldest first: <gate>.json, <gate>.r2.json, ..."""
    base = root / EVIDENCE / f"{gid}.json"
    out = [base] if base.is_file() else []
    n = 2
    while out and (root / EVIDENCE / f"{gid}.r{n}.json").is_file():
        out.append(root / EVIDENCE / f"{gid}.r{n}.json")
        n += 1
    return out


def cmd_seal(root: Path, args) -> int:
    ledger = load(root)
    g = require_open(root, ledger, args.gate, args.reverify)
    prior = evidence_files(root, args.gate)
    recorded = {a.get("evidence") for a in g["attempts"]}
    if prior and prior[-1].relative_to(root).as_posix() not in recorded:
        prior[-1].unlink()  # sealed but never recorded: replace it
        prior = prior[:-1]
    used = {c["name"] for p in prior for c in read_json(p)["passing_checks"] + read_json(p)["failed_attempts"]}
    files = [p for p in sorted((root / CHECKS).glob(args.gate + ".*.json")) if read_json(p).get("gate") == args.gate]
    fresh = [a for a in map(read_json, files) if a["name"] not in used]
    if not fresh:
        fail("no new run-check attestation exists for this gate")
    checks = [a for a in fresh if a.get("exit_code") == 0 and not a.get("timed_out")]
    failed = [a for a in fresh if a not in checks]
    for a in checks + (failed if args.allow_failures else []):
        log = root / a["log"]
        if not log.is_file() or digest(log.read_bytes()) != a["log_sha256"]:
            fail(f"log missing or changed since the command ran: {a['log']}")
    if not checks and not args.allow_failures:
        fail("no passing attestation; fix and rerun, or seal a failed device row with --allow-failures")
    changed = changed_paths(root)
    evidence = {"ledger": "migration", "gate": args.gate, "revision_number": len(prior) + 1, "sealed": clock(),
                "revision": git(root, "rev-parse", "HEAD"), "branch": git(root, "branch", "--show-current"),
                "dirty": bool(changed), "dirty_paths": changed[:50],
                "passing_checks": [{k: a[k] for k in ("name", "command", "exit_code", "log", "log_sha256", "finished")} for a in checks],
                "failed_attempts": [{k: a[k] for k in ("name", "command", "exit_code", "timed_out", "log", "log_sha256")} for a in failed]}
    name = f"{args.gate}.json" if not prior else f"{args.gate}.r{len(prior) + 1}.json"
    atomic_write(root / EVIDENCE / name, json.dumps(evidence, indent=2, ensure_ascii=False, sort_keys=True) + "\n")
    print(f"SEALED {(EVIDENCE / name).as_posix()}: {len(checks)} passing, {len(failed)} failed attempts")
    return 0


def cmd_record(root: Path, args) -> int:
    ledger = load(root)
    g = require_open(root, ledger, args.gate, args.reverify)
    files = evidence_files(root, args.gate)
    if not files:
        fail(f"seal the gate first: no evidence file for {args.gate}")
    path = files[-1]
    rel = path.relative_to(root).as_posix()
    if rel in {a.get("evidence") for a in g["attempts"]}:
        fail(f"{rel} is already recorded; run new checks and seal again")
    evidence = read_json(path)
    if evidence.get("gate") != args.gate:
        fail("evidence file belongs to another gate")
    if args.result == "pass" and not evidence["passing_checks"]:
        fail("cannot record pass: the evidence has no passing check")
    if args.result == "fail" and g["kind"] != "device-row":
        fail("only device rows may be recorded as fail; other gates stay pending until they pass")
    g["status"] = args.result
    g["attempts"].append({"at": clock(), "result": args.result, "evidence": rel, "evidence_sha256": digest(path.read_bytes()),
                          "revision": evidence["revision"], **({"note": args.note} if args.note else {})})
    save(root, ledger)
    print(f"RECORDED {args.gate}: {args.result} ({rel})")
    return 0


def cmd_block(root: Path, args) -> int:
    ledger = load(root)
    gates = index_of(ledger)
    if args.gate not in gates:
        fail(f"unknown gate {args.gate}")
    g = gates[args.gate]
    if g["status"] in ("pass", "superseded"):
        fail(f"{args.gate} is {g['status']}")
    g["status"] = "blocked"
    g["attempts"].append({"at": clock(), "result": "blocked", "reason": args.reason})
    save(root, ledger)
    print(f"BLOCKED {args.gate}: {args.reason}")
    return 0


def cmd_unblock(root: Path, args) -> int:
    ledger = load(root)
    gates = index_of(ledger)
    if args.gate not in gates or gates[args.gate]["status"] != "blocked":
        fail(f"{args.gate} is not a blocked gate")
    g = gates[args.gate]
    results = [a["result"] for a in g["attempts"] if a["result"] in ("pass", "fail")]
    g["status"] = "fail" if results and results[-1] == "fail" else "pending"
    g["attempts"].append({"at": clock(), "result": "unblocked", "note": args.note})
    save(root, ledger)
    print(f"UNBLOCKED {args.gate}: now {g['status']}")
    return 0


def cmd_guard_device(root: Path, args) -> int:
    ledger = load(root)
    if index_of(ledger)[LOCK]["status"] != "pass":
        fail("implementation-first policy: no physical-device install, launch or test before ImplementationLock-100 is pass")
    print("PASS: ImplementationLock-100 is recorded; the device campaign may run D1, then D2, then D3")
    return 0


def cmd_add_round(root: Path, args) -> int:
    ledger = load(root)
    gates = index_of(ledger)
    rnd = args.round
    if not 5 <= rnd <= 12:
        fail("backlog rounds are 5 to 12")
    if gates["RELEASE-PREP"]["status"] != "pass":
        fail("backlog rounds start after RELEASE-PREP is pass")
    if any(g.startswith(f"R{rnd:02d}-") for g in gates):
        fail(f"round {rnd} is already in the ledger")
    if rnd > 5 and f"LOCK-ROUND-{rnd - 1:02d}" not in gates:
        fail(f"add round {rnd - 1} first: backlog rounds keep their score order")
    catalog = read_json(root / CATALOG)
    members = [e for e in catalog["experiences"] if e["collection"] == f"round-{rnd:02d}"]
    new = round_gates(read_json(root / FEATURES), members, rnd, ["RELEASE-PREP"])
    lock = f"LOCK-ROUND-{rnd:02d}"
    new.append(gate(lock, "lock", f"All {len(members)} experiences of round {rnd} simulator-verified by an independent rerun",
                    [f"X-{e['code']}" for e in members]))
    rows = device_gates(members, lock, f"-ROUND-{rnd:02d}")
    new += rows
    new.append(gate(f"RECONCILE-ROUND-{rnd:02d}", "lock", f"All device rows of round {rnd} pass on the final source",
                    [g["id"] for g in rows]))
    ledger["gates"].extend(new)
    save(root, ledger)
    print(f"added round {rnd}: {len(new)} gates")
    return 0


def validate(root: Path) -> list[str]:
    problems: list[str] = []
    path = root / LEDGER
    if not path.is_file():
        return [f"{LEDGER} missing"]
    ledger = read_json(path)
    gates = index_of(ledger)
    if len(gates) != len(ledger["gates"]):
        problems.append("duplicate gate ids")
    for g in ledger["gates"]:
        for d in g["depends"] + g.get("superseded_by", []) + g.get("rows", []):
            if d not in gates:
                problems.append(f"{g['id']}: unknown gate {d}")
        if g["status"] not in STATUSES:
            problems.append(f"{g['id']}: unknown status {g['status']}")
        if g["status"] == "superseded" and not g.get("superseded_by"):
            problems.append(f"{g['id']}: superseded without superseded_by")
    if problems:
        return problems
    state: dict[str, int] = {}
    for start in gates:  # iterative depth-first search: the graph must be acyclic
        if state.get(start):
            continue
        state[start] = 1
        stack = [(start, iter(gates[start]["depends"] + gates[start].get("superseded_by", [])))]
        while stack:
            node, it = stack[-1]
            for d in it:
                if state.get(d) == 1:
                    problems.append(f"dependency cycle through {d}")
                elif not state.get(d):
                    state[d] = 1
                    stack.append((d, iter(gates[d]["depends"] + gates[d].get("superseded_by", []))))
                    break
            else:
                state[node] = 2
                stack.pop()
    legacy = legacy_state(root)["stages"]
    for l in ledger["legacy_ledger"]["passed_at_creation"]:
        if legacy.get(l, {}).get("status") != "pass":
            problems.append(f"legacy gate {l} was pass when the migration ledger was created and is no longer pass")
    if len(legacy) != ledger["legacy_ledger"]["gates"]:
        problems.append("the legacy ledger changed its gate set")
    for g in ledger["gates"]:
        for l in g.get("requires_legacy", []):
            if l not in legacy:
                problems.append(f"{g['id']}: unknown legacy gate {l}")
    xs = [g for g in ledger["gates"] if g["kind"] == "experience"]
    tiers = {t: sum(g["tier"] == t for g in xs) for t in ("free", "premium")}
    if tiers != {"free": 50, "premium": 50}:
        problems.append(f"expected 50 free and 50 premium experience gates, found {tiers}")
    rows = [g for g in ledger["gates"] if g["kind"] == "device-row"]
    if len(rows) != 3 * len(xs):
        problems.append(f"expected {3 * len(xs)} device rows, found {len(rows)}")
    lock_passed = gates[LOCK]["status"] == "pass"
    for g in ledger["gates"]:
        for a in g["attempts"]:
            if "evidence" not in a:
                continue
            ev = root / a["evidence"]
            if not ev.is_file():
                problems.append(f"{g['id']}: evidence file missing: {a['evidence']}")
            elif digest(ev.read_bytes()) != a["evidence_sha256"]:
                problems.append(f"{g['id']}: evidence file changed after it was recorded: {a['evidence']}")
        if g["status"] in ("pass", "fail") and not any("evidence" in a for a in g["attempts"]):
            problems.append(f"{g['id']}: {g['status']} without recorded evidence")
        if g["status"] == "pass":
            problems += [f"{g['id']}: pass with unmet requirement {d}" for d in unmet(g, gates, legacy)]
        if g["kind"] in ("device-row", "device-campaign") and g["status"] in ("pass", "fail") and not lock_passed:
            problems.append(f"{g['id']}: device gate recorded before {LOCK}")
    return problems


def cmd_validate(root: Path, args) -> int:
    problems = validate(root)
    for p in problems:
        print("PROBLEM:", p)
    print(f"{'PASS' if not problems else 'FAIL'}: migration ledger, {len(problems)} problems")
    return 1 if problems else 0


def main(argv: list[str] | None = None, root: Path = ROOT) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    a = sub.add_parser("init"); a.add_argument("--force", action="store_true")
    sub.add_parser("status")
    a = sub.add_parser("next"); a.add_argument("--kind"); a.add_argument("--limit", type=int, default=20)
    a = sub.add_parser("show"); a.add_argument("--gate", required=True)
    a = sub.add_parser("run-check"); a.add_argument("--gate", required=True); a.add_argument("--name", required=True)
    a.add_argument("--timeout", type=int, default=600); a.add_argument("--reverify", action="store_true")
    a.add_argument("argv", nargs=argparse.REMAINDER)
    a = sub.add_parser("seal"); a.add_argument("--gate", required=True); a.add_argument("--allow-failures", action="store_true")
    a.add_argument("--reverify", action="store_true")
    a = sub.add_parser("record"); a.add_argument("--gate", required=True)
    a.add_argument("--result", choices=["pass", "fail"], default="pass"); a.add_argument("--note")
    a.add_argument("--reverify", action="store_true")
    a = sub.add_parser("block"); a.add_argument("--gate", required=True); a.add_argument("--reason", required=True)
    a = sub.add_parser("unblock"); a.add_argument("--gate", required=True); a.add_argument("--note", required=True)
    sub.add_parser("guard-device")
    a = sub.add_parser("add-round"); a.add_argument("--round", type=int, required=True)
    sub.add_parser("validate")
    args = ap.parse_args(argv)
    handler = {"init": cmd_init, "status": cmd_status, "next": cmd_next, "show": cmd_show, "run-check": cmd_run_check,
               "seal": cmd_seal, "record": cmd_record, "block": cmd_block, "unblock": cmd_unblock,
               "guard-device": cmd_guard_device, "add-round": cmd_add_round, "validate": cmd_validate}[args.cmd]
    return handler(root, args)


if __name__ == "__main__":
    sys.exit(main())
