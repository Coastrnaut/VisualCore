#!/usr/bin/env python3
"""The experience verification driver (feature UA-F09 T-U09-021, T-U09-023, T-U09-026; FR-U09-020 to FR-U09-025,
FR-U09-033, FR-U09-050 to FR-U09-055, FR-U09-060, FR-U09-061; research R6, R7, R8, R10;
specs/195-ua-f09-verification-runner/contracts/verification-api.md, section Tools).

  python3 scripts/verify_experiences.py --only a99.contract-sample --runtime 27 26
  python3 scripts/verify_experiences.py --only debug --runtime 27 --scenario save-restore
  python3 scripts/verify_experiences.py --only a99.contract-sample --scenario endurance --runtime 27
  python3 scripts/verify_experiences.py --audits
  python3 scripts/verify_experiences.py --self-test [--runtime 27]
  python3 scripts/verify_experiences.py --only a99.contract-sample debug --runtime 27 26 --dry-run

Experiences. `a99.contract-sample` (code `sample`) takes the package path: its host tests run once per driver run,
then on each runtime `scripts/xcodebuild_package.py` runs the scenario tests of `ScenarioRunnerTests`, one
`-only-testing` id per scenario, into `.autonomy/xcresults/verify-<id>-<runtime>-<run>.xcresult`. The driver then
checks that bundle itself (`xcrun xcresulttool get test-results summary`: `result` Passed and no failed test) and
exports its attachments (`xcrun xcresulttool export attachments`); each attachment named
`evidence-a99.contract-sample-<scenario>.json` is a record, and each attachment named
`frame-a99.contract-sample-<scenario>.rgba` is the frame that record hashes. `endurance` is its own test run
(`ScenarioRunnerTests/testEnduranceKeepsResourcesFlat`, 600 simulated seconds) whose record
`evidence-a99.contract-sample-endurance.json` is validated and counted like the others. The test command runs in
its own process group, and the whole group is killed when its limit (540 s) passes. The summary's `bundle` block
carries the bundle's result, counts, destination (name and OS from the summary's devicesAndConfigurations) and the
names of its failed tests (`xcrun xcresulttool get test-results tests`: every node of type "Test Case" whose result
is Failed). `debug` is the app's debug experience
(`a98.debug-experience`, code `debug`); it and every id registered in `Catalog/registrations.json` take the app path:
one unsigned Debug build per driver run into `Build/DerivedData/verify` (after `release_check.py --only xcodegen`),
then per runtime the simulator is chosen by runtime and kind, booted (limit 300 s), the app installed, and each
scenario launched with `simctl launch --terminate-running-process` and the `SIMCTL_CHILD_VISUALCORE_AUTORUN*`
environment. The driver waits for `Documents/visualcore-evidence/<run>/<id>.<scenario>.json` in the app's data
container (limit `--max-seconds`, default 120; endurance 600 + 120), then for the process to exit (limit 30 s),
copies the record to `.autonomy/verify/<run>/<runtime>/` and removes it from the container. While it waits for the
record it also watches the process: a process that is gone without a record fails at once ("the app exited without
a record (crash)"). When no record came within the limit or the process did not exit, the app is stopped with
`xcrun simctl terminate <udid> dev.visualcore.VisualCore` (limit 30 s) and that is reported. When no record came,
the driver also reads `Documents/visualcore-evidence/invalid-request/request-error.json` (the app's error record
for a request whose run id did not parse) and reports its failures. `save-restore` is two launches: phase `save`
(its record is completed, kept as `<id>.save-restore.save.json`, validated and must be `pass`; otherwise the
scenario fails with "save phase: …" and no restore launch is made; its `digests.final` is passed on), then phase
`restore` with `VISUALCORE_AUTORUN_EXPECTED_DIGEST`; the restore record is the scenario's record. A launch refused
with "Busy" is retried once after 20 s.

Frames. The app writes the read frame's RGBA bytes (rows bottom-up) as `<id>.<scenario>.frame.rgba` beside its
record; the package tests attach `frame-<id>-<scenario>.rgba`. When a record's `frames[0]` names a `sha256`, the
driver copies that file (app path: from the container, then removes it there; package path: from the exported
attachments) to `.autonomy/verify/<run>/<runtime>/<id>.<scenario>.frame.rgba`, requires its SHA-256 to equal
`frames[0].sha256` (a missing file or another hash fails the scenario with "frame: …"), and sets `frames[0].path` to
that repository-relative path before the record is validated and hashed.

Process exit. `simctl launch` prints `<bundle id>: <pid>`. A simulator app is a process of the host, so the driver
polls `ps -p <pid> -o pid=` (exit 1 once the process is gone). When the launch printed no pid, it polls
`xcrun simctl spawn <udid> launchctl list` until no line names `UIKitApplication:<bundle id>`.

Records. The driver completes `run.attempt` (from the run state), `environment` (kind simulator, the runtime's
version and build, the device type identifier, `xcodebuild -version`, the first line of `swift --version`, the
simulator SDK build, `sw_vers -productVersion`, signing none), `source` (`git rev-parse HEAD`, `git status
--porcelain` not empty, `git rev-parse HEAD^{tree}`, `git submodule status`, SHA-256 of `Catalog/experiences.json`,
SHA-256 of the binary under test) and `artifacts`. The binary under test is, on the app path, the app's main
executable; on the package path, the `VisualCoreExperienceHostTests.xctest` executable under
`Build/DerivedData/VisualCoreRendering-sim-<runtime>`, or, when it cannot be found, the result bundle's
`Info.plist` (stated in the run output). `artifacts.record_sha256` is the SHA-256 of the record written with that
field set to null (sorted keys, two-space indent, trailing newline); the run state and the summary carry the same
hash. Every record is checked with `scripts/check_evidence.py`. A scenario counts only when its bundle (package
path) passed, its record validates, its code is the experience's code and its result is `pass`.

State and outputs. `.autonomy/verify/state.json` holds `{runs: {"<id>|<scenario>|<runtime>": {result,
record_sha256, finished, commit, binary_sha256, attempt[, process]}}}`. Unless `--fresh`, a scenario is skipped only
when its last result is `pass`, its `commit` is the current `git rev-parse HEAD` and its `binary_sha256` (the app's
executable on the app path, the test bundle's executable on the package path, the same hash as `source.app_sha256`)
equals that of the binary on disk now; anything else is run again. A summary row of a save-restore whose record says
`configuration.process` `single` (the package path) carries `"process": "single"`: it is not proof of a relaunch.
`.autonomy/verify/lock` (with the
pid) refuses a second concurrent run; a lock whose pid is not alive is removed. Tracked summaries go to
`docs/verification/<id>/summary-<runtime>.json` (no simulator identifier, no device name); raw logs go to
`.autonomy/logs/verify/<run>/`, records to `.autonomy/verify/<run>/`, bundles to `.autonomy/xcresults/`.

Audits (`--audits`, over `git ls-files` restricted to shipped paths): markers, raster files, reducer bypass,
content counts, direct GL (`check_app_isolation.py`), network (`check_compliance.py`), and the entitlement audit,
which is named as not yet provided (UA-F08) and never counted. A raster file passes only when
`Catalog/generated-art.json` lists it with its SHA-256, its path is inside
`Apps/VisualCore/Resources/Assets.xcassets/AppIcon.appiconset/` and its `generator` names a file of the repository.
The reducer-bypass and content audits read the scenario manifests of the registered experiences: a registration in
`Catalog/registrations.json` names its manifest as `registrations[<id>].manifest`, a repository-relative JSON file
(the manifest's JSON form: experience, kind, controls, scenarios). A game's levels come from the runtime catalog
(`Catalog/experiences.json`, the entry's `content.levels`; null counts 0), not from the manifest. While no
experience is registered, both audits print `SKIP: … (nothing to audit yet: 0 registered experiences)` and do not
fail; they act from the first registration (UA-F07). `--audits` together with `--only` runs the audits only (no
simulator work), with the bypass and content audits scoped to those ids. `--self-test` plants defects in a temporary tree and
requires each to be found and nothing else; with `--runtime` it also runs the sample's `LossySnapshot` variant,
whose save-restore record must be judged a failure by name.

Every external command goes through one runner (`run(argv, timeout, cwd=None, env=None, kill_group=False) -> (code,
stdout, stderr)`; `kill_group` starts the command in its own session and kills its whole process group at the
limit), and every wait uses an injected clock and sleep, so the script tests touch no simulator.
Exit codes: 0 everything passed; 1 a failure (also a held lock); 2 bad input (unknown id or scenario, no runtime).
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import plistlib
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
HERE = Path(__file__).resolve().parent
PY = sys.executable or "python3"

STANDARD = ["launch-first-frame", "input-response", "completion", "rejection", "save-restore", "reset",
            "suspend-resume", "teardown-reentry", "cancel-prepare"]
ENDURANCE = "endurance"
ENDURANCE_SECONDS = 600          # the longest endurance a manifest may name (data-model section 2)
SCENARIOS = STANDARD + [ENDURANCE]
BUNDLE_ID = "dev.visualcore.VisualCore"
BOOT_LIMIT = 300
EXIT_LIMIT = 30
BUSY_WAIT = 20
TEST_RUN_LIMIT = 540            # the limit of the test runners (scripts/xcodebuild_app.py --max-seconds)
TERMINATE_LIMIT = 30
BUILD_LIMIT = 600
COMMAND_LIMIT = 120

SAMPLE_ID = "a99.contract-sample"
DEBUG_ID = "a98.debug-experience"
ALIASES = {"debug": DEBUG_ID}
EXPERIENCES = {
    SAMPLE_ID: {
        "path": "package", "code": "sample",
        "package": "Packages/VisualCoreRendering", "scheme": "VisualCoreRendering-Package",
        "only_testing": "VisualCoreExperienceHostTests/ScenarioRunnerTests",
        "endurance_test": "testEnduranceKeepsResourcesFlat",
        "lossy_test": "testALossySnapshotFailsSaveRestoreByName",
        "test_binary": "VisualCoreExperienceHostTests",
        "host_tests": ["swift", "test", "--package-path", "Packages/VisualCore", "--filter", "VisualCoreExperienceTests"],
    },
    DEBUG_ID: {"path": "app", "code": "debug", "host_tests": None},
}
APP_DERIVED = "Build/DerivedData/verify"
APP_PATH = APP_DERIVED + "/Build/Products/Debug-iphonesimulator/VisualCore.app"
EVIDENCE_DIR = "Documents/visualcore-evidence"
KINDS = {"phone": "iPhone", "tablet": "iPad"}
UDID = re.compile(r"[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}")
LOSSY = "save-restore-lossy"
REQUEST_ERROR = "invalid-request/request-error.json"
APP_ICON_SET = "Apps/VisualCore/Resources/Assets.xcassets/AppIcon.appiconset/"


class BadInput(Exception):
    """Input the driver refuses (exit 2)."""


# --- the runner ----------------------------------------------------------------------------------------------------

def system_run(argv: list[str], timeout: float, cwd=None, env=None, kill_group: bool = False) -> tuple[int, str, str]:
    """Runs one command with a time limit; a command that does not finish in time returns code 124. With
    `kill_group` the command starts in its own session (process group), and at the limit the whole group is killed,
    so children such as xcodebuild under a wrapper script stop too."""
    if kill_group:
        try:
            proc = subprocess.Popen(argv, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, cwd=cwd,
                                    env=env, start_new_session=True)
        except OSError as e:
            return 127, "", f"cannot run {argv[0]}: {e}"
        try:
            out, err = proc.communicate(timeout=timeout)
            return proc.returncode, out or "", err or ""
        except subprocess.TimeoutExpired:
            try:
                os.killpg(proc.pid, signal.SIGKILL)
            except (ProcessLookupError, PermissionError):
                pass
            try:
                out, _ = proc.communicate(timeout=10)
            except subprocess.TimeoutExpired:
                out = ""
            return 124, out or "", f"timeout after {timeout:.0f} s; process group killed"
    try:
        r = subprocess.run(argv, capture_output=True, text=True, timeout=timeout, cwd=cwd, env=env)
        return r.returncode, r.stdout or "", r.stderr or ""
    except subprocess.TimeoutExpired as e:
        out = e.stdout.decode() if isinstance(e.stdout, bytes) else (e.stdout or "")
        return 124, out, f"timeout after {timeout:.0f} s"
    except OSError as e:
        return 127, "", f"cannot run {argv[0]}: {e}"


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def dump(data) -> str:
    return json.dumps(data, indent=2, sort_keys=True) + "\n"


def load_check_evidence():
    if str(HERE) not in sys.path:
        sys.path.insert(0, str(HERE))
    import check_evidence
    return check_evidence


# --- planning ------------------------------------------------------------------------------------------------------

def registrations(root: Path) -> dict[str, dict]:
    """`Catalog/registrations.json` as {id: registration}; a list of ids gives empty registrations."""
    try:
        data = json.loads((Path(root) / "Catalog" / "registrations.json").read_text(encoding="utf-8"))
        regs = data.get("registrations", {}) if isinstance(data, dict) else {}
    except (OSError, ValueError):
        return {}
    if isinstance(regs, dict):
        return {str(k): (v if isinstance(v, dict) else {}) for k, v in regs.items()}
    if isinstance(regs, list):
        return {str(k): {} for k in regs}
    return {}


def registered_ids(root: Path) -> list[str]:
    return sorted(registrations(root))


def plan(only: list[str], skip: list[str], scenarios: list[str] | None, registrations: list[str]) -> list[dict]:
    """One item per experience to verify: {id, code, path, scenarios, entry}. Aliases are resolved, `skip` is
    applied after, and an unknown id or scenario raises BadInput."""
    if scenarios:
        unknown = [s for s in scenarios if s not in SCENARIOS]
        if unknown:
            raise BadInput("unknown scenario: " + ", ".join(unknown) + " (known: " + ", ".join(SCENARIOS) + ")")
    chosen = list(dict.fromkeys(scenarios)) if scenarios else list(STANDARD)
    skipped = {ALIASES.get(s, s) for s in skip}
    items: list[dict] = []
    for raw in only:
        ident = ALIASES.get(raw, raw)
        if ident in EXPERIENCES:
            entry = EXPERIENCES[ident]
        elif ident in registrations:
            entry = {"path": "app", "code": None, "host_tests": None}
        else:
            raise BadInput(f"unknown experience: {raw}")
        if ident in skipped or any(i["id"] == ident for i in items):
            continue
        items.append({"id": ident, "code": entry["code"], "path": entry["path"], "scenarios": list(chosen),
                      "entry": entry})
    return items


def test_method(scenario: str) -> str:
    """`launch-first-frame` → `testLaunchFirstFrame` (the scenario tests of ScenarioRunnerTests)."""
    return "test" + "".join(part[:1].upper() + part[1:] for part in scenario.split("-"))


# --- simulators ----------------------------------------------------------------------------------------------------

def parse_runtimes(text: str) -> list[dict]:
    """The available iOS runtimes of `xcrun simctl list -j runtimes`: {version, build, identifier}."""
    out = []
    for r in json.loads(text).get("runtimes", []):
        ident = str(r.get("identifier", ""))
        if r.get("isAvailable", True) and ("iOS" in str(r.get("platform", "")) or ".iOS-" in ident):
            out.append({"version": str(r.get("version", "")), "build": str(r.get("buildversion", "")),
                        "identifier": ident})
    return out


def _version_key(v: str) -> tuple:
    return tuple(int(p) if p.isdigit() else 0 for p in v.split("."))


def resolve_runtime(runtimes: list[dict], arg: str) -> dict:
    """27 → the newest installed iOS 27.x; 26 → iOS 26.5; a full version (27.2) → exactly that one."""
    if arg == "26":
        wanted = [r for r in runtimes if r["version"] == "26.5"]
    elif "." in arg:
        wanted = [r for r in runtimes if r["version"] == arg]
    else:
        wanted = [r for r in runtimes if r["version"].split(".")[0] == arg]
    if not wanted:
        raise BadInput(f"no installed iOS simulator runtime for {arg}")
    return max(wanted, key=lambda r: _version_key(r["version"]))


def pick_device(devices: dict, runtime: dict, kind: str) -> dict:
    """The first available simulator of the runtime whose name starts with the family of `kind` (the same choice
    as scripts/xcodebuild_package.py), as {udid, name, device_type}. The identifier is used for commands only."""
    prefix = KINDS[kind]
    for key, listed in sorted(devices.get("devices", {}).items()):
        m = re.search(r"SimRuntime\.iOS-(\d+)-(\d+)$", key)
        if key != runtime["identifier"] and not (m and f"{m.group(1)}.{m.group(2)}" == runtime["version"]):
            continue
        for d in listed:
            if d.get("isAvailable", True) and str(d.get("name", "")).startswith(prefix) and d.get("udid"):
                return {"udid": d["udid"], "name": d["name"], "device_type": d.get("deviceTypeIdentifier", "")}
    raise BadInput(f"no available {prefix} simulator for iOS {runtime['version']}")


# --- result bundles ------------------------------------------------------------------------------------------------

def parse_bundle_summary(text: str) -> dict:
    """The verdict of `xcresulttool get test-results summary --format json`, read defensively: {ok, result, total,
    passed, failed, skipped, destination: {name, os}}. `ok` needs result Passed and 0 failed tests."""
    try:
        data = json.loads(text)
    except ValueError:
        return {"ok": False, "result": "unreadable", "total": 0, "passed": 0, "failed": 0, "skipped": 0,
                "destination": None}
    if not isinstance(data, dict):
        data = {}

    def count(key):
        v = data.get(key)
        return v if isinstance(v, int) and not isinstance(v, bool) else 0

    destination = None
    for d in data.get("devicesAndConfigurations") or []:
        device = d.get("device") if isinstance(d, dict) else None
        if isinstance(device, dict):
            destination = {"name": str(device.get("modelName") or device.get("deviceName") or ""),
                           "os": str(device.get("osVersion") or "")}
            break
    result = str(data.get("result", "missing"))
    failed = count("failedTests")
    total = count("totalTestCount")
    return {"ok": result == "Passed" and failed == 0 and total > 0, "result": result, "total": total,
            "passed": count("passedTests"), "failed": failed, "skipped": count("skippedTests"),
            "destination": destination}


def parse_attachments(folder: Path) -> list[tuple[str, Path]]:
    """(suggested name, exported file) for every exported attachment. Read from `manifest.json` when it exists,
    else every `evidence-*.json` and `frame-*.rgba` file of the folder under its own name."""
    manifest = folder / "manifest.json"
    out: list[tuple[str, Path]] = []
    if manifest.is_file():
        try:
            tests = json.loads(manifest.read_text(encoding="utf-8"))
        except ValueError:
            tests = []
        for test in tests if isinstance(tests, list) else []:
            for a in (test.get("attachments") or []) if isinstance(test, dict) else []:
                name = a.get("suggestedHumanReadableName") or a.get("exportedFileName")
                exported = a.get("exportedFileName") or name
                if name and exported:
                    out.append((str(name), folder / str(exported)))
        return out
    return [(p.name, p) for p in sorted(list(folder.glob("evidence-*.json")) + list(folder.glob("frame-*.rgba")))]


def attachment_scenario(name: str, experience: str, kind: str = "evidence", ext: str = ".json") -> str | None:
    """The scenario of `evidence-<experience>-<scenario>[_<n>_<uuid>].json` (or, with kind `frame` and ext `.rgba`,
    of `frame-<experience>-<scenario>[_<n>_<uuid>].rgba`), or None for another attachment."""
    prefix = f"{kind}-{experience}-"
    if not name.startswith(prefix) or not name.endswith(ext):
        return None
    rest = name[len(prefix):-len(ext)]
    rest = re.sub(r"_\d+_[0-9A-Fa-f-]+$", "", rest)
    return rest if re.fullmatch(r"[a-z0-9-]{1,64}", rest) else None


def parse_failed_tests(text: str) -> list[str]:
    """The names of the failed tests of `xcresulttool get test-results tests --format json`: every node, at any
    depth, whose nodeType is "Test Case" and whose result is Failed."""
    try:
        data = json.loads(text)
    except ValueError:
        return []
    names: list[str] = []

    def walk(node):
        if isinstance(node, list):
            for n in node:
                walk(n)
        elif isinstance(node, dict):
            if node.get("nodeType") == "Test Case" and node.get("result") == "Failed":
                names.append(str(node.get("name") or node.get("nodeIdentifier") or "unnamed test"))
            walk(node.get("children") or [])
    walk(data.get("testNodes") if isinstance(data, dict) else data)
    return names


# --- records -------------------------------------------------------------------------------------------------------

def parse_xcode(text: str) -> str:
    """`Xcode 27.2\\nBuild version 27C100` → `27.2 (27C100)`."""
    v = re.search(r"Xcode\s+(\S+)", text)
    b = re.search(r"Build version\s+(\S+)", text)
    if v and b:
        return f"{v.group(1)} ({b.group(1)})"
    return text.strip().splitlines()[0] if text.strip() else "unknown"


def parse_submodules(text: str) -> dict[str, str]:
    out = {}
    for line in text.splitlines():
        m = re.match(r"^[ +\-U]?([0-9a-f]{40}) (\S+)", line)
        if m:
            out[m.group(2)] = m.group(1)
    return out


def complete_record(record: dict, *, run_id: str, attempt: int, environment: dict, source: dict,
                    artifacts: dict) -> dict:
    """The driver's fields of a record (data-model section 4)."""
    record = json.loads(json.dumps(record))
    run = record.get("run") if isinstance(record.get("run"), dict) else {}
    run.update({"id": run_id, "attempt": attempt})
    run.setdefault("lock_sha256", None)
    record["run"] = run
    record["environment"] = dict(environment)
    record["source"] = dict(source)
    art = record.get("artifacts") if isinstance(record.get("artifacts"), dict) else {}
    art.update(artifacts)
    art["record_sha256"] = None
    record["artifacts"] = art
    return record


