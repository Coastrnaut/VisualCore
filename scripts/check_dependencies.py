#!/usr/bin/env python3
"""Enforce the VisualCore package rules R1-R5 (T-F103; contracts specs/002-architecture-contracts/contracts/package-map.md).

R1  Only Harnesses/ProjectMReference/ may import/depend on reference ProjectM modules
    (ProjectMBridge, ANGLERendering, Rendering, PresetLibrary, CaptureKit, CaptureUI, AudioCore,
    Diagnostics) or reference packages / ProjectM.xcframework. Module names match whole.
R2  Pure Packages/VisualCore sources import only Foundation-level system modules and pure VisualCore modules.
R3  No cycles in the target dependency graph of Packages/*/Package.swift.
R4  Packages/* never import app or harness modules.
R5  VisualCoreTestSupport is a dependency of test targets only.

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


def check(root: Path = ROOT) -> list[dict]:
    v: list[dict] = []
    rel = lambda p: p.relative_to(root).as_posix()
    pure_modules = {p.name for p in (root / "Packages" / "VisualCore" / "Sources").iterdir()} if (root / "Packages" / "VisualCore" / "Sources").exists() else set()
    apps = app_modules(root)
    # R1 imports
    for base in ("Packages", "Apps", "Showcase", "Harnesses"):
        for p in sources(root, base):
            if rel(p).startswith(HARNESS + "/"):
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


def main() -> int:
    v = check()
    for x in v:
        print(f"{x['rule']} {x['path']}: {x['detail']}")
    print("PASS: R1-R5 hold" if not v else f"FAIL: {len(v)} violations")
    return 1 if v else 0


if __name__ == "__main__":
    sys.exit(main())
