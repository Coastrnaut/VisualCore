#!/usr/bin/env python3
"""Tick one verified Spec Kit task, then commit (and push only when the checkout is on `main`).

  python3 scripts/tick_task.py specs/004-resources-shaders T-F302 "evidence text" "commit subject"

Refuses if the task is missing or already ticked, if `validate_docs.py` fails, or if the evidence is
empty. Appends `— Verified YYYY-MM-DD: <evidence>` (Constitution VI), stages all changes and commits
without trailers. It pushes only when the current branch is `main` (the pre-migration cadence); on any other
branch, such as `migration/unified-app-plan`, nothing is pushed (ADR-0009 D-13). `--no-push` skips the push on
`main` too.
"""
from __future__ import annotations

import argparse
import datetime as dt
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("feature_dir")
    ap.add_argument("task_id")
    ap.add_argument("evidence")
    ap.add_argument("message")
    ap.add_argument("--no-push", action="store_true")
    args = ap.parse_args()
    if not args.evidence.strip():
        raise SystemExit("evidence is required (Constitution VI)")
    tasks = ROOT / args.feature_dir / "tasks.md"
    lines = tasks.read_text(encoding="utf-8").splitlines()
    prefix = f"- [ ] {args.task_id} "
    hits = [i for i, line in enumerate(lines) if line.startswith(prefix)]
    if len(hits) != 1:
        raise SystemExit(f"{args.task_id}: expected exactly one unticked task, found {len(hits)}")
    i = hits[0]
    lines[i] = lines[i].replace("- [ ]", "- [X]", 1) + f" — Verified {dt.date.today().isoformat()}: {args.evidence}"
    tasks.write_text("\n".join(lines) + "\n", encoding="utf-8")
    if subprocess.run([sys.executable, str(ROOT / "scripts" / "validate_docs.py")], cwd=ROOT,
                      capture_output=True).returncode != 0:
        raise SystemExit("validate_docs.py failed after ticking; fix before committing")
    subprocess.run(["git", "add", "-A"], cwd=ROOT, check=True)
    subprocess.run(["git", "commit", "-q", "-m", args.message], cwd=ROOT, check=True)
    branch = subprocess.run(["git", "branch", "--show-current"], cwd=ROOT, capture_output=True, text=True).stdout.strip()
    if branch != "main":
        print(f"not pushed: branch {branch or '(detached)'} is not main (ADR-0009 D-13)")
    elif not args.no_push:
        subprocess.run(["git", "push", "-q", "origin", "main"], cwd=ROOT, check=True)
    print(subprocess.run(["git", "log", "--oneline", "-1"], cwd=ROOT, capture_output=True, text=True).stdout.strip())
    return 0


if __name__ == "__main__":
    sys.exit(main())
