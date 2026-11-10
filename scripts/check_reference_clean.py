#!/usr/bin/env python3
"""Fail if the read-only reference checkout External/projectm-ios has tracked changes (T-F002; FR-F002).

Checks the reference and every nested submodule (`git status --porcelain --ignore-submodules=untracked`,
untracked files ignored because builds legitimately write gitignored outputs). Also confirms the
superproject gitlink still equals the reference HEAD. Never resets or cleans anything.
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REF = ROOT / "External" / "projectm-ios"


def git(args: list[str], cwd: Path) -> tuple[int, str]:
    p = subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True, timeout=600, check=False)
    return p.returncode, p.stdout.strip()


def changes(repo: Path) -> list[str]:
    rc, out = git(["status", "--porcelain", "--untracked-files=no", "--ignore-submodules=untracked"], repo)
    if rc != 0:
        return [f"{repo}: git status failed"]
    return [line for line in out.splitlines() if line.strip()]


def check(ref: Path = REF, superproject: Path = ROOT) -> list[str]:
    problems = [f"reference: {c}" for c in changes(ref)]
    _, subs = git(["submodule", "--quiet", "foreach", "--recursive", "echo $displaypath"], ref)
    for rel in subs.splitlines():
        problems += [f"{rel}: {c}" for c in changes(ref / rel)]
    _, head = git(["rev-parse", "HEAD"], ref)
    rc, tree = git(["ls-tree", "HEAD", str(ref.relative_to(superproject))], superproject)
    if rc == 0 and tree and tree.split()[2] != head:
        problems.append(f"superproject gitlink {tree.split()[2]} != reference HEAD {head}")
    return problems


def main() -> int:
    problems = check()
    for p in problems:
        print("CHANGED:", p)
    print("PASS: reference checkout and nested submodules unmodified" if not problems else f"FAIL: {len(problems)} changes")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
