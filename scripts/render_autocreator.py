#!/usr/bin/env python3
"""Render the generated blocks of Auto-Creator.md. Deterministic, standard library only; never calls a model.

Auto-Creator.md is a hand-edited book. The parts that are pure data (experience cards, backlog table, shared-feature
map, unified-app feature briefs with their Spec Kit prompts, gate structure, traceability summary, table of contents)
sit between marker lines and are produced here from the tracked data files, so they can never drift from them:

    <!-- GENERATED:BEGIN name -->
    ...
    <!-- GENERATED:END name -->

    python3 scripts/render_autocreator.py           # rewrite every block in place
    python3 scripts/render_autocreator.py --check   # exit 1 if a block is stale or a marker is unknown
    python3 scripts/render_autocreator.py --list    # block names and sizes

Data sources: docs/catalog/experience-catalog.json, docs/catalog/feature-index.json,
docs/catalog/unified-app-features.json, docs/catalog/shared-feature-map.json, .autonomy/migration/ledger.json (gate
structure only, never gate status) and docs/migration/source-to-canonical-matrix.csv. Text outside the markers is
never touched.
"""
from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))
import planning_index  # noqa: E402

DOC = Path("Auto-Creator.md")
CATALOG = Path("docs/catalog/experience-catalog.json")
FEATURES = Path("docs/catalog/feature-index.json")
BRIEFS = Path("docs/catalog/unified-app-features.json")
SHARED = Path("docs/catalog/shared-feature-map.json")
LEDGER = Path(".autonomy/migration/ledger.json")
MATRIX = Path("docs/migration/source-to-canonical-matrix.csv")
BLOCK = re.compile(r"(<!-- GENERATED:BEGIN ([a-z0-9-]+) -->\n)(.*?)(<!-- GENERATED:END \2 -->)", re.S)
FENCE = re.compile(r"^(```|~~~)")


def load(root: Path, rel: Path):
    return json.loads((root / rel).read_text(encoding="utf-8"))


def anchor(heading: str) -> str:
    """GitHub's heading anchor: lower case, punctuation removed, spaces to hyphens."""
    text = re.sub(r"[^\w\- ]", "", heading.strip().lower())
    return text.replace(" ", "-")


def headings(text: str) -> list[tuple[int, str]]:
    """(level, title) of every Markdown heading outside code fences."""
    out, fenced = [], False
    for line in text.split("\n"):
        if FENCE.match(line):
            fenced = not fenced
        elif not fenced:
            m = re.match(r"^(#{1,6}) (.+?)\s*$", line)
            if m:
                out.append((len(m.group(1)), m.group(2)))
    return out


def cell(value) -> str:
    return str(value).replace("|", "\\|").replace("\n", " ").strip()


def joined(items: list[str], numbered: bool = False) -> str:
    items = [str(i).strip().rstrip(".") for i in items if str(i).strip()]
    if numbered:
        return " ".join(f"({n}) {i}." for n, i in enumerate(items, 1))
    return "; ".join(items) + ("." if items else "")


def sentence(value: str) -> str:
    value = str(value).strip()
    return value if value.endswith((".", "!", "?")) else value + "."


def card_title(e: dict) -> str:
    return f"{e['code']} {e['name']}"


def card_link(e: dict) -> str:
    return f"[{e['code']}](#{anchor(card_title(e))})"


# ---------------------------------------------------------------- blocks

def block_toc(ctx) -> str:
    lines = []
    for level, title in headings(ctx["doc"])[1:]:
        if level == 1:
            lines.append(f"- **[{title}](#{anchor(title)})**")
        elif level == 2 and title != "Contents":
            lines.append(f"  - [{title}](#{anchor(title)})")
    return "\n".join(lines)


