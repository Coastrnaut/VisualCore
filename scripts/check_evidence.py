#!/usr/bin/env python3
"""Validate evidence records of schema 1 (feature UA-F09 T-U09-016; FR-U09-030 to FR-U09-032, FR-U09-062;
specs/195-ua-f09-verification-runner/data-model.md section 4; Auto-Creator.md section 22.3).

  python3 scripts/check_evidence.py .autonomy/evidence/scenarios/<run>/<record>.json [...]
  python3 scripts/check_evidence.py --self-test

A record is one JSON object with exactly the 21 top-level fields of schema 1. The validator rejects a missing or
mistyped field (every field is present; `null` only where the schema allows it), an unknown (0 or negative) or
newer (above 1) schema, an extra top-level field, a hash that is not 64 (or, for commits and trees, 40) lower-case
hex characters, a `result` outside pass/fail/error, a pass with failures, a fail or error without failures, a pass
without observed evidence (no step and no initial and final digest, except for `cancel-prepare` and
`teardown-reentry`), a drawing pass (`launch-first-frame`, `hero`) without a non-blank frame with a hash,
`environment.kind` other than simulator or device, any key or string value shaped like a UDID or an ECID, and in a
device record any key named `udid`, `serial` or `ecid` (the format stays usable on devices without carrying a
hardware identifier).

Output: one `PASS: <file>` line, or one `FAIL: <file>: <problem>` line per problem (each problem names its field
path). Exit codes: 0 every file passed (or the self-test passed); 1 a file or a self-test case failed; 2 bad usage.
"""
from __future__ import annotations

import argparse
import copy
import json
import re
import sys
from pathlib import Path

SCHEMA = 1
EXPERIENCE_ID = re.compile(r"[a-z0-9]+\.[a-z0-9-]+")
SCENARIO = re.compile(r"[a-z0-9-]{1,64}")
RUN_ID = re.compile(r"[A-Za-z0-9-]{1,64}")
SEED = re.compile(r"[0-9]+")
HEX64 = re.compile(r"[0-9a-f]{64}")
HEX40 = re.compile(r"[0-9a-f]{40}")
UDID = re.compile(r"[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}")
ECID = re.compile(r"0x[0-9A-Fa-f]{13,16}|ECID")
DEVICE_ID_KEYS = {"udid", "serial", "ecid"}
NO_EVIDENCE_SCENARIOS = {"cancel-prepare", "teardown-reentry"}
DRAWING_SCENARIOS = {"launch-first-frame", "hero"}
RESULTS = {"pass", "fail", "error"}


# --- field specifications ------------------------------------------------------------------------------------------
# A specification is a dict (an object whose keys are all required), or a tuple:
#   ("leaf", description, predicate), ("null", spec), ("list", spec), ("map", spec).

def _leaf(description: str, predicate) -> tuple:
    return ("leaf", description, predicate)


def _null(spec) -> tuple:
    return ("null", spec)


def _list(spec) -> tuple:
    return ("list", spec)


def _map(spec) -> tuple:
    return ("map", spec)


def _is_int(v) -> bool:
    return isinstance(v, int) and not isinstance(v, bool)


def _is_number(v) -> bool:
    return isinstance(v, (int, float)) and not isinstance(v, bool)


def _matches(pattern: re.Pattern) -> callable:
    return lambda v: isinstance(v, str) and pattern.fullmatch(v) is not None


STRING = _leaf("a string", lambda v: isinstance(v, str))
NONEMPTY = _leaf("a non-empty string", lambda v: isinstance(v, str) and v != "")
BOOL = _leaf("a boolean", lambda v: isinstance(v, bool))
INT = _leaf("an integer", _is_int)
COUNT = _leaf("an integer >= 0", lambda v: _is_int(v) and v >= 0)
NUMBER = _leaf("a number", _is_number)
DURATION = _leaf("a number >= 0", lambda v: _is_number(v) and v >= 0)
SHA256 = _leaf("64 lower-case hex characters", _matches(HEX64))
SHA1 = _leaf("40 lower-case hex characters", _matches(HEX40))

