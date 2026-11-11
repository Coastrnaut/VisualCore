#!/usr/bin/env python3
"""Release-readiness check for any built app (feature 017 T-A01-602; FR-A01-610; shared by all apps, constitution II).

  python3 scripts/check_app_release.py --app Build/.../GenerativeArtStudio.app --config docs/apps/<slug>/release.json

Checks the built bundle against the app's release config: bundle id, version and build, the export-compliance key,
NS*UsageDescription keys (exactly the allowed set), PrivacyInfo.xcprivacy present, a compiled app icon, the required
release documents, and that every row of the release checklist has a known status with evidence or owner steps.
Exit 0 when every item passes, 1 when any fails (one line per item), 2 on bad input.
"""
from __future__ import annotations

import argparse
import json
import plistlib
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
STATUSES = {"verified", "pending-campaign-ii", "owner-action"}


def checklist_problems(text: str) -> list[str]:
    """Rows of the first markdown table with a Status column: each needs a known status and non-empty evidence/steps."""
    problems: list[str] = []
    rows = [line for line in text.splitlines() if line.startswith("|")]
    if len(rows) < 3:
        return ["checklist has no table"]
    header = [c.strip().lower() for c in rows[0].strip("|").split("|")]
    if "status" not in header:
        return ["checklist table has no Status column"]
    si = header.index("status")
    ei = len(header) - 1
    count = 0
    for row in rows[2:]:
        cells = [c.strip() for c in row.strip("|").split("|")]
        if len(cells) != len(header):
            problems.append(f"malformed row: {row[:60]}")
            continue
        count += 1
        status = cells[si].strip("` ").lower()
        if status not in STATUSES:
            problems.append(f"row '{cells[0]} / {cells[1] if len(cells) > 1 else ''}' has unknown status '{cells[si]}'")
        if not cells[ei]:
            problems.append(f"row '{cells[0]} / {cells[1] if len(cells) > 1 else ''}' has no evidence or steps")
    if count == 0:
        problems.append("checklist table has no rows")
    return problems


def check(app: Path, config: dict, root: Path = ROOT) -> list[tuple[str, bool, str]]:
    with open(app / "Info.plist", "rb") as f:
        info = plistlib.load(f)
    results: list[tuple[str, bool, str]] = []

    def item(name: str, ok: bool, detail: str = "") -> None:
        results.append((name, ok, detail))

    item("bundle id", info.get("CFBundleIdentifier") == config["bundleID"], str(info.get("CFBundleIdentifier")))
    item("version", info.get("CFBundleShortVersionString") == config["version"], str(info.get("CFBundleShortVersionString")))
    item("build", str(info.get("CFBundleVersion")) == str(config["build"]), str(info.get("CFBundleVersion")))
    item("export compliance key", "ITSAppUsesNonExemptEncryption" in info, str(info.get("ITSAppUsesNonExemptEncryption")))
    usage = sorted(k for k in info if re.fullmatch(r"NS\w+UsageDescription", k))
    allowed = sorted(config.get("allowedUsageDescriptions", []))
    item("usage descriptions", usage == allowed and all(str(info[k]).strip() for k in usage), f"found {usage}, allowed {allowed}")
    if config.get("privacyManifest", True):
        item("privacy manifest", (app / "PrivacyInfo.xcprivacy").is_file(), "PrivacyInfo.xcprivacy in bundle")
    if config.get("icon", True):
        icons = info.get("CFBundleIcons", {}).get("CFBundlePrimaryIcon", {}) if isinstance(info.get("CFBundleIcons"), dict) else {}
        has_icon = bool(info.get("CFBundleIconName") or icons.get("CFBundleIconName") or icons.get("CFBundleIconFiles"))
        item("app icon", has_icon and (app / "Assets.car").is_file(), "CFBundleIconName/CFBundleIcons + Assets.car")
    for doc in config.get("requiredDocs", []):
        item(f"doc {doc}", (root / doc).is_file(), "")
    checklist = config.get("checklist")
    if checklist:
        path = root / checklist
        problems = checklist_problems(path.read_text()) if path.is_file() else [f"missing {checklist}"]
        item("release checklist", not problems, "; ".join(problems[:5]))
    return results


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--app", type=Path, required=True)
    ap.add_argument("--config", type=Path, required=True)
    ap.add_argument("--root", type=Path, default=ROOT)
    a = ap.parse_args(argv)
    if not (a.app / "Info.plist").is_file() or not a.config.is_file():
        print("ERROR: --app must be a built .app and --config a release.json", file=sys.stderr)
        return 2
    try:
        config = json.loads(a.config.read_text())
        results = check(a.app, config, a.root)
    except (KeyError, ValueError) as e:
        print(f"ERROR: bad config: {e}", file=sys.stderr)
        return 2
    for name, ok, detail in results:
        print(f"  {'ok  ' if ok else 'FAIL'} {name}{': ' + detail if detail and not ok else ''}")
    failed = sum(not ok for _, ok, _ in results)
    print(f"{'PASS' if not failed else 'FAIL'}: {len(results) - failed}/{len(results)} release items")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