def block_catalog_summary(ctx) -> str:
    rows = ["| Collection | Codes | Experiences | Kind | Tier | Release | Source document |", "|---|---|---:|---|---|---|---|"]
    groups: dict[str, list[dict]] = {}
    for e in ctx["catalog"]["experiences"]:
        groups.setdefault(e["collection"], []).append(e)
    for name, es in groups.items():
        src = "`docs/archive/planning/embedded/apps/` (25 manuals)" if name == "original" else f"`{es[0]['source']['file']}`"
        rows.append(f"| {name} | {es[0]['code']} … {es[-1]['code']} | {len(es)} | {es[0]['kind']} | {es[0]['tier']} | "
                    f"{es[0]['release']} | {src} |")
    c = ctx["catalog"]["counts"]
    rows.append(f"| **Total** | | **{c['experiences']}** | | {c['free']} free, {c['premium']} premium, "
                f"{c['premium-backlog']} premium backlog | {c['launch']} launch, {c['backlog']} backlog | |")
    return "\n".join(rows)


def block_experience_index(ctx) -> str:
    rows = ["| # | Code | Runtime id | Name | Category | Family | Tier | Integration gate |", "|---:|---|---|---|---|---|---|---|"]
    for e in ctx["catalog"]["experiences"]:
        if e["release"] == "launch":
            rows.append(f"| {e['order']} | {card_link(e)} | `{e['id']}` | {cell(e['name'])} | {e['launcher_category']} | "
                        f"{cell(e['family'])} | {e['tier']} | `X-{e['code']}` |")
    return "\n".join(rows)


def creative_card(e: dict) -> str:
    d = e["design"]
    first = 11 + (e["collection_position"] - 1) * 7
    phases = "; ".join(f"P{p['phase']:02d} {p['title']}" for p in d["phases"])
    types = "; ".join(f"`{t['contract']}`" for t in d["domain_types"])
    components = "; ".join(f"`{c['file']}` ({c['role']})" for c in d["components"])
    src = e["source"]
    lines = [
        f"### {card_title(e)}", "",
        f"`{e['id']}` · {e['tier']} · category {e['launcher_category']} · family {e['family']} · legacy gates "
        f"`{d['phases'][0]['gate']}` … `{d['phases'][-1]['gate']}` (specs {first:03d}–{first + 6:03d}) · integration gate `X-{e['code']}`", "",
        sentence(d["summary"]), "",
        f"- **Primary capability:** {sentence(d['primary_capability'])} **Main validity risk:** {sentence(d['validity_risk'])}",
        f"- **Capabilities:** {joined(d['capabilities'])} **For:** {joined(d['audiences'])}",
        f"- **Journeys:** {joined(d['journeys'], True)}",
        f"- **Required features:** {joined(d['mvp_features'], True)}",
        f"- **Non-goals:** {joined(d['non_goals'])} **Later ideas (not in the first release):** {joined(d['later_ideas'])}",
        f"- **Domain types (proposed contracts):** {types}.",
        f"- **Components named by the manual:** {components}.",
        f"- **Algorithm decisions:** {joined(d['algorithm_decisions'], True)}",
        f"- **Render stages:** {joined(d['render_stages'], True)}",
        f"- **Engineering rule:** {sentence(d['engineering_rule'])}",
        f"- **Regression fixtures (acceptance):** {joined(d['fixtures'], True)}",
        f"- **Profiling:** {joined(d['profiling'])}",
        f"- **Risks:** {joined(d['risks'])}",
        f"- **Phases:** {phases}.",
        f"- **Source:** `{src['file']}` (lines {src['line_start']}–{src['line_end']}). Prompts: "
        f"`python3 scripts/speckit_prompts.py --feature {first:03d}` … `--feature {first + 6:03d}`, each with the override of "
        f"`python3 scripts/planning_index.py prompt --feature {e['code']}-P00 --override`.",
    ]
    return "\n".join(lines)


def ranking(e: dict) -> str:
    rank = e.get("source_rank")
    rank = f"rank {rank}" if isinstance(rank, int) else "supplemental candidate"
    extra = " (provisional score)" if e.get("provenance") == "supplemental-provisional" else ""
    return f"score {e['score']} · {rank} · candidate {e['source_candidate']}{extra}"


