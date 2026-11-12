#!/usr/bin/env python3
"""Build the runtime catalog of the unified app from the planning catalog (feature 187, UA-F01). Standard library only.

    python3 scripts/build_catalog.py               # write Catalog/experiences.json and the copies the package tests use
    python3 scripts/build_catalog.py --check       # compare the committed files with what would be written; write nothing
    python3 scripts/build_catalog.py --add-golden  # append the ids of new planning-catalog experiences to the golden list

Inputs:
  docs/catalog/experience-catalog.json   the planning catalog: ids, names, tiers, categories, families, order
  .autonomy/migration/ledger.json        read only: an experience is available only when its gate X-<code> is pass
  Catalog/registrations.json             what a built experience declares: capabilities, quality tiers, tile colors,
                                         content facts; empty until the first experience is integrated
  Catalog/categories.json, Catalog/path-map.json   written by hand, validated here

Outputs:
  Catalog/experiences.json               the runtime manifest (schema 1; contracts of specs/187-ua-f01-experience-catalog)
  Packages/VisualCore/Tests/VisualCoreExperienceTests/Fixtures/Catalog/   byte-identical copies of the five catalog files

Rules: the launch set is exactly 50 free (A01-A25, R02-G01..G25) and 50 premium (R03-G01..R04-G25); an available
experience needs a registration; every id of the planning catalog is in Catalog/experience-ids.golden.txt, which only
grows; the same inputs give the same bytes; each file is written completely or not at all. This tool never writes
the migration ledger and never starts Claude or calls a model.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PLANNING = Path("docs/catalog/experience-catalog.json")
LEDGER = Path(".autonomy/migration/ledger.json")  # read only: scripts/migration_ledger.py is its writer
CATALOG = Path("Catalog")
MANIFEST = CATALOG / "experiences.json"
CATEGORY_FILE = CATALOG / "categories.json"
REGISTRATIONS = CATALOG / "registrations.json"
MOVES = CATALOG / "path-map.json"
GOLDEN = CATALOG / "experience-ids.golden.txt"
FIXTURES = Path("Packages/VisualCore/Tests/VisualCoreExperienceTests/Fixtures/Catalog")
COPIED = (MANIFEST, CATEGORY_FILE, REGISTRATIONS, MOVES, GOLDEN)
CATEGORIES = ["create", "audio", "play", "learn", "ambient", "tools", "puzzle"]
ID = re.compile(r"(a\d\d|r\d\d-g\d\d)\.[a-z0-9]+(-[a-z0-9]+)*")
FREE = [f"A{n:02d}" for n in range(1, 26)] + [f"R02-G{n:02d}" for n in range(1, 26)]
PREMIUM = [f"R{r:02d}-G{n:02d}" for r in (3, 4) for n in range(1, 26)]
REGISTRATION_KEYS = ["capabilities", "quality_tiers", "palette", "content"]


def fail(message: str) -> None:
    raise SystemExit("ERROR: " + message)


def read_json(root: Path, rel: Path):
    try:
        return json.loads((root / rel).read_text(encoding="utf-8"))
    except (OSError, ValueError) as error:
        fail(f"cannot read {rel.as_posix()}: {type(error).__name__}: {str(error)[:120]}")


def need(condition: bool, rel: Path, message: str) -> None:
    if not condition:
        fail(f"{rel.as_posix()}: {message}")


def family_tag(family: str) -> str:
    """Lower case, groups of ASCII letters and digits joined by hyphens ("Wave mathematics" -> wave-mathematics)."""
    return re.sub(r"[^a-z0-9]+", "-", family.lower()).strip("-")


def tile_seed(experience_id: str) -> int:
    """The first four bytes of SHA-256 of the id as an unsigned whole number."""
    return int.from_bytes(hashlib.sha256(experience_id.encode("utf-8")).digest()[:4], "big")


def strings(value, rel: Path, what: str, max_count: int, max_length: int) -> list[str]:
    need(isinstance(value, list) and len(value) <= max_count and all(isinstance(v, str) and 1 <= len(v) <= max_length for v in value),
         rel, f"{what} must be at most {max_count} texts of 1 to {max_length} characters")
    return value


def load_registrations(root: Path, known_ids: set[str]) -> dict:
    data = read_json(root, REGISTRATIONS)
    need(isinstance(data, dict) and data.get("schema") == 1, REGISTRATIONS, "expected schema 1")
    need(set(data) == {"schema", "registrations"} and isinstance(data["registrations"], dict), REGISTRATIONS,
         "expected exactly the keys schema and registrations")
    for experience_id, entry in data["registrations"].items():
        need(experience_id in known_ids, REGISTRATIONS, f"{experience_id} is not an id of the planning catalog")
        need(isinstance(entry, dict) and sorted(entry) == sorted(REGISTRATION_KEYS), REGISTRATIONS,
             f"{experience_id}: expected exactly the keys {', '.join(REGISTRATION_KEYS)}")
        strings(entry["capabilities"], REGISTRATIONS, f"{experience_id}: capabilities", 16, 40)
        strings(entry["quality_tiers"], REGISTRATIONS, f"{experience_id}: quality_tiers", 8, 40)
        need(isinstance(entry["palette"], list) and len(entry["palette"]) <= 8
             and all(isinstance(c, str) and re.fullmatch(r"#[0-9A-Fa-f]{6}", c) for c in entry["palette"]),
             REGISTRATIONS, f"{experience_id}: palette must be at most 8 colors written #RRGGBB")
        content = entry["content"]
        need(content is None or (isinstance(content, dict) and sorted(content) == ["catalog_sha256", "levels"]
                                 and isinstance(content["levels"], int) and not isinstance(content["levels"], bool)
                                 and 0 <= content["levels"] <= 10_000
                                 and isinstance(content["catalog_sha256"], str) and re.fullmatch(r"[0-9a-f]{64}", content["catalog_sha256"])),
             REGISTRATIONS, f"{experience_id}: content must be null or levels (0 to 10,000) and catalog_sha256")
    return data["registrations"]


def check_side_files(root: Path) -> None:
    categories = read_json(root, CATEGORY_FILE)
    need(isinstance(categories, dict) and categories.get("schema") == 1 and set(categories) == {"schema", "categories"},
         CATEGORY_FILE, "expected schema 1 and the key categories")
    listed = categories["categories"]
    need(isinstance(listed, list) and [c.get("id") if isinstance(c, dict) else None for c in listed] == CATEGORIES, CATEGORY_FILE,
         "expected the seven categories in launcher order: " + ", ".join(CATEGORIES))
    need(all(set(c) == {"id", "title"} and isinstance(c["title"], str) and 1 <= len(c["title"]) <= 40 for c in listed),
         CATEGORY_FILE, "each category has exactly an id and a title of 1 to 40 characters")
    moves = read_json(root, MOVES)
    need(isinstance(moves, dict) and moves.get("schema") == 1 and set(moves) == {"schema", "moves"} and isinstance(moves["moves"], list),
         MOVES, "expected schema 1 and the list moves")
    need(len(moves["moves"]) <= 5_000 and all(isinstance(m, dict) and sorted(m) == ["commit", "from", "gate", "to"]
                                                and all(isinstance(v, str) and 1 <= len(v) <= 300 for v in m.values())
                                                for m in moves["moves"]),
         MOVES, "each move has exactly from, to, gate and commit, each a text of 1 to 300 characters")


def planning_experiences(root: Path) -> tuple[list[dict], str]:
    try:
        raw = (root / PLANNING).read_bytes()
    except OSError as error:
        fail(f"cannot read {PLANNING.as_posix()}: {type(error).__name__}")
    catalog = read_json(root, PLANNING)
    need(isinstance(catalog, dict) and isinstance(catalog.get("experiences"), list), PLANNING, "expected the list experiences")
    experiences = catalog["experiences"]
    for e in experiences:
        need(isinstance(e, dict) and all(k in e for k in ("id", "code", "name", "slug", "kind", "tier", "release", "family",
                                                          "launcher_category", "order", "design")), PLANNING,
             f"an experience lacks an expected key ({e.get('code') if isinstance(e, dict) else e})")
        need(isinstance(e["id"], str) and ID.fullmatch(e["id"]) is not None and e["id"] == f"{e['code'].lower()}.{e['slug']}",
             PLANNING, f"{e['code']}: the id is not <code in lower case>.<slug>")
    need(len({e["id"] for e in experiences}) == len(experiences), PLANNING, "an id occurs twice")
    return experiences, hashlib.sha256(raw).hexdigest()


def golden_ids(root: Path) -> list[str]:
    path = root / GOLDEN
    return path.read_text(encoding="utf-8").splitlines() if path.is_file() else []


def golden_problems(root: Path, experiences: list[dict]) -> list[str]:
    listed, defined = golden_ids(root), [e["id"] for e in experiences]
    problems = [f"{GOLDEN.as_posix()}: {i} is listed twice" for i in sorted({i for i in listed if listed.count(i) > 1})]
    problems += [f"{GOLDEN.as_posix()}: the listed id {i} is not in the planning catalog (an id never changes and is never removed)"
                 for i in listed if i not in set(defined)]
    problems += [f"{GOLDEN.as_posix()}: {i} of the planning catalog is not listed (run python3 scripts/build_catalog.py --add-golden)"
                 for i in defined if i not in set(listed)]
    return problems


def manifest_text(root: Path) -> tuple[str, dict]:
    """The manifest as it must be written, and its counts. Stops with an error when an input is wrong."""
    experiences, catalog_hash = planning_experiences(root)
    ledger = read_json(root, LEDGER)
    need(isinstance(ledger, dict) and isinstance(ledger.get("gates"), list), LEDGER, "expected the list gates")
    gates = {g["id"]: g.get("status") for g in ledger["gates"] if isinstance(g, dict) and "id" in g}
    registrations = load_registrations(root, {e["id"] for e in experiences})
    check_side_files(root)

    launch = [e for e in experiences if e["release"] == "launch"]
    for codes, tier in ((FREE, "free"), (PREMIUM, "premium")):
        for code in codes:
            match = [e for e in launch if e["code"] == code]
            need(len(match) == 1 and match[0]["tier"] == tier, PLANNING,
                 f"launch allocation: {code} must be present once and {tier} (ADR-0009 D-02)")
    need(len(launch) == len(FREE) + len(PREMIUM), PLANNING, "launch allocation: the launch set is exactly 50 free and 50 premium")

    entries = []
    for e in sorted(experiences, key=lambda x: x["order"]):
        gate = f"X-{e['code']}"
        if e["release"] != "launch" and gate not in gates:
            continue  # a backlog round enters the manifest when its gates exist in the ledger
        summary = e["design"].get("summary") or e["design"].get("pitch") or ""
        need(1 <= len(e["name"]) <= 80 and 1 <= len(summary) <= 300 and 1 <= len(e["family"]) <= 60, PLANNING,
             f"{e['code']}: title, summary or family outside its length limit")
        need(e["launcher_category"] in CATEGORIES and (e["launcher_category"] == "puzzle") == (e["kind"] == "game"), PLANNING,
             f"{e['code']}: a game is a puzzle and a creative experience is not")
        available = gates.get(gate) == "pass"
        registration = registrations.get(e["id"])
        if available and registration is None:
            fail(f"{e['id']} is available ({gate} is pass) but has no registration in {REGISTRATIONS.as_posix()}")
        registration = registration or {"capabilities": [], "quality_tiers": [], "palette": [], "content": None}
        need(registration["content"] is None or e["kind"] == "game", REGISTRATIONS, f"{e['id']}: only a game has content facts")
        entries.append({
            "id": e["id"], "code": e["code"], "title": e["name"], "summary": summary,
            "kind": "creative" if e["kind"] == "creative-app" else "game",
            "tier": "free" if e["tier"] == "free" else "premium",
            "category": e["launcher_category"], "family": e["family"], "tags": [family_tag(e["family"])], "order": e["order"],
            "palette": registration["palette"], "tile_seed": tile_seed(e["id"]), "capabilities": registration["capabilities"],
            "quality_tiers": registration["quality_tiers"], "content": registration["content"], "available": available,
        })
    counts = {"experiences": len(entries), "free": sum(x["tier"] == "free" for x in entries),
              "premium": sum(x["tier"] == "premium" for x in entries), "available": sum(x["available"] for x in entries)}
    text = json.dumps({"schema": 1, "catalog_sha256": catalog_hash, "experiences": entries}, indent=2, ensure_ascii=False) + "\n"
    return text, counts


def atomic_write(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
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


def expected_files(root: Path) -> tuple[dict[Path, bytes], dict]:
    """Every file this tool owns, with the bytes it must have."""
    text, counts = manifest_text(root)
    files = {MANIFEST: text.encode("utf-8")}
    for rel in COPIED:
        files[FIXTURES / rel.name] = files[MANIFEST] if rel == MANIFEST else (root / rel).read_bytes()
    return files, counts


def first_difference(found: bytes, expected: bytes) -> str:
    a, b = found.decode("utf-8", "replace").split("\n"), expected.decode("utf-8", "replace").split("\n")
    for number, (x, y) in enumerate(zip(a, b), 1):
        if x != y:
            return f"line {number}: found {x.strip()[:80]!r}, expected {y.strip()[:80]!r}"
    return f"{len(a)} lines found, {len(b)} expected"


def cmd_add_golden(root: Path) -> int:
    experiences, _ = planning_experiences(root)
    listed = golden_ids(root)
    foreign = [i for i in listed if i not in {e["id"] for e in experiences}]
    if foreign:
        fail(f"{GOLDEN.as_posix()}: the listed id {foreign[0]} is not in the planning catalog; an id never changes and is never removed")
    new = [e["id"] for e in sorted(experiences, key=lambda x: x["order"]) if e["id"] not in set(listed)]
    if new:
        atomic_write(root / GOLDEN, ("\n".join(listed + new) + "\n").encode("utf-8"))
    print(f"{GOLDEN.as_posix()}: {len(new)} ids added, {len(listed) + len(new)} listed")
    return 0


def cmd_check(root: Path) -> int:
    experiences, _ = planning_experiences(root)
    problems = golden_problems(root, experiences)
    files, _ = expected_files(root)
    for rel, expected in files.items():
        path = root / rel
        if not path.is_file():
            problems.append(f"{rel.as_posix()}: missing (run python3 scripts/build_catalog.py)")
        elif path.read_bytes() != expected:
            problems.append(f"{rel.as_posix()}: differs from what the tool writes; {first_difference(path.read_bytes(), expected)}")
    for problem in problems:
        print("PROBLEM:", problem)
    print(f"{'PASS' if not problems else 'FAIL'}: runtime catalog, {len(problems)} problems")
    return 1 if problems else 0


def cmd_build(root: Path) -> int:
    experiences, _ = planning_experiences(root)
    problems = golden_problems(root, experiences)
    if problems:
        fail(problems[0])
    files, counts = expected_files(root)
    for rel, data in files.items():
        if not (root / rel).is_file() or (root / rel).read_bytes() != data:
            atomic_write(root / rel, data)
    print(f"built {MANIFEST.as_posix()}: {counts['experiences']} experiences, {counts['free']} free, {counts['premium']} premium, "
          f"{counts['available']} available")
    return 0


def main(argv: list[str] | None = None, root: Path = ROOT) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    group = ap.add_mutually_exclusive_group()
    group.add_argument("--check", action="store_true")
    group.add_argument("--add-golden", action="store_true")
    args = ap.parse_args(argv)
    if args.add_golden:
        return cmd_add_golden(root)
    return cmd_check(root) if args.check else cmd_build(root)


if __name__ == "__main__":
    sys.exit(main())
