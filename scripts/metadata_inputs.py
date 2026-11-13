#!/usr/bin/env python3
"""Generate or check the store-metadata inputs (UA-F11 story 7; FR-U11-070..072, data-model §6).

  python3 scripts/metadata_inputs.py --write [--privacy-report F --tracking-report F] [--json F]
  python3 scripts/metadata_inputs.py --check [--privacy-report F --tracking-report F] [--json F]

Output `docs/release/metadata-inputs.json` (schema 1):

  experiences      launch experiences of the catalog whose `X-<code>` gate in the migration ledger is `pass`, in
                   catalog queue order (`order`), each with id, code, name, tier, category (`launcher_category`)
                   and permissions (the registration's optional `permissions` list; absent means []).
                   Pending, failed and absent gates and backlog experiences are never listed.
  ledger_sha256    SHA-256 of the canonical JSON (sorted keys, no spaces) of the sorted list of [id, status] pairs
                   of the ledger's `X-` gates. It is deliberately not the digest of the whole ledger file, so a
                   ledger write that does not change an experience gate does not make the file stale.
  privacy_answers  {"data_collected": "none", "tracking": "no", "proof": {executable_sha256, privacy_report,
                   tracking_report}} only when both reports (check_privacy_manifest and check_no_tracking, data-model
                   §7) say PASS and carry the same non-null executable digest; otherwise the string "unproven".

`--check` compares the file with a fresh generation. Without reports it compares schema, experiences and
ledger_sha256 and requires privacy_answers to be "unproven" or a well-formed proven object (the proof was made by
an earlier `--write` with the reports of a release-check build). With both reports it also compares privacy_answers.
A missing or stale file is a FAIL (exit 1); an unreadable input, a newer schema or only one report is exit 2.

The tool reads only local files: it never reads or writes App Store Connect and never uses the network
(FR-U11-072). The ledger is read only; only scripts/migration_ledger.py writes it.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from report_meta import ROOT, ReportError, meta, read_versioned, write_report  # noqa: E402

CHECK = "metadata-inputs"
SCHEMA = 1
HEX64 = re.compile(r"^[0-9a-f]{64}$")
DEFAULT_LEDGER = ROOT / ".autonomy/migration/ledger.json"
DEFAULT_CATALOG = ROOT / "docs/catalog/experience-catalog.json"
DEFAULT_REGISTRATIONS = ROOT / "Catalog/registrations.json"
DEFAULT_OUT = ROOT / "docs/release/metadata-inputs.json"


def _load(path: Path, what: str) -> dict:
    try:
        data = json.loads(Path(path).read_text())
    except FileNotFoundError as error:
        raise ReportError(f"{path}: {what} missing") from error
    except (OSError, ValueError) as error:
        raise ReportError(f"{path}: {what} not readable JSON ({error})") from error
    if not isinstance(data, dict):
        raise ReportError(f"{path}: {what} is not a JSON object")
    return data


def gate_statuses(ledger: dict, path: Path) -> dict[str, str]:
    """Status of every `X-` gate of the ledger."""
    gates = ledger.get("gates")
    if not isinstance(gates, list):
        raise ReportError(f"{path}: ledger has no gates list")
    return {g["id"]: g.get("status") for g in gates
            if isinstance(g, dict) and isinstance(g.get("id"), str) and g["id"].startswith("X-")}


def ledger_digest(statuses: dict[str, str]) -> str:
    """SHA-256 of the canonical sorted [id, status] list of the experience gates."""
    canonical = json.dumps(sorted([gid, status] for gid, status in statuses.items()), separators=(",", ":"))
    return hashlib.sha256(canonical.encode()).hexdigest()


def experiences(catalog: dict, catalog_path: Path, registrations: dict, statuses: dict[str, str]) -> list[dict]:
    """Launch experiences with a passing `X-<code>` gate, in queue order."""
    items = catalog.get("experiences")
    if not isinstance(items, list):
        raise ReportError(f"{catalog_path}: catalog has no experiences list")
    listed = []
    for item in sorted((e for e in items if isinstance(e, dict) and e.get("release") == "launch"),
                       key=lambda e: e.get("order", 0)):
        if statuses.get(f"X-{item.get('code')}") != "pass":
            continue
        registration = registrations.get(item.get("id")) or {}
        listed.append({"id": item.get("id"), "code": item.get("code"), "name": item.get("name"),
                       "tier": item.get("tier"), "category": item.get("launcher_category"),
                       "permissions": list(registration.get("permissions") or [])})
    return listed


def _display(path: Path) -> str:
    resolved = Path(path).resolve()
    try:
        return resolved.relative_to(ROOT).as_posix()
    except ValueError:
        return str(path)


def privacy_answers(privacy: Path | None, tracking: Path | None) -> str | dict:
    """Proven answers from two passing reports of one executable digest, otherwise "unproven"."""
    if privacy is None or tracking is None:
        return "unproven"
    reports = [read_versioned(privacy), read_versioned(tracking)]
    # Each report must come from the check it stands for (privacy manifest audit, tracking scan).
    if [r.get("check") for r in reports] != ["privacy-manifest", "no-tracking"]:
        return "unproven"
    digests = {(r.get("meta") or {}).get("executable_sha256") for r in reports}
    if any(r.get("verdict") != "PASS" for r in reports) or len(digests) != 1:
        return "unproven"
    digest = digests.pop()
    if not isinstance(digest, str) or not HEX64.match(digest):
        return "unproven"
    return {"data_collected": "none", "tracking": "no",
            "proof": {"executable_sha256": digest, "privacy_report": _display(privacy),
                      "tracking_report": _display(tracking)}}


def generate(args: argparse.Namespace) -> dict:
    ledger = _load(args.ledger, "ledger")
    catalog = _load(args.catalog, "catalog")
    registrations = _load(args.registrations, "registrations").get("registrations")
    if not isinstance(registrations, dict):
        raise ReportError(f"{args.registrations}: registrations has no registrations object")
    statuses = gate_statuses(ledger, args.ledger)
    return {"schema": SCHEMA, "ledger_sha256": ledger_digest(statuses),
            "experiences": experiences(catalog, args.catalog, registrations, statuses),
            "privacy_answers": privacy_answers(args.privacy_report, args.tracking_report)}


def _well_formed(answers) -> bool:
    if answers == "unproven":
        return True
    if not isinstance(answers, dict) or answers.get("data_collected") != "none" or answers.get("tracking") != "no":
        return False
    proof = answers.get("proof")
    return (isinstance(proof, dict) and isinstance(proof.get("executable_sha256"), str)
            and bool(HEX64.match(proof["executable_sha256"]))
            and all(isinstance(proof.get(k), str) and proof[k] for k in ("privacy_report", "tracking_report")))


def check(fresh: dict, out: Path, with_reports: bool) -> list[dict]:
    """Findings of comparing the existing file with a fresh generation."""
    if not Path(out).is_file():
        return [{"file": _display(out), "kind": "missing", "text": "file missing; run --write"}]
    existing = read_versioned(out)
    findings = []
    for key in ("ledger_sha256", "experiences"):
        if existing.get(key) != fresh[key]:
            findings.append({"file": _display(out), "kind": "stale", "text": f"{key} differs from a fresh generation"})
    if not _well_formed(existing.get("privacy_answers")):
        findings.append({"file": _display(out), "kind": "privacy-answers",
                         "text": "privacy_answers is neither \"unproven\" nor a proven object with proof"})
    elif with_reports and existing.get("privacy_answers") != fresh["privacy_answers"]:
        findings.append({"file": _display(out), "kind": "stale",
                         "text": "privacy_answers differs from the given reports"})
    return findings


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--write", action="store_true", help="write the inputs file")
    mode.add_argument("--check", action="store_true", help="fail when the file differs from a fresh generation")
    parser.add_argument("--ledger", type=Path, default=DEFAULT_LEDGER)
    parser.add_argument("--catalog", type=Path, default=DEFAULT_CATALOG)
    parser.add_argument("--registrations", type=Path, default=DEFAULT_REGISTRATIONS)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--privacy-report", type=Path, help="check_privacy_manifest.py --json report")
    parser.add_argument("--tracking-report", type=Path, help="check_no_tracking.py --json report")
    parser.add_argument("--json", type=Path, help="write the check report (data-model §7)")
    args = parser.parse_args(argv)

    if (args.privacy_report is None) != (args.tracking_report is None):
        print("error: --privacy-report and --tracking-report go together", file=sys.stderr)
        print(f"FAIL: {CHECK}: usage")
        return 2
    try:
        fresh = generate(args)
        if args.write:
            write_report(args.out, fresh)
            findings = []
        else:
            findings = check(fresh, args.out, args.privacy_report is not None)
    except ReportError as error:
        print(f"error: {error}", file=sys.stderr)
        print(f"FAIL: {CHECK}: unusable input")
        return 2

    for finding in findings:
        print(f"{finding['file']}: {finding['kind']}: {finding['text']}")
    verdict = "FAIL" if findings else "PASS"
    proven = "proven" if isinstance(fresh["privacy_answers"], dict) else "unproven"
    if args.json:
        write_report(args.json, {"schema": SCHEMA, "check": CHECK, "meta": meta(None, None), "findings": findings,
                                 "experiences": [e["code"] for e in fresh["experiences"]],
                                 "privacy_answers": proven, "verdict": verdict})
    action = "written" if args.write else "checked"
    print(f"{verdict}: {CHECK}: {len(fresh['experiences'])} experiences, privacy answers {proven}, "
          f"{_display(args.out)} {action}")
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