def round2_card(e: dict, live: set[str]) -> str:
    d, src, out, lm, qa = e["design"], e["source"], e["assertion_outline"], e["level_manifest"], e["acceptance_scenarios"]
    first = 301 + (e["collection_position"] - 1) * 10
    used = [s for s in e["shared_feature_dependencies"] if s in live]
    lines = [
        f"### {card_title(e)}", "",
        f"`{e['id']}` · {e['tier']} · category {e['launcher_category']} · family {e['family']} · {ranking(e)} · features "
        f"`{e['features'][0]}` … `{e['features'][-1]}` (specs {first}–{first + 9}) · integration gate `X-{e['code']}`", "",
        sentence(d["pitch"]), "",
        f"- **Objective:** {sentence(d['objective'])} **Victory:** {sentence(d['victory'])} **Failure:** {sentence(d['failure'])}",
        f"- **Controls:** {sentence(d['controls'])}",
        f"- **Model:** core abstraction {d['core_abstraction']}; state: {d['state_model']}; fixed step {d['timestep_seconds']} s; "
        f"solver: {d['solver']}; truth metric: {sentence(d['truth_metric'])}",
        f"- **Look (code only):** {d['hero_art']}; geometry: {d['geometry']}; signature shader: {d['signature_shader']}; "
        f"palette: {sentence(d['palette'])}",
        f"- **Content:** {lm['rows']} solver-certified levels: the catalog in lines {lm['line_start']}–{lm['line_end']} is "
        f"canonical (`python3 scripts/planning_index.py levels --experience {e['code']}`); {qa['rows']} acceptance scenarios in "
        f"lines {qa['line_start']}–{qa['line_end']}. The chapter header's earlier figure (\"{d['content_target']}\") and its "
        f"shorter manifests are milestones only.",
        f"- **Shared features used:** {', '.join(used)}; the remaining shared dependencies of the source are delivered by "
        f"unified-app features (section 13).",
        f"- **Source:** `{src['file']}` lines {src['line_start']}–{src['line_end']} ({len(e['sections'])} sections); assertion "
        f"outline lines {out['line_start']}–{out['line_end']}. Prompts: "
        f"`python3 scripts/planning_index.py prompt --feature {e['features'][0]} --override`.",
    ]
    return "\n".join(lines)


def later_card(e: dict) -> str:
    d, src, out, lm = e["design"], e["source"], e["assertion_outline"], e["level_manifest"]
    action = "" if d["player_action"] == d["pitch"] else f" **Player action:** {sentence(d['player_action'])}"
    basis = f" Score basis: {sentence(e['score_basis'])}" if e.get("score_basis") else ""
    directory = f"specs/{e['code'].lower()}-01-* … -10-*"
    lines = [
        f"### {card_title(e)}", "",
        f"`{e['id']}` · {e['tier']} · category {e['launcher_category']} · family {e['family']} · {ranking(e)} · features "
        f"`{e['features'][0]}` … `{e['features'][-1]}` (`{directory}`) · integration gate `X-{e['code']}`", "",
        sentence(d["pitch"]) + action, "",
        f"- **Win:** {sentence(d['win_predicate'])} **Failure:** {sentence(d['failure_predicate'])}",
        f"- **Controls:** {sentence(d['controls'])}",
        f"- **Model:** core abstraction {d['core_abstraction']}; state: {d['state_model']}; solver: {d['solver']}; numeric "
        f"risks: {sentence(d['numeric_risks'])}",
        f"- **Look (code only):** {d['hero_art']}; geometry: {sentence(d['geometry'])}",
        f"- **Content:** {d['content_target']} (levels in lines {lm['line_start']}–{lm['line_end']}, scenarios in lines "
        f"{e['acceptance_scenarios']['line_start']}–{e['acceptance_scenarios']['line_end']}, fault injection in lines "
        f"{e['fault_injection']['line_start']}–{e['fault_injection']['line_end']}); golden seed `{d['golden_seed']}`.{basis}",
        f"- **Source:** `{src['file']}` lines {src['line_start']}–{src['line_end']} ({len(e['sections'])} sections); levels as "
        f"JSON: `python3 scripts/planning_index.py levels --experience {e['code']}`; assertion outline lines "
        f"{out['line_start']}–{out['line_end']}. Prompts: "
        f"`python3 scripts/planning_index.py prompt --feature {e['features'][0]} --override`.",
    ]
    return "\n".join(lines)


