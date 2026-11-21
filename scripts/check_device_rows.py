#!/usr/bin/env python3
"""Device-row definition check of one experience (feature 310, R02-G01-10, task T-R02G0110-003; FR-R02G0110-003,
FR-R02G0110-004; contract specs/310-aurora-loom-device-automation-preparation/contracts/device-rows.md).

  python3 scripts/check_device_rows.py --experience r02-g01.aurora-loom
  python3 scripts/check_device_rows.py --experience r02-g01.aurora-loom --root <fixture root>

Inputs, all found from the experience id (`r02-g01.aurora-loom`: code `R02-G01`, folder `aurora-loom`):

  definition  docs/apps/<folder>/device-rows.json
  manifest    the Packages/ExperiencesRound02/*/scenario-manifest.json whose `experience` equals the id
  ledger      .autonomy/migration/ledger.json (read only), its `gates` DEV1-<CODE>, DEV2-<CODE>, DEV3-<CODE>
  tasks       the open device tasks (`- [ ] T-… {device} …`) of the experience's earlier features

Round-two numbering: game Gnn of round two owns the ten features 3(nn-1)1 … 3(nn-1)0, i.e. G01 is 301–310 and G02
311–320; the last of the ten is the device-preparation feature itself, so the coverage scan reads the first nine
(for R02-G01: specs/301…309 whose folder name is `<number>-<folder>-…`).

Required coverage (every item named by at least one row's `covers`):
  * every open {device} task id of those nine features;
  * the experience's extra device items, a constant table keyed by the experience id (EXTRA_ITEMS): items deferred
    to devices in a feature header rather than a task line (for Aurora Loom R02-G01-06 hearing, feeling and
    VoiceOver, research R2);
  * the six UA-F13 measurement names (UA_F13_ITEMS).

Rules (exit 1, one line `device-rows <id>: <reason>` per problem): missing or unreadable definition; schema not 1;
experience mismatch; unknown experience (no manifest); devices not exactly D1, D2, D3 with the ledger's DEV ids (each
present in the ledger); a scenario not in the manifest or duplicated; a row missing a field or with an empty value
(gating is a boolean and may be false); a status other than "pending device campaign"; a result field on a row
(FORBIDDEN_FIELDS, no device number before the campaign); duplicate row ids; row devices outside D1, D2, D3; an
uncovered required item. On success prints `device-rows <id>: PASS (<n> rows, <m> scenarios)` and exits 0. Never
contacts a device. Standard library only.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

LEDGER = ".autonomy/migration/ledger.json"
DEVICES = ("D1", "D2", "D3")
STATUS = "pending device campaign"
ROW_FIELDS = ("id", "title", "devices", "procedure", "measurements", "pass", "gating", "covers", "owner_steps",
              "status")
FORBIDDEN_FIELDS = ("result", "results", "value", "measured", "measurement_values")
UA_F13_ITEMS = ("launch", "first-frame", "frame-pacing", "memory", "thermal", "stress")
EXTRA_ITEMS = {
    "r02-g01.aurora-loom": ("R02-G01-06:sound", "R02-G01-06:haptics", "R02-G01-06:voiceover"),
}
EXPERIENCE_ID = re.compile(r"^(r\d{2}-g\d{2}|a\d{2})\.([a-z0-9-]+)$")
OPEN_DEVICE_TASK = re.compile(r"^- \[ \] (T-[A-Z0-9]+-\d+)\b.*\{device\}")


def experience_parts(experience: str) -> tuple[str, str] | None:
    """The upper-cased code (`R02-G01`) and the app folder (`aurora-loom`) of an id, or None when malformed."""
    match = EXPERIENCE_ID.match(experience)
    return (match.group(1).upper(), match.group(2)) if match else None


def find_manifest(root: Path, experience: str) -> dict | None:
    """The round-two scenario manifest whose `experience` equals the id, or None."""
    for path in sorted((root / "Packages" / "ExperiencesRound02").glob("*/scenario-manifest.json")):
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            continue
        if isinstance(data, dict) and data.get("experience") == experience:
            return data
    return None


def feature_range(code: str) -> range | None:
    """The nine earlier feature numbers of a round-two game (R02-G01 -> 301..309), None for other codes."""
    match = re.match(r"^R02-G(\d{2})$", code)
    if not match or int(match.group(1)) < 1:
        return None
    base = 300 + (int(match.group(1)) - 1) * 10
    return range(base + 1, base + 10)


def open_device_tasks(root: Path, code: str, folder: str) -> list[str]:
    """The ids of the open {device} task lines of the experience's earlier features, sorted."""
    numbers = feature_range(code) or range(0)
    found: set[str] = set()
    for number in numbers:
        for spec in sorted((root / "specs").glob(f"{number}-{folder}-*")):
            tasks = spec / "tasks.md"
            if not tasks.is_file():
                continue
            for line in tasks.read_text(encoding="utf-8").splitlines():
                match = OPEN_DEVICE_TASK.match(line)
                if match:
                    found.add(match.group(1))
    return sorted(found)


