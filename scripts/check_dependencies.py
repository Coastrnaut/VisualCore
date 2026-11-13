#!/usr/bin/env python3
"""Enforce the VisualCore package rules R1-R8 (T-F103; contracts specs/002-architecture-contracts/contracts/package-map.md;
R6-R8 from UA-F10 FR-U10-030, specs/196-ua-f10-build-ci research R4).

R1  Only Harnesses/ProjectMReference/ may import/depend on reference ProjectM modules
    (ProjectMBridge, ANGLERendering, Rendering, PresetLibrary, CaptureKit, CaptureUI, AudioCore,
    Diagnostics) or reference packages / ProjectM.xcframework. Module names match whole.
R2  Pure Packages/VisualCore sources import only Foundation-level system modules and pure VisualCore modules.
R3  No cycles in the target dependency graph of Packages/*/Package.swift.
R4  Packages/* never import app or harness modules.
R5  VisualCoreTestSupport is a dependency of test targets only.
R6  A source of experience X in a Packages/Experiences*/ package never imports a module of another experience Y
    (`<Y>Core`, `<Y>Experience`). The owning experience is the folder `Packages/<Pkg>/<Name>/...` (any depth), mapped
    through the `path:` of the targets `<Name>Core`, `<Name>CoreTests`, `<Name>Experience`, `<Name>ExperienceTests`.
R7  In an Experiences* Package.swift, a target of experience X never depends on a target or product of experience Y.
R8  No source (and no target) of an Experiences* package imports or depends on a reference ProjectM module; such
    imports are reported as R8 instead of R1.

Exit 1 with one line per violation: rule, path:line, detail. Standard library only.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REFERENCE_MODULES = {"ProjectMBridge", "ANGLERendering", "Rendering", "PresetLibrary", "CaptureKit",
                     "CaptureUI", "AudioCore", "Diagnostics", "CANGLE", "CFlashLimiter"}
HARNESS = "Harnesses/ProjectMReference"
PURE_ALLOWED_SYSTEM = {"Foundation", "Dispatch", "os", "Darwin", "Glibc", "Synchronization", "simd",
                       "XCTest", "Testing", "_Concurrency", "Accelerate"}
SOURCE_EXT = {".swift", ".c", ".h", ".m", ".mm"}
IMPORT = re.compile(r"^\s*(?:@\w+(?:\([^)]*\))?\s+)*import\s+(?:(?:typealias|struct|class|enum|protocol|let|var|func)\s+)?([A-Za-z_][\w]*)", re.M)
CINCLUDE = re.compile(r'^\s*#\s*(?:include|import)\s*[<"]([\w-]+)/', re.M)
SKIP_PARTS = {".build", "Build", ".swiftpm", "DerivedData", "External"}


def sources(root: Path, base: str):
    d = root / base
    if not d.exists():
        return
    for p in sorted(d.rglob("*")):
        if p.is_file() and p.suffix in SOURCE_EXT and p.name != "Package.swift" and not (SKIP_PARTS & set(p.relative_to(root).parts)):
            yield p


def imports(path: Path) -> list[tuple[int, str]]:
    text = path.read_text(encoding="utf-8", errors="replace")
    text = re.sub(r"/\*.*?\*/", lambda m: "\n" * m.group(0).count("\n"), text, flags=re.S)
    text = re.sub(r"//[^\n]*", "", text)
    out = []
    for rx in (IMPORT, CINCLUDE):
        for m in rx.finditer(text):
            out.append((text.count("\n", 0, m.start()) + 1, m.group(1)))
    return out


def call_blocks(text: str, kinds: tuple[str, ...]) -> list[tuple[str, str, str]]:
    """Return (kind, name, body) for each `.kind(name: "X", ...)` call with balanced parentheses."""
    out = []
    for m in re.finditer(r"\.(%s)\(\s*name:\s*\"([^\"]+)\"" % "|".join(kinds), text):
        depth, i = 0, m.start() + len(m.group(1)) + 1
        start = i
        while i < len(text):
            if text[i] == "(":
                depth += 1
            elif text[i] == ")":
                depth -= 1
                if depth == 0:
                    break
            i += 1
        out.append((m.group(1), m.group(2), text[start:i + 1]))
    return out


def target_deps(body: str) -> list[str]:
    m = re.search(r"dependencies:\s*\[", body)
    if not m:
        return []
    depth, i = 1, m.end()
    while i < len(body) and depth:
        depth += {"[": 1, "]": -1}.get(body[i], 0)
        i += 1
    seg = body[m.end():i - 1]
    names = re.findall(r'\.product\(name:\s*"([^"]+)"', seg)
    names += re.findall(r'\.target\(name:\s*"([^"]+)"', seg)
    names += re.findall(r'(?<![:\w])"([^"]+)"', re.sub(r'\.(?:product|target)\([^)]*\)', "", seg))
    return names


def manifests(root: Path):
    for m in sorted((root / "Packages").glob("*/Package.swift")) if (root / "Packages").exists() else []:
        yield m, m.read_text(encoding="utf-8")


def app_modules(root: Path) -> set[str]:
    names = set()
    for base in ("Apps", "Harnesses"):
        d = root / base
        if d.exists():
            names |= {p.name for p in d.iterdir() if p.is_dir()}
    for yml in list(root.glob("*.yml")) + list((root / "Harnesses").glob("*.yml") if (root / "Harnesses").exists() else []):
        text = yml.read_text(encoding="utf-8")
        tgt = text.split("\ntargets:", 1)[1] if "\ntargets:" in text else ""
        names |= set(re.findall(r"^  ([A-Za-z][\w-]*):\s*$", tgt, re.M))
    return {n.replace("-", "_") for n in names} | names


EXPERIENCE_SUFFIXES = ("ExperienceTests", "CoreTests", "Experience", "Core")
MODULE_SUFFIXES = ("Experience", "Core")


def experience_of(target: str) -> str | None:
    """Return the experience a target name `<Name>{Core,CoreTests,Experience,ExperienceTests}` belongs to."""
    for suf in EXPERIENCE_SUFFIXES:
        if target.endswith(suf) and len(target) > len(suf):
            return target[:-len(suf)]
    return None


def experience_packages(root: Path) -> list[dict]:
    """Describe each Packages/Experiences*/ package: owners of targets, products and folders."""
    out = []
    pk = root / "Packages"
    if not pk.exists():
        return out
    for d in sorted(p for p in pk.glob("Experiences*") if p.is_dir()):
        mf = d / "Package.swift"
        text = mf.read_text(encoding="utf-8") if mf.exists() else ""
        targets: dict[str, tuple[str, list[str]]] = {}
        folders: dict[str, str] = {}
        for kind, name, body in call_blocks(text, ("target", "testTarget", "executableTarget")):
            exp = experience_of(name)
            if exp is None:
                continue
            targets[name] = (exp, target_deps(body))
            pm = re.search(r'path:\s*"([^"]+)"', body)
            parts = Path(pm.group(1)).parts if pm else ("Sources", name)
            folder = parts[0] if parts[0] != "Sources" or len(parts) == 1 else parts[1]
            folders.setdefault(folder, exp)
            folders.setdefault(exp, exp)
        owners = {n: e for n, (e, _) in targets.items()}
        for name, body in re.findall(r'\.library\(\s*name:\s*"([^"]+)"\s*,([^)]*)\)', text):
            ts = re.findall(r'"([^"]+)"', body)
            exps = {owners[t] for t in ts if t in owners}
            if len(exps) == 1:
                owners.setdefault(name, exps.pop())
        out.append({"dir": d, "manifest": mf, "targets": targets, "folders": folders, "owners": owners})
    return out


def check(root: Path = ROOT) -> list[dict]:
    v: list[dict] = []
    rel = lambda p: p.relative_to(root).as_posix()
    pure_modules = {p.name for p in (root / "Packages" / "VisualCore" / "Sources").iterdir()} if (root / "Packages" / "VisualCore" / "Sources").exists() else set()
    apps = app_modules(root)
    exp_pkgs = experience_packages(root)
    exp_dirs = {e["dir"].relative_to(root).as_posix() + "/" for e in exp_pkgs}
    in_exp = lambda p: any(rel(p).startswith(d) for d in exp_dirs)
    # R1 imports (experience packages are reported as R8 below)
    for base in ("Packages", "Apps", "Showcase", "Harnesses"):
        for p in sources(root, base):
            if rel(p).startswith(HARNESS + "/") or in_exp(p):
                continue
            for line, mod in imports(p):
                if mod in REFERENCE_MODULES:
                    v.append({"rule": "R1", "path": f"{rel(p)}:{line}", "detail": f"imports reference module {mod}"})
    # R1 manifests / project specs
    for m, text in manifests(root):
        for ref in re.findall(r'\.package\(path:\s*"([^"]+)"', text):
            if "projectm-ios/Packages" in ref:
                v.append({"rule": "R1", "path": rel(m), "detail": f"depends on reference package {ref}"})
        if "ProjectM.xcframework" in text:
            v.append({"rule": "R1", "path": rel(m), "detail": "references ProjectM.xcframework"})
    ymls = list(root.glob("*.yml")) + (list((root / "Harnesses").glob("*.yml")) if (root / "Harnesses").exists() else [])
    for y in ymls:
        if y.name == "ProjectMReference.yml":
            continue
        text = re.sub(r"#[^\n]*", "", y.read_text(encoding="utf-8"))
        if re.search(r"projectm-ios/Packages|ProjectM\.xcframework", text):
            v.append({"rule": "R1", "path": rel(y), "detail": "project spec depends on ProjectM reference code"})
    # R2 pure imports
    for p in sources(root, "Packages/VisualCore"):
        for line, mod in imports(p):
            if mod not in PURE_ALLOWED_SYSTEM and mod not in pure_modules:
                v.append({"rule": "R2", "path": f"{rel(p)}:{line}", "detail": f"pure module imports {mod}"})
    # R4 packages importing apps
    for p in sources(root, "Packages"):
        for line, mod in imports(p):
            if mod in apps:
                v.append({"rule": "R4", "path": f"{rel(p)}:{line}", "detail": f"shared package imports app/harness module {mod}"})
    # R6 cross-experience imports, R8 reference imports in experience sources
    module_owner: dict[str, str] = {}
    for e in exp_pkgs:
        for n, (exp, _) in e["targets"].items():
            if n.endswith(MODULE_SUFFIXES):
                module_owner[n] = exp
    for e in exp_pkgs:
        base = e["dir"].relative_to(root).as_posix()
        for p in sources(root, base):
            parts = p.relative_to(e["dir"]).parts
            folder = parts[1] if parts[0] == "Sources" and len(parts) > 2 else parts[0]
            owner = e["folders"].get(folder)
            for line, mod in imports(p):
                if mod in REFERENCE_MODULES:
                    v.append({"rule": "R8", "path": f"{rel(p)}:{line}",
                              "detail": f"experience {owner or folder} imports reference ProjectM module {mod}"})
                elif owner and mod in module_owner and module_owner[mod] != owner:
                    v.append({"rule": "R6", "path": f"{rel(p)}:{line}",
                              "detail": f"experience {owner} imports {mod} of experience {module_owner[mod]}"})
    # R7 cross-experience target dependencies, R8 reference dependencies in experience manifests
    all_owners: dict[str, str] = {}
    for e in exp_pkgs:
        all_owners.update(e["owners"])
    for e in exp_pkgs:
        for n, (exp, tdeps) in e["targets"].items():
            for d in tdeps:
                if d in REFERENCE_MODULES:
                    v.append({"rule": "R8", "path": rel(e["manifest"]),
                              "detail": f"target {n} of experience {exp} depends on reference ProjectM module {d}"})
                elif d in all_owners and all_owners[d] != exp:
                    v.append({"rule": "R7", "path": rel(e["manifest"]),
                              "detail": f"target {n} of experience {exp} depends on {d} of experience {all_owners[d]}"})
    # R3 cycles + R5
    graph: dict[str, list[str]] = {}
    for m, text in manifests(root):
        for kind, name, body in call_blocks(text, ("target", "testTarget", "executableTarget", "binaryTarget")):
            deps = target_deps(body)
            graph[name] = deps
            if kind != "testTarget" and "VisualCoreTestSupport" in deps:
                v.append({"rule": "R5", "path": rel(m), "detail": f"non-test target {name} depends on VisualCoreTestSupport"})
    for y in ymls:
        text = y.read_text(encoding="utf-8")
        for tgt, typ, body in re.findall(r"^  ([\w-]+):\n    type: (\S+)\n((?:    .*\n?)*)", text, re.M):
            if "test" not in typ and "VisualCoreTestSupport" in body:
                v.append({"rule": "R5", "path": rel(y), "detail": f"{tgt} ({typ}) depends on VisualCoreTestSupport"})
    state: dict[str, int] = {}

    def visit(n: str, stack: list[str]):
        state[n] = 1
        for d in graph.get(n, []):
            if d not in graph:
                continue
            if state.get(d) == 1:
                cyc = stack[stack.index(d):] + [d] if d in stack else [n, d]
                v.append({"rule": "R3", "path": "Packages/*/Package.swift", "detail": "cycle " + " -> ".join(cyc)})
            elif not state.get(d):
                visit(d, stack + [d])
        state[n] = 2
    for n in sorted(graph):
        if not state.get(n):
            visit(n, [n])
    return v


def main(argv: list[str] | None = None) -> int:
    import argparse
    ap = argparse.ArgumentParser(description="Check the VisualCore package rules R1-R8.")
    ap.add_argument("--root", type=Path, default=ROOT, help="repository root (default: this repository)")
    v = check(ap.parse_args(argv).root.resolve())
    for x in v:
        print(f"{x['rule']} {x['path']}: {x['detail']}")
    print("PASS: R1-R8 hold" if not v else f"FAIL: {len(v)} violations")
    return 1 if v else 0


if __name__ == "__main__":
    sys.exit(main())