def live_shared(ctx, rnd: int) -> set[str]:
    return {g["id"] for g in ctx["ledger"]["gates"]
            if g["kind"] == "shared-round-feature" and g["id"].startswith(f"R{rnd:02d}-") and g["status"] != "superseded"}


def cards(ctx, collection: str) -> str:
    es = [e for e in ctx["catalog"]["experiences"] if e["collection"] == collection]
    if collection == "original":
        return "\n\n".join(creative_card(e) for e in es)
    if collection == "round-02":
        live = live_shared(ctx, 2)
        return "\n\n".join(round2_card(e, live) for e in es)
    return "\n\n".join(later_card(e) for e in es)


def block_backlog(ctx) -> str:
    rows = ["| # | Code | Runtime id | Name | Family | Score | Source rank | Pitch | Source lines |", "|---:|---|---|---|---|---:|---|---|---|"]
    for e in ctx["catalog"]["experiences"]:
        if e["release"] != "backlog":
            continue
        rank = e.get("source_rank")
        rank = str(rank) if isinstance(rank, int) else "supplemental (provisional score)"
        src = e["source"]
        rows.append(f"| {e['order']} | {e['code']} | `{e['id']}` | {cell(e['name'])} | {cell(e['family'])} | {e['score']} | {rank} | "
                    f"{cell(e['design']['pitch'])} | `{Path(src['file']).name}` {src['line_start']}–{src['line_end']} |")
    return "\n".join(rows)


def gate_of(ctx, fid: str) -> str:
    g = next((g for g in ctx["ledger"]["gates"] if g["id"] == fid), None)
    if not g:
        return "added with `add-round`"
    if g["status"] == "superseded":
        return "no gate: superseded by " + ", ".join(g["superseded_by"])
    return f"`{fid}`"


def block_shared_round02(ctx) -> str:
    table = ctx["shared"]["round-02"]
    rows = ["| Feature | Title and deliverable | Consumers | Disposition | Reuses today | New code goes to | Gate | Note |",
            "|---|---|---|---|---|---|---|---|"]
    for f in ctx["index"]["features"]:
        if f["kind"] != "shared-round-feature" or f["round"] != 2:
            continue
        m = table[f["id"].split("-")[1]]
        reuse = ", ".join(f"`{s}`" for s in m["existing"]) or "—"
        rows.append(f"| {f['id']} | **{cell(f['title'])}** — {cell(f['deliverable'])} | {cell(f['consumers'])} | {m['disposition']} | "
                    f"{reuse} | {cell(m['home']) or '—'} | {gate_of(ctx, f['id'])} | {cell(m['note'])} |")
    return "\n".join(rows)


def block_shared_later(ctx) -> str:
    table = ctx["shared"]["rounds-03-12"]
    rows = ["| Feature | Title and deliverable (Round 3 wording) | Disposition | Reuses today | New code goes to | Gates at launch | Note |",
            "|---|---|---|---|---|---|---|"]
    for f in ctx["index"]["features"]:
        if f["kind"] != "shared-round-feature" or f["round"] != 3:
            continue
        key = f["id"].split("-")[1]
        m = table[key]
        reuse = ", ".join(f"`{s}`" for s in m["existing"]) or "—"
        gates = "no gate: superseded" if m["disposition"] == "superseded" else f"`R03-{key}`, `R04-{key}`"
        rows.append(f"| Rnn-{key} | **{cell(f['title'])}** — {cell(f['deliverable'])} | {m['disposition']} | {reuse} | "
                    f"{cell(m['home']) or '—'} | {gates} | {cell(m['note'])} |")
    return "\n".join(rows)


def block_game_features(ctx, rnd: int) -> str:
    rows = ["| # | Feature | Requirement in the source | Reading in the single app |", "|---:|---|---|---|"]
    reading = ctx["game_feature_reading"][2 if rnd == 2 else 3]
    seen = set()
    for f in ctx["index"]["features"]:
        if f["kind"] == "game-feature" and f["round"] == rnd:
            n = int(f["id"].rsplit("-", 1)[1])
            if n not in seen:
                seen.add(n)
                rows.append(f"| {n:02d} | {cell(f['title'])} | {cell(f['requirement'])} | {reading[n]} |")
    return "\n".join(rows)