def ledger_gate_ids(root: Path) -> set[str]:
    """The gate ids of the migration ledger (read only); empty when it cannot be read."""
    try:
        data = json.loads((root / LEDGER).read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return set()
    gates = data.get("gates") if isinstance(data, dict) else None
    return {g["id"] for g in gates or [] if isinstance(g, dict) and isinstance(g.get("id"), str)}


def is_empty(value) -> bool:
    if value is None:
        return True
    if isinstance(value, str):
        return not value.strip()
    if isinstance(value, (list, dict)):
        return not value
    return False


def check_rows(rows, problems: list[str]) -> tuple[set[str], int]:
    """Row rules; returns the covered items and the number of rows."""
    covered: set[str] = set()
    if not isinstance(rows, list) or not rows:
        problems.append("rows missing or empty")
        return covered, 0
    seen: set[str] = set()
    for index, row in enumerate(rows):
        if not isinstance(row, dict):
            problems.append(f"row {index + 1} is not an object")
            continue
        name = row.get("id") if isinstance(row.get("id"), str) and row.get("id") else f"row {index + 1}"
        for field in ROW_FIELDS:
            if field not in row:
                problems.append(f"{name}: missing field {field}")
            elif field == "gating":
                if not isinstance(row[field], bool):
                    problems.append(f"{name}: gating is not true or false")
            elif is_empty(row[field]):
                problems.append(f"{name}: empty field {field}")
        for field in FORBIDDEN_FIELDS:
            if field in row:
                problems.append(f"{name}: result field {field} before the device campaign")
        if "status" in row and row["status"] != STATUS and not is_empty(row["status"]):
            problems.append(f"{name}: status {row['status']!r} is not {STATUS!r}")
        if isinstance(row.get("id"), str) and row["id"]:
            if row["id"] in seen:
                problems.append(f"duplicate row id {row['id']}")
            seen.add(row["id"])
        devices = row.get("devices")
        if isinstance(devices, list):
            extra = [d for d in devices if d not in DEVICES]
            if extra:
                problems.append(f"{name}: unknown devices {', '.join(map(str, extra))}")
        elif devices is not None:
            problems.append(f"{name}: devices is not a list")
        covers = row.get("covers")
        if isinstance(covers, list):
            covered.update(c for c in covers if isinstance(c, str))
        elif covers is not None:
            problems.append(f"{name}: covers is not a list")
    return covered, len(rows)


def check(root: Path, experience: str) -> tuple[list[str], int, int]:
    """All problems of the experience's definition, with the row and scenario counts."""
    parts = experience_parts(experience)
    if parts is None:
        return ["unknown experience (malformed id)"], 0, 0
    code, folder = parts
    path = root / "docs" / "apps" / folder / "device-rows.json"
    rel = path.relative_to(root).as_posix()
    if not path.is_file():
        return [f"missing definition {rel}"], 0, 0
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, ValueError) as error:
        return [f"unreadable definition {rel} ({type(error).__name__})"], 0, 0
    if not isinstance(data, dict):
        return [f"unreadable definition {rel} (not an object)"], 0, 0
    problems: list[str] = []
    if data.get("schema") != 1:
        problems.append(f"schema {data.get('schema')!r} is not 1")
    if data.get("experience") != experience:
        problems.append(f"experience {data.get('experience')!r} does not match")
    manifest = find_manifest(root, experience)
    if manifest is None:
        problems.append("unknown experience (no scenario manifest names it)")

    gates = ledger_gate_ids(root)
    expected = [{"name": name, "ledger": f"DEV{name[1]}-{code}"} for name in DEVICES]
    devices = data.get("devices")
    if not isinstance(devices, list) or [
            {"name": d.get("name"), "ledger": d.get("ledger")} if isinstance(d, dict) else d for d in devices] != expected:
        problems.append("devices are not exactly " + ", ".join(f"{d['name']}={d['ledger']}" for d in expected))
    for device in expected:
        if device["ledger"] not in gates:
            problems.append(f"ledger gate {device['ledger']} not found")

    scenarios = data.get("scenarios")
    known = {s.get("name") if isinstance(s, dict) else s for s in (manifest or {}).get("scenarios", [])}
    if not isinstance(scenarios, list) or not scenarios:
        problems.append("scenarios missing or empty")
        scenarios = []
    seen: set = set()
    for scenario in scenarios:
        if scenario in seen:
            problems.append(f"duplicate scenario {scenario}")
        seen.add(scenario)
        if manifest is not None and scenario not in known:
            problems.append(f"scenario {scenario} not in the manifest")

    covered, row_count = check_rows(data.get("rows"), problems)
    required = open_device_tasks(root, code, folder) + list(EXTRA_ITEMS.get(experience, ())) + list(UA_F13_ITEMS)
    for item in required:
        if item not in covered:
            problems.append(f"{item} not covered by any row")
    return problems, row_count, len(scenarios)


def main(argv: list[str] | None = None, root: Path = ROOT) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--experience", required=True, help="experience id, e.g. r02-g01.aurora-loom")
    ap.add_argument("--root", type=Path, default=None, help="repository root (default: this repository)")
    args = ap.parse_args(argv)
    base = (args.root or root).resolve()
    problems, rows, scenarios = check(base, args.experience)
    if problems:
        for problem in problems:
            print(f"device-rows {args.experience}: {problem}")
        return 1
    print(f"device-rows {args.experience}: PASS ({rows} rows, {scenarios} scenarios)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
