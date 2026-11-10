#!/usr/bin/env python3
"""Source hash and requirement-preservation report (T-F004).

Re-verifies the 33 archived sources embedded in README.md (SHA-256 per block), compares them with
the extracted copies in .autonomy/context, and maps each app manual to its ledger gates and
planned spec directory. Writes docs/verification/source-hashes.json. Exit 1 on any mismatch.
"""
from __future__ import annotations

import hashlib
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE = re.compile(r"<!-- SOURCE-BEGIN: ([^\s]+) SHA256=([a-f0-9]{64}) -->\n(.*?)<!-- SOURCE-END: \1 -->", re.S)
OUT = ROOT / "docs" / "verification" / "source-hashes.json"


def main() -> int:
    readme = (ROOT / "README.md").read_text(encoding="utf-8")
    rows, problems = [], []
    for m in SOURCE.finditer(readme):
        name, want, content = m.groups()
        data = content.encode("utf-8")
        got = hashlib.sha256(data).hexdigest()
        extracted = ROOT / ".autonomy" / "context" / name
        ext_ok = extracted.is_file() and extracted.read_bytes() == data
        row = {"source": name, "sha256": want, "bytes": len(data), "embedded_ok": got == want, "extracted_ok": ext_ok}
        am = re.match(r"apps/(\d{2})-(.+)\.md$", name)
        if am:
            n = int(am.group(1))
            row["app"] = {"number": n, "slug": am.group(2),
                          "gates": [f"A{n:02d}-P{p:02d}" for p in range(7)],
                          "spec_feature_numbers": [f"{10 + (n - 1) * 7 + ph + 1:03d}" for ph in range(7)]}
        if got != want:
            problems.append(f"{name}: embedded hash mismatch")
        if not ext_ok:
            problems.append(f"{name}: extracted copy missing or different (run desktop_runbook.py bootstrap)")
        rows.append(row)
    if len(rows) != 33:
        problems.append(f"expected 33 sources, found {len(rows)}")
    apps = [r for r in rows if "app" in r]
    if len(apps) != 25:
        problems.append(f"expected 25 app manuals, found {len(apps)}")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"readme_sha256": hashlib.sha256(readme.encode()).hexdigest(),
                               "sources": rows, "problems": problems}, indent=2) + "\n", encoding="utf-8")
    print(f"{len(rows)} sources, {len(apps)} app manuals; problems: {len(problems)}")
    for p in problems:
        print("PROBLEM:", p)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
