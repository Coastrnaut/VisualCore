#!/usr/bin/env python3
"""App isolation check (feature 019 T-A02-115; FR-A02-106, analyze C1; constitution I and A02 "consumer, not fork").

  python3 scripts/check_app_isolation.py --app Apps/FluidArtPlayground [--built-app path/To.app] [--allow-network]

Every app is a VisualCore consumer: its Swift sources must not import the EGL shim or call EGL (only VisualCore's
audited RenderHost owns the context). Unless `--allow-network` is given (an app with a justified networking need),
the sources must not use networking APIs, and a built app must declare no NS*UsageDescription key unless listed with
`--allow-usage`. Comments are ignored. Exit 0 = clean, 1 = violations (one line each), 2 = bad input.
"""
from __future__ import annotations

import argparse
import plistlib
import re
import sys
from pathlib import Path

EGL = [r"\bimport\s+CVisualCoreEGL\b", r"\bimport\s+CVisualCoreGL\b", r"\begl[A-Z]\w*\s*\("]
NETWORK = [r"\bURLSession\b", r"\bNWConnection\b", r"\bNWPathMonitor\b", r"\bimport\s+Network\b", r"\bCFSocket\w*"]


def strip_comments(text: str) -> str:
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    return re.sub(r"//[^\n]*", "", text)


def scan(app: Path, allow_network: bool = False, include_tests: bool = False) -> list[str]:
    patterns = EGL + ([] if allow_network else NETWORK)
    problems = []
    for path in sorted(app.rglob("*.swift")):
        parts = set(path.relative_to(app).parts)
        if "Generated" in parts or (not include_tests and "Tests" in parts):
            continue
        text = strip_comments(path.read_text(encoding="utf-8", errors="replace"))
        for pattern in patterns:
            for m in re.finditer(pattern, text):
                problems.append(f"{path}: {m.group(0).strip()}")
    return problems


def usage_problems(built: Path, allowed: list[str]) -> list[str]:
    with open(built / "Info.plist", "rb") as f:
        info = plistlib.load(f)
    found = sorted(k for k in info if re.fullmatch(r"NS\w+UsageDescription", k))
    return [f"{built.name}: undeclared usage description {k}" for k in found if k not in allowed]


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--app", type=Path, required=True, help="app folder, e.g. Apps/FluidArtPlayground")
    ap.add_argument("--built-app", type=Path)
    ap.add_argument("--allow-network", action="store_true")
    ap.add_argument("--allow-usage", nargs="*", default=[])
    a = ap.parse_args(argv)
    if not a.app.is_dir() or (a.built_app and not (a.built_app / "Info.plist").is_file()):
        print("ERROR: --app must be a folder and --built-app a built .app", file=sys.stderr)
        return 2
    problems = scan(a.app, a.allow_network)
    if a.built_app:
        problems += usage_problems(a.built_app, a.allow_usage)
    for p in problems:
        print(f"  FAIL {p}")
    files = sum(1 for p in a.app.rglob("*.swift") if "Tests" not in p.relative_to(a.app).parts)
    print(f"{'PASS' if not problems else 'FAIL'}: {a.app} — {files} app Swift files, {len(problems)} isolation problems")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