FIELDS: dict = {
    "schema": INT,
    "experience": _leaf("an experience id such as sample.orbit", _matches(EXPERIENCE_ID)),
    "code": NONEMPTY,
    "scenario": _leaf("a scenario name of 1 to 64 characters a-z 0-9 -", _matches(SCENARIO)),
    "seed": _null(_leaf("a decimal string", _matches(SEED))),
    "result": _leaf("one of pass, fail, error", lambda v: v in RESULTS),
    "run": {
        "id": _leaf("1 to 64 characters A-Z a-z 0-9 -", _matches(RUN_ID)),
        "attempt": _leaf("an integer >= 1", lambda v: _is_int(v) and v >= 1),
        "lock_sha256": _null(SHA256),
    },
    "environment": {
        "kind": _leaf("simulator or device", lambda v: v in {"simulator", "device"}),
        "os_version": STRING, "os_build": STRING, "device_type": STRING, "xcode": STRING, "swift": STRING,
        "sdk": STRING, "host_os": STRING, "signing": STRING,
    },
    "source": {
        "commit": SHA1, "dirty": BOOL, "tree": SHA1, "submodules": _map(SHA1),
        "catalog_sha256": SHA256, "app_sha256": SHA256,
    },
    "configuration": {
        "build": _leaf("Debug or Release", lambda v: v in {"Debug", "Release"}),
        "automation": BOOL,
        "quality_tier": _null(INT),
        "entitlement": STRING,
        "process": _leaf("two-launch or single", lambda v: v in {"two-launch", "single"}),
    },
    "steps": _list({
        "control": STRING, "values": _list(NUMBER), "result": STRING, "reason": _null(STRING),
        "digest": _null(SHA256),
    }),
    "digests": {"initial": _null(SHA256), "final": _null(SHA256), "after_restore": _null(SHA256),
                "after_reset": _null(SHA256)},
    "frames": _list({
        "non_blank": BOOL,
        "probes": _list({"name": STRING, "expected": STRING, "observed": STRING, "pass": BOOL}),
        "path": _null(STRING), "sha256": _null(SHA256),
    }),
    "timing": {"launch_ms": _null(DURATION), "preparation_ms": _null(DURATION),
               "shader_compilation_ms": _null(DURATION), "first_present_ms": _null(DURATION)},
    "pacing": _null({"samples": INT, "on_time": INT, "median_ms": NUMBER, "p95_ms": NUMBER, "p99_ms": NUMBER}),
    "resources": {"footprint_bytes": _null(COUNT), "gpu_bytes": _null(COUNT), "live": _null(COUNT),
                  "leaked": _null(COUNT)},
    "thermal_state": _null(STRING),
    "low_power": _null(BOOL),
    "battery": _null(NUMBER),
    "artifacts": {"result_bundle": _null(STRING), "log": STRING, "log_sha256": SHA256,
                  "record_sha256": _null(SHA256)},
    "failures": _list(STRING),
}


def _type_name(value) -> str:
    """The JSON type of a value, never the value itself (a value may carry an identifier)."""
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "a boolean"
    if isinstance(value, (int, float)):
        return "a number"
    if isinstance(value, str):
        return "a string"
    if isinstance(value, list):
        return "a list"
    if isinstance(value, dict):
        return "an object"
    return type(value).__name__


def _check(path: str, value, spec, problems: list[str]) -> None:
    """Appends to `problems` every place where `value` does not follow `spec`."""
    if isinstance(spec, dict):
        if not isinstance(value, dict):
            problems.append(f"{path}: expected an object, got {_type_name(value)}")
            return
        for key, sub in spec.items():
            if key not in value:
                problems.append(f"{path}.{key}: missing")
            else:
                _check(f"{path}.{key}", value[key], sub, problems)
        return
    kind = spec[0]
    if kind == "null":
        if value is not None:
            _check(path, value, spec[1], problems)
    elif kind == "list":
        if not isinstance(value, list):
            problems.append(f"{path}: expected a list, got {_type_name(value)}")
            return
        for i, item in enumerate(value):
            _check(f"{path}[{i}]", item, spec[1], problems)
    elif kind == "map":
        if not isinstance(value, dict):
            problems.append(f"{path}: expected an object, got {_type_name(value)}")
            return
        for key, item in value.items():
            _check(f"{path}[{key}]", item, spec[1], problems)
    else:
        _, description, predicate = spec
        if not predicate(value):
            problems.append(f"{path}: expected {description}, got {_type_name(value)}")


def _identifiers(path: str, value, device: bool, problems: list[str]) -> None:
    """Every key and string value, recursively, that looks like a UDID or an ECID; in a device record also every key
    named udid, serial or ecid. The offending text itself is never repeated."""
    def text(where: str, s: str, what: str) -> None:
        if UDID.search(s):
            problems.append(f"{where}: {what} looks like a UDID")
        if ECID.search(s):
            problems.append(f"{where}: {what} looks like an ECID")

    if isinstance(value, dict):
        for key, item in value.items():
            where = f"{path}.{key}" if path else str(key)
            if isinstance(key, str):
                text(where, key, "key")
                if device and key.lower() in DEVICE_ID_KEYS:
                    problems.append(f"{where}: a device record carries no hardware identifier ({key.lower()})")
            _identifiers(where, item, device, problems)
    elif isinstance(value, list):
        for i, item in enumerate(value):
            _identifiers(f"{path}[{i}]", item, device, problems)
    elif isinstance(value, str):
        text(path, value, "value")


