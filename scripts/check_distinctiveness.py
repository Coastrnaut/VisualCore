#!/usr/bin/env python3
"""Distinctiveness matrix of the 100 launch experiences (UA-F11 story 6, FR-U11-060..066; data-model §4, §5).

  check_distinctiveness.py --write   generate docs/legal/distinctiveness-matrix.json and .md from the catalog
  check_distinctiveness.py --check   regenerate in memory, compare both files byte for byte, then apply the rules

Every launch experience is reduced to a triple (core abstraction, player action, win rule) by its design schema
(clarification 2):

  R03-*, R04-*   design.core_abstraction, design.player_action,       design.win_predicate
  R02-*          design.core_abstraction, design.roster_core_action, design.victory
  A01-A25        launcher_category,       design.primary_capability, "open-ended"

Two experiences share a mechanic when their triples are equal ("triple"), when their player actions are equal
("action"), or when the Jaccard similarity of their player-action word sets is at least 0.5 ("score"). Texts are
compared lower case with whitespace collapsed. Words (clarification 3): lower case, runs of [a-z]+ of three or more
letters, the fixed STOP_WORDS removed, a trailing "s" dropped. A shared core abstraction or win rule alone is not a
shared mechanic.

Rows: the six close pairs of the Round 2 source first, in their source order, then every other unordered pair by
score descending, then by code. A failure names the pair and asks for a redesign of the later experience in queue
order (catalog "order") inside its concept (ADR-0009 D-16). The check also fails on a stale matrix (catalog digest),
a matrix that does not cover exactly the launch set, duplicate names or slugs, and a name in
Configs/known-game-titles.json (case-insensitive, whitespace-normalized).

Exit 0 PASS, 1 FAIL, 2 unusable input (missing or unparsable file, newer schema). The last line is PASS or FAIL;
--json writes the check report of data-model §7. Standard library only; deterministic, LF output.
"""
from __future__ import annotations

import argparse
import hashlib
import itertools
import json
import os
import re
import tempfile
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from report_meta import ReportError, meta, read_versioned, write_report  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
CATALOG = ROOT / "docs" / "catalog" / "experience-catalog.json"
TITLES = ROOT / "Configs" / "known-game-titles.json"
MATRIX = ROOT / "docs" / "legal" / "distinctiveness-matrix.json"
SUMMARY = ROOT / "docs" / "legal" / "distinctiveness-matrix.md"

SCHEMA = 1
THRESHOLD = 0.5
MEASURE = "jaccard-player-action-words"
OPEN_ENDED = "open-ended"
CLOSE_PAIRS = (("R02-G01", "R02-G10"), ("R02-G02", "R02-G03"), ("R02-G09", "R02-G14"),
               ("R02-G08", "R02-G24"), ("R02-G17", "R02-G18"), ("R02-G13", "R02-G12"))
TOP = 20

# Fixed English function words; changing this list changes every score and therefore the matrix.
STOP_WORDS = frozenset("""
about above across after against along among and another any are around as at away back because before behind
below beneath between beyond both but can could does down during each either else every for from has have her his
how inside into its itself may more most much must near nor not off once only onto other our out over own per
same should since some such than that the their them then there these they this those though through thru till
toward towards under until upon very via was were what when where whether which while who whose why will with
within without would yet you your
""".split())

WORD = re.compile(r"[a-z]+")
SPACE = re.compile(r"\s+")


def normal_name(text: str) -> str:
    """Case-insensitive, whitespace-normalized form of a name or text."""
    return SPACE.sub(" ", str(text)).strip().casefold()


