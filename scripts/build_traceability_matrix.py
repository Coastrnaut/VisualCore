#!/usr/bin/env python3
"""Build the source-to-canonical traceability matrix. Deterministic, standard library only; never calls a model.

    python3 scripts/build_traceability_matrix.py            # write docs/migration/source-to-canonical-matrix.csv
    python3 scripts/build_traceability_matrix.py --check    # exit 1 if the file is stale or a source map is wrong

Every row maps one item of the planning corpus (docs/archive/planning and the documents retained in place) to its
canonical home: a section of Auto-Creator.md (canonical_id `AC-<section>`), or the tracked path that holds the
record of completed work, or `archive` when the item is history only. Row sources:

  document            one row per archived, retained or extracted planning document (ARCHIVE-MANIFEST.json)
  heading             one row per heading of the rule-carrying documents, from the reviewed maps in
                      docs/migration/heading-maps/*.json (each heading is checked against the source file)
  experience          one row per experience (300), from docs/catalog/experience-catalog.json
  experience-section  one row per chapter section of every game
  assertion-outline   one row per embedded assertion outline
  level-manifest      one row per 100-level manifest
  scenario-table      one row per table of acceptance scenarios and of fault-injection cases
  feature             one row per planned feature (3,089), from docs/catalog/feature-index.json, with its prompt count
  constitution-prompt one row per archived per-round constitution prompt

Statuses: implemented-and-verified, implemented-but-unverified, planned, superseded, blocked, historical.
"implemented-and-verified" always means host and simulator evidence sealed by a ledger gate; no row claims
device verification.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import io
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = Path("docs/migration/source-to-canonical-matrix.csv")
MAPS = Path("docs/migration/heading-maps")
MANIFEST = Path("docs/archive/planning/ARCHIVE-MANIFEST.json")
CATALOG = Path("docs/catalog/experience-catalog.json")
FEATURES = Path("docs/catalog/feature-index.json")
LEDGER = Path(".autonomy/migration/ledger.json")
DOC = Path("Auto-Creator.md")
COLUMNS = ["row", "source_kind", "source_file", "source_locator", "source_id", "source_sha256", "canonical_target",
           "canonical_id", "status", "note"]
STATUSES = ("implemented-and-verified", "implemented-but-unverified", "planned", "superseded", "blocked", "historical")
LIBRARY = {"original": "AC-7", "round-02": "AC-8", "round-03": "AC-9", "round-04": "AC-9"}
PLAYBOOK_HEADING = "## Playbook: a new iOS app with Claude and Spec Kit, little human interaction (2026-11-10)"
README_RANGE = (1, 1557)

# Role of each planning document as a whole: (canonical id or path, status, note).
DOCUMENT_ROLES = {
    "README-2026-11-10-full-specification.md": ("AC-26", "superseded", "Former steering specification; replaced by Auto-Creator.md (ADR-0009 D-10). Its chapters are mapped heading by heading and its 33 embedded sources separately."),
    "CLAUDE-2026-11-11-agent-contract.md": ("CLAUDE.md", "superseded", "Former agent contract; replaced by the bootstrap CLAUDE.md and Auto-Creator.md. Mapped heading by heading."),
    "setup-2026-11-11.md": ("setup.md", "superseded", "Copy of the setup guide before its revision; the dated checkpoint and resume prompt are history."),
    "START-HERE.md": ("AC-2", "superseded", "Index of the round documents; replaced by Auto-Creator.md section 2 and the catalog."),
    "DESKTOP-ONE-SHOT.md": ("AC-28", "superseded", "Controller prompt for rounds 3-12; replaced by the continuation prompt."),
    "manifest.json": ("docs/archive/planning/ARCHIVE-MANIFEST.json", "historical", "Hash manifest of rounds 3-12; the archive manifest now holds every hash."),
    "round2.md": ("AC-8", "planned", "Round 2: 34 shared features, 25 games; packaging, price and device sequencing superseded (C-02, C-03, C-05)."),
}
RETAINED_ROLES = {
    "docs/brainstorm/": ("AC-5", "historical", "Scoring study behind the catalog order; the order itself is binding (section 5.2)."),
    "docs/process/": ("AC-21", "planned", "Prompts of features 001-185; 036-185 are still to be run with the canonical override."),
}
SECTION_RULES = [  # (pattern in a game chapter's section title, canonical id, note)
    (r"hardware", "AC-23", "Device work happens only after ImplementationLock-100; per-round campaigns are superseded (C-03)."),
    (r"file inventory|source file checklist|module boundaries", "AC-16", "Layout adapted to the experience module; no app target (C-05)."),
    (r"spec kit|implementation backlog", "AC-21", "Prompts are used verbatim with the canonical override."),
    (r"shipping decision|commercial", "AC-15.4", "Originality rules stand; separate shipping is superseded (C-01)."),
    (r"acceptance|fault-injection|counterexample|risk-directed", "AC-22", "Becomes automated scenarios of the experience."),
    (r"level catalog|content manifest|content-production|content production|seed-by-seed", "AC-6", "Content completeness of the experience (section 6.2)."),
    (r"persistence", "AC-15.1", "Storage through the experience context."),
    (r"accessib", "AC-15.3", "Accessibility and comfort rules."),
    (r"shared-feature dependencies", "AC-13", "Shared features and reuse."),
    (r"visual identity|renderer architecture|visual-quality", "AC-12", "Code-only visuals on the existing renderer."),
]


def sha_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load(root: Path, rel: Path):
    return json.loads((root / rel).read_text(encoding="utf-8"))


def heading_lines(lines: list[str]) -> dict[int, str]:
    """1-based line number -> stripped heading text, for headings of level 1-4 outside code fences."""
    out, fence = {}, None
    for n, line in enumerate(lines, 1):
        m = re.match(r"^\s{0,3}(```+|~~~+)", line)
        if m:
            mark = m.group(1)[0] * 3
            fence = None if fence == mark else (fence or mark)
            continue
        if fence is None and re.match(r"^#{1,4} ", line):
            out[n] = line.strip()
    return out


def canonical(target: str) -> tuple[str, str]:
    """(canonical_target, canonical_id) from a map target: AC-<n>[.<m>], a repository path, or 'archive'."""
    if re.fullmatch(r"AC-\d+(\.\d+)?", target):
        return f"Auto-Creator.md §{target[3:]}", target
    if target == "archive":
        return "docs/archive/planning (history only)", "archive"
    return target, ""


def skip_spans(catalog: dict, index: dict, source: str) -> list[tuple[int, int]]:
    spans = []
    for e in catalog["experiences"]:
        if e["source"]["file"] == source:
            spans.append((e["source"]["line_start"], e["source"]["line_end"]))
        if e.get("assertion_outline", {}).get("file") == source:
            spans.append((e["assertion_outline"]["line_start"], e["assertion_outline"]["line_end"]))
    for f in index["features"]:
        if f.get("source") and f["source"]["file"] == source:
            spans.append((f["source"]["line_start"], f["source"]["line_end"]))
    return spans


def expected_headings(root: Path, source: str, catalog: dict, index: dict) -> dict[int, str]:
    lines = (root / source).read_text(encoding="utf-8").split("\n")
    found = heading_lines(lines)
    name = Path(source).name
    if name == "README-2026-11-10-full-specification.md":
        return {n: h for n, h in found.items() if README_RANGE[0] <= n <= README_RANGE[1]}
    if re.fullmatch(r"round\d+\.md", name):
        spans = skip_spans(catalog, index, source)
        return {n: h for n, h in found.items() if not any(a <= n <= b for a, b in spans)}
    if name == "ProjectM-iOS-CLAUDE.md":
        stop = next((n for n, h in found.items() if h == PLAYBOOK_HEADING), None)
        return {n: h for n, h in found.items() if stop is None or n < stop}
    return found


def heading_rows(root: Path, catalog: dict, index: dict, hashes: dict[str, str]) -> tuple[list[dict], list[str]]:
    rows, problems = [], []
    seen_sources = set()
    for path in sorted((root / MAPS).glob("*.json")):
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as error:
            problems.append(f"{path.name}: not valid JSON ({error})")
            continue
        source = data.get("source", "")
        if not (root / source).is_file():
            problems.append(f"{path.name}: source {source!r} does not exist")
            continue
        if source in seen_sources:
            problems.append(f"{path.name}: second map for {source}")
        seen_sources.add(source)
        lines = (root / source).read_text(encoding="utf-8").split("\n")
        expected = expected_headings(root, source, catalog, index)
        mapped = set()
        digest = hashes.get(source) or sha_file(root / source)
        for r in data.get("rows", []):
            line, heading = r.get("line"), r.get("heading", "")
            whole = heading == "(whole document)"
            if not whole:
                if not isinstance(line, int) or not 1 <= line <= len(lines) or lines[line - 1].strip() != heading:
                    problems.append(f"{path.name}: line {line} is not the heading {heading[:60]!r}")
                    continue
                mapped.add(line)
            if r.get("status") not in STATUSES:
                problems.append(f"{path.name}: line {line}: unknown status {r.get('status')!r}")
                continue
            target, cid = canonical(str(r.get("target", "")))
            if not cid and not (root / target).exists():
                problems.append(f"{path.name}: line {line}: target {target!r} does not exist")
                continue
            rows.append({"source_kind": "heading", "source_file": source, "source_locator": f"line {line}",
                         "source_id": heading, "source_sha256": digest, "canonical_target": target, "canonical_id": cid,
                         "status": r["status"], "note": str(r.get("note", "")).strip()})
        missing = sorted(set(expected) - mapped)
        problems += [f"{path.name}: heading at line {n} is not mapped: {expected[n][:70]}" for n in missing[:10]]
        if len(missing) > 10:
            problems.append(f"{path.name}: {len(missing) - 10} further headings are not mapped")
    return rows, problems


def document_rows(root: Path, manifest: dict) -> tuple[list[dict], dict[str, str]]:
    rows, hashes = [], {}
    for d in manifest["entries"]:
        path = d.get("archive_path") or d["original_path"]
        hashes[path] = d["sha256"]
        name = Path(path).name
        role = DOCUMENT_ROLES.get(name)
        if not role:
            m = re.fullmatch(r"round(\d+)\.md", name)
            if m:
                n = int(m.group(1))
                role = ("AC-9" if n in (3, 4) else "AC-10", "planned",
                        f"Round {n}: 12 shared features, 25 games; packaging, price and device sequencing superseded (C-02, C-03, C-05).")
            else:
                role = next((v for k, v in RETAINED_ROLES.items() if path.startswith(k)), ("archive", "historical", "Planning document."))
        target, cid = canonical(role[0])
        rows.append({"source_kind": "document", "source_file": path, "source_locator": "whole file",
                     "source_id": d["original_path"], "source_sha256": d["sha256"], "canonical_target": target,
                     "canonical_id": cid, "status": role[1], "note": role[2]})
    for d in manifest.get("derived", []):
        path = d["path"]
        hashes[path] = d["sha256"]
        app = re.search(r"embedded/apps/(\d\d)-", path)
        if app:
            role = ("AC-7", "planned", f"Manual of original app A{app.group(1)}; traced by its experience row and its seven phase rows.")
        elif "playbook/" in path:
            role = ("AC-19", "planned", "ProjectM-iOS playbook, verbatim; its still-applicable lessons are rules of sections 19, 22, 23 and 24. Its approvals and results are history of another repository.")
        else:
            role = ("archive", "historical", "Embedded source of the former README; mapped heading by heading where it carries rules.")
        target, cid = canonical(role[0])
        rows.append({"source_kind": "document", "source_file": path, "source_locator": "whole file",
                     "source_id": d.get("embedded_name") or d["kind"], "source_sha256": d["sha256"],
                     "canonical_target": target, "canonical_id": cid, "status": role[1], "note": role[2]})
    return rows, hashes


def experience_rows(catalog: dict) -> list[dict]:
    rows = []
    for e in catalog["experiences"]:
        cid = LIBRARY.get(e["collection"], "AC-10")
        src = e["source"]
        impl = e["implementation"]
        if e["collection"] == "original" and impl["legacy_gates_passed"] and not impl["legacy_gates_pending"]:
            status = "implemented-and-verified"
            note = (f"Standalone app, all seven phases sealed with host and simulator evidence ({impl['legacy_gates_passed'][0]} … "
                    f"{impl['legacy_gates_passed'][-1]}). Integration in the unified app is pending (X-{e['code']}).")
        elif e["collection"] == "original" and impl["legacy_gates_passed"]:
            status = "planned"
            note = f"{len(impl['legacy_gates_passed'])} of 7 phases sealed; the rest and the integration gate X-{e['code']} are pending."
        else:
            status = "planned"
            note = f"Tier {e['tier']}; integration gate X-{e['code']}." if e["release"] == "launch" else "Backlog; added in score order after the first release."
        if e.get("superseded_source_terms"):
            terms = e["superseded_source_terms"]
            note += f" Superseded source terms: {terms.get('packaging')}, {terms.get('price')} (C-01, C-02)."
        base = {"source_file": src["file"], "canonical_target": f"Auto-Creator.md §{cid[3:]}", "canonical_id": f"{cid}:{e['id']}"}
        rows.append({**base, "source_kind": "experience", "source_locator": f"lines {src['line_start']}-{src['line_end']}",
                     "source_id": f"{e['code']} {e['name']}", "source_sha256": src["sha256"], "status": status, "note": note})
        for s in e.get("sections", []):
            target, why = cid, "Design of the experience; carried by its card and its features."
            for pattern, section, text in SECTION_RULES:
                if re.search(pattern, s["title"], re.I):
                    target, why = section, text
                    break
            rows.append({"source_kind": "experience-section", "source_file": src["file"],
                         "source_locator": f"lines {s['line_start']}-{s['line_end']}",
                         "source_id": f"{e['code']} §{s['number']} {s['title']}", "source_sha256": src["sha256"],
                         "canonical_target": f"Auto-Creator.md §{target[3:]}", "canonical_id": f"{target}:{e['id']}",
                         "status": "planned", "note": why})
        if e.get("assertion_outline"):
            a = e["assertion_outline"]
            rows.append({"source_kind": "assertion-outline", "source_file": a["file"],
                         "source_locator": f"lines {a['line_start']}-{a['line_end']}", "source_id": f"{e['code']} assertion outline",
                         "source_sha256": a["sha256"], "canonical_target": "Auto-Creator.md §22", "canonical_id": f"AC-22:{e['id']}",
                         "status": "planned", "note": "Requirement of the game's acceptance scenarios (section 21.4)."})
        if e.get("level_manifest"):
            lm = e["level_manifest"]
            rows.append({"source_kind": "level-manifest", "source_file": src["file"],
                         "source_locator": f"lines {lm['line_start']}-{lm['line_end']}", "source_id": f"{e['code']} level manifest ({lm['rows']} levels)",
                         "source_sha256": src["sha256"], "canonical_target": "Auto-Creator.md §6", "canonical_id": f"AC-6:{e['id']}",
                         "status": "planned", "note": "The 100 levels are a content requirement (section 6.2)."})
        for key, label in (("acceptance_scenarios", "acceptance scenarios"), ("fault_injection", "fault-injection cases")):
            if e.get(key):
                t = e[key]
                rows.append({"source_kind": "scenario-table", "source_file": src["file"],
                             "source_locator": f"lines {t['line_start']}-{t['line_end']}", "source_id": f"{e['code']} {t['rows']} {label}",
                             "source_sha256": src["sha256"], "canonical_target": "Auto-Creator.md §22", "canonical_id": f"AC-22:{e['id']}",
                             "status": "planned", "note": "Each row becomes an automated scenario of the experience (section 22.1)."})
    return rows


def feature_rows(root: Path, catalog: dict, index: dict, ledger: dict) -> list[dict]:
    rows = []
    gates = {g["id"]: g for g in ledger["gates"]}
    collection = {e["code"]: e["collection"] for e in catalog["experiences"]}
    later_superseded = {1: "UA-F00", 9: "UA-F06", 10: "UA-F10", 11: "UA-F09, UA-F13", 12: "UA-F11, UA-F12"}
    for f in index["features"]:
        src = f.get("source") or {}
        prompts = len(f.get("prompts", {}))
        locator = f"lines {src['line_start']}-{src['line_end']}" if src else "prompt manifest"
        source_file = src.get("file") or "docs/process/speckit-prompt-manifest.json"
        if f["kind"] in ("foundation-phase", "original-app-phase"):
            sealed = f["legacy_gate_status"] == "pass"
            directory = f.get("spec_dir")
            if sealed and directory and (root / directory).is_dir():
                target, cid, status = directory, "", "implemented-and-verified"
                note = f"Legacy gate {f['id']} sealed; evidence .autonomy/evidence/{f['id']}.json (host and simulator)."
            else:
                target, cid, status = "Auto-Creator.md §7", f"AC-7:{f['id']}", "planned"
                note = f"Legacy gate {f['id']} pending; feature {f['spec_number']}; prompts in the prompt manifest, used with the canonical override."
        elif f["kind"] == "shared-round-feature":
            number = int(f["id"].rsplit("F", 1)[1])
            gate = gates.get(f["id"])
            by = ", ".join(gate["superseded_by"]) if gate and gate["status"] == "superseded" else (later_superseded.get(number) if not gate and f["round"] > 2 else None)
            if by:
                target, cid, status = "Auto-Creator.md §13", f"AC-13:{f['id']}", "superseded"
                note = f"Delivered by {by}; its unique requirements are imported by the absorbing feature (no separate gate)."
            else:
                target, cid, status = "Auto-Creator.md §13", f"AC-13:{f['id']}", "planned"
                note = f"Gate {f['id']}; spec directory {f['spec_dir_proposed']}." if gate else f"Backlog round {f['round']}; gates are added with add-round."
        else:
            cid_base = LIBRARY.get(collection[f["experience"]], "AC-10")
            target, cid, status = f"Auto-Creator.md §{cid_base[3:]}", f"{cid_base}:{f['id']}", "planned"
            note = f"Gate {f['id']}; spec directory {f['spec_dir_proposed']}." if f["id"] in gates else f"Backlog round {f['round']}; spec directory {f['spec_dir_proposed']}."
        if prompts:
            note += f" {prompts} archived stage prompts."
        rows.append({"source_kind": "feature", "source_file": source_file, "source_locator": locator,
                     "source_id": f"{f.get('source_id') or f['id']} {f['title']}", "source_sha256": src.get("sha256", ""),
                     "canonical_target": target, "canonical_id": cid, "status": status, "note": note})
    for info in index["rounds"]:
        cp = info.get("constitution_prompt")
        if cp:
            rows.append({"source_kind": "constitution-prompt", "source_file": info["file"], "source_locator": f"line {cp['line']}",
                         "source_id": f"Round {info['round']} /speckit-constitution prompt", "source_sha256": cp["sha256"],
                         "canonical_target": "Auto-Creator.md §19", "canonical_id": "AC-19.2", "status": "superseded",
                         "note": "Replaced by the single amendment to constitution 2.0.0 (gate CONSTITUTION-2)."})
    return rows


def sections_of(doc: str) -> set[str]:
    """AC ids that exist as numbered headings of Auto-Creator.md (## N. and ### N.M)."""
    return {"AC-" + m.group(1) for m in re.finditer(r"^#{2,3} (\d+(?:\.\d+)?)\.? ", doc, re.M)}


def build(root: Path = ROOT) -> tuple[str, list[str]]:
    manifest, catalog, index, ledger = load(root, MANIFEST), load(root, CATALOG), load(root, FEATURES), load(root, LEDGER)
    rows, hashes = document_rows(root, manifest)
    mapped, problems = heading_rows(root, catalog, index, hashes)
    rows += mapped
    rows += experience_rows(catalog)
    rows += feature_rows(root, catalog, index, ledger)
    known = sections_of((root / DOC).read_text(encoding="utf-8")) if (root / DOC).is_file() else set()
    for r in rows:
        if r["status"] not in STATUSES:
            problems.append(f"{r['source_id'][:50]}: unknown status {r['status']}")
        base = r["canonical_id"].split(":")[0]
        if base.startswith("AC-") and known and base not in known:
            problems.append(f"{r['source_file']} {r['source_locator']}: {base} is not a section of {DOC}")
    out = io.StringIO()
    writer = csv.DictWriter(out, fieldnames=COLUMNS, lineterminator="\n")
    writer.writeheader()
    for n, r in enumerate(rows, 1):
        writer.writerow({"row": n, **r})
    return out.getvalue(), sorted(set(problems))


def coverage(root: Path = ROOT) -> list[str]:
    """Problems of coverage: documents without a row, rule-carrying documents without a heading map."""
    problems = []
    manifest = load(root, MANIFEST)
    path = root / OUT
    if not path.is_file():
        return [f"{OUT} missing"]
    with path.open(encoding="utf-8", newline="") as f:
        rows = list(csv.DictReader(f))
    by_kind: dict[str, set[str]] = {}
    for r in rows:
        by_kind.setdefault(r["source_kind"], set()).add(r["source_file"])
    for d in manifest["entries"]:
        doc = d.get("archive_path") or d["original_path"]
        if doc not in by_kind.get("document", set()):
            problems.append(f"no document row for {doc}")
        needs_map = doc.endswith(".md") and doc.startswith("docs/archive/planning/")
        if needs_map and doc not in by_kind.get("heading", set()):
            problems.append(f"no heading map for {doc}")
    for d in manifest.get("derived", []):
        if "/embedded/sources/" in d["path"] and d["path"].endswith(".md") and d["path"] not in by_kind.get("heading", set()):
            problems.append(f"no heading map for {d['path']}")
    catalog, index = load(root, CATALOG), load(root, FEATURES)
    ids = {r["source_id"].split(" ")[0] for r in rows if r["source_kind"] == "experience"}
    problems += [f"no experience row for {e['code']}" for e in catalog["experiences"] if e["code"] not in ids]
    feature_ids = {r["source_id"].split(" ")[0] for r in rows if r["source_kind"] == "feature"}
    missing = [f["id"] for f in index["features"] if (f.get("source_id") or f["id"]) not in feature_ids]
    problems += [f"no feature row for {m}" for m in missing[:10]]
    return problems


def main(argv: list[str] | None = None, root: Path = ROOT) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args(argv)
    text, problems = build(root)
    path = root / OUT
    if args.check:
        if not path.is_file() or path.read_text(encoding="utf-8") != text:
            problems.append(f"{OUT} is stale: run python3 scripts/build_traceability_matrix.py")
        else:
            problems += coverage(root)
    else:
        path.write_text(text, encoding="utf-8")
        problems += coverage(root)
    for p in problems:
        print("PROBLEM:", p)
    rows = text.count("\n") - 1
    print(f"{'PASS' if not problems else 'FAIL'}: traceability matrix, {rows:,} rows, {len(problems)} problems")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
