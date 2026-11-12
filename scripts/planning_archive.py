#!/usr/bin/env python3
"""Planning archive: manifest, extracted sources and integrity check (ADR-0009).

    python3 scripts/planning_archive.py build    # extract embedded sources and the playbook; write ARCHIVE-MANIFEST.json
    python3 scripts/planning_archive.py verify   # prove every archived document is byte-identical to the baseline

The planning corpus that used to sit in the repository root was moved, unchanged, to docs/archive/planning/.
`build` additionally writes two kinds of derived, verbatim copies so the archive can be searched and linked file by
file:

  * docs/archive/planning/embedded/<name>   the 33 source documents embedded in the archived specification, each
                                            checked against the SHA-256 in its SOURCE-BEGIN marker;
  * docs/archive/planning/playbook/...      the playbook "A new iOS app with Claude and Spec Kit, little human
                                            interaction (2026-11-10)", the exact byte range of the archived agent
                                            contract from that heading to the end of the file.

`verify` compares every archived file with the SHA-256 recorded for its original path in
docs/migration/pre-fable-baseline.json, re-checks the derived copies and the rounds 3-12 hash manifest. Standard
library only.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ARCHIVE = Path("docs/archive/planning")
BASELINE = Path("docs/migration/pre-fable-baseline.json")
MANIFEST = ARCHIVE / "ARCHIVE-MANIFEST.json"
SPEC = ARCHIVE / "root/README-2026-11-10-full-specification.md"
CONTRACT = ARCHIVE / "root/CLAUDE-2026-11-11-agent-contract.md"
PLAYBOOK = ARCHIVE / "playbook/Playbook-new-iOS-app-with-Claude-and-Spec-Kit-2026-11-10.md"
PLAYBOOK_HEADING = b"## Playbook: a new iOS app with Claude and Spec Kit, little human interaction (2026-11-10)\n"
SOURCE = re.compile(rb"<!-- SOURCE-BEGIN: ([^\s]+) SHA256=([a-f0-9]{64}) -->\n(.*?)<!-- SOURCE-END: \1 -->", re.S)

# original path (as tracked at the baseline) -> archive path under ARCHIVE, how it got there, what it is
ENTRIES: list[tuple[str, str, str, str]] = [
    ("README.md", "root/README-2026-11-10-full-specification.md", "moved",
     "Former root README: canonical specification chapters 1-19 and the verbatim archive of 33 source documents"),
    ("CLAUDE.md", "root/CLAUDE-2026-11-11-agent-contract.md", "moved",
     "Former root agent contract (sections 0-13) with the verbatim ProjectM-iOS playbook (section 14)"),
    ("setup.md", "root/setup-2026-11-11.md", "copied",
     "Machine setup guide as it stood at the baseline; the root setup.md continues and is revised"),
    ("START-HERE.md", "root/START-HERE.md", "moved", "Index of rounds 3-12"),
    ("DESKTOP-ONE-SHOT.md", "root/DESKTOP-ONE-SHOT.md", "moved", "Controller prompt for rounds 3-12 (superseded)"),
    ("manifest.json", "root/manifest.json", "moved", "Hash manifest and roster metadata for rounds 3-12"),
    ("Round2.md", "rounds/round2.md", "moved",
     "Round 2: 34 shared features, 25 games, embedded assertion outlines and 500-candidate study "
     "(tracked as Round2.md; the document names itself round2.md)"),
] + [(f"round{n}.md", f"rounds/round{n}.md", "moved", f"Round {n}: 12 shared features and 25 games") for n in range(3, 13)]

RETAINED = [
    ("docs/brainstorm/Round-2-Refined-Premium-500x62-Scoring.csv", "500 candidates scored on 62 criteria"),
    ("docs/brainstorm/Round-2-Refined-Premium-Games-Study-500.md", "500-candidate study"),
    ("docs/brainstorm/Round-2-Refined-Top25-Selected.csv", "Round 2 selection (top 25)"),
    ("docs/brainstorm/Round-2-Top25-Complete-AssertionOutlines.md", "25 Round 2 assertion outlines"),
    ("docs/brainstorm/round3-to-round12-selection.csv", "Rounds 3-12 selection in score order"),
    ("docs/brainstorm/supplemental-26-provisional-candidates.csv", "26 supplemental provisional candidates"),
    ("docs/process/speckit-prompt-manifest.json", "Spec Kit prompts for features 001-185 (generated)"),
    ("docs/process/speckit-prompt-manifest.md", "Summary of the prompt manifest"),
]


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def embedded_sources(root: Path) -> list[tuple[str, str, bytes]]:
    return [(m.group(1).decode(), m.group(2).decode(), m.group(3)) for m in SOURCE.finditer((root / SPEC).read_bytes())]


def playbook_bytes(root: Path) -> bytes:
    data = (root / CONTRACT).read_bytes()
    start = data.find(PLAYBOOK_HEADING)
    if start < 0:
        raise SystemExit("ERROR: playbook heading not found in the archived agent contract")
    return data[start:]


def build(root: Path = ROOT) -> dict:
    base = json.loads((root / BASELINE).read_text(encoding="utf-8"))
    by_path = {f["path"]: f for f in base["tracked"]["files"] if "sha256" in f}
    entries = []
    for original, rel, method, role in ENTRIES:
        target = root / ARCHIVE / rel
        entries.append({"original_path": original, "archive_path": (ARCHIVE / rel).as_posix(), "method": method,
                        "role": role, "bytes": target.stat().st_size, "sha256": digest(target.read_bytes()),
                        "baseline_sha256": by_path[original]["sha256"]})
    for path, role in RETAINED:
        entries.append({"original_path": path, "archive_path": None, "method": "retained in place", "role": role,
                        "bytes": (root / path).stat().st_size, "sha256": digest((root / path).read_bytes()),
                        "baseline_sha256": by_path[path]["sha256"]})
    derived = []
    for name, want, data in embedded_sources(root):
        if name.startswith("/") or ".." in Path(name).parts:
            raise SystemExit("ERROR: unsafe embedded source name " + name)
        if digest(data) != want:
            raise SystemExit("ERROR: embedded source hash mismatch for " + name)
        out = root / ARCHIVE / "embedded" / name
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_bytes(data)
        derived.append({"path": (ARCHIVE / "embedded" / name).as_posix(), "derived_from": SPEC.as_posix(),
                        "kind": "embedded source", "embedded_name": name, "bytes": len(data), "sha256": want})
    pb = playbook_bytes(root)
    (root / PLAYBOOK).parent.mkdir(parents=True, exist_ok=True)
    (root / PLAYBOOK).write_bytes(pb)
    derived.append({"path": PLAYBOOK.as_posix(), "derived_from": CONTRACT.as_posix(),
                    "kind": "verbatim section (from the playbook heading to the end of the file)",
                    "bytes": len(pb), "sha256": digest(pb)})
    manifest = {"schema": 1,
                "note": "Every entry is byte-identical to the file tracked at the baseline commit "
                        f"{base['repository']['commit']}; derived copies are verbatim extractions.",
                "baseline": BASELINE.as_posix(), "entries": entries, "derived": derived}
    (root / MANIFEST).write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return manifest


def verify(root: Path = ROOT) -> list[str]:
    problems: list[str] = []
    if not (root / MANIFEST).is_file():
        return [f"{MANIFEST} missing (run planning_archive.py build)"]
    manifest = json.loads((root / MANIFEST).read_text(encoding="utf-8"))
    base = json.loads((root / BASELINE).read_text(encoding="utf-8"))
    by_path = {f["path"]: f for f in base["tracked"]["files"] if "sha256" in f}
    seen = set()
    for e in manifest["entries"]:
        original = e["original_path"]
        seen.add(original)
        current = root / (e["archive_path"] or original)
        if original not in by_path:
            problems.append(f"{original}: not in the baseline")
        elif not current.is_file():
            problems.append(f"{original}: archived copy missing at {current.relative_to(root)}")
        elif digest(current.read_bytes()) != by_path[original]["sha256"]:
            problems.append(f"{original}: archived copy differs from the baseline ({current.relative_to(root)})")
    for f in base["planning_documents"]:
        if f["path"] not in seen:
            problems.append(f"{f['path']}: baseline planning document has no archive entry")
    sources = embedded_sources(root)
    if len(sources) != 33:
        problems.append(f"expected 33 embedded sources, found {len(sources)}")
    for name, want, data in sources:
        out = root / ARCHIVE / "embedded" / name
        if digest(data) != want:
            problems.append(f"embedded source {name}: marker hash mismatch")
        if not out.is_file() or out.read_bytes() != data:
            problems.append(f"embedded source {name}: extracted copy missing or different")
    listed = {d["path"] for d in manifest["derived"]}
    # Finder metadata (.DS_Store) is ignored by Git and is not part of the archive.
    on_disk = {p.relative_to(root).as_posix() for p in (root / ARCHIVE / "embedded").rglob("*")
               if p.is_file() and p.name != ".DS_Store"}
    for extra in sorted(on_disk - listed):
        problems.append(f"unlisted file in the extracted sources: {extra}")
    if not (root / PLAYBOOK).is_file() or (root / PLAYBOOK).read_bytes() != playbook_bytes(root):
        problems.append("playbook extraction missing or different from the archived agent contract")
    rounds = json.loads((root / ARCHIVE / "root/manifest.json").read_text(encoding="utf-8"))["rounds"]
    for name, meta in rounds.items():
        path = root / ARCHIVE / "rounds" / name
        if not path.is_file() or digest(path.read_bytes()) != meta["sha256"]:
            problems.append(f"{name}: does not match the rounds 3-12 hash manifest")
    return problems


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("cmd", choices=["build", "verify"])
    args = ap.parse_args(argv)
    if args.cmd == "build":
        m = build()
        print(f"archive manifest: {len(m['entries'])} documents, {len(m['derived'])} derived copies")
    problems = verify()
    for p in problems:
        print("PROBLEM:", p)
    print(f"{'PASS' if not problems else 'FAIL'}: planning archive, {len(problems)} problems")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