def seal_record(record: dict) -> tuple[dict, str]:
    """Sets artifacts.record_sha256 to the hash of the record written with that field null; returns both."""
    record["artifacts"]["record_sha256"] = None
    digest = sha256_bytes(dump(record).encode())
    record["artifacts"]["record_sha256"] = digest
    return record, digest


def judge(record: dict, code: str | None, bundle_ok: bool | None) -> tuple[str, list[str]]:
    """The driver's verdict on one completed record: ("pass", []) or ("fail", problems)."""
    problems = [f"record: {p}" for p in load_check_evidence().validate(record)]
    if bundle_ok is False:
        problems.append("result bundle did not pass")
    if code is not None and record.get("code") != code:
        problems.append(f"code {record.get('code')!r} is not {code!r}")
    if record.get("result") != "pass":
        problems.append(f"result {record.get('result')}: " + "; ".join(map(str, record.get("failures") or [])))
    return ("pass" if not problems else "fail"), problems


# --- the driver ----------------------------------------------------------------------------------------------------

class Driver:
    def __init__(self, root: Path = ROOT, run=system_run, clock=time.monotonic, sleep=time.sleep, now=None,
                 out=None, pid_alive=None, pid: int | None = None, max_seconds: int = 120, fresh: bool = False,
                 kind: str = "phone"):
        self.root = Path(root)
        self.run = run
        self.clock = clock
        self.sleep = sleep
        self.now = now or (lambda: dt.datetime.now())
        self.out = out or (lambda line: print(line, flush=True))
        self.pid_alive = pid_alive or _pid_alive
        self.pid = os.getpid() if pid is None else pid
        self.max_seconds = max_seconds
        self.fresh = fresh
        self.kind = kind
        self.run_id = "verify-" + self.now().strftime("%Y%m%dT%H%M%S")
        self.failures: list[str] = []
        self._cache: dict = {}
        self.records: list[dict] = []
        self.written: dict[str, dict] = {}     # "<runtime>/<file name>" → the completed record

    # paths
    @property
    def verify_dir(self) -> Path:
        return self.root / ".autonomy" / "verify"

    def run_dir(self, runtime: str) -> Path:
        d = self.verify_dir / self.run_id / runtime
        d.mkdir(parents=True, exist_ok=True)
        return d

    def log_path(self, name: str) -> Path:
        d = self.root / ".autonomy" / "logs" / "verify" / self.run_id
        d.mkdir(parents=True, exist_ok=True)
        return d / f"{name}.log"

    def rel(self, path: Path) -> str:
        try:
            return Path(path).relative_to(self.root).as_posix()
        except ValueError:
            return str(path)

    def fail(self, text: str) -> None:
        self.failures.append(text)
        self.out("FAIL: " + text)

    # lock and state
    def acquire_lock(self) -> bool:
        self.verify_dir.mkdir(parents=True, exist_ok=True)
        lock = self.verify_dir / "lock"
        for _ in range(2):
            try:
                fd = os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
            except FileExistsError:
                try:
                    holder = int(lock.read_text().strip() or "0")
                except (OSError, ValueError):
                    holder = 0
                if holder and self.pid_alive(holder):
                    self.out(f"FAIL: another verification run holds {self.rel(lock)} (pid {holder})")
                    return False
                self.out(f"stale lock of pid {holder} removed")
                lock.unlink(missing_ok=True)
                continue
            with os.fdopen(fd, "w") as f:
                f.write(f"{self.pid}\n")
            return True
        return False

    def release_lock(self) -> None:
        lock = self.verify_dir / "lock"
        try:
            if lock.read_text().strip() == str(self.pid):
                lock.unlink()
        except OSError:
            pass

    def load_state(self) -> dict:
        try:
            data = json.loads((self.verify_dir / "state.json").read_text(encoding="utf-8"))
            if isinstance(data, dict) and isinstance(data.get("runs"), dict):
                return data
        except (OSError, ValueError):
            pass
        return {"runs": {}}

    def save_state(self, state: dict) -> None:
        self.verify_dir.mkdir(parents=True, exist_ok=True)
        tmp = self.verify_dir / "state.json.tmp"
        tmp.write_text(dump(state))
        tmp.replace(self.verify_dir / "state.json")

    @staticmethod
    def key(ident: str, scenario: str, runtime: str) -> str:
        return f"{ident}|{scenario}|{runtime}"

    def pending(self, state: dict, ident: str, scenarios: list[str], runtime: str,
                binary: str | None = None) -> list[str]:
        """The scenarios to run: all with `--fresh`; otherwise every one whose last result is not a pass made at
        the current commit with the binary `binary` (None: no binary on disk, so nothing is skipped)."""
        if self.fresh:
            return list(scenarios)
        commit = self.cached("commit", ["git", "rev-parse", "HEAD"]).strip()

        def current(entry: dict) -> bool:
            return (entry.get("result") == "pass" and bool(commit) and entry.get("commit") == commit
                    and binary is not None and entry.get("binary_sha256") == binary)
        return [s for s in scenarios if not current(state["runs"].get(self.key(ident, s, runtime), {}))]

    def record_state(self, state: dict, ident: str, scenario: str, runtime: str, result: str,
                     record_sha: str | None, binary: str | None = None, record: dict | None = None) -> None:
        key = self.key(ident, scenario, runtime)
        before = state["runs"].get(key, {})
        entry = {"result": result, "record_sha256": record_sha,
                 "finished": self.now().strftime("%Y-%m-%dT%H:%M:%S"),
                 "commit": self.cached("commit", ["git", "rev-parse", "HEAD"]).strip(),
                 "binary_sha256": binary, "attempt": int(before.get("attempt", 0)) + 1}
        process = ((record or {}).get("configuration") or {}).get("process") if isinstance(record, dict) else None
        if isinstance(process, str):
            entry["process"] = process
        state["runs"][key] = entry
        self.save_state(state)

    def current_binary(self, item: dict, runtime: dict) -> str | None:
        """The SHA-256 of the binary under test as it is on disk before this run (None when there is none): the
        app's executable on the app path, the test bundle's executable on the package path."""
        if item["path"] == "app":
            sha = self.app_binary_sha()
            return None if sha == "0" * 64 else sha
        found = self.test_binary_path(item, runtime)
        return sha256_file(found) if found else None

    def attempt(self, state: dict, ident: str, scenario: str, runtime: str) -> int:
        return int(state["runs"].get(self.key(ident, scenario, runtime), {}).get("attempt", 0)) + 1

    # commands
    def cmd(self, argv: list[str], timeout: float = COMMAND_LIMIT, **kw) -> tuple[int, str, str]:
        return self.run(argv, timeout, **kw)

    def terminate(self, udid: str, label: str) -> None:
        """Stops the app on the simulator (bounded) after a scenario gave no record or did not exit."""
        code, _, err = self.cmd(["xcrun", "simctl", "terminate", udid, BUNDLE_ID], TERMINATE_LIMIT)
        self.out(f"{label}: the app was terminated (xcrun simctl terminate, exit {code})")

    def cached(self, name: str, argv: list[str]) -> str:
        if name not in self._cache:
            code, out, err = self.cmd(argv, cwd=str(self.root))
            self._cache[name] = out if code == 0 else ""
        return self._cache[name]

    def runtimes(self) -> list[dict]:
        if "runtimes" not in self._cache:
            code, out, err = self.cmd(["xcrun", "simctl", "list", "-j", "runtimes"])
            if code != 0:
                raise BadInput("cannot list simulator runtimes: " + err.strip())
            self._cache["runtimes"] = parse_runtimes(out)
        return self._cache["runtimes"]

    def device(self, runtime: dict) -> dict:
        key = "device-" + runtime["version"]
        if key not in self._cache:
            code, out, err = self.cmd(["xcrun", "simctl", "list", "-j", "devices", "available"])
            if code != 0:
                raise BadInput("cannot list simulators: " + err.strip())
            self._cache[key] = pick_device(json.loads(out), runtime, self.kind)
        return self._cache[key]

    def environment(self, runtime: dict, device: dict) -> dict:
        swift = self.cached("swift", ["swift", "--version"]).strip().splitlines()
        return {"kind": "simulator", "os_version": runtime["version"], "os_build": runtime["build"],
                "device_type": device["device_type"],
                "xcode": parse_xcode(self.cached("xcode", ["xcodebuild", "-version"])),
                "swift": swift[0] if swift else "unknown",
                "sdk": self.cached("sdk", ["xcrun", "--sdk", "iphonesimulator", "--show-sdk-build-version"]).strip()
                or "unknown",
                "host_os": self.cached("host", ["sw_vers", "-productVersion"]).strip() or "unknown",
                "signing": "none"}

    def source(self, binary_sha: str) -> dict:
        commit = self.cached("commit", ["git", "rev-parse", "HEAD"]).strip()
        tree = self.cached("tree", ["git", "rev-parse", "HEAD^{tree}"]).strip()
        dirty = self.cached("dirty", ["git", "status", "--porcelain"]).strip() != ""
        submodules = parse_submodules(self.cached("submodules", ["git", "submodule", "status"]))
        catalog = self.root / "Catalog" / "experiences.json"
        return {"commit": commit, "dirty": dirty, "tree": tree, "submodules": submodules,
                "catalog_sha256": sha256_file(catalog) if catalog.is_file() else "0" * 64,
                "app_sha256": binary_sha}

    def write_log(self, name: str, parts: list[str]) -> tuple[str, str]:
        path = self.log_path(name)
        path.write_text("".join(parts))
        return self.rel(path), sha256_file(path)

    def finish_record(self, raw: dict, *, ident: str, code: str | None, scenario: str, runtime: dict,
                      device: dict, attempt: int, binary_sha: str, log: tuple[str, str], bundle: str | None,
                      bundle_ok: bool | None, dest_name: str, extra: list[str] | None = None
                      ) -> tuple[str, str, list[str]]:
        """Completes, seals, writes and judges one record; returns (result, record hash, problems). `extra` are
        problems found before (the frame check), which fail the record too."""
        record = complete_record(raw, run_id=self.run_id, attempt=attempt,
                                 environment=self.environment(runtime, device), source=self.source(binary_sha),
                                 artifacts={"result_bundle": bundle, "log": log[0], "log_sha256": log[1]})
        record, digest = seal_record(record)
        target = self.run_dir(runtime["version"]) / dest_name
        target.write_text(dump(record))
        self.records.append(record)
        self.written[f"{runtime['version']}/{dest_name}"] = record
        result, problems = judge(record, code, bundle_ok)
        problems = list(extra or []) + problems
        return ("pass" if not problems else "fail"), digest, problems

    def keep_frame(self, raw: dict, dest: Path, copy) -> list[str]:
        """When the record's frames[0] names a sha256: `copy(dest)` brings the frame file to `dest`, its SHA-256
        must equal that hash, and frames[0].path becomes the repository-relative path. Returns the problems."""
        frames = raw.get("frames") if isinstance(raw, dict) else None
        if not isinstance(frames, list) or not frames or not isinstance(frames[0], dict):
            return []
        expected = frames[0].get("sha256")
        if not isinstance(expected, str) or not expected:
            return []
        dest.unlink(missing_ok=True)
        if not copy(dest) or not dest.is_file():
            return [f"frame: no frame file {dest.name} beside the record"]
        frames[0]["path"] = self.rel(dest)
        actual = sha256_file(dest)
        if actual != expected:
            return [f"frame: SHA-256 of {self.rel(dest)} is {actual}, the record names {expected}"]
        return []

    # host tests
    def host_tests(self, item: dict) -> bool:
        argv = item["entry"].get("host_tests")
        if not argv:
            return True
        key = "host-" + item["id"]
        if key in self._cache:
            return self._cache[key]
        self.out("$ " + " ".join(argv))
        code, out, err = self.cmd(argv, TEST_RUN_LIMIT, cwd=str(self.root))
        self.write_log(f"host-{item['id']}", [out, err])
        ok = code == 0
        if not ok:
            self.fail(f"{item['id']}: host tests failed (exit {code})")
        self._cache[key] = ok
        return ok

    # package path
    def package_test(self, item: dict, runtime: dict, methods: list[str], suffix: str) -> dict:
        """Runs one package test into its own result bundle and checks the bundle; returns {bundle, summary,
        attachments, log}. The test command runs in its own process group, killed as a whole at its limit."""
        entry = item["entry"]
        rt = runtime["version"]
        name = f"verify-{item['id']}-{rt}-{self.run_id}{suffix}"
        bundle = self.root / ".autonomy" / "xcresults" / f"{name}.xcresult"
        argv = [PY, "scripts/xcodebuild_package.py", "--package", entry["package"], "--scheme", entry["scheme"],
                "--destination", f"sim-{rt}", "--action", "test", "--result-name", name,
                "--only-testing", *[f"{entry['only_testing']}/{m}" for m in methods]]
        self.out("$ " + " ".join(argv))
        code, out, err = self.cmd(argv, TEST_RUN_LIMIT, cwd=str(self.root), kill_group=True)
        if code == 124:
            self.out(f"{item['id']} {rt}: the test run passed its limit of {TEST_RUN_LIMIT} s; its process group "
                     "was killed")
        log = self.write_log(name, [out, err])
        result = {"bundle": bundle, "log": log, "exit": code, "attachments": [], "summary": None,
                  "failed_tests": []}
        if not bundle.exists():
            result["summary"] = {"ok": False, "result": "missing", "total": 0, "passed": 0, "failed": 0,
                                 "skipped": 0, "destination": None}
            return result
        scode, sout, serr = self.cmd(["xcrun", "xcresulttool", "get", "test-results", "summary", "--path",
                                      str(bundle), "--format", "json"])
        summary = parse_bundle_summary(sout) if scode == 0 else parse_bundle_summary("")
        if code != 0 and summary["ok"]:
            summary = dict(summary, ok=False, result=f"Passed, but the test command exited {code}")
        result["summary"] = summary
        tcode, tout, _ = self.cmd(["xcrun", "xcresulttool", "get", "test-results", "tests", "--path", str(bundle),
                                   "--format", "json"])
        result["failed_tests"] = parse_failed_tests(tout) if tcode == 0 else []
        folder = self.run_dir(rt) / f"attachments-{item['id']}{suffix}"
        shutil.rmtree(folder, ignore_errors=True)
        folder.mkdir(parents=True, exist_ok=True)
        ecode, _, eerr = self.cmd(["xcrun", "xcresulttool", "export", "attachments", "--path", str(bundle),
                                   "--output-path", str(folder)])
        if ecode == 0:
            result["attachments"] = parse_attachments(folder)
        return result

    def test_binary_path(self, item: dict, runtime: dict) -> Path | None:
        name = item["entry"]["test_binary"]
        base = self.root / "Build" / "DerivedData" / f"{Path(item['entry']['package']).name}-sim-{runtime['version']}"
        found = sorted((base / "Build" / "Products").glob(f"*/{name}.xctest/{name}")) if base.is_dir() else []
        return found[0] if found else None

    def test_binary_sha(self, item: dict, runtime: dict, bundle: Path) -> str:
        found = self.test_binary_path(item, runtime)
        if found:
            return sha256_file(found)
        name = item["entry"]["test_binary"]
        base = self.root / "Build" / "DerivedData" / f"{Path(item['entry']['package']).name}-sim-{runtime['version']}"
        info = bundle / "Info.plist"
        self.out(f"note: {name}.xctest not found under {self.rel(base)}; app_sha256 is the result bundle's Info.plist")
        return sha256_file(info) if info.is_file() else "0" * 64

    @staticmethod
    def bundle_block(summary: dict, failed_tests: list[str]) -> dict:
        """The summary's `bundle` block of one result bundle."""
        return {"result": summary["result"], "total": summary["total"], "passed": summary["passed"],
                "failed": summary["failed"], "destination": summary.get("destination"),
                "failed_tests": list(failed_tests)}

    def verify_package(self, item: dict, runtime: dict, state: dict, scenarios: list[str],
                       lossy: bool = False) -> dict:
        """Returns {scenario: (result, record hash)} for the scenarios run, plus the bundle block. The standard
        scenarios share one test run; endurance is a test run of its own; both give records."""
        ident, rt = item["id"], runtime["version"]
        device = self.device(runtime)
        results: dict[str, tuple[str, str | None]] = {}
        bundle_info = None
        normal = [s for s in scenarios if s != ENDURANCE]
        groups = []
        methods = [test_method(s) for s in normal] + ([item["entry"]["lossy_test"]] if lossy else [])
        if methods:
            groups.append((methods, normal + ([LOSSY] if lossy else []), ""))
        if ENDURANCE in scenarios:
            groups.append(([item["entry"]["endurance_test"]], [ENDURANCE], "-endurance"))
        for methods, wanted, suffix in groups:
            run = self.package_test(item, runtime, methods, suffix)
            summary = run["summary"]
            block = self.bundle_block(summary, run["failed_tests"])
            if bundle_info is None:
                bundle_info = block
            else:                      # the endurance run joins the block of the standard run
                bundle_info = {"result": block["result"] if bundle_info["result"] == "Passed" else bundle_info["result"],
                               "total": bundle_info["total"] + block["total"],
                               "passed": bundle_info["passed"] + block["passed"],
                               "failed": bundle_info["failed"] + block["failed"],
                               "destination": bundle_info["destination"] or block["destination"],
                               "failed_tests": bundle_info["failed_tests"] + block["failed_tests"]}
            self.out(f"{'PASS' if summary['ok'] else 'FAIL'}: {ident} {rt} result bundle{suffix and ' (endurance)'} "
                     f"{summary['result']}, {summary['passed']} of {summary['total']} passed, {summary['failed']} "
                     "failed" + (f" ({', '.join(run['failed_tests'])})" if run["failed_tests"] else ""))
            binary = self.test_binary_sha(item, runtime, run["bundle"])
            found: dict[str, Path] = {}
            frames: dict[str, Path] = {}
            for name, path in run["attachments"]:
                scenario = attachment_scenario(name, ident)
                if scenario:
                    found[scenario] = path
                scenario = attachment_scenario(name, ident, "frame", ".rgba")
                if scenario:
                    frames[scenario] = path
            for scenario in wanted:
                attempt = self.attempt(state, ident, scenario, rt)
                path = found.get(scenario)
                if path is None or not path.is_file():
                    if scenario != LOSSY:
                        self.fail(f"{ident} {scenario} {rt}: no record in the result bundle")
                        if not lossy:
                            self.record_state(state, ident, scenario, rt, "fail", None, binary)
                    results[scenario] = ("missing", None)
                    continue
                try:
                    raw = json.loads(path.read_text(encoding="utf-8"))
                except ValueError:
                    raw = {}
                extra: list[str] = []
                if scenario != LOSSY:
                    source = frames.get(scenario)

                    def copy(dest: Path, source=source) -> bool:
                        if source is None or not source.is_file():
                            return False
                        shutil.copyfile(source, dest)
                        return True
                    extra = self.keep_frame(raw, self.run_dir(rt) / f"{ident}.{scenario}.frame.rgba", copy)
                result, digest, problems = self.finish_record(
                    raw, ident=ident, code=item["code"], scenario=scenario, runtime=runtime, device=device,
                    attempt=attempt, binary_sha=binary, log=run["log"], bundle=self.rel(run["bundle"]),
                    bundle_ok=summary["ok"], dest_name=f"{ident}.{scenario}.json", extra=extra)
                results[scenario] = (result, digest)
                if scenario == LOSSY:
                    continue
                if result == "pass":
                    self.out(f"PASS: {ident} {scenario} {rt}")
                else:
                    self.fail(f"{ident} {scenario} {rt}: " + "; ".join(problems))
                if not lossy:
                    self.record_state(state, ident, scenario, rt, result, digest, binary,
                                      self.written.get(f"{rt}/{ident}.{scenario}.json"))
        return {"results": results, "bundle": bundle_info, "device": device}

    # app path
    def build_app(self) -> bool:
        if "app-build" in self._cache:
            return self._cache["app-build"]
        parts = []
        steps = [[PY, "scripts/release_check.py", "--only", "xcodegen"],
                 ["xcodebuild", "build", "-project", "VisualCore.xcodeproj", "-scheme", "VisualCore",
                  "-configuration", "Debug", "-destination", "generic/platform=iOS Simulator",
                  "-derivedDataPath", APP_DERIVED, "CODE_SIGNING_ALLOWED=NO"]]
        ok = True
        for argv in steps:
            self.out("$ " + " ".join(argv))
            code, out, err = self.cmd(argv, BUILD_LIMIT, cwd=str(self.root))
            parts += ["$ " + " ".join(argv) + "\n", out, err]
            if code != 0:
                self.fail(f"app build failed (exit {code}): {' '.join(argv[:3])}")
                ok = False
                break
        self.write_log("app-build", parts)
        self._cache["app-build"] = ok
        return ok

    def app_binary_sha(self) -> str:
        app = self.root / APP_PATH
        try:
            with open(app / "Info.plist", "rb") as f:
                exe = app / plistlib.load(f)["CFBundleExecutable"]
            return sha256_file(exe)
        except (OSError, KeyError, ValueError, plistlib.InvalidFileException):
            return "0" * 64

    def prepare_simulator(self, runtime: dict, device: dict, log: list[str]) -> str | None:
        """Boots (bounded), installs and returns the app's data container, or None after a failure."""
        udid = device["udid"]
        key = "container-" + runtime["version"]
        if key in self._cache:
            return self._cache[key]
        self.cmd(["xcrun", "simctl", "boot", udid], COMMAND_LIMIT)          # an already booted device is fine
        code, out, err = self.cmd(["xcrun", "simctl", "bootstatus", udid, "-b"], BOOT_LIMIT)
        if code != 0:
            self.fail(f"simulator of iOS {runtime['version']} did not boot within {BOOT_LIMIT} s")
            self._cache[key] = None
            return None
        code, out, err = self.cmd(["xcrun", "simctl", "install", udid, str(self.root / APP_PATH)], COMMAND_LIMIT)
        if code != 0:
            self.fail(f"install on iOS {runtime['version']} failed: {err.strip()[:200]}")
            self._cache[key] = None
            return None
        code, out, err = self.cmd(["xcrun", "simctl", "get_app_container", udid, BUNDLE_ID, "data"])
        container = out.strip() if code == 0 and out.strip() else None
        if container is None:
            self.fail(f"no data container of {BUNDLE_ID} on iOS {runtime['version']}")
        self._cache[key] = container
        return container

    def launch(self, udid: str, env: dict, log: list[str]) -> tuple[bool, int | None, str]:
        argv = ["xcrun", "simctl", "launch", "--terminate-running-process", udid, BUNDLE_ID]
        for attempt in range(2):
            code, out, err = self.cmd(argv, COMMAND_LIMIT, env={**os.environ, **env})
            log += ["$ simctl launch " + " ".join(f"{k}={v}" for k, v in sorted(env.items())) + "\n", out, err]
            if code == 0:
                m = re.search(r":\s*(\d+)\s*$", out.strip())
                return True, int(m.group(1)) if m else None, ""
            if "Busy" in err and attempt == 0:
                self.out(f"simulator busy; launch retried once after {BUSY_WAIT} s")
                self.sleep(BUSY_WAIT)
                continue
            return False, None, err.strip()[:200]
        return False, None, "busy"

    def wait_for(self, check, limit: float) -> bool:
        start = self.clock()
        while True:
            if check():
                return True
            if self.clock() - start >= limit:
                return False
            self.sleep(1)

    def process_gone(self, udid: str, pid: int | None) -> bool:
        if pid is not None:
            code, out, _ = self.cmd(["ps", "-p", str(pid), "-o", "pid="], 10)
            return code != 0 or not out.strip()
        code, out, _ = self.cmd(["xcrun", "simctl", "spawn", udid, "launchctl", "list"], 30)
        return code == 0 and f"UIKitApplication:{BUNDLE_ID}" not in out

    def request_error(self, container: str, rt: str, label: str) -> str | None:
        """The failures of the app's error record for a request whose run id did not parse
        (`visualcore-evidence/invalid-request/request-error.json`), or None when there is none."""
        path = f"{container}/{EVIDENCE_DIR}/{REQUEST_ERROR}"
        if self.cmd(["test", "-f", path], 10)[0] != 0:
            return None
        target = self.run_dir(rt) / f"{label.split(' ')[0]}.request-error.json"
        code, _, _ = self.cmd(["cp", path, str(target)], 30)
        self.cmd(["rm", "-f", path], 30)
        try:
            failures = json.loads(target.read_text(encoding="utf-8")).get("failures") or []
        except (OSError, ValueError, AttributeError):
            failures = []
        return "; ".join(map(str, failures)) or "an error record without failures"

    def app_launch(self, item: dict, scenario: str, runtime: dict, device: dict, container: str, log: list[str],
                   phase: str | None = None, expected: str | None = None, dest_name: str | None = None
                   ) -> tuple[dict | None, str | None, list[str]]:
        """One launch of one scenario: (raw record, None, frame problems) or (None, failure, [])."""
        ident, rt, udid = item["id"], runtime["version"], device["udid"]
        evidence = f"{container}/{EVIDENCE_DIR}/{self.run_id}"
        self.cmd(["rm", "-rf", evidence], 30)
        self.cmd(["rm", "-f", f"{container}/{EVIDENCE_DIR}/{REQUEST_ERROR}"], 30)
        if scenario == "save-restore" and phase != "restore":
            self.cmd(["rm", "-rf", f"{container}/Library/Application Support/Experiences/{ident}"], 30)
        env = {"SIMCTL_CHILD_VISUALCORE_AUTORUN": "scenario", "SIMCTL_CHILD_VISUALCORE_AUTORUN_EXPERIENCE": ident,
               "SIMCTL_CHILD_VISUALCORE_AUTORUN_SCENARIO": scenario, "SIMCTL_CHILD_VISUALCORE_AUTORUN_RUN": self.run_id}
        if phase:
            env["SIMCTL_CHILD_VISUALCORE_AUTORUN_PHASE"] = phase
        if expected:
            env["SIMCTL_CHILD_VISUALCORE_AUTORUN_EXPECTED_DIGEST"] = expected
        ok, pid, why = self.launch(udid, env, log)
        label = f"{ident} {scenario}{' (' + phase + ')' if phase else ''} {rt}"
        if not ok:
            return None, f"{label}: launch failed: {why}", []
        limit = max(self.max_seconds, ENDURANCE_SECONDS + 120) if scenario == ENDURANCE else self.max_seconds
        record_path = f"{evidence}/{ident}.{scenario}.json"
        crashed = [False]

        def record_or_gone() -> bool:
            if self.cmd(["test", "-f", record_path], 10)[0] == 0:
                return True
            if self.process_gone(udid, pid):
                # The record may have been written just before the exit.
                if self.cmd(["test", "-f", record_path], 10)[0] != 0:
                    crashed[0] = True
                return True
            return False

        if not self.wait_for(record_or_gone, limit):
            self.terminate(udid, label)
            refused = self.request_error(container, rt, label)
            return None, f"{label}: no record within {limit:.0f} s" + (
                f"; the request was refused: {refused}" if refused else ""), []
        if crashed[0]:
            refused = self.request_error(container, rt, label)
            if refused:
                return None, f"{label}: the request was refused: {refused}", []
            return None, f"{label}: the app exited without a record (crash)", []
        if not self.wait_for(lambda: self.process_gone(udid, pid), EXIT_LIMIT):
            self.terminate(udid, label)
            return None, f"{label}: the process did not exit within {EXIT_LIMIT} s", []
        name = dest_name or f"{ident}.{scenario}.json"
        target = self.run_dir(rt) / name
        code, _, err = self.cmd(["cp", record_path, str(target)], 30)
        if code != 0:
            return None, f"{label}: record could not be copied: {err.strip()[:200]}", []
        self.cmd(["rm", "-f", record_path], 30)
        try:
            raw = json.loads(target.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            return None, f"{label}: the record is not valid JSON", []
        frame_path = f"{evidence}/{ident}.{scenario}.frame.rgba"

        def copy(dest: Path) -> bool:
            if self.cmd(["test", "-f", frame_path], 10)[0] != 0:
                return False
            copied = self.cmd(["cp", frame_path, str(dest)], 30)[0] == 0
            self.cmd(["rm", "-f", frame_path], 30)
            return copied
        extra = self.keep_frame(raw, self.run_dir(rt) / (name[:-len(".json")] + ".frame.rgba"), copy) \
            if isinstance(raw, dict) else []
        return raw, None, extra

    def verify_app(self, item: dict, runtime: dict, state: dict, scenarios: list[str]) -> dict:
        ident, rt = item["id"], runtime["version"]
        results: dict[str, tuple[str, str | None]] = {}
        device = self.device(runtime)

        def fail_all(reason: str):
            for s in scenarios:
                self.fail(f"{ident} {s} {rt}: {reason}")
                self.record_state(state, ident, s, rt, "fail", None)
                results[s] = ("fail", None)
            return {"results": results, "bundle": None, "device": device}

        if not self.build_app():
            return fail_all("the app did not build")
        container = self.prepare_simulator(runtime, device, [])
        if container is None:
            return fail_all("the simulator could not be prepared")
        binary = self.app_binary_sha()
        for scenario in scenarios:
            log: list[str] = []
            attempt = self.attempt(state, ident, scenario, rt)
            extra: list[str] = []
            if scenario == "save-restore":
                saved, why, save_extra = self.app_launch(item, scenario, runtime, device, container, log,
                                                         phase="save", dest_name=f"{ident}.save-restore.save.json")
                digest = None
                if saved is not None:
                    # The save phase is judged like any record; a failed save phase fails the scenario and the
                    # restore launch is not made.
                    save_log = self.write_log(f"{ident}-{rt}-save-restore-save", log)
                    save_result, _, save_problems = self.finish_record(
                        saved, ident=ident, code=item["code"], scenario=scenario, runtime=runtime, device=device,
                        attempt=attempt, binary_sha=binary, log=save_log, bundle=None, bundle_ok=None,
                        dest_name=f"{ident}.save-restore.save.json", extra=save_extra)
                    digest = (saved.get("digests") or {}).get("final") if isinstance(saved, dict) else None
                    if save_result != "pass":
                        why = f"{ident} save-restore {rt}: save phase: " + "; ".join(save_problems)
                    elif not digest:
                        why = f"{ident} save-restore (save) {rt}: the save record has no digests.final"
                raw = None
                if why is None:
                    raw, why, extra = self.app_launch(item, scenario, runtime, device, container, log,
                                                      phase="restore", expected=digest)
            else:
                raw, why, extra = self.app_launch(item, scenario, runtime, device, container, log)
            logref = self.write_log(f"{ident}-{rt}-{scenario}", log)
            if raw is None:
                self.fail(why)
                self.record_state(state, ident, scenario, rt, "fail", None, binary)
                results[scenario] = ("fail", None)
                continue
            result, digest, problems = self.finish_record(
                raw, ident=ident, code=item["code"], scenario=scenario, runtime=runtime, device=device,
                attempt=attempt, binary_sha=binary, log=logref, bundle=None, bundle_ok=None,
                dest_name=f"{ident}.{scenario}.json", extra=extra)
            if result == "pass":
                self.out(f"PASS: {ident} {scenario} {rt}")
            else:
                self.fail(f"{ident} {scenario} {rt}: " + "; ".join(problems))
            self.record_state(state, ident, scenario, rt, result, digest, binary,
                              self.written.get(f"{rt}/{ident}.{scenario}.json"))
            results[scenario] = (result, digest)
        return {"results": results, "bundle": None, "device": device}

    # summaries
    def write_summary(self, item: dict, runtime: dict, device: dict, state: dict, bundle) -> Path | None:
        # Every standard scenario, then any other this run or an earlier one ran: a run of a few scenarios
        # keeps the latest results of the others, each with the commit it was made at.
        names = list(STANDARD)
        for s in item["scenarios"]:
            if s not in names:
                names.append(s)
        for key in state["runs"]:
            ident, scenario, version = key.split("|")
            if ident == item["id"] and version == runtime["version"] and scenario not in names:
                names.append(scenario)
        rows = []
        for s in names:
            entry = state["runs"].get(self.key(item["id"], s, runtime["version"]), {})
            row = {"scenario": s, "result": entry.get("result", "not-run"), "record_sha256": entry.get("record_sha256"),
                   "commit": entry.get("commit")}
            if s == "save-restore" and entry.get("process") == "single":
                row["process"] = "single"          # one process: not proof of a relaunch (FR-U09-013)
            rows.append(row)
        summary = {"schema": 1, "experience": item["id"], "runtime": runtime["version"],
                   "runtime_build": runtime["build"], "device_type": device["device_type"],
                   "commit": self.cached("commit", ["git", "rev-parse", "HEAD"]).strip(),
                   "results": rows, "bundle": bundle}
        text = dump(summary)
        if UDID.search(text):
            self.fail(f"{item['id']} {runtime['version']}: the summary would carry a simulator identifier; not written")
            return None
        path = self.root / "docs" / "verification" / item["id"] / f"summary-{runtime['version']}.json"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
        self.out(f"summary {self.rel(path)}")
        return path

    def verify(self, items: list[dict], runtime_args: list[str]) -> int:
        if not self.acquire_lock():
            return 1
        try:
            runtimes = [resolve_runtime(self.runtimes(), r) for r in runtime_args]
            state = self.load_state()
            self.out(f"run {self.run_id}")
            for item in items:
                if not self.host_tests(item):
                    for rt in runtimes:
                        for s in item["scenarios"]:
                            self.record_state(state, item["id"], s, rt["version"], "fail", None)
                    continue
                for runtime in runtimes:
                    todo = self.pending(state, item["id"], item["scenarios"], runtime["version"],
                                        None if self.fresh else self.current_binary(item, runtime))
                    done = [s for s in item["scenarios"] if s not in todo]
                    if done:
                        self.out(f"{item['id']} {runtime['version']}: passed earlier at this commit with this "
                                 f"binary, skipped: {', '.join(done)}")
                    if not todo:
                        continue
                    if item["path"] == "package":
                        result = self.verify_package(item, runtime, state, todo)
                    else:
                        result = self.verify_app(item, runtime, state, todo)
                    self.write_summary(item, runtime, result["device"], state, result["bundle"])
        except BadInput as e:
            self.out(f"FAIL: {e}")
            return 2
        finally:
            self.release_lock()
        passed = not self.failures
        self.out(("PASS" if passed else "FAIL") + f": {len(self.failures)} failures in run {self.run_id}")
        return 0 if passed else 1

    def lossy_self_test(self, runtime_args: list[str]) -> int:
        """Runs the sample's save-restore and its LossySnapshot variant; the variant must be judged a failure that
        names the expectation. Exit 0 when it was."""
        if not self.acquire_lock():
            return 1
        item = plan([SAMPLE_ID], [], ["save-restore"], [])[0]
        ok = True
        try:
            runtimes = [resolve_runtime(self.runtimes(), r) for r in runtime_args]
            for runtime in runtimes:
                result = self.verify_package(item, runtime, {"runs": {}}, ["save-restore"], lossy=True)
                verdict, _ = result["results"].get(LOSSY, ("missing", None))
                record = self.written.get(f"{runtime['version']}/{SAMPLE_ID}.{LOSSY}.json")
                named = bool(record) and any(str(f).startswith("after-restore digest") or str(f).endswith("at restore")
                                             for f in record.get("failures") or [])
                valid = bool(record) and not load_check_evidence().validate(record)
                if verdict == "fail" and named and valid:
                    self.out(f"PASS: self-test {runtime['version']}: the LossySnapshot record was judged a failure "
                             f"(save-restore: {next(f for f in record['failures'] if 'restore' in f)})")
                else:
                    ok = False
                    self.out(f"FAIL: self-test {runtime['version']}: the LossySnapshot record was not detected "
                             f"(record {'found' if record else 'missing'}, verdict {verdict}, valid {valid}, "
                             f"named {named})")
        except BadInput as e:
            self.out(f"FAIL: {e}")
            return 2
        finally:
            self.release_lock()
        return 0 if ok else 1


def _pid_alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


# --- audits --------------------------------------------------------------------------------------------------------

SHIPPED_PREFIXES = ("Apps/VisualCore/App/", "Apps/VisualCore/Resources/")
SHIPPED_FILES = ("Catalog/experiences.json", "Catalog/categories.json")
RASTER = {".png", ".jpg", ".jpeg", ".gif", ".heic", ".webp", ".tif", ".tiff", ".bmp", ".psd", ".ico", ".icns"}
CODE_EXT = {".swift": True, ".glsl": False, ".vsh": False, ".fsh": False, ".vert": False, ".frag": False,
            ".c": False, ".h": False, ".m": False, ".mm": False, ".metal": False}
WORK_MARKER = re.compile(r"\b(TODO|FIXME|XXX)\b")
VISIBLE_MARKER = re.compile(r"lorem ipsum|coming soon|placeholder", re.IGNORECASE)
VIEW_CALLEES = {"Text", "Label", "Button", "accessibilityLabel", "accessibilityHint", "navigationTitle"}


def shipped(path: str) -> bool:
    if path.startswith("Packages/VisualCore/Sources/VisualCoreTestSupport/"):
        return False
    if path.startswith(SHIPPED_PREFIXES) or path in SHIPPED_FILES:
        return True
    parts = path.split("/")
    return len(parts) > 3 and parts[0] == "Packages" and parts[2] == "Sources"


def lex(text: str, swift: bool) -> list[tuple[str, int, int]]:
    """(kind, start, end) of every comment and string literal; kind is `comment` or `string`. Swift block comments
    nest; Swift raw (`#"…"#`) and multi-line strings are understood; the code of an interpolation stays in the
    string."""
    tokens = []
    i, n = 0, len(text)
    while i < n:
        c = text[i]
        if text.startswith("//", i):
            j = text.find("\n", i)
            j = n if j < 0 else j
            tokens.append(("comment", i, j))
            i = j
        elif text.startswith("/*", i):
            depth, j = 1, i + 2
            while j < n and depth:
                if swift and text.startswith("/*", j):
                    depth, j = depth + 1, j + 2
                elif text.startswith("*/", j):
                    depth, j = depth - 1, j + 2
                else:
                    j += 1
            tokens.append(("comment", i, j))
            i = j
        elif swift and c == "#" and re.match(r'#+"', text[i:i + 64]):
            hashes = len(re.match(r"#+", text[i:]).group(0))
            opening = text[i + hashes:i + hashes + 3]
            quote = '"""' if opening == '"""' else '"'
            close = quote + "#" * hashes
            j = text.find(close, i + hashes + len(quote))
            j = n if j < 0 else j + len(close)
            tokens.append(("string", i, j))
            i = j
        elif text.startswith('"""', i):
            j = i + 3
            while j < n and not text.startswith('"""', j):
                j += 2 if text[j] == "\\" else 1
            j = min(n, j + 3)
            tokens.append(("string", i, j))
            i = j
        elif c == '"':
            j = i + 1
            while j < n and text[j] != '"' and text[j] != "\n":
                if text[j] == "\\" and swift and j + 1 < n and text[j + 1] == "(":
                    depth, j = 1, j + 2
                    while j < n and depth:
                        depth += {"(": 1, ")": -1}.get(text[j], 0)
                        j += 1
                    continue
                j += 2 if text[j] == "\\" else 1
            j = min(n, j + 1)
            tokens.append(("string", i, j))
            i = j
        elif c == "'" and not swift:
            j = i + 1
            while j < n and text[j] != "'" and text[j] != "\n":
                j += 2 if text[j] == "\\" else 1
            i = j + 1
        else:
            i += 1
    return tokens


def _code_view(text: str, tokens) -> str:
    """The text with comments and string contents blanked (newlines kept), so brackets inside them do not count."""
    chars = list(text)
    for kind, start, end in tokens:
        lo, hi = (start, end) if kind == "comment" else (start + 1, end - 1)
        for k in range(lo, max(lo, hi)):
            if chars[k] != "\n":
                chars[k] = " "
    return "".join(chars)


def view_callee(code: str, start: int) -> bool:
    """Whether the string literal at `start` is an argument of a view text call (Text, Label, Button,
    .accessibilityLabel, .accessibilityHint, .navigationTitle) or of String(localized:)."""
    depth, j = 0, start - 1
    while j >= 0 and start - j < 4000:
        ch = code[j]
        if ch in ")]}":
            depth += 1
        elif ch in "([{":
            if depth == 0:
                if ch != "(":
                    return False
                m = re.search(r"([A-Za-z_][A-Za-z0-9_]*)\s*$", code[max(0, j - 200):j])
                if not m:
                    return False
                name = m.group(1)
                if name in VIEW_CALLEES:
                    return True
                if name == "String" and re.fullmatch(r"\s*localized\s*:\s*", code[j + 1:start]):
                    return True
                return False
            depth -= 1
        j -= 1
    return False


def _line(text: str, offset: int) -> int:
    return text.count("\n", 0, offset) + 1


def _xcstrings_values(data) -> list[str]:
    out = []
    strings = data.get("strings", {}) if isinstance(data, dict) else {}
    for key, entry in strings.items():
        if not isinstance(entry, dict) or not entry.get("localizations"):
            out.append(key)                       # no localization: the key is the text shown
            continue

        def walk(node):
            if isinstance(node, dict):
                unit = node.get("stringUnit")
                if isinstance(unit, dict) and isinstance(unit.get("value"), str):
                    out.append(unit["value"])
                for v in node.values():
                    walk(v)
            elif isinstance(node, list):
                for v in node:
                    walk(v)
        walk(entry["localizations"])
    return out


def _json_strings(node) -> list[str]:
    if isinstance(node, str):
        return [node]
    if isinstance(node, dict):
        return [s for k, v in node.items() for s in [k] + _json_strings(v)]
    if isinstance(node, list):
        return [s for v in node for s in _json_strings(v)]
    return []


def audit_markers(root: Path, files: list[str]) -> list[str]:
    """TODO, FIXME, XXX in comments and strings; lorem ipsum, coming soon, placeholder in visible text."""
    findings = []
    for rel in files:
        path = Path(root) / rel
        ext = path.suffix.lower()
        try:
            text = path.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError):
            continue
        if ext in CODE_EXT:
            swift = CODE_EXT[ext]
            tokens = lex(text, swift)
            code = _code_view(text, tokens) if swift else ""
            for kind, start, end in tokens:
                chunk = text[start:end]
                m = WORK_MARKER.search(chunk)
                if m:
                    findings.append(f"{rel}:{_line(text, start)}: {m.group(1)} in a {kind}")
                if swift and kind == "string":
                    v = VISIBLE_MARKER.search(chunk)
                    if v and view_callee(code, start):
                        findings.append(f"{rel}:{_line(text, start)}: \"{v.group(0)}\" in visible text")
        elif ext == ".xcstrings":
            try:
                values = _xcstrings_values(json.loads(text))
            except ValueError:
                findings.append(f"{rel}: not valid JSON")
                continue
            for value in values:
                for rx, what in ((WORK_MARKER, "work marker"), (VISIBLE_MARKER, "visible text")):
                    m = rx.search(value)
                    if m:
                        findings.append(f"{rel}: \"{m.group(0)}\" in the string catalog ({what})")
        elif ext == ".json":
            try:
                values = _json_strings(json.loads(text))
            except ValueError:
                continue
            for value in values:
                m = WORK_MARKER.search(value)
                if m:
                    findings.append(f"{rel}: {m.group(1)} in a string")
    return findings


