#!/usr/bin/env python3
"""Scan the commits that are not on origin/main yet, before they are pushed. Standard library only.

    python3 scripts/prepush_scan.py                # scan origin/main..HEAD; exit 1 on any finding
    python3 scripts/prepush_scan.py --range A..B   # another range
    python3 scripts/prepush_scan.py --push         # scan, then `git push origin main` (only on branch main, never forced)

Owner rule: before any push, scan for device identifiers, ECIDs, serial numbers, team ids and secrets. The scan
reads every ADDED line of the outgoing commits (a rename without changes adds nothing) and looks for:

  hardware identifier   eight hexadecimal digits, a hyphen, sixteen hexadecimal digits
  device or other UUID  the 8-4-4-4-12 form; allowed are synthetic ids that start with 00000000-0000-4000-8000- and
                        the identifiers of this Mac's own simulators (they appear in recorded test commands and
                        identify nothing outside this machine)
  ECID, serial number   only when a value follows the word
  team id               a DEVELOPMENT_TEAM assignment or "team id" followed by ten characters
  e-mail address, absolute home path with a user name
  private key, access token

It also refuses when a path that must never be tracked is tracked: .autonomy/private, logs, result bundles, the
local signing file, provisioning profiles, key stores.

Lines of scripts/test_scripts.py are not scanned: they hold deliberately fake values that test this scanner.
A finding is not always a secret. Read it, then either remove it or, when it is a synthetic value that belongs in
the repository, change it to the allowed synthetic form.
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PATTERNS = [
    ("hardware identifier", re.compile(r"\b[0-9A-Fa-f]{8}-[0-9A-Fa-f]{16}\b")),
    ("device or simulator UUID", re.compile(r"\b(?!00000000-0000-4000-8000-)[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\b")),
    ("ECID", re.compile(r"(?i)\becid\b[\"']?\s*[:=]\s*[\"']?(?:0x)?[0-9a-f]{6,}")),
    ("serial number", re.compile(r"(?i)\bserial(?:\s*number|number)?\b[\"']?\s*[:=]\s*[\"']?[A-Z0-9]{8,14}\b")),
    ("development team id", re.compile(r"DEVELOPMENT_TEAM\s*[=:]\s*[A-Z0-9]{10}\b|(?i:\bteam\s*id\b[\"']?\s*[:=]\s*[\"']?)[A-Z0-9]{10}\b")),
    ("e-mail address", re.compile(r"\b[\w.+-]+@[\w-]+\.[A-Za-z]{2,}\b")),
    ("absolute home path", re.compile(r"/Users/(?!Shared/|<)[A-Za-z][\w.-]*/")),
    ("private key", re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----")),
    ("access token", re.compile(r"\b(ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|sk-ant-[A-Za-z0-9-]{10,}|AKIA[0-9A-Z]{16})\b")),
]
ALLOWED_ADDRESSES = {"git@github.com"}
FORBIDDEN_PATHS = re.compile(r"^\.autonomy/(private|logs|xcresults|reports)/|^Configs/Signing\.local\.xcconfig$|"
                             r"\.(mobileprovision|p12|p8|cer|xcresult)(/|$)")
UNSCANNED = {"scripts/test_scripts.py"}


def scan_line(line: str, allowed: frozenset[str] = frozenset()) -> list[str]:
    """Labels of everything suspicious in one added line. `allowed` holds upper-case UUIDs that are not findings."""
    found = []
    for label, pattern in PATTERNS:
        for m in pattern.finditer(line):
            if label == "e-mail address" and m.group(0) in ALLOWED_ADDRESSES:
                continue
            if label == "device or simulator UUID" and m.group(0).upper() in allowed:
                continue
            found.append(label)
            break
    return found


def scan_diff(diff: str, allowed: frozenset[str] = frozenset()) -> list[str]:
    """Findings in a unified diff: 'file: label: text' for every suspicious added line."""
    findings, current = [], None
    for line in diff.split("\n"):
        if line.startswith("+++ "):
            current = line[6:] if line.startswith("+++ b/") else None
        elif line.startswith("+") and not line.startswith("+++") and current and current not in UNSCANNED:
            for label in scan_line(line[1:], allowed):
                findings.append(f"{current}: {label}: {line[1:].strip()[:100]}")
    return findings


def simulator_identifiers() -> frozenset[str]:
    """Identifiers of the simulators installed on this Mac; empty where simctl is unavailable."""
    try:
        out = subprocess.run(["xcrun", "simctl", "list", "devices", "-j"], capture_output=True, text=True, timeout=60, check=False).stdout
    except (OSError, subprocess.TimeoutExpired):
        return frozenset()
    return frozenset(u.upper() for u in re.findall(r'"udid"\s*:\s*"([0-9A-Fa-f-]{36})"', out))


def forbidden(paths: list[str]) -> list[str]:
    return [f"{p}: this path must never be tracked" for p in paths if FORBIDDEN_PATHS.search(p)]


def git(root: Path, *argv: str) -> subprocess.CompletedProcess:
    return subprocess.run(["git", *argv], cwd=root, capture_output=True, text=True, errors="replace", check=False)


def scan(root: Path = ROOT, commits: str = "origin/main..HEAD") -> list[str]:
    diff = git(root, "diff", "--unified=0", "--no-color", "--find-renames", commits)
    if diff.returncode != 0:
        return [f"cannot read {commits}: {diff.stderr.strip()[:200]}"]
    return scan_diff(diff.stdout, simulator_identifiers()) + forbidden(git(root, "ls-files").stdout.splitlines())


def main(argv: list[str] | None = None, root: Path = ROOT) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--range", default="origin/main..HEAD")
    ap.add_argument("--push", action="store_true")
    args = ap.parse_args(argv)
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
