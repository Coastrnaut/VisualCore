#!/usr/bin/env python3
"""Read-only inventory of the owner's D1/D2/D3 devices (F00; README §10). NEVER installs,
launches or tests anything: it only runs `xcrun devicectl list devices --json-output`.

* Raw devicectl output (contains hardware UDIDs, ECIDs, serials) stays private in
  .autonomy/private/ (gitignored).
* A sanitized summary without identifiers goes to docs/verification/devices-observed.json.
* Matching uses hardwareProperties.productType AND hardwareProperties.reality == "physical":
  CoreSimulator devices share product types (e.g. a simulated iPad15,7 exists), and device
  names are not unique.
Exit 1 if a role's device is missing or D3 is no longer iPadOS 26.5 (never upgrade D3).
`--from-json <file>` parses an existing devicectl export instead (tests, dry runs).
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PRIVATE = ROOT / ".autonomy" / "private" / "devices-raw.json"
PUBLIC = ROOT / "docs" / "verification" / "devices-observed.json"
ROLES = {
    "D1": {"product_type": "iPhone15,4", "baseline_os": "27.0.1", "baseline_build": "24A446", "name": "iPhone 15"},
    "D2": {"product_type": "iPad17,3", "baseline_os": "27.2", "baseline_build": "24B119", "name": "iPad Pro 13-inch (M5)"},
    "D3": {"product_type": "iPad15,7", "baseline_os": "26.5", "baseline_build": "23F77", "name": "iPad (A16)"},
}


def physical_devices(raw: dict) -> list[dict]:
    rows = []
    for dev in raw.get("result", {}).get("devices", []):
        hw = dev.get("hardwareProperties", {})
        if hw.get("reality") != "physical":
            continue
        props = dev.get("deviceProperties", {})
        conn = dev.get("connectionProperties", {})
        rows.append({
            "product_type": hw.get("productType"),
            "marketing_name": hw.get("marketingName"),
            "name": props.get("name"),
            "os_version": props.get("osVersionNumber"),
            "os_build": props.get("osBuildUpdate"),
            "developer_mode": props.get("developerModeStatus"),
            "pairing": conn.get("pairingState"),
            "tunnel": conn.get("tunnelState"),
            "_hardware_udid": hw.get("udid"),
            "_devicectl_id": dev.get("identifier"),
        })
    return rows


def classify(rows: list[dict]) -> tuple[dict, list[str]]:
    roles, problems = {}, []
    for role, want in ROLES.items():
        matches = [r for r in rows if r["product_type"] == want["product_type"]]
        if not matches:
            problems.append(f"{role} ({want['product_type']}) not paired with this Mac")
            roles[role] = {"status": "missing", **want}
            continue
        if len(matches) > 1:
            problems.append(f"{role}: {len(matches)} physical {want['product_type']} devices; ambiguous")
        r = matches[0]
        public = {k: v for k, v in r.items() if not k.startswith("_")}
        drift = r["os_version"] != want["baseline_os"]
        if role == "D3" and drift:
            problems.append("D3 is no longer iPadOS 26.5: iOS 26 fallback qualification BLOCKED (never upgrade D3)")
        roles[role] = {"status": "os-drift" if drift else "baseline", "expected": want, "observed": public}
    return roles, problems


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--from-json")
    ap.add_argument("--public", default=str(PUBLIC))
    args = ap.parse_args()
    if args.from_json:
        raw = json.loads(Path(args.from_json).read_text(encoding="utf-8"))
    else:
        PRIVATE.parent.mkdir(parents=True, exist_ok=True)
        proc = subprocess.run(["xcrun", "devicectl", "list", "devices", "--json-output", str(PRIVATE)],
                              capture_output=True, text=True, timeout=180, check=False)
        if proc.returncode != 0:
            print("devicectl failed:", proc.stderr[:400])
            return 1
        raw = json.loads(PRIVATE.read_text(encoding="utf-8"))
    rows = physical_devices(raw)
    roles, problems = classify(rows)
    report = {"observed_at": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
              "note": "Inventory only (F00). No install/launch/test was performed. Hardware UDIDs kept in .autonomy/private.",
              "roles": roles, "other_physical_devices": len(rows) - sum(1 for r in roles.values() if "observed" in r),
              "problems": problems}
    out = Path(args.public)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    for role, r in roles.items():
        o = r.get("observed", {})
        print(f"{role}: {r['status']:9} {o.get('product_type')} {o.get('name')} OS {o.get('os_version')} ({o.get('os_build')}) devmode={o.get('developer_mode')} {o.get('pairing')}/{o.get('tunnel')}")
    print("PASS" if not problems else "PROBLEMS: " + "; ".join(problems))
    return 0 if not problems else 1


if __name__ == "__main__":
    sys.exit(main())