def validate(record) -> list[str]:
    """Every problem of one evidence record; empty when it follows schema 1. Each problem names its field path."""
    if not isinstance(record, dict):
        return [f"record: expected an object, got {_type_name(record)}"]
    problems: list[str] = []
    for key in FIELDS:
        if key not in record:
            problems.append(f"{key}: missing")
    for key in record:
        if key not in FIELDS:
            problems.append(f"{key}: unknown top-level field")
    for key, spec in FIELDS.items():
        if key in record:
            _check(key, record[key], spec, problems)

    schema = record.get("schema")
    if _is_int(schema) and schema != SCHEMA:
        problems.append(f"schema: unknown schema {schema}" if schema < SCHEMA else
                        f"schema: newer schema {schema} than this validator ({SCHEMA})")

    result = record.get("result")
    failures = record.get("failures")
    failures = failures if isinstance(failures, list) else None
    scenario = record.get("scenario")
    if result == "pass":
        if failures:
            problems.append("failures: a pass has no failures")
        steps = record.get("steps")
        digests = record.get("digests") if isinstance(record.get("digests"), dict) else {}
        has_steps = isinstance(steps, list) and len(steps) > 0
        has_digests = digests.get("initial") is not None and digests.get("final") is not None
        if scenario not in NO_EVIDENCE_SCENARIOS and not has_steps and not has_digests:
            problems.append("steps: a pass has at least one step or the digests.initial and digests.final digests")
        if scenario in DRAWING_SCENARIOS:
            frames = record.get("frames") if isinstance(record.get("frames"), list) else []
            if not any(isinstance(f, dict) and f.get("non_blank") is True and f.get("sha256") is not None
                       for f in frames):
                problems.append(f"frames: a {scenario} pass has at least one frame with non_blank true and a sha256")
    elif result in {"fail", "error"} and failures is not None and not failures:
        problems.append(f"failures: a {result} names at least one failure")

    environment = record.get("environment")
    device = isinstance(environment, dict) and environment.get("kind") == "device"
    _identifiers("", record, device, problems)
    return problems


def validate_file(path) -> list[str]:
    """The problems of the record in one JSON file; an unreadable file or bad JSON is a problem too."""
    try:
        record = json.loads(Path(path).read_text(encoding="utf-8"))
    except OSError as e:
        return [f"file: cannot be read ({e.strerror or e})"]
    except ValueError as e:
        return [f"file: not valid JSON ({e})"]
    return validate(record)


# --- self-test -----------------------------------------------------------------------------------------------------

def sample_record(kind: str = "simulator") -> dict:
    """A valid record of schema 1 (an input-response pass of the sample experience); `kind` is simulator or device."""
    h = lambda c: c * 64
    return {
        "schema": 1,
        "experience": "sample.orbit",
        "code": "sample",
        "scenario": "input-response",
        "seed": "42",
        "result": "pass",
        "run": {"id": "run-20261112-1", "attempt": 1, "lock_sha256": None},
        "environment": {"kind": kind, "os_version": "27.2", "os_build": "24C5057p", "device_type": "iPhone 18",
                        "xcode": "27.2 (27C100)", "swift": "6.3", "sdk": "iphonesimulator27.2",
                        "host_os": "macOS 27.2", "signing": "none"},
        "source": {"commit": "1" * 40, "dirty": False, "tree": "2" * 40,
                   "submodules": {"External/projectm-ios": "3" * 40},
                   "catalog_sha256": h("4"), "app_sha256": h("5")},
        "configuration": {"build": "Debug", "automation": True, "quality_tier": 2, "entitlement": "none",
                          "process": "two-launch"},
        "steps": [{"control": "speed", "values": [0.5], "result": "accepted", "reason": None, "digest": h("6")},
                  {"control": "speed", "values": [9.0], "result": "rejected", "reason": "out-of-range",
                   "digest": h("6")}],
        "digests": {"initial": h("7"), "final": h("6"), "after_restore": h("6"), "after_reset": h("7")},
        "frames": [{"non_blank": True,
                    "probes": [{"name": "center-lit", "expected": ">0.1", "observed": "0.42", "pass": True}],
                    "path": ".autonomy/evidence/scenarios/run-20261112-1/frame-0.png", "sha256": h("8")}],
        "timing": {"launch_ms": 812.5, "preparation_ms": 41.0, "shader_compilation_ms": 12.25,
                   "first_present_ms": 60.0},
        "pacing": {"samples": 120, "on_time": 119, "median_ms": 16.7, "p95_ms": 17.1, "p99_ms": 18.0},
        "resources": {"footprint_bytes": 52428800, "gpu_bytes": 8388608, "live": 12, "leaked": 0},
        "thermal_state": "nominal",
        "low_power": False,
        "battery": None,
        "artifacts": {"result_bundle": ".autonomy/xcresults/run-20261112-1.xcresult",
                      "log": ".autonomy/logs/scenarios/run-20261112-1/sample.orbit.log",
                      "log_sha256": h("9"), "record_sha256": None},
        "failures": [],
    }


