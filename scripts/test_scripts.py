#!/usr/bin/env python3
"""Unit tests for the deterministic VisualCore scripts (T-F006). Run: python3 scripts/test_scripts.py"""
from __future__ import annotations

import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent


def load(name: str):
    spec = importlib.util.spec_from_file_location(name, HERE / f"{name}.py")
    mod = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod


compliance = load("check_compliance")
docs = load("validate_docs")
inventory = load("inventory_devices")
clean = load("check_reference_clean")
refinv = load("inventory_reference")
baseline = load("run_reference_baseline")
try:
    deps = load("check_dependencies")
except FileNotFoundError:
    deps = None


class ComplianceTests(unittest.TestCase):
    def scan(self, rel: str, text: str) -> list[str]:
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / rel
            p.parent.mkdir(parents=True)
            p.write_text(text)
            return compliance.scan(Path(d))

    def test_dlsym_rejected(self):
        self.assertTrue(self.scan("Packages/X/a.c", "void *p = dlsym(h, \"x\");"))

    def test_comment_ignored(self):
        self.assertFalse(self.scan("Packages/X/a.swift", "// dlsym( is forbidden\nlet x = 1"))

    def test_projectm_outside_harness(self):
        self.assertTrue(self.scan("Apps/A/a.swift", "import ProjectMBridge"))
        self.assertFalse(self.scan("Harnesses/ProjectMReference/a.swift", "import ProjectMBridge"))

    def test_replaykit_and_metalkit(self):
        self.assertTrue(self.scan("Apps/A/a.swift", "import ReplayKit"))
        self.assertTrue(self.scan("Apps/A/a.swift", "import MetalKit"))

    def test_signing_team(self):
        self.assertTrue(self.scan("Apps/A/project.yml", "DEVELOPMENT_TEAM: ABCDE12345"))
        self.assertFalse(self.scan("Apps/A/project.yml", "# DEVELOPMENT_TEAM: set by owner"))

    def test_network_requires_allowlist(self):
        self.assertTrue(self.scan("Apps/A/a.swift", "let s = URLSession.shared"))


class DocsTests(unittest.TestCase):
    def make(self, d: Path, spec: str, tasks: str = ""):
        (d / ".specify/memory").mkdir(parents=True)
        (d / ".specify/memory/constitution.md").write_text("# C\n**Version**: 1.0.0 | x\n")
        f = d / "specs/001-x"
        f.mkdir(parents=True)
        (f / "spec.md").write_text(spec)
        (f / "tasks.md").write_text(tasks)
        (d / "docs/decisions").mkdir(parents=True)

    def test_clean(self):
        with tempfile.TemporaryDirectory() as t:
            d = Path(t)
            self.make(d, "- **FR-F001**: a\n", "- [X] T-F001 x — Verified 2026-11-10: cmd\n")
            self.assertEqual(docs.validate(d), [])

    def test_unverified_tick_and_duplicate(self):
        with tempfile.TemporaryDirectory() as t:
            d = Path(t)
            self.make(d, "- **FR-F001**: a\n- **FR-F001**: b\n", "- [X] T-F001 x\n")
            probs = docs.validate(d)
            self.assertTrue(any("duplicated" in p or "defined in" in p for p in probs))
            self.assertTrue(any("Verified" in p for p in probs))

    def test_namespace(self):
        with tempfile.TemporaryDirectory() as t:
            d = Path(t)
            self.make(d, "- **FR-F101**: phase 1 id inside the phase 0 feature\n")
            self.assertTrue(any("namespace" in p for p in docs.validate(d)))


class InventoryTests(unittest.TestCase):
    def test_simulated_devices_ignored_and_d3_drift(self):
        raw = {"result": {"devices": [
            {"hardwareProperties": {"productType": "iPad15,7", "reality": "simulated", "udid": "S"},
             "deviceProperties": {"osVersionNumber": "27.2"}, "connectionProperties": {}},
            {"hardwareProperties": {"productType": "iPad15,7", "reality": "physical", "udid": "P"},
             "deviceProperties": {"osVersionNumber": "27.0"}, "connectionProperties": {}},
        ]}}
        rows = inventory.physical_devices(raw)
        self.assertEqual(len(rows), 1)
        roles, problems = inventory.classify(rows)
        self.assertEqual(roles["D3"]["status"], "os-drift")
        self.assertTrue(any("D3" in p for p in problems))
        self.assertNotIn("_hardware_udid", json.dumps(roles))