GAME_FEATURE_READING = {
    2: {1: "unchanged", 2: "unchanged; 100 certified levels", 3: "unchanged", 4: "unchanged",
        5: "unchanged; the game is free, \"premium content\" means complete content",
        6: "unchanged", 7: "storage through the experience context (UA-F05)", 8: "unchanged; goldens are supporting evidence",
        9: "no app target: register the experience and pass its scenario set in the unified app (UA-F09)",
        10: "scenario set and device-row definition only; no device contact before ImplementationLock-100 (UA-F13)"},
    3: {1: "unchanged", 2: "unchanged", 3: "unchanged; 100 levels", 4: "unchanged", 5: "unchanged", 6: "unchanged",
        7: "unchanged",
        8: "storage through the experience context (UA-F05); \"paid completion\" is the shared premium entitlement (UA-F08), never a purchase inside the game",
        9: "one app: the experience compiles in the unified app and passes its scenario set on both simulator runtimes",
        10: "no per-game target or signed build: register the experience, hash its manifests, define its device row (UA-F12, UA-F13)"},
}


def block_unified_features(ctx) -> str:
    out = []
    gates = {g["id"]: g for g in ctx["ledger"]["gates"]}
    for b in ctx["briefs"]["features"]:
        ns, directory = b["namespace"], f"specs/{b['number']}-{b['slug']}"
        depends = [d for d in gates[b["id"]]["depends"]]
        out += [
            f"### {b['id']} {b['title']}", "",
            "| | |", "|---|---|",
            f"| Spec directory | `{directory}` |",
            f"| Ids | `FR-{ns}-###`, `SC-{ns}-###`, `T-{ns}-###` |",
            f"| Ledger gate | `{b['id']}`; depends on {', '.join(f'`{d}`' for d in depends)} |",
            f"| Read first | {cell('; '.join(b['sources']))} |",
            f"| Absorbs | {cell('; '.join(b['absorbs'])) or '—'} |", "",
            f"**Scope.** {b['scope']}", "",
            "**Acceptance.**", "",
        ]
        out += [f"{n}. {sentence(a)}" for n, a in enumerate(b["acceptance"], 1)]
        out += ["", "**Evidence commands.**", ""]
        out += [f"- `{c}`" for c in b["evidence"]]
        out += ["",
                f"**Device-only, after ImplementationLock-100 (`{{device}}` tasks).** {joined(b['device']) or 'None.'}", "",
                f"**Owner-only (`{{owner}}` tasks).** {joined(b['owner']) or 'None.'}", "",
                f"**Out of scope.** {joined(b['out_of_scope'])}", ""]
        prompts = planning_index.unified_prompts(b)
        for stage in planning_index.STAGES:
            out += [f"#### {b['id']} `/speckit-{stage}`", "", "```text", prompts[stage], "```", ""]
    return "\n".join(out).rstrip("\n")


def block_constitution_prompt(ctx) -> str:
    return "```text\n" + ctx["briefs"]["constitution_amendment"]["prompt"] + "\n```"


