#!/usr/bin/env python3
"""No advertising, analytics or tracking in the built app (UA-F11 T-U11-014; FR-U11-020..023, 025, 080, 081).

  python3 scripts/check_no_tracking.py --app <Release VisualCore.app> [--json .autonomy/logs/ua-f11/tracking.json]

The deny list (`Configs/tracking-denylist.json`, schema 1, data-model §3) names advertising-support and
tracking-transparency frameworks, advertising-identifier and tracking-authorization symbols, and libraries of four
kinds (advertising, analytics, attribution, crash-reporting). The scan covers:

  * every Mach-O file of the app (main executable, embedded frameworks and libraries via
    `check_release_symbols.binaries`, and any other Mach-O in the bundle): `otool -L` linked libraries against the
    frameworks, `nm -m` symbols against the symbols;
  * every bundled file, read in 1 MiB chunks: library names as whole identifiers (not preceded or followed by
    [A-Za-z0-9_]) and symbol names as plain case-sensitive texts.

`--libraries-file` and `--symbols-file` add `otool -L`-style and `nm`-style lines to the main executable's output
(fixtures for the self-tests). Allowances in the deny list suppress one text in files whose bundle-relative path
matches `file_pattern` (fnmatch); an allowance that suppresses nothing is itself a finding (no stale exemptions).
Without `otool`/`nm` (Linux) only the fixtures and the byte scan apply, and an app containing a Mach-O is refused.

Exit 0 PASS (no findings), 1 findings, 2 unusable input (missing app, unreadable or newer deny list, missing tools).
Findings are printed, then one final `PASS: ...` or `FAIL: ...` line; `--json` writes the report of data-model §7.
"""
from __future__ import annotations

import argparse
import fnmatch
import importlib.util
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(Path(__file__).resolve().parent))
from report_meta import ReportError, meta, read_versioned, write_report  # noqa: E402


