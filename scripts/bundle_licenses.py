#!/usr/bin/env python3
"""Bundle the license texts of every shipped component into an app (feature 017 T-A01-610; shared by all apps).

  python3 scripts/bundle_licenses.py --out "$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/Licenses"

Reads `docs/legal/third-party.json` and, for every component with `scope: shipped`, writes `<id>.txt` plus an index
`licenses.json` ([{id, name, license, file}]) that `VisualCoreUI.AcknowledgementsView` displays. Texts are copied
unmodified from their recorded source (ANGLE's are read from the pinned reference, read-only). Components whose source
is the notices page (algorithms re-implemented from published work) get their attribution text generated here.
Exit 0 on success, 1 when a recorded text is missing, 2 on bad input.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

BSD3 = """Redistribution and use in source and binary forms, with or without modification, are permitted provided that the
following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following
   disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following
   disclaimer in the documentation and/or other materials provided with the distribution.
3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote
   products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
"""

# Attribution texts for components re-implemented from published work (recorded in THIRD_PARTY_NOTICES.md).
GENERATED = {
    "easing": "Easing curves in VisualCoreMath are re-derived from Robert Penner's easing equations.\n\n"
              "Easing Equations (c) 2001 Robert Penner. All rights reserved.\n\n" + BSD3,
    "xoshiro": "VisualCoreSimulation.SeededRandom implements xoshiro256** and SplitMix64 from the published algorithms "
               "by David Blackman and Sebastiano Vigna (prng.di.unimi.it), which the authors released to the public "
               "domain. No code was copied.\n",
}


def bundle(inventory: dict, out: Path, root: Path = ROOT) -> list[str]:
    """Writes the texts and the index; returns problems (missing texts)."""
    out.mkdir(parents=True, exist_ok=True)
    index, problems = [], []
    for c in inventory.get("components", []):
        if c.get("scope") != "shipped":
            continue
        cid = c["id"]
        if cid in GENERATED:
            text = GENERATED[cid]
        else:
            src = root / c.get("text", "")
            if not c.get("text") or not src.is_file():
                problems.append(f"missing license text for {cid}: {c.get('text')}")
                continue
            text = src.read_text(errors="replace")
        (out / f"{cid}.txt").write_text(text)
        index.append({"id": cid, "name": c["name"], "license": c["license"], "file": f"{cid}.txt"})
    (out / "licenses.json").write_text(json.dumps(sorted(index, key=lambda e: e["name"].lower()), indent=2) + "\n")
    return problems


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--inventory", type=Path, default=ROOT / "docs/legal/third-party.json")
    ap.add_argument("--root", type=Path, default=ROOT)
    a = ap.parse_args(argv)
    try:
        inventory = json.loads(a.inventory.read_text())
    except (OSError, ValueError) as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 2
    problems = bundle(inventory, a.out, a.root)
    for p in problems:
        print(f"  {p}", file=sys.stderr)
    count = len(json.loads((a.out / "licenses.json").read_text()))
    print(f"{'PASS' if not problems else 'FAIL'}: {count} license texts in {a.out}")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