def audit_raster(root: Path, files: list[str]) -> list[str]:
    """Every raster file is a finding unless Catalog/generated-art.json lists it with its SHA-256, the path is inside
    the app icon set (the only generated raster allowed) and its `generator` is a file of the repository."""
    listed: dict[str, dict] = {}
    try:
        art = json.loads((Path(root) / "Catalog" / "generated-art.json").read_text(encoding="utf-8"))
        for f in art.get("files", []):
            listed[str(f.get("path"))] = f
    except (OSError, ValueError, AttributeError):
        pass
    findings = []
    for rel in files:
        if Path(rel).suffix.lower() not in RASTER:
            continue
        if rel not in listed:
            findings.append(f"{rel}: raster file not listed in Catalog/generated-art.json")
            continue
        entry = listed[rel]
        path = Path(root) / rel
        actual = sha256_file(path) if path.is_file() else "missing"
        if actual != str(entry.get("sha256")):
            findings.append(f"{rel}: SHA-256 differs from Catalog/generated-art.json")
        if not rel.startswith(APP_ICON_SET):
            findings.append(f"{rel}: a generated raster outside {APP_ICON_SET}")
        generator = entry.get("generator")
        gen_path = (Path(root) / generator).resolve() if isinstance(generator, str) and generator else None
        inside = gen_path is not None and str(gen_path).startswith(str(Path(root).resolve()) + os.sep)
        if not inside or not gen_path.is_file():
            findings.append(f"{rel}: generator {generator!r} is not a file of the repository")
    return findings


