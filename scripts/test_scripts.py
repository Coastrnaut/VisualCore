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
        self.assertTrue(baseline.destination("19108E51-71E5-4862-9C7F-6CBC357C060D").startswith("platform=iOS Simulator"))
        with self.assertRaises(SystemExit):
            baseline.destination("platform=iOS,id=00008120-001A2B3C4D5E6F70")


if __name__ == "__main__":
    unittest.main(verbosity=2)
