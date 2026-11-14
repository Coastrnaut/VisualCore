#!/usr/bin/env python3
"""Refuse allocating constructs on the marked audio hot path (feature 049, A06-P03, T-A06-303; FR-A06-320, SC-A06-305).

    python3 scripts/check_audio_hot_path.py                      # the three audio sources of the repository
    python3 scripts/check_audio_hot_path.py --root DIR           # the same relative files under DIR
    python3 scripts/check_audio_hot_path.py --root DIR a.swift   # explicit files (relative to DIR or absolute)

Every audio-side block handler (demo, file, microphone source) is enclosed in a region that starts at a line
containing `// vc:hot-path begin` and ends at a line containing `// vc:hot-path end`. Regions must be balanced and
not nested, and every checked file needs at least one region.

Inside a region, comment-only lines and lines carrying `// vc:cold` (failure-only paths) are ignored; on the other
lines a trailing `//` comment is removed before matching. Refused constructs (each reported as `path:line: reason`):
array and dictionary literals or initialisers (`= [`, `[Float](`, `Array(`, `ContiguousArray(`, `Dictionary(`,
`[String:`), `String(`, string interpolation, string literals, `.append(`, `.insert(`, `.map`, `.filter`, `.reduce`,
`.compactMap`, `.flatMap`, `.sorted`, `print(`, `NSLog(`, closure literals with a capture list or an explicit `in`,
`AVAudioPCMBuffer(`, `SampleRingBuffer(`, `Data(` and `.allocate(`.

Closure rule: only closures that declare a capture list or parameters with `in` are refused, because those are the
shape of escaping (heap-allocated) closures. A trailing closure without parameters (`{ buffer.write(...) }`) is
allowed, and so is a non-escaping `withUnsafe…` pointer-access block with or without parameters
(`withUnsafeMutableBufferPointer { out in ... }`) as long as it has no capture list: non-escaping `withUnsafe…` blocks
do not allocate.

Exit codes: 0 PASS, 1 problems, 2 usage or unreadable input. Standard library only; runs on Linux.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCES = "Packages/VisualCoreRendering/Sources/VisualCoreAudio"
DEFAULT_FILES = tuple(f"{SOURCES}/{name}.swift"
                      for name in ("DemoAudioSource", "FileAudioSource", "MicrophoneAudioSource"))

BEGIN = "// vc:hot-path begin"
END = "// vc:hot-path end"
COLD = "// vc:cold"

CLOSURE = re.compile(r"\{\s*(\[[^\]]*\]\s*)?[\w\s,_]*\bin\b")
WITH_UNSAFE = re.compile(r"\bwithUnsafe\w*\s*(\([^()]*\))?\s*$")

REFUSED = (
    (re.compile(r"=\s*\["), "array or dictionary literal"),
    (re.compile(r"\[[\w.]+(\s*:\s*[\w.]+)?\]\s*\("), "array or dictionary initialiser"),
    (re.compile(r"(?<![\w.])Array\s*[(<]"), "Array initialiser"),
    (re.compile(r"\bContiguousArray\s*[(<]"), "ContiguousArray initialiser"),
    (re.compile(r"(?<![\w.])Dictionary\s*[(<]"), "Dictionary initialiser"),
    (re.compile(r"\[\s*String\s*:"), "dictionary literal or type"),
    (re.compile(r"(?<![\w.])String\s*\("), "String initialiser"),
    (re.compile(r"\\\("), "string interpolation"),
    (re.compile(r'"'), "string literal"),
    (re.compile(r"\.append\s*\("), ".append"),
    (re.compile(r"\.insert\s*\("), ".insert"),
    (re.compile(r"\.map\b"), ".map"),
    (re.compile(r"\.filter\b"), ".filter"),
    (re.compile(r"\.reduce\b"), ".reduce"),
    (re.compile(r"\.compactMap\b"), ".compactMap"),
    (re.compile(r"\.flatMap\b"), ".flatMap"),
    (re.compile(r"\.sorted\b"), ".sorted"),
    (re.compile(r"(?<![\w.])print\s*\("), "print"),
    (re.compile(r"\bNSLog\s*\("), "NSLog"),
    (re.compile(r"\bAVAudioPCMBuffer\s*\("), "AVAudioPCMBuffer instantiation"),
    (re.compile(r"\bSampleRingBuffer\s*\("), "SampleRingBuffer instantiation"),
    (re.compile(r"(?<![\w.])Data\s*\("), "Data instantiation"),
    (re.compile(r"\.allocate\s*\("), ".allocate"),
)


def strip_comment(line: str) -> str:
    """`line` without a trailing `//` comment; a `//` inside a string literal is kept."""
    quoted = False
    i = 0
    while i < len(line):
        char = line[i]
        if char == "\\" and quoted:
            i += 2
            continue
        if char == '"':
            quoted = not quoted
        elif not quoted and line.startswith("//", i):
            return line[:i]
        i += 1
    return line


def is_comment_only(line: str) -> bool:
    """True for a blank line or a line that holds only a comment."""
    text = line.strip()
    return not text or text.startswith("//") or text.startswith("/*") or text.startswith("*")


def closure_problem(code: str) -> bool:
    """True when `code` holds a closure literal with a capture list or explicit parameters, other than a
    non-escaping `withUnsafe…` block without a capture list."""
    for match in CLOSURE.finditer(code):
        if match.group(1) is None and WITH_UNSAFE.search(code[:match.start()]):
            continue
        return True
    return False


def check_file(path: Path, label: str) -> tuple[int, list[str]]:
    """(number of regions, problems) for one Swift source."""
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except (OSError, UnicodeDecodeError) as error:
        raise OSError(f"{label}: unreadable ({error})") from error
    problems: list[str] = []
    regions = 0
    open_line = 0
    for number, line in enumerate(lines, start=1):
        if BEGIN in line:
            if open_line:
                problems.append(f"{label}:{number}: nested hot-path begin (region opened at line {open_line})")
            else:
                open_line = number
            continue
        if END in line:
            if not open_line:
                problems.append(f"{label}:{number}: hot-path end without begin")
            else:
                regions += 1
                open_line = 0
            continue
        if not open_line or is_comment_only(line) or COLD in line:
            continue
        code = strip_comment(line)
        for pattern, reason in REFUSED:
            if pattern.search(code):
                problems.append(f"{label}:{number}: {reason} on the hot path")
        if closure_problem(code):
            problems.append(f"{label}:{number}: closure literal on the hot path")
    if open_line:
        problems.append(f"{label}:{open_line}: hot-path begin without end")
    if regions == 0 and not any("hot-path begin" in p or "hot-path end" in p for p in problems):
        problems.append(f"{label}:1: no hot-path region")
    return regions, problems


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--root", type=Path, default=ROOT, help="repository root (default: this repository)")
    parser.add_argument("files", nargs="*", help="Swift files to check (default: the three audio sources)")
    args = parser.parse_args(argv)
    names = args.files or list(DEFAULT_FILES)
    total_regions = 0
    problems: list[str] = []
    for name in names:
        path = Path(name) if Path(name).is_absolute() else args.root / name
        try:
            regions, found = check_file(path, name)
        except OSError as error:
            print(f"ERROR: {error}", file=sys.stderr)
            return 2
        total_regions += regions
        problems.extend(found)
    for problem in problems:
        print(problem)
    if problems:
        print(f"FAIL: audio hot path, {total_regions} regions in {len(names)} files, {len(problems)} problems")
        return 1
    print(f"PASS: audio hot path, {total_regions} regions in {len(names)} files, 0 problems")
    return 0


if __name__ == "__main__":
    sys.exit(main())
