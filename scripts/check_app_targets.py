#!/usr/bin/env python3
"""Check that the project has exactly one shippable application. Standard library only.

Feature UA-F10 (specs/196-ua-f10-build-ci), task T-U10-008, requirements FR-U10-010 and FR-U10-011.

    python3 scripts/check_app_targets.py              # check the repository; exit 0 on pass, 1 on findings
    python3 scripts/check_app_targets.py --root DIR   # check another root (tests)

Inputs, all read-only:

  project.yml                       the application targets (`type: application`) of the top-level `targets:`
                                    mapping and their `settings: base: PRODUCT_BUNDLE_IDENTIFIER`
  Configs/app-targets.json          the declared list (schema 1): name, bundle, ships, reason, until_gate
  .autonomy/migration/ledger.json   the status of every `until_gate`

Rules (one finding line `RULE location: detail` each; any finding exits 1):

  ONE-SHIPPING      exactly one target has `ships: true`
  UNIQUE-NAME       target names are unique
  UNIQUE-BUNDLE     bundle identifiers are unique
  UNDECLARED        every application target of project.yml is listed
  UNKNOWN-TARGET    every listed name is an application target of project.yml
  BUNDLE-MISMATCH   the listed bundle equals the one in project.yml
  SHIPPING-BUNDLE   no non-shipping target uses the shipping bundle
  REASON            a non-shipping target has a non-empty reason
  UNTIL-GATE        an `until_gate` that is pass in the ledger means: remove the target; an unknown gate id fails

A damaged list or ledger, or a list schema other than 1, exits 2 with a message (never a traceback).
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

SCHEMA = 1
LIST_PATH = "Configs/app-targets.json"
PROJECT_PATH = "project.yml"
LEDGER_PATH = ".autonomy/migration/ledger.json"


class Refusal(Exception):
    """An input that cannot be checked at all (exit 2)."""


def _indent(line: str) -> int:
    return len(line) - len(line.lstrip(" "))


def _scalar(value: str) -> str:
    value = value.split(" #", 1)[0].strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
        value = value[1:-1]
    return value


def read_application_targets(text: str) -> dict[str, str | None]:
    """Return {target name: bundle id or None} for every `type: application` target of the top-level `targets:`."""
    lines = [ln.rstrip("\n") for ln in text.splitlines()]
    meaningful = [ln for ln in lines if ln.strip() and not ln.lstrip().startswith("#")]
    targets: dict[str, dict[str, str | None]] = {}
    in_targets = False
    target_indent = None
    current = None
    path: list[tuple[int, str]] = []  # (indent, key) below the current target
    for ln in meaningful:
        ind = _indent(ln)
        stripped = ln.strip()
        if ind == 0:
            in_targets = stripped.split(":", 1)[0] == "targets" and stripped.endswith(":")
            target_indent, current, path = None, None, []
            continue
        if not in_targets:
            continue
        if target_indent is None:
            target_indent = ind
        if ind == target_indent:
            name = stripped.split(":", 1)[0].strip()
            current = name
            targets[name] = {"type": None, "bundle": None}
            path = []
            continue
        if current is None or ind < target_indent or stripped.startswith("-") or ":" not in stripped:
            continue
        key, _, value = stripped.partition(":")
        key = key.strip()
        while path and path[-1][0] >= ind:
            path.pop()
        keys = [k for _, k in path]
        if not keys and key == "type":
            targets[current]["type"] = _scalar(value)
        elif keys == ["settings", "base"] and key == "PRODUCT_BUNDLE_IDENTIFIER":
            targets[current]["bundle"] = _scalar(value) or None
        if not value.strip() or value.strip().startswith("#"):
            path.append((ind, key))
    return {n: t["bundle"] for n, t in targets.items() if t["type"] == "application"}


def _load_json(path: Path, label: str):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        raise Refusal(f"{label} missing: {path}")
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise Refusal(f"{label} damaged: {path}: {exc}")


def _ledger_status(root: Path) -> dict[str, str]:
    data = _load_json(root / LEDGER_PATH, "migration ledger")
    gates = data.get("gates") if isinstance(data, dict) else None
    if not isinstance(gates, list):
        raise Refusal(f"migration ledger damaged: {root / LEDGER_PATH}: no gate list")
    return {g["id"]: str(g.get("status")) for g in gates if isinstance(g, dict) and isinstance(g.get("id"), str)}


def check(root: Path) -> tuple[list[str], str]:
    """Return (findings, pass summary). Raises Refusal for inputs that cannot be checked."""
    listing = _load_json(root / LIST_PATH, "target list")
    if not isinstance(listing, dict) or listing.get("schema") != SCHEMA:
        schema = listing.get("schema") if isinstance(listing, dict) else None
        raise Refusal(f"target list {LIST_PATH}: schema {schema!r} is not {SCHEMA}")
    entries = listing.get("targets")
    if not isinstance(entries, list) or not all(isinstance(e, dict) for e in entries):
        raise Refusal(f"target list damaged: {LIST_PATH}: `targets` must be a list of objects")
    try:
        project_text = (root / PROJECT_PATH).read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        raise Refusal(f"{PROJECT_PATH} unreadable: {exc}")
    apps = read_application_targets(project_text)
    ledger = _ledger_status(root)

    findings: list[str] = []
    shipping = [e for e in entries if e.get("ships") is True]
    if len(shipping) != 1:
        names = ", ".join(str(e.get("name")) for e in shipping) or "none"
        findings.append(f"ONE-SHIPPING {LIST_PATH}: {len(shipping)} targets ship ({names}); exactly one must")
    seen_names: set[str] = set()
    seen_bundles: dict[str, str] = {}
    for e in entries:
        name, bundle = str(e.get("name") or ""), str(e.get("bundle") or "")
        loc = f"{LIST_PATH}#{name or '?'}"
        if name in seen_names:
            findings.append(f"UNIQUE-NAME {loc}: name listed more than once")
        seen_names.add(name)
        if bundle in seen_bundles:
            findings.append(f"UNIQUE-BUNDLE {loc}: bundle {bundle} also used by {seen_bundles[bundle]}")
        else:
            seen_bundles[bundle] = name
        if name not in apps:
            findings.append(f"UNKNOWN-TARGET {loc}: not an application target of {PROJECT_PATH}")
        elif apps[name] != bundle:
            findings.append(f"BUNDLE-MISMATCH {loc}: listed {bundle or '(none)'}, {PROJECT_PATH} has {apps[name]}")
        if e.get("ships") is not True:
            for s in shipping:
                if s.get("bundle") and bundle == s.get("bundle"):
                    findings.append(f"SHIPPING-BUNDLE {loc}: uses the shipping bundle {bundle}")
            if not isinstance(e.get("reason"), str) or not e["reason"].strip():
                findings.append(f"REASON {loc}: a non-shipping target needs a reason")
        gate = e.get("until_gate")
        if gate is not None:
            if gate not in ledger:
                findings.append(f"UNTIL-GATE {loc}: unknown gate {gate}")
            elif ledger[gate] == "pass":
                findings.append(f"UNTIL-GATE {loc}: gate {gate} is pass; remove the target")
    for name in sorted(set(apps) - seen_names):
        findings.append(f"UNDECLARED {PROJECT_PATH}#{name}: application target missing from {LIST_PATH}")

    others = [str(e.get("name")) for e in entries if e.get("ships") is not True]
    ship_name = shipping[0].get("name") if len(shipping) == 1 else "?"
    summary = f"PASS: 1 shippable app ({ship_name}); {len(others)} non-shipping: {', '.join(others) or 'none'}"
    return findings, summary


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args(argv)
    try:
        findings, summary = check(args.root)
    except Refusal as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2
    for f in findings:
        print(f)
    if findings:
        print(f"FAIL: {len(findings)} finding(s)")
        return 1
    print(summary)
    return 0


if __name__ == "__main__":
    sys.exit(main())
