#!/usr/bin/env python3
"""App VisualCore contract checker (feature 011 T-A01-003; FR-A01-003; contract
specs/011-gas-p00-boundary-audit/contracts/app-contract.md; data model schema 1).

App-neutral: every app's Phase 00 writes docs/apps/<slug>/visualcore-contract.json (inventory, capability matrix, gap
register, traceability, negative rules, decision); this tool verifies that every cited file exists and every cited
symbol is declared there (with `public` when required), that products exist, that gaps cover every non-available row,
and renders the Markdown view.

  python3 scripts/check_app_contract.py --app generative-art-studio [--render] [--root DIR]

Exit 0 PASS, 1 problems, 2 usage/schema error. Standard library only; the JSON is treated as untrusted input.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
STATUSES = ("available", "requires adaptation", "upstream gap")
KINDS = ("adaptation", "upstream")
MAX_ROWS, MAX_STR = 200, 2000
BEGIN, END = "<!-- BEGIN GENERATED -->", "<!-- END GENERATED -->"
KEYS = {
    "top": {"schema", "app", "gate", "date", "inventory", "matrix", "gaps", "traceability", "negative", "decision"},
    "inventory": {"area", "description", "paths", "owner"},
    "matrix": {"id", "capability", "source", "status", "evidence", "example", "notes"},
    "evidence": {"file", "symbol", "product", "public"},
    "example": {"file", "symbol"},
    "gaps": {"id", "matrix", "kind", "owner", "justification", "phase", "test"},
    "traceability": {"item", "matrix", "phases"},
    "negative": {"rule", "source"},
    "decision": {"result", "reasons", "blockers"},
}
DECL = r"\b(?:class|struct|enum|protocol|actor|func|var|let|typealias|case|init|extension)\s+{name}\b"


class SchemaError(Exception):
    pass


def check_keys(obj, kind: str, where: str) -> None:
    if not isinstance(obj, dict):
        raise SchemaError(f"{where}: expected an object")
    unknown = set(obj) - KEYS[kind]
    if unknown:
        raise SchemaError(f"{where}: unknown keys {sorted(unknown)}")
    for k, v in obj.items():
        if isinstance(v, str) and len(v) > MAX_STR:
            raise SchemaError(f"{where}.{k}: string longer than {MAX_STR}")


def load(path: Path) -> dict:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as e:
        raise SchemaError(f"{path}: {e}")
    check_keys(data, "top", "contract")
    if data.get("schema") != 1:
        raise SchemaError("contract: schema must be 1")
    for kind in ("inventory", "matrix", "gaps", "traceability", "negative"):
        rows = data.get(kind, [])
        if not isinstance(rows, list) or len(rows) > MAX_ROWS:
            raise SchemaError(f"{kind}: expected a list of at most {MAX_ROWS} rows")
        for i, row in enumerate(rows):
            check_keys(row, kind, f"{kind}[{i}]")
            if kind == "matrix":
                for j, ev in enumerate(row.get("evidence", [])):
                    check_keys(ev, "evidence", f"matrix[{i}].evidence[{j}]")
                if row.get("example") is not None:
                    check_keys(row["example"], "example", f"matrix[{i}].example")
    check_keys(data.get("decision", {}), "decision", "decision")
    return data


def products(root: Path) -> set[str]:
    """Library products declared in Packages/*/Package.swift (literal names and `name: $0` over string arrays)."""
    found: set[str] = set()
    for manifest in sorted(root.glob("Packages/*/Package.swift")):
        text = manifest.read_text(encoding="utf-8")
        found.update(re.findall(r'\.library\(\s*name:\s*"([^"]+)"', text))
        if re.search(r"\.library\(\s*name:\s*\$0", text):
            for array in re.findall(r"let\s+\w+\s*=\s*\[([^\]]*)\]", text):
                found.update(re.findall(r'"([^"]+)"', array))
    return found


def declared(text: str, name: str, public: bool) -> bool:
    for line in text.splitlines():
        if re.search(DECL.format(name=re.escape(name)), line) and not line.lstrip().startswith("//"):
            if not public or re.search(r"\b(public|open)\b", line) or line.lstrip().startswith("extension"):
                return True
    return False


