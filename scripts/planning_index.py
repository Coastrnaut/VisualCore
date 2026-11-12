#!/usr/bin/env python3
"""Planning index: experience catalog, feature index and exact Spec Kit prompts from the planning archive (ADR-0009).

    python3 scripts/planning_index.py build                      # regenerate docs/catalog/*.json from the archive
    python3 scripts/planning_index.py verify                     # re-parse the archive and compare with docs/catalog
    python3 scripts/planning_index.py prompt --feature R03-G01-02 [--stage plan] [--override]
    python3 scripts/planning_index.py levels --experience R03-G01     # the planned level manifest of one game (JSON)

The archive under docs/archive/planning/ is the lossless source. This tool never edits it. It extracts

  * docs/catalog/experience-catalog.json   300 experiences: the 25 original creative apps (A01-A25), the 25 Round 2
                                           games (R02-G01..G25) and the 250 games of rounds 3-12, each with its unique
                                           design facts, its tier and the exact archive location it came from;
  * docs/catalog/feature-index.json        every planned Spec Kit feature (10 foundation phases, 175 original app
                                           phases, 154 shared round features, 2,750 game features) with the archive
                                           location of its section and of each of its stage prompts.

`prompt` prints the archived prompt text verbatim, after checking it against the hash recorded in the index.
`--override` appends the canonical override note of Auto-Creator.md section 21 for that feature class.

Line numbers are 1-based. A section hash is the SHA-256 of its lines joined with LF (no trailing LF).
Standard library only.
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
OUT_DIR = Path("docs/catalog")
CATALOG = OUT_DIR / "experience-catalog.json"
FEATURES = OUT_DIR / "feature-index.json"
BRIEFS = OUT_DIR / "unified-app-features.json"
SPEC_DOC = ARCHIVE / "root/README-2026-11-10-full-specification.md"
LEDGER = Path(".autonomy/state.json")
STAGES = ["specify", "clarify", "plan", "checklist", "tasks", "analyze", "implement", "converge"]
BOLD = re.compile(r"\*\*([^*:]+):\*\*\s*")


class ParseError(Exception):
    pass


def need(cond: bool, message: str) -> None:
    if not cond:
        raise ParseError(message)


def sha(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def slugify(name: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")


def read_lines(root: Path, rel: Path) -> list[str]:
    return (root / rel).read_text(encoding="utf-8").split("\n")


def span(rel: Path, lines: list[str], start: int, end: int) -> dict:
    """Archive location of lines[start:end] (0-based, end exclusive) as 1-based inclusive line numbers."""
    return {"file": rel.as_posix(), "line_start": start + 1, "line_end": end, "sha256": sha("\n".join(lines[start:end]))}


def bold_fields(text: str) -> dict[str, str]:
    """`**Key:** value **Key2:** value2` -> {Key: value, Key2: value2} (values stripped of trailing separators)."""
    out: dict[str, str] = {}
    parts = BOLD.split(text)
    for key, value in zip(parts[1::2], parts[2::2]):
        out.setdefault(key.strip(), value.strip().rstrip("•").strip())
    return out


def sentence(value: str) -> str:
    """The first sentence of a field (the unique fact); the templated tail after it is boilerplate."""
    cut = re.search(r"\.(\s|$)", value)
    return (value[:cut.start()] if cut else value).strip()


def headings(lines: list[str], lo: int, hi: int, pattern: str) -> list[tuple[int, re.Match]]:
    rx = re.compile(pattern)
    out, fence = [], False
    for i in range(lo, hi):
        if lines[i].startswith("```"):
            fence = not fence
        elif not fence:
            m = rx.match(lines[i])
            if m:
                out.append((i, m))
    return out


def find_line(lines: list[str], pattern: str, lo: int = 0, hi: int | None = None) -> int:
    rx = re.compile(pattern)
    for i in range(lo, len(lines) if hi is None else hi):
        if rx.match(lines[i]):
            return i
    raise ParseError(f"line not found: {pattern}")


def bullets(lines: list[str], start: int, stop_patterns: tuple[str, ...] = ("#", "**", ">", "|")) -> list[str]:
    """Consecutive `- ` or `N. ` items after line `start` (exclusive), skipping blank lines before the first."""
    out: list[str] = []
    i = start + 1
    while i < len(lines) and not lines[i].strip():
        i += 1
    while i < len(lines):
        m = re.match(r"^(?:- |\d+\. )(.*)$", lines[i])
        if not m:
            break
        out.append(m.group(1).strip())
        i += 1
    return out


# --------------------------------------------------------------------------------------------------------------
# Original 25 creative apps (the manuals embedded in the archived specification)
# --------------------------------------------------------------------------------------------------------------

# Launcher category of each original-app source category; every round game is a puzzle with its family as a tag.
LAUNCHER_CATEGORY = {"Creative and visual": "create", "Music and audio": "audio",
                     "Games and interactive experiences": "play", "Education and science": "learn",
                     "Ambient and lifestyle": "ambient", "Developer and creator tools": "tools"}

FEATURE_TAIL = " Acceptance requires an implemented behavior and a test or documented manual verification—not a screenshot mock."
RISK_TAIL = " Document owner, verification method, and a release blocker condition in `docs/decisions/`."


def roster_original(root: Path) -> dict[int, dict]:
    lines = read_lines(root, SPEC_DOC)
    start = find_line(lines, r"^### 2\.2 25 apps: original order and shared dependency waves")
    rows = {}
    for l in lines[start:start + 40]:
        m = re.match(r"^\| (\d\d) \| \*\*(.+?)\*\* \| ([ABC]) \| (.+?) \| (.+?) \|$", l)
        if m:
            rows[int(m.group(1))] = {"name": m.group(2), "wave": m.group(3), "capability": m.group(4), "validity_risk": m.group(5)}
    need(len(rows) == 25, f"original roster: expected 25 rows, found {len(rows)}")
    return rows


def parse_original(root: Path, ledger: dict) -> tuple[list[dict], list[dict]]:
    roster = roster_original(root)
    spec_dirs = {int(p.name[:3]): p.name for p in sorted((root / "specs").glob("[0-9][0-9][0-9]-*"))}
    experiences, features = [], []
    files = sorted((root / ARCHIVE / "embedded/apps").glob("[0-9][0-9]-*.md"))
    need(len(files) == 25, f"expected 25 app manuals, found {len(files)}")
    for path in files:
        rel = path.relative_to(root)
        lines = path.read_text(encoding="utf-8").split("\n")
        number = int(path.name[:2])
        name = lines[0].lstrip("# ").strip()
        need(name == roster[number]["name"], f"{rel}: name {name!r} differs from the roster")
        head = bold_fields(lines[find_line(lines, r"^\*\*Concept #")])
        category = head["Category"].rstrip("|").strip()
        target = re.search(r"`([^`]+)`", head["Proposed app/repository target"]).group(1)
        s1 = find_line(lines, r"^## 1\. Executive summary")
        summary = next(l for l in lines[s1 + 1:] if l.strip())
        quote = lines[find_line(lines, r"^> ", s1)][2:].strip()
        caps = bullets(lines, find_line(lines, r"^\*\*VisualCore capabilities listed in the brainstorm:\*\*"))
        opportunity = bold_fields(lines[find_line(lines, r"^\*\*Original product opportunity:\*\*")])["Original product opportunity"]
        audiences = bullets(lines, find_line(lines, r"^### Primary audiences"))
        journeys = [re.sub(r"^\*\*Journey \d+:\*\* ", "", b) for b in bullets(lines, find_line(lines, r"^### End-to-end user journeys"))]
        feats = [re.sub(r"^\*\*Feature \d+:\*\* ", "", b).replace(FEATURE_TAIL, "").rstrip(".")
                 for b in bullets(lines, find_line(lines, r"^### Version 0\.1 feature contract"))]
        non_goals = bullets(lines, find_line(lines, r"^### Explicit non-goals"))
        later = bullets(lines, find_line(lines, r"^### Later-stage ideas"))
        comps = []
        for b in bullets(lines, find_line(lines, r"^### Application-specific components")):
            m = re.match(r"^\*\*`([^`]+)`\*\*: (pure domain|renderer-facing|[^;,]+)", b)
            if m:
                comps.append({"file": m.group(1), "role": "domain" if m.group(2).startswith("pure") else
                              "renderer" if m.group(2).startswith("renderer") else m.group(2).strip()})
        d0 = find_line(lines, r"^### Versioned domain schemas")
        types = []
        for l in lines[d0:d0 + 14]:
            m = re.match(r"^\| `([^`]+)` \| `([^`]+)`\.", l)
            if m:
                types.append({"name": m.group(1), "contract": m.group(2)})
        decisions = bullets(lines, find_line(lines, r"^### Algorithm and correctness decisions"))
        stages = [re.sub(r"^\*\*Stage \d+:\*\* ", "", b) for b in bullets(lines, find_line(lines, r"^### App-specific render sequence"))]
        rule = lines[find_line(lines, r"^> \*\*Domain-specific engineering rule:\*\*")]
        rule = rule.split(":**", 1)[1].strip()
        fixtures = [re.sub(r"^Fixture \d+: ", "", b).rstrip(".") for b in bullets(lines, find_line(lines, r"^### Implementation-level fixtures"))]
        p0 = find_line(lines, r"^## 12\. Profiling plan")
        profiling = bullets(lines, next(i for i in range(p0 + 1, p0 + 8) if lines[i].startswith("Before specifying")) + 0)
        risks = [re.sub(r"^\*\*Risk \d+:\*\* ", "", b).replace(RISK_TAIL, "").rstrip(".")
                 for b in bullets(lines, find_line(lines, r"^### App-specific risk register"))]
        need(len(journeys) == 3 and len(feats) == 6 and len(fixtures) == 5 and len(risks) == 3,
             f"{rel}: unexpected list sizes (journeys {len(journeys)}, features {len(feats)}, fixtures {len(fixtures)}, risks {len(risks)})")
        phase_heads = headings(lines, 0, len(lines), r"^### Phase (\d\d) — (.+)$")
        need(len(phase_heads) == 7, f"{rel}: expected 7 phases, found {len(phase_heads)}")
        end_phases = find_line(lines, r"^## 10\. ")
        code = f"A{number:02d}"
        phases = []
        for k, (i, m) in enumerate(phase_heads):
            j = phase_heads[k + 1][0] if k + 1 < len(phase_heads) else end_phases
            block = lines[i:j]
            mvp = next((l.split(":", 1)[1].strip() for l in block if l.startswith("- MVP requirement:")), None)
            fixture = next((l.split(":", 1)[1].strip() for l in block if l.startswith("- Regression fixture:")), None)
            phase = int(m.group(1))
            gate = f"{code}-P{phase:02d}"
            number3 = 10 + (number - 1) * 7 + phase + 1
            phases.append({"phase": phase, "title": m.group(2).strip(), "gate": gate, "mvp_requirement": mvp,
                           "regression_fixture": fixture})
            features.append({
                "id": gate, "kind": "original-app-phase", "experience": code, "title": m.group(2).strip(),
                "spec_number": f"{number3:03d}", "spec_dir": f"specs/{spec_dirs[number3]}" if number3 in spec_dirs else None,
                "source": span(rel, lines, i, j),
                "prompt_source": f"docs/process/speckit-prompt-manifest.json (feature {number3:03d}); "
                                 f"python3 scripts/speckit_prompts.py --feature {number3:03d}",
                "legacy_gate_status": ledger.get(gate, {}).get("status", "pending"),
            })
        passed = [p["gate"] for p in phases if ledger.get(p["gate"], {}).get("status") == "pass"]
        state = "standalone-complete" if len(passed) == 7 else "standalone-partial" if passed else "not-started"
        experiences.append({
            "code": code, "name": name, "slug": slugify(name), "id": f"{code.lower()}.{slugify(name)}",
            "collection": "original", "collection_position": number, "kind": "creative-app",
            "tier": "free", "release": "launch", "family": category, "launcher_category": LAUNCHER_CATEGORY[category],
            "wave": roster[number]["wave"],
            "score": None, "source_candidate": f"AppsBrainstorm catalog item {number}", "legacy_target": target,
            "design": {
                "summary": summary, "brainstorm_concept": quote, "primary_capability": roster[number]["capability"],
                "validity_risk": roster[number]["validity_risk"], "capabilities": caps, "opportunity": opportunity,
                "audiences": audiences, "journeys": journeys, "mvp_features": feats, "non_goals": non_goals,
                "later_ideas": later, "components": comps, "domain_types": types, "algorithm_decisions": decisions,
                "render_stages": stages, "engineering_rule": rule, "fixtures": fixtures, "profiling": profiling,
                "risks": risks, "phases": phases,
            },
            "implementation": {"state": state, "legacy_gates_passed": passed,
                               "legacy_gates_pending": [p["gate"] for p in phases if p["gate"] not in passed],
                               "unified_integration": "pending"},
            "source": span(rel, lines, 0, len(lines) - (1 if lines[-1] == "" else 0)),
        })
    return experiences, features


def parse_foundation(root: Path, ledger: dict) -> list[dict]:
    feats = []
    for p in sorted((root / "specs").glob("0[01][0-9]-*")):
        num = int(p.name[:3])
        if 1 <= num <= 10:
            gate = f"F{num - 1:02d}"
            feats.append({"id": gate, "kind": "foundation-phase", "experience": None, "title": p.name[4:],
                          "spec_number": p.name[:3], "spec_dir": f"specs/{p.name}", "source": None,
                          "prompt_source": f"docs/process/speckit-prompt-manifest.json (feature {p.name[:3]})",
                          "legacy_gate_status": ledger.get(gate, {}).get("status", "pending")})
    need(len(feats) == 10, f"expected 10 foundation features, found {len(feats)}")
    return feats


# --------------------------------------------------------------------------------------------------------------
# Round 2
# --------------------------------------------------------------------------------------------------------------

def one_line_prompts(lines: list[str], lo: int, hi: int) -> dict[str, dict]:
    """Round 2 prompts: a fenced block holding exactly one line `/speckit-<stage> ...`."""
    out: dict[str, dict] = {}
    for i in range(lo, hi - 2):
        if lines[i] == "```text" and lines[i + 2] == "```":
            m = re.match(r"^/speckit-([a-z]+) ", lines[i + 1])
            if m and m.group(1) in STAGES and m.group(1) not in out:
                out[m.group(1)] = [i + 2, i + 2]
    return out


def parse_round2(root: Path) -> tuple[list[dict], list[dict], dict]:
    rel = ARCHIVE / "rounds/round2.md"
    lines = read_lines(root, rel)
    s4, s5, s6, s7 = (find_line(lines, rf"^## {n}\. ") for n in (4, 5, 6, 7))
    # roster
    roster = {}
    for l in lines[s5:s6]:
        m = re.match(r"^\| (\d\d) (.+?) \| (G\d+) \| ([\d.]+) \| (\$[\d.]+) \| (.+?) \| (.+?) \|$", l)
        if m:
            roster[int(m.group(1))] = {"name": m.group(2), "candidate": m.group(3), "score": float(m.group(4)),
                                       "price": m.group(5), "core_action": m.group(6), "hero_graphics": m.group(7)}
    need(len(roster) == 25, f"round 2 roster: expected 25 rows, found {len(roster)}")
    # shared features
    features = []
    dep_rows = {}
    for l in lines[s4:s5]:
        m = re.match(r"^\| `(R2-F\d\d)` \| (.+?) \| (.+?) \| (.+?) \|$", l)
        if m:
            dep_rows[m.group(1)] = {"consumers": m.group(3), "depends_on": m.group(4)}
    heads = headings(lines, s4, s5, r"^#### (R2-F\d\d): (.+)$")
    need(len(heads) == 34 and len(dep_rows) == 34, f"round 2: expected 34 shared features, found {len(heads)}/{len(dep_rows)}")
    stop = find_line(lines, r"^### 4\.3 ", s4)
    for k, (i, m) in enumerate(heads):
        j = heads[k + 1][0] if k + 1 < len(heads) else stop
        fields = bold_fields(lines[i + 1])
        prompts = one_line_prompts(lines, i, j)
        need(list(prompts) == STAGES, f"{m.group(1)}: expected 8 stage prompts, found {list(prompts)}")
        spec_dir = re.search(r"`(specs/[^`]+)`", fields.get("Spec directory", ""))
        features.append({
            "id": m.group(1).replace("R2-", "R02-"), "source_id": m.group(1), "kind": "shared-round-feature",
            "round": 2, "experience": None, "title": m.group(2).strip(),
            "spec_dir_proposed": spec_dir.group(1).rstrip("/") if spec_dir else None,
            "deliverable": fields.get("Deliverable", "").rstrip("."),
            "consumers": dep_rows[m.group(1)]["consumers"], "depends_on": dep_rows[m.group(1)]["depends_on"],
            "source": span(rel, lines, i, j), "prompts": prompts, "prompts_file": rel.as_posix(),
        })
    # games
    gheads = headings(lines, s6, s7, r"^### (\d\d)\. (.+) — fully specified proposed game design$")
    need(len(gheads) == 25, f"round 2: expected 25 games, found {len(gheads)}")
    outline_start = find_line(lines, r"^# VisualCore — Refined Round 2: 25 Complete AssertionOutlines")
    outline_heads = headings(lines, outline_start, len(lines), r"^## (\d\d)\. (.+) — ([\d.]+)/100$")
    outline_end = find_line(lines, r"^## Evidence and interpretation limitations", outline_start)
    experiences = []
    for k, (i, m) in enumerate(gheads):
        j = gheads[k + 1][0] if k + 1 < len(gheads) else s7
        pos = int(m.group(1))
        name = m.group(2).strip()
        need(name == roster[pos]["name"], f"round 2 game {pos}: {name!r} differs from the roster")
        ident = bold_fields(lines[i + 1])
        story = bold_fields(lines[i + 2])
        sections = headings(lines, i, j, r"^#### 6\.\d+\.(\d+)\. (.+)$")
        fields: dict[str, str] = {}
        for l in lines[i + 1:sections[4][0] if len(sections) > 4 else j]:
            for key, value in bold_fields(l).items():
                fields.setdefault(key, value)
        law_line = next(l for l in lines[i:j] if l.startswith("**Simulation domain:**"))
        solver = re.search(r"The reference solver is (.+?)\. \*\*Truth metric", law_line)
        code = f"R02-G{pos:02d}"
        fheads = headings(lines, i, j, r"^##### (R2-G\d\d-(\d\d)): (.+)$")
        need(len(fheads) == 10, f"{code}: expected 10 features, found {len(fheads)}")
        feature_stop = next(s[0] for s in sections if s[0] > fheads[-1][0])
        deps_section = next((s for s in sections if "shared-feature dependencies" in s[1].group(2)), None)
        deps = sorted(set(re.findall(r"R2-F\d\d", "\n".join(lines[deps_section[0]:fheads[0][0]])))) if deps_section else []
        game_features = []
        for q, (fi, fm) in enumerate(fheads):
            fj = fheads[q + 1][0] if q + 1 < len(fheads) else feature_stop
            ff = bold_fields(lines[fi + 1])
            prompts = one_line_prompts(lines, fi, fj)
            need(list(prompts) == STAGES, f"{fm.group(1)}: expected 8 stage prompts, found {list(prompts)}")
            spec_dir = re.search(r"`(specs/[^`]+)`", ff.get("Spec directory", ""))
            fid = f"{code}-{fm.group(2)}"
            game_features.append(fid)
            features.append({
                "id": fid, "source_id": fm.group(1), "kind": "game-feature", "round": 2, "experience": code,
                "title": fm.group(3).strip(), "spec_dir_proposed": spec_dir.group(1).rstrip("/") if spec_dir else None,
                "requirement": ff.get("Functional requirement", "").rstrip("."),
                "source": span(rel, lines, fi, fj), "prompts": prompts, "prompts_file": rel.as_posix(),
            })
        oi, om = outline_heads[pos - 1]
        oj = outline_heads[pos][0] if pos < len(outline_heads) else outline_end
        need(om.group(2).strip() == name, f"{code}: assertion outline {om.group(2)!r} does not match")
        experiences.append({
            "code": code, "name": name, "slug": slugify(name), "id": f"{code.lower()}.{slugify(name)}",
            "collection": "round-02", "collection_position": pos, "kind": "game", "tier": "free", "release": "launch",
            "family": ident["Category"], "launcher_category": "puzzle",
            "score": roster[pos]["score"], "source_candidate": roster[pos]["candidate"],
            "source_rank": int(ident["Comparative rank"].split("/")[0]), "provenance": "original-500",
            "design": {
                "pitch": story.get("Player fantasy", "").rstrip("."), "hero_art": story.get("Signature spectacle", "").rstrip("."),
                "objective": story.get("Objective", "").rstrip("."), "failure": story.get("A failure", "").rstrip("."),
                "victory": story.get("A victory", "").rstrip("."),
                "controls": sentence(fields.get("Controls", "")),
                "core_abstraction": fields.get("Simulation domain", "").rstrip("."),
                "state_model": fields.get("Proposed authoritative law", "").rstrip("."),
                "timestep_seconds": float(ident["Primary timestep"].split()[0]),
                "solver": solver.group(1) if solver else None,
                "truth_metric": sentence(fields.get("Truth metric", "")),
                "geometry": fields.get("Required geometry", "").rstrip("."),
                "signature_shader": fields.get("Signature shader", "").rstrip("."),
                "palette": fields.get("Palette", "").rstrip("."),
                "content_target": ident.get("Content target", ""),
                "roster_core_action": roster[pos]["core_action"], "roster_hero_graphics": roster[pos]["hero_graphics"],
            },
            "shared_feature_dependencies": [d.replace("R2-", "R02-") for d in deps],
            "features": game_features,
            "sections": [{"number": int(sm.group(1)), "title": sm.group(2).strip(), "line_start": si + 1,
                          "line_end": (sections[n + 1][0] if n + 1 < len(sections) else j)}
                         for n, (si, sm) in enumerate(sections)],
            "assertion_outline": span(rel, lines, oi, oj),
            "superseded_source_terms": {"price": roster[pos]["price"], "packaging": "separate paid app"},
            "implementation": {"state": "not-started", "unified_integration": "pending"},
            "source": span(rel, lines, i, j),
        })
    cp = find_line(lines, r"^### 3\.1 Constitution amendment")
    cline = next(i for i in range(cp, cp + 12) if lines[i].startswith("/speckit-constitution"))
    meta = {"round": 2, "file": rel.as_posix(), "sha256": hashlib.sha256((root / rel).read_bytes()).hexdigest(),
            "constitution_prompt": {"line": cline + 1, "sha256": sha(lines[cline])},
            "games": 25, "shared_features": 34}
    return experiences, features, meta


# --------------------------------------------------------------------------------------------------------------
# Rounds 3-12
# --------------------------------------------------------------------------------------------------------------

def block_prompts(lines: list[str], lo: int, hi: int, fid: str) -> dict[str, dict]:
    """Rounds 3-12 prompts: a fenced six-line block whose first line is `/speckit-<stage> — feature <id> — <title>`."""
    out: dict[str, dict] = {}
    i = lo
    while i < hi:
        if lines[i] == "```text" and lines[i + 1].startswith("/speckit-"):
            j = i + 1
            while lines[j] != "```":
                j += 1
            m = re.match(r"^/speckit-([a-z]+) — feature (\S+) — ", lines[i + 1])
            need(bool(m) and m.group(2) == fid, f"{fid}: unexpected prompt header at line {i + 2}")
            out[m.group(1)] = [i + 2, j]
            i = j
        i += 1
    return out


def parse_round(root: Path, n: int) -> tuple[list[dict], list[dict], dict]:
    rel = ARCHIVE / f"rounds/round{n}.md"
    lines = read_lines(root, rel)
    tag = f"R{n:02d}"
    s1, s3, s4, s5, s6, s7 = (find_line(lines, rf"^## {k}\. ") for k in (1, 3, 4, 5, 6, 7))
    roster = {}
    for l in lines[s1:s1 + 40]:
        m = re.match(r"^\| (\d+) \| (\S+) \| (\S+) \| \*\*(.+?)\*\* \| (.+?) \| ([\d.]+) \| (\$[\d.]+) \| (.+?) \|$", l)
        if m:
            roster[int(m.group(1))] = {"source_rank": m.group(2), "candidate": m.group(3), "name": m.group(4),
                                       "family": m.group(5), "score": float(m.group(6)), "price": m.group(7)}
    need(len(roster) == 25, f"round {n} roster: expected 25 rows, found {len(roster)}")
    features = []
    contracts = {}
    for l in lines[s3:s3 + 20]:
        m = re.match(rf"^\| `({tag}-F\d\d)` \| (.+?) \| (.+?) \|$", l)
        if m:
            contracts[m.group(1)] = m.group(2)
    heads = headings(lines, s3, s4, rf"^#### ({tag}-F\d\d)\. (.+)$")
    need(len(heads) == 12 and len(contracts) == 12, f"round {n}: expected 12 shared features, found {len(heads)}/{len(contracts)}")
    stop = find_line(lines, r"^### 3\.2 ", s3)
    for k, (i, m) in enumerate(heads):
        j = heads[k + 1][0] if k + 1 < len(heads) else stop
        prompts = block_prompts(lines, i, j, m.group(1))
        need(list(prompts) == STAGES, f"{m.group(1)}: expected 8 stage prompts, found {list(prompts)}")
        target = re.search(r"active Spec Kit feature directory: (specs/[^/]+)/", lines[prompts["specify"][0]])
        features.append({
            "id": m.group(1), "source_id": m.group(1), "kind": "shared-round-feature", "round": n, "experience": None,
            "title": m.group(2).strip(), "spec_dir_proposed": target.group(1) if target else None,
            "deliverable": contracts[m.group(1)].split(": ", 1)[-1],
            "consumers": "ALL", "depends_on": "previous feature of the round (F12 closes after the device campaign)",
            "source": span(rel, lines, i, j), "prompts": prompts, "prompts_file": rel.as_posix(),
        })
    gheads = headings(lines, s5, s6, rf"^### (\d\d)\. (.+) — complete proposed implementation design \(`({tag}-G\d\d)`\)$")
    need(len(gheads) == 25, f"round {n}: expected 25 games, found {len(gheads)}")
    arg_heads = headings(lines, s6, s7, r"^### Argument (\d\d): (.+)$")
    need(len(arg_heads) == 25, f"round {n}: expected 25 assertion outlines, found {len(arg_heads)}")
    experiences = []
    for k, (i, m) in enumerate(gheads):
        j = gheads[k + 1][0] if k + 1 < len(gheads) else s6
        pos, name, code = int(m.group(1)), m.group(2).strip(), m.group(3)
        need(name == roster[pos]["name"], f"{code}: {name!r} differs from the roster")
        src = re.match(r"^\*\*Source:\*\* `([^`]+)`, source `([^`]+)`, conceptual score \*\*([\d.]+) /100\*\*", lines[i + 1])
        need(bool(src), f"{code}: source line not understood")
        story = bold_fields(lines[i + 2])
        sections = headings(lines, i, j, r"^#### 5\.\d+\.(\d+)\. (.+)$")
        need(len(sections) == 11, f"{code}: expected 11 sections, found {len(sections)}")
        sec = {int(sm.group(1)): (si, sections[q + 1][0] if q + 1 < len(sections) else j) for q, (si, sm) in enumerate(sections)}
        rules: dict[str, str] = {}
        for l in lines[sec[2][0]:sec[2][1]]:
            mm = re.match(r"^- \*\*(.+?):\*\* (.*)$", l)
            if mm:
                rules[mm.group(1)] = mm.group(2)
        touch = next((bold_fields(l).get("Touch") for l in lines[sec[3][0]:sec[3][1]] if l.startswith("**Touch:**")), "")
        render = {}
        for l in lines[sec[4][0]:sec[4][1]]:
            render.update({kk: vv for kk, vv in bold_fields(l).items() if kk not in render})
        golden = re.search(r"Visual replay golden uses seed `([0-9a-f]+)`", render.get("Numeric shader interface", ""))
        fheads = headings(lines, sec[7][0], sec[7][1], rf"^##### ({code}-(\d\d)): (.+)$")
        need(len(fheads) == 10, f"{code}: expected 10 features, found {len(fheads)}")
        game_features = []
        for q, (fi, fm) in enumerate(fheads):
            fj = fheads[q + 1][0] if q + 1 < len(fheads) else sec[7][1]
            prompts = block_prompts(lines, fi, fj, fm.group(1))
            need(list(prompts) == STAGES, f"{fm.group(1)}: expected 8 stage prompts, found {list(prompts)}")
            target = re.search(r"active Spec Kit feature directory: (specs/[^/]+)/", lines[prompts["specify"][0]])
            scope = bold_fields(lines[fi + 1]).get("Scope", "").rstrip(".")
            game_features.append(fm.group(1))
            features.append({
                "id": fm.group(1), "source_id": fm.group(1), "kind": "game-feature", "round": n, "experience": code,
                "title": fm.group(3).strip(), "spec_dir_proposed": target.group(1) if target else None,
                "requirement": scope, "source": span(rel, lines, fi, fj), "prompts": prompts, "prompts_file": rel.as_posix(),
            })
        level_rows = [l for l in lines[sec[8][0]:sec[8][1]] if re.match(r"^\| \d{3} \| `[0-9a-f]+` \|", l)]
        scenario_rows = [l for l in lines[sec[9][0]:sec[9][1]] if re.match(rf"^\| `{code}-S\d{{3}}` \|", l)]
        fault_rows = [l for l in lines[sec[10][0]:sec[10][1]] if re.match(r"^\| `F\d{3}` \|", l)]
        need(len(level_rows) == 100, f"{code}: expected 100 level rows, found {len(level_rows)}")
        ai, am = arg_heads[pos - 1]
        aj = arg_heads[pos][0] if pos < len(arg_heads) else s7
        need(am.group(2).strip() == name, f"{code}: assertion outline {am.group(2)!r} does not match")
        supplemental = not roster[pos]["source_rank"].isdigit() or "upplement" in src.group(2)
        experiences.append({
            "code": code, "name": name, "slug": slugify(name), "id": f"{code.lower()}.{slugify(name)}",
            "collection": f"round-{n:02d}", "collection_position": pos, "kind": "game",
            "tier": "premium" if n in (3, 4) else "premium-backlog", "release": "launch" if n in (3, 4) else "backlog",
            "family": roster[pos]["family"], "launcher_category": "puzzle",
            "score": roster[pos]["score"], "source_candidate": roster[pos]["candidate"],
            "source_rank": int(roster[pos]["source_rank"]) if roster[pos]["source_rank"].isdigit() else roster[pos]["source_rank"],
            "provenance": "supplemental-provisional" if supplemental else "original-500", "score_basis": src.group(2),
            "design": {
                "pitch": story.get("One-sentence pitch", "").rstrip("."),
                "hero_art": story.get("Signature animated environment", "").rstrip("."),
                "core_abstraction": story.get("Core abstraction", "").rstrip("."),
                "state_model": sentence(rules.get("State model", "")),
                "player_action": sentence(rules.get("Player action", "")),
                "win_predicate": sentence(rules.get("Win predicate", "")),
                "failure_predicate": sentence(rules.get("Failure predicate", "")),
                "solver": sentence(rules.get("Solver", "")),
                "numeric_risks": sentence(rules.get("Numeric risks", "")),
                "controls": sentence(touch or ""),
                "geometry": sentence(render.get("Geometry", "")),
                "golden_seed": golden.group(1) if golden else None,
                "content_target": f"{len(level_rows)} planned levels; {len(scenario_rows)} acceptance scenarios; "
                                  f"{len(fault_rows)} fault-injection cases",
            },
            "features": game_features,
            "sections": [{"number": int(sm.group(1)), "title": sm.group(2).strip(), "line_start": si + 1,
                          "line_end": sec[int(sm.group(1))][1]} for si, sm in sections],
            "level_manifest": {"line_start": sec[8][0] + 1, "line_end": sec[8][1], "rows": len(level_rows)},
            "assertion_outline": span(rel, lines, ai, aj),
            "superseded_source_terms": {"price": roster[pos]["price"], "packaging": "separate paid app"},
            "implementation": {"state": "not-started", "unified_integration": "pending"},
            "source": span(rel, lines, i, j),
        })
    cp = find_line(lines, r"^### 3\.0 Constitution amendment")
    cline = next(i for i in range(cp, cp + 8) if lines[i].startswith("/speckit-constitution"))
    meta = {"round": n, "file": rel.as_posix(), "sha256": hashlib.sha256((root / rel).read_bytes()).hexdigest(),
            "constitution_prompt": {"line": cline + 1, "sha256": sha(lines[cline])},
            "games": 25, "shared_features": 12}
    return experiences, features, meta


# --------------------------------------------------------------------------------------------------------------
# Build / verify / print
# --------------------------------------------------------------------------------------------------------------

def generate(root: Path = ROOT) -> tuple[dict, dict]:
    ledger = json.loads((root / LEDGER).read_text(encoding="utf-8"))["stages"]
    experiences, features = parse_original(root, ledger)
    features = parse_foundation(root, ledger) + features
    rounds = []
    e2, f2, m2 = parse_round2(root)
    experiences += e2
    features += f2
    rounds.append(m2)
    for n in range(3, 13):
        en, fn, mn = parse_round(root, n)
        experiences += en
        features += fn
        rounds.append(mn)
    for order, e in enumerate(experiences, 1):
        e["order"] = order
    ids = [e["id"] for e in experiences]
    need(len(set(ids)) == len(ids) == 300, f"expected 300 unique experience ids, found {len(set(ids))}/{len(ids)}")
    need(len({e['slug'] for e in experiences}) == 300, "experience slugs are not unique")
    need(len({e['code'] for e in experiences}) == 300, "experience codes are not unique")
    fids = [f["id"] for f in features]
    need(len(set(fids)) == len(fids), "feature ids are not unique")
    tiers = {t: sum(e["tier"] == t for e in experiences) for t in ("free", "premium", "premium-backlog")}
    need(tiers == {"free": 50, "premium": 50, "premium-backlog": 200}, f"tier allocation is {tiers}")
    kinds: dict[str, int] = {}
    for f in features:
        kinds[f["kind"]] = kinds.get(f["kind"], 0) + 1
    catalog = {
        "schema": 1, "generated_by": "scripts/planning_index.py build",
        "note": "Planning catalog. 'tier' and 'release' are product decisions of ADR-0009; 'implementation' reflects the "
                "legacy ledger at generation time. Nothing here is evidence that an experience is implemented.",
        "counts": {"experiences": len(experiences), **tiers,
                   "launch": sum(e["release"] == "launch" for e in experiences),
                   "backlog": sum(e["release"] == "backlog" for e in experiences)},
        "experiences": experiences,
    }
    index = {
        "schema": 1, "generated_by": "scripts/planning_index.py build",
        "note": "Feature index, one feature per line. 'prompts' maps each Spec Kit stage to the 1-based inclusive line "
                "range of the exact prompt text in 'prompts_file'; the feature's 'source' hash covers its whole section, "
                "prompts included. Features 001-185 keep their prompts in docs/process/speckit-prompt-manifest.json.",
        "counts": {"features": len(features), **kinds,
                   "archived_stage_prompts": sum(len(f.get("prompts", {})) for f in features)},
        "rounds": rounds, "features": features,
    }
    return catalog, index


def dump(value: dict) -> str:
    return json.dumps(value, indent=1, ensure_ascii=False) + "\n"


def dump_index(index: dict) -> str:
    """The feature index with a readable header and one compact feature object per line."""
    head = {k: v for k, v in index.items() if k != "features"}
    text = json.dumps(head, indent=1, ensure_ascii=False)
    rows = ",\n".join("  " + json.dumps(f, ensure_ascii=False, separators=(",", ":")) for f in index["features"])
    return text[:-2] + ',\n "features": [\n' + rows + "\n ]\n}\n"


def build(root: Path = ROOT) -> None:
    catalog, index = generate(root)
    (root / OUT_DIR).mkdir(parents=True, exist_ok=True)
    (root / CATALOG).write_text(dump(catalog), encoding="utf-8")
    (root / FEATURES).write_text(dump_index(index), encoding="utf-8")
    print(f"catalog: {catalog['counts']}")
    print(f"features: {index['counts']}")


def verify(root: Path = ROOT) -> list[str]:
    problems = []
    try:
        catalog, index = generate(root)
    except ParseError as error:
        return [f"archive no longer parses: {error}"]
    for rel, text in ((CATALOG, dump(catalog)), (FEATURES, dump_index(index))):
        path = root / rel
        if not path.is_file():
            problems.append(f"{rel} missing (run planning_index.py build)")
        elif path.read_text(encoding="utf-8") != text:
            problems.append(f"{rel} is out of date with the archive or the ledger (run planning_index.py build)")
    return problems


def load_feature(root: Path, fid: str) -> dict:
    index = json.loads((root / FEATURES).read_text(encoding="utf-8"))
    wanted = fid.upper().replace("R2-", "R02-")
    for f in index["features"]:
        if f["id"] == wanted or f.get("source_id") == fid:
            return f
    raise SystemExit(f"ERROR: unknown feature {fid}")


def prompt_text(root: Path, feature: dict, stage: str) -> str:
    start, end = feature["prompts"][stage]
    lines = read_lines(root, Path(feature["prompts_file"]))
    src = feature["source"]
    if sha("\n".join(lines[src["line_start"] - 1:src["line_end"]])) != src["sha256"]:
        raise SystemExit(f"ERROR: the archived section of {feature['id']} does not match the index hash")
    return "\n".join(lines[start - 1:end])


OVERRIDE_GAME = (
    "Canonical override (ADR-0009, Auto-Creator.md section 21): this game is experience {code} inside the single "
    "VisualCore app. Create no app target, bundle identifier, XcodeGen scheme or per-game store listing; add an "
    "experience module and register it in the catalog. Ignore the source's price, 'no IAP', per-round device "
    "campaign and prior-round device prerequisites: entitlement comes from the shared purchase controller "
    "(tier: {tier}), and physical-device testing happens only after ImplementationLock-100. Use the spec directory "
    "and requirement-ID namespace of Auto-Creator.md section 19. All other requirements of the prompt stand."
)
OVERRIDE_SHARED = (
    "Canonical override (ADR-0009, Auto-Creator.md section 21): implement this shared feature in the existing "
    "VisualCore packages for the single VisualCore app. First check Auto-Creator.md section 13: if an existing module "
    "or a unified-app feature already provides the contract, write the audit and a verified reuse adapter instead of a "
    "duplicate. Ignore prerequisites that demand a completed device campaign of an earlier round; devices are tested "
    "only after ImplementationLock-100. Use the numbering of Auto-Creator.md section 19."
)


OVERRIDE_APP_PHASE = (
    "Canonical override (ADR-0009, Auto-Creator.md section 21): this app is experience {code} inside the single "
    "VisualCore app. Do not create or extend a standalone app target, bundle identifier or store listing. Until "
    "UA-F07 has moved an app, its sources stay where they are; afterwards and for every app not yet started the "
    "sources are the experience modules named in Auto-Creator.md section 16. Store-listing, pricing and per-app "
    "release-dossier parts of Phase 06 are inapplicable; its quality, privacy, accessibility and regression gates "
    "stand. Physical-device tasks are tagged {{device}} and run only after ImplementationLock-100. Feature directory "
    "and ids follow ADR-0004 (specs/{number:03d}-*, FR-{code}-{phase}##, SC-{code}-{phase}##, T-{code}-{phase}##); "
    "evidence is recorded with Tools/python/desktop_runbook.py run-check --stage {gate}. All other requirements of "
    "the prompt stand."
)
UNIFIED_BOUNDARIES = (
    "BOUNDARIES: one app target (VisualCore) and one bundle identifier; experiences never depend on each other; the "
    "OpenGL ES to ANGLE to Metal path is the only renderer and is not forked; External/projectm-ios is read-only and "
    "ProjectM types stay out of the VisualCore public API and out of the app; public Apple APIs only; no advertising, "
    "analytics or tracking code and no network use; pure logic goes in Packages/VisualCore and GPU or UIKit code in "
    "Packages/VisualCoreRendering; every public symbol gets /// documentation and the API baseline is updated; no "
    "physical-device action before ImplementationLock-100; owner-only actions are recorded as BLOCKED_OWNER_ACTION and "
    "never performed."
)
UNIFIED_DISCIPLINE = (
    "DISCIPLINE: work in Claude Desktop Code on branch migration/unified-app-plan (never the Claude CLI, never a push to "
    "main). Reference only APIs verified in the current source; every name marked (new) or proposed in the brief must "
    "be confirmed or corrected against real code and the correction recorded. Never claim device performance from "
    "simulator results. Tick a task only with reproduced evidence in the form '- [X] <id> ... \u2014 Verified YYYY-MM-DD: "
    "<command and result>'. Commit after every task without trailers."
)


def load_briefs(root: Path) -> dict:
    return json.loads((root / BRIEFS).read_text(encoding="utf-8"))


def numbered(items: list[str]) -> str:
    return " ".join(f"({i}) {text}{'' if text.endswith('.') else '.'}" for i, text in enumerate(items, 1)) if items else "none."


def unified_prompts(brief: dict) -> dict[str, str]:
    """The eight copy-ready stage prompts of one unified-app feature, rendered from its brief."""
    fid, ns = brief["id"], brief["namespace"]
    directory = f"specs/{brief['number']}-{brief['slug']}"
    ids = f"requirement ids FR-{ns}-###, success criteria SC-{ns}-###, task ids T-{ns}-###"
    override = f"Canonical override: feature directory {directory}; {ids}"
    check = f"python3 scripts/migration_ledger.py run-check --gate {fid} --name <check-name> -- <command>"
    depends = ", ".join(brief["depends_on"]) or "none"
    absorbed = ("ABSORBED SOURCE REQUIREMENTS: " + "; ".join(brief["absorbs"]) + ". Read each archived feature with "
                "python3 scripts/planning_index.py prompt --feature <ID> --stage specify, and list every unique requirement "
                "in the specification as adopted, adapted or superseded with the reason.\n") if brief["absorbs"] else ""
    return {
        "specify": (
            f"/speckit-specify Feature {fid}: {brief['title']}.\n"
            f"SCOPE: {brief['scope']}\n"
            f"DEPENDS ON: {depends} (each must be pass in the migration ledger before this feature is implemented).\n"
            f"SOURCES TO READ FIRST: {'; '.join(brief['sources'])}.\n"
            f"{absorbed}"
            f"ACCEPTANCE (each item becomes at least one functional requirement and one measurable success criterion): "
            f"{numbered(brief['acceptance'])}\n"
            f"OUT OF SCOPE: {numbered(brief['out_of_scope'])}\n"
            f"DEVICE-ONLY VERIFICATION (tasks tagged {{device}}, run only after ImplementationLock-100): {numbered(brief['device'])}\n"
            f"OWNER-ONLY ITEMS (tasks tagged {{owner}}, never performed by the agent): {numbered(brief['owner'])}\n"
            f"{UNIFIED_BOUNDARIES}\n"
            "Write prioritized user stories that can each be tested alone, acceptance scenarios, and edge cases for failure, "
            "cancellation, lifecycle interruption, memory pressure and corrupted or newer-version data where they apply. "
            "State requirements as observable behavior; name existing modules only where the brief names them.\n"
            f"{override}."
        ),
        "clarify": (
            f"/speckit-clarify Review the {fid} specification for unverified VisualCore or Apple APIs, lifecycle and thread-"
            "ownership assumptions, data-format and migration semantics, performance statements that need a device, and "
            "anything that contradicts ADR-0009 or the Auto-Creator.md sections named in the sources. Ask only questions "
            "whose answer changes the design, at most five.\n"
            f"{override}. Answer every question yourself under the owner's standing delegation, recommended option first, "
            "and record each answer in spec.md under Clarifications."
        ),
        "plan": (
            f"/speckit-plan Create the technical plan for {fid}. Begin with a read-only audit of the existing sources named "
            "in the brief and record it in research.md; reference only APIs the audit verified. Give exact source paths, "
            "each marked existing, new, move or modify; module and dependency direction; public API; lifecycle and thread-"
            "ownership contracts; data schemas with versions and migrations; the tests of each layer (host, package tests "
            "on the iOS 27.x and iOS 26.5 simulators, app UI tests); build and test commands; rollback. Check the plan "
            "against every constitution principle. quickstart.md must contain these evidence commands: "
            f"{'; '.join(brief['evidence'])}. When VisualCore changes: python3 scripts/check_public_api.py --update, "
            "python3 scripts/check_documented_api.py, and the seven-step ProjectM reference regression in two chunks.\n"
            f"{UNIFIED_DISCIPLINE}\n"
            f"{override}. The clarification decisions are binding."
        ),
        "checklist": (
            f"/speckit-checklist Generate the requirements-quality checklist for {fid}: completeness, clarity, consistency, "
            "measurability, lifecycle and failure coverage, privacy and no-advertising constraints, accessibility, the split "
            "between simulator-verifiable and device-only requirements, and traceability to the sources.\n"
            f"{override}. Evaluate every item yourself under the owner's standing delegation, record the evaluation in the "
            "checklist, and correct the specification for every failed item before continuing."
        ),
        "tasks": (
            f"/speckit-tasks Break {fid} into dependency-ordered tasks with exact files, tests written before the code they "
            "prove, an integration acceptance task per user story, commit boundaries and review checkpoints. Include one task "
            "for every evidence command of quickstart.md; the documentation, API-baseline and ProjectM-regression tasks when "
            "VisualCore changes; one task tagged {device} for every device-only item and one tagged {owner} for every "
            "owner-only item; and a final task that runs /speckit-converge until it appends nothing.\n"
            f"{override}. Tasks start at T-{ns}-001. Evidence is recorded with {check}."
        ),
        "analyze": (
            f"/speckit-analyze Validate the {fid} specification, plan and tasks: requirements without tasks, tasks without "
            "requirements, speculative dependencies, missing tests, ambiguous terms, and conflicts with the constitution or "
            "ADR-0009. Stop if a critical finding remains.\n"
            f"{override}. Apply the fixes yourself under the owner's standing delegation, record them in the artifacts, and "
            "run the analysis again until no critical or high finding remains."
        ),
        "implement": (
            f"/speckit-implement Implement {fid} task by task in small verified groups. Run the real builds and tests (host "
            "tests, package tests on the iOS 27.x and iOS 26.5 simulators, app tests where the feature has UI); a task is "
            "never ticked from reading code. Tasks tagged {device} or {owner} stay open, are listed in the final report and "
            "do not block the gate.\n"
            f"{UNIFIED_DISCIPLINE}\n"
            f"{override}. Record each passing command with {check}."
        ),
        "converge": (
            f"/speckit-converge Assess the code against the {fid} specification, plan and tasks and append every remaining gap "
            "as a task. Then run /speckit-implement for the appended tasks and /speckit-converge again; repeat until a run "
            "appends nothing and reports what it checked. Only then seal and record the gate: "
            f"python3 scripts/migration_ledger.py seal --gate {fid} && python3 scripts/migration_ledger.py record --gate {fid}.\n"
            f"{override}. Appended tasks continue the T-{ns}-### sequence."
        ),
    }


def cmd_prompt(args: argparse.Namespace) -> int:
    wanted = args.feature.upper()
    if wanted in ("CONSTITUTION-2", "CONSTITUTION"):
        print("# CONSTITUTION-2 — amend the constitution to 2.0.0 — /speckit-constitution  (docs/catalog/unified-app-features.json)")
        print(load_briefs(ROOT)["constitution_amendment"]["prompt"])
        return 0
    if wanted.startswith("UA-F"):
        brief = next((b for b in load_briefs(ROOT)["features"] if b["id"] == wanted), None)
        if not brief:
            raise SystemExit(f"ERROR: unknown feature {args.feature}")
        prompts = unified_prompts(brief)
        for stage in ([args.stage] if args.stage else STAGES):
            print(f"# {brief['id']} — {brief['title']} — /speckit-{stage}  (docs/catalog/unified-app-features.json)")
            print(prompts[stage])
            print()
        return 0
    feature = load_feature(ROOT, args.feature)
    if "prompts" not in feature:
        print(f"{feature['id']}: prompts are in {feature['prompt_source']}")
        if args.override and feature["kind"] == "original-app-phase":
            code, phase = feature["id"].split("-P")
            print()
            print(OVERRIDE_APP_PHASE.format(code=code, phase=int(phase), number=int(feature["spec_number"]), gate=feature["id"]))
        return 0
    stages = [args.stage] if args.stage else STAGES
    for stage in stages:
        if stage not in feature["prompts"]:
            raise SystemExit(f"ERROR: {feature['id']} has no {stage} prompt")
        print(f"# {feature['id']} — {feature['title']} — /speckit-{stage}  ({feature['prompts_file']}:"
              f"{feature['prompts'][stage][0]})")
        print(prompt_text(ROOT, feature, stage))
        if args.override:
            catalog = json.loads((ROOT / CATALOG).read_text(encoding="utf-8"))
            exp = next((e for e in catalog["experiences"] if e["code"] == feature.get("experience")), None)
            print()
            print(OVERRIDE_GAME.format(code=exp["code"], tier=exp["tier"]) if exp else OVERRIDE_SHARED)
        print()
    return 0


def cmd_levels(args: argparse.Namespace) -> int:
    catalog = json.loads((ROOT / CATALOG).read_text(encoding="utf-8"))
    exp = next((e for e in catalog["experiences"] if e["code"] == args.experience.upper()), None)
    if not exp or "level_manifest" not in exp:
        raise SystemExit(f"ERROR: {args.experience} has no archived level manifest (rounds 3-12 only)")
    lines = read_lines(ROOT, Path(exp["source"]["file"]))
    lm = exp["level_manifest"]
    header = [c.strip() for c in lines[lm["line_start"]].strip("|").split("|")]
    rows = []
    for l in lines[lm["line_start"] - 1:lm["line_end"]]:
        if re.match(r"^\| \d{3} \|", l):
            cells = [c.strip().strip("`") for c in l.strip("|").split(" | ")]
            rows.append(dict(zip(header, cells)))
    print(json.dumps({"experience": exp["code"], "name": exp["name"], "source": exp["source"]["file"], "levels": rows},
                     indent=1, ensure_ascii=False))
    return 0


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("build")
    sub.add_parser("verify")
    p = sub.add_parser("prompt")
    p.add_argument("--feature", required=True)
    p.add_argument("--stage", choices=STAGES)
    p.add_argument("--override", action="store_true")
    l = sub.add_parser("levels")
    l.add_argument("--experience", required=True)
    args = ap.parse_args(argv)
    if args.cmd == "build":
        try:
            build()
        except ParseError as error:
            print("ERROR:", error)
            return 1
        return 0
    if args.cmd == "verify":
        problems = verify()
        for problem in problems:
            print("PROBLEM:", problem)
        print(f"{'PASS' if not problems else 'FAIL'}: planning index, {len(problems)} problems")
        return 1 if problems else 0
    if args.cmd == "prompt":
        return cmd_prompt(args)
    return cmd_levels(args)


if __name__ == "__main__":
    sys.exit(main())
