#!/usr/bin/env python3
"""Build the Spec Kit prompt manifest for all 185 README features (owner instructions 2026-11-10).

For every ledger gate (F00-F09 and A01-P00 ... A25-P06) this extracts the *supplied* prompts verbatim
from the hash-verified archive extracted in .autonomy/context:
  * foundation phases: sources/README.md §10.1-10.11 (``/speckit.x`` → installed ``/speckit-x``);
  * app NN phase P: apps/NN-*.md §9 "Phase 0P" block, plus that manual's ``/speckit-constitution``.
Then it guarantees the full command sequence
  specify → clarify → plan → checklist → tasks → analyze → implement → converge
  → implement (converge-appended tasks and required fixes) → converge (repeat until no new tasks)
filling any command the archive omits with a labelled "supplement" entry (empty or standard prompt),
so that **every feature ends with /speckit-converge and its fixes are implemented**.

Outputs docs/process/speckit-prompt-manifest.json and docs/process/speckit-prompt-manifest.md.
`--feature NNN` prints the ordered commands for one feature. `--check` fails if outputs are stale.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CTX = ROOT / ".autonomy" / "context"
OUT_JSON = ROOT / "docs" / "process" / "speckit-prompt-manifest.json"
OUT_MD = ROOT / "docs" / "process" / "speckit-prompt-manifest.md"
ORDER = ["specify", "clarify", "plan", "checklist", "tasks", "analyze", "implement", "converge"]
FIX_LOOP = [
    {"command": "speckit-implement", "source": "supplement:converge-fix-loop",
     "prompt": "Implement every task that /speckit-converge appended to tasks.md and every required fix it "
               "reported, in small verified groups; run the real builds/tests; tick tasks only with "
               "'— Verified YYYY-MM-DD: <command/result>'."},
    {"command": "speckit-converge", "source": "supplement:converge-fix-loop",
     "prompt": "Re-run convergence after the fixes. Repeat implement → converge until converge appends no new "
               "tasks; only then may the ledger gate be sealed."},
]
FOUNDATION_TITLES = ["Repository integration and baseline audit", "Architecture constitution and integration contracts",
                     "Rendering lifecycle extraction", "Shared GPU resource and shader services",
                     "Reusable effects and render pipelines", "Input, animation, scenes, and procedural graphics",
                     "Standalone VisualCore Showcase application", "ProjectM integration and regression hardening",
                     "Reuse validation with a second consumer", "Stabilization, documentation, and release"]


def split_commands(block: str) -> list[tuple[str, str]]:
    """Split a text block into (command, prompt) pairs; prompts may span lines."""
    out, cur, buf = [], None, []
    for line in block.splitlines():
        m = re.match(r"^/speckit[.-]([a-z]+)\s*(.*)$", line.strip())
        if m:
            if cur:
                out.append((cur, "\n".join(buf).strip()))
            cur, buf = m.group(1), [m.group(2)] if m.group(2) else []
        elif cur is not None:
            buf.append(line)
    if cur:
        out.append((cur, "\n".join(buf).strip()))
    return out


def foundation() -> list[dict]:
    text = (CTX / "sources" / "README.md").read_text(encoding="utf-8")
    sec = text.split("## 10. Initial Claude Code and Spec Kit prompts", 1)[1].split("\n## 11.", 1)[0]
    parts = re.split(r"\n### 10\.(\d+) ", sec)
    by_num = {int(parts[i]): parts[i + 1] for i in range(1, len(parts), 2)}
    constitution = split_commands("\n".join(re.findall(r"```text\n(.*?)```", by_num[1], re.S)))
    features = []
    for phase in range(10):
        body = by_num[phase + 2]
        cmds = split_commands("\n".join(re.findall(r"```text\n(.*?)```", body, re.S)))
        notes = [l.strip() for l in re.sub(r"```.*?```", "", body, flags=re.S).splitlines()
                 if re.search(r"standard|workflow|Implement one|Require|Add a build-time", l)]
        extra = [{"command": "speckit-constitution", "source": "archive:sources/README.md §10.1",
                  "prompt": constitution[0][1]}] if phase == 1 else []
        features.append(build(f"{phase + 1:03d}", f"F{phase:02d}", f"Phase {phase} — {FOUNDATION_TITLES[phase]}",
                              cmds, f"archive:sources/README.md §10.{phase + 2}", notes, extra))
    return features


def apps() -> list[dict]:
    features = []
    for path in sorted((CTX / "apps").glob("[0-9][0-9]-*.md")):
        n = int(path.name[:2])
        text = path.read_text(encoding="utf-8")
        const = [l.strip() for l in text.splitlines() if l.startswith("/speckit-constitution")]
        sec9 = text.split("## 9. Implementation phases", 1)[1].split("\n## 10.", 1)[0]
        phases = re.split(r"\n### Phase (\d{2}) — ([^\n]+)\n", sec9)
        for i in range(1, len(phases), 3):
            p, title, body = int(phases[i]), phases[i + 1].strip(), phases[i + 2]
            cmds = split_commands("\n".join(l for l in body.splitlines() if l.startswith("/speckit")))
            extra = [{"command": "speckit-constitution", "source": f"archive:apps/{path.name} §8",
                      "prompt": split_commands(const[0])[0][1]}] if p == 0 and const else []
            num = f"{10 + (n - 1) * 7 + p + 1:03d}"
            features.append(build(num, f"A{n:02d}-P{p:02d}", f"{path.stem[3:].replace('-', ' ').title()} — Phase {p:02d} {title}",
                                  cmds, f"archive:apps/{path.name} §9 Phase {p:02d}", [], extra))
    return features


def build(num, gate, title, cmds, source, notes, extra) -> dict:
    got = {}
    for c, prompt in cmds:
        got.setdefault(c, []).append(prompt)
    seq = list(extra)
    for c in ORDER:
        prompts = got.get(c)
        if prompts:
            for pr in prompts:
                seq.append({"command": f"speckit-{c}", "source": source, "prompt": pr})
        else:
            seq.append({"command": f"speckit-{c}", "source": "supplement:standard-sequence",
                        "prompt": "" if c in ("tasks", "analyze") else
                        f"(No phase-specific prompt supplied; standard quality workflow per archive.) {' '.join(notes)}".strip()})
    seq += FIX_LOOP
    return {"feature": num, "gate": gate, "title": title, "archive_notes": notes, "commands": seq,
            "supplemented": sorted({s["command"] for s in seq if s["source"].startswith("supplement:standard")})}


def render_md(features: list[dict]) -> str:
    lines = ["# Spec Kit prompt manifest (all 185 README features)", "",
             "Generated by `scripts/speckit_prompts.py` from the hash-verified archive. Owner instructions "
             "2026-11-10: run **every** command with the supplied prompt, for **all** features; every feature "
             "ends with `/speckit-converge`, then implements the converge-appended tasks and required fixes and "
             "converges again until nothing new is appended. `supplement:*` rows fill commands the archive "
             "omits. Do not edit by hand; rerun the script.", "",
             "| Feature | Gate | Title | Supplemented commands |", "|---|---|---|---|"]
    for f in features:
        lines.append(f"| {f['feature']} | {f['gate']} | {f['title']} | {', '.join(f['supplemented']) or '—'} |")
    lines += ["", "Full prompts: `docs/process/speckit-prompt-manifest.json`, or "
              "`python3 scripts/speckit_prompts.py --feature NNN`.", ""]
    return "\n".join(lines)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--feature")
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()
    features = foundation() + apps()
    if len(features) != 185 or len({f["gate"] for f in features}) != 185:
        print(f"ERROR: expected 185 unique features, got {len(features)}")
        return 1
    for f in features:
        if f["commands"][-1]["command"] != "speckit-converge" or not any(
                c["command"] == "speckit-converge" and not c["source"].startswith("supplement:converge") for c in f["commands"]):
            print("ERROR: missing converge in", f["feature"])
            return 1
    if args.feature:
        f = next((x for x in features if x["feature"] == args.feature or x["gate"] == args.feature), None)
        if not f:
            print("unknown feature")
            return 1
        print(f"# {f['feature']} {f['gate']} {f['title']}")
        for i, c in enumerate(f["commands"], 1):
            print(f"\n## {i}. /{c['command']}  [{c['source']}]\n{c['prompt']}")
        return 0
    body_json = json.dumps({"features": features}, indent=2, ensure_ascii=False) + "\n"
    body_md = render_md(features)
    if args.check:
        stale = [p for p, b in ((OUT_JSON, body_json), (OUT_MD, body_md)) if not p.exists() or p.read_text() != b]
        print("stale: " + ", ".join(map(str, stale)) if stale else "manifest up to date")
        return 1 if stale else 0
    OUT_JSON.parent.mkdir(parents=True, exist_ok=True)
    OUT_JSON.write_text(body_json, encoding="utf-8")
    OUT_MD.write_text(body_md, encoding="utf-8")
    sup = sum(1 for f in features if f["supplemented"])
    print(f"185 features; {sup} needed supplements; every feature ends with converge + fix loop")
    return 0


if __name__ == "__main__":
    sys.exit(main())