def symbol_problem(root: Path, file: str, symbol: str, public: bool) -> str | None:
    path = root / file
    if not path.is_file():
        return "file not found"
    text = path.read_text(encoding="utf-8", errors="replace")
    for name in symbol.split("."):
        if not declared(text, name, public):
            return f"symbol {name!r} not declared{' public' if public else ''} in file"
    return None


def evidence_location_problem(file: str) -> str | None:
    parts = Path(file).parts
    if "Tests" in parts or parts[:1] in (("External",), ("Harnesses",)):
        return "evidence must be shippable VisualCore API (not tests, External/ or Harnesses/)"
    return None


def validate(root: Path, data: dict) -> list[str]:
    problems: list[str] = []
    known = products(root)
    rows = {r.get("id"): r for r in data.get("matrix", [])}
    for entry in data.get("inventory", []):
        for path in entry.get("paths", []):
            if not (root / path).exists():
                problems.append(f"inventory {entry.get('area')}: path {path} not found")
    covered = {m for g in data.get("gaps", []) for m in g.get("matrix", [])}
    for row in data.get("matrix", []):
        rid = row.get("id", "?")
        status = row.get("status")
        if status not in STATUSES:
            problems.append(f"{rid}: status {status!r} not one of {STATUSES}")
        evidence = row.get("evidence", [])
        if status != "upstream gap" and not evidence:
            problems.append(f"{rid}: needs at least one evidence item")
        if status == "upstream gap" and not evidence and not row.get("notes"):
            problems.append(f"{rid}: upstream gap needs evidence or notes")
        for ev in evidence:
            cite = f"{ev.get('file')}:{ev.get('symbol')}"
            loc = evidence_location_problem(ev.get("file", ""))
            if loc:
                problems.append(f"{rid}: {cite}: {loc}")
            why = symbol_problem(root, ev.get("file", ""), ev.get("symbol", ""), bool(ev.get("public", True)))
            if why:
                problems.append(f"{rid}: {cite}: {why}")
            if ev.get("product") not in known:
                problems.append(f"{rid}: {cite}: unknown product {ev.get('product')!r}")
        ex = row.get("example")
        if ex:
            why = symbol_problem(root, ex.get("file", ""), ex.get("symbol", ""), False)
            if why:
                problems.append(f"{rid}: example {ex.get('file')}:{ex.get('symbol')}: {why}")
        else:
            problems.append(f"{rid}: needs an example consumer (SC: every row, upstream gaps cite the closest consumer)")
        if status in ("requires adaptation", "upstream gap") and rid not in covered:
            problems.append(f"{rid}: {status} row has no gap entry")
    for gap in data.get("gaps", []):
        gid = gap.get("id", "?")
        if gap.get("kind") not in KINDS:
            problems.append(f"{gid}: kind {gap.get('kind')!r} not one of {KINDS}")
        owner = gap.get("owner", "")
        if not (owner.startswith("VisualCore:") or owner == "app-local"):
            problems.append(f"{gid}: owner must be 'VisualCore:<Module>' or 'app-local'")
        if owner == "app-local" and not gap.get("justification"):
            problems.append(f"{gid}: app-local gap needs a justification")
        if not isinstance(gap.get("phase"), int) or not 1 <= gap["phase"] <= 6:
            problems.append(f"{gid}: phase must be 1-6")
        if not gap.get("test"):
            problems.append(f"{gid}: needs a test intent")
        for m in gap.get("matrix", []):
            if m not in rows:
                problems.append(f"{gid}: references unknown matrix row {m}")
    for t in data.get("traceability", []):
        for m in t.get("matrix", []):
            if m not in rows:
                problems.append(f"traceability {t.get('item')}: unknown matrix row {m}")
    decision = data.get("decision", {})
    if decision.get("result") not in ("go", "stop"):
        problems.append("decision: result must be go or stop")
    if decision.get("result") == "go" and decision.get("blockers"):
        problems.append("decision: go with blockers")
    return problems