def audit_bypass(manifests: list[dict], records: list[dict]) -> list[str]:
    """Static: an action of an undeclared control (when the manifest lists its controls); an entry digest, final
    digest or outcome expected before any action (except launch-first-frame and reset). Dynamic: a record whose
    failures report a bypass (the evaluator's check that the engine handled as many actions as were sent)."""
    findings = []
    for m in manifests:
        exp = m.get("experience", "?")
        controls = m.get("controls")
        declared = {c if isinstance(c, str) else c.get("id") for c in controls} if isinstance(controls, list) else None
        for spec in m.get("scenarios", []):
            name = spec.get("name", "?")
            exempt = name in ("launch-first-frame", "reset")
            acted = False
            for i, entry in enumerate(spec.get("entries", [])):
                action = entry.get("action")
                if action:
                    acted = True
                    if declared is not None and action.get("control") not in declared:
                        findings.append(f"{exp} {name}: entry {i} acts on an undeclared control")
                if entry.get("digest") and not acted and not exempt:
                    findings.append(f"{exp} {name}: entry {i} expects a digest without an action before it")
            expect = spec.get("expect") or {}
            if (expect.get("outcome") or expect.get("finalDigest")) and not acted and not exempt:
                findings.append(f"{exp} {name}: an outcome or final digest is expected without actions")
    for r in records:
        if any("bypass" in str(f) for f in r.get("failures") or []):
            findings.append(f"{r.get('experience')} {r.get('scenario')}: the engine handled fewer actions than sent")
    return findings


