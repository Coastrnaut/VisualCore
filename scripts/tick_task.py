#!/usr/bin/env python3
"""Tick one verified Spec Kit task, then commit (and push only when the checkout is on `main`).

  python3 scripts/tick_task.py specs/004-resources-shaders T-F302 "evidence text" "commit subject"

Works for a task of every namespace of the numbering map (ADR-0009 D-11). Refuses, and changes nothing, when the
task list does not exist, when the task is missing, already ticked or listed twice, or when the evidence is empty
or spans several lines. Appends `— Verified YYYY-MM-DD: <evidence>` with the local date (Constitution VI), then runs
the document validator; when it fails, the task list is restored to its previous bytes and nothing is committed.
Otherwise it stages all changes and commits without trailers. On `main` it then runs `scripts/prepush_scan.py` and
pushes to `origin main` only when the scan is clean (owner rule: scan before every push; ADR-0009 D-13). When the
scan finds something or the push fails, the commit stays local and the tool fails with the command that pushes
later. On any other branch nothing is pushed. `--no-push` skips the push on `main` too.
"""
from __future__ import annotations

import argparse
import datetime as dt
import os
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(Path(__file__).resolve().parent))
import prepush_scan  # noqa: E402
import validate_docs  # noqa: E402

PUSH_LATER = "python3 scripts/prepush_scan.py --push"


def write_atomic(path: Path, data: bytes) -> None:
    """Replace `path` in one step: a reader sees the old bytes or the new ones, never a part."""
    fd, tmp = tempfile.mkstemp(prefix=".writing-", dir=str(path.parent))
    try:
        with os.fdopen(fd, "wb") as f:
            f.write(data)
            f.flush()
            os.fsync(f.fileno())
        os.chmod(tmp, 0o644)
        os.replace(tmp, path)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


def main(argv: list[str] | None = None, root: Path = ROOT) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("feature_dir")
    ap.add_argument("task_id")
    ap.add_argument("evidence")
    ap.add_argument("message")
    ap.add_argument("--no-push", action="store_true")
    args = ap.parse_args(argv)
    if not args.evidence.strip():
        raise SystemExit("evidence is required (Constitution VI)")
    if "\n" in args.evidence or "\r" in args.evidence:
        raise SystemExit("evidence must be one line: a line break would split the task line")
    tasks = root / args.feature_dir / "tasks.md"
    if not tasks.is_file():
        raise SystemExit(f"{args.feature_dir}/tasks.md does not exist")
    before = tasks.read_bytes()
    lines = before.decode("utf-8").splitlines()
    prefix = f"- [ ] {args.task_id} "
    hits = [i for i, line in enumerate(lines) if line.startswith(prefix)]
    if len(hits) != 1:
        raise SystemExit(f"{args.task_id}: expected exactly one unticked task, found {len(hits)}")
    i = hits[0]
    lines[i] = lines[i].replace("- [ ]", "- [X]", 1) + f" — Verified {dt.date.today().isoformat()}: {args.evidence}"
    write_atomic(tasks, ("\n".join(lines) + "\n").encode("utf-8"))
    problems = validate_docs.validate(root)
    if problems:
        write_atomic(tasks, before)
        raise SystemExit("validate_docs.py failed after ticking; the task list was restored and nothing was committed:\n"
                         + "\n".join(problems[:5]))
    subprocess.run(["git", "add", "-A"], cwd=root, check=True)
    subprocess.run(["git", "commit", "-q", "-m", args.message], cwd=root, check=True)
    branch = subprocess.run(["git", "branch", "--show-current"], cwd=root, capture_output=True, text=True).stdout.strip()
    if branch != "main":
        print(f"not pushed: branch {branch or '(detached)'} is not main (ADR-0009 D-13)")
    elif not args.no_push:
        if prepush_scan.main([], root) != 0:
            raise SystemExit(f"committed but NOT pushed: the pre-push scan found something; fix it, then run {PUSH_LATER}")
        if subprocess.run(["git", "push", "-q", "origin", "main"], cwd=root, check=False).returncode != 0:
            raise SystemExit(f"committed but NOT pushed: git push failed; run {PUSH_LATER} when the remote can be reached")
    print(subprocess.run(["git", "log", "--oneline", "-1"], cwd=root, capture_output=True, text=True).stdout.strip())
    return 0


if __name__ == "__main__":
    sys.exit(main())