def _edit(**changes):
    """A mutation that sets dotted paths (`a.b`) of a copy of the sample record; the value `...` deletes the key."""
    def apply(record: dict) -> dict:
        for dotted, value in changes.items():
            *parents, last = dotted.split("__")
            target = record
            for p in parents:
                target = target[int(p)] if isinstance(target, list) else target[p]
            if value is ...:
                del target[last]
            elif isinstance(target, list):
                target[int(last)] = value
            else:
                target[last] = value
        return record
    return apply


# (name, mutation of the sample record, substring every problem list must contain, or None for a valid record)
SELF_TEST_CASES = [
    ("valid simulator record", _edit(), None),
    ("valid device record", _edit(environment__kind="device"), None),
    ("cancel-prepare pass without evidence",
     _edit(scenario="cancel-prepare", steps=[], digests__initial=None, digests__final=None), None),
    ("fail with a failure", _edit(result="fail", failures=["digest mismatch"]), None),
    *[(f"missing {k}", _edit(**{k: ...}), f"{k}: missing") for k in FIELDS],
    ("seed as an integer", _edit(seed=42), "seed: expected a decimal string"),
    ("schema 0", _edit(schema=0), "unknown schema"),
    ("schema 2", _edit(schema=2), "newer schema"),
    ("short digest", _edit(digests__initial="a" * 63), "digests.initial"),
    ("upper-case hash", _edit(source__app_sha256="A" * 64), "source.app_sha256"),
    ("result ok", _edit(result="ok"), "result: expected one of"),
    ("pass with failures", _edit(failures=["x"]), "failures: a pass has no failures"),
    ("pass without evidence", _edit(steps=[], digests__initial=None, digests__final=None), "steps: a pass"),
    ("drawing pass without a frame", _edit(scenario="launch-first-frame", frames=[]), "frames: a launch-first-frame"),
    ("drawing pass with a blank frame", _edit(scenario="hero", frames__0__non_blank=False), "frames: a hero"),
    ("error without failures", _edit(result="error"), "failures: a error"),
    ("UDID in the log path",
     _edit(artifacts__log=".autonomy/logs/0A1B2C3D-0000-4000-8000-00000000ABCD/x.log"), "artifacts.log: value looks like a UDID"),
    ("ECID-shaped value", _edit(environment__device_type="0x001A2B3C4D5E6F7"), "looks like an ECID"),
    ("kind emulator", _edit(environment__kind="emulator"), "environment.kind"),
    ("extra top-level field", _edit(extra=1), "extra: unknown top-level field"),
    ("device record with a serial key",
     _edit(environment__kind="device", environment__serial="none"), "environment.serial: a device record"),
    ("run attempt 0", _edit(run__attempt=0), "run.attempt"),
    ("negative timing", _edit(timing__launch_ms=-1), "timing.launch_ms"),
]


def self_test() -> list[str]:
    """Runs every built-in case; returns the description of each case that did not behave."""
    bad: list[str] = []
    for name, mutate, expected in SELF_TEST_CASES:
        problems = validate(mutate(copy.deepcopy(sample_record())))
        if expected is None and problems:
            bad.append(f"{name}: expected valid, got {problems}")
        elif expected is not None and not any(expected in p for p in problems):
            bad.append(f"{name}: expected a problem containing {expected!r}, got {problems}")
    return bad


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("files", nargs="*", help="evidence record JSON files")
    ap.add_argument("--self-test", action="store_true", help="run the built-in cases")
    try:
        a = ap.parse_args(argv)
    except SystemExit as e:
        return 0 if e.code == 0 else 2
    if not a.files and not a.self_test:
        print("FAIL: name at least one record file, or --self-test")
        return 2
    code = 0
    if a.self_test:
        bad = self_test()
        for line in bad:
            print(f"FAIL: self-test: {line}")
        if bad:
            code = 1
        else:
            print(f"PASS: self-test ({len(SELF_TEST_CASES)} cases)")
    for name in a.files:
        problems = validate_file(name)
        for p in problems:
            print(f"FAIL: {name}: {p}")
        if problems:
            code = 1
        else:
            print(f"PASS: {name}")
    return code


if __name__ == "__main__":
    sys.exit(main())