def content_requirement(row: dict) -> dict:
    """The planning catalog's content counts of one experience."""
    def rows(key):
        v = row.get(key) or (row.get("design") or {}).get(key) or {}
        return int(v.get("rows", 0)) if isinstance(v, dict) else 0
    fixtures = (row.get("design") or {}).get("fixtures") or []
    return {"acceptance": rows("acceptance_scenarios"), "faults": rows("fault_injection"),
            "levels": rows("level_manifest"), "fixtures": len(fixtures) if isinstance(fixtures, list) else 0}


def runtime_levels(runtime_catalog: dict, ident: str) -> int:
    """The levels of one experience in the runtime catalog (`Catalog/experiences.json`): `content.levels`, where a
    null content or null levels count 0."""
    for e in (runtime_catalog or {}).get("experiences", []) if isinstance(runtime_catalog, dict) else []:
        if isinstance(e, dict) and e.get("id") == ident:
            content = e.get("content")
            levels = content.get("levels") if isinstance(content, dict) else None
            return levels if isinstance(levels, int) and not isinstance(levels, bool) else 0
    return 0


def audit_content(manifests: list[dict], registered: list[str], catalog: dict,
                  runtime_catalog: dict | None = None) -> list[str]:
    """For each registered experience: its manifest has the nine standard scenarios and at least the planning
    catalog's acceptance, fault and fixture scenarios; its levels in the runtime catalog (`content.levels`) are at
    least the planning catalog's."""
    rows = {e.get("id"): e for e in catalog.get("experiences", [])} if isinstance(catalog, dict) else {}
    by_id = {m.get("experience"): m for m in manifests}
    findings = []
    for ident in registered:
        m = by_id.get(ident)
        if m is None:
            findings.append(f"{ident}: registered without a scenario manifest")
            continue
        names = [s.get("name", "") for s in m.get("scenarios", [])]
        missing = [s for s in STANDARD if s not in names]
        if missing:
            findings.append(f"{ident}: standard scenarios missing: {', '.join(missing)}")
        need = content_requirement(rows.get(ident, {}))
        have = {"acceptance": sum(n.startswith("acceptance-") for n in names),
                "faults": sum(n.startswith("fault-") for n in names),
                "fixtures": sum(n.startswith("fixture-") for n in names),
                "levels": runtime_levels(runtime_catalog or {}, ident)}
        for k in ("acceptance", "faults", "levels", "fixtures"):
            if have[k] < need[k]:
                findings.append(f"{ident}: {have[k]} {k} below the planning catalog's {need[k]}")
    return findings