def block_prompt_catalog(ctx) -> str:
    groups: dict[str, list[dict]] = {}
    for f in ctx["index"]["features"]:
        if f["kind"] == "foundation-phase":
            key = "Foundation phases F00–F09 (sealed)"
        elif f["kind"] == "original-app-phase":
            key = "Original app phases A01-P00 … A25-P06"
        else:
            scope = "Round 2" if f["round"] == 2 else "Rounds 3–4" if f["round"] in (3, 4) else "Rounds 5–12 (backlog)"
            key = f"{scope} {'shared features' if f['kind'] == 'shared-round-feature' else 'game features'}"
        groups.setdefault(key, []).append(f)
    rows = ["| Features | Count | Archived stage prompts | Prompts are in | Print with |", "|---|---:|---:|---|---|"]
    total_features = total_prompts = 0
    for key, fs in groups.items():
        prompts = sum(len(f.get("prompts", {})) for f in fs)
        total_features += len(fs)
        total_prompts += prompts
        if prompts:
            where = "`docs/archive/planning/rounds/`"
            how = "`python3 scripts/planning_index.py prompt --feature <ID> --stage <stage> --override`"
        else:
            where = "`docs/process/speckit-prompt-manifest.json` (extracted from the archive)"
            how = "`python3 scripts/speckit_prompts.py --feature <NNN>`" + (
                "" if "sealed" in key else " plus `python3 scripts/planning_index.py prompt --feature A<nn>-P<p> --override`")
        rows.append(f"| {key} | {len(fs):,} | {prompts:,} | {where} | {how} |" if prompts else
                    f"| {key} | {len(fs):,} | in the manifest | {where} | {how} |")
    briefs = ctx["briefs"]["features"]
    rows.append(f"| Unified-app features UA-F00 … UA-F{len(briefs) - 1:02d} (new) | {len(briefs)} | {len(briefs) * len(planning_index.STAGES)} rendered | "
                "`docs/catalog/unified-app-features.json`, section 20 | `python3 scripts/planning_index.py prompt --feature UA-F<kk>` |")
    rows.append(f"| Constitution prompts of rounds 2–12 | {len(ctx['index']['rounds'])} | superseded | archive | replaced by the amendment of section 19.2 |")
    rows.append(f"| **Archived features in the index** | **{total_features:,}** | **{total_prompts:,}** | | |")
    return "\n".join(rows)


def block_canonical_overrides(ctx) -> str:
    example_game = next(e for e in ctx["catalog"]["experiences"] if e["code"] == "R02-G01")
    parts = [
        "For every game feature (example: a feature of R02-G01):", "", "```text",
        planning_index.OVERRIDE_GAME.format(code=example_game["code"], tier=example_game["tier"]), "```", "",
        "For every shared round feature:", "", "```text", planning_index.OVERRIDE_SHARED, "```", "",
        "For every phase of an original app (example: A05-P01, feature 040):", "", "```text",
        planning_index.OVERRIDE_APP_PHASE.format(code="A05", phase=1, number=40, gate="A05-P01"), "```",
    ]
    return "\n".join(parts)


def block_gate_structure(ctx) -> str:
    gates = ctx["ledger"]["gates"]
    kinds: dict[str, list[str]] = {}
    for g in gates:
        kinds.setdefault(g["kind"], []).append(g["id"])
    rows = ["| Kind | Gates | First … last |", "|---|---:|---|"]
    for kind, ids in kinds.items():
        rows.append(f"| {kind} | {len(ids)} | `{ids[0]}`" + (f" … `{ids[-1]}` |" if len(ids) > 1 else " |"))
    rows.append(f"| **Total** | **{len(gates)}** | |")
    segments: list[list[str]] = []
    previous = None
    for g in gates:
        prefix = re.match(r"^(?:X-)?(R\d\d)|^(DEV\d)-(?!CAMPAIGN)|^(X-A)|^(UA)", g["id"])
        group = next((p for p in prefix.groups() if p), None) if prefix else None
        games = g["kind"] in ("game-feature", "experience") and not g["id"].startswith("X-A")
        key = ("game" if games else g["kind"], group or g["id"])
        if key != previous:
            segments.append([])
            previous = key
        segments[-1].append(g["id"])
    order = ["", "Execution order stored in the ledger (first to last):", ""]
    for n, seg in enumerate(segments, 1):
        order.append(f"{n}. `{seg[0]}`" + (f" … `{seg[-1]}` ({len(seg)} gates)" if len(seg) > 1 else ""))
    return "\n".join(rows + order)


def block_traceability(ctx) -> str:
    path = ctx["root"] / MATRIX
    if not path.is_file():
        return "_The matrix has not been generated yet: run `python3 scripts/build_traceability_matrix.py`._"
    counts: dict[str, dict[str, int]] = {}
    statuses: list[str] = []
    with path.open(encoding="utf-8", newline="") as f:
        for row in csv.DictReader(f):
            counts.setdefault(row["source_kind"], {}).setdefault(row["status"], 0)
            counts[row["source_kind"]][row["status"]] += 1
            if row["status"] not in statuses:
                statuses.append(row["status"])
    order = [s for s in ("implemented-and-verified", "implemented-but-unverified", "planned", "superseded", "blocked", "historical") if s in statuses]
    rows = ["| Source kind | " + " | ".join(order) + " | Rows |", "|---|" + "---:|" * (len(order) + 1)]
    total = {s: 0 for s in order}
    for kind in sorted(counts):
        c = counts[kind]
        rows.append(f"| {kind} | " + " | ".join(str(c.get(s, 0)) for s in order) + f" | {sum(c.values())} |")
        for s in order:
            total[s] += c.get(s, 0)
    rows.append("| **Total** | " + " | ".join(f"**{total[s]}**" for s in order) + f" | **{sum(total.values())}** |")
    return "\n".join(rows)