def cell(text) -> str:
    if isinstance(text, list):
        text = ", ".join(str(t) for t in text)
    return str(text if text is not None else "").replace("|", "\\|").replace("\n", " ")


def render(data: dict) -> str:
    out = [BEGIN, "", f"_Generated by `scripts/check_app_contract.py --render` from `visualcore-contract.json` "
           f"(gate {data.get('gate')}, {data.get('date')}). Do not edit by hand._", "", "### Inventory", "",
           "| Area | Description | Paths | Owner |", "|---|---|---|---|"]
    out += [f"| {cell(r['area'])} | {cell(r['description'])} | {cell(r.get('paths'))} | {cell(r.get('owner'))} |"
            for r in data.get("inventory", [])]
    out += ["", "### Capability matrix", "", "| ID | Capability | Source | Status | Evidence | Example |",
            "|---|---|---|---|---|---|"]
    for r in data.get("matrix", []):
        ev = "; ".join(f"`{e['symbol']}` ({e['product']}, {e['file']})" for e in r.get("evidence", []))
        ex = f"`{r['example']['symbol']}` ({r['example']['file']})" if r.get("example") else "—"
        out.append(f"| {r['id']} | {cell(r['capability'])} | {cell(r.get('source'))} | **{r['status']}** | "
                   f"{cell(ev) or cell(r.get('notes'))} | {cell(ex)} |")
    out += ["", "### Gap register", "", "| ID | Rows | Kind | Owner | Phase | Test | Justification |",
            "|---|---|---|---|---|---|---|"]
    out += [f"| {g['id']} | {cell(g.get('matrix'))} | {g.get('kind')} | {cell(g.get('owner'))} | {g.get('phase')} | "
            f"{cell(g.get('test'))} | {cell(g.get('justification'))} |" for g in data.get("gaps", [])]
    out += ["", "### Traceability", "", "| Item | Matrix rows | Phases |", "|---|---|---|"]
    out += [f"| {cell(t['item'])} | {cell(t.get('matrix'))} | {cell(t.get('phases'))} |"
            for t in data.get("traceability", [])]
    out += ["", "### Negative requirements", "", "| Rule | Source |", "|---|---|"]
    out += [f"| {cell(n['rule'])} | {cell(n.get('source'))} |" for n in data.get("negative", [])]
    d = data.get("decision", {})
    out += ["", "### Decision", "", f"**{str(d.get('result', '?')).upper()}**", ""]
    out += [f"- {cell(r)}" for r in d.get("reasons", [])]
    out += [f"- Blocker: {cell(b)}" for b in d.get("blockers", [])]
    out += ["", END]
    return "\n".join(out)


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--app", required=True)
    ap.add_argument("--root", type=Path, default=ROOT)
    ap.add_argument("--render", action="store_true")
    a = ap.parse_args(argv)
    if not re.fullmatch(r"[a-z0-9-]+", a.app):
        print("usage error: --app must be a lowercase slug", file=sys.stderr)
        return 2
    base = a.root / "docs" / "apps" / a.app
    try:
        data = load(base / "visualcore-contract.json")
    except SchemaError as e:
        print(f"SCHEMA: {e}", file=sys.stderr)
        return 2
    problems = validate(a.root, data)
    if a.render:
        md = base / "visualcore-contract.md"
        text = md.read_text(encoding="utf-8") if md.is_file() else ""
        if BEGIN not in text or END not in text:
            problems.append(f"{md.relative_to(a.root)}: missing generated-block markers")
        else:
            start, end = text.index(BEGIN), text.index(END) + len(END)
            md.write_text(text[:start] + render(data) + text[end:], encoding="utf-8")
    for p in problems:
        print("PROBLEM:", p)
    cites = sum(len(r.get("evidence", [])) + (1 if r.get("example") else 0) for r in data.get("matrix", []))
    if problems:
        print(f"FAIL: {len(problems)} problem(s)")
        return 1
    print(f"PASS: {len(data.get('matrix', []))} rows, {cites} citations, {len(data.get('gaps', []))} gaps, "
          f"decision {data.get('decision', {}).get('result')}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