def tracked_files(root: Path, run) -> list[str]:
    code, out, err = run(["git", "ls-files", "-z"], COMMAND_LIMIT, cwd=str(root))
    if code != 0:
        raise BadInput("git ls-files failed: " + err.strip())
    return [p for p in out.split("\0") if p]


def load_manifests(root: Path, regs: dict[str, dict]) -> tuple[list[dict], list[str]]:
    """The scenario manifests the registrations name (`registrations[id].manifest`, a repository-relative JSON
    file), with the problems of those that name a path that cannot be read. A registration without a manifest gives
    none (the content audit reports it)."""
    out, problems = [], []
    for ident, reg in sorted(regs.items()):
        rel = reg.get("manifest") if isinstance(reg, dict) else None
        if not rel:
            continue
        try:
            data = json.loads((Path(root) / str(rel)).read_text(encoding="utf-8"))
            if not isinstance(data, dict):
                raise ValueError("not an object")
            data.setdefault("experience", ident)
            out.append(data)
        except (OSError, ValueError) as e:
            problems.append(f"{ident}: manifest {rel} cannot be read ({e})")
            out.append({"experience": ident, "scenarios": [], "unreadable": True})
    return out, problems


def run_audits(root: Path, run, out, records: list[dict] | None = None, files: list[str] | None = None,
               only: list[str] | None = None) -> int:
    """Runs every audit; `only` scopes the reducer-bypass and content audits to those ids."""
    root = Path(root)
    files = [f for f in (files if files is not None else tracked_files(root, run)) if shipped(f)]
    regs = registrations(root)
    if only is not None:
        regs = {k: v for k, v in regs.items() if k in only}
    manifests, unreadable = load_manifests(root, regs)
    registered = sorted(regs)
    scoped = [r for r in (records or []) if only is None or r.get("experience") in only]
    try:
        catalog = json.loads((root / "docs" / "catalog" / "experience-catalog.json").read_text(encoding="utf-8"))
    except (OSError, ValueError):
        catalog = {}
    try:
        runtime_catalog = json.loads((root / "Catalog" / "experiences.json").read_text(encoding="utf-8"))
    except (OSError, ValueError):
        runtime_catalog = {}
    failed = False

    def report(name: str, findings: list[str], detail: str) -> None:
        nonlocal failed
        if findings:
            failed = True
            out(f"FAIL: {name}: {len(findings)} findings")
            for f in findings:
                out("    " + f)
        else:
            out(f"PASS: {name} ({detail})")

    report("markers", audit_markers(root, files), f"{len(files)} shipped files")
    report("raster", audit_raster(root, files), "no unlisted raster file")
    if not registered:
        # Nothing is registered yet: both audits act from the first registration (UA-F07).
        out("SKIP: reducer-bypass (nothing to audit yet: 0 registered experiences)")
        out("SKIP: content-counts (nothing to audit yet: 0 registered experiences)")
    else:
        report("reducer-bypass", unreadable + audit_bypass(manifests, scoped),
               f"{len(manifests)} manifests, {len(scoped)} records")
        report("content-counts", audit_content(manifests, registered, catalog, runtime_catalog),
               f"{len(registered)} registered experiences")
    for name, argv in (("direct-gl", [PY, "scripts/check_app_isolation.py", "--app", "Apps/VisualCore",
                                      "--require-sources"]),
                       ("network", [PY, "scripts/check_compliance.py"])):
        code, sout, serr = run(argv, COMMAND_LIMIT, cwd=str(root))
        tail = [line for line in (sout + serr).strip().splitlines() if line.strip()]
        report(name, [] if code == 0 else (tail[-10:] or [f"exit {code}"]), " ".join(argv[1:]))
    out("entitlement: not yet provided (UA-F08)")
    return 1 if failed else 0


