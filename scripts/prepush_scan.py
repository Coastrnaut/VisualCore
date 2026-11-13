#!/usr/bin/env python3
"""Scan the commits that are not on origin/main yet, before they are pushed. Standard library only.

    python3 scripts/prepush_scan.py                # scan origin/main..HEAD; exit 1 on any finding
    python3 scripts/prepush_scan.py --range A..B   # another range
    python3 scripts/prepush_scan.py --push         # scan, then `git push origin main` (only on branch main, never forced)
    python3 scripts/prepush_scan.py --record-simulators   # record the hashes of this Mac's simulator identifiers

Owner rule: before any push, scan for device identifiers, ECIDs, serial numbers, team ids and secrets. The scan
reads every ADDED line of the outgoing commits (a rename without changes adds nothing) and looks for exactly the
entries of PATTERNS:

  hardware identifier        eight hexadecimal digits, a hyphen, sixteen hexadecimal digits
  device or simulator UUID   the 8-4-4-4-12 form; allowed are synthetic ids that start with 00000000-0000-4000-8000-
                             and identifiers whose SHA-256 hash is in Configs/simulator-identifier-hashes.json
  ECID, serial number        only when a value follows the word
  development team setting   a DEVELOPMENT_TEAM assignment
  development team id        "team id" followed by ten characters
  e-mail address, absolute home path with a user name, private key
  GitHub token, GitHub fine-grained token, Anthropic API key, AWS access key id

Simulator identifiers appear in recorded test commands and identify nothing outside the Mac that created them.
They are accepted through a tracked list of hashes, never through a list of identifiers, so that the scan gives the
same verdict on the development Mac and in CI (feature 186, FR-U00-025). `--record-simulators` adds the hashes of
the simulators this Mac has now; it never removes one. A simulator of this Mac that is not recorded yet is a
finding that names that command.

It also refuses when a path that must never be tracked is tracked (FORBIDDEN): private device data, logs, result
bundles, reports, the local signing file, provisioning profiles, key stores, signing keys and certificates.

Lines of scripts/test_scripts.py are not scanned: they hold deliberately fake values that test this scanner.
A finding is not always a secret. Read it, then either remove it or, when it is a synthetic value that belongs in
the repository, change it to the allowed synthetic form.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
UUID_LABEL = "device or simulator UUID"
SYNTHETIC_PREFIX = "00000000-0000-4000-8000-"
# One entry per kind of value: the self-tests hold one finding and one clean line for every label (FR-U00-020, 023).
PATTERNS = [
    ("hardware identifier", re.compile(r"\b[0-9A-Fa-f]{8}-[0-9A-Fa-f]{16}\b")),
    (UUID_LABEL, re.compile(r"\b[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\b")),
    ("ECID", re.compile(r"(?i)\becid\b[\"']?\s*[:=]\s*[\"']?(?:0x)?[0-9a-f]{6,}")),
    ("serial number", re.compile(r"(?i)\bserial(?:\s*number|number)?\b[\"']?\s*[:=]\s*[\"']?[A-Z0-9]{8,14}\b")),
    ("development team setting", re.compile(r"DEVELOPMENT_TEAM\s*[=:]\s*[A-Z0-9]{10}\b")),
    ("development team id", re.compile(r"(?i:\bteam\s*id\b[\"']?\s*[:=]\s*[\"']?)[A-Z0-9]{10}\b")),
    ("e-mail address", re.compile(r"\b[\w.+-]+@[\w-]+\.[A-Za-z]{2,}\b")),
    ("absolute home path", re.compile(r"/Users/(?!Shared/|<)[A-Za-z][\w.-]*/")),
    ("private key", re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----")),
    ("GitHub token", re.compile(r"\bghp_[A-Za-z0-9]{20,}\b")),
    ("GitHub fine-grained token", re.compile(r"\bgithub_pat_[A-Za-z0-9_]{20,}\b")),
    ("Anthropic API key", re.compile(r"\bsk-ant-[A-Za-z0-9-]{10,}\b")),
    ("AWS access key id", re.compile(r"\bAKIA[0-9A-Z]{16}\b")),
]
ALLOWED_ADDRESSES = {"git@github.com"}
# One entry per class of path that must never be tracked (FR-U00-022).
FORBIDDEN = [
    ("private device data", re.compile(r"^\.autonomy/private/")),
    ("logs", re.compile(r"^\.autonomy/logs/")),
    ("result bundles", re.compile(r"^\.autonomy/xcresults/|\.xcresult(/|$)")),
    ("reports", re.compile(r"^\.autonomy/reports/")),
    ("local signing file", re.compile(r"^Configs/Signing\.local\.xcconfig$")),
    ("provisioning profile", re.compile(r"\.mobileprovision(/|$)")),
    ("key store", re.compile(r"\.p12(/|$)")),
    ("signing key", re.compile(r"\.p8(/|$)")),
    ("certificate", re.compile(r"\.cer(/|$)")),
]
UNSCANNED = {"scripts/test_scripts.py"}
HASHES = Path("Configs/simulator-identifier-hashes.json")
HASHES_NOTE = ("SHA-256 of the upper-case identifiers of the development Mac's simulators. Written by "
               "scripts/prepush_scan.py --record-simulators. No identifier is stored.")
RECORD_COMMAND = "python3 scripts/prepush_scan.py --record-simulators"


def identifier_hash(identifier: str) -> str:
    """SHA-256 of the identifier in upper case: what the tracked list holds instead of the identifier."""
    return hashlib.sha256(identifier.upper().encode("utf-8")).hexdigest()


def load_hashes(root: Path = ROOT) -> frozenset[str]:
    """Hashes of the recorded simulator identifiers. A missing list is empty; a damaged list or another schema
    raises ValueError with a message that names the file."""
    path = root / HASHES
    if not path.is_file():
        return frozenset()
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as error:
        raise ValueError(f"{HASHES.as_posix()}: cannot be read ({type(error).__name__})") from error
    hashes = data.get("sha256") if isinstance(data, dict) else None
    if not isinstance(data, dict) or data.get("schema") != 1 or not isinstance(hashes, list) \
            or not all(isinstance(h, str) and re.fullmatch(r"[0-9a-f]{64}", h) for h in hashes):
        raise ValueError(f"{HASHES.as_posix()}: cannot be read (expected schema 1 with SHA-256 hashes only)")
    return frozenset(hashes)


def record_simulators(root: Path, identifiers) -> int:
    """Add the hashes of `identifiers` to the tracked list and return how many were new. Recorded hashes are kept;
    the list is written sorted and only when it changed, so recording twice changes no byte."""
    known = load_hashes(root)
    new = {identifier_hash(i) for i in identifiers} - known
    if new:
        path = root / HASHES
        path.parent.mkdir(parents=True, exist_ok=True)
        text = json.dumps({"schema": 1, "note": HASHES_NOTE, "sha256": sorted(known | new)}, indent=2) + "\n"
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
    return len(new)


def scan_line(line: str, allowed_hashes: frozenset[str] = frozenset(), local_simulators: frozenset[str] = frozenset()) -> list[str]:
    """Labels of everything suspicious in one added line.

    `allowed_hashes` are the recorded hashes of simulator identifiers. `local_simulators` are the upper-case
    identifiers of this machine's simulators: one of them that is not recorded is reported with the command that
    records it, instead of the plain label."""
    found = []
    for label, pattern in PATTERNS:
        for m in pattern.finditer(line):
            value = m.group(0)
            if label == "e-mail address" and value in ALLOWED_ADDRESSES:
                continue
            if label == UUID_LABEL:
                if value.upper().startswith(SYNTHETIC_PREFIX) or identifier_hash(value) in allowed_hashes:
                    continue
                if value.upper() in local_simulators:
                    found.append(f"simulator identifier not recorded (run {RECORD_COMMAND}, commit the list, then push)")
                    break
            found.append(label)
            break
    return found


def scan_diff(diff: str, allowed_hashes: frozenset[str] = frozenset(), local_simulators: frozenset[str] = frozenset()) -> list[str]:
    """Findings in a unified diff: 'file: label: text' for every suspicious added line."""
    findings, current = [], None
    for line in diff.split("\n"):
        if line.startswith("+++ "):
            current = line[6:] if line.startswith("+++ b/") else None
        elif line.startswith("+") and not line.startswith("+++") and current and current not in UNSCANNED:
            for label in scan_line(line[1:], allowed_hashes, local_simulators):
                findings.append(f"{current}: {label}: {line[1:].strip()[:100]}")
    return findings


def simulator_identifiers() -> frozenset[str] | None:
    """Upper-case identifiers of the simulators installed on this machine; None where the list cannot be read
    (no Xcode, as on a CI runner without it, or a failing `simctl`)."""
    try:
        done = subprocess.run(["xcrun", "simctl", "list", "devices", "-j"], capture_output=True, text=True, timeout=60, check=False)
    except (OSError, subprocess.TimeoutExpired):
        return None
    if done.returncode != 0:
        return None
    return frozenset(u.upper() for u in re.findall(r'"udid"\s*:\s*"([0-9A-Fa-f-]{36})"', done.stdout))


def forbidden(paths: list[str]) -> list[str]:
    return [f"{p}: this path must never be tracked ({label})" for p in paths for label, pattern in FORBIDDEN if pattern.search(p)]


def git(root: Path, *argv: str) -> subprocess.CompletedProcess:
    return subprocess.run(["git", *argv], cwd=root, capture_output=True, text=True, errors="replace", check=False)


def scan(root: Path = ROOT, commits: str = "origin/main..HEAD") -> list[str]:
    """Scans the change of every outgoing commit on its own, not only the net change of the range: a file that one
    commit adds and a later one removes is still pushed in the first commit's history (feature 195 found this when a
    raw run folder with a simulator identifier was added by one commit and untracked by the next)."""
    # A three-dot range (a pull request, <base>...<head>) is the head's side only: what the base did after the
    # fork is not part of it.
    side = ["--right-only"] if "..." in commits else []
    listed = git(root, "rev-list", "--reverse", *side, commits)
    if listed.returncode != 0:
        return [f"cannot read {commits}: {listed.stderr.strip()[:200]}"]
    findings, hashes = [], frozenset()
    try:
        hashes = load_hashes(root)
    except ValueError as error:
        findings.append(str(error))
    local = simulator_identifiers() or frozenset()
    seen: set[str] = set()
    for commit in listed.stdout.split():
        diff = git(root, "show", "--unified=0", "--no-color", "--find-renames", "--format=", commit)
        if diff.returncode != 0:
            findings.append(f"cannot read {commit[:12]}: {diff.stderr.strip()[:200]}")
            continue
        for finding in scan_diff(diff.stdout, hashes, local):
            if finding not in seen:
                seen.add(finding)
                findings.append(finding)
    return findings + forbidden(git(root, "ls-files").stdout.splitlines())


def record_command(root: Path) -> int:
    identifiers = simulator_identifiers()
    if identifiers is None:
        print("cannot read the simulator list of this machine (xcrun simctl); nothing was recorded")
        return 1
    try:
        added = record_simulators(root, identifiers)
        total = len(load_hashes(root))
    except ValueError as error:
        print(f"{error}; nothing was recorded")
        return 1
    print(f"recorded {added} new simulator identifier hashes ({total} in {HASHES.as_posix()})")
    return 0


def main(argv: list[str] | None = None, root: Path = ROOT) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--range", default="origin/main..HEAD")
    ap.add_argument("--push", action="store_true")
    ap.add_argument("--record-simulators", action="store_true")
    args = ap.parse_args(argv)
    if args.record_simulators:
        return record_command(root)
    findings = scan(root, args.range)
    for f in findings[:40]:
        print("FINDING:", f)
    if len(findings) > 40:
        print(f"… and {len(findings) - 40} more")
    count = git(root, "rev-list", "--count", args.range).stdout.strip() or "0"
    print(f"{'PASS' if not findings else 'FAIL'}: pre-push scan of {count} commits ({args.range}), {len(findings)} findings")
    if findings or not args.push:
        return 1 if findings else 0
    branch = git(root, "branch", "--show-current").stdout.strip()
    if branch != "main":
        print(f"not pushed: branch {branch or '(detached)'} is not main")
        return 1
    pushed = subprocess.run(["git", "push", "origin", "main"], cwd=root, check=False)
    return pushed.returncode


if __name__ == "__main__":
    sys.exit(main())