BLOCKS = {
    "toc": block_toc,
    "catalog-summary": block_catalog_summary,
    "experience-index": block_experience_index,
    "cards-creative": lambda ctx: cards(ctx, "original"),
    "game-features-round02": lambda ctx: block_game_features(ctx, 2),
    "cards-round02": lambda ctx: cards(ctx, "round-02"),
    "game-features-rounds03-12": lambda ctx: block_game_features(ctx, 3),
    "cards-round03": lambda ctx: cards(ctx, "round-03"),
    "cards-round04": lambda ctx: cards(ctx, "round-04"),
    "backlog": block_backlog,
    "shared-round02": block_shared_round02,
    "shared-rounds03-12": block_shared_later,
    "constitution-prompt": block_constitution_prompt,
    "unified-features": block_unified_features,
    "prompt-catalog": block_prompt_catalog,
    "canonical-overrides": block_canonical_overrides,
    "gate-structure": block_gate_structure,
    "traceability-summary": block_traceability,
}


def context(root: Path, doc: str) -> dict:
    return {"root": root, "doc": doc, "catalog": load(root, CATALOG), "index": load(root, FEATURES), "briefs": load(root, BRIEFS),
            "shared": load(root, SHARED), "ledger": load(root, LEDGER), "game_feature_reading": GAME_FEATURE_READING}


def render(root: Path = ROOT) -> tuple[str, str, list[str]]:
    """(current text, rendered text, problems)."""
    current = (root / DOC).read_text(encoding="utf-8")
    problems: list[str] = []
    found = [m.group(2) for m in BLOCK.finditer(current)]
    problems += [f"unknown generated block '{n}'" for n in found if n not in BLOCKS]
    problems += [f"generated block '{n}' occurs {found.count(n)} times" for n in sorted(set(found)) if found.count(n) > 1]
    problems += [f"generated block '{n}' is missing from {DOC}" for n in BLOCKS if n not in found]
    if len(re.findall(r"<!-- GENERATED:(BEGIN|END) ", current)) != 2 * len(found):
        problems.append("unbalanced GENERATED markers")
    text = current
    for _ in range(2):  # the table of contents depends on the headings of the other blocks
        ctx = context(root, text)
        text = BLOCK.sub(lambda m: m.group(1) + (BLOCKS[m.group(2)](ctx) + "\n" if m.group(2) in BLOCKS else m.group(3)) + m.group(4), text)
    return current, text, problems


def main(argv: list[str] | None = None, root: Path = ROOT) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--list", action="store_true")
    args = ap.parse_args(argv)
    current, text, problems = render(root)
    if args.list:
        for m in BLOCK.finditer(text):
            print(f"{m.group(2):28s} {len(m.group(3)):8d} bytes")
        return 0
    for p in problems:
        print("PROBLEM:", p)
    if args.check:
        stale = current != text
        if stale:
            a, b = {m.group(2): m.group(3) for m in BLOCK.finditer(current)}, {m.group(2): m.group(3) for m in BLOCK.finditer(text)}
            for name in b:
                if a.get(name) != b[name]:
                    print(f"PROBLEM: generated block '{name}' is stale: run python3 scripts/render_autocreator.py")
        print(f"{'FAIL' if problems or stale else 'PASS'}: generated blocks of {DOC}")
        return 1 if problems or stale else 0
    if problems:
        return 1
    if current != text:
        (root / DOC).write_text(text, encoding="utf-8")
    print(f"rendered {len(BLOCKS)} blocks into {DOC} ({len(text.encode()):,} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