# --- self-test -----------------------------------------------------------------------------------------------------

def plant(root: Path) -> tuple[list[str], list[str], list[dict], list[dict], list[str], dict, dict]:
    """Writes planted defects into `root`. Returns (tracked files, expected finding substrings, manifests, records,
    registered ids, planning catalog, runtime catalog)."""
    files = {
        "Apps/VisualCore/App/Planted.swift":
            "// TODO: finish this\n"
            "let message = \"FIXME later\"\n"
            "var body: some View { Text(\"Coming soon\") }\n"
            "let label = Label(\"A placeholder\", systemImage: \"star\")\n"
            "let placeholderSurface = 1\n"
            "// the placeholder surface keeps the context current\n"
            "let title = String(localized: \"ok\")\n",
        "Apps/VisualCore/Resources/Localizable.xcstrings": json.dumps({"sourceLanguage": "en", "strings": {
            "vc.soon": {"localizations": {"en": {"stringUnit": {"state": "translated", "value": "Coming soon"}}}},
            "vc.placeholder.key": {"localizations": {"en": {"stringUnit": {"state": "translated", "value": "Fine"}}}},
        }}),
        "Packages/VisualCore/Sources/VisualCoreTestSupport/Ignored.swift": "// TODO: test support is not shipped\n",
    }
    for rel, text in files.items():
        (root / rel).parent.mkdir(parents=True, exist_ok=True)
        (root / rel).write_text(text)
    rasters = (("Apps/VisualCore/Resources/x.png", b"\x89PNG stray"),
               (APP_ICON_SET + "wrong.png", b"\x89PNG generated"),
               (APP_ICON_SET + "right.png", b"\x89PNG generated ok"),
               ("Apps/VisualCore/Resources/outside.png", b"\x89PNG generated elsewhere"))
    for rel, data in rasters:
        (root / rel).parent.mkdir(parents=True, exist_ok=True)
        (root / rel).write_bytes(data)
    (root / "scripts").mkdir(parents=True, exist_ok=True)
    (root / "scripts" / "x.py").write_text("# the planted icon generator\n")
    (root / "Catalog").mkdir(parents=True, exist_ok=True)
    (root / "Catalog" / "generated-art.json").write_text(dump({"schema": 1, "files": [
        {"path": APP_ICON_SET + "wrong.png", "sha256": "0" * 64, "generator": "scripts/x.py"},
        {"path": APP_ICON_SET + "right.png", "sha256": sha256_bytes(b"\x89PNG generated ok"),
         "generator": "scripts/x.py"},
        {"path": "Apps/VisualCore/Resources/outside.png", "sha256": sha256_bytes(b"\x89PNG generated elsewhere"),
         "generator": "scripts/missing.py"}]}))
    untracked = root / "Apps/VisualCore/App/Build/Generated.swift"     # on disk, not tracked: never audited
    untracked.parent.mkdir(parents=True, exist_ok=True)
    untracked.write_text("// TODO: build product\n")
    tracked = sorted(files) + [rel for rel, _ in rasters]
    game = "r02-g01.aurora-loom"
    standard = [{"name": n, "seed": "1", "entries": [{"steps": 1, "action": {"control": "tap", "values": []}}],
                 "expect": {}} for n in STANDARD]
    manifests = [
        {"schema": 1, "experience": "a01.planted", "kind": "creative", "controls": ["tap"], "scenarios": [
            {"name": "completion", "seed": "1", "entries": [{"steps": 10}], "expect": {"outcome": "target-reached"}}]},
        {"schema": 1, "experience": game, "kind": "game", "round": 2,
         "scenarios": standard + [{"name": n, "seed": "1", "entries": [{"steps": 1, "action": {"control": "tap"}}],
                                   "expect": {}} for n in ["full-playthrough", "hero"]
                                  + [f"acceptance-{i:02d}" for i in range(1, 80)]]},
    ]
    records = [{"experience": "a01.planted", "scenario": "input-response", "failures": ["bypass: 3 handled of 4 sent"]}]
    catalog = {"experiences": [{"id": game, "acceptance_scenarios": {"rows": 80}, "level_manifest": {"rows": 100},
                                "design": {"fixtures": []}}]}
    runtime_catalog = {"experiences": [{"id": game, "content": {"levels": 100}}]}
    expected = ["Planted.swift:1: TODO in a comment", "Planted.swift:2: FIXME in a string",
                "Planted.swift:3: \"Coming soon\" in visible text", "Planted.swift:4: \"placeholder\" in visible text",
                "Localizable.xcstrings: \"Coming soon\" in the string catalog", "x.png: raster file not listed",
                "wrong.png: SHA-256 differs", "outside.png: a generated raster outside",
                "outside.png: generator 'scripts/missing.py' is not a file",
                "a01.planted completion: an outcome or final digest is expected",
                "a01.planted input-response: the engine handled fewer actions",
                f"{game}: 79 acceptance below the planning catalog's 80"]
    return tracked, expected, manifests, records, [game], catalog, runtime_catalog