def _load(name: str):
    spec = importlib.util.spec_from_file_location(name, Path(__file__).resolve().parent / f"{name}.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


release_symbols = _load("check_release_symbols")

DEFAULT_DENYLIST = ROOT / "Configs" / "tracking-denylist.json"
KINDS = ("advertising", "analytics", "attribution", "crash-reporting")
CHUNK = 1 << 20
IDENT = re.compile(r"[A-Za-z_][A-Za-z0-9_]*\Z")
MACHO_MAGIC = (b"\xcf\xfa\xed\xfe", b"\xce\xfa\xed\xfe", b"\xca\xfe\xba\xbe", b"\xfe\xed\xfa\xcf", b"\xfe\xed\xfa\xce",
               b"\xbe\xba\xfe\xca")


# --- deny list ------------------------------------------------------------------------------------------------

def _texts(path: Path, value, field: str) -> list[str]:
    if not isinstance(value, list) or not all(isinstance(t, str) and 3 <= len(t) <= 80 for t in value):
        raise ReportError(f"{path}: {field} must be a list of texts of 3-80 characters")
    return value


def load_denylist(path: Path) -> dict:
    """Read and validate the deny list; raise ReportError naming the path on any defect."""
    data = read_versioned(path)
    frameworks = _texts(path, data.get("frameworks"), "frameworks")
    symbols = _texts(path, data.get("symbols"), "symbols")
    libraries = data.get("libraries")
    if not isinstance(libraries, dict):
        raise ReportError(f"{path}: libraries must be an object of kind -> list")
    for kind in KINDS:
        names = _texts(path, libraries.get(kind), f"libraries.{kind}")
        if len(names) < 3:
            raise ReportError(f"{path}: libraries.{kind} needs at least three libraries (FR-U11-020)")
        for name in names:
            if len(name) < 6 or not IDENT.match(name):
                raise ReportError(f"{path}: library {name!r} is not an identifier of at least 6 characters")
    extra = sorted(set(libraries) - set(KINDS))
    if extra:
        raise ReportError(f"{path}: unknown library kinds {extra}")
    allowances = data.get("allowances")
    if not isinstance(allowances, list):
        raise ReportError(f"{path}: allowances must be a list")
    for entry in allowances:
        if not isinstance(entry, dict) or set(entry) != {"text", "file_pattern", "reason"}:
            raise ReportError(f"{path}: an allowance needs exactly text, file_pattern and reason")
        _texts(path, [entry["text"]], "allowance text")
        if not all(isinstance(entry[k], str) and entry[k].strip() for k in ("file_pattern", "reason")):
            raise ReportError(f"{path}: allowance for {entry['text']!r} needs a non-empty file_pattern and reason")
    return {"frameworks": frameworks, "symbols": symbols, "libraries": libraries, "allowances": allowances}


# --- matching -------------------------------------------------------------------------------------------------

def _library_regex(names: list[str]) -> re.Pattern:
    alternatives = b"|".join(re.escape(n.encode()) for n in sorted(names, key=len, reverse=True))
    return re.compile(rb"(?<![A-Za-z0-9_])(?:" + alternatives + rb")(?![A-Za-z0-9_])")


def library_hits_in_bytes(data: bytes, names: list[str]) -> set[str]:
    """Library names present in `data` as whole identifiers."""
    return {m.group().decode() for m in _library_regex(names).finditer(data)}


def scan_bytes(path: Path, libraries: list[str], symbols: list[str], chunk: int = CHUNK) -> tuple[set[str], set[str]]:
    """(library names, symbol texts) found in one file, read in chunks; matches across chunk boundaries count."""
    regex = _library_regex(libraries)
    encoded = [(s, s.encode()) for s in symbols]
    keep = max(len(t) for t in libraries + symbols) + 1
    libs, syms = set(), set()
    tail = b""
    with path.open("rb") as handle:
        while True:
            block = handle.read(chunk)
            last = not block
            buffer = tail + block
            for m in regex.finditer(buffer):
                # A match touching the buffer end may continue in the next chunk; it is seen again there.
                if m.end() < len(buffer) or last:
                    libs.add(m.group().decode())
            syms.update(s for s, b in encoded if b in buffer)
            if last:
                return libs, syms
            tail = buffer[-keep:]


def frameworks_linked(lines: list[str], frameworks: list[str]) -> set[str]:
    found = set()
    for line in lines:
        path = line.strip().split(" (")[0]
        for name in frameworks:
            if f"/{name}.framework/" in path or path.endswith(f"/{name}.framework") or path == name:
                found.add(name)
    return found


def symbols_named(text: str, symbols: list[str]) -> set[str]:
    return {s for s in symbols if s in text}


def is_macho(path: Path) -> bool:
    try:
        with path.open("rb") as handle:
            return handle.read(4) in MACHO_MAGIC
    except OSError:
        return False


def _tool(argv: list[str]) -> str:
    out = subprocess.run(argv, capture_output=True, text=True, errors="replace", timeout=120)
    if out.returncode != 0:
        raise ReportError(f"{argv[-1]}: {argv[0]} failed ({out.stderr.strip()[:200]})")
    return out.stdout


# --- scan -----------------------------------------------------------------------------------------------------

def scan(app: Path, deny: dict, denylist_path: Path, symbols_file: Path | None = None,
         libraries_file: Path | None = None) -> list[dict]:
    """Findings [{file, kind, text}] for the app, after allowances; unused allowances are findings."""
    if not app.is_dir():
        raise ReportError(f"{app}: no such app")
    try:
        listed = release_symbols.binaries(app)
    except (OSError, KeyError, ValueError) as error:
        raise ReportError(f"{app}: no readable Info.plist or main executable ({error})") from error
    main_exe = listed[0]
    if not main_exe.is_file():
        raise ReportError(f"{app}: no main executable {main_exe.name}")
    files = sorted(p for p in app.rglob("*") if p.is_file())
    machos = list(dict.fromkeys([p for p in listed if p.is_file() and is_macho(p)] + [p for p in files if is_macho(p)]))
    have_tools = shutil.which("otool") is not None and shutil.which("nm") is not None
    if machos and not have_tools:
        raise ReportError(f"{machos[0]}: Mach-O file but otool/nm are not available")

    raw: set[tuple[str, str, str]] = set()
    rel = lambda p: p.relative_to(app).as_posix()  # noqa: E731
    for binary in machos:
        linked = _tool(["otool", "-L", str(binary)]).splitlines()[1:]
        raw.update((rel(binary), "framework", n) for n in frameworks_linked(linked, deny["frameworks"]))
        raw.update((rel(binary), "symbol", s) for s in symbols_named(_tool(["nm", "-m", str(binary)]), deny["symbols"]))
    try:
        if libraries_file:
            lines = libraries_file.read_text().splitlines()
            raw.update((rel(main_exe), "framework", n) for n in frameworks_linked(lines, deny["frameworks"]))
        if symbols_file:
            raw.update((rel(main_exe), "symbol", s) for s in symbols_named(symbols_file.read_text(), deny["symbols"]))
    except OSError as error:
        raise ReportError(f"{error.filename}: unreadable fixture ({error.strerror})") from error

    libraries = [n for kind in KINDS for n in deny["libraries"][kind]]
    for path in files:
        try:
            libs, syms = scan_bytes(path, libraries, deny["symbols"])
        except OSError as error:
            raise ReportError(f"{path}: unreadable ({error.strerror})") from error
        raw.update((rel(path), "library", n) for n in libs)
        raw.update((rel(path), "symbol", s) for s in syms)

    used = [False] * len(deny["allowances"])
    findings = []
    for file, kind, text in sorted(raw):
        allowed = False
        for i, a in enumerate(deny["allowances"]):
            if a["text"] == text and fnmatch.fnmatch(file, a["file_pattern"]):
                used[i] = allowed = True
        if not allowed:
            findings.append({"file": file, "kind": kind, "text": text})
    findings += [{"file": str(denylist_path), "kind": "unused-allowance", "text": a["text"]}
                 for a, u in zip(deny["allowances"], used) if not u]
    return findings


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--app", required=True, type=Path)
    ap.add_argument("--denylist", type=Path, default=DEFAULT_DENYLIST)
    ap.add_argument("--symbols-file", type=Path, help="extra nm-style lines for the main executable (fixtures)")
    ap.add_argument("--libraries-file", type=Path, help="extra otool -L-style lines for the main executable (fixtures)")
    ap.add_argument("--json", type=Path, help="write the machine-readable report here")
    a = ap.parse_args(argv)
    try:
        deny = load_denylist(a.denylist)
        findings = scan(a.app, deny, a.denylist, a.symbols_file, a.libraries_file)
        configuration = "Release" if any(part.startswith("Release") for part in a.app.resolve().parts) else None
        report_meta = meta(a.app, configuration) if a.json else None
    except (ReportError, subprocess.TimeoutExpired) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 2
    for f in findings:
        print(f"FINDING: {f['file']}: {f['kind']} {f['text']}")
    verdict = "FAIL" if findings else "PASS"
    if a.json:
        write_report(a.json, {"schema": 1, "check": "no-tracking", "meta": report_meta, "findings": findings,
                              "verdict": verdict})
    count = sum(1 for _ in a.app.rglob("*") if _.is_file())
    print(f"{verdict}: {len(findings)} advertising, analytics or tracking findings in {a.app.name} "
          f"({count} files scanned)")
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
