#!/usr/bin/env python3
"""Copy-claim check for store text and interface strings (feature 038 T-A04-615; A04-P06 research D5).

  python3 scripts/check_copy_claims.py [--config Configs/copy-claims-denylist.json] --text FILE... [--swift FILE...]
      [--allow WORD...]

The denylist (schema 1, data-model "Copy denylist") refuses measured claims (`patterns`: numbers with fps, ms, %,
hours or Hz, frame-rate and battery claims; case-insensitive regular expressions), unmeasured quality words and
features the experience does not have (`words`: case-insensitive whole words or phrases).

`--text` files (Markdown or plain text) are scanned line by line. `--swift` files are scanned only inside Swift string
literals, which is the human-facing text: comment lines and trailing `//` comments are ignored, interpolations
`\\(...)` are left out of the surrounding literal (string literals nested in them are scanned on their own), and
literals that are identifiers or commands rather than copy are skipped: arguments of `identifier:` /
`identifier(` / `accessibilityIdentifier(`, `send(` and `systemName:`. A line containing `copy-claims: allow` is
skipped in both kinds of file (for quoted denylist examples in documents).

`--allow` removes denylist `words` that name a feature the experience really has (feature 045 A05-P06: Infinite
Geometry has a camera and shares pictures; the shared denylist was written for Particle Universe, which has neither).
It never removes a measured-claim pattern. The experience's `release.json` lists them in `copyCheck.allow`.

Prints `PROBLEM: <file>:<line>: '<match>' (<reason>)` per hit and `FAIL: copy claims, N problems`, exit 1; otherwise
`PASS: copy claims, N files`, exit 0. Exit 2 on unreadable input.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_CONFIG = ROOT / "Configs" / "copy-claims-denylist.json"
SCHEMA = 1
ALLOW = "copy-claims: allow"
# A literal directly after one of these is an identifier or a command name, not copy.
SKIP_BEFORE = re.compile(r"(identifier\s*[:(]|Identifier\s*\(|send\s*\(|systemName\s*:)\s*$")


def load_rules(config: dict, allow: list[str] | None = None) -> list[tuple[re.Pattern[str], str]]:
    """Compiled (pattern, reason) pairs: the regex patterns first, then each word as a whole-word phrase, except the
    words in `allow` (compared ignoring case)."""
    if config.get("schema") != SCHEMA:
        raise ValueError(f"schema is {config.get('schema')!r}, expected {SCHEMA}")
    rules = [(re.compile(p["regex"], re.IGNORECASE), p["reason"]) for p in config.get("patterns", [])]
    allowed = {a.casefold() for a in (allow or [])}
    for w in config.get("words", []):
        if w["word"].casefold() in allowed:
            continue
        phrase = r"\s+".join(re.escape(part) for part in w["word"].split())
        rules.append((re.compile(rf"(?<![A-Za-z0-9]){phrase}(?![A-Za-z0-9])", re.IGNORECASE), w["reason"]))
    return rules


def hits(text: str, rules: list[tuple[re.Pattern[str], str]]) -> list[tuple[str, str]]:
    """(match, reason) for every rule match in one text."""
    return [(m.group(0), reason) for rx, reason in rules for m in rx.finditer(text)]


def _string(line: str, i: int, out: list[str]) -> int:
    """Parse the literal whose opening quote is at i; append its text (and nested literals) to out; return the end."""
    text: list[str] = []
    nested: list[str] = []
    i += 1
    while i < len(line):
        c = line[i]
        if c == "\\" and i + 1 < len(line):
            if line[i + 1] == "(":
                i, depth = i + 2, 1
                while i < len(line) and depth:
                    if line[i] == '"':
                        i = _string(line, i, nested)
                        continue
                    depth += {"(": 1, ")": -1}.get(line[i], 0)
                    i += 1
                text.append(" ")
                continue
            text.append(line[i + 1])
            i += 2
            continue
        if c == '"':
            i += 1
            break
        text.append(c)
        i += 1
    out.append("".join(text))
    out.extend(nested)
    return i


def swift_literals(line: str) -> list[str]:
    """Human-facing string literal contents of one Swift source line."""
    if line.lstrip().startswith("//"):
        return []
    found: list[str] = []
    i = 0
    while i < len(line):
        if line.startswith("//", i):
            break
        if line[i] == '"':
            if line.startswith('"""', i):          # multi-line literal delimiters carry no text on their own line
                i += 3
                continue
            parts: list[str] = []
            end = _string(line, i, parts)
            if not SKIP_BEFORE.search(line[:i]):
                found.extend(parts)
            i = end
            continue
        i += 1
    return found


def scan(path: Path, swift: bool, rules: list[tuple[re.Pattern[str], str]]) -> list[str]:
    """PROBLEM texts for one file."""
    problems: list[str] = []
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if ALLOW in line:
            continue
        texts = swift_literals(line) if swift else [line]
        for text in texts:
            for match, reason in hits(text, rules):
                problems.append(f"{path}:{number}: '{match}' ({reason})")
    return problems


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--config", type=Path, default=DEFAULT_CONFIG, help="denylist JSON (schema 1)")
    ap.add_argument("--text", type=Path, nargs="*", default=[], help="Markdown or plain-text files, every line")
    ap.add_argument("--swift", type=Path, nargs="*", default=[], help="Swift files, string literals only")
    ap.add_argument("--allow", nargs="*", default=[], metavar="WORD",
                    help="denylist words that are real features of this experience (never measured-claim patterns)")
    a = ap.parse_args(argv)
    if not a.text and not a.swift:
        print("ERROR: give at least one --text or --swift file", file=sys.stderr)
        return 2
    try:
        rules = load_rules(json.loads(a.config.read_text(encoding="utf-8")), a.allow)
        problems: list[str] = []
        for path in a.text:
            problems += scan(path, False, rules)
        for path in a.swift:
            problems += scan(path, True, rules)
    except (OSError, ValueError, KeyError, re.error) as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 2
    if problems:
        for p in problems:
            print("PROBLEM:", p)
        print(f"FAIL: copy claims, {len(problems)} problems")
        return 1
    print(f"PASS: copy claims, {len(a.text) + len(a.swift)} files")
    return 0


if __name__ == "__main__":
    sys.exit(main())