def self_test_offline(out) -> int:
    ce = load_check_evidence()
    bad = ce.self_test()
    ok = not bad
    for line in bad:
        out(f"FAIL: self-test: check_evidence: {line}")
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        tracked, expected, manifests, records, registered, catalog, runtime_catalog = plant(root)
        files = [f for f in tracked if shipped(f)]
        findings = (audit_markers(root, files) + audit_raster(root, files) + audit_bypass(manifests, records)
                    + audit_content(manifests, registered, catalog, runtime_catalog))
    for e in expected:
        hits = [f for f in findings if e in f]
        if len(hits) != 1:
            ok = False
            out(f"FAIL: self-test: planted defect {e!r} found {len(hits)} times")
    extra = [f for f in findings if not any(e in f for e in expected)]
    for f in extra:
        ok = False
        out(f"FAIL: self-test: unexpected finding {f!r}")
    try:
        items = plan(["a99.contract-sample", "debug"], [], None, [])
        planner_ok = [(i["id"], i["path"], i["code"]) for i in items] == [
            (SAMPLE_ID, "package", "sample"), (DEBUG_ID, "app", "debug")] and items[0]["scenarios"] == STANDARD
    except BadInput:
        planner_ok = False
    try:
        plan(["no.such-experience"], [], None, [])
        planner_ok = False
    except BadInput:
        pass
    if not planner_ok:
        ok = False
        out("FAIL: self-test: planner")
    if ok:
        out(f"PASS: self-test (check_evidence {len(ce.SELF_TEST_CASES)} cases; {len(expected)} planted audit defects "
            f"found, nothing else; planner)")
    return 0 if ok else 1


# --- command line --------------------------------------------------------------------------------------------------

def shown_runtime(arg: str) -> str:
    """How a --runtime argument is shown before it is resolved: 26 → 26.5, 27 → 27.x, 27.2 → 27.2."""
    return "26.5" if arg == "26" else arg if "." in arg else f"{arg}.x"


def print_plan(items: list[dict], runtimes: list[str], driver: Driver, out) -> None:
    out(f"plan for run {driver.run_id} (dry run: nothing is executed)")
    for r in runtimes:
        out(f"runtime {r}: " + ("iOS 26.5" if r == "26" else f"the newest installed iOS {r}.x" if "." not in r
                                 else f"iOS {r}") + ", resolved from `xcrun simctl list -j runtimes`; simulator: "
            f"the first available {KINDS[driver.kind]} of that runtime")
    app_build_shown = False
    for item in items:
        e = item["entry"]
        out(f"{item['id']} (code {item['code']}): {item['path']} path; scenarios: {', '.join(item['scenarios'])}")
        if e.get("host_tests"):
            out("  host tests, once: " + " ".join(e["host_tests"]))
        for r in runtimes:
            rt = shown_runtime(r)
            if item["path"] == "package":
                normal = [s for s in item["scenarios"] if s != ENDURANCE]
                if normal:
                    name = f"verify-{item['id']}-{rt}-{driver.run_id}"
                    out(f"  {r}: python3 scripts/xcodebuild_package.py --package {e['package']} --scheme {e['scheme']} "
                        f"--destination sim-{rt} --action test --result-name {name} --only-testing "
                        + " ".join(f"{e['only_testing']}/{test_method(s)}" for s in normal) + f" (limit {TEST_RUN_LIMIT} s)")
                    out(f"  {r}: xcrun xcresulttool get test-results summary --path .autonomy/xcresults/{name}.xcresult "
                        "--format json (Passed, 0 failed); xcrun xcresulttool export attachments; check_evidence on "
                        f"each evidence-{item['id']}-<scenario>.json")
                if ENDURANCE in item["scenarios"]:
                    out(f"  {r}: endurance: --only-testing {e['only_testing']}/{e['endurance_test']} into "
                        f"verify-{item['id']}-{rt}-{driver.run_id}-endurance (600 simulated seconds; its record "
                        f"evidence-{item['id']}-endurance.json is checked like the others)")
            else:
                if not app_build_shown:
                    out("  app build, once: python3 scripts/release_check.py --only xcodegen; xcodebuild build -project "
                        "VisualCore.xcodeproj -scheme VisualCore -configuration Debug -destination 'generic/platform=iOS "
                        f"Simulator' -derivedDataPath {APP_DERIVED} CODE_SIGNING_ALLOWED=NO (limit {BUILD_LIMIT} s)")
                    app_build_shown = True
                out(f"  {r}: boot (limit {BOOT_LIMIT} s), install {APP_PATH}; per scenario: simctl launch "
                    f"--terminate-running-process {BUNDLE_ID} with VISUALCORE_AUTORUN=scenario, _EXPERIENCE={item['id']}, "
                    f"_SCENARIO=<name>, _RUN={driver.run_id}; wait ≤{driver.max_seconds} s for "
                    f"{EVIDENCE_DIR}/{driver.run_id}/{item['id']}.<scenario>.json, ≤{EXIT_LIMIT} s for the exit; copy, "
                    "then remove it" + ("; save-restore: launch phase save, then restore with _EXPECTED_DIGEST"
                                        if "save-restore" in item["scenarios"] else ""))
        for r in runtimes:
            out(f"  summary: docs/verification/{item['id']}/summary-{shown_runtime(r)}.json")


def main(argv: list[str] | None = None, *, root: Path = ROOT, run=system_run, clock=time.monotonic,
         sleep=time.sleep, now=None, out=None, pid_alive=None, pid: int | None = None) -> int:
    out = out or (lambda line: print(line, flush=True))
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--only", nargs="+", default=[], metavar="ID")
    ap.add_argument("--skip", nargs="+", default=[], metavar="ID")
    ap.add_argument("--scenario", nargs="+", default=[], metavar="NAME")
    ap.add_argument("--runtime", nargs="+", default=[], metavar="N", help="27, 26 or a full version such as 27.2")
    ap.add_argument("--kind", choices=sorted(KINDS), default="phone")
    ap.add_argument("--audits", action="store_true")
    ap.add_argument("--self-test", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--fresh", action="store_true")
    ap.add_argument("--max-seconds", type=int, default=120)
    try:
        a = ap.parse_args(argv)
    except SystemExit as e:
        return 0 if e.code == 0 else 2
    if not a.only and not a.audits and not a.self_test:
        out("FAIL: name at least one experience with --only, or --audits, or --self-test")
        return 2
    if a.max_seconds < 1:
        out("FAIL: --max-seconds must be at least 1")
        return 2
    for r in a.runtime:
        if not re.fullmatch(r"\d+(\.\d+)?", r):
            out(f"FAIL: --runtime takes 27, 26 or a version such as 27.2, not {r}")
            return 2
    driver = Driver(root=root, run=run, clock=clock, sleep=sleep, now=now, out=out, pid_alive=pid_alive, pid=pid,
                    max_seconds=a.max_seconds, fresh=a.fresh, kind=a.kind)
    try:
        items = plan(a.only, a.skip, a.scenario or None, registered_ids(Path(root))) if a.only else []
    except BadInput as e:
        out(f"FAIL: {e}")
        return 2
    # `--audits` with `--only` audits only: no simulator work, the bypass and content audits scoped to the ids.
    audit_scope = [i["id"] for i in items] if a.audits and items else None
    if audit_scope is not None:
        items = []
    runtimes = a.runtime or (["27", "26"] if items else [])
    if a.dry_run:
        if items:
            print_plan(items, runtimes, driver, out)
        if a.audits:
            out("audits: markers, raster, reducer-bypass, content-counts over `git ls-files` (shipped paths)"
                + (f", reducer-bypass and content-counts scoped to {', '.join(audit_scope)}" if audit_scope else "")
                + "; direct-gl: check_app_isolation.py --app Apps/VisualCore --require-sources; network: "
                "check_compliance.py; entitlement: not yet provided (UA-F08)")
        if a.self_test:
            out("self-test: check_evidence self-test, planted audit defects, planner"
                + (f"; LossySnapshot on {', '.join(a.runtime)}" if a.runtime else ""))
        return 0
    code = 0
    if a.self_test:
        code = max(code, self_test_offline(out))
        if a.runtime:
            code = max(code, driver.lossy_self_test(a.runtime))
    if items:
        code = max(code, driver.verify(items, runtimes))
    if a.audits:
        try:
            code = max(code, run_audits(Path(root), run, out, records=driver.records, only=audit_scope))
        except BadInput as e:
            out(f"FAIL: {e}")
            code = max(code, 2)
    return code


if __name__ == "__main__":
    sys.exit(main())