class ReferenceCleanTests(unittest.TestCase):
    def test_clean_and_modified_repo(self):
        import subprocess
        with tempfile.TemporaryDirectory() as t:
            repo = Path(t) / "ref"
            repo.mkdir()
            run = lambda *a: subprocess.run(["git", *a], cwd=repo, check=True, capture_output=True)
            run("init", "-q"); run("config", "user.email", "t@t"); run("config", "user.name", "t")
            (repo / "a.txt").write_text("x")
            run("add", "a.txt"); run("commit", "-qm", "init")
            self.assertEqual(clean.changes(repo), [])
            (repo / "b.txt").write_text("untracked build output")
            self.assertEqual(clean.changes(repo), [])
            (repo / "a.txt").write_text("changed")
            self.assertTrue(clean.changes(repo))


class CitationTests(unittest.TestCase):
    def test_resolution(self):
        with tempfile.TemporaryDirectory() as t:
            ref = Path(t)
            (ref / "S.swift").write_text("func hello() {}")
            doc = ref / "doc.md"
            doc.write_text("ok ref:`S.swift`#`func hello()` bad ref:`S.swift`#`nope` missing ref:`X.swift`#`a`")
            old = refinv.REF
            refinv.REF = ref
            try:
                bad = refinv.check_citations(doc)
            finally:
                refinv.REF = old
            self.assertEqual(len(bad), 2)


class BaselineDestinationTests(unittest.TestCase):
    def test_only_simulator_or_generic(self):
        self.assertEqual(baseline.destination("generic/platform=iOS"), "generic/platform=iOS")
        self.assertTrue(baseline.destination("00000000-0000-4000-8000-000000000001").startswith("platform=iOS Simulator"))
        with self.assertRaises(SystemExit):
            baseline.destination("platform=iOS,id=00008120-001A2B3C4D5E6F70")


PURE_PKG = """// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "VisualCore", products: [],
    targets: [
        .target(name: "VisualCoreMath"),
        .target(name: "VisualCoreSimulation", dependencies: ["VisualCoreMath"]),
        .target(name: "VisualCoreTestSupport", dependencies: ["VisualCoreMath"]),
        .testTarget(name: "VisualCoreMathTests", dependencies: ["VisualCoreMath", "VisualCoreTestSupport"]),
    ])
"""


@unittest.skipIf(deps is None, "check_dependencies.py not written yet (T-F103)")
class DependencyCheckerTests(unittest.TestCase):
    def tree(self, files: dict) -> Path:
        d = Path(tempfile.mkdtemp())
        for rel, text in files.items():
            (d / rel).parent.mkdir(parents=True, exist_ok=True)
            (d / rel).write_text(text)
        return d

    def rules(self, files: dict) -> set:
        return {v["rule"] for v in deps.check(self.tree(files))}

    def base(self) -> dict:
        return {"Packages/VisualCore/Package.swift": PURE_PKG,
                "Packages/VisualCore/Sources/VisualCoreMath/M.swift": "import Foundation\n",
                "Packages/VisualCore/Sources/VisualCoreSimulation/S.swift": "import VisualCoreMath\n"}

    def test_clean(self):
        self.assertEqual(self.rules(self.base()), set())

    def test_r1_projectm_import_outside_harness(self):
        f = self.base(); f["Apps/Foo/App/A.swift"] = "import ProjectMBridge\n"
        self.assertIn("R1", self.rules(f))
        f = self.base(); f["Harnesses/ProjectMReference/A.swift"] = "import ProjectMBridge\n"
        self.assertNotIn("R1", self.rules(f))

    def test_r1_whole_module_names(self):
        f = self.base(); f["Apps/Foo/App/A.swift"] = "import VisualCoreDiagnostics\n"
        self.assertNotIn("R1", self.rules(f))
        f["Apps/Foo/App/B.swift"] = "import Diagnostics\n"
        self.assertIn("R1", self.rules(f))

    def test_r2_uikit_in_pure_module(self):
        f = self.base(); f["Packages/VisualCore/Sources/VisualCoreMath/U.swift"] = "import UIKit\n"
        self.assertIn("R2", self.rules(f))

    def test_r3_cycle(self):
        f = self.base()
        f["Packages/VisualCore/Package.swift"] = PURE_PKG.replace('.target(name: "VisualCoreMath")', '.target(name: "VisualCoreMath", dependencies: ["VisualCoreSimulation"])')
        self.assertIn("R3", self.rules(f))

    def test_r4_package_imports_app(self):
        f = self.base(); f["Apps/Foo/App/A.swift"] = "import Foundation\n"
        f["Packages/VisualCore/Sources/VisualCoreMath/X.swift"] = "import Foo\n"
        self.assertIn("R4", self.rules(f))

    def test_r5_testsupport_in_product_target(self):
        f = self.base()
        f["Packages/VisualCore/Package.swift"] = PURE_PKG.replace('.target(name: "VisualCoreSimulation", dependencies: ["VisualCoreMath"])', '.target(name: "VisualCoreSimulation", dependencies: ["VisualCoreMath", "VisualCoreTestSupport"])')
        self.assertIn("R5", self.rules(f))


if __name__ == "__main__":
    unittest.main(verbosity=2)
