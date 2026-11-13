#!/usr/bin/env python3
"""Experience package check of the one app (feature UA-F10, T-U10-011; FR-U10-020, FR-U10-021, FR-U10-022; research
R3): every implemented experience lives in the package of its round, with its four targets and its product, and the
app links exactly the implemented experiences.

The implemented set is `Catalog/registrations.json` (schema 1, key `registrations`, experience id -> data). For each
registered id the catalog `docs/catalog/experience-catalog.json` gives the code and the name:

  package  A01..A25 -> ExperiencesCreative, R02-.. -> ExperiencesRound02, R03-.. -> ExperiencesRound03,
           R04-.. -> ExperiencesRound04; any other code is a finding (launch scope)
  Name     the catalog name in UpperCamelCase without spaces or punctuation ("Generative Art Studio" ->
           GenerativeArtStudio)

Rules (one finding line `RULE location: detail` each):
  UNKNOWN_ID       a registered id is not in the catalog
  OUT_OF_SCOPE     a registered code has no launch package
  MISSING_PACKAGE  the package's Package.swift does not exist
  MISSING_TARGET   <Name>Core, <Name>CoreTests, <Name>Experience or <Name>ExperienceTests is not declared
  MISSING_PRODUCT  the library product <Name>Experience is not declared
  NOT_LINKED       the VisualCore target of project.yml does not list the product as a package dependency
  EXTRA_TARGET     a target of an Experiences* package belongs to no registered experience of that package
  EXTRA_LINK       an <X>Experience product linked by the VisualCore target belongs to no registered experience
  EMPTY_PACKAGE    an Experiences* package exists although no registered experience belongs to it

A package of a round without a registered experience may be absent. Package.swift and project.yml are read
textually (no Swift toolchain, no YAML library).

  python3 scripts/check_experience_packages.py
  python3 scripts/check_experience_packages.py --root <fixture root>

Exit codes: 0 pass (prints `PASS: N experiences in M packages`), 1 findings, 2 when an input is missing or damaged
(registrations not JSON or schema not 1, catalog without `experiences`, project.yml without the VisualCore target).
Standard library only.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CATALOG = "docs/catalog/experience-catalog.json"
REGISTRATIONS = "Catalog/registrations.json"
PROJECT = "project.yml"
APP_TARGET = "VisualCore"
SUFFIXES = ("ExperienceTests", "Experience", "CoreTests", "Core")  # longest first for suffix stripping
PACKAGE_PREFIXES = (("R02-", "ExperiencesRound02"), ("R03-", "ExperiencesRound03"), ("R04-", "ExperiencesRound04"))
A_CODE = re.compile(r"^A(0[1-9]|1[0-9]|2[0-5])$")
TARGET_DECL = re.compile(r"\.(target|testTarget)\s*\(\s*name\s*:\s*\"([^\"]+)\"")
PRODUCT_DECL = re.compile(r"\.library\s*\(\s*name\s*:\s*\"([^\"]+)\"")


class InputError(Exception):
    """An input that is missing or damaged (exit 2)."""


def package_for(code: str) -> str | None:
    """The launch package of an experience code, or None when the code is outside the launch scope."""
    if A_CODE.match(code):
        return "ExperiencesCreative"
    for prefix, package in PACKAGE_PREFIXES:
        if code.startswith(prefix):
            return package
    return None


def type_name(name: str) -> str:
    """The catalog name in UpperCamelCase without spaces or punctuation."""
    words = re.split(r"[^A-Za-z0-9]+", name)
    return "".join(w[:1].upper() + w[1:] for w in words if w)


def load_json(path: Path, label: str) -> object:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        raise InputError(f"{label} not found: {path}") from None
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise InputError(f"{label} is damaged: {path}: {exc}") from None


def load_inputs(root: Path) -> tuple[dict[str, dict], list[str]]:
    """The catalog by id and the registered ids, validated."""
    catalog = load_json(root / CATALOG, "catalog")
    if not isinstance(catalog, dict) or not isinstance(catalog.get("experiences"), list):
        raise InputError(f"catalog has no `experiences` list: {root / CATALOG}")
    by_id: dict[str, dict] = {}
    for entry in catalog["experiences"]:
        if isinstance(entry, dict) and isinstance(entry.get("id"), str):
            by_id[entry["id"]] = entry
    regs = load_json(root / REGISTRATIONS, "registrations")
    if not isinstance(regs, dict) or regs.get("schema") != 1:
        raise InputError(f"registrations schema is not 1: {root / REGISTRATIONS}")
    if not isinstance(regs.get("registrations"), dict):
        raise InputError(f"registrations has no `registrations` object: {root / REGISTRATIONS}")
    return by_id, list(regs["registrations"])


def parse_package(path: Path) -> tuple[set[str], set[str]]:
    """The target names and library product names declared in a Package.swift."""
    text = path.read_text(encoding="utf-8")
    text = re.sub(r"//[^\n]*", "", text)
    targets = {m.group(2) for m in TARGET_DECL.finditer(text)}
    products = {m.group(1) for m in PRODUCT_DECL.finditer(text)}
    return targets, products


def app_package_products(root: Path) -> list[tuple[str, str]]:
    """The (package, product) dependencies of the VisualCore target in project.yml."""
    path = root / PROJECT
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except (OSError, UnicodeDecodeError) as exc:
        raise InputError(f"project.yml unreadable: {path}: {exc}") from None
    in_targets = False
    start = None
    for i, line in enumerate(lines):
        if re.match(r"^\S", line):
            in_targets = line.rstrip() == "targets:"
            continue
        if in_targets and line.rstrip() == f"  {APP_TARGET}:":
            start = i + 1
            break
    if start is None:
        raise InputError(f"project.yml has no target {APP_TARGET}: {path}")
    block: list[str] = []
    for line in lines[start:]:
        if re.match(r"^ {0,2}\S", line):
            break
        block.append(line)
    deps: list[tuple[str, str]] = []
    in_deps = False
    package = None
    for line in block:
        if re.match(r"^    \S", line):
            in_deps = line.strip() == "dependencies:"
            continue
        if not in_deps:
            continue
        stripped = line.split("#", 1)[0].strip()
        m = re.match(r"^-\s*package:\s*(\S+)$", stripped)
        if m:
            package = m.group(1)
            continue
        if stripped.startswith("-"):
            package = None
            continue
        m = re.match(r"^product:\s*(\S+)$", stripped)
        if m and package:
            deps.append((package, m.group(1)))
            package = None
    return deps


def check(root: Path) -> tuple[list[str], int, int]:
    """The findings, the number of registered experiences and the number of packages they live in."""
    by_id, registered = load_inputs(root)
    findings: list[str] = []
    names_by_package: dict[str, set[str]] = {}
    expected: list[tuple[str, str, str]] = []  # (id, package, Name)
    for exp_id in registered:
        entry = by_id.get(exp_id)
        if entry is None:
            findings.append(f"UNKNOWN_ID {REGISTRATIONS}: {exp_id} is not in the catalog")
            continue
        code = str(entry.get("code", ""))
        package = package_for(code)
        if package is None:
            findings.append(f"OUT_OF_SCOPE {REGISTRATIONS}: {exp_id} ({code}) has no launch package")
            continue
        name = type_name(str(entry.get("name", "")))
        names_by_package.setdefault(package, set()).add(name)
        expected.append((exp_id, package, name))

    parsed: dict[str, tuple[set[str], set[str]]] = {}
    for manifest in sorted(root.glob("Packages/Experiences*/Package.swift")):
        try:
            parsed[manifest.parent.name] = parse_package(manifest)
        except (OSError, UnicodeDecodeError) as exc:
            raise InputError(f"Package.swift unreadable: {manifest}: {exc}") from None

    links = app_package_products(root)
    linked = {(pkg, prod) for pkg, prod in links if pkg.startswith("Experiences")}

    for exp_id, package, name in expected:
        location = f"Packages/{package}/Package.swift"
        if package not in parsed:
            findings.append(f"MISSING_PACKAGE {location}: {exp_id} needs package {package}")
            continue
        targets, products = parsed[package]
        for suffix in ("Core", "CoreTests", "Experience", "ExperienceTests"):
            if name + suffix not in targets:
                findings.append(f"MISSING_TARGET {location}: {exp_id} has no target {name}{suffix}")
        if name + "Experience" not in products:
            findings.append(f"MISSING_PRODUCT {location}: {exp_id} has no product {name}Experience")
        if (package, name + "Experience") not in linked:
            findings.append(f"NOT_LINKED {PROJECT}: target {APP_TARGET} does not link {package}/{name}Experience "
                            f"({exp_id})")

    for package, (targets, _products) in sorted(parsed.items()):
        location = f"Packages/{package}/Package.swift"
        names = names_by_package.get(package, set())
        if not names:
            findings.append(f"EMPTY_PACKAGE {location}: no registered experience belongs to {package}")
            continue
        for target in sorted(targets):
            base = next((target[: -len(s)] for s in SUFFIXES if target.endswith(s) and len(target) > len(s)), None)
            if base not in names:
                findings.append(f"EXTRA_TARGET {location}: {target} belongs to no registered experience")

    for package, product in sorted(linked):
        if product.endswith("Experience") and product[: -len("Experience")] in names_by_package.get(package, set()):
            continue
        if product.endswith("Experience"):
            findings.append(f"EXTRA_LINK {PROJECT}: target {APP_TARGET} links {package}/{product}, which belongs to "
                            f"no registered experience")
    return findings, len(expected), len(names_by_package)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--root", type=Path, default=ROOT, help="repository root (default: this repository)")
    args = parser.parse_args(argv)
    try:
        findings, count, packages = check(args.root.resolve())
    except InputError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2
    if findings:
        for line in findings:
            print(line)
        return 1
    print(f"PASS: {count} experiences in {packages} packages")
    return 0


if __name__ == "__main__":
    sys.exit(main())
