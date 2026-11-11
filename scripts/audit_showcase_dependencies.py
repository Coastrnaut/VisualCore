#!/usr/bin/env python3
"""Build-time dependency audit: the Showcase must not compile against or link ProjectM engine, preset or
reference-bridge modules (feature 007 T-F602; FR-F610, SC-F602; contract specs/007-showcase-app/contracts/
showcase-contract.md). Deterministic, Apple tools only (otool, nm, swift package dump-package); no network.

Layers:
  spec      the Showcase target and the packages it uses in the XcodeGen spec
  packages  every local Swift package reachable from the spec (manifest dependencies and binary targets)
  imports   import / #include lines in the Showcase sources
  binary    every file in the built .app: bundle paths, otool -L libraries and nm symbols

Allowed: the owner's ANGLE libEGL / libGLESv2 frameworks (renderer baseline, constitution I), even though they
are built inside the read-only reference tree. Everything ProjectM-specific is denied.
Exit: 0 no findings, 1 findings (printed as "<layer>: <item>"), 2 usage/input error.
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
# Rule R1 reference modules (scripts/check_dependencies.py) plus engine/preset names.
REFERENCE_MODULES = {"ProjectMBridge", "ANGLERendering", "Rendering", "PresetLibrary", "CaptureKit",
                     "CaptureUI", "AudioCore", "Diagnostics", "CANGLE", "CFlashLimiter", "projectM", "ProjectM",
                     "projectM_iOS", "MilkDrop"}
DENY_TEXT = re.compile(r"projectm|milkdrop|presetlibrary|capturekit|captureui|cflashlimiter", re.I)
ALLOWED_PATH = re.compile(r"External/projectm-ios/Build/ANGLEFrameworks/lib(EGL|GLESv2)\.xcframework", re.I)
SOURCE_EXT = {".swift", ".m", ".mm", ".h", ".c", ".cpp"}
IMPORT = re.compile(r"^\s*(?:@\w+(?:\([^)]*\))?\s+)*import\s+(?:(?:typealias|struct|class|enum|protocol|let|var|func)\s+)?([A-Za-z_]\w*)", re.M)
CINCLUDE = re.compile(r'^\s*#\s*(?:include|import)\s*[<"]([^>"]+)[>"]', re.M)


def denied_text(text: str) -> bool:
    return bool(DENY_TEXT.search(ALLOWED_PATH.sub("", text)))


# --- spec ---------------------------------------------------------------------------------------------

def target_block(lines: list[str], name: str) -> list[str]:
    """Lines of `targets: <name>:` in an XcodeGen YAML file (indentation-based, no YAML dependency)."""
    out, inside, indent = [], False, None
    in_targets = False
    for line in lines:
        stripped = line.strip()
        if re.match(r"^targets:\s*$", line):
            in_targets = True
            continue
        if in_targets and re.match(r"^\S", line):
            in_targets = False
            if inside:
                break
        if in_targets and re.match(rf"^(\s+){re.escape(name)}:\s*$", line):
            inside, indent = True, len(line) - len(line.lstrip())
            continue
        if inside:
            if stripped and (len(line) - len(line.lstrip())) <= indent:
                break
            out.append(line)
    return out


def packages_section(lines: list[str]) -> dict[str, str]:
    """`packages:` name → path/url."""
    pkgs, current, in_pkgs = {}, None, False
    for line in lines:
        if re.match(r"^packages:\s*$", line):
            in_pkgs = True
            continue
        if in_pkgs and re.match(r"^\S", line):
            break
        if not in_pkgs:
            continue
        m = re.match(r"^  (\S+):\s*$", line)
        if m:
            current = m.group(1)
            pkgs[current] = ""
            continue
        m = re.match(r"^\s+(path|url):\s*(\S+)", line)
        if m and current:
            pkgs[current] = m.group(2)
    return pkgs


def audit_spec(spec: Path, target: str) -> tuple[list[str], list[str], dict[str, str]]:
    lines = spec.read_text().splitlines()
    block = target_block(lines, target)
    if not block:
        raise ValueError(f"target {target!r} not found in {spec}")
    findings, checked = [], [f"{spec.name}:{target}"]
    used = set()
    # Judge structure only: drop YAML comments and the bodies of build-script phases (names and shell text).
    structural, script_indent = [], None
    for raw in block:
        line = re.sub(r"\s+#.*$|^\s*#.*$", "", raw)
        indent = len(raw) - len(raw.lstrip())
        if script_indent is not None:
            if raw.strip() and indent <= script_indent:
                script_indent = None
            else:
                continue
        if re.match(r"^\s*(pre|post)BuildScripts:\s*$", line) or re.match(r"^\s*buildToolPlugins:\s*$", line):
            script_indent = indent
            continue
        if line.strip():
            structural.append(line)
    for line in structural:
        if re.match(r"^\s*-?\s*package:\s*(\S+)", line):
            used.add(re.match(r"^\s*-?\s*package:\s*(\S+)", line).group(1))
        m = re.match(r"^\s*(?:-\s*)?(?:product|target|framework|sdk|path):\s*(\S+)", line)
        if m:
            item = m.group(1)
            if item in REFERENCE_MODULES or denied_text(item):
                findings.append(f"spec: {target} references {item}")
        elif denied_text(line):
            findings.append(f"spec: {target} line '{line.strip()}'")
    pkgs = packages_section(lines)
    for name in sorted(used):
        loc = pkgs.get(name, "")
        checked.append(f"package {name} -> {loc}")
        if name in REFERENCE_MODULES or denied_text(name) or denied_text(loc):
            findings.append(f"spec: package {name} ({loc})")
    return findings, checked, {n: pkgs.get(n, "") for n in used}


# --- packages ------------------------------------------------------------------------------------------

def dump_package(path: Path) -> dict:
    out = subprocess.run(["swift", "package", "dump-package", "--package-path", str(path)],
                         capture_output=True, text=True, timeout=300)
    if out.returncode != 0:
        raise ValueError(f"swift package dump-package failed for {path}: {out.stderr.strip()[:300]}")
    return json.loads(out.stdout)


def audit_packages(roots: list[Path]) -> tuple[list[str], list[str]]:
    findings, checked, seen = [], [], set()
    queue = list(roots)
    while queue:
        pkg = queue.pop(0).resolve()
        if pkg in seen:
            continue
        seen.add(pkg)
        if denied_text(str(pkg)):
            findings.append(f"packages: local package {pkg}")
            continue
        if not (pkg / "Package.swift").exists():
            raise ValueError(f"package {pkg} has no Package.swift")
        manifest = dump_package(pkg)
        checked.append(manifest.get("name", pkg.name))
        for dep in manifest.get("dependencies", []):
            for kind, info in dep.items():
                for entry in info if isinstance(info, list) else [info]:
                    loc = entry.get("path") or entry.get("location", {}).get("remote", [{}])[0].get("urlString", "") \
                        if isinstance(entry, dict) else ""
                    ident = entry.get("identity", "") if isinstance(entry, dict) else ""
                    if denied_text(str(loc)) or denied_text(ident):
                        findings.append(f"packages: {manifest.get('name')} depends on {ident or loc}")
                    elif kind == "fileSystem" and loc:
                        queue.append(Path(loc))
        for target in manifest.get("targets", []):
            tname = target.get("name", "")
            if tname in REFERENCE_MODULES or denied_text(tname):
                findings.append(f"packages: {manifest.get('name')} target {tname}")
            tpath = target.get("path") or ""
            if target.get("type") == "binary" and tpath and not ALLOWED_PATH.search(tpath) and denied_text(tpath):
                findings.append(f"packages: {manifest.get('name')} binary target {tname} at {tpath}")
            for d in target.get("dependencies", []):
                for _, val in d.items():
                    name = val[0] if isinstance(val, list) and val else ""
                    if name in REFERENCE_MODULES or denied_text(str(name)):
                        findings.append(f"packages: {manifest.get('name')}/{tname} depends on {name}")
        resolved = pkg / "Package.resolved"
        if resolved.exists() and denied_text(resolved.read_text()):
            findings.append(f"packages: {resolved} pins a denied package")
    return findings, checked


# --- imports ------------------------------------------------------------------------------------------

def audit_imports(sources: Path) -> tuple[list[str], list[str]]:
    findings, checked = [], []
    for f in sorted(p for p in sources.rglob("*") if p.suffix in SOURCE_EXT and p.is_file()):
        checked.append(str(f.relative_to(sources)))
        text = f.read_text(errors="replace")
        for m in IMPORT.finditer(text):
            if m.group(1) in REFERENCE_MODULES or denied_text(m.group(1)):
                findings.append(f"imports: {f.relative_to(sources)} imports {m.group(1)}")
        for m in CINCLUDE.finditer(text):
            if denied_text(m.group(1)):
                findings.append(f"imports: {f.relative_to(sources)} includes {m.group(1)}")
    return findings, checked


# --- binary -------------------------------------------------------------------------------------------

def is_macho(path: Path) -> bool:
    try:
        with path.open("rb") as fh:
            magic = fh.read(4)
    except OSError:
        return False
    return magic in (b"\xcf\xfa\xed\xfe", b"\xce\xfa\xed\xfe", b"\xca\xfe\xba\xbe", b"\xfe\xed\xfa\xcf")


def audit_binary(app: Path | None, symbols_file: Path | None) -> tuple[list[str], list[str]]:
    findings, checked = [], []
    for f in (sorted(app.rglob("*")) if app else []):
        rel = str(f.relative_to(app))
        if denied_text(rel):
            findings.append(f"binary: bundle contains {rel}")
        if not f.is_file() or not is_macho(f):
            continue
        checked.append(rel)
        libs = subprocess.run(["otool", "-L", str(f)], capture_output=True, text=True).stdout.splitlines()[1:]
        for lib in libs:
            if denied_text(lib):
                findings.append(f"binary: {rel} links {lib.strip().split(' ')[0]}")
        syms = subprocess.run(["nm", "-a", str(f)], capture_output=True, text=True).stdout
        bad = [s for s in syms.splitlines() if denied_text(s)]
        if bad:
            findings.append(f"binary: {rel} has {len(bad)} denied symbols (e.g. {bad[0].split()[-1]})")
    if symbols_file:
        checked.append(f"symbols file {symbols_file.name}")
        bad = [s for s in symbols_file.read_text().splitlines() if denied_text(s)]
        if bad:
            findings.append(f"binary: {symbols_file.name} has {len(bad)} denied symbols (e.g. {bad[0].split()[-1]})")
    return findings, checked


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--root", type=Path, default=ROOT, help="repository (or fixture) root")
    ap.add_argument("--spec", type=Path, default=Path("project.yml"))
    ap.add_argument("--target", default="Showcase")
    ap.add_argument("--sources", type=Path, default=Path("Showcase"))
    ap.add_argument("--app", type=Path, help="built Showcase.app to inspect")
    ap.add_argument("--symbols-file", type=Path, help="extra nm-style symbol list to inspect (fixtures)")
    ap.add_argument("--skip-packages", action="store_true", help="skip manifest inspection (fixtures without packages)")
    ap.add_argument("--json", type=Path)
    args = ap.parse_args(argv)
    root = args.root.resolve()
    try:
        spec = root / args.spec
        if not spec.exists():
            raise ValueError(f"spec {spec} not found")
        report: dict = {"target": args.target, "layers": {}}
        f1, c1, used = audit_spec(spec, args.target)
        report["layers"]["spec"] = {"checked": c1, "findings": f1}
        f2, c2 = [], []
        if not args.skip_packages:
            roots = [root / loc for loc in used.values() if loc and not loc.startswith(("http", "git@"))]
            f2, c2 = audit_packages([r for r in roots if not denied_text(str(r))])
            f2 += [f"packages: spec package path {r}" for r in roots if denied_text(str(r))]
        report["layers"]["packages"] = {"checked": c2, "findings": f2}
        src = root / args.sources
        if not src.is_dir():
            raise ValueError(f"sources {src} not found")
        f3, c3 = audit_imports(src)
        report["layers"]["imports"] = {"checked": c3, "findings": f3}
        f4, c4 = [], []
        if args.app or args.symbols_file:
            app = args.app.resolve() if args.app else None
            if app and not app.is_dir():
                raise ValueError(f"app {app} not found")
            f4, c4 = audit_binary(app, args.symbols_file)
        report["layers"]["binary"] = {"checked": c4, "findings": f4}
    except (ValueError, OSError, subprocess.TimeoutExpired, json.JSONDecodeError) as exc:
        print(f"audit error: {exc}", file=sys.stderr)
        return 2
    findings = [f for layer in report["layers"].values() for f in layer["findings"]]
    report["passed"] = not findings
    for layer, data in report["layers"].items():
        print(f"{layer}: checked {len(data['checked'])}, findings {len(data['findings'])}")
    for f in findings:
        print(f)
    if args.json:
        args.json.write_text(json.dumps(report, indent=2) + "\n")
    print("PASS: no ProjectM engine/preset/bridge dependency" if not findings else f"FAIL: {len(findings)} finding(s)")
    return 0 if not findings else 1


if __name__ == "__main__":
    sys.exit(main())
