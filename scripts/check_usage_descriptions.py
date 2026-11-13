#!/usr/bin/env python3
"""Check the app's permission usage descriptions against the declared permissions (feature 197, UA-F11, story 2).

    python3 scripts/check_usage_descriptions.py                    # Apps/VisualCore/Generated/Info.plist
    python3 scripts/check_usage_descriptions.py --app APP          # APP/Info.plist of a built app (XML or binary)
    python3 scripts/check_usage_descriptions.py --json report.json

Each registration in Catalog/registrations.json may declare `permissions`, words of Configs/permission-vocabulary.json;
each word names one usage-description key and its reviewed text. The check passes only when the property list's
NS*UsageDescription keys equal the union of the keys of all declared words and every text equals the vocabulary's
text (FR-U11-010 to FR-U11-012). Findings: `extra-key`, `missing-key`, `unknown-word`, `text-differs`.

Exit codes: 0 PASS, 1 findings, 2 usage or unreadable input (the path is named on stderr). Standard library only; runs
on Linux (property lists are read with plistlib). With --json, writes the report of data-model section 7 atomically:
{"schema": 1, "check": "usage-descriptions", "meta": ..., "findings": [...], "verdict": "PASS"|"FAIL"}.
"""
from __future__ import annotations

import argparse
import plistlib
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from report_meta import ReportError, meta, read_versioned, write_report  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
PLIST = ROOT / "Apps/VisualCore/Generated/Info.plist"
REGISTRATIONS = ROOT / "Catalog/registrations.json"
VOCABULARY = ROOT / "Configs/permission-vocabulary.json"
USAGE_KEY = re.compile(r"NS[A-Za-z]+UsageDescription")


def read_plist(path: Path) -> dict:
    """An XML or binary property list as a dictionary."""
    try:
        data = plistlib.loads(Path(path).read_bytes())
    except FileNotFoundError as error:
        raise ReportError(f"{path}: missing") from error
    except Exception as error:  # noqa: BLE001 - any parse failure is an unusable input
        raise ReportError(f"{path}: unreadable property list ({error})") from error
    if not isinstance(data, dict):
        raise ReportError(f"{path}: expected a dictionary")
    return data


def vocabulary_words(path: Path) -> dict[str, dict]:
    """The vocabulary's words as {word: {"key", "text"}}; schema 1 only."""
    words = read_versioned(path).get("words")
    if not isinstance(words, dict) or not all(
            isinstance(e, dict) and isinstance(e.get("key"), str) and isinstance(e.get("text"), str) for e in words.values()):
        raise ReportError(f"{path}: words must map each word to a key and a text")
    return words


def declared(path: Path) -> list[tuple[str, str]]:
    """(experience id, word) for every permission word declared in the registrations."""
    regs = read_versioned(path).get("registrations")
    if not isinstance(regs, dict):
        raise ReportError(f"{path}: expected the object registrations")
    pairs = []
    for experience_id, entry in sorted(regs.items()):
        permissions = entry.get("permissions", []) if isinstance(entry, dict) else []
        if not isinstance(permissions, list) or not all(isinstance(w, str) for w in permissions):
            raise ReportError(f"{path}: {experience_id}: permissions must be a list of words")
        pairs += [(experience_id, word) for word in permissions]
    return pairs


def findings(plist: dict, pairs: list[tuple[str, str]], words: dict[str, dict], plist_name: str) -> list[dict]:
    result = []
    expected: dict[str, str] = {}
    for experience_id, word in pairs:
        if word not in words:
            result.append({"file": "registrations", "kind": "unknown-word",
                           "text": f"{experience_id} declares {word!r}, which is not a vocabulary word"})
        else:
            expected[words[word]["key"]] = words[word]["text"]
    present = {k: v for k, v in plist.items() if USAGE_KEY.fullmatch(k)}
    for key in sorted(set(present) - set(expected)):
        result.append({"file": plist_name, "kind": "extra-key",
                       "text": f"{key} is present but no registered experience declares a permission for it"})
    for key in sorted(set(expected) - set(present)):
        result.append({"file": plist_name, "kind": "missing-key",
                       "text": f"{key} is needed by a declared permission but absent"})
    for key in sorted(set(expected) & set(present)):
        if present[key] != expected[key]:
            result.append({"file": plist_name, "kind": "text-differs",
                           "text": f"{key} is {present[key]!r}; the vocabulary says {expected[key]!r}"})
    return result


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    source = ap.add_mutually_exclusive_group()
    source.add_argument("--plist", type=Path, help="property list to check (default: %(default)s)")
    source.add_argument("--app", type=Path, help="built app bundle; its Info.plist is checked")
    ap.add_argument("--registrations", type=Path, default=REGISTRATIONS)
    ap.add_argument("--vocabulary", type=Path, default=VOCABULARY)
    ap.add_argument("--json", type=Path, help="write the machine-readable report here")
    args = ap.parse_args(argv)
    plist_path = args.app / "Info.plist" if args.app else (args.plist or PLIST)
    try:
        plist = read_plist(plist_path)
        words = vocabulary_words(args.vocabulary)
        pairs = declared(args.registrations)
        found = findings(plist, pairs, words, str(plist_path))
        report_meta = meta(args.app, None) if args.json else None
    except ReportError as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 2
    for item in found:
        print(f"FINDING [{item['kind']}] {item['file']}: {item['text']}")
    keys = sorted(k for k in plist if USAGE_KEY.fullmatch(k))
    verdict = "FAIL" if found else "PASS"
    if args.json:
        write_report(args.json, {"schema": 1, "check": "usage-descriptions", "meta": report_meta,
                                 "findings": found, "verdict": verdict})
    print(f"{verdict}: usage descriptions, {len(keys)} key{'s' if len(keys) != 1 else ''}"
          f" ({', '.join(keys) or 'none'}), {len(found)} findings")
    return 1 if found else 0


if __name__ == "__main__":
    sys.exit(main())
