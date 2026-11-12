#!/usr/bin/env python3
"""Validate the steering documents of the unified VisualCore app. Deterministic, standard library only.

    python3 scripts/validate_autocreator.py            # every check; exit 1 on any problem
    python3 scripts/validate_autocreator.py --list     # the checks
    python3 scripts/validate_autocreator.py --only catalog prices

Checks (ADR-0009; each returns a list of problems and has self-tests in scripts/test_scripts.py):

  baseline      planning documents, legacy evidence and legacy passed gates are unchanged since the baseline
  archive       docs/archive/planning is byte-identical to the original documents
  index         the catalog and the feature index match the archive and the legacy ledger
  catalog       300 unique experiences; exactly 100 at launch: 50 free (A01-A25, R02) and 50 premium (R03, R04)
  game-specs    every game has its source span, ten features with eight prompts each, an assertion outline, a
                manifest of 100 levels and 80 acceptance scenarios (and 50 fault-injection cases from round 3 on);
                every feature of features 001-185 ends with implement and converge
  briefs        15 unified-app features with unique ids, numbers 186-200, complete briefs and eight stage prompts
  structure     Auto-Creator.md has sections 1-28 in order, a working table of contents, a card for each of the
                100 launch experiences, unique requirement ids, and its generated blocks match their data
  continuation  the continuation prompt is the last section and the last text of Auto-Creator.md and is complete
  ledger        the migration ledger validates and agrees with the catalog and the briefs
  matrix        the traceability matrix is current, covers every document, experience and feature, and points
                at sections and paths that exist
  prices        USD 1.99 is the only forward price; other prices appear only as superseded source terms
  monetization  no sentence allows advertising, subscriptions, consumables or tracking
  secrets       no hardware identifier, team id, e-mail address, key or token in the steering documents
  links         relative links of the root documents and docs/migration resolve; referenced scripts exist
  references    types named as existing exist in the framework; path-map sources exist; skills are installed
  bootstrap     CLAUDE.md is small and points at the constitution, Auto-Creator.md, the ledgers and the safety rules
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))
import build_traceability_matrix as matrix  # noqa: E402
import migration_baseline  # noqa: E402
import migration_ledger  # noqa: E402
import planning_archive  # noqa: E402
import planning_index  # noqa: E402
import render_autocreator  # noqa: E402

DOC = Path("Auto-Creator.md")
CATALOG = Path("docs/catalog/experience-catalog.json")
FEATURES = Path("docs/catalog/feature-index.json")
BRIEFS = Path("docs/catalog/unified-app-features.json")
SHARED = Path("docs/catalog/shared-feature-map.json")
PATHMAP = Path("docs/migration/path-map.json")
LEGACY_PROMPTS = Path("docs/process/speckit-prompt-manifest.json")
STEERING = ["Auto-Creator.md", "README.md", "setup.md", "CLAUDE.md", "docs/decisions/ADR-0009-unified-app.md",
            "docs/migration/migration-plan.md", "docs/migration/pre-fable-baseline.md", "docs/archive/planning/README.md",
            "docs/catalog/unified-app-features.json", "docs/catalog/shared-feature-map.json", "docs/migration/path-map.json"]
LINKED = ["Auto-Creator.md", "README.md", "setup.md", "CLAUDE.md", "docs/migration/migration-plan.md",
          "docs/archive/planning/README.md"]
SECTIONS = 28
SKILLS = ["constitution", "specify", "clarify", "plan", "checklist", "tasks", "analyze", "implement", "converge"]
PLANNED_SCRIPTS = {"scripts/verify_experiences.py", "scripts/run_device_campaign.py"}
PROMPT_MUST_CONTAIN = [
    "STEP 0", "CHECKPOINT REPORT", "STEP 1", "ORDER OF WORK", "DONE MEANS", "STOP CONDITIONS", "REPORT AT THE END",
    "on branch main", "python3 scripts/prepush_scan.py --push", "python3 scripts/migration_ledger.py status",
    "python3 scripts/migration_ledger.py next",
    "python3 Tools/python/desktop_runbook.py status", "python3 scripts/validate_autocreator.py", "guard-device",
    "ImplementationLock-100", "LOCK-FREE-50", "LOCK-PREMIUM-50", "UA-F08", "1.99", "/speckit-converge", "CONSTITUTION-2",
    "iPhone15,4", "iPad17,3", "iPad15,7", "iPadOS 26.5", "NEVER update", "BLOCKED_OWNER_ACTION", "add-round", "xcodebuild",
    "devicectl", "Never use the\nClaude CLI",
]
FENCE = re.compile(r"^(```|~~~)")
NEGATION = re.compile(r"\b(no|not|never|none|without|neither|nor|forbid\w*|prohibit\w*|refus\w*|zero|free of|absent|superseded|"
                      r"excluded?|fails?|reject\w*|must not|nothing|any finding|scan\w*|audit\w*|non-goals?)\b", re.I)
MONETIZATION = re.compile(r"\b(ads?|advertis\w+|ad[- ]supported|rewarded|subscriptions?|consumables?|ad identifiers?|"
                          r"AdSupport|AppTrackingTransparency|tracking SDKs?|analytics SDKs?)\b", re.I)
SECRET_PATTERNS = [
    ("hardware identifier", re.compile(r"\b[0-9A-Fa-f]{8}-[0-9A-Fa-f]{16}\b")),
    ("device or simulator UUID", re.compile(r"\b[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}\b")),
    ("development team id", re.compile(r"DEVELOPMENT_TEAM\s*[=:]\s*[A-Z0-9]{10}\b")),
    ("e-mail address", re.compile(r"\b[\w.+-]+@[\w-]+\.[A-Za-z]{2,}\b")),
    ("private key", re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----")),
    ("access token", re.compile(r"\b(ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|sk-ant-[A-Za-z0-9-]{10,}|AKIA[0-9A-Z]{16})\b")),
]


def read(root: Path, rel) -> str:
    return (root / rel).read_text(encoding="utf-8")


def load(root: Path, rel):
    return json.loads(read(root, rel))


def prose_lines(text: str) -> list[tuple[int, str]]:
    """(line number, line) outside fenced code blocks."""
    out, fenced = [], False
    for n, line in enumerate(text.split("\n"), 1):
        if FENCE.match(line):
            fenced = not fenced
        elif not fenced:
            out.append((n, line))
    return out


# ---------------------------------------------------------------- pure checks (unit-tested)

def check_catalog(catalog: dict) -> list[str]:
    problems = []
    es = catalog["experiences"]
    for field in ("code", "id", "slug"):
        values = [e[field] for e in es]
        dupes = sorted({v for v in values if values.count(v) > 1})
        if field != "slug" and dupes:
            problems.append(f"duplicate experience {field}: {', '.join(dupes[:5])}")
    if len(es) != 300:
        problems.append(f"expected 300 experiences, found {len(es)}")
    if [e["order"] for e in es] != list(range(1, len(es) + 1)):
        problems.append("catalog order is not 1..N")
    for e in es:
        if e["id"] != f"{e['code'].lower()}.{e['slug']}":
            problems.append(f"{e['code']}: runtime id {e['id']} is not <code>.<slug>")
        if not re.fullmatch(r"[a-z0-9-]+\.[a-z0-9-]+", e["id"]):
            problems.append(f"{e['code']}: runtime id {e['id']} has characters outside [a-z0-9-.]")
    launch = [e for e in es if e["release"] == "launch"]
    free = [e["code"] for e in launch if e["tier"] == "free"]
    premium = [e["code"] for e in launch if e["tier"] == "premium"]
    want_free = [f"A{n:02d}" for n in range(1, 26)] + [f"R02-G{n:02d}" for n in range(1, 26)]
    want_premium = [f"R{r:02d}-G{n:02d}" for r in (3, 4) for n in range(1, 26)]
    if len(launch) != 100:
        problems.append(f"expected exactly 100 launch experiences, found {len(launch)}")
    if free != want_free:
        problems.append("the free tier is not exactly A01-A25 and R02-G01..G25 in order")
    if premium != want_premium:
        problems.append("the premium tier is not exactly R03-G01..R04-G25 in order")
    rest = [e for e in es if e["release"] != "launch"]
    if any(e["tier"] != "premium-backlog" or e["release"] != "backlog" for e in rest):
        problems.append("an experience outside the launch set is not premium-backlog")
    if [e["code"] for e in rest] != [f"R{r:02d}-G{n:02d}" for r in range(5, 13) for n in range(1, 26)]:
        problems.append("the backlog is not rounds 5-12 in their source order")
    return problems


def check_game_specs(catalog: dict, index: dict, legacy_prompts: dict | None = None) -> list[str]:
    problems = []
    by_exp: dict[str, list[dict]] = {}
    ids = [f["id"] for f in index["features"]]
    if len(ids) != len(set(ids)):
        problems.append("duplicate feature ids in the feature index")
    for f in index["features"]:
        if f["kind"] == "game-feature":
            by_exp.setdefault(f["experience"], []).append(f)
        if f["kind"] in ("game-feature", "shared-round-feature"):
            missing = [s for s in planning_index.STAGES if s not in f.get("prompts", {})]
            if missing:
                problems.append(f"{f['id']}: missing stage prompts {', '.join(missing)}")
            if not f.get("spec_dir_proposed"):
                problems.append(f"{f['id']}: no spec directory")
    for e in catalog["experiences"]:
        if e["kind"] != "game":
            if len(e["design"]["phases"]) != 7 or len(e["design"]["mvp_features"]) < 1 or not e["design"]["fixtures"]:
                problems.append(f"{e['code']}: creative experience without seven phases, required features or fixtures")
            continue
        if len(by_exp.get(e["code"], [])) != 10:
            problems.append(f"{e['code']}: expected ten game features, found {len(by_exp.get(e['code'], []))}")
        if not e.get("assertion_outline"):
            problems.append(f"{e['code']}: no assertion outline")
        if not e.get("source", {}).get("sha256"):
            problems.append(f"{e['code']}: no source span")
        if e.get("level_manifest", {}).get("rows") != 100:
            problems.append(f"{e['code']}: level manifest does not have 100 rows")
        if e.get("acceptance_scenarios", {}).get("rows") != 80:
            problems.append(f"{e['code']}: the chapter does not have 80 acceptance scenarios")
        if e["collection"] != "round-02" and e.get("fault_injection", {}).get("rows") != 50:
            problems.append(f"{e['code']}: the chapter does not have 50 fault-injection cases")
    if legacy_prompts is not None:
        for f in legacy_prompts["features"]:
            commands = [c["command"] for c in f["commands"]]
            if not commands or commands[-1] != "speckit-converge" or "speckit-implement" not in commands:
                problems.append(f"feature {f['feature']} ({f['gate']}): the prompt sequence does not end with implement and converge")
    return problems


def check_briefs(briefs: dict) -> list[str]:
    problems = []
    fs = briefs["features"]
    if [b["id"] for b in fs] != [f"UA-F{n:02d}" for n in range(len(fs))] or len(fs) != 15:
        problems.append("unified-app features are not exactly UA-F00..UA-F14 in order")
    if [b["number"] for b in fs] != list(range(186, 186 + len(fs))):
        problems.append("unified-app feature numbers are not 186..200")
    known = {b["id"] for b in fs}
    for b in fs:
        if b["namespace"] != f"U{b['number'] - 186:02d}":
            problems.append(f"{b['id']}: namespace {b['namespace']} does not match number {b['number']}")
        for field in ("title", "scope", "acceptance", "evidence", "sources", "out_of_scope"):
            if not b.get(field):
                problems.append(f"{b['id']}: empty {field}")
        if len(b.get("acceptance", [])) < 3:
            problems.append(f"{b['id']}: fewer than three acceptance statements")
        problems += [f"{b['id']}: depends on unknown feature {d}" for d in b["depends_on"] if d not in known]
        if b["id"] in b["depends_on"]:
            problems.append(f"{b['id']}: depends on itself")
        prompts = planning_index.unified_prompts(b)
        for stage in planning_index.STAGES:
            text = prompts.get(stage, "")
            if not text.startswith(f"/speckit-{stage} ") or len(text) < 200:
                problems.append(f"{b['id']}: the {stage} prompt is missing or too short")
            if f"specs/{b['number']}-{b['slug']}" not in text:
                problems.append(f"{b['id']}: the {stage} prompt does not name the spec directory")
        if "repeat until a run\nappends nothing" not in prompts["converge"] and "repeat until a run appends nothing" not in prompts["converge"]:
            problems.append(f"{b['id']}: the converge prompt has no repeat-until-converged contract")
        if "{device}" not in prompts["tasks"] or "{owner}" not in prompts["tasks"]:
            problems.append(f"{b['id']}: the tasks prompt does not tag device-only and owner-only work")
    if "/speckit-constitution" not in briefs.get("constitution_amendment", {}).get("prompt", ""):
        problems.append("the constitution amendment prompt is missing")
    return problems


def numbered_sections(text: str) -> list[tuple[int, str]]:
    return [(int(m.group(1)), m.group(2)) for n, line in prose_lines(text) for m in [re.match(r"^## (\d+)\. (.+)$", line)] if m]


def check_structure(text: str, catalog: dict, briefs: dict) -> list[str]:
    problems = []
    numbers = [n for n, _ in numbered_sections(text)]
    if numbers != list(range(1, SECTIONS + 1)):
        problems.append(f"sections are not numbered 1..{SECTIONS} in order: found {numbers}")
    anchors = {render_autocreator.anchor(title) for _, title in render_autocreator.headings(text)}
    for n, line in prose_lines(text):
        for target in re.findall(r"\]\(#([^)]+)\)", line):
            if target not in anchors:
                problems.append(f"line {n}: link to missing anchor #{target}")
    titles = {title for level, title in render_autocreator.headings(text) if level == 3}
    for e in catalog["experiences"]:
        if e["release"] == "launch" and f"{e['code']} {e['name']}" not in titles:
            problems.append(f"no card for {e['code']} {e['name']}")
    for b in briefs["features"]:
        if f"{b['id']} {b['title']}" not in titles:
            problems.append(f"no brief for {b['id']}")
        for stage in planning_index.STAGES:
            if f"#### {b['id']} `/speckit-{stage}`" not in text:
                problems.append(f"{b['id']}: no /speckit-{stage} prompt in section 20")
    for prefix in ("P", "E"):
        ids = re.findall(rf"^\| ({prefix}-\d\d)\b", text, re.M)
        dupes = sorted({i for i in ids if ids.count(i) > 1})
        if dupes:
            problems.append(f"duplicate requirement ids: {', '.join(dupes)}")
    if text.count("\r"):
        problems.append("the document has CR line endings")
    return problems


def check_continuation(text: str) -> list[str]:
    problems = []
    sections = numbered_sections(text)
    if not sections or sections[-1] != (SECTIONS, "Continuation prompt"):
        return [f"the last numbered section is not '{SECTIONS}. Continuation prompt'"]
    start = text.rindex(f"\n## {SECTIONS}. Continuation prompt\n")
    if re.search(r"^#{1,6} ", text[start + 4:].split("```text\n", 1)[0].split("\n", 1)[1], re.M):
        problems.append("a heading follows the continuation prompt heading before the prompt")
    tail = text[start:]
    if tail.count("```text\n") != 1 or not tail.endswith("\n```\n"):
        problems.append("the continuation prompt must be one ```text block that ends the file")
        return problems
    prompt = tail.split("```text\n", 1)[1][:-len("```\n")]
    if "```" in prompt:
        problems.append("text follows the continuation prompt block")
    for needle in PROMPT_MUST_CONTAIN:
        if needle not in prompt:
            problems.append(f"the continuation prompt lacks {needle!r}")
    order = ["UA-F00", "LOCK-FREE-50", "UA-F08", "LOCK-PREMIUM-50", "ImplementationLock-100", "D1 (iPhone15,4)", "RELEASE-PREP", "add-round"]
    body = prompt.split("ORDER OF WORK", 1)[-1].split("DONE MEANS", 1)[0]
    positions = [body.find(o) for o in order]
    if -1 in positions or positions != sorted(positions):
        problems.append("the order of work in the continuation prompt is not: unified features, free library, purchase, "
                        "premium library, lock, devices, release preparation, backlog")
    if re.search(r"\b(click|open Xcode|in Xcode's (menu|UI)|press the)\b", prompt.replace("TOOLS, NOT CLICKS", ""), re.I):
        problems.append("the continuation prompt tells the reader to operate a user interface")
    return problems


def check_prices(name: str, text: str) -> list[str]:
    """USD 1.99 is the only price. Any other amount must be a quoted source term (inside double quotes) in a Markdown
    document; data files may not contain another amount at all."""
    problems = []
    data_file = name.endswith(".json")
    for n, line in enumerate(text.split("\n"), 1):
        visible = line if data_file else re.sub(r'"[^"]*"', "", line)
        for amount in re.findall(r"(?:\$|USD\s?)(\d+\.\d\d)", visible):
            if amount != "1.99":
                problems.append(f"{name}:{n}: price {amount} is not USD 1.99 and is not a quoted source term")
    return problems


def statements(text: str) -> list[tuple[int, str]]:
    """(first line number, statement). A statement is a sentence; table rows and list items are units of their own."""
    units: list[tuple[int, list[str]]] = []
    for n, line in enumerate(text.split("\n"), 1):
        stripped = line.strip()
        starts = not units or not stripped or stripped.startswith(("|", "- ", "* ", "#")) or re.match(r"^\d+\. ", stripped) \
            or not units[-1][1] or units[-1][1][-1].startswith("|")
        if not stripped:
            units.append((n, []))
        elif starts:
            units.append((n, [stripped]))
        else:
            units[-1][1].append(stripped)
    out = []
    for n, parts in units:
        if parts:
            out += [(n, piece) for piece in re.split(r"(?<=[.!?])\s+", " ".join(parts)) if piece]
    return out


def check_monetization(name: str, text: str) -> list[str]:
    """Every statement that mentions advertising, subscriptions or consumables must exclude them."""
    problems = []
    for n, statement in statements(text):
        cleaned = re.sub(r"non-consumables?|no-advertising|zero-ads|ad-free", "", statement, flags=re.I)
        if MONETIZATION.search(cleaned) and not NEGATION.search(cleaned):
            problems.append(f"{name}:{n}: mentions advertising, subscriptions or consumables without excluding them: "
                            f"{statement.strip()[:90]}")
    return problems


def check_secrets(name: str, text: str) -> list[str]:
    problems = []
    for n, line in enumerate(text.split("\n"), 1):
        for label, pattern in SECRET_PATTERNS:
            if pattern.search(line):
                problems.append(f"{name}:{n}: looks like a {label}")
    return problems


def check_links(root: Path, name: str, text: str) -> list[str]:
    problems = []
    base = (root / name).parent
    for n, line in prose_lines(text):
        for target in re.findall(r"\]\(([^)\s]+)\)", line):
            if re.match(r"^[a-z][a-z0-9+.-]*:", target) or target.startswith("#"):
                continue
            if not (base / target.split("#", 1)[0]).exists():
                problems.append(f"{name}:{n}: broken link {target}")
        for script in re.findall(r"\b((?:scripts|Tools/python)/[A-Za-z0-9_]+\.py)\b", line):
            if not (root / script).is_file() and script not in PLANNED_SCRIPTS:
                problems.append(f"{name}:{n}: script {script} does not exist and is not a planned script")
            if script in PLANNED_SCRIPTS and (root / script).is_file():
                problems.append(f"{name}:{n}: {script} exists now; remove it from the planned list of the validator")
    return problems


def check_bootstrap(text: str) -> list[str]:
    problems = []
    if len(text.encode()) > 12000:
        problems.append(f"CLAUDE.md is {len(text.encode())} bytes; the bootstrap must stay under 12,000")
    for needle in ("Auto-Creator.md", ".specify/memory/constitution.md", "scripts/migration_ledger.py status",
                   "Tools/python/desktop_runbook.py status", "DO NOT UPDATE D3", "ImplementationLock-100",
                   "BLOCKED_OWNER_ACTION", "scripts/prepush_scan.py", "No advertising"):
        if needle not in text:
            problems.append(f"CLAUDE.md lacks {needle!r}")
    return problems


# ---------------------------------------------------------------- repository checks

def cited_sections(briefs: dict) -> set[str]:
    """Section numbers of Auto-Creator.md cited by the briefs, with ranges such as '11.4 to 11.6' expanded."""
    out = set()
    for b in briefs["features"]:
        for src in b["sources"]:
            if src.startswith("Auto-Creator.md"):
                out |= set(re.findall(r"\b(\d+(?:\.\d+)?)\b", src))
                for major, first, last in re.findall(r"\b(\d+)\.(\d+) to \1\.(\d+)\b", src):
                    out |= {f"{major}.{k}" for k in range(int(first), int(last) + 1)}
    return out


def run_structure(root: Path) -> list[str]:
    text = read(root, DOC)
    catalog, briefs = load(root, CATALOG), load(root, BRIEFS)
    problems = check_structure(text, catalog, briefs)
    current, rendered, render_problems = render_autocreator.render(root)
    problems += render_problems
    if current != rendered:
        problems.append("generated blocks are stale: run python3 scripts/render_autocreator.py")
    known = matrix.sections_of(text)
    for number in sorted(cited_sections(briefs)):
        if f"AC-{number}" not in known:
            problems.append(f"a feature brief cites section {number}, which is not a heading of {DOC}")
    for note in (planning_index.OVERRIDE_GAME, planning_index.OVERRIDE_SHARED, planning_index.OVERRIDE_APP_PHASE,
                 briefs["constitution_amendment"]["prompt"]):
        for number in re.findall(r"Auto-Creator\.md section (\d+(?:\.\d+)?)", note):
            if f"AC-{number}" not in known:
                problems.append(f"a prompt cites section {number}, which is not a heading of {DOC}")
    return problems


def run_ledger(root: Path) -> list[str]:
    problems = migration_ledger.validate(root)
    ledger = load(root, migration_ledger.LEDGER)
    gates = {g["id"]: g for g in ledger["gates"]}
    catalog, briefs = load(root, CATALOG), load(root, BRIEFS)
    for b in briefs["features"]:
        g = gates.get(b["id"])
        if not g:
            problems.append(f"no ledger gate for {b['id']}")
        elif g.get("spec_dir") != f"specs/{b['number']}-{b['slug']}":
            problems.append(f"{b['id']}: ledger spec_dir differs from the brief")
        elif not set(b["depends_on"]) <= set(g["depends"]):
            problems.append(f"{b['id']}: ledger dependencies do not include the brief's")
    for e in catalog["experiences"]:
        if e["release"] != "launch":
            continue
        g = gates.get(f"X-{e['code']}")
        if not g or g.get("tier") != e["tier"] or g.get("experience") != e["id"]:
            problems.append(f"X-{e['code']}: missing or inconsistent with the catalog")
        problems += [f"{d}-{e['code']}: missing device row" for d in migration_ledger.DEVICES if f"{d}-{e['code']}" not in gates]
    shared = load(root, SHARED)
    for g in ledger["gates"]:
        if g["kind"] != "shared-round-feature":
            continue
        rnd, key = g["id"].split("-")
        entry = shared["round-02" if rnd == "R02" else "rounds-03-12"].get(key)
        if not entry:
            problems.append(f"{g['id']}: not in the shared-feature map")
        elif (entry["disposition"] == "superseded") != (g["status"] == "superseded"):
            problems.append(f"{g['id']}: the shared-feature map and the ledger disagree about supersession")
    legacy = load(root, migration_ledger.LEGACY)["stages"]
    for e in catalog["experiences"]:
        if e["collection"] == "original":
            passed = [p["gate"] for p in e["design"]["phases"] if legacy[p["gate"]]["status"] == "pass"]
            if passed != e["implementation"]["legacy_gates_passed"]:
                problems.append(f"{e['code']}: the catalog's implementation state is stale: run python3 scripts/planning_index.py build")
    return problems


def run_matrix(root: Path) -> list[str]:
    text, problems = matrix.build(root)
    path = root / matrix.OUT
    if not path.is_file() or read(root, matrix.OUT) != text:
        problems.append(f"{matrix.OUT} is stale: run python3 scripts/build_traceability_matrix.py")
    else:
        problems += matrix.coverage(root)
    return problems


def run_references(root: Path) -> list[str]:
    problems = []
    declared = set()
    for f in (root / "Packages").rglob("Sources/**/*.swift"):
        declared |= set(re.findall(r"^\s*public\s+(?:final\s+)?(?:struct|class|enum|protocol|actor|typealias)\s+(\w+)", f.read_text(encoding="utf-8"), re.M))
    shared = load(root, SHARED)
    for group in ("round-02", "rounds-03-12"):
        for key, entry in shared[group].items():
            problems += [f"shared-feature map {group} {key}: {s} is not a public type of the framework" for s in entry["existing"] if s not in declared]
    listing = subprocess.run(["git", "ls-files"], cwd=root, capture_output=True, text=True, check=False)
    tracked = listing.stdout.splitlines() if listing.returncode == 0 else None
    for e in load(root, PATHMAP)["entries"]:
        if e["state"] != "pending":
            continue
        if e["from"] and not (root / e["from"]).exists():
            problems.append(f"path map: source {e['from']} does not exist")
        elif e["from"] and tracked is not None and not any(t == e["from"] or t.startswith(e["from"] + "/") for t in tracked):
            problems.append(f"path map: source {e['from']} is not tracked (generated output does not belong in the path map)")
        if e["action"] == "new" and (root / e["to"]).exists():
            problems.append(f"path map: {e['to']} is marked new but exists")
    problems += [f"Spec Kit skill speckit-{s} is not installed" for s in SKILLS if not (root / f".claude/skills/speckit-{s}/SKILL.md").is_file()]
    return problems


def run_text_checks(root: Path, check) -> list[str]:
    problems = []
    for name in STEERING:
        if not (root / name).is_file():
            problems.append(f"{name} is missing")
            continue
        problems += check(name, read(root, name))
    return problems


CHECKS = {
    "baseline": lambda root: migration_baseline.verify(root),
    "archive": lambda root: planning_archive.verify(root),
    "index": lambda root: planning_index.verify(root),
    "catalog": lambda root: check_catalog(load(root, CATALOG)),
    "game-specs": lambda root: check_game_specs(load(root, CATALOG), load(root, FEATURES), load(root, LEGACY_PROMPTS)),
    "briefs": lambda root: check_briefs(load(root, BRIEFS)),
    "structure": run_structure,
    "continuation": lambda root: check_continuation(read(root, DOC)),
    "ledger": run_ledger,
    "matrix": run_matrix,
    "prices": lambda root: run_text_checks(root, check_prices),
    "monetization": lambda root: run_text_checks(root, check_monetization),
    "secrets": lambda root: run_text_checks(root, check_secrets),
    "links": lambda root: [p for name in LINKED for p in (check_links(root, name, read(root, name)) if (root / name).is_file() else [f"{name} is missing"])],
    "references": run_references,
    "bootstrap": lambda root: check_bootstrap(read(root, "CLAUDE.md")),
}


def validate(root: Path = ROOT, only: list[str] | None = None) -> dict[str, list[str]]:
    results = {}
    for name, check in CHECKS.items():
        if only and name not in only:
            continue
        try:
            results[name] = list(check(root))
        except (OSError, KeyError, ValueError, SystemExit) as error:
            results[name] = [f"check could not run: {type(error).__name__}: {error}"]
    return results


def main(argv: list[str] | None = None, root: Path = ROOT) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--only", nargs="+", choices=list(CHECKS))
    args = ap.parse_args(argv)
    if args.list:
        print("\n".join(CHECKS))
        return 0
    results = validate(root, args.only)
    total = 0
    for name, problems in results.items():
        print(f"{'ok  ' if not problems else 'FAIL'} {name}" + (f" ({len(problems)})" if problems else ""))
        for p in problems[:25]:
            print("     PROBLEM:", p)
        if len(problems) > 25:
            print(f"     … and {len(problems) - 25} more")
        total += len(problems)
    print(f"{'PASS' if not total else 'FAIL'}: steering documents, {len(results)} checks, {total} problems")
    return 1 if total else 0


if __name__ == "__main__":
    sys.exit(main())