def _text(entry: dict, value, field: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ReportError(f"catalog: {entry.get('code', '?')} has no text in {field}")
    return SPACE.sub(" ", value).strip()


def normalize_triple(entry: dict) -> dict:
    """The (core abstraction, player action, win rule) triple of one catalog entry, by its schema."""
    code = str(entry.get("code", ""))
    design = entry.get("design") if isinstance(entry.get("design"), dict) else {}
    if code.startswith(("R03-", "R04-")):
        fields = ("design.core_abstraction", "design.player_action", "design.win_predicate")
    elif code.startswith("R02-"):
        fields = ("design.core_abstraction", "design.roster_core_action", "design.victory")
    elif re.fullmatch(r"A\d\d", code):
        fields = ("launcher_category", "design.primary_capability", None)
    else:
        raise ReportError(f"catalog: {code or '?'} has no known design schema")
    values = []
    for field in fields:
        if field is None:
            values.append(OPEN_ENDED)
            continue
        source = design if field.startswith("design.") else entry
        values.append(_text(entry, source.get(field.removeprefix("design.")), field))
    return dict(zip(("core_abstraction", "player_action", "win_rule"), values))


def action_words(text: str) -> frozenset:
    """Normalized word set of a player action (clarification 3)."""
    words = set()
    for word in WORD.findall(str(text).lower()):
        if len(word) < 3 or word in STOP_WORDS:
            continue
        words.add(word[:-1] if word.endswith("s") else word)
    return frozenset(words)


def score(a: str, b: str) -> float:
    """Jaccard similarity of two player actions' word sets, rounded to 4 decimals (0.0 for two empty sets)."""
    wa, wb = action_words(a), action_words(b)
    union = wa | wb
    return round(len(wa & wb) / len(union), 4) if union else 0.0


def compare(ta: dict, tb: dict) -> tuple:
    """(score, verdict, reason) of two triples; reason is None for "distinct"."""
    value = score(ta["player_action"], tb["player_action"])
    if all(normal_name(ta[k]) == normal_name(tb[k]) for k in ("core_abstraction", "player_action", "win_rule")):
        return value, "shares-mechanic", "triple"
    if normal_name(ta["player_action"]) == normal_name(tb["player_action"]):
        return value, "shares-mechanic", "action"
    if value >= THRESHOLD:
        return value, "shares-mechanic", "score"
    return value, "distinct", None


def load_catalog(raw: bytes) -> list:
    """Launch entries of the catalog in queue order."""
    try:
        data = json.loads(raw)
    except ValueError as error:
        raise ReportError(f"catalog: not readable JSON ({error})") from error
    entries = data.get("experiences") if isinstance(data, dict) else None
    if not isinstance(entries, list):
        raise ReportError("catalog: no \"experiences\" list")
    launch = [e for e in entries if isinstance(e, dict) and e.get("release") == "launch"]
    for e in launch:
        if not isinstance(e.get("order"), int) or not isinstance(e.get("code"), str):
            raise ReportError(f"catalog: launch entry {e.get('code', '?')} lacks an integer order or a code")
    return sorted(launch, key=lambda e: (e["order"], e["code"]))


def _row(a: str, b: str, triples: dict) -> list:
    value, verdict, reason = compare(triples[a], triples[b])
    return [a, b, value, verdict] + ([reason] if reason else [])


def _dump(matrix: dict) -> str:
    """Sorted keys, indent 2, one pair or row per line; deterministic and LF."""
    lines = ["{"]
    keys = sorted(matrix)
    for i, key in enumerate(keys):
        comma = "," if i < len(keys) - 1 else ""
        value = matrix[key]
        if key in ("rows", "close_pairs"):
            items = [json.dumps(item, ensure_ascii=False) for item in value]
            body = ",\n".join(f"    {item}" for item in items)
            lines.append(f'  "{key}": [\n{body}\n  ]{comma}' if items else f'  "{key}": []{comma}')
        else:
            text = json.dumps(value, indent=2, sort_keys=True, ensure_ascii=False).replace("\n", "\n  ")
            lines.append(f'  "{key}": {text}{comma}')
    lines.append("}")
    return "\n".join(lines) + "\n"


def _markdown(matrix: dict, names: dict) -> str:
    rows, summary = matrix["rows"], matrix["summary"]

    def line(r):
        return (f"| {r[0]} / {r[1]} | {names[r[0]]} / {names[r[1]]} | {r[2]:.4f} | {r[3]}"
                f"{' (' + r[4] + ')' if len(r) > 4 else ''} |")

    head = ["| Pair | Names | Score | Verdict |", "|---|---|---|---|"]
    shared = [r for r in rows if r[3] == "shares-mechanic"]
    out = ["# Distinctiveness matrix of the launch experiences", "",
           "Generated by `python3 scripts/check_distinctiveness.py --write` from "
           "`docs/catalog/experience-catalog.json`; do not edit by hand (UA-F11, FR-U11-060..066).", "",
           "## Rule", "",
           "Each experience is reduced to (core abstraction, player action, win rule): R03/R04 core abstraction, "
           "player action, win predicate; R02 core abstraction, core action, victory; A01-A25 launcher category, "
           "primary capability, \"open-ended\". Two experiences share a mechanic when their triples are equal, "
           "their player actions are equal, or the Jaccard similarity of their player-action words is at least "
           f"{matrix['threshold']} (lower case, words of three or more letters, stop words dropped from the "
           "comparison, a trailing \"s\" dropped). A shared core abstraction or win rule alone is not a shared "
           "mechanic. A shared mechanic is fixed by redesigning the later experience in queue order inside its "
           "concept (ADR-0009 D-16). The human distinctiveness review is an owner review and does not gate (D-17).",
           "", "## Counts", "",
           f"- Catalog SHA-256: `{matrix['catalog_sha256']}`",
           f"- Launch experiences: {len(matrix['experiences'])}",
           f"- Pairs: {summary['pairs']}",
           f"- Shared mechanics: {summary['shared']}",
           f"- Highest score: {summary['max_score']:.4f}", "",
           "## Close pairs of the Round 2 source", "", *head, *(line(r) for r in rows[:len(CLOSE_PAIRS)]), "",
           f"## Top {TOP} other pairs by score", "", *head, *(line(r) for r in rows[len(CLOSE_PAIRS):][:TOP]), "",
           "## Shared mechanics", ""]
    out += [*head, *(line(r) for r in shared)] if shared else ["None."]
    return "\n".join(out) + "\n"


def generate(raw: bytes) -> tuple:
    """(matrix, matrix JSON text, Markdown summary text) for catalog bytes."""
    launch = load_catalog(raw)
    triples = {e["code"]: normalize_triple(e) for e in launch}
    names = {e["code"]: str(e.get("name", "")) for e in launch}
    for pair in CLOSE_PAIRS:
        for code in pair:
            if code not in triples:
                raise ReportError(f"catalog: close-pair experience {code} is not in the launch set")
    codes = [e["code"] for e in launch]
    close = [list(p) for p in CLOSE_PAIRS]
    close_keys = {frozenset(p) for p in CLOSE_PAIRS}
    rows = [_row(a, b, triples) for a, b in CLOSE_PAIRS]
    rest = [_row(*sorted((a, b)), triples) for a, b in itertools.combinations(codes, 2)
            if frozenset((a, b)) not in close_keys]
    rest.sort(key=lambda r: (-r[2], r[0], r[1]))
    rows += rest
    matrix = {"schema": SCHEMA, "catalog_sha256": hashlib.sha256(raw).hexdigest(), "threshold": THRESHOLD,
              "measure": MEASURE, "experiences": triples, "close_pairs": close, "rows": rows,
              "summary": {"pairs": len(rows), "shared": sum(r[3] == "shares-mechanic" for r in rows),
                          "max_score": max((r[2] for r in rows), default=0.0)}}
    return matrix, _dump(matrix), _markdown(matrix, names)


def rule_findings(raw: bytes, matrix: dict, titles: list, catalog_path: Path) -> list:
    """Shared mechanics, duplicate names and slugs, and known titles."""
    launch = load_catalog(raw)
    order = {e["code"]: e["order"] for e in launch}
    findings = []
    for r in matrix["rows"]:
        if r[3] == "shares-mechanic":
            later = max(r[0], r[1], key=lambda c: (order[c], c))
            findings.append({"file": str(catalog_path), "kind": "shares-mechanic",
                             "text": f"{r[0]}/{r[1]} shares a mechanic ({r[4]}) at score {r[2]}: "
                                     f"redesign {later} inside its concept"})
    known = {normal_name(t) for t in titles}
    for field in ("name", "slug"):
        seen = {}
        for e in launch:
            value = normal_name(e.get(field, ""))
            if not value:
                findings.append({"file": str(catalog_path), "kind": f"missing-{field}",
                                 "text": f"{e['code']} has no {field}"})
                continue
            if value in seen:
                findings.append({"file": str(catalog_path), "kind": f"duplicate-{field}",
                                 "text": f"{seen[value]} and {e['code']} have the same {field} {e.get(field)!r}: "
                                         f"redesign {e['code']} inside its concept"})
            else:
                seen[value] = e["code"]
            if field == "name" and value in known:
                findings.append({"file": str(catalog_path), "kind": "known-title",
                                 "text": f"{e['code']} name {e.get('name')!r} is a known game title: "
                                         f"rename {e['code']} inside its concept"})
    return findings


def coverage_findings(stored: dict, matrix_path: Path, codes: list) -> list:
    """The stored matrix covers exactly the launch set, every unordered pair once."""
    findings = []
    experiences = stored.get("experiences")
    if not isinstance(experiences, dict) or sorted(experiences) != sorted(codes):
        findings.append({"file": str(matrix_path), "kind": "coverage",
                         "text": "experiences differ from the catalog's launch set"})
    rows = stored.get("rows")
    pairs = set()
    if isinstance(rows, list):
        for r in rows:
            if isinstance(r, list) and len(r) >= 2:
                pairs.add(frozenset(r[:2]))
    expected = {frozenset(p) for p in itertools.combinations(codes, 2)}
    if not isinstance(rows, list) or len(rows) != len(expected) or pairs != expected:
        findings.append({"file": str(matrix_path), "kind": "coverage",
                         "text": f"rows do not cover the {len(expected)} launch pairs exactly once"})
    return findings


def _titles(path: Path) -> list:
    data = read_versioned(path)
    titles = data.get("titles")
    if not isinstance(titles, list) or not all(isinstance(t, str) and t.strip() for t in titles):
        raise ReportError(f"{path}: \"titles\" must be a list of non-empty strings")
    return titles


def run(args) -> tuple:
    """(exit code, findings, summary) for parsed arguments."""
    catalog_path, matrix_path, summary_path = Path(args.catalog), Path(args.matrix), Path(args.summary)
    titles = _titles(Path(args.titles))
    try:
        raw = catalog_path.read_bytes()
    except FileNotFoundError as error:
        raise ReportError(f"{catalog_path}: missing") from error
    matrix, text, md = generate(raw)
    findings = []
    if args.write:
        for path, content in ((matrix_path, text), (summary_path, md)):
            write_atomically(path, content)
            print(f"wrote {path}")
    else:
        if not matrix_path.is_file():
            findings.append({"file": str(matrix_path), "kind": "missing",
                             "text": "matrix missing; run check_distinctiveness.py --write"})
        else:
            stored = read_versioned(matrix_path)
            if stored.get("catalog_sha256") != matrix["catalog_sha256"]:
                findings.append({"file": str(matrix_path), "kind": "stale",
                                 "text": "matrix is stale: the catalog changed since it was generated; "
                                         "run check_distinctiveness.py --write"})
            elif matrix_path.read_bytes() != text.encode("utf-8"):
                findings.append({"file": str(matrix_path), "kind": "differs",
                                 "text": "matrix differs from a fresh generation; run --write"})
            findings += coverage_findings(stored, matrix_path, list(matrix["experiences"]))
        if not summary_path.is_file() or summary_path.read_bytes() != md.encode("utf-8"):
            findings.append({"file": str(summary_path), "kind": "differs",
                             "text": "summary missing or differs from a fresh generation; run --write"})
    findings += rule_findings(raw, matrix, titles, catalog_path)
    return (1 if findings else 0), findings, matrix["summary"]


def write_atomically(path: Path, content: str) -> None:
    """Write `content` whole or not at all: a temporary file in the same folder, then a rename (spec edge case
    "Cancellation and interruption"); an interruption keeps the previous file."""
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temp = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(fd, "wb") as handle:
            handle.write(content.encode("utf-8"))
        os.replace(temp, path)
    except BaseException:
        Path(temp).unlink(missing_ok=True)
        raise


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--write", action="store_true", help="generate the matrix and its summary")
    mode.add_argument("--check", action="store_true", help="verify the files and the rules")
    parser.add_argument("--catalog", default=str(CATALOG))
    parser.add_argument("--titles", default=str(TITLES))
    parser.add_argument("--matrix", default=str(MATRIX))
    parser.add_argument("--summary", default=str(SUMMARY))
    parser.add_argument("--json", dest="json_path", help="write the check report (data-model §7)")
    args = parser.parse_args(argv)
    summary = None
    try:
        code, findings, summary = run(args)
    except ReportError as error:
        code, findings = 2, [{"file": "", "kind": "input", "text": str(error)}]
    for f in findings:
        print(f"{f['kind']}: {f['file'] + ': ' if f['file'] else ''}{f['text']}")
    if summary is not None:
        print(f"pairs {summary['pairs']}, shared {summary['shared']}, max score {summary['max_score']}")
    verdict = "PASS" if code == 0 else "FAIL"
    if args.json_path:
        write_report(Path(args.json_path), {"schema": SCHEMA, "check": "distinctiveness", "meta": meta(None, None),
                                            "findings": findings, "summary": summary, "verdict": verdict})
    print(verdict)
    return code


if __name__ == "__main__":
    sys.exit(main())
