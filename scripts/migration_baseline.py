#!/usr/bin/env python3
"""Pre-migration baseline for the unified-app consolidation (ADR-0009).

    python3 scripts/migration_baseline.py capture   # writes docs/migration/pre-fable-baseline.{json,sha256}
    python3 scripts/migration_baseline.py verify    # re-checks the preserved ledger and source hashes

`capture` records the Git identity, submodule pins, every tracked file (bytes, SHA-256, Git blob), the ledger
summary and an inventory of ignored directories. It refuses to overwrite an existing baseline: the baseline is
written once, before anything moves. `verify` proves that the legacy ledger (`.autonomy/state.json` as captured,
`.autonomy/evidence/`, `.autonomy/checks/`) and the planning documents still exist with the captured content,
either at their original path or at the archive path recorded in docs/archive/planning/ARCHIVE-MANIFEST.json.

Standard library only. Records no device identifiers, signing data or secrets; ignored directories are listed by
name, entry count and size only.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT_JSON = ROOT / "docs" / "migration" / "pre-fable-baseline.json"
OUT_SUMS = ROOT / "docs" / "migration" / "pre-fable-baseline.sha256"
ARCHIVE_MANIFEST = ROOT / "docs" / "archive" / "planning" / "ARCHIVE-MANIFEST.json"
IGNORED_DIRS = [".autonomy/context", ".autonomy/logs", ".autonomy/xcresults", "Build", "External/projectm-ios"]
LEDGER_PREFIXES = (".autonomy/state.json", ".autonomy/evidence/", ".autonomy/checks/")


def git(*args: str, root: Path = ROOT) -> str:
    return subprocess.run(["git", *args], cwd=root, check=True, capture_output=True, text=True).stdout


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def is_planning(path: str) -> bool:
    """Planning and steering documents: root Markdown/JSON, brainstorm sources and the prompt manifest."""
    if "/" not in path:
        return path.endswith(".md") or path == "manifest.json"
    return path.startswith(("docs/brainstorm/", "docs/process/"))


def tracked_files(root: Path = ROOT) -> list[dict]:
    rows = []
    for line in git("ls-files", "-s", "-z", root=root).split("\0"):
        if not line:
            continue
        meta, path = line.split("\t", 1)
        mode, blob, _stage = meta.split()
        full = root / path
        if mode == "160000":            # submodule gitlink
            rows.append({"path": path, "submodule_commit": blob})
            continue
        rows.append({"path": path, "bytes": full.stat().st_size, "sha256": sha256(full), "git_blob": blob})
    return rows


def dir_inventory(root: Path, rel: str) -> dict:
    base = root / rel
    if not base.exists():
        return {"path": rel, "present": False}
    entries = sorted(p.name for p in base.iterdir())
    out = subprocess.run(["du", "-sk", str(base)], capture_output=True, text=True).stdout.split()
    return {"path": rel, "present": True, "top_level_entries": len(entries),
            "kilobytes": int(out[0]) if out else None}


def ledger_summary(root: Path) -> dict:
    state_path = root / ".autonomy" / "state.json"
    state = json.loads(state_path.read_text(encoding="utf-8"))
    stages = state["stages"]
    order = state["order"]
    counts: dict[str, int] = {}
    for v in stages.values():
        counts[v["status"]] = counts.get(v["status"], 0) + 1
    passed = [s for s in order if stages[s]["status"] == "pass"]
    nxt = next((s for s in order if stages[s]["status"] != "pass"), None)
    return {"path": ".autonomy/state.json", "sha256": sha256(state_path), "schema": state.get("schema"),
            "gates": len(order), "status_counts": counts, "passed": passed, "next": nxt,
            "updated": state.get("updated")}


def capture(args: argparse.Namespace) -> int:
    if OUT_JSON.exists() and not args.force:
        print(f"ERROR: {OUT_JSON.relative_to(ROOT)} exists; the baseline is captured once (use --force only to redo "
              "an aborted capture before any file has moved)")
        return 1
    status = git("status", "--porcelain=v1").splitlines()
    files = tracked_files()
    subs = []
    for line in git("submodule", "status", "--recursive").splitlines():
        flag, rest = line[0], line[1:].split()
        subs.append({"path": rest[1], "commit": rest[0],
                     "state": {" ": "checked-out", "-": "not-initialized", "+": "differs-from-index", "U": "conflict"}[flag]})
    try:
        ahead_behind = git("rev-list", "--left-right", "--count", "origin/main...HEAD").split()
    except subprocess.CalledProcessError:
        ahead_behind = None
    regular = [f for f in files if "sha256" in f]
    ledger_files = [f for f in regular if f["path"].startswith(LEDGER_PREFIXES)]
    agg = hashlib.sha256()
    for f in sorted(ledger_files, key=lambda r: r["path"]):
        agg.update(f"{f['sha256']}  {f['path']}\n".encode())
    manifest = {
        "schema": 1,
        "purpose": "State of the VisualCore checkout before the unified-app documentation consolidation (ADR-0009).",
        "captured_at": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
        "repository": {
            "branch_at_capture": args.source_branch,
            "commit": git("rev-parse", "HEAD").strip(),
            "tree": git("rev-parse", "HEAD^{tree}").strip(),
            "commit_date": git("log", "-1", "--format=%cI").strip(),
            "commit_subject": git("log", "-1", "--format=%s").strip(),
            "remotes": dict(l.split()[:2] for l in git("remote", "-v").splitlines() if l.endswith("(fetch)")),
            "origin_main_behind_ahead": ahead_behind,
            "working_tree_changes": status,
            "local_branches": git("branch", "--format=%(refname:short)").split(),
        },
        "submodules": {"count": len(subs),
                       "checked_out": [s for s in subs if s["state"] != "not-initialized"],
                       "not_initialized_count": sum(s["state"] == "not-initialized" for s in subs)},
        "tracked": {"count": len(files), "regular_files": len(regular),
                    "bytes": sum(f["bytes"] for f in regular), "files": files},
        "planning_documents": [f for f in regular if is_planning(f["path"])],
        "ledger": {**ledger_summary(ROOT), "evidence_files": sum(f["path"].startswith(".autonomy/evidence/") for f in regular),
                   "check_files": sum(f["path"].startswith(".autonomy/checks/") for f in regular),
                   "aggregate_sha256": agg.hexdigest(),
                   "aggregate_note": "SHA-256 over 'sha256  path\\n' lines of state.json, evidence/ and checks/, sorted by path"},
        "ignored_inventory": [dir_inventory(ROOT, d) for d in IGNORED_DIRS],
        "notes": args.note or [],
    }
    OUT_JSON.parent.mkdir(parents=True, exist_ok=True)
    OUT_JSON.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    OUT_SUMS.write_text("".join(f"{f['sha256']}  {f['path']}\n" for f in regular), encoding="utf-8")
    print(f"captured {len(regular)} files ({manifest['tracked']['bytes']} bytes), {len(subs)} submodule entries, "
          f"ledger {manifest['ledger']['status_counts']} next={manifest['ledger']['next']}")
    return 0


def load_archive_map() -> dict[str, str]:
    """original path -> archive path, from the archive manifest (empty before anything is archived)."""
    if not ARCHIVE_MANIFEST.is_file():
        return {}
    data = json.loads(ARCHIVE_MANIFEST.read_text(encoding="utf-8"))
    return {e["original_path"]: e["archive_path"] for e in data.get("entries", []) if e.get("archive_path")}


def verify(root: Path = ROOT, baseline: Path = OUT_JSON, archive_map: dict[str, str] | None = None) -> list[str]:
    """Problems found; empty means every preserved file still has its captured content.

    Checked: every planning document (at its original or archived path), and the legacy ledger evidence and check
    files captured in the baseline. `.autonomy/state.json` may gain passes later, so only the gates passed at
    capture time are required to still be `pass`.
    """
    problems: list[str] = []
    if not baseline.is_file():
        return [f"baseline missing: {baseline}"]
    base = json.loads(baseline.read_text(encoding="utf-8"))
    amap = load_archive_map() if archive_map is None else archive_map
    for f in base["planning_documents"]:
        current = root / amap.get(f["path"], f["path"])
        if not current.is_file():
            problems.append(f"planning document missing: {f['path']} (looked at {current.relative_to(root)})")
        elif sha256(current) != f["sha256"]:
            problems.append(f"planning document changed: {f['path']} at {current.relative_to(root)}")
    for f in base["tracked"]["files"]:
        p = f["path"]
        if "sha256" in f and p.startswith((".autonomy/evidence/", ".autonomy/checks/")):
            current = root / p
            if not current.is_file():
                problems.append(f"ledger file missing: {p}")
            elif sha256(current) != f["sha256"]:
                problems.append(f"ledger file changed: {p}")
    state_path = root / ".autonomy" / "state.json"
    if not state_path.is_file():
        problems.append("legacy ledger .autonomy/state.json missing")
    else:
        stages = json.loads(state_path.read_text(encoding="utf-8")).get("stages", {})
        for gate in base["ledger"]["passed"]:
            if stages.get(gate, {}).get("status") != "pass":
                problems.append(f"legacy gate {gate} was pass at baseline and is no longer pass")
        if len(stages) != base["ledger"]["gates"]:
            problems.append(f"legacy ledger has {len(stages)} gates, baseline had {base['ledger']['gates']}")
    return problems


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    c = sub.add_parser("capture")
    c.add_argument("--source-branch", default="main", help="branch the baseline commit was taken from")
    c.add_argument("--note", action="append", help="free-text note recorded in the manifest (repeatable)")
    c.add_argument("--force", action="store_true")
    sub.add_parser("verify")
    args = ap.parse_args(argv)
    if args.cmd == "capture":
        return capture(args)
    problems = verify()
    for p in problems:
        print("PROBLEM:", p)
    print(f"{'PASS' if not problems else 'FAIL'}: baseline verification, {len(problems)} problems")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
