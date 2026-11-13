#!/usr/bin/env python3
"""Unit tests for the deterministic VisualCore scripts (T-F006). Run: python3 scripts/test_scripts.py"""
from __future__ import annotations

import ast
import contextlib
import datetime
import hashlib
import importlib.util
import io
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
from unittest import mock
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT_DIR = HERE.parent


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
audit = load("audit_showcase_dependencies")
docapi = load("check_documented_api")
publicapi = load("check_public_api")
licenses = load("check_licenses")
autosim = load("run_automation_sim")
relsym = load("check_release_symbols")
relcheck = load("release_check")
apprunner = load("xcodebuild_app")
appcontract = load("check_app_contract")
enumeration = load("check_test_enumeration")
testmap = load("check_test_map")
privacy = load("check_privacy_manifest")
appreleasecheck = load("check_app_release")
licensebundle = load("bundle_licenses")
isolation = load("check_app_isolation")
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

    def test_broken_relative_link(self):
        with tempfile.TemporaryDirectory() as t:
            d = Path(t)
            self.make(d, "- **FR-F001**: a\n")
            (d / "docs/guide.md").write_text("[ok](decisions/) [web](https://example.com) [anchor](#x)\n"
                                             "[gone](missing.md#part)\n```\n[in code](nowhere.md)\n```\n")
            probs = docs.validate(d)
            self.assertEqual([p for p in probs if "broken link" in p], ["docs/guide.md: broken link missing.md#part"])

    def test_namespace(self):
        with tempfile.TemporaryDirectory() as t:
            d = Path(t)
            self.make(d, "- **FR-F101**: phase 1 id inside the phase 0 feature\n")
            self.assertTrue(any("namespace" in p for p in docs.validate(d)))

    def test_unified_numbering_map(self):
        # ADR-0009 D-11: every block of the numbering map has its own id namespace.
        cases = {"186-ua-f00-x": "U00", "200-ua-f14-x": "U14", "201-x": "R02F01", "234-x": "R02F34",
                 "301-x": "R02G0101", "310-x": "R02G0110", "550-x": "R02G2510",
                 "r03-f03-kernels": "R03F03", "r12-g25-10-final": "R12G2510"}
        for name, ns in cases.items():
            self.assertEqual(docs.namespace(Path("specs") / name), ns, name)
        for name in ("250-x", "600-x", "r03-g01-missing-feature-number"):
            self.assertEqual(docs.namespace(Path("specs") / name), "", name)

    def test_unified_namespaces_are_enforced(self):
        with tempfile.TemporaryDirectory() as t:
            d = Path(t)
            self.make(d, "- **FR-F001**: a\n")
            good = {"186-ua-f00-x": "U00", "205-mesh": "R02F05", "301-kernel": "R02G0101", "r03-g01-01-rules": "R03G0101"}
            for name, ns in good.items():
                f = d / "specs" / name
                f.mkdir(parents=True)
                (f / "spec.md").write_text(f"- **FR-{ns}-001**: a\n- **SC-{ns}-001**: b\n")
                (f / "tasks.md").write_text(f"- [X] T-{ns}-001 x per FR-{ns}-001 — Verified 2026-11-11: cmd\n- [ ] T-{ns}-002 y\n")
            self.assertEqual(docs.validate(d), [])
            (d / "specs/186-ua-f00-x/spec.md").write_text("- **FR-U01-001**: wrong namespace\n")
            self.assertTrue(any("FR-U01-001 outside namespace U00" in p for p in docs.validate(d)))
            (d / "specs/186-ua-f00-x/spec.md").write_text("- **FR-U00-001**: a\n")
            (d / "specs/205-mesh/tasks.md").write_text("- [X] T-R02F05-001 ticked without evidence\n- [ ] T-R02F05-002 uses FR-R02F05-999\n")
            probs = docs.validate(d)
            self.assertTrue(any("T-R02F05-001 ticked without" in p for p in probs))
            self.assertTrue(any("undefined FR-R02F05-999" in p for p in probs))
            (d / "specs/205-mesh/tasks.md").write_text("")
            (d / "specs/250-nowhere").mkdir()
            self.assertTrue(any("250-nowhere: feature directory outside the numbering map" in p for p in docs.validate(d)))

    # ---- feature 186 (UA-F00): the whole numbering map, one exact id shape per directory form

    OUTSIDE_THE_MAP = ("000-x", "235-x", "300-x", "551-x", "r02-f01-x", "r13-f01-x", "r03-f00-x", "r03-g00-01-x",
                       "r03-g26-01-x", "r03-g01-00-x", "r03-g01-11-x", "r03-g01-x", "notes", "r3-g1-x")
    NEW_NAMESPACES = {  # label: (directory, its namespace, a namespace of another feature of the same kind)
        "U<kk>": ("190-ua-f04-x", "U04", "U05"),
        "R02F<ff>": ("205-mesh", "R02F05", "R02F06"),
        "R02G<gg><ff>": ("301-kernel", "R02G0101", "R02G0102"),
        "RnnFff": ("r03-f03-kernels", "R03F03", "R04F03"),
        "RnnGggff": ("r12-g25-10-final", "R12G2510", "R12G2509"),
    }

    def test_directories_outside_the_map_are_reported(self):
        # FR-U00-002 (research G-01, G-02): nothing under specs/ is silently ignored.
        for name in self.OUTSIDE_THE_MAP:
            self.assertEqual(docs.namespace(Path("specs") / name), "", name)
            self.assertIsNone(docs.id_shape(Path("specs") / name), name)
        with tempfile.TemporaryDirectory() as t:
            d = Path(t)
            self.make(d, "- **FR-F001**: a\n")
            for name in self.OUTSIDE_THE_MAP:
                (d / "specs" / name).mkdir()
            (d / "specs" / "a-file-is-not-a-dossier.md").write_text("x\n")
            probs = docs.validate(d)
            for name in self.OUTSIDE_THE_MAP:
                self.assertIn(f"specs/{name}: feature directory outside the numbering map (ADR-0009 D-11)", probs, name)
            self.assertEqual(len(probs), len(self.OUTSIDE_THE_MAP))

    def test_ids_have_the_exact_shape_of_their_directory(self):
        # FR-U00-003, FR-U00-004 (research G-03, G-04): a namespace that only begins like the expected one is rejected.
        shapes = {"001-x": ("F001", "F0001"), "035-x": ("A04-301", "A04-3011"), "186-x": ("U00-001", "U000-001"),
                  "205-x": ("R02F05-001", "R02F051-001"), "301-x": ("R02G0101-001", "R02G01011-001"),
                  "r03-f01-x": ("R03F01-001", "R03F011-001"), "r03-g01-01-x": ("R03G0101-001", "R03G01011-001")}
        for name, (good, bad) in shapes.items():
            shape = docs.id_shape(Path("specs") / name)
            self.assertTrue(shape.fullmatch(good), (name, good))
            self.assertFalse(shape.fullmatch(bad), (name, bad))
        with tempfile.TemporaryDirectory() as t:
            d = Path(t)
            self.make(d, "- **FR-F0001**: four digits after the foundation namespace\n", "- [ ] T-F101 a task of phase 1\n")
            f = d / "specs/r03-f01-x"
            f.mkdir()
            (f / "spec.md").write_text("- **FR-R03F011-001**: one digit too many in the feature number\n")
            (f / "tasks.md").write_text("- [ ] T-R03F02-001 a task of another shared feature\n")
            probs = docs.validate(d)
            for needle in ("specs/001-x/spec.md: FR-F0001 outside namespace F0", "specs/001-x/tasks.md: T-F101 outside namespace F0",
                           "specs/r03-f01-x/spec.md: FR-R03F011-001 outside namespace R03F01",
                           "specs/r03-f01-x/tasks.md: T-R03F02-001 outside namespace R03F01"):
                self.assertIn(needle, probs)

    def test_each_new_namespace_accepts_its_own_ids_and_rejects_others(self):
        # FR-U00-008: one accepted and one rejected dossier per new namespace (ten sub-cases).
        for label, (name, ns, other) in self.NEW_NAMESPACES.items():
            with tempfile.TemporaryDirectory() as t:
                d = Path(t)
                self.make(d, "- **FR-F001**: a\n")
                f = d / "specs" / name
                f.mkdir()
                (f / "spec.md").write_text(f"- **FR-{ns}-001**: a\n- **SC-{ns}-001**: b\n")
                (f / "tasks.md").write_text(f"- [X] T-{ns}-001 does FR-{ns}-001 — Verified 2026-11-11: cmd\n- [ ] T-{ns}-002 open\n")
                self.assertEqual(docs.validate(d), [], f"{label}: accepted dossier")
                (f / "spec.md").write_text(f"- **FR-{ns}-001**: a\n- **SC-{other}-001**: of another feature\n")
                (f / "tasks.md").write_text(f"- [ ] T-{other}-001 of another feature\n")
                probs = docs.validate(d)
                self.assertIn(f"specs/{name}/spec.md: SC-{other}-001 outside namespace {ns}", probs, f"{label}: rejected definition")
                self.assertIn(f"specs/{name}/tasks.md: T-{other}-001 outside namespace {ns}", probs, f"{label}: rejected task")

    def test_every_ledger_directory_is_in_the_map(self):
        # FR-U00-001: every feature directory the migration ledger names has exactly one namespace of its own.
        gates = json.loads((ROOT_DIR / ".autonomy/migration/ledger.json").read_text())["gates"]
        seen = {}
        for g in gates:
            if "spec_dir" not in g:
                continue
            ns = docs.namespace(Path(g["spec_dir"]))
            self.assertTrue(ns, g["id"])
            self.assertNotIn(ns, seen, f"{g['id']} shares {ns} with {seen.get(ns)}")
            seen[ns] = g["id"]
        self.assertEqual(len(seen), 823)

    def test_the_full_planned_set_of_dossiers_validates(self):
        # Edge case "large input": every planned feature directory at once, each with ids of its own namespace.
        index = json.loads((ROOT_DIR / "docs/catalog/feature-index.json").read_text())["features"]
        briefs = json.loads((ROOT_DIR / "docs/catalog/unified-app-features.json").read_text())["features"]
        names = ([f"{n:03d}-x" for n in range(1, 186)] + [f"{b['number']}-{b['slug']}" for b in briefs]
                 + [Path(f["spec_dir_proposed"]).name for f in index if f["kind"] in ("shared-round-feature", "game-feature")])
        gates = json.loads((ROOT_DIR / ".autonomy/migration/ledger.json").read_text())["gates"]
        self.assertLessEqual({Path(g["spec_dir"]).name for g in gates if "spec_dir" in g}, set(names))
        self.assertEqual(len(names), len(set(names)))
        self.assertGreater(len(names), 1200)
        with tempfile.TemporaryDirectory() as t:
            d = Path(t)
            self.make(d, "- **FR-F001**: a\n", "- [ ] T-F001 a task\n")
            for name in names[1:]:
                f = d / "specs" / name
                f.mkdir()
                ns = docs.namespace(f)
                ident = ns + ("01" if ns[0] in "FA" else "-001")
                (f / "spec.md").write_text(f"- **FR-{ident}**: a\n- **SC-{ident}**: b\n")
                (f / "tasks.md").write_text(f"- [X] T-{ident} does FR-{ident} — Verified 2026-11-12: cmd\n")
            started = time.monotonic()
            self.assertEqual(docs.validate(d), [])
            self.assertEqual(len(docs.feature_dirs(d)), len(names))
            self.assertLess(time.monotonic() - started, 30)

    def test_duplicated_task_names_both_places(self):
        # FR-U00-005: a task id listed twice, in one task list or in two dossiers, is reported with both places.
        with tempfile.TemporaryDirectory() as t:
            d = Path(t)
            self.make(d, "- **FR-F001**: a\n", "- [ ] T-F001 first\n- [ ] T-F001 again\n")
            other = d / "specs/002-y"
            other.mkdir()
            (other / "tasks.md").write_text("- [ ] T-F001 in another dossier\n")
            probs = docs.validate(d)
            self.assertIn("task T-F001 duplicated in specs/001-x/tasks.md and specs/001-x/tasks.md", probs)
            self.assertIn("task T-F001 duplicated in specs/001-x/tasks.md and specs/002-y/tasks.md", probs)

    def test_every_dossier_is_counted(self):
        # research G-05: round directories are dossiers too.
        with tempfile.TemporaryDirectory() as t:
            d = Path(t)
            self.make(d, "- **FR-F001**: a\n")
            for name in ("186-ua-f00-x", "r03-f03-kernels", "notes"):
                (d / "specs" / name).mkdir()
            self.assertEqual([f.name for f in docs.feature_dirs(d)], ["001-x", "186-ua-f00-x", "r03-f03-kernels"])

    def test_archive_links_are_not_checked(self):
        # ADR-0009: docs/archive/ holds verbatim historical documents; their relative links point at old locations.
        with tempfile.TemporaryDirectory() as t:
            d = Path(t)
            self.make(d, "- **FR-F001**: a\n")
            (d / "docs/archive/planning").mkdir(parents=True)
            (d / "docs/archive/planning/old.md").write_text("[moved](round3.md)\n")
            (d / "docs/live.md").write_text("[gone](round3.md)\n")
            probs = [p for p in docs.validate(d) if "broken link" in p]
            self.assertEqual(probs, ["docs/live.md: broken link round3.md"])


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

    def test_missing_reference_project_is_generated_first(self):
        # A fresh clone has no generated .xcodeproj (setup.md §6); the build step generates it first.
        missing = ["xcodebuild", "-project", "/nonexistent/ProjectM-iOS.xcodeproj", "-scheme", "projectM-iOS", "build"]
        self.assertEqual(baseline.missing_project_generation(missing), ["xcodegen", "generate", "--spec", "project.yml"])
        lab = ["xcodebuild", "-project", "/nonexistent/RendererLab.xcodeproj", "build"]
        self.assertEqual(baseline.missing_project_generation(lab), ["xcodegen", "generate", "--spec", "RendererLab.yml"])
        self.assertIsNone(baseline.missing_project_generation(["xcodebuild", "test", "-scheme", "ANGLERendering"]))
        with tempfile.TemporaryDirectory() as d:
            existing = Path(d) / "ProjectM-iOS.xcodeproj"
            existing.mkdir()
            self.assertIsNone(baseline.missing_project_generation(["xcodebuild", "-project", str(existing), "build"]))


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


class ShowcaseAuditTests(unittest.TestCase):
    """Feature 007 T-F602 (FR-F610, SC-F602): every contaminated fixture fails and names the item."""
    FIX = HERE / "fixtures" / "showcase_audit"

    def run_audit(self, name: str, *extra: str) -> tuple[int, str]:
        import contextlib, io
        out = io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(io.StringIO()):
            code = audit.main(["--root", str(self.FIX / name), "--skip-packages", *extra])
        return code, out.getvalue()

    def test_clean_passes(self):
        code, out = self.run_audit("clean")
        self.assertEqual(code, 0, out)

    def test_comments_and_build_scripts_are_not_structure(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            (root / "Showcase" / "App").mkdir(parents=True)
            (root / "Showcase" / "App" / "A.swift").write_text("import SwiftUI\n")
            spec = (self.FIX / "clean" / "project.yml").read_text().replace(
                "    type: application\n",
                "    type: application\n    # Must never depend on ProjectM (comment)\n"
                "    postBuildScripts:\n      - name: Audit ProjectM independence\n        script: |\n          echo projectm\n")
            (root / "project.yml").write_text(spec)
            code, out = self.run_audit_at(root)
            self.assertEqual(code, 0, out)

    def run_audit_at(self, root: Path, *extra: str) -> tuple[int, str]:
        import contextlib, io
        out = io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(io.StringIO()):
            code = audit.main(["--root", str(root), "--skip-packages", *extra])
        return code, out.getvalue()

    def test_harness_spec_package_paths_resolve_relative_to_the_spec(self):
        # Feature 009 T-F802: SecondConsumer.yml uses ../../Packages paths; its packages are audited, not mis-resolved.
        spec = HERE.parent / "Harnesses" / "SecondConsumer" / "SecondConsumer.yml"
        if not spec.exists():
            self.skipTest("no SecondConsumer harness")
        import contextlib, io
        out = io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(io.StringIO()):
            code = audit.main(["--spec", "Harnesses/SecondConsumer/SecondConsumer.yml", "--target", "SecondConsumer",
                               "--sources", "Harnesses/SecondConsumer"])
        self.assertEqual(code, 0, out.getvalue())
        self.assertIn("packages: checked 3", out.getvalue(), "GardenKit, VisualCore, VisualCoreRendering")

    def test_import_contamination(self):
        code, out = self.run_audit("import")
        self.assertEqual(code, 1)
        self.assertIn("imports: App/B.swift imports ProjectMBridge", out)

    def test_package_contamination(self):
        code, out = self.run_audit("package")
        self.assertEqual(code, 1)
        self.assertIn("spec: package ProjectMReference (External/projectm-ios)", out)
        self.assertIn("ProjectMBridge", out)

    def test_framework_contamination(self):
        code, out = self.run_audit("framework", "--app", str(self.FIX / "framework" / "app_bundle"))
        self.assertEqual(code, 1)
        self.assertIn("binary: bundle contains Frameworks/ProjectM.framework", out)

    def test_symbol_contamination(self):
        code, out = self.run_audit("symbols", "--symbols-file", str(self.FIX / "symbols" / "symbols.txt"))
        self.assertEqual(code, 1)
        self.assertIn("1 denied symbols", out)

    def test_allowed_angle_paths_and_usage_errors(self):
        self.assertFalse(audit.denied_text("../../External/projectm-ios/Build/ANGLEFrameworks/libEGL.xcframework"))
        self.assertTrue(audit.denied_text("../../External/projectm-ios/Build/ProjectM.xcframework"))
        import contextlib, io
        with contextlib.redirect_stderr(io.StringIO()), contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(audit.main(["--root", str(self.FIX / "clean"), "--target", "Missing", "--skip-packages"]), 2)

    def test_real_repository_spec_packages_and_imports_are_clean(self):
        if not (HERE.parent / "project.yml").exists():
            self.skipTest("no root project.yml")
        import contextlib, io
        out = io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(io.StringIO()):
            code = audit.main([])
        self.assertEqual(code, 0, out.getvalue())
        self.assertIn("packages: checked 2", out.getvalue())


class DocumentedApiTests(unittest.TestCase):
    """Feature 009 T-F803 (FR-F806, SC-F802)."""
    FIX = HERE / "fixtures" / "documented_api"

    def run_check(self, consumer: str) -> tuple[int, str]:
        import contextlib, io
        out = io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(io.StringIO()):
            code = docapi.main(["--root", str(self.FIX), "--sources", consumer, "--packages", "packages", "--docs", "docs/README.md"])
        return code, out.getvalue()

    def test_documented_use_passes_and_ignores_comments_and_strings(self):
        code, out = self.run_check("consumer_ok")
        self.assertEqual(code, 0, out)
        self.assertIn("used by consumer_ok: 2", out)

    def test_undocumented_use_fails_naming_the_symbol(self):
        code, out = self.run_check("consumer_bad")
        self.assertEqual(code, 1)
        self.assertIn("UNDOCUMENTED Hidden", out)

    def test_usage_errors(self):
        import contextlib, io
        with contextlib.redirect_stderr(io.StringIO()), contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(docapi.main(["--root", str(self.FIX), "--sources", "missing"]), 2)

    def test_experience_packages_are_not_visualcore_api(self):
        import contextlib, io
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            (root / "packages/ExperiencesCreative/A").mkdir(parents=True)
            (root / "packages/ExperiencesCreative/A/A.swift").write_text("public struct ArtCore {}\n")
            (root / "packages/VisualCore").mkdir(parents=True)
            (root / "packages/VisualCore/V.swift").write_text("public struct Shown {}\n")
            (root / "app").mkdir()
            (root / "app/App.swift").write_text("let a = ArtCore()\nlet s = Shown()\n")
            (root / "README.md").write_text("Shown\n")
            out = io.StringIO()
            with contextlib.redirect_stdout(out), contextlib.redirect_stderr(io.StringIO()):
                code = docapi.main(["--root", d, "--sources", "app", "--packages", "packages", "--docs", "README.md"])
            self.assertEqual(code, 0, out.getvalue())
            self.assertNotIn("ArtCore", out.getvalue())


class PublicApiTests(unittest.TestCase):
    """Feature 010 T-F901 (FR-F901, SC-F901)."""
    FIX = HERE / "fixtures" / "public_api"

    def run_check(self, root: Path, *extra: str) -> tuple[int, str]:
        import contextlib, io
        out = io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(io.StringIO()):
            code = publicapi.main(["--root", str(root), *extra])
        return code, out.getvalue()

    def test_undocumented_declaration_is_named(self):
        with tempfile.TemporaryDirectory() as d:
            import shutil
            shutil.copytree(self.FIX / "Packages", Path(d) / "Packages")
            code, out = self.run_check(Path(d), "--update")
            self.assertEqual(code, 1)
            self.assertIn("UNDOCUMENTED", out)
            self.assertIn("undocumentedMethod", out)
            self.assertEqual(out.count("UNDOCUMENTED"), 1, out)
            self.assertIn("public declarations: 5", out)

    def test_baseline_detects_surface_changes(self):
        with tempfile.TemporaryDirectory() as d:
            import shutil
            shutil.copytree(self.FIX / "Packages", Path(d) / "Packages")
            lib = Path(d) / "Packages/Lib/Sources/Lib/Lib.swift"
            lib.write_text(lib.read_text().replace("    public func undocumentedMethod() {}\n", "    /// Now documented.\n    public func undocumentedMethod() {}\n"))
            code, _ = self.run_check(Path(d), "--update")
            self.assertEqual(code, 0)
            code, out = self.run_check(Path(d))
            self.assertEqual(code, 0, out)
            lib.write_text(lib.read_text() + "\n/// Added later.\npublic func added() {}\n")
            code, out = self.run_check(Path(d))
            self.assertEqual(code, 1)
            self.assertIn("ADDED   Lib | func | public func added()", out)

    def test_missing_packages_is_usage_error(self):
        with tempfile.TemporaryDirectory() as d:
            self.assertEqual(self.run_check(Path(d))[0], 2)


class LicenseTests(unittest.TestCase):
    """Feature 010 T-F907 (FR-F909)."""

    def run_check(self, root: Path) -> tuple[int, str]:
        import contextlib, io
        out = io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(io.StringIO()):
            code = licenses.main(["--root", str(root)])
        return code, out.getvalue()

    def test_repository_dependencies_are_inventoried(self):
        code, out = self.run_check(HERE.parent)
        self.assertEqual(code, 0, out)
        self.assertIn("binary libEGL", out)

    def test_unknown_binary_fails(self):
        code, out = self.run_check(HERE / "fixtures" / "licenses" / "unknown")
        self.assertEqual(code, 1)
        self.assertIn("binary target Mystery", out)


class AutomationScriptTests(unittest.TestCase):
    """Feature 010 T-F904: simulator automation runner and Release symbol check logic."""

    def test_pick_simulator_by_runtime_not_name(self):
        data = {"devices": {
            "com.apple.CoreSimulator.SimRuntime.iOS-26-5": [{"name": "iPad Air", "udid": "P", "isAvailable": True},
                                                             {"name": "iPhone 17", "udid": "A", "isAvailable": True}],
            "com.apple.CoreSimulator.SimRuntime.iOS-27-2": [{"name": "iPhone 18", "udid": "B", "isAvailable": False},
                                                             {"name": "iPhone 18 Pro", "udid": "C", "isAvailable": True}]}}
        self.assertEqual(autosim.pick_simulator(data, "26.5"), "A")
        self.assertEqual(autosim.pick_simulator(data, "27.2"), "C")
        with self.assertRaises(SystemExit):
            autosim.pick_simulator(data, "25.0")

    def test_launch_env_and_command(self):
        self.assertEqual(autosim.launch_env("smoke", None), {"SIMCTL_CHILD_VISUALCORE_AUTORUN": "smoke"})
        self.assertEqual(autosim.launch_env("smoke", 50)["SIMCTL_CHILD_VISUALCORE_AUTORUN_FRAMES"], "50")
        self.assertEqual(autosim.launch_env("smoke", None, 7)["SIMCTL_CHILD_VISUALCORE_AUTORUN_SEED"], "7")
        self.assertNotIn("SIMCTL_CHILD_VISUALCORE_AUTORUN_SEED", autosim.launch_env("smoke", None))
        self.assertEqual(autosim.launch_command("U", "dev.visualcore.Showcase")[2:4], ["launch", "--terminate-running-process"])

    def test_newest_report(self):
        with tempfile.TemporaryDirectory() as d:
            docs_dir = Path(d)
            self.assertIsNone(autosim.newest_report(docs_dir, "smoke"))
            for name in ["visualcore-automation-smoke-20261110T100000Z.json", "visualcore-automation-smoke-20261110T110000Z.json",
                         "visualcore-automation-launch-20261110T120000Z.json"]:
                (docs_dir / name).write_text("{}")
            self.assertEqual(autosim.newest_report(docs_dir, "smoke").name, "visualcore-automation-smoke-20261110T110000Z.json")

    def test_dry_run_prints_commands(self):
        import contextlib, io
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = autosim.main(["--app", "/nonexistent/Showcase.app", "--runtime", "27.2", "--mode", "launch",
                                 "--out", "/tmp/x", "--dry-run"])
        self.assertEqual(code, 0)
        self.assertIn("SIMCTL_CHILD_VISUALCORE_AUTORUN=launch", out.getvalue())

    def test_symbol_filter(self):
        nm = ("0000000100001000 T _main\n"
              "0000000100002000 T _$s20VisualCoreAutomation16AutomationRunnerC3run4mode6framesAA0C6ReportVSS_SitF\n"
              "0000000100003000 T _$s19VisualCoreRendering10RenderHostC\n")
        self.assertEqual(len(relsym.automation_symbols(nm)), 1)
        self.assertEqual(relsym.automation_symbols("0000 T _main\n"), [])


class AppIsolationTests(unittest.TestCase):
    """Feature 019 T-A02-115: apps never own EGL and stay offline unless allowed."""

    def scan(self, files: dict[str, str], **kw) -> list[str]:
        with tempfile.TemporaryDirectory() as d:
            for rel, text in files.items():
                p = Path(d) / rel
                p.parent.mkdir(parents=True, exist_ok=True)
                p.write_text(text)
            return isolation.scan(Path(d), **kw)

    def test_egl_and_network_are_flagged(self):
        problems = self.scan({"App/A.swift": "import CVisualCoreEGL\nlet d = eglGetDisplay(nil)\nlet s = URLSession.shared"})
        self.assertEqual(len(problems), 3)

    def test_comments_tests_and_allowed_network_are_ignored(self):
        self.assertEqual(self.scan({"App/A.swift": "// eglGetDisplay( and URLSession in a comment\n/* import Network */\nlet x = 1",
                                    "Tests/T.swift": "let s = URLSession.shared"}), [])
        self.assertEqual(self.scan({"App/A.swift": "let s = URLSession.shared"}, allow_network=True), [])

    def test_usage_descriptions(self):
        import plistlib
        with tempfile.TemporaryDirectory() as d:
            app = Path(d) / "X.app"
            app.mkdir()
            with open(app / "Info.plist", "wb") as f:
                plistlib.dump({"NSMicrophoneUsageDescription": "x", "CFBundleName": "X"}, f)
            self.assertEqual(len(isolation.usage_problems(app, [])), 1)
            self.assertEqual(isolation.usage_problems(app, ["NSMicrophoneUsageDescription"]), [])


class ExperienceIsolationTests(unittest.TestCase):
    """Feature UA-F03 T-U03-011: `--experiences`, line numbers, folders without sources (FR-U03-090, FR-U03-091)."""

    CLEAN = "import VisualCore\nlet x = 1\n"

    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.root = Path(self._tmp.name)

    def write(self, rel: str, text: str) -> Path:
        p = self.root / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text)
        return p

    def run_main(self, *args) -> tuple[int, str]:
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            try:
                code = isolation.main([str(a) for a in args])
            except SystemExit as e:
                code = e.code
        return code, out.getvalue()

    def two_folders(self, second_text: str) -> tuple[Path, Path, Path]:
        self.write("One/A.swift", self.CLEAN)
        bad = self.write("Two/Sub/B.swift", second_text)
        return self.root / "One", self.root / "Two", bad

    def assert_reported(self, text: str, line: int, match: str):
        one, two, bad = self.two_folders(text)
        code, out = self.run_main("--experiences", one, two)
        self.assertEqual(code, 1)
        self.assertEqual(out, f"PASS: {one} — 1 Swift files, 0 isolation problems, 0 test files left out\n"
                              f"  FAIL {bad}:{line}: {match}\n"
                              f"FAIL: {two} — 1 Swift files, 1 isolation problems, 0 test files left out\n")

    def test_two_clean_folders_pass(self):
        one, two, _ = self.two_folders(self.CLEAN)
        code, out = self.run_main("--experiences", one, two)
        self.assertEqual(code, 0)
        self.assertEqual(out, f"PASS: {one} — 1 Swift files, 0 isolation problems, 0 test files left out\n"
                              f"PASS: {two} — 1 Swift files, 0 isolation problems, 0 test files left out\n")

    def test_shim_import_is_reported_with_file_and_line(self):
        self.assert_reported("import VisualCore\nimport CVisualCoreGL\n", 2, "import CVisualCoreGL")

    def test_egl_call_is_reported_with_file_and_line(self):
        self.assert_reported("let a = 1\n\nfunc f() {\n    eglMakeCurrent(d, s, s, c)\n}\n", 4, "eglMakeCurrent(")

    def test_vcgl_call_is_reported_with_file_and_line(self):
        self.assert_reported("/* two\n   lines */\nfunc f() { vcglClear(1) }\n", 3, "vcglClear(")

    def test_gl_call_is_reported_with_file_and_line(self):
        self.assert_reported("func f() {\n    glClear(1)\n}\n", 2, "glClear(")

    def test_gl_calls_are_only_refused_for_experiences(self):
        self.write("App/A.swift", "func f() { glClear(1); vcglClear(1) }\n")
        self.assertEqual(self.run_main("--app", self.root / "App")[0], 0)
        self.assertEqual(isolation.scan(self.root / "App"), [])
        self.assertEqual(len(isolation.scan(self.root / "App", extra_patterns=isolation.GL)), 2)

    def test_commented_out_calls_are_not_reported(self):
        one, two, _ = self.two_folders("// glClear(1) and eglMakeCurrent(d)\n/* vcglClear(1)\nimport CVisualCoreGL */\n"
                                       "let single = 1\n")
        code, out = self.run_main("--experiences", one, two)
        self.assertEqual(code, 0)
        self.assertNotIn("  FAIL", out)

    def test_test_files_are_left_out_and_counted(self):
        self.write("One/A.swift", self.CLEAN)
        self.write("One/Tests/T1.swift", "func t() { glClear(1) }\n")
        self.write("One/Sub/Tests/T2.swift", "import CVisualCoreGL\n")
        code, out = self.run_main("--experiences", self.root / "One")
        self.assertEqual(code, 0)
        self.assertEqual(out, f"PASS: {self.root / 'One'} — 1 Swift files, 0 isolation problems, 2 test files left out\n")

    def test_missing_and_empty_folders_pass_as_nothing_checked(self):
        missing, empty = self.root / "Missing", self.root / "Empty"
        self.write("Empty/Tests/T.swift", "let s = 1\n")
        self.write("Empty/Generated/G.swift", "let g = 1\n")
        code, out = self.run_main("--experiences", missing, empty)
        self.assertEqual(code, 0)
        self.assertEqual(out, f"PASS: {missing} — nothing checked (no Swift sources yet)\n"
                              f"PASS: {empty} — nothing checked (no Swift sources yet)\n")
        code, out = self.run_main("--app", missing)
        self.assertEqual((code, out), (0, f"PASS: {missing} — nothing checked (no Swift sources yet)\n"))

    def test_require_sources_fails_missing_and_empty_folders(self):
        missing, empty = self.root / "Missing", self.root / "Empty"
        empty.mkdir()
        code, out = self.run_main("--experiences", missing, empty, "--require-sources")
        self.assertEqual(code, 1)
        self.assertEqual(out, f"FAIL: {missing} — no Swift sources found\nFAIL: {empty} — no Swift sources found\n")
        code, out = self.run_main("--app", missing, "--require-sources")
        self.assertEqual((code, out), (1, f"FAIL: {missing} — no Swift sources found\n"))

    def test_app_keeps_its_summary_line_and_adds_line_numbers(self):
        self.write("App/A.swift", self.CLEAN)
        self.write("App/Tests/T.swift", "let s = URLSession.shared\n")
        app = self.root / "App"
        self.assertEqual(self.run_main("--app", app), (0, f"PASS: {app} — 1 app Swift files, 0 isolation problems\n"))
        bad = self.write("App/B.swift", "let a = 1\nlet s = URLSession.shared\n")
        self.assertEqual(self.run_main("--app", app),
                         (1, f"  FAIL {bad}:2: URLSession\nFAIL: {app} — 2 app Swift files, 1 isolation problems\n"))
        self.assertEqual(self.run_main("--app", app, "--allow-network")[0], 0)
        self.assertEqual(isolation.scan_lines(app), [(bad, 2, "URLSession")])

    def test_app_and_experiences_together(self):
        self.write("App/A.swift", self.CLEAN)
        self.write("One/A.swift", "func f() { glClear(1) }\n")
        code, out = self.run_main("--app", self.root / "App", "--experiences", self.root / "One")
        self.assertEqual(code, 1)
        self.assertIn(f"PASS: {self.root / 'App'} — 1 app Swift files, 0 isolation problems\n", out)
        self.assertIn(f"FAIL: {self.root / 'One'} — 1 Swift files, 1 isolation problems, 0 test files left out\n", out)

    def test_bad_input_exits_2(self):
        self.assertEqual(self.run_main(), (2, ""))
        self.assertEqual(self.run_main("--allow-network"), (2, ""))
        self.assertEqual(self.run_main("--experiences"), (2, ""))
        self.write("App/A.swift", self.CLEAN)
        self.assertEqual(self.run_main("--app", self.root / "App", "--built-app", self.root / "No.app"), (2, ""))
        self.assertEqual(self.run_main("--app", self.root / "App" / "A.swift"), (2, ""))


class StorageRuleTests(unittest.TestCase):
    """Feature UA-F05 T-U05-001: `--no-direct-storage` and `--no-crash-on-stored-data` (FR-U05-006, FR-U05-071)."""

    CLEAN = "import VisualCore\nlet x = 1\n"
    STORAGE_PASS = "Swift files use no storage directly"
    CRASH_PASS = "Swift files read stored data without a deliberate crash"

    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.root = Path(self._tmp.name)

    def write(self, rel: str, text: str) -> Path:
        p = self.root / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text)
        return p

    def run_main(self, *args) -> tuple[int, str]:
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            try:
                code = isolation.main([str(a) for a in args])
            except SystemExit as e:
                code = e.code
        return code, out.getvalue()

    def test_file_reads_and_writes_without_a_storage_name_are_reported(self):
        """Converge task T-U05-038: reading or writing a file needs none of the storage names."""
        uses = {"Data(contentsOf": "let d = try Data(contentsOf: url)",
                "String(contentsOf": "let s = try String( contentsOf: url)",
                ".write(to:": "try data.write(to: url)"}
        self.assertEqual(sorted(uses), sorted(name for _, name in isolation.STORAGE_CALLS))
        for name, code_line in uses.items():
            with self.subTest(name):
                self.assertEqual(isolation.storage_uses("let a = 1\n" + code_line + "\n"), [(2, name)])
        clean = "items.append(contentsOf: more)\nprint(x, to: &stream)\nlet t = text.write\n"
        self.assertEqual(isolation.storage_uses(clean), [])

    def test_each_storage_name_is_reported_with_file_and_line(self):
        uses = {"UserDefaults": "let d = UserDefaults.standard",
                "FileManager": "let m = FileManager.default",
                "NSHomeDirectory": "let h = NSHomeDirectory()",
                "NSTemporaryDirectory": "let t = NSTemporaryDirectory()",
                "applicationSupportDirectory": "let a = URL.applicationSupportDirectory",
                "documentDirectory": "let u = urls(for: .documentDirectory, in: .userDomainMask)",
                "cachesDirectory": "let c = URL.cachesDirectory",
                "AppStorage": '@AppStorage("k") var k = 0',
                "SceneStorage": '@SceneStorage("k") var k = 0',
                "FileHandle": "let f = FileHandle(forReadingAtPath: p)",
                "documentsDirectory": "let u = URL.documentsDirectory",
                "libraryDirectory": "let u = URL.libraryDirectory",
                "homeDirectory": "let u = URL.homeDirectory",
                "temporaryDirectory": "let u = URL.temporaryDirectory"}
        self.assertEqual(sorted(uses), sorted(isolation.STORAGE))
        for name, code_line in uses.items():
            with self.subTest(name):
                bad = self.write(f"{name}.swift", f"import Foundation\n\n{code_line}\n")
                self.assertEqual(self.run_main("--no-direct-storage", bad),
                                 (1, f"  FAIL {bad}:3: {name}\nFAIL: 1 direct uses of storage in 1 Swift files\n"))

    def test_storage_names_are_whole_identifiers_and_every_use_counts(self):
        bad = self.write("A.swift", "let a = MyUserDefaults()\nlet b = FileManagerLike()\nlet documentDirectoryName = 1\n"
                                    "let c = FileManager.default; let d = UserDefaults.standard\n")
        self.assertEqual(self.run_main("--no-direct-storage", bad),
                         (1, f"  FAIL {bad}:4: FileManager\n  FAIL {bad}:4: UserDefaults\n"
                             "FAIL: 2 direct uses of storage in 1 Swift files\n"))

    def test_storage_names_in_comments_and_strings_are_not_findings(self):
        good = self.write("A.swift", "// UserDefaults and FileManager in a comment\n"
                                     "/* NSHomeDirectory()\n   NSTemporaryDirectory() /* nested cachesDirectory */\n"
                                     "   documentDirectory */\n"
                                     'let a = "UserDefaults, FileManager, applicationSupportDirectory"\n'
                                     'let b = """\n  NSHomeDirectory() and "cachesDirectory"\n  """\n'
                                     'let c = #"a "FileManager" \\(documentDirectory)"#\n'
                                     'let d = "an escaped \\" quote, then UserDefaults"\n'
                                     "let e = 1 // cachesDirectory\n")
        self.assertEqual(self.run_main("--no-direct-storage", good), (0, f"PASS: 1 {self.STORAGE_PASS}\n"))

    def test_line_numbers_survive_comments_and_strings_and_interpolation_is_code(self):
        bad = self.write("A.swift", "/* two\n   lines */\nlet a = \"\"\"\n  text\n  \"\"\"\n"
                                    "let b = FileManager.default // FileManager\n"
                                    'let c = "home: \\(NSHomeDirectory()) UserDefaults"\n')
        self.assertEqual(self.run_main("--no-direct-storage", bad),
                         (1, f"  FAIL {bad}:6: FileManager\n  FAIL {bad}:7: NSHomeDirectory\n"
                             "FAIL: 2 direct uses of storage in 1 Swift files\n"))

    def test_a_clean_file_passes_both_options(self):
        good = self.write("A.swift", self.CLEAN)
        self.assertEqual(self.run_main("--no-direct-storage", good), (0, f"PASS: 1 {self.STORAGE_PASS}\n"))
        self.assertEqual(self.run_main("--no-crash-on-stored-data", good), (0, f"PASS: 1 {self.CRASH_PASS}\n"))
        self.assertEqual(self.run_main("--no-direct-storage", good, "--no-crash-on-stored-data", good),
                         (0, f"PASS: 1 {self.STORAGE_PASS}\nPASS: 1 {self.CRASH_PASS}\n"))

    def test_a_directory_is_searched_recursively(self):
        self.write("Src/A.swift", self.CLEAN)
        self.write("Src/notes.txt", "UserDefaults try! fatalError()\n")
        deep = self.write("Src/Sub/Deeper/B.swift", "let a = 1\nlet d = UserDefaults.standard\nlet v = a as! Int\n")
        test = self.write("Src/Tests/T.swift", "let m = FileManager.default\nlet v = try! f()\n")
        src = self.root / "Src"
        self.assertEqual(self.run_main("--no-direct-storage", src),
                         (1, f"  FAIL {deep}:2: UserDefaults\n  FAIL {test}:1: FileManager\n"
                             "FAIL: 2 direct uses of storage in 3 Swift files\n"))
        self.assertEqual(self.run_main("--no-crash-on-stored-data", src),
                         (1, f"  FAIL {deep}:3: forced cast\n  FAIL {test}:2: try!\n"
                             "FAIL: 2 deliberate crashes in 3 Swift files\n"))

    def test_files_and_directories_together_count_each_file_once(self):
        a = self.write("Src/A.swift", self.CLEAN)
        other = self.write("Other/C.swift", self.CLEAN)
        self.assertEqual(self.run_main("--no-direct-storage", self.root / "Src", a, other),
                         (0, f"PASS: 2 {self.STORAGE_PASS}\n"))

    def test_a_missing_path_and_an_empty_directory_are_errors(self):
        missing, empty = self.root / "Missing.swift", self.root / "Empty"
        empty.mkdir()
        (empty / "notes.txt").write_text("nothing\n")
        good = self.write("A.swift", self.CLEAN)
        for option, passed in (("--no-direct-storage", self.STORAGE_PASS), ("--no-crash-on-stored-data", self.CRASH_PASS)):
            with self.subTest(option):
                self.assertEqual(self.run_main(option, missing), (1, f"FAIL: {missing} — no Swift sources found\n"))
                self.assertEqual(self.run_main(option, empty), (1, f"FAIL: {empty} — no Swift sources found\n"))
                self.assertEqual(self.run_main(option, missing, good, empty),
                                 (1, f"FAIL: {missing} — no Swift sources found\n"
                                     f"FAIL: {empty} — no Swift sources found\nPASS: 1 {passed}\n"))
                self.assertEqual(self.run_main(option), (2, ""))

    def test_each_crash_construct_is_reported_with_file_and_line(self):
        cases = [("let v = try! decode(data)", "try!"),
                 ('fatalError("unreadable")', "fatalError("),
                 ("preconditionFailure()", "preconditionFailure("),
                 ("precondition(count > 0)", "precondition("),
                 ('assertionFailure("no")', "assertionFailure("),
                 ("assert(count > 0)", "assert("),
                 ("let v = value!", "forced unwrap"),
                 ("let v = call()!", "forced unwrap"),
                 ("let v = items[0]!", "forced unwrap"),
                 ("let v = value!.count", "forced unwrap"),
                 ("let v = any as! Int", "forced cast"),
                 ("var x: Int!", "forced unwrap"),
                 ('let s = "n: \\(value!)"', "forced unwrap")]
        for number, (code_line, what) in enumerate(cases):
            with self.subTest(code_line):
                bad = self.write(f"C{number}.swift", f"import Foundation\n// a comment\n\n{code_line}\n")
                self.assertEqual(self.run_main("--no-crash-on-stored-data", bad),
                                 (1, f"  FAIL {bad}:4: {what}\nFAIL: 1 deliberate crashes in 1 Swift files\n"))

    def test_several_crashes_are_ordered_by_line_and_column(self):
        bad = self.write("A.swift", "let a = try! f()!\nfunc g() {\n    precondition(a as! Bool)\n}\n")
        self.assertEqual(self.run_main("--no-crash-on-stored-data", bad),
                         (1, f"  FAIL {bad}:1: try!\n  FAIL {bad}:1: forced unwrap\n  FAIL {bad}:3: precondition(\n"
                             f"  FAIL {bad}:3: forced cast\nFAIL: 4 deliberate crashes in 1 Swift files\n"))

    def test_negations_and_comparisons_are_not_crashes(self):
        good = self.write("A.swift", "if a != b { }\nif a!=b { }\nif a !== b { }\nlet n = !flag\n"
                                     "guard !list.isEmpty else { return }\nif ready && !done || (!other) { }\n"
                                     "let t = try? f()\nlet u = try f()\nlet c = any as? Int\nlet o: Int? = nil\n"
                                     "XCTAssert(n)\nlet preconditions = [!n]\nobject.assertions(1)\n")
        self.assertEqual(self.run_main("--no-crash-on-stored-data", good), (0, f"PASS: 1 {self.CRASH_PASS}\n"))

    def test_crashes_in_comments_and_strings_are_not_findings(self):
        good = self.write("A.swift", 'let s = "wow!"\n// done!\nlet t = "try! fatalError() value!" // assert(x)\n'
                                     "/* precondition(a)\n   items[0]! as! Int */\n"
                                     'let m = """\n  call()! and "quoted!"\n  """\nlet r = #"raw! \\(x!)"#\n'
                                     'let i = "count: \\(list.count) items!"\n')
        self.assertEqual(self.run_main("--no-crash-on-stored-data", good), (0, f"PASS: 1 {self.CRASH_PASS}\n"))

    def test_both_options_together_fail_when_either_fails(self):
        clean = self.write("Clean.swift", self.CLEAN)
        stores = self.write("Stores.swift", "let d = UserDefaults.standard\n")
        crashes = self.write("Crashes.swift", "let v = value!\n")
        self.assertEqual(self.run_main("--no-direct-storage", stores, "--no-crash-on-stored-data", clean),
                         (1, f"  FAIL {stores}:1: UserDefaults\nFAIL: 1 direct uses of storage in 1 Swift files\n"
                             f"PASS: 1 {self.CRASH_PASS}\n"))
        self.assertEqual(self.run_main("--no-direct-storage", clean, "--no-crash-on-stored-data", crashes),
                         (1, f"PASS: 1 {self.STORAGE_PASS}\n  FAIL {crashes}:1: forced unwrap\n"
                             "FAIL: 1 deliberate crashes in 1 Swift files\n"))
        self.assertEqual(self.run_main("--no-direct-storage", stores, "--no-crash-on-stored-data", crashes)[0], 1)
        # each option checks only its own rule
        self.assertEqual(self.run_main("--no-direct-storage", crashes, "--no-crash-on-stored-data", stores)[0], 0)

    def test_the_options_combine_with_the_existing_ones(self):
        self.write("App/A.swift", self.CLEAN)
        self.write("One/A.swift", self.CLEAN)
        stores = self.write("App/Stores.swift", "let d = UserDefaults.standard\n")
        app, one = self.root / "App", self.root / "One"
        code, out = self.run_main("--app", app, "--experiences", one, "--require-sources", "--no-direct-storage", app)
        self.assertEqual(code, 1)
        self.assertEqual(out, f"PASS: {app} — 2 app Swift files, 0 isolation problems\n"
                              f"PASS: {one} — 1 Swift files, 0 isolation problems, 0 test files left out\n"
                              f"  FAIL {stores}:1: UserDefaults\nFAIL: 1 direct uses of storage in 2 Swift files\n")
        bad = self.write("One/B.swift", "func f() { glClear(1) }\n")
        code, out = self.run_main("--experiences", one, "--no-crash-on-stored-data", one)
        self.assertEqual(code, 1)
        self.assertEqual(out, f"  FAIL {bad}:1: glClear(\n"
                              f"FAIL: {one} — 2 Swift files, 1 isolation problems, 0 test files left out\n"
                              f"PASS: 2 {self.CRASH_PASS}\n")

    def test_code_only_keeps_length_and_line_breaks(self):
        text = 'let a = "x // y" /* c\n d */ + b // tail\nlet c = #"raw "q" \\n"# + """\n  m \\(v + f("s")) n\n  """\n'
        code = isolation.code_only(text)
        self.assertEqual(len(code), len(text))
        self.assertEqual(code.count("\n"), text.count("\n"))
        self.assertEqual(code.split("\n")[0].rstrip(), 'let a = "      "')
        self.assertEqual(code.split("\n")[1].rstrip(), "      + b")
        self.assertIn('v + f(" ")', code)
        self.assertNotIn("raw", code)


class ReleaseCheckTests(unittest.TestCase):
    """Feature 010 T-F908: release-check runner logic (step list, selection, logs, summary, failure handling)."""

    def test_missing_projects_are_found_with_their_specs(self):
        # Fresh clone (setup.md §8): generated .xcodeproj files are missing; each is generated from its XcodeGen spec.
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            (root / "project.yml").write_text("name: VisualCore\n")
            harness = root / "Harnesses" / "ProjectMReference"
            harness.mkdir(parents=True)
            (harness / "ProjectMReference.yml").write_text("name: ProjectMReference\n")
            argv = ["xcodebuild", "test", "-project", "Harnesses/ProjectMReference/ProjectMReference.xcodeproj",
                    "-scheme", "ProjectMReference"]
            self.assertEqual(relcheck.missing_projects(argv, root),
                             [(harness / "ProjectMReference.xcodeproj", harness / "ProjectMReference.yml")])
            self.assertEqual(relcheck.missing_projects(["xcodebuild", "-project", "VisualCore.xcodeproj"], root),
                             [(root / "VisualCore.xcodeproj", root / "project.yml")])
            (root / "VisualCore.xcodeproj").mkdir()
            self.assertEqual(relcheck.missing_projects(["xcodebuild", "-project", "VisualCore.xcodeproj"], root), [])
            self.assertEqual(relcheck.missing_projects(["swift", "test"], root), [])

    def test_step_list_covers_every_release_gate(self):
        names = [s.name for s in relcheck.steps("X")]
        self.assertEqual(len(names), len(set(names)))
        for required in ["docs", "app-contracts", "compliance", "dependencies", "public-api", "licenses", "script-tests", "host-visualcore",
                         "host-gardenkit", "documented-api-showcase", "documented-api-second-consumer",
                         "rendering-sim-ios27", "rendering-sim-ios26", "showcase-ios27", "showcase-ios26",
                         "interactive-demo-ios26", "second-consumer-ios27", "projectm-reference-ios26",
                         "reference-clean", "showcase-release-build", "release-symbols", "projectm-independence"]:
            self.assertIn(required, names)
        self.assertLess(names.index("showcase-release-build"), names.index("release-symbols"))
        self.assertLess(names.index("showcase-release-build"), names.index("projectm-independence"))
        for s in relcheck.steps("X"):
            self.assertNotIn("devicectl", " ".join(s.argv))
            self.assertNotIn("platform=iOS,id=", " ".join(s.argv))

    def test_app_steps_are_discovered_per_app(self):
        """Feature 019 T-A02-115: documented-API, domain-package host tests and app tests for every app."""
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            for app, core in [("FluidArtPlayground", "FluidArtPlaygroundCore"), ("Solo", None)]:
                (root / "Apps" / app / "App").mkdir(parents=True)
                if core:
                    (root / "Apps" / app / core).mkdir()
                    (root / "Apps" / app / core / "Package.swift").write_text("// swift-tools-version: 6.0")
            (root / "Apps" / "NotAnApp").mkdir(parents=True)
            (root / "project.yml").write_text("schemes:\n  FluidArtPlayground:\n    build:\n      targets: {}\n")
            names = [s.name for s in relcheck.app_domain_steps(root)]
            self.assertEqual(names, ["documented-api-fluid-art-playground", "isolation-fluid-art-playground",
                                     "host-fluid-art-playground-core", "documented-api-solo", "isolation-solo"])
            tests = relcheck.app_test_steps("27.2", "X", root)
            self.assertEqual([s.name for s in tests], ["app-fluid-art-playground-ios27"])
            self.assertEqual(tests[0].needs_simulator, "27.2")
        self.assertEqual(relcheck.kebab("GenerativeArtStudio"), "generative-art-studio")
        names = [s.name for s in relcheck.steps("X")]
        for required in ["documented-api-particle-universe", "app-particle-universe-ios26",
                         # Feature 193: the adopted experiences' package on both runtimes.
                         "experiences-creative-sim-ios27", "experiences-creative-sim-ios26"]:
            self.assertIn(required, names)
        # Feature 193 (UA-F07): A01 and A02 are retired; no step of their standalone apps remains.
        self.assertFalse([n for n in names if "generative-art-studio" in n or "fluid-art-playground" in n
                          or "fractal-explorer" in n], names)

    def test_select_only_skip_and_unknown(self):
        all_steps = relcheck.steps("X")
        self.assertEqual([s.name for s in relcheck.select(all_steps, ["docs", "licenses"], None)], ["docs", "licenses"])
        self.assertNotIn("docs", [s.name for s in relcheck.select(all_steps, None, ["docs"])])
        with self.assertRaises(SystemExit):
            relcheck.select(all_steps, ["nope"], None)

    def test_runner_logs_each_step_and_fails_overall_on_one_failure(self):
        import contextlib, io
        fake = lambda stamp: [relcheck.Step("ok", [sys.executable, "-c", "print('fine')"]),
                              relcheck.Step("bad", [sys.executable, "-c", "import sys; print('boom'); sys.exit(3)"]),
                              relcheck.Step("slow", [sys.executable, "-c", "import time; time.sleep(5)"], timeout=1)]
        with tempfile.TemporaryDirectory() as d:
            with contextlib.redirect_stdout(io.StringIO()):
                code = relcheck.main(["--log-dir", d], step_factory=fake)
            self.assertEqual(code, 1)
            summary = json.loads((Path(d) / "summary.json").read_text())
            self.assertEqual([(x["name"], x["status"], x["exit_code"]) for x in summary["steps"]],
                             [("ok", "pass", 0), ("bad", "fail", 3), ("slow", "timeout", None)])
            self.assertEqual(summary["result"], "fail")
            self.assertIn("boom", (Path(d) / "bad.log").read_text())

    def test_all_pass(self):
        import contextlib, io
        fake = lambda stamp: [relcheck.Step("ok", [sys.executable, "-c", "pass"])]
        with tempfile.TemporaryDirectory() as d:
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(relcheck.main(["--log-dir", d], step_factory=fake), 0)

    def test_list_contains_the_unified_app_build(self):
        """Feature UA-F04 T-U04-029: the unsigned generic-simulator build of the scheme VisualCore is a release step."""
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            self.assertEqual(relcheck.main(["--list"]), 0)
        lines = [l for l in out.getvalue().splitlines() if l.startswith("visualcore-app-build: ")]
        self.assertEqual(lines, ["visualcore-app-build: xcodebuild build -project VisualCore.xcodeproj -scheme VisualCore "
                                 "-destination generic/platform=iOS Simulator "
                                 "-derivedDataPath Build/DerivedData/release-VisualCore-sim CODE_SIGNING_ALLOWED=NO"])
        names = [s.name for s in relcheck.steps("X")]
        self.assertLess(names.index("xcodegen"), names.index("visualcore-app-build"))
        self.assertEqual(names.index("visualcore-app-build"), names.index("xcodegen") + 1)


class PerformanceDocsTests(unittest.TestCase):
    """Feature UA-F06 T-U06-030 (FR-U06-060 to FR-U06-062): check_performance_docs.py."""

    tool = load("check_performance_docs")
    NOTICE = "Simulator numbers are development signals, not device performance."
    HEAD = "| Budget | Proposal | Status | Confirmed by |\n|---|---|---|---|\n"
    GOOD = "| Frame pacing | 95% on time | proposal | D1, D2, D3: scenario steady, 200 samples per device |\n"

    def run_on(self, files: dict[str, str]):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            for name, text in files.items():
                (root / name).write_text(text)
            problems, count, rows = self.tool.check(root, root)
        return problems, count, rows

    def test_a_proposal_with_a_device_measurement_passes(self):
        problems, files, rows = self.run_on({"budgets.md": "# B\n\n" + self.HEAD + self.GOOD
                                             + "| Build size | recorded | proposal | tooling: release build of UA-F10 |\n"})
        self.assertEqual(problems, [])
        self.assertEqual((files, rows), (1, 2))

    def test_a_row_without_its_measurement_fails_with_file_and_line(self):
        cases = {
            "| Launch | fast | proposal | |\n": "lacks its confirming measurement",
            "| Launch | fast | proposal | later |\n": "lacks its confirming measurement",
            "| Launch | fast | proposal | D1 only |\n": "lacks its confirming measurement",
            "| Launch | fast | proposal | D1: 200 samples |\n": "lacks its confirming measurement",
            "| Launch | fast | proposal | 200 samples |\n": "lacks its confirming measurement",
            "| Launch | fast | proposal | tooling: |\n": "lacks its confirming measurement",
            "| Launch | fast | measured | D1: scenario launch, 200 samples |\n": "neither proposal nor confirmed",
            "| Launch | fast | confirmed | D1: scenario launch, 200 samples |\n": "confirmed without a link",
            "| Launch |  | proposal | D1: scenario launch, 200 samples |\n": "needs a budget and a proposal",
        }
        for row, expected in cases.items():
            problems, _, _ = self.run_on({"budgets.md": self.HEAD + row})
            self.assertEqual(len(problems), 1, row)
            self.assertTrue(problems[0].startswith("budgets.md:3: "), problems[0])
            self.assertIn(expected, problems[0])
        ok, _, _ = self.run_on({"budgets.md": self.HEAD
                                + "| Launch | fast | confirmed | D1: scenario launch, 200 samples, [report](r.md) |\n"})
        self.assertEqual(ok, [])

    def test_a_simulator_number_without_the_notice_fails(self):
        text = "# Baselines\n\nMedian on the simulator: 12.4 ms.\n"
        problems, _, _ = self.run_on({"budgets.md": self.HEAD + self.GOOD, "notes.md": text})
        self.assertEqual(len(problems), 2)
        self.assertTrue(problems[0].startswith("notes.md:3: a simulator is mentioned without the notice"), problems[0])
        self.assertTrue(problems[1].startswith("notes.md:3: a simulator number is given without calling it"), problems[1])
        # The notice alone is not enough for a line that gives a number: the line itself says what the number is.
        problems, _, _ = self.run_on({"budgets.md": self.HEAD + self.GOOD, "notes.md": self.NOTICE + "\n" + text})
        self.assertEqual(len(problems), 1)
        self.assertTrue(problems[0].startswith("notes.md:4: a simulator number is given without calling it"), problems[0])
        labelled = self.NOTICE + "\n\nDevelopment signal on the simulator: 12.4 ms.\n"
        problems, _, _ = self.run_on({"budgets.md": self.HEAD + self.GOOD, "notes.md": labelled})
        self.assertEqual(problems, [])
        # A line about the simulator without a number needs no label.
        plain = self.NOTICE + "\n\nThe simulator runs are repeated after framework changes.\n"
        problems, _, _ = self.run_on({"budgets.md": self.HEAD + self.GOOD, "notes.md": plain})
        self.assertEqual(problems, [])

    def test_a_directory_without_a_budget_table_fails(self):
        problems, _, rows = self.run_on({"notes.md": "# nothing\n"})
        self.assertEqual(rows, 0)
        self.assertEqual(len(problems), 1)
        self.assertIn("no budget table", problems[0])

    def test_the_real_documents_pass_and_the_tool_exits_with_the_right_codes(self):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = self.tool.main([])
        self.assertEqual(code, 0, out.getvalue())
        self.assertIn("8 budget rows", out.getvalue().splitlines()[-1])
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(self.tool.main(["--dir", "docs/no-such-directory"]), 2)
        listing = subprocess.run([sys.executable, str(HERE / "release_check.py"), "--list"],
                                 capture_output=True, text=True, check=True).stdout
        self.assertIn("performance-docs: ", listing)
        # Feature 191 (UA-F05): the two source rules run with every release check, on files that exist.
        self.assertIn("storage-rule: ", listing)
        self.assertIn("stored-data-rule: ", listing)
        tool = load("release_check")
        # A source is a file or, for the adapters of feature 193 (UA-F07), a folder of them.
        for source in tool.STORAGE_RULE_SOURCES + tool.STORED_DATA_SOURCES:
            self.assertTrue((ROOT_DIR / source).exists(), source)


class UnifiedAppTargetTests(unittest.TestCase):
    """Feature UA-F04 T-U04-045 (FR-U04-001, FR-U04-070): the project has exactly one application target marked as
    the shippable one, with one unit-test and one interface-test target, and the standing isolation step of every
    app fails when its sources are missing."""

    @staticmethod
    def targets() -> dict[str, list[str]]:
        """Target name -> the lines of its block, from the `targets:` section of the root project.yml."""
        lines = (HERE.parent / "project.yml").read_text().splitlines()
        start = lines.index("targets:")
        blocks: dict[str, list[str]] = {}
        name = None
        for line in lines[start + 1:]:
            if line and not line.startswith((" ", "#")):
                break
            m = re.match(r"  ([A-Za-z0-9_]+):\s*$", line)
            if m:
                name = m.group(1)
                blocks[name] = []
            elif name:
                blocks[name].append(line)
        return blocks

    def test_exactly_one_application_target_is_marked_shippable(self):
        blocks = self.targets()
        marked = [n for n, b in blocks.items() if any("only shippable application target" in l for l in b)]
        self.assertEqual(marked, ["VisualCore"])
        app = blocks["VisualCore"]
        self.assertIn("    type: application", app)
        self.assertTrue(any("PRODUCT_BUNDLE_IDENTIFIER: dev.visualcore.VisualCore" == l.strip() for l in app))
        self.assertTrue(any("PRODUCT_MODULE_NAME: VisualCoreApp" == l.strip() for l in app))

    def test_the_app_has_one_unit_test_and_one_interface_test_target(self):
        blocks = self.targets()
        testing = {n: b for n, b in blocks.items() if any(l.strip() == "- target: VisualCore" for l in b)}
        # Feature 193 (UA-F07): each adopted experience's framework has one unit-test bundle hosted by the app.
        adopted = sorted(n for n in testing if n.endswith("ExperienceTests"))
        self.assertEqual(sorted(set(testing) - set(adopted)), ["VisualCoreTests", "VisualCoreUITests"])
        self.assertIn("    type: bundle.unit-test", testing["VisualCoreTests"])
        self.assertIn("    type: bundle.ui-testing", testing["VisualCoreUITests"])
        for name in adopted:
            self.assertIn("    type: bundle.unit-test", testing[name])
            self.assertIn(name.removesuffix("Tests"), blocks, "its framework target exists")

    def test_the_app_links_no_unused_framework_product(self):
        products = [l.split("product:")[1].strip() for l in self.targets()["VisualCore"] if "product:" in l]
        # Feature 193 (UA-F07): the adapter cores of the adopted experiences, which the registry names.
        self.assertEqual(products, ["VisualCoreExperience", "VisualCoreSimulation", "VisualCoreDiagnostics",
                                    "VisualCorePersistence",
                                    "VisualCoreRendering", "VisualCoreUI", "VisualCoreExperienceHost",
                                    "GenerativeArtStudioExperience", "FluidArtPlaygroundExperience",
                                    "FractalExplorerExperience", "ParticleUniverseExperience"])

    def test_the_standing_isolation_step_requires_sources(self):
        listing = subprocess.run([sys.executable, str(HERE / "release_check.py"), "--list"],
                                 capture_output=True, text=True, check=True).stdout
        steps = [l for l in listing.splitlines() if l.startswith("isolation-")]
        self.assertTrue(any(l.startswith("isolation-visual-core:") for l in steps), steps)
        for line in steps:
            self.assertTrue(line.endswith(" --require-sources"), line)


class ComplianceScanReportTests(unittest.TestCase):
    """The compliance check says what it scanned, so a missing app folder cannot pass unseen (UA-F04)."""

    def test_each_app_is_reported_as_its_own_area(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "Apps" / "One" / "App").mkdir(parents=True)
            (root / "Apps" / "One" / "App" / "A.swift").write_text("let a = 1\n")
            (root / "Apps" / "One" / "App" / "B.swift").write_text("let b = 1\n")
            (root / "Packages" / "P").mkdir(parents=True)
            (root / "Packages" / "P" / "C.swift").write_text("let c = 1\n")
            self.assertEqual(compliance.scanned(root), {"Apps/One": 2, "Packages": 1})

    def test_the_unified_app_is_scanned(self):
        self.assertGreater(compliance.scanned().get("Apps/VisualCore", 0), 15)


class AppTestRunnerTests(unittest.TestCase):
    """Feature UA-F04 T-U04-002 (FR-U04-080): scripts/xcodebuild_app.py."""

    PHONE_27, TABLET_27, PHONE_26, TABLET_26, GONE = ("AAAA1111-0000-0000-0000-000000000001",
                                                      "AAAA1111-0000-0000-0000-000000000002",
                                                      "BBBB2222-0000-0000-0000-000000000001",
                                                      "BBBB2222-0000-0000-0000-000000000002",
                                                      "CCCC3333-0000-0000-0000-000000000009")
    DEVICES = {"devices": {
        "com.apple.CoreSimulator.SimRuntime.iOS-27-2": [
            {"name": "iPhone 18 Pro", "udid": GONE, "isAvailable": False},
            {"name": "iPad Pro 13-inch (M5)", "udid": TABLET_27, "isAvailable": True},
            {"name": "iPhone 18", "udid": PHONE_27, "isAvailable": True},
            {"name": "iPhone 18 Plus", "udid": "AAAA1111-0000-0000-0000-000000000003", "isAvailable": True},
        ],
        "com.apple.CoreSimulator.SimRuntime.iOS-26-5": [
            {"name": "iPhone 17", "udid": PHONE_26, "isAvailable": True},
            {"name": "iPad Air 11-inch (M3)", "udid": TABLET_26, "isAvailable": True},
        ],
        "com.apple.CoreSimulator.SimRuntime.iOS-25-0": [
            {"name": "iPhone 16", "udid": "DDDD4444-0000-0000-0000-000000000001", "isAvailable": True},
        ],
        "com.apple.CoreSimulator.SimRuntime.watchOS-27-2": [
            {"name": "iPhone-like Watch", "udid": "EEEE5555-0000-0000-0000-000000000001", "isAvailable": True},
        ],
    }}

    def test_guard_is_limited_to_the_classes_of_a_chunk(self):
        """A run in chunks names whole classes or single methods; the guard then checks only these. An id that names
        a target gives no list, so the guard runs for everything."""
        tool = load("xcodebuild_app")
        self.assertEqual(tool.guard_classes(["VisualCoreUITests/RoutesUITests", "VisualCoreTests/StoreTests"]),
                         ["RoutesUITests", "StoreTests"])
        self.assertEqual(tool.guard_classes(["VisualCoreUITests/RoutesUITests/testOne"]), ["RoutesUITests/testOne"])
        self.assertEqual(tool.guard_classes(["VisualCoreUITests"]), [])
        self.assertEqual(tool.guard_classes([]), [])

    def test_picks_a_phone_and_a_tablet_by_runtime(self):
        pick = apprunner.pick_simulator
        self.assertEqual(pick(self.DEVICES, "27.2", "phone"), (self.PHONE_27, "iPhone 18"))   # the unavailable one is skipped
        self.assertEqual(pick(self.DEVICES, "27.2", "tablet"), (self.TABLET_27, "iPad Pro 13-inch (M5)"))
        self.assertEqual(pick(self.DEVICES, "26.5", "phone"), (self.PHONE_26, "iPhone 17"))
        self.assertEqual(pick(self.DEVICES, "26.5", "tablet"), (self.TABLET_26, "iPad Air 11-inch (M3)"))

    def test_a_phone_is_the_narrowest_one_with_a_known_width(self):
        """FR-U04-035 asks for the smallest phone: with widths the narrowest available phone of the runtime is taken;
        a type without width comes last; a tablet stays the first one."""
        devices = {"devices": {"com.apple.CoreSimulator.SimRuntime.iOS-27-2": [
            {"udid": "P1", "name": "iPhone Wide", "isAvailable": True, "deviceTypeIdentifier": "t.wide"},
            {"udid": "P2", "name": "iPhone Unknown", "isAvailable": True, "deviceTypeIdentifier": "t.unknown"},
            {"udid": "P3", "name": "iPhone Narrow", "isAvailable": True, "deviceTypeIdentifier": "t.narrow"},
            {"udid": "P4", "name": "iPhone Narrow Too", "isAvailable": True, "deviceTypeIdentifier": "t.narrow"},
            {"udid": "P5", "name": "iPhone Gone", "isAvailable": False, "deviceTypeIdentifier": "t.tiny"},
            {"udid": "T1", "name": "iPad Big", "isAvailable": True, "deviceTypeIdentifier": "t.big"},
            {"udid": "T2", "name": "iPad Small", "isAvailable": True, "deviceTypeIdentifier": "t.small"}]}}
        widths = {"t.wide": 440.0, "t.narrow": 390.0, "t.tiny": 320.0, "t.big": 1024.0, "t.small": 744.0}
        pick = apprunner.pick_simulator
        self.assertEqual(pick(devices, "27.2", "phone", widths), ("P3", "iPhone Narrow"))
        self.assertEqual(pick(devices, "27.2", "phone", {}), ("P1", "iPhone Wide"))
        self.assertEqual(pick(devices, "27.2", "phone"), ("P1", "iPhone Wide"))
        self.assertEqual(pick(devices, "27.2", "tablet", widths), ("T1", "iPad Big"))

    def test_phone_widths_are_points_from_the_device_type_capabilities(self):
        types = {"devicetypes": [
            {"identifier": "t.a", "bundlePath": "/types/a"}, {"identifier": "t.b", "bundlePath": "/types/b"},
            {"identifier": "t.c", "bundlePath": "/types/c"}, {"identifier": "t.d"}]}
        plists = {
            "/types/a/Contents/Resources/capabilities.plist":
                {"capabilities": {"ScreenDimensionsCapability": {"main-screen-width": 1170, "main-screen-scale": 3.0}}},
            "/types/b/Contents/Resources/capabilities.plist":
                {"ScreenDimensionsCapability": {"main-screen-width": 1320, "main-screen-scale": 3.0}},
            "/types/c/Contents/Resources/capabilities.plist": {"capabilities": {}}}

        def run(cmd, **kw):
            self.assertEqual(cmd, ["xcrun", "simctl", "list", "-j", "devicetypes"])
            return subprocess.CompletedProcess(cmd, 0, stdout=json.dumps(types), stderr="")

        self.assertEqual(apprunner.phone_widths(run=run, load=lambda path: plists[path]), {"t.a": 390.0, "t.b": 440.0})
        failing = lambda cmd, **kw: subprocess.CompletedProcess(cmd, 1, stdout="", stderr="no")
        self.assertEqual(apprunner.phone_widths(run=failing, load=lambda path: {}), {})

        def broken(cmd, **kw):
            raise OSError("no xcrun")
        self.assertEqual(apprunner.phone_widths(run=broken), {})

    def test_none_when_the_runtime_or_kind_has_none(self):
        pick = apprunner.pick_simulator
        self.assertIsNone(pick(self.DEVICES, "28.0", "phone"))
        self.assertIsNone(pick(self.DEVICES, "25.0", "tablet"))
        self.assertIsNone(pick(self.DEVICES, "27.2", "watch"))
        self.assertIsNone(pick({"devices": {}}, "27.2", "phone"))
        self.assertIsNone(pick({}, "27.2", "phone"))

    def test_exact_command(self):
        self.assertEqual(apprunner.test_command("VisualCore.xcodeproj", "VisualCore", "UDID", "Build/DerivedData/x", []),
                         ["xcodebuild", "test", "-project", "VisualCore.xcodeproj", "-scheme", "VisualCore",
                          "-destination", "platform=iOS Simulator,id=UDID",
                          "-test-timeouts-enabled", "YES", "-default-test-execution-time-allowance", "180",
                          "-derivedDataPath", "Build/DerivedData/x", "CODE_SIGNING_ALLOWED=NO"])
        self.assertEqual(apprunner.test_command("P.xcodeproj", "S", "U", "D", [], action="test-without-building")[1],
                         "test-without-building")
        par = apprunner.test_command("P.xcodeproj", "S", "U", "D", [], parallel=3)
        self.assertEqual(par[par.index("-parallel-testing-worker-count") + 1], "3")
        self.assertIn("-parallel-testing-enabled", par)
        self.assertNotIn("-parallel-testing-enabled", apprunner.test_command("P.xcodeproj", "S", "U", "D", []))
        cmd = apprunner.test_command("P.xcodeproj", "S", "U", "D", ["VisualCoreTests/A", "VisualCoreUITests/B/testC"])
        self.assertEqual(cmd[-2:], ["-only-testing:VisualCoreTests/A", "-only-testing:VisualCoreUITests/B/testC"])
        self.assertIn("CODE_SIGNING_ALLOWED=NO", cmd)

    def run_main(self, args, xcode_exit=0, guard_exit=0, listing=None, sources=True, processes=""):
        """Runs the tool in a temporary root with a fake runner and guard; returns (code, output, calls, guards, root files)."""
        calls, guards = [], []
        devices = self.DEVICES if listing is None else listing

        def fake_run(cmd, **kw):
            if cmd[0] == "ps":
                return subprocess.CompletedProcess(cmd, 0, stdout=processes, stderr="")
            calls.append((list(cmd), kw))
            if cmd[:2] == ["xcrun", "simctl"]:
                return subprocess.CompletedProcess(cmd, 0, stdout=json.dumps(devices), stderr="")
            kw["stdout"].write("Test Case '-[T.A testOne]' passed (0.1 s).\n"
                               f"destination id={cmd[cmd.index('-destination') + 1].split('id=')[1]}\n** TEST RESULT **\n")
            return subprocess.CompletedProcess(cmd, xcode_exit)

        def fake_guard(src, log):
            guards.append((src, log, log.read_text()))
            return guard_exit

        with tempfile.TemporaryDirectory() as d:
            root = Path(d).resolve()
            if sources:
                (root / "Apps" / "VisualCore" / "Tests").mkdir(parents=True)
            out = io.StringIO()
            with contextlib.redirect_stdout(out), contextlib.redirect_stderr(io.StringIO()):
                code = apprunner.main(args, root=root, run=fake_run, guard=fake_guard, widths=lambda: {})
            files = sorted(str(p.relative_to(root)) for p in root.rglob("*.log"))
            guards = [(str(s.relative_to(root)), str(l.relative_to(root)), text) for s, l, text in guards]
            cwd_ok = all(kw.get("cwd") == root for c, kw in calls if c[0] == "xcodebuild")
        return code, out.getvalue(), calls, guards, files, cwd_ok

    BASE = ["--scheme", "VisualCore", "--runtime", "27.2", "--kind", "phone"]

    def test_a_run_refuses_while_another_xcodebuild_uses_the_simulator(self):
        code, out, calls, *_ = self.run_main(self.BASE, processes=f"xcodebuild test -destination platform=iOS Simulator,id={self.PHONE_27}\n")
        self.assertEqual(code, 2, out)
        self.assertIn("another xcodebuild", out)
        self.assertFalse(any(c[0] == "xcodebuild" for c, _ in calls))

    def test_pass_runs_tests_then_guard_and_writes_the_log(self):
        code, out, calls, guards, files, cwd_ok = self.run_main(self.BASE)
        self.assertEqual(code, 0)
        self.assertEqual(calls[0][0], ["xcrun", "simctl", "list", "-j", "devices", "available"])
        self.assertEqual(calls[1][0], apprunner.test_command("VisualCore.xcodeproj", "VisualCore", self.PHONE_27,
                                                             "Build/DerivedData/app-VisualCore-27.2-phone", []))
        self.assertEqual(calls[1][1]["stderr"], subprocess.STDOUT)
        self.assertTrue(cwd_ok)
        self.assertEqual(files, [".autonomy/logs/app-tests/VisualCore-27.2-phone.log"])
        self.assertEqual([(s, l) for s, l, _ in guards],
                         [("Apps/VisualCore/Tests", ".autonomy/logs/app-tests/VisualCore-27.2-phone.log")])
        self.assertIn("testOne]' passed", guards[0][2])   # the guard reads the finished log
        self.assertEqual(out.splitlines()[-1], "PASS: VisualCore on iOS 27.2 phone — tests and enumeration guard passed "
                                               "(.autonomy/logs/app-tests/VisualCore-27.2-phone.log)")
        self.assertIn("** TEST RESULT **", out)            # the last lines of the log are repeated

    def test_a_run_that_does_not_end_is_stopped_and_names_its_last_test(self):
        """The runner hands its time limit to the process runner; when the limit is reached it fails with exit 3,
        names the last test that started and says how to go on, instead of running into the caller's own limit."""
        seen = {}

        def slow_run(cmd, **kw):
            if cmd[0] == "ps":
                return subprocess.CompletedProcess(cmd, 0, stdout="", stderr="")
            if cmd[:2] == ["xcrun", "simctl"]:
                return subprocess.CompletedProcess(cmd, 0, stdout=json.dumps(self.DEVICES), stderr="")
            seen["timeout"] = kw.get("timeout")
            kw["stdout"].write("Test Case '-[T.A testOne]' started.\nTest Case '-[T.A testOne]' passed (0.1 s).\n"
                               "Test Case '-[T.B testHangs]' started.\n")
            kw["stdout"].flush()
            raise subprocess.TimeoutExpired(cmd, kw.get("timeout"))

        with tempfile.TemporaryDirectory() as d:
            root = Path(d).resolve()
            (root / "Apps" / "VisualCore" / "Tests").mkdir(parents=True)
            out = io.StringIO()
            with contextlib.redirect_stdout(out), contextlib.redirect_stderr(io.StringIO()):
                code = apprunner.main(self.BASE + ["--max-seconds", "7"], root=root, run=slow_run,
                                      guard=lambda src, log: 0, widths=lambda: {})
        self.assertEqual(code, 3)
        self.assertEqual(seen["timeout"], 7)
        last = out.getvalue().splitlines()[-1]
        self.assertTrue(last.startswith("FAIL: VisualCore on iOS 27.2 phone — stopped after 7 s: "
                                        "the last test started was T.B testHangs."), last)
        self.assertIn("--only-testing", last)

    def test_the_default_limit_is_below_ten_minutes_and_zero_disables_it(self):
        code, out, calls, guards, files, cwd_ok = self.run_main(self.BASE)
        self.assertEqual(calls[1][1]["timeout"], 540)
        code, out, calls, guards, files, cwd_ok = self.run_main(self.BASE + ["--max-seconds", "0"])
        self.assertIsNone(calls[1][1]["timeout"])

    def test_identifier_is_never_printed(self):
        for kind, udid, name in [("phone", self.PHONE_27, "iPhone 18"), ("tablet", self.TABLET_27, "iPad Pro 13-inch (M5)")]:
            code, out, calls, _, files, _ = self.run_main(["--scheme", "VisualCore", "--runtime", "27.2", "--kind", kind])
            self.assertEqual(code, 0)
            self.assertIn(f"id={udid}", " ".join(calls[1][0]))   # passed to xcodebuild only
            self.assertNotIn(udid, out)                          # even though the fake log's tail contains it
            self.assertNotIn(udid, " ".join(files))
            self.assertIn(name, out)
            self.assertIn("iOS 27.2", out)

    def test_options_reach_the_command_and_the_log_name(self):
        code, out, calls, guards, files, _ = self.run_main(
            ["--scheme", "VisualCore", "--runtime", "26.5", "--kind", "tablet", "--project", "Other.xcodeproj",
             "--only-testing", "VisualCoreTests/A", "VisualCoreTests/B", "--only-testing", "VisualCoreUITests",
             "--log-name", "smoke", "--derived-data", "Build/DerivedData/custom"])
        self.assertEqual(code, 0)
        self.assertEqual(calls[1][0], apprunner.test_command("Other.xcodeproj", "VisualCore", self.TABLET_26, "Build/DerivedData/custom",
                                                             ["VisualCoreTests/A", "VisualCoreTests/B", "VisualCoreUITests"]))
        self.assertEqual(files, [".autonomy/logs/app-tests/smoke.log"])
        self.assertTrue(out.splitlines()[-1].startswith("PASS: VisualCore on iOS 26.5 tablet — "))

    def test_exit_1_when_the_tests_fail(self):
        code, out, _, guards, files, _ = self.run_main(self.BASE, xcode_exit=65)
        self.assertEqual(code, 1)
        self.assertEqual(guards, [])                             # no guard on a failed run
        self.assertTrue(out.splitlines()[-1].startswith("FAIL: VisualCore on iOS 27.2 phone — tests failed"))
        self.assertIn(files[0], out.splitlines()[-1])

    def test_exit_1_when_the_guard_fails(self):
        code, out, _, guards, _, _ = self.run_main(self.BASE, guard_exit=1)
        self.assertEqual(code, 1)
        self.assertEqual(len(guards), 1)
        self.assertTrue(out.splitlines()[-1].startswith("FAIL: VisualCore on iOS 27.2 phone — tests passed but the enumeration guard failed"))

    def test_exit_2_without_a_simulator_or_with_bad_input(self):
        code, out, calls, _, files, _ = self.run_main(["--scheme", "VisualCore", "--runtime", "28.0", "--kind", "phone"])
        self.assertEqual((code, len(calls), files), (2, 1, []))  # xcodebuild is never started
        self.assertEqual(out.splitlines()[-1], "FAIL: VisualCore on iOS 28.0 phone — no available iPhone simulator of iOS 28.0")
        code, out, calls, _, _, _ = self.run_main(["--scheme", "VisualCore", "--runtime", "25.0", "--kind", "tablet"])
        self.assertEqual((code, len(calls)), (2, 1))
        self.assertIn("no available iPad simulator", out)
        for bad in [["--scheme", "VisualCore", "--runtime", "27.2", "--kind", "watch"],
                    ["--scheme", "VisualCore", "--runtime", "latest", "--kind", "phone"],
                    ["--scheme", "VisualCore", "--runtime", "27.2"],
                    self.BASE + ["--log-name", "../escape"],
                    self.BASE + ["--destination", "platform=iOS,id=00008140-000000000000001E"],
                    self.BASE + ["--only-testing", "platform=iOS,id=X"]]:
            code, _, calls, _, files, _ = self.run_main(bad)
            self.assertEqual((code, calls, files), (2, [], []), bad)
        code, _, calls, _, _, _ = self.run_main(self.BASE, sources=False)
        self.assertEqual((code, calls), (2, []))

    def test_default_guard_is_the_enumeration_check(self):
        with tempfile.TemporaryDirectory() as t:
            d = Path(t)
            (d / "src").mkdir()
            (d / "src" / "A.swift").write_text("final class ATests: XCTestCase {\n    func testOne() {}\n}\n")
            log = d / "log"
            log.write_text("Test Case '-[T.ATests testOne]' passed (1 s).\n")
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(apprunner.enumeration_guard(d / "src", log), 0)
                log.write_text("nothing ran\n")
                self.assertEqual(apprunner.enumeration_guard(d / "src", log), 1)

    def test_result_name_adds_the_result_bundle_path(self):
        """UA-F09 T-U09-001 (FR-U09-023): `--result-name NAME` passes `-resultBundlePath
        <root>/.autonomy/xcresults/NAME.xcresult`; without it the command is unchanged."""
        self.assertNotIn("-resultBundlePath", apprunner.test_command("P.xcodeproj", "S", "U", "D", []))
        cmd = apprunner.test_command("P.xcodeproj", "S", "U", "D", ["T/A"], "/r/.autonomy/xcresults/x.xcresult")
        self.assertEqual(cmd[-3:], ["-resultBundlePath", "/r/.autonomy/xcresults/x.xcresult", "-only-testing:T/A"])
        code, _, calls, _, _, _ = self.run_main(self.BASE)
        self.assertEqual(code, 0)
        self.assertNotIn("-resultBundlePath", calls[1][0])
        seen = {}

        def fake_run(cmd, **kw):
            if cmd[0] == "ps":
                return subprocess.CompletedProcess(cmd, 0, stdout="", stderr="")
            if cmd[:2] == ["xcrun", "simctl"]:
                return subprocess.CompletedProcess(cmd, 0, stdout=json.dumps(self.DEVICES), stderr="")
            seen["cmd"] = list(cmd)
            bundle = Path(cmd[cmd.index("-resultBundlePath") + 1])
            seen["old_gone"] = not bundle.exists()
            seen["parent"] = bundle.parent.is_dir()
            kw["stdout"].write("Test Case '-[T.A testOne]' passed (0.1 s).\n")
            return subprocess.CompletedProcess(cmd, 0)

        with tempfile.TemporaryDirectory() as d:
            root = Path(d).resolve()
            (root / "Apps" / "VisualCore" / "Tests").mkdir(parents=True)
            old = root / ".autonomy" / "xcresults" / "smoke-27.2.xcresult"
            (old / "Data").mkdir(parents=True)
            (old / "Info.plist").write_text("old")
            with contextlib.redirect_stdout(io.StringIO()):
                code = apprunner.main(self.BASE + ["--result-name", "smoke-27.2"], root=root, run=fake_run,
                                      guard=lambda src, log: 0, widths=lambda: {})
        self.assertEqual(code, 0)
        i = seen["cmd"].index("-resultBundlePath")
        self.assertEqual(seen["cmd"][i + 1], str(root / ".autonomy" / "xcresults" / "smoke-27.2.xcresult"))
        self.assertTrue(seen["old_gone"])     # the older bundle of that name was removed before the run
        self.assertTrue(seen["parent"])
        for bad in ["../escape", "a/b", ""]:
            code, _, calls, _, _, _ = self.run_main(self.BASE + ["--result-name", bad])
            self.assertEqual((code, calls), (2, []), bad)


class EvidenceValidatorTests(unittest.TestCase):
    """Feature UA-F09 T-U09-015 (FR-U09-030 to FR-U09-032, FR-U09-062): scripts/check_evidence.py."""

    GROUPS = ["schema", "experience", "code", "scenario", "seed", "result", "run", "environment", "source",
              "configuration", "steps", "digests", "frames", "failures"]

    @classmethod
    def setUpClass(cls):
        cls.tool = load("check_evidence")

    def record(self, **changes):
        """The tool's valid sample record with dotted-path (`a.b`, `frames.0.x`) changes; `...` deletes a key."""
        rec = self.tool.sample_record()
        for dotted, value in changes.items():
            *parents, last = dotted.split(".")
            target = rec
            for p in parents:
                target = target[int(p)] if isinstance(target, list) else target[p]
            if value is ...:
                del target[last]
            else:
                target[last] = value
        return rec

    def problems(self, **changes):
        return self.tool.validate(self.record(**changes))

    def assertRejected(self, changes, needle):
        problems = self.problems(**changes)
        self.assertTrue(any(needle in p for p in problems), (needle, problems))

    def test_a_valid_simulator_record_passes(self):
        self.assertEqual(self.tool.validate(self.tool.sample_record()), [])
        self.assertEqual(self.tool.sample_record()["environment"]["kind"], "simulator")

    def test_each_field_group_missing_is_rejected_by_name(self):
        for group in self.GROUPS:
            with self.subTest(group=group):
                problems = self.problems(**{group: ...})
                self.assertIn(f"{group}: missing", problems)

    def test_wrong_type_schema_hash_and_result(self):
        self.assertRejected({"seed": 42}, "seed: expected a decimal string")
        self.assertRejected({"schema": 0}, "unknown")
        self.assertRejected({"schema": 2}, "newer")
        self.assertRejected({"digests.initial": "a" * 63}, "digests.initial")
        self.assertRejected({"steps.0.digest": "a" * 63}, "steps[0].digest")
        self.assertRejected({"result": "ok"}, "result")

    def test_pass_rules(self):
        self.assertRejected({"failures": ["boom"]}, "failures")
        self.assertRejected({"steps": [], "digests.initial": None, "digests.final": None}, "steps")
        self.assertRejected({"scenario": "launch-first-frame", "frames": []}, "frames")
        self.assertRejected({"scenario": "hero", "frames.0.non_blank": False}, "frames")
        self.assertRejected({"result": "fail", "failures": []}, "failures")
        self.assertEqual(self.problems(scenario="cancel-prepare", steps=[], **{"digests.initial": None,
                                                                             "digests.final": None}), [])
        self.assertEqual(self.problems(result="fail", failures=["digest mismatch"]), [])

    def test_identifiers_and_kind(self):
        self.assertRejected({"artifacts.log": ".autonomy/logs/" + "-".join(["0A1B2C3D", "0000", "4000", "8000", "0000" + "0000ABCD"]) + "/x.log"},
                            "artifacts.log")
        self.assertRejected({"environment.device_type": "0x" + "001A2B3C" + "4D5E6F7"}, "environment.device_type")
        self.assertRejected({"environment.kind": "emulator"}, "environment.kind")
        self.assertRejected({"extra": True}, "extra")
        self.assertRejected({"environment.kind": "device", "environment.udid": "none"}, "environment.udid")

    def test_a_device_record_without_identifiers_passes(self):
        self.assertEqual(self.problems(**{"environment.kind": "device"}), [])

    def test_cli_exit_codes_and_self_test(self):
        tool = self.tool
        with tempfile.TemporaryDirectory() as d:
            good, bad, broken = Path(d) / "good.json", Path(d) / "bad.json", Path(d) / "broken.json"
            good.write_text(json.dumps(tool.sample_record()))
            bad.write_text(json.dumps(self.record(result="ok")))
            broken.write_text("{not json")
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                self.assertEqual(tool.main([str(good)]), 0)
                self.assertEqual(tool.main([str(good), str(bad)]), 1)
                self.assertEqual(tool.main([str(broken)]), 1)
                self.assertEqual(tool.main(["--self-test"]), 0)
            lines = out.getvalue().splitlines()
            self.assertIn(f"PASS: {good}", lines)
            self.assertTrue(any(l.startswith(f"FAIL: {bad}: result") for l in lines), lines)
            self.assertTrue(any(l.startswith(f"FAIL: {broken}: file: not valid JSON") for l in lines), lines)
            self.assertTrue(lines[-1].startswith("PASS: self-test ("), lines[-1])
            self.assertTrue(tool.validate_file(broken))
        proc = subprocess.run([sys.executable, str(HERE / "check_evidence.py"), "--self-test"],
                              capture_output=True, text=True)
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)


class ForbiddenTextTests(unittest.TestCase):
    """Feature UA-F04 T-U04-014 (FR-U04-004): `check_release_symbols.py --forbid`."""

    def check(self, args, main_nm="0000 T _main\n", main_bytes=b"\x00plain\x00", fw_nm="0000 T _helper\n",
              fw_bytes=b"\x00other\x00", nm_exit=0):
        import plistlib
        with tempfile.TemporaryDirectory() as d:
            app = Path(d) / "VisualCore.app"
            fw = app / "Frameworks" / "Kit.framework"
            fw.mkdir(parents=True)
            for folder, name, data in [(app, "VisualCore", main_bytes), (fw, "Kit", fw_bytes)]:
                (folder / "Info.plist").write_bytes(plistlib.dumps({"CFBundleExecutable": name}))
                (folder / name).write_bytes(data)

            def fake_run(cmd, **kw):
                self.assertEqual(cmd[:3], ["xcrun", "nm", "-U"])
                text = fw_nm if cmd[3].endswith("Kit.framework/Kit") else main_nm
                return subprocess.CompletedProcess(cmd, nm_exit, stdout=text, stderr="nm: broken")

            out = io.StringIO()
            with mock.patch.object(relsym.subprocess, "run", fake_run), contextlib.redirect_stdout(out), \
                    contextlib.redirect_stderr(io.StringIO()):
                code = relsym.main(["--app", str(app)] + args)
        return code, out.getvalue()

    def test_loose_libraries_of_the_app_are_searched(self):
        """A debug build keeps the app's code in `<name>.debug.dylib` beside the executable; the search covers loose
        libraries in the app folder and in Frameworks."""
        import plistlib
        with tempfile.TemporaryDirectory() as d:
            app = Path(d) / "VisualCore.app"
            (app / "Frameworks").mkdir(parents=True)
            (app / "Info.plist").write_bytes(plistlib.dumps({"CFBundleExecutable": "VisualCore"}))
            for path in (app / "VisualCore", app / "VisualCore.debug.dylib", app / "Frameworks" / "libX.dylib"):
                path.write_bytes(b"x")
            self.assertEqual([p.relative_to(app).as_posix() for p in relsym.binaries(app)],
                             ["VisualCore", "Frameworks/libX.dylib", "VisualCore.debug.dylib"])

    def test_no_hit_passes(self):
        code, out = self.check(["--forbid", "DebugLaunch", "vcFixtureCatalog"])
        self.assertEqual(code, 0)
        self.assertEqual(out.splitlines()[-1], "PASS: 0 of 2 forbidden texts found (expected 0)")

    def test_hit_in_symbols_fails_naming_text_and_binary(self):
        code, out = self.check(["--forbid", "DebugLaunch", "vcFixtureCatalog"],
                               main_nm="0000 T _$s10VisualCore11DebugLaunchV\n")
        self.assertEqual(code, 1)
        self.assertIn("'DebugLaunch' found in VisualCore.app/VisualCore (symbols)", out)
        self.assertEqual(out.splitlines()[-1],
                         "FAIL: 1 of 2 forbidden texts found (expected 0): DebugLaunch in VisualCore.app/VisualCore")

    def test_hit_in_the_bytes_of_an_embedded_framework_fails(self):
        code, out = self.check(["--forbid", "DebugLaunch", "openExperience"], fw_bytes=b"\x00-openExperience\x00")
        self.assertEqual(code, 1)
        self.assertIn("'openExperience' found in VisualCore.app/Frameworks/Kit.framework/Kit (strings)", out)
        self.assertNotIn("'DebugLaunch' found", out)

    def test_expect_present_inverts(self):
        args = ["--forbid", "DebugLaunch", "vcFixtureCatalog", "--expect-present"]
        code, out = self.check(args, main_nm="0000 T _DebugLaunch\n", fw_bytes=b"vcFixtureCatalog")
        self.assertEqual(code, 0)
        self.assertEqual(out.splitlines()[-1], "PASS: 2 of 2 texts present (expected all)")
        code, out = self.check(args, main_nm="0000 T _DebugLaunch\n")
        self.assertEqual(code, 1)
        self.assertIn("'vcFixtureCatalog' not found in any binary", out)
        self.assertEqual(self.check(args)[0], 1)

    def test_nm_failure_is_exit_2(self):
        self.assertEqual(self.check(["--forbid", "DebugLaunch"], nm_exit=1)[0], 2)

    def test_without_forbid_the_check_is_unchanged(self):
        code, out = self.check([])
        self.assertEqual(code, 0)
        self.assertEqual(out.splitlines()[-1], "PASS: 0 automation symbols, 0 trigger strings (expected 0)")
        # The texts that --forbid would look for are not part of the built-in check.
        code, out = self.check([], main_nm="0000 T _DebugLaunch\n", main_bytes=b"vcFixtureCatalog")
        self.assertEqual(code, 0)
        code, out = self.check([], main_nm="0000 T _$s20VisualCoreAutomation6RunnerC\n")
        self.assertEqual(code, 1)
        self.assertIn("VisualCore.app/VisualCore: 1 automation symbols, 0 trigger strings", out)
        self.assertEqual(out.splitlines()[-1], "FAIL: 1 automation symbols, 0 trigger strings (expected 0)")
        code, out = self.check([], fw_bytes=b"\x00VISUALCORE_AUTORUN\x00")
        self.assertEqual(code, 1)
        code, out = self.check(["--expect-present"], main_nm="0000 T _AutomationRunner\n")
        self.assertEqual((code, out.splitlines()[-1]),
                         (0, "PASS: measurement build has 1 automation symbols (expected > 0)"))
        self.assertEqual(self.check(["--expect-present"])[0], 1)


class VersionTests(unittest.TestCase):
    """Feature 010 T-F913: every module carries the same release version (1.0.0-rc.1)."""

    def test_every_module_version_matches(self):
        import re
        root = HERE.parent
        found = {}
        for f in sorted(root.glob("Packages/*/Sources/*/Module.swift")):
            m = re.search(r'version = "([^"]+)"', f.read_text())
            self.assertIsNotNone(m, f"{f} has no version constant")
            found[f.parent.name] = m.group(1)
        self.assertGreaterEqual(len(found), 14)
        self.assertEqual(set(found.values()), {"1.0.0-rc.1"}, found)
        self.assertTrue((root / "docs/release/release-notes-1.0.0-rc.1.md").is_file())


class AppContractTests(unittest.TestCase):
    """Feature 011 T-A01-003: app-neutral VisualCore contract checker (FR-A01-003)."""
    FIX = HERE / "fixtures" / "app_contract"

    def run_checker(self, root: Path, *extra: str) -> tuple[int, str]:
        import contextlib, io
        out = io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(io.StringIO()):
            code = appcontract.main(["--app", "demo", "--root", str(root), *extra])
        return code, out.getvalue()

    def test_good_fixture_passes(self):
        code, out = self.run_checker(self.FIX / "good")
        self.assertEqual(code, 0, out)
        self.assertIn("PASS: 2 rows, 3 citations, 1 gaps, decision go", out)

    def test_bad_fixture_reports_every_problem_by_row(self):
        code, out = self.run_checker(self.FIX / "bad")
        self.assertEqual(code, 1)
        for expected in ["M01: Packages/Demo/Sources/DemoKit/Nope.swift:Widget: file not found",
                         "M02: Packages/Demo/Sources/DemoKit/Widget.swift:Widget.twirl: symbol 'twirl' not declared public",
                         "M03: Packages/Demo/Sources/DemoKit/Widget.swift:Widget.hidden: symbol 'hidden' not declared public",
                         "M04: Packages/Demo/Sources/DemoKit/Widget.swift:Widget: unknown product 'Nonexistent'",
                         "M05: requires adaptation row has no gap entry",
                         "M06: Packages/Demo/Tests/DemoKitTests/WidgetTests.swift:WidgetProbe: evidence must be shippable",
                         "M07: External/ref/Engine.swift:Engine: evidence must be shippable",
                         "M08: upstream gap needs evidence or notes",
                         "G-LOCAL: app-local gap needs a justification",
                         "decision: go with blockers",
                         "M08: needs an example consumer",
                         "inventory ghost: path Packages/Demo/Sources/DemoKit/Gone.swift not found"]:
            self.assertIn(expected, out)
        self.assertIn("FAIL: 12 problem(s)", out)

    def test_closed_gaps_do_not_cover_open_rows(self):
        import shutil
        with tempfile.TemporaryDirectory() as t:
            root = Path(t) / "good"
            shutil.copytree(self.FIX / "good", root)
            path = root / "docs/apps/demo/visualcore-contract.json"
            data = json.loads(path.read_text())
            data["gaps"][0]["closed"] = "A00-P01"
            path.write_text(json.dumps(data))
            code, out = self.run_checker(root)
            self.assertEqual(code, 1)
            self.assertIn("M02: upstream gap row has no gap entry", out)
            data["matrix"][1]["status"] = "available"
            data["matrix"][1]["evidence"] = [{"file": "Packages/Demo/Sources/DemoKit/Widget.swift", "symbol": "Widget", "product": "DemoKit", "public": True}]
            path.write_text(json.dumps(data))
            self.assertEqual(self.run_checker(root)[0], 0)
            data["gaps"][0]["closed"] = "yesterday"
            path.write_text(json.dumps(data))
            self.assertIn("closed must name the gate", self.run_checker(root)[1])

    def test_products_include_mapped_array_names(self):
        self.assertEqual(appcontract.products(self.FIX / "good"), {"DemoKit", "DemoExtra"})
        real = appcontract.products(HERE.parent)
        self.assertTrue({"VisualCoreMath", "VisualCoreRendering", "VisualCoreEffects"} <= real)

    def test_render_is_idempotent(self):
        import shutil
        with tempfile.TemporaryDirectory() as t:
            root = Path(t) / "good"
            shutil.copytree(self.FIX / "good", root)
            md = root / "docs/apps/demo/visualcore-contract.md"
            self.assertEqual(self.run_checker(root, "--render")[0], 0)
            first = md.read_text()
            self.assertIn("| M01 | spin |", first)
            self.assertIn("**GO**", first)
            self.run_checker(root, "--render")
            self.assertEqual(md.read_text(), first)

    def test_schema_errors_exit_2(self):
        with tempfile.TemporaryDirectory() as t:
            d = Path(t) / "docs/apps/demo"
            d.mkdir(parents=True)
            (d / "visualcore-contract.json").write_text('{"schema": 1, "surprise": true}')
            self.assertEqual(self.run_checker(Path(t))[0], 2)
            (d / "visualcore-contract.json").write_text('{"schema": 2}')
            self.assertEqual(self.run_checker(Path(t))[0], 2)
            (d / "visualcore-contract.json").write_text('{"schema": 1, "matrix": [{"id": "M", "notes": "' + "x" * 2001 + '"}]}')
            self.assertEqual(self.run_checker(Path(t))[0], 2)
        self.assertEqual(appcontract.main(["--app", "../etc"]), 2)


class TestEnumerationTests(unittest.TestCase):
    def test_a_parallel_log_counts_its_passed_tests(self):
        import contextlib, io
        guard = load("check_test_enumeration")
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            (root / "T.swift").write_text("final class A: XCTestCase {\n    func testOne() {}\n}\n")
            (root / "log").write_text("Test case 'A.testOne()' passed on 'Clone 1 of iPhone - Runner (1)' (1.0 seconds)\n")
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(guard.main(["--sources", d, "--log", str(root / "log")]), 0)

    def test_a_method_id_limits_the_guard_to_that_method(self):
        import contextlib, io
        guard = load("check_test_enumeration")
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            (root / "T.swift").write_text("final class A: XCTestCase {\n    func testOne() {}\n    func testTwo() {}\n}\n")
            (root / "log").write_text("Test Case '-[UI.A testOne]' passed (1.0 seconds).\n")
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(guard.main(["--sources", d, "--log", str(root / "log"), "--only", "A/testOne"]), 0)
                self.assertEqual(guard.main(["--sources", d, "--log", str(root / "log"), "--only", "A"]), 1)

    def test_missing_class_fails_and_full_run_passes(self):
        with tempfile.TemporaryDirectory() as t:
            d = Path(t)
            (d / "src").mkdir()
            (d / "src" / "A.swift").write_text("final class AUITests: XCTestCase {\n    func testOne() {}\n    func helper() {}\n}\n"
                                             "class BUITests: XCTestCase {\n    @MainActor func testTwo() throws {}\n}\n")
            log = d / "log"
            log.write_text("Test Case '-[T.AUITests testOne]' passed (1 s).\n")
            self.assertEqual(enumeration.main(["--sources", str(d / "src"), "--log", str(log)]), 1)
            self.assertEqual(enumeration.main(["--sources", str(d / "src"), "--log", str(log), "--only", "AUITests"]), 0)
            log.write_text(log.read_text() + "Test Case '-[T.BUITests testTwo]' passed (1 s).\n")
            self.assertEqual(enumeration.main(["--sources", str(d / "src"), "--log", str(log)]), 0)
            self.assertEqual(enumeration.main(["--sources", str(d / "nope"), "--log", str(log)]), 2)


class TestMapTests(unittest.TestCase):
    """scripts/check_test_map.py: no interface test of a standalone app is lost in the unified app (T-U07-002)."""

    HEADER = "app,old_class,old_method,new_class,new_method,note\n"

    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.d = Path(self._tmp.name)
        (self.d / "old").mkdir()
        (self.d / "new").mkdir()
        (self.d / "old" / "A.swift").write_text("final class AUITests: XCTestCase {\n    func testOne() {}\n"
                                               "    @MainActor func testTwo() throws {}\n    func helper() {}\n}\n")
        (self.d / "old" / "B.swift").write_text("class BUITests: XCTestCase {\n    func testThree() {}\n}\n")
        (self.d / "new" / "N.swift").write_text("final class NewAUITests: XCTestCase {\n    func testOneA() {}\n"
                                               "    func testOneB() {}\n    func testTwo() {}\n}\n"
                                               "final class NewBUITests: XCTestCase {\n    func testThree() {}\n}\n")
        self.rows = ["A,AUITests,testOne,NewAUITests,testOneA;testOneB,",
                     "A,AUITests,testTwo,NewAUITests,testTwo,",
                     "B,BUITests,testThree,NewBUITests,testThree,"]

    def tearDown(self):
        self._tmp.cleanup()

    def run_map(self, rows, *extra, header=None):
        m = self.d / "map.csv"
        m.write_text((header if header is not None else self.HEADER) + "".join(r + "\n" for r in rows))
        out = io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(io.StringIO()):
            code = testmap.main(["--map", str(m), "--old", str(self.d / "old"), "--new", str(self.d / "new"), *extra])
        return code, out.getvalue()

    def test_complete_map_passes_and_splits_method_lists(self):
        code, out = self.run_map(self.rows)
        self.assertEqual(code, 0, out)
        self.assertEqual(out.strip().splitlines()[-1], "PASS: 3 old tests mapped to 4 new tests")

    def test_missing_old_method_fails_naming_it(self):
        code, out = self.run_map(self.rows[:1] + self.rows[2:])
        self.assertEqual(code, 1)
        self.assertIn("FAIL: missing from the map: AUITests.testTwo", out)
        self.assertEqual(out.strip().splitlines()[-1], "FAIL: 1 problems")

    def test_row_for_nonexistent_old_test_fails(self):
        code, out = self.run_map(self.rows + ["A,AUITests,testGone,NewAUITests,testTwo,"])
        self.assertEqual(code, 1)
        self.assertIn("FAIL: not an old test: AUITests.testGone", out)

    def test_duplicate_old_row_fails(self):
        code, out = self.run_map(self.rows + [self.rows[1]])
        self.assertEqual(code, 1)
        self.assertIn("FAIL: mapped 2 times: AUITests.testTwo", out)

    def test_nonexistent_new_method_fails(self):
        rows = ["A,AUITests,testOne,NewAUITests,testOneA;testOneZ,"] + self.rows[1:]
        code, out = self.run_map(rows)
        self.assertEqual(code, 1)
        self.assertIn("FAIL: no such new test: NewAUITests.testOneZ", out)
        self.assertNotIn("testOneA", out)

    def test_no_counterpart_row_needs_a_covering_test_in_the_note(self):
        base = self.rows[:2]
        code, out = self.run_map(base + ["B,BUITests,testThree,-,-,"])
        self.assertEqual(code, 1)
        self.assertIn("no covering Class.method in the note: BUITests.testThree", out)
        code, out = self.run_map(base + ["B,BUITests,testThree,-,-,the gallery replaces it; covered by NewAUITests.testMissing"])
        self.assertEqual(code, 1)
        self.assertIn("FAIL: no such new test: NewAUITests.testMissing", out)
        code, out = self.run_map(base + ['B,BUITests,testThree,-,-,"unified app equivalent, covered by NewBUITests.testThree"'])
        self.assertEqual(code, 0, out)

    def test_log_requires_every_mapped_and_covering_test_to_pass(self):
        rows = self.rows[:2] + ["B,BUITests,testThree,-,-,covered by NewBUITests.testThree"]
        lines = ["Test Case '-[VisualCoreUITests.NewAUITests testOneA]' passed (1.0 seconds).",
                 "Test Case '-[VisualCoreUITests.NewAUITests testOneB]' passed (1.0 seconds).",
                 "Test Case '-[VisualCoreUITests.NewAUITests testTwo]' failed (1.0 seconds).",
                 "Test Case '-[VisualCoreUITests.NewBUITests testThree]' passed (1.0 seconds)."]
        log1 = self.d / "one.log"
        log1.write_text("\n".join(lines) + "\n")
        code, out = self.run_map(rows, "--log", str(log1))
        self.assertEqual(code, 1)
        self.assertIn("FAIL: did not pass: NewAUITests.testTwo", out)
        self.assertEqual(out.count("did not pass"), 1)
        log2 = self.d / "two.log"
        log2.write_text("Test Case '-[VisualCoreUITests.NewAUITests testTwo]' passed (2.0 seconds).\n")
        code, out = self.run_map(rows, "--log", str(log1), str(log2))
        self.assertEqual(code, 0, out)
        self.assertIn("PASS: 3 old tests mapped to 4 new tests", out)

    def test_app_limits_the_rows(self):
        (self.d / "old" / "B.swift").unlink()
        code, out = self.run_map(self.rows, "--app", "A")
        self.assertEqual(code, 0, out)
        self.assertIn("PASS: 2 old tests mapped to 3 new tests", out)
        code, out = self.run_map(self.rows)
        self.assertEqual(code, 1)
        self.assertIn("FAIL: not an old test: BUITests.testThree", out)

    def test_bad_input_exits_2(self):
        code, _ = self.run_map(self.rows, header="app,old_class,old_method,new_class,new_method\n")
        self.assertEqual(code, 2)
        code, _ = self.run_map(self.rows, "--log", str(self.d / "absent.log"))
        self.assertEqual(code, 2)
        out = io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(io.StringIO()):
            code = testmap.main(["--map", str(self.d / "absent.csv"), "--old", str(self.d / "old"), "--new", str(self.d / "new")])
        self.assertEqual(code, 2)


class PrivacyManifestTests(unittest.TestCase):
    clean = {"NSPrivacyTracking": False, "NSPrivacyTrackingDomains": [], "NSPrivacyCollectedDataTypes": [],
             "NSPrivacyAccessedAPITypes": []}

    def test_detects_each_category(self):
        found = privacy.scan(["_OBJC_CLASS_$_NSUserDefaults", "_stat$INODE64", "_mach_absolute_time", "_statfs$INODE64",
                              "_printf"], ["activeInputModes"])
        self.assertEqual(set(found), {f"NSPrivacyAccessedAPICategory{c}" for c in
                                      ["UserDefaults", "FileTimestamp", "SystemBootTime", "DiskSpace", "ActiveKeyboards"]})
        self.assertEqual(privacy.scan(["_printf", "_malloc"], ["hello"]), {})
        self.assertIn("NSPrivacyAccessedAPICategoryFileTimestamp", privacy.scan([], ["NSFileModificationDate"]))
        self.assertIn("NSPrivacyAccessedAPICategoryUserDefaults",
                      privacy.scan(["_$s7SwiftUI10AppStorageV12wrappedValuexvg"], []), "@AppStorage counts as UserDefaults")

    def test_compare_reports_undeclared_unused_and_violations(self):
        detected = {"NSPrivacyAccessedAPICategoryUserDefaults": ["x"]}
        ok = dict(self.clean, NSPrivacyAccessedAPITypes=[{"NSPrivacyAccessedAPIType": "NSPrivacyAccessedAPICategoryUserDefaults",
                                                         "NSPrivacyAccessedAPITypeReasons": ["CA92.1"]}])
        r = privacy.compare(detected, ok)
        self.assertEqual((r["undeclared"], r["unused"], r["violations"]), ([], [], []))
        r = privacy.compare(detected, self.clean)
        self.assertEqual(r["undeclared"], ["NSPrivacyAccessedAPICategoryUserDefaults"])
        r = privacy.compare({}, ok)
        self.assertEqual(r["unused"], ["NSPrivacyAccessedAPICategoryUserDefaults"])
        r = privacy.compare({}, dict(self.clean, NSPrivacyTracking=True, NSPrivacyCollectedDataTypes=[{"a": 1}]))
        self.assertEqual(len(r["violations"]), 2)
        bad = dict(self.clean, NSPrivacyAccessedAPITypes=[{"NSPrivacyAccessedAPIType": "X", "NSPrivacyAccessedAPITypeReasons": []}])
        self.assertTrue(any("no reason" in v for v in privacy.compare({}, bad)["violations"]))

    def test_bad_input_exits_2(self):
        with tempfile.TemporaryDirectory() as t:
            self.assertEqual(privacy.main(["--app", str(Path(t) / "Missing.app")]), 2)


class AppReleaseTests(unittest.TestCase):
    def make(self, d: Path, info: dict, icon=True, manifest=True):
        import plistlib
        app = d / "X.app"
        app.mkdir()
        with open(app / "Info.plist", "wb") as f:
            plistlib.dump(info, f)
        if manifest:
            (app / "PrivacyInfo.xcprivacy").write_bytes(b"x")
        if icon:
            (app / "Assets.car").write_bytes(b"x")
        (d / "docs").mkdir()
        (d / "docs" / "a.md").write_text("x")
        (d / "docs" / "check.md").write_text("| Area | Item | Status | Evidence |\n|---|---|---|---|\n"
                                             "| Privacy | manifest | verified | scan |\n| Store | upload | owner-action | steps |\n")
        return app

    good = {"CFBundleIdentifier": "dev.x", "CFBundleShortVersionString": "1.0.0", "CFBundleVersion": "1",
            "ITSAppUsesNonExemptEncryption": False, "CFBundleIconName": "AppIcon", "NSPhotoLibraryAddUsageDescription": "Saves."}
    config = {"bundleID": "dev.x", "version": "1.0.0", "build": 1, "allowedUsageDescriptions": ["NSPhotoLibraryAddUsageDescription"],
              "requiredDocs": ["docs/a.md"], "checklist": "docs/check.md"}

    def run_check(self, info, **kw):
        with tempfile.TemporaryDirectory() as t:
            d = Path(t)
            app = self.make(d, info, **kw)
            return {n: ok for n, ok, _ in appreleasecheck.check(app, self.config, d)}

    def test_passes_and_each_failure(self):
        self.assertTrue(all(self.run_check(self.good).values()))
        self.assertFalse(self.run_check(dict(self.good, NSCameraUsageDescription="x"))["usage descriptions"])
        self.assertFalse(self.run_check(dict(self.good, CFBundleShortVersionString="0.1"))["version"])
        info = dict(self.good); del info["ITSAppUsesNonExemptEncryption"]
        self.assertFalse(self.run_check(info)["export compliance key"])
        self.assertFalse(self.run_check(self.good, icon=False)["app icon"])
        self.assertFalse(self.run_check(self.good, manifest=False)["privacy manifest"])

    def test_checklist_rows_need_status_and_evidence(self):
        ok = "| Area | Item | Status | Evidence |\n|---|---|---|---|\n| A | b | pending-campaign-ii | D1-D3 rows |\n"
        self.assertEqual(appreleasecheck.checklist_problems(ok), [])
        self.assertTrue(appreleasecheck.checklist_problems(ok.replace("pending-campaign-ii", "done")))
        self.assertTrue(appreleasecheck.checklist_problems(ok.replace("D1-D3 rows", "")))
        self.assertTrue(appreleasecheck.checklist_problems("no table"))

    def test_bad_input_exits_2(self):
        with tempfile.TemporaryDirectory() as t:
            self.assertEqual(appreleasecheck.main(["--app", str(Path(t) / "Y.app"), "--config", str(Path(t) / "c.json")]), 2)


class BundleLicensesTests(unittest.TestCase):
    def test_bundles_shipped_texts_and_generated_attributions(self):
        with tempfile.TemporaryDirectory() as t:
            d = Path(t)
            (d / "L.txt").write_text("MIT text")
            inv = {"components": [
                {"id": "a", "name": "A", "license": "MIT", "scope": "shipped", "text": "L.txt"},
                {"id": "easing", "name": "Easing", "license": "BSD-3-Clause", "scope": "shipped", "text": "notices"},
                {"id": "h", "name": "Harness", "license": "LGPL-2.1", "scope": "harness", "text": "L.txt"}]}
            self.assertEqual(licensebundle.bundle(inv, d / "out", d), [])
            index = json.loads((d / "out" / "licenses.json").read_text())
            self.assertEqual([e["id"] for e in index], ["a", "easing"], "harness-only components are never bundled")
            self.assertIn("Robert Penner", (d / "out" / "easing.txt").read_text())
            inv["components"][0]["text"] = "missing.txt"
            self.assertEqual(len(licensebundle.bundle(inv, d / "out2", d)), 1)

    def test_real_inventory_bundles_every_shipped_component(self):
        with tempfile.TemporaryDirectory() as t:
            self.assertEqual(licensebundle.main(["--out", str(Path(t) / "L")]), 0)
            inv = json.loads((ROOT_DIR / "docs/legal/third-party.json").read_text())
            shipped = {c["id"] for c in inv["components"] if c["scope"] == "shipped"}
            self.assertEqual({e["id"] for e in json.loads((Path(t) / "L" / "licenses.json").read_text())}, shipped)


# ---------------------------------------------------------------- unified-app steering tools (ADR-0009)

ledgertool = load("migration_ledger")
planidx = load("planning_index")
render = load("render_autocreator")
tracematrix = load("build_traceability_matrix")
steering = load("validate_autocreator")


class MigrationLedgerTests(unittest.TestCase):
    """The migration ledger refuses everything that is not real, ordered evidence."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        for rel in ("docs/catalog/experience-catalog.json", "docs/catalog/feature-index.json",
                    "docs/catalog/unified-app-features.json", ".autonomy/state.json"):
            (self.root / rel).parent.mkdir(parents=True, exist_ok=True)
            (self.root / rel).write_bytes((ROOT_DIR / rel).read_bytes())
        (self.root / "ok.py").write_text("print('ok')\n")
        (self.root / "bad.py").write_text("raise SystemExit(3)\n")
        self.assertEqual(ledgertool.main(["init"], self.root), 0)

    def tearDown(self):
        self.tmp.cleanup()

    def run_tool(self, *argv):
        return ledgertool.main(list(argv), self.root)

    def refuses(self, text, *argv):
        with self.assertRaises(SystemExit) as raised:
            self.run_tool(*argv)
        self.assertIn(text, str(raised.exception))

    def ledger(self):
        return json.loads((self.root / ledgertool.LEDGER).read_text())

    def force(self, statuses):
        """Test helper only: write gate statuses directly, as no real tool may."""
        data = self.ledger()
        for g in data["gates"]:
            if g["id"] in statuses:
                g["status"] = statuses[g["id"]]
        (self.root / ledgertool.LEDGER).write_text(ledgertool.dump_ledger(data))

    def pass_gate(self, gate, name="ok"):
        self.assertEqual(self.run_tool("run-check", "--gate", gate, "--name", name, "--", sys.executable, "ok.py"), 0)
        self.assertEqual(self.run_tool("seal", "--gate", gate), 0)
        self.assertEqual(self.run_tool("record", "--gate", gate), 0)

    def test_structure(self):
        data = self.ledger()
        kinds = {}
        for g in data["gates"]:
            kinds[g["kind"]] = kinds.get(g["kind"], 0) + 1
        self.assertEqual(kinds["experience"], 100)
        self.assertEqual(kinds["device-row"], 300)
        self.assertEqual(kinds["unified-feature"], 15)
        self.assertEqual(kinds["game-feature"], 750)
        self.assertEqual(ledgertool.validate(self.root), [])
        self.assertEqual(data["gates"][0]["id"], "M0-CONSOLIDATION")
        self.refuses("exists", "init")

    def test_order_is_enforced(self):
        self.refuses("not ready", "run-check", "--gate", "CONSTITUTION-2", "--name", "x", "--", sys.executable, "ok.py")
        self.refuses("not ready", "run-check", "--gate", "UA-F08", "--name", "x", "--", sys.executable, "ok.py")
        self.pass_gate("M0-CONSOLIDATION")
        self.assertEqual(self.ledger()["gates"][0]["status"], "pass")
        self.refuses("already pass", "run-check", "--gate", "M0-CONSOLIDATION", "--name", "again", "--", sys.executable, "ok.py")
        self.pass_gate("CONSTITUTION-2")
        self.assertEqual(ledgertool.validate(self.root), [])
        self.assertEqual(ledgertool.next_actions(self.ledger(), ledgertool.legacy_state(self.root))[0][0]["id"], "UA-F00")

    def test_purchase_waits_for_the_free_lock(self):
        gates = {g["id"]: g for g in self.ledger()["gates"]}
        self.assertIn("LOCK-FREE-50", gates["UA-F08"]["depends"])
        self.assertIn("UA-F08", gates["R03-F02"]["depends"])
        self.assertIn("UA-F08", gates["X-R03-G01"]["depends"])
        self.assertNotIn("UA-F08", gates["X-R02-G01"]["depends"])
        self.assertIn("UA-F13", gates["ImplementationLock-100"]["depends"])

    def test_attestations_are_single_use_and_logs_are_hashed(self):
        ok = ["--", sys.executable, "ok.py"]
        self.assertEqual(self.run_tool("run-check", "--gate", "M0-CONSOLIDATION", "--name", "a", *ok), 0)
        self.refuses("already recorded", "run-check", "--gate", "M0-CONSOLIDATION", "--name", "a", *ok)
        log = self.root / ledgertool.LOGS / "M0-CONSOLIDATION.a.log"
        log.write_text(log.read_text() + "edited\n")
        self.refuses("changed since the command ran", "seal", "--gate", "M0-CONSOLIDATION")

    def test_failed_command_cannot_pass_a_gate(self):
        self.assertNotEqual(self.run_tool("run-check", "--gate", "M0-CONSOLIDATION", "--name", "bad", "--", sys.executable, "bad.py"), 0)
        self.refuses("no passing attestation", "seal", "--gate", "M0-CONSOLIDATION")
        self.refuses("seal the gate first", "record", "--gate", "M0-CONSOLIDATION")

    def test_claude_cli_is_refused(self):
        self.refuses("Claude CLI is prohibited", "run-check", "--gate", "M0-CONSOLIDATION", "--name", "x", "--", "claude", "-p", "hello")

    def test_evidence_commands_are_argument_lists(self):
        self.refuses("no shell wrapper", "run-check", "--gate", "M0-CONSOLIDATION", "--name", "x", "--", "/bin/sh", "-c", "true")
        self.refuses("no shell wrapper", "run-check", "--gate", "M0-CONSOLIDATION", "--name", "x", "--", "zsh", "script.zsh")
        self.refuses("no inline script", "run-check", "--gate", "M0-CONSOLIDATION", "--name", "x", "--", sys.executable, "-c", "print(1)")
        self.refuses("requires a command", "run-check", "--gate", "M0-CONSOLIDATION", "--name", "x")
        self.refuses("alphanumeric", "run-check", "--gate", "M0-CONSOLIDATION", "--name", "bad name", "--", sys.executable, "ok.py")

    def test_devices_are_guarded_by_the_lock(self):
        self.refuses("no physical-device", "guard-device")
        self.refuses("not ready", "run-check", "--gate", "DEV1-A01", "--name", "x", "--", sys.executable, "ok.py")
        self.force({"DEV1-A01": "pass"})
        self.assertTrue(any("device gate recorded before" in p or "without recorded evidence" in p for p in ledgertool.validate(self.root)))

    def test_original_apps_need_their_legacy_gates(self):
        self.force({g: "pass" for g in ("M0-CONSOLIDATION", "CONSTITUTION-2", "UA-F00", "UA-F01", "UA-F02", "UA-F03", "UA-F04",
                                         "UA-F05", "UA-F06", "UA-F07", "UA-F09", "UA-F10", "UA-F11", "UA-F12")})
        data, legacy = self.ledger(), ledgertool.legacy_state(self.root)
        gates = ledgertool.index_of(data)
        self.assertEqual(ledgertool.unmet(gates["X-A01"], gates, legacy["stages"]), [])
        self.assertIn("legacy:A04-P04", ledgertool.unmet(gates["X-A04"], gates, legacy["stages"]))
        actions = ledgertool.next_actions(data, legacy, limit=40)
        waiting = [why for g, why in actions if "legacy" in why]
        self.assertEqual(len(waiting), 1)
        self.assertIn("A04-P04", waiting[0])
        legacy_before = (self.root / ledgertool.LEGACY).read_bytes()
        self.refuses("legacy:A04-P04", "run-check", "--gate", "X-A04", "--name", "x", "--", sys.executable, "ok.py")
        self.refuses("legacy:A04-P04", "seal", "--gate", "X-A04")
        self.refuses("legacy:A04-P04", "record", "--gate", "X-A04")
        self.assertEqual((self.root / ledgertool.LEGACY).read_bytes(), legacy_before)  # FR-U00-035: the legacy ledger is never written

    def test_tampered_evidence_is_detected(self):
        self.pass_gate("M0-CONSOLIDATION")
        evidence = self.root / ledgertool.EVIDENCE / "M0-CONSOLIDATION.json"
        evidence.write_text(evidence.read_text().replace('"exit_code": 0', '"exit_code": 0 '))
        self.assertTrue(any("evidence file changed" in p for p in ledgertool.validate(self.root)))

    def test_reverification_keeps_every_revision(self):
        self.pass_gate("M0-CONSOLIDATION")
        ok = ["--", sys.executable, "ok.py"]
        self.assertEqual(self.run_tool("run-check", "--gate", "M0-CONSOLIDATION", "--name", "second", "--reverify", *ok), 0)
        self.assertEqual(self.run_tool("seal", "--gate", "M0-CONSOLIDATION", "--reverify"), 0)
        self.assertEqual(self.run_tool("record", "--gate", "M0-CONSOLIDATION", "--reverify"), 0)
        attempts = self.ledger()["gates"][0]["attempts"]
        self.assertEqual([a["evidence"].rsplit("/", 1)[1] for a in attempts], ["M0-CONSOLIDATION.json", "M0-CONSOLIDATION.r2.json"])
        second = json.loads((self.root / attempts[1]["evidence"]).read_text())
        self.assertEqual([c["name"] for c in second["passing_checks"]], ["second"])
        self.assertEqual(ledgertool.validate(self.root), [])
        self.refuses("no new run-check attestation", "seal", "--gate", "M0-CONSOLIDATION", "--reverify")

    def test_block_and_unblock(self):
        self.assertEqual(self.run_tool("block", "--gate", "M0-CONSOLIDATION", "--reason", "BLOCKED_OWNER_ACTION: test"), 0)
        self.refuses("is blocked", "run-check", "--gate", "M0-CONSOLIDATION", "--name", "x", "--", sys.executable, "ok.py")
        self.assertEqual(self.run_tool("unblock", "--gate", "M0-CONSOLIDATION", "--note", "resolved"), 0)
        self.assertEqual(self.ledger()["gates"][0]["status"], "pending")
        self.refuses("after RELEASE-PREP", "add-round", "--round", "5")

    # ---- feature 186 (UA-F00): every refusal also for seal and record; damaged files stop the tool cleanly

    def tree(self):
        """Every file of the temporary ledger tree with its bytes: what a refusal must leave untouched."""
        base = self.root / ".autonomy" / "migration"
        return {f.relative_to(base).as_posix(): f.read_bytes() for f in sorted(base.rglob("*")) if f.is_file()}

    def test_seal_and_record_are_refused_for_an_unmet_dependency(self):
        before = self.tree()
        for command in ("seal", "record"):
            self.refuses("CONSTITUTION-2 is not ready; unmet: M0-CONSOLIDATION", command, "--gate", "CONSTITUTION-2")
        self.assertEqual(self.tree(), before)

    def test_device_gates_are_refused_for_every_command_before_the_lock(self):
        self.force({g: "pass" for g in ("M0-CONSOLIDATION", "CONSTITUTION-2", "UA-F13")})
        before = self.tree()
        for gate in ("DEV1-A01", "DEV1-CAMPAIGN", "DEV3-R04-G25"):
            self.refuses("ImplementationLock-100", "run-check", "--gate", gate, "--name", "x", "--", sys.executable, "ok.py")
            self.refuses("ImplementationLock-100", "seal", "--gate", gate)
            self.refuses("ImplementationLock-100", "record", "--gate", gate)
        self.refuses("no physical-device install, launch or test before ImplementationLock-100", "guard-device")
        self.assertEqual(self.tree(), before)

    def test_removed_log_cannot_be_sealed(self):
        self.assertEqual(self.run_tool("run-check", "--gate", "M0-CONSOLIDATION", "--name", "a", "--", sys.executable, "ok.py"), 0)
        (self.root / ledgertool.LOGS / "M0-CONSOLIDATION.a.log").unlink()
        self.refuses("log missing or changed since the command ran", "seal", "--gate", "M0-CONSOLIDATION")
        self.assertFalse((self.root / ledgertool.EVIDENCE / "M0-CONSOLIDATION.json").exists())

    def test_damaged_files_stop_the_tool_with_a_message(self):
        ok = ["--", sys.executable, "ok.py"]
        self.assertEqual(self.run_tool("run-check", "--gate", "M0-CONSOLIDATION", "--name", "a", *ok), 0)
        attestation = self.root / ledgertool.CHECKS / "M0-CONSOLIDATION.a.json"
        good = attestation.read_text()
        attestation.write_text("{not json")
        self.refuses("cannot read .autonomy/migration/checks/M0-CONSOLIDATION.a.json", "seal", "--gate", "M0-CONSOLIDATION")
        self.assertFalse((self.root / ledgertool.EVIDENCE / "M0-CONSOLIDATION.json").exists())
        attestation.write_text(good)
        self.assertEqual(self.run_tool("seal", "--gate", "M0-CONSOLIDATION"), 0)
        evidence = self.root / ledgertool.EVIDENCE / "M0-CONSOLIDATION.json"
        evidence.write_text("{not json")
        ledger_before = (self.root / ledgertool.LEDGER).read_bytes()
        self.refuses("cannot read .autonomy/migration/evidence/M0-CONSOLIDATION.json", "record", "--gate", "M0-CONSOLIDATION")
        self.assertEqual((self.root / ledgertool.LEDGER).read_bytes(), ledger_before)
        ledger = self.root / ledgertool.LEDGER
        ledger.write_text("{not json")
        before = self.tree()
        for argv in (["status"], ["next"], ["show", "--gate", "UA-F00"], ["validate"], ["guard-device"], ["seal", "--gate", "UA-F00"],
                     ["record", "--gate", "UA-F00"], ["run-check", "--gate", "UA-F00", "--name", "x", *ok],
                     ["block", "--gate", "UA-F00", "--reason", "r"]):
            self.refuses("cannot read .autonomy/migration/ledger.json", *argv)
        self.assertEqual(self.tree(), before)
        ledger.write_text(json.dumps({"schema": 2, "gates": []}))
        self.refuses("unexpected migration ledger schema", "status")
        ledger.unlink()
        self.refuses("migration ledger missing", "status")

    def test_pass_without_evidence_is_reported(self):
        self.force({"M0-CONSOLIDATION": "pass"})
        self.assertIn("M0-CONSOLIDATION: pass without recorded evidence", ledgertool.validate(self.root))

    def test_missing_evidence_and_early_device_gates_are_reported(self):
        # FR-U00-037
        self.pass_gate("M0-CONSOLIDATION")
        (self.root / ledgertool.EVIDENCE / "M0-CONSOLIDATION.json").unlink()
        self.assertIn("M0-CONSOLIDATION: evidence file missing: .autonomy/migration/evidence/M0-CONSOLIDATION.json",
                      ledgertool.validate(self.root))
        self.force({"DEV1-A01": "pass"})
        problems = ledgertool.validate(self.root)
        self.assertIn("DEV1-A01: device gate recorded before ImplementationLock-100", problems)
        self.assertIn("DEV1-A01: pass without recorded evidence", problems)

    def test_log_without_attestation_is_not_evidence(self):
        # Edge case "cancellation": an interrupted check leaves at most a log, which no seal accepts.
        log = self.root / ledgertool.LOGS / "M0-CONSOLIDATION.interrupted.log"
        log.parent.mkdir(parents=True, exist_ok=True)
        log.write_text("Command: python3 ok.py\n")
        self.refuses("no new run-check attestation", "seal", "--gate", "M0-CONSOLIDATION")
        self.assertFalse((self.root / ledgertool.EVIDENCE / "M0-CONSOLIDATION.json").exists())

    def test_unrecorded_evidence_is_replaced_by_the_next_seal(self):
        # Edge case "lifecycle interruption": a session ended between seal and record.
        ok = ["--", sys.executable, "ok.py"]
        self.assertEqual(self.run_tool("run-check", "--gate", "M0-CONSOLIDATION", "--name", "a", *ok), 0)
        self.assertEqual(self.run_tool("seal", "--gate", "M0-CONSOLIDATION"), 0)
        self.assertEqual(self.run_tool("run-check", "--gate", "M0-CONSOLIDATION", "--name", "b", *ok), 0)
        self.assertEqual(self.run_tool("seal", "--gate", "M0-CONSOLIDATION"), 0)
        evidence = json.loads((self.root / ledgertool.EVIDENCE / "M0-CONSOLIDATION.json").read_text())
        self.assertEqual([c["name"] for c in evidence["passing_checks"]], ["a", "b"])
        self.assertEqual(evidence["revision_number"], 1)
        self.assertFalse((self.root / ledgertool.EVIDENCE / "M0-CONSOLIDATION.r2.json").exists())
        self.assertEqual(self.run_tool("record", "--gate", "M0-CONSOLIDATION"), 0)
        self.assertEqual(ledgertool.validate(self.root), [])

    def test_only_device_rows_may_fail(self):
        self.assertNotEqual(self.run_tool("run-check", "--gate", "M0-CONSOLIDATION", "--name", "bad", "--", sys.executable, "bad.py"), 0)
        self.assertEqual(self.run_tool("seal", "--gate", "M0-CONSOLIDATION", "--allow-failures"), 0)
        self.refuses("only device rows may be recorded as fail", "record", "--gate", "M0-CONSOLIDATION", "--result", "fail")


class SteeringDocumentTests(unittest.TestCase):
    """validate_autocreator.py: each check accepts the good case and names the bad one."""

    @classmethod
    def setUpClass(cls):
        cls.catalog = json.loads((ROOT_DIR / "docs/catalog/experience-catalog.json").read_text())
        cls.index = json.loads((ROOT_DIR / "docs/catalog/feature-index.json").read_text())
        cls.briefs = json.loads((ROOT_DIR / "docs/catalog/unified-app-features.json").read_text())
        cls.doc = (ROOT_DIR / "Auto-Creator.md").read_text()

    def copy(self, value):
        return json.loads(json.dumps(value))

    def test_catalog_allocation(self):
        self.assertEqual(steering.check_catalog(self.catalog), [])
        bad = self.copy(self.catalog)
        bad["experiences"][30]["tier"] = "premium"                      # a Round 2 game sold as premium
        self.assertTrue(any("free tier" in p for p in steering.check_catalog(bad)))
        bad = self.copy(self.catalog)
        bad["experiences"][120]["release"], bad["experiences"][120]["tier"] = "launch", "premium"   # a 101st launch experience
        self.assertTrue(any("exactly 100" in p for p in steering.check_catalog(bad)))
        bad = self.copy(self.catalog)
        bad["experiences"][5]["id"] = bad["experiences"][4]["id"]
        self.assertTrue(any("duplicate experience id" in p for p in steering.check_catalog(bad)))
        bad = self.copy(self.catalog)
        bad["experiences"][50], bad["experiences"][51] = bad["experiences"][51], bad["experiences"][50]   # queue reordered
        self.assertTrue(steering.check_catalog(bad))

    def test_game_specs(self):
        self.assertEqual(steering.check_game_specs(self.catalog, self.index), [])
        bad = self.copy(self.index)
        victim = next(f for f in bad["features"] if f["id"] == "R03-G01-04")
        del victim["prompts"]["converge"]
        self.assertTrue(any("R03-G01-04: missing stage prompts converge" in p for p in steering.check_game_specs(self.catalog, bad)))
        bad = self.copy(self.index)
        bad["features"] = [f for f in bad["features"] if f["id"] != "R02-G07-10"]
        self.assertTrue(any("R02-G07: expected ten game features" in p for p in steering.check_game_specs(self.catalog, bad)))
        legacy = {"features": [{"feature": "040", "gate": "A05-P01", "commands": [{"command": "speckit-specify"}, {"command": "speckit-implement"}]}]}
        self.assertTrue(any("does not end with implement and converge" in p for p in steering.check_game_specs(self.catalog, self.index, legacy)))

    def test_briefs_and_prompts(self):
        self.assertEqual(steering.check_briefs(self.briefs), [])
        for b in self.briefs["features"]:
            prompts = planidx.unified_prompts(b)
            self.assertEqual(list(prompts), planidx.STAGES)
            for stage, text in prompts.items():
                self.assertTrue(text.startswith(f"/speckit-{stage} "), (b["id"], stage))
                self.assertIn(f"FR-{b['namespace']}-###", text)
                ns = b["namespace"]
                self.assertTrue(text.split("\n")[-1].startswith(
                    f"Canonical override: feature directory specs/{b['number']}-{b['slug']}; requirement ids FR-{ns}-###, "
                    f"success criteria SC-{ns}-###, task ids T-{ns}-###"), (b["id"], stage))  # FR-U00-042
        bad = self.copy(self.briefs)
        bad["features"][3]["acceptance"] = []
        bad["features"][4]["number"] = 250
        bad["features"][5]["depends_on"] = ["UA-F99"]
        problems = steering.check_briefs(bad)
        for needle in ("UA-F03: empty acceptance", "numbers are not 186..200", "UA-F05: depends on unknown feature UA-F99"):
            self.assertTrue(any(needle in p for p in problems), needle)

    def test_structure(self):
        self.assertEqual(steering.check_structure(self.doc, self.catalog, self.briefs), [])
        self.assertTrue(any("not numbered" in p for p in steering.check_structure(self.doc.replace("\n## 12. ", "\n## 13. ", 1), self.catalog, self.briefs)))
        self.assertTrue(any("no card for A05" in p for p in steering.check_structure(self.doc.replace("### A05 Infinite Geometry", "### A05 Renamed"), self.catalog, self.briefs)))
        self.assertTrue(any("missing anchor" in p for p in steering.check_structure(self.doc + "\n[x](#no-such-heading)\n", self.catalog, self.briefs)))
        self.assertTrue(any("duplicate requirement ids: E-01" in p for p in steering.check_structure(self.doc + "\n| E-01 again | x |\n", self.catalog, self.briefs)))
        self.assertTrue(any("UA-F02: no /speckit-converge" in p for p in steering.check_structure(self.doc.replace("#### UA-F02 `/speckit-converge`", "#### UA-F02 converge"), self.catalog, self.briefs)))

    def test_continuation_prompt_is_last_and_complete(self):
        self.assertEqual(steering.check_continuation(self.doc), [])
        self.assertTrue(steering.check_continuation(self.doc + "\n## 29. Afterword\n\ntext\n"))
        self.assertTrue(any("ends the file" in p for p in steering.check_continuation(self.doc + "\nA trailing remark.\n")))
        self.assertTrue(any("STOP CONDITIONS" in p for p in steering.check_continuation(self.doc.replace("STOP CONDITIONS", "WHEN TO PAUSE"))))
        self.assertTrue(any("guard-device" in p for p in steering.check_continuation(self.doc.replace("guard-device", "guard"))))
        swapped = self.doc.replace("  3. UA-F08: the single USD 1.99 StoreKit 2 unlock with SKTestSession tests.\n", "")
        swapped = swapped.replace("  1. Unified-app features first:", "  0. UA-F08: the single USD 1.99 StoreKit 2 unlock first.\n  1. Unified-app features first:")
        self.assertTrue(any("order of work" in p for p in steering.check_continuation(swapped)))
        self.assertTrue(any("user interface" in p for p in steering.check_continuation(self.doc.replace("Do not operate the Xcode\nuser interface.", "Then click Run in Xcode."))))

    def test_prices(self):
        self.assertEqual(steering.check_prices("a.md", 'The unlock costs USD 1.99. The archive says "$2.99" and "$1.99–$4.99 one-time purchase".'), [])
        self.assertTrue(steering.check_prices("a.md", "Each game costs $2.99."))
        self.assertTrue(steering.check_prices("a.md", "The unlock costs USD 2.49."))
        self.assertTrue(steering.check_prices("a.json", '{"price": "$2.99"}'))
        self.assertEqual(steering.check_prices("a.json", '{"price": "USD 1.99"}'), [])

    def test_monetization(self):
        good = ("No advertising of any kind, ever. No ad or tracking SDKs, ad identifiers, subscriptions,\n"
                "consumables, external payment paths, dark patterns or required accounts.\n\n"
                "One non-consumable product at USD 1.99.\n\n"
                "| Advertising code in the binary | none |\n"
                "- **Non-goals:** Social accounts; cloud sharing and subscription infrastructure.\n")
        self.assertEqual(steering.check_monetization("a.md", good), [])
        for bad in ("The free tier is supported by ads.", "Players can watch a rewarded video for hints.",
                    "A monthly subscription unlocks the premium library.", "Hints are sold as consumables."):
            self.assertTrue(steering.check_monetization("a.md", bad), bad)

    def test_secrets(self):
        self.assertEqual(steering.check_secrets("a.md", "commit 38d98ebb376088e18f053f3cc39d246a7e7dd3b3, product type iPhone15,4"), [])
        for bad in ("device 00008120-001A2B3C4D5E6F78", "simulator 1A2B3C4D-5E6F-4A7B-8C9D-0E1F2A3B4C5D", "DEVELOPMENT_TEAM = ABCDE12345",
                    "write to someone@example.com", "-----BEGIN RSA PRIVATE KEY-----", "token ghp_abcdefghijklmnopqrstuvwxyz0123"):
            self.assertTrue(steering.check_secrets("a.md", bad), bad)

    def test_links_and_scripts(self):
        with tempfile.TemporaryDirectory() as t:
            d = Path(t)
            (d / "scripts").mkdir()
            (d / "scripts/real.py").write_text("")
            (d / "other.md").write_text("x")
            text = ("[ok](other.md) [web](https://example.com) [gone](missing.md)\n`scripts/real.py` `scripts/run_device_campaign.py` "
                    "`scripts/invented.py`\n```\n[in code](nowhere.md) scripts/also_invented.py\n```\n")
            (d / "doc.md").write_text(text)
            problems = steering.check_links(d, "doc.md", text)
            self.assertEqual(len(problems), 2)
            self.assertTrue(any("broken link missing.md" in p for p in problems))
            self.assertTrue(any("scripts/invented.py does not exist" in p for p in problems))

    def test_bootstrap(self):
        text = (ROOT_DIR / "CLAUDE.md").read_text()
        self.assertEqual(steering.check_bootstrap(text), [])
        self.assertTrue(any("under 12,000" in p for p in steering.check_bootstrap(text + "x" * 12000)))
        self.assertTrue(any("DO NOT UPDATE D3" in p for p in steering.check_bootstrap(text.replace("DO NOT UPDATE D3", "keep D3"))))

    def test_renderer(self):
        self.assertEqual(render.anchor("11. App architecture"), "11-app-architecture")
        self.assertEqual(render.anchor("Part I — Orientation"), "part-i--orientation")
        self.assertEqual(render.headings("# A\n```\n# not a heading\n```\n## B\n"), [(1, "A"), (2, "B")])
        with tempfile.TemporaryDirectory() as t:
            d = Path(t)
            for rel in ("docs/catalog/experience-catalog.json", "docs/catalog/feature-index.json", "docs/catalog/unified-app-features.json",
                        "docs/catalog/shared-feature-map.json", ".autonomy/migration/ledger.json", "docs/migration/source-to-canonical-matrix.csv"):
                (d / rel).parent.mkdir(parents=True, exist_ok=True)
                (d / rel).write_bytes((ROOT_DIR / rel).read_bytes())
            stale = self.doc.replace("| 1 | [A01]", "| 1 | [A01-edited-by-hand]", 1) + ""
            (d / "Auto-Creator.md").write_text(stale.replace("<!-- GENERATED:BEGIN backlog -->", "<!-- GENERATED:BEGIN mystery -->").replace("<!-- GENERATED:END backlog -->", "<!-- GENERATED:END mystery -->"))
            current, rendered, problems = render.render(d)
            self.assertNotEqual(current, rendered)
            self.assertTrue(any("unknown generated block 'mystery'" in p for p in problems))
            self.assertTrue(any("'backlog' is missing" in p for p in problems))

    def test_traceability_matrix_helpers(self):
        lines = ["# Title", "```", "# shell comment", "```", "## Real", "text", "~~~", "### also not", "~~~", "#### Deep"]
        self.assertEqual(tracematrix.heading_lines(lines), {1: "# Title", 5: "## Real", 10: "#### Deep"})
        self.assertEqual(tracematrix.canonical("AC-11.3"), ("Auto-Creator.md §11.3", "AC-11.3"))
        self.assertEqual(tracematrix.canonical("archive")[1], "archive")
        self.assertEqual(tracematrix.canonical("specs/004-resources-shaders"), ("specs/004-resources-shaders", ""))
        self.assertIn("AC-11.3", tracematrix.sections_of(self.doc))
        self.assertIn("AC-28", tracematrix.sections_of(self.doc))
        with tempfile.TemporaryDirectory() as t:
            d = Path(t)
            (d / "docs/migration/heading-maps").mkdir(parents=True)
            (d / "src.md").write_text("# One\n\n## Two\n\n## Three\n")
            (d / "docs/migration/heading-maps/src.json").write_text(json.dumps({"schema": 1, "source": "src.md", "rows": [
                {"line": 1, "heading": "# One", "target": "AC-1", "status": "planned", "note": ""},
                {"line": 3, "heading": "## Wrong text", "target": "AC-2", "status": "planned", "note": ""},
                {"line": 5, "heading": "## Three", "target": "AC-3", "status": "done", "note": ""}]}))
            rows, problems = tracematrix.heading_rows(d, {"experiences": []}, {"features": []}, {})
            self.assertEqual([r["source_id"] for r in rows], ["# One"])
            self.assertTrue(any("line 3 is not the heading" in p for p in problems))
            self.assertTrue(any("unknown status 'done'" in p for p in problems))
            self.assertTrue(any("heading at line 3 is not mapped" in p for p in problems))

    def test_repository_is_consistent(self):
        """The real repository passes every steering check (this is the CI wiring of the validator)."""
        results = steering.validate(ROOT_DIR)
        self.assertEqual(list(results), list(steering.CHECKS))
        self.assertEqual({name: problems for name, problems in results.items() if problems}, {})


prepush = load("prepush_scan")


class PrepushScanTests(unittest.TestCase):
    """The scan before every push finds identifiers and secrets in added lines and nothing else. Every pattern and
    every forbidden path class the scanner lists has a fixture here (feature 186, FR-U00-020 to FR-U00-026)."""

    SIM = "1A2B3C4D-5E6F-4A7B-8C9D-0E1F2A3B4C5D"
    # label: (a line that is a finding, a line that is not). Token-like values are assembled so that no complete
    # look-alike stands in this file.
    PATTERN_FIXTURES = {
        "hardware identifier": ("device 00008120-001A2B3C4D5E6F78", "commit 38d98ebb376088e18f053f3cc39d246a7e7dd3b3"),
        "device or simulator UUID": ("sim " + SIM, "fixture 00000000-0000-4000-8000-000000000001.json"),
        "ECID": ('"ecid": 0x1A2B3C4D5E6F', "scan for UDIDs, ECIDs, serials and team ids"),
        "serial number": ("Serial Number: F2LXK1ABCD12", "serial numbers are never tracked"),
        "development team setting": ("DEVELOPMENT_TEAM = ABCDE12345", "DEVELOPMENT_TEAM is set in the local signing file"),
        "development team id": ("team id: ABCDE12345", "the team id stays with the owner"),
        "e-mail address": ("write to someone@example.com", "git@github.com:owner/repo.git"),
        "absolute home path": ("open /Users/somebody/Documents/x", "/Users/<name>/Documents and /Users/Shared/tools"),
        "private key": ("-----BEGIN OPENSSH " + "PRIVATE KEY-----", "the private key never leaves the keychain"),
        "GitHub token": ("token ghp_" + "abcdefghijklmnopqrstuvwxyz0123", "a ghp_ token is never written down"),
        "GitHub fine-grained token": ("github_pat_" + "11ABCDEFG0abcdefghijkl_mnop", "github_pat_ tokens are refused"),
        "Anthropic API key": ("key sk-ant-" + "api03-abcdefghij", "sk-ant- keys are refused"),
        "AWS access key id": ("AKIA" + "IOSFODNN7EXAMPLE", "AKIA followed by sixteen characters"),
    }
    # label: (a path that must never be tracked, a similar path that may be)
    FORBIDDEN_FIXTURES = {
        "private device data": (".autonomy/private/devices.json", ".autonomy/migration/ledger.json"),
        "logs": (".autonomy/logs/a.log", "docs/logs/readme.md"),
        "result bundles": ("out/Run.xcresult/Info.plist", ".autonomy/evidence/F00.json"),
        "reports": (".autonomy/reports/run.json", "docs/verification/report.md"),
        "local signing file": ("Configs/Signing.local.xcconfig", "Configs/Signing.xcconfig"),
        "provisioning profile": ("profiles/a.mobileprovision", "docs/provisioning.md"),
        "key store": ("certs/dev.p12", "docs/p12-notes.md"),
        "signing key": ("keys/AuthKey_ABC.p8", "docs/p8.md"),
        "certificate": ("certs/dev.cer", "docs/certificates.md"),
    }

    def test_every_pattern_has_a_finding_and_a_clean_fixture(self):
        labels = [label for label, _ in prepush.PATTERNS]
        self.assertEqual(len(labels), len(set(labels)), "pattern labels are unique")
        for label in labels:
            self.assertIn(label, self.PATTERN_FIXTURES, f"scan pattern without a fixture: {label}")
        self.assertEqual(set(self.PATTERN_FIXTURES) - set(labels), set(), "fixture for a pattern the scanner does not list")
        self.assertEqual(len(labels), 13)
        for label, (finding, clean) in self.PATTERN_FIXTURES.items():
            self.assertEqual(prepush.scan_line(finding), [label], finding)
            self.assertEqual(prepush.scan_line(clean), [], clean)

    def test_every_forbidden_path_class_has_fixtures(self):
        labels = [label for label, _ in prepush.FORBIDDEN]
        for label in labels:
            self.assertIn(label, self.FORBIDDEN_FIXTURES, f"forbidden path class without a fixture: {label}")
        self.assertEqual(set(self.FORBIDDEN_FIXTURES) - set(labels), set())
        self.assertEqual(len(labels), 9)
        for label, (bad, good) in self.FORBIDDEN_FIXTURES.items():
            self.assertEqual(prepush.forbidden([bad, good]), [f"{bad}: this path must never be tracked ({label})"])
        self.assertEqual(len(prepush.forbidden([".autonomy/xcresults/x/y", ".autonomy/state.json", "docs/a.md"])), 1)

    def test_allowed_look_alikes(self):
        for clean in ("brew install python@3.15", "git@github.com:owner/repo.git", "product type iPhone15,4 on iPadOS 26.5",
                      "/Users/<name>/Documents", "/Users/Shared/tools", "id 00000000-0000-4000-8000-00000000ABCD"):
            self.assertEqual(prepush.scan_line(clean), [], clean)

    def test_simulator_identifiers_are_accepted_by_hash_only(self):
        line = "xcodebuild test -destination id=" + self.SIM
        recorded = frozenset({prepush.identifier_hash(self.SIM)})
        self.assertEqual(prepush.identifier_hash(self.SIM.lower()), prepush.identifier_hash(self.SIM))
        self.assertEqual(prepush.scan_line(line), ["device or simulator UUID"])
        self.assertEqual(prepush.scan_line(line, recorded), [])
        self.assertEqual(prepush.scan_line(line.lower(), recorded), [])
        unrecorded = prepush.scan_line(line, frozenset(), frozenset({self.SIM}))
        self.assertEqual(len(unrecorded), 1)
        self.assertIn("simulator identifier not recorded", unrecorded[0])
        self.assertIn("python3 scripts/prepush_scan.py --record-simulators", unrecorded[0])

    def test_recording_keeps_hashes_sorted_and_stores_no_identifier(self):
        with tempfile.TemporaryDirectory() as t:
            root = Path(t)
            self.assertEqual(prepush.load_hashes(root), frozenset())
            other = "9F8E7D6C-5B4A-4321-8FED-CBA987654321"
            self.assertEqual(prepush.record_simulators(root, {self.SIM, other.lower()}), 2)
            path = root / prepush.HASHES
            first = path.read_bytes()
            data = json.loads(first)
            self.assertEqual(data["schema"], 1)
            self.assertEqual(data["sha256"], sorted({prepush.identifier_hash(self.SIM), prepush.identifier_hash(other)}))
            self.assertNotRegex(first.decode(), r"[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-")
            self.assertEqual(prepush.record_simulators(root, {self.SIM, other}), 0)
            self.assertEqual(path.read_bytes(), first)
            third = "0A0B0C0D-1E1F-4A2B-9C3D-4E5F6A7B8C9D"
            self.assertEqual(prepush.record_simulators(root, {third}), 1)
            self.assertEqual(len(prepush.load_hashes(root)), 3)
            self.assertLessEqual(set(data["sha256"]), set(prepush.load_hashes(root)))

    def test_unreadable_hash_list_and_simulator_list(self):
        with tempfile.TemporaryDirectory() as t:
            root = Path(t)
            path = root / prepush.HASHES
            path.parent.mkdir(parents=True)
            for damaged in ('{"schema": 2, "sha256": []}', "{not json", '{"schema": 1, "sha256": ["' + self.SIM + '"]}'):
                path.write_text(damaged)
                with self.assertRaises(ValueError) as raised:
                    prepush.load_hashes(root)
                self.assertIn("Configs/simulator-identifier-hashes.json: cannot be read", str(raised.exception))
                with self.assertRaises(ValueError):
                    prepush.record_simulators(root, {self.SIM})
                self.assertEqual(path.read_text(), damaged)
            path.unlink()
            with mock.patch.object(prepush, "simulator_identifiers", return_value=None), contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(prepush.main(["--record-simulators"], root), 1)
            self.assertFalse(path.exists())
            with mock.patch.object(prepush, "simulator_identifiers", return_value=frozenset({self.SIM})), \
                    contextlib.redirect_stdout(io.StringIO()) as out:
                self.assertEqual(prepush.main(["--record-simulators"], root), 0)
            self.assertIn("1 new", out.getvalue())
            self.assertEqual(prepush.load_hashes(root), frozenset({prepush.identifier_hash(self.SIM)}))

    def test_only_added_lines_of_scanned_files_count(self):
        diff = ("--- a/docs/x.md\n+++ b/docs/x.md\n@@ -1 +1 @@\n-old 00008120-001A2B3C4D5E6F78\n+new text\n"
                "+++ b/docs/y.md\n+device 00008120-001A2B3C4D5E6F78\n"
                "+++ b/scripts/test_scripts.py\n+device 00008120-001A2B3C4D5E6F78\n")
        self.assertEqual(prepush.scan_diff(diff), ["docs/y.md: hardware identifier: device 00008120-001A2B3C4D5E6F78"])

    def sandbox(self):
        box = GitSandbox()
        self.addCleanup(box.cleanup)
        return box

    def run_main(self, box, *argv):
        with contextlib.redirect_stdout(io.StringIO()) as out:
            code = prepush.main(list(argv), box.root)
        return code, out.getvalue()

    def test_scan_of_a_repository_without_a_simulator_list(self):
        # A CI runner has no simulator list of the development Mac: the tracked hash list alone decides.
        box = self.sandbox()
        box.write("docs/run.md", "xcodebuild test -destination id=" + self.SIM + "\n")
        box.commit_all("a recorded command")
        with mock.patch.object(prepush, "simulator_identifiers", return_value=None):
            self.assertEqual(prepush.scan(box.root), ["docs/run.md: device or simulator UUID: xcodebuild test -destination id=" + self.SIM])
            prepush.record_simulators(box.root, {self.SIM})
            self.assertEqual(prepush.scan(box.root), [])
            (box.root / prepush.HASHES).write_text("{not json")
            findings = prepush.scan(box.root)
        self.assertTrue(any("Configs/simulator-identifier-hashes.json: cannot be read" in f for f in findings), findings)
        self.assertTrue(any("device or simulator UUID" in f for f in findings), findings)

    def test_unreadable_range_is_a_finding(self):
        box = self.sandbox()
        findings = prepush.scan(box.root, "0000000000000000000000000000000000000000..HEAD")
        self.assertEqual(len(findings), 1)
        self.assertTrue(findings[0].startswith("cannot read 0000000000000000000000000000000000000000..HEAD"), findings)
        code, out = self.run_main(box, "--range", "no-such-commit..HEAD")
        self.assertEqual(code, 1)
        self.assertIn("FINDING: cannot read", out)

    def test_range_with_one_seeded_finding_fails(self):
        box = self.sandbox()
        box.write("docs/clean.md", "nothing private\n")
        box.commit_all("clean")
        self.assertEqual(self.run_main(box, "--range", "HEAD~1..HEAD")[0], 0)
        box.write("docs/leak.md", "write to someone@example.com\n")
        box.commit_all("a leak")
        code, out = self.run_main(box, "--range", "HEAD~1..HEAD")
        self.assertEqual(code, 1)
        self.assertIn("FINDING: docs/leak.md: e-mail address", out)
        self.assertIn("1 findings", out)
        self.assertEqual(self.run_main(box, "--range", "HEAD~2..HEAD~1")[0], 0)

    def test_a_finding_added_and_removed_inside_the_range_still_fails(self):
        # Feature 195: the net change of the range is clean, but the first commit carries the identifier and is
        # pushed with its history; every outgoing commit is scanned on its own.
        box = self.sandbox()
        box.write("docs/clean.md", "nothing private\n")
        box.commit_all("clean")
        box.write("raw/run.json", '{"deviceId": "' + self.SIM + '"}\n')
        box.commit_all("a raw run")
        (box.root / "raw/run.json").unlink()
        box.commit_all("untracked again")
        with mock.patch.object(prepush, "simulator_identifiers", return_value=None):
            code, out = self.run_main(box, "--range", "HEAD~2..HEAD")
        self.assertEqual(code, 1)
        self.assertIn("FINDING: raw/run.json: device or simulator UUID", out)

    def test_push_only_when_clean_and_on_main(self):
        box = self.sandbox()
        box.write("docs/clean.md", "nothing private\n")
        clean = box.commit_all("clean")
        self.assertEqual(self.run_main(box, "--push")[0], 0)
        self.assertEqual(box.remote_head(), clean)
        box.write("docs/leak.md", "device 00008120-001A2B3C4D5E6F78\n")
        box.commit_all("a leak")
        self.assertEqual(self.run_main(box, "--push")[0], 1)
        self.assertEqual(box.remote_head(), clean)
        box.git("reset", "-q", "--hard", clean)
        box.git("checkout", "-q", "-b", "work")
        box.write("docs/more.md", "still clean\n")
        box.commit_all("on a branch")
        code, out = self.run_main(box, "--push")
        self.assertEqual(code, 1)
        self.assertIn("not pushed: branch work is not main", out)
        self.assertEqual(box.remote_head(), clean)

    def test_three_dot_range_reads_the_commits_since_the_merge_base(self):
        # FR-U00-051: the range of a pull request, <base>...<head>. What the base branch did after the fork is not
        # part of it; a two-dot range would report a line the base deleted as if the head had added it.
        box = self.sandbox()
        box.write("docs/old.md", "write to someone@example.com\n")
        box.commit_all("an old line that both branches start with")
        box.git("checkout", "-q", "-b", "feature")
        box.write("docs/new.md", "device 00008120-001A2B3C4D5E6F78\n")
        box.commit_all("the pull request adds a finding")
        box.git("checkout", "-q", "main")
        (box.root / "docs/old.md").unlink()
        box.commit_all("the base deletes the old line after the fork")
        self.assertEqual(prepush.scan(box.root, "main...feature"),
                         ["docs/new.md: hardware identifier: device 00008120-001A2B3C4D5E6F78"])
        # Every commit of the range is scanned on its own (feature 195), so the two-dot range reads the feature's
        # commit alone as well; the base's later deletion is no added line of it.
        self.assertEqual(prepush.scan(box.root, "main..feature"),
                         ["docs/new.md: hardware identifier: device 00008120-001A2B3C4D5E6F78"])
        self.assertEqual(self.run_main(box, "--range", "main...feature")[0], 1)

    def test_large_diff_is_read_to_its_end(self):
        # Edge case "large input": a commit of several megabytes; the one finding is on its last line.
        box = self.sandbox()
        clean = "".join(f"row {n:07d}: procedural mesh, signed-distance field, fixed step\n" for n in range(110000))
        self.assertGreater(len(clean), 5_000_000)
        box.write("docs/big.txt", clean + "device 00008120-001A2B3C4D5E6F78\n")
        box.commit_all("a large file")
        # The time limit guards against a scan that hangs or grows faster than its input. It is set against the
        # machine it runs on: a reference pass over the same text with one simple pattern is timed first, and the
        # scan may take 30 seconds or 400 times that pass, whichever is longer. (A fixed 30 seconds failed on a
        # shared CI runner that was several times slower than usual on 2026-11-12; the scan was correct.)
        reference_started = time.monotonic()
        self.assertEqual(len(re.findall(r"^row \d{7}: ", clean, re.M)), 110000)
        reference = time.monotonic() - reference_started
        limit = max(30.0, 400 * reference)
        # The scan alone is timed: the simulator list (`xcrun simctl`) is stubbed. On the CI runner that call waits
        # for its 60-second limit, which is what both failures of this test measured (61.7 s and 61.8 s), not the
        # scan.
        started = time.monotonic()
        with mock.patch.object(prepush, "simulator_identifiers", return_value=None):
            findings = prepush.scan(box.root)
        elapsed = time.monotonic() - started
        self.assertLess(elapsed, limit, f"scan took {elapsed:.1f} s; reference pass {reference:.3f} s")
        self.assertEqual(findings, ["docs/big.txt: hardware identifier: device 00008120-001A2B3C4D5E6F78"])

    def test_output_is_bounded(self):
        # Edge case "large input": at most 40 findings are printed, then the rest is counted.
        box = self.sandbox()
        box.write("docs/many.md", "".join(f"line {n}: write to person{n}@example.com\n" for n in range(45)))
        box.commit_all("45 findings")
        code, out = self.run_main(box, "--range", "HEAD~1..HEAD")
        self.assertEqual(code, 1)
        self.assertEqual(out.count("FINDING:"), 40)
        self.assertIn("… and 5 more", out)
        self.assertIn("45 findings", out)

    def test_forbidden_tracked_path_is_a_finding(self):
        box = self.sandbox()
        box.write(".autonomy/reports/run.json", "{}\n")
        box.commit_all("a report that must not be tracked")
        self.assertIn(".autonomy/reports/run.json: this path must never be tracked (reports)", prepush.scan(box.root))

    def test_repository_tracks_no_forbidden_path(self):
        self.assertEqual(prepush.scan(ROOT_DIR, "HEAD..HEAD"), [])


# ---------------------------------------------------------------- governance tooling (feature 186, UA-F00)

ticktool = load("tick_task")
phaseprompts = load("speckit_prompts")


class GitSandbox:
    """A temporary repository on `main` with a bare remote named origin, for the tools that commit and push
    (T-U00-002). It holds a minimal constitution so that the document validator runs on it."""

    def __init__(self):
        self.tmp = tempfile.TemporaryDirectory()
        base = Path(self.tmp.name)
        self.remote = base / "origin.git"
        self.root = base / "work"
        self.root.mkdir()
        self.git("init", "-q", "--bare", "--initial-branch=main", str(self.remote), cwd=base)
        self.git("init", "-q", "--initial-branch=main")
        for key, value in (("user.name", "Sandbox"), ("user.email", "sandbox@invalid.example"),
                           ("commit.gpgsign", "false"), ("core.hooksPath", "/dev/null")):
            self.git("config", key, value)
        self.git("remote", "add", "origin", str(self.remote))
        self.write(".specify/memory/constitution.md", "# C\n**Version**: 1.0.0 | x\n")
        self.write("docs/decisions/README.md", "decisions\n")
        self.commit_all("first commit")
        self.git("push", "-q", "-u", "origin", "main")

    def git(self, *argv: str, cwd: Path | None = None) -> str:
        done = subprocess.run(["git", *argv], cwd=cwd or self.root, capture_output=True, text=True, check=False)
        if done.returncode != 0:
            raise AssertionError(f"git {' '.join(argv)} failed: {done.stderr.strip()}")
        return done.stdout.strip()

    def write(self, rel: str, text: str) -> Path:
        path = self.root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")
        return path

    def commit_all(self, message: str) -> str:
        self.git("add", "-A")
        self.git("commit", "-q", "-m", message)
        return self.head()

    def head(self) -> str:
        return self.git("rev-parse", "HEAD")

    def remote_head(self) -> str:
        return self.git("--git-dir", str(self.remote), "rev-parse", "refs/heads/main", cwd=self.remote.parent)

    def commits(self) -> int:
        return int(self.git("rev-list", "--count", "HEAD"))

    def last_message(self) -> str:
        return self.git("log", "-1", "--format=%B")

    def cleanup(self) -> None:
        self.tmp.cleanup()


class GitSandboxTests(unittest.TestCase):
    def test_sandbox_pushes_to_its_bare_remote(self):
        box = GitSandbox()
        self.addCleanup(box.cleanup)
        self.assertEqual(box.git("branch", "--show-current"), "main")
        self.assertEqual(box.commits(), 1)
        self.assertEqual(box.remote_head(), box.head())
        box.write("docs/a.md", "a\n")
        second = box.commit_all("second")
        self.assertNotEqual(box.remote_head(), second)
        box.git("push", "-q", "origin", "main")
        self.assertEqual(box.remote_head(), second)
        self.assertEqual(docs.validate(box.root), [])


class CheckRenamesTests(unittest.TestCase):
    """check_renames.py passes pure renames and fails a changed line or an empty listing (feature 193)."""

    def test_renames_pass_and_edits_fail(self):
        box = GitSandbox()
        self.addCleanup(box.cleanup)
        box.write("old/a.swift", "let a = 1\n")
        box.commit_all("base")
        base = box.head()
        tool = load("check_renames")
        (box.root / "new").mkdir()
        box.git("mv", "old/a.swift", "new/a.swift")
        box.commit_all("move")
        with contextlib.redirect_stdout(io.StringIO()) as out:
            self.assertEqual(tool.main(["--base", base, "old", "new"], box.root), 0)
        self.assertIn("PASS: 1 files", out.getvalue())
        box.write("new/a.swift", "let a = 2\n")
        box.commit_all("edit")
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(tool.main(["--base", base, "old", "new"], box.root), 1)
            self.assertEqual(tool.main(["--base", box.head(), "old", "new"], box.root), 1, "nothing listed")
        with contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(tool.main(["--base", "no-such-ref", "old"], box.root), 2)


class TickTaskTests(unittest.TestCase):
    """tick_task.py ticks one verified task of any namespace, refuses without changing anything, and pushes only
    on main after a clean scan (feature 186, FR-U00-010 to FR-U00-014)."""

    FORMS = {"001-x": "F0{:02d}", "035-x": "A04-3{:02d}", "186-x": "U00-{:03d}", "205-x": "R02F05-{:03d}",
             "301-x": "R02G0101-{:03d}", "r03-f01-x": "R03F01-{:03d}", "r03-g01-01-x": "R03G0101-{:03d}"}

    def setUp(self):
        self.box = GitSandbox()
        self.addCleanup(self.box.cleanup)
        for name, form in self.FORMS.items():
            self.box.write(f"specs/{name}/spec.md", f"- **FR-{form.format(1)}**: a\n")
            self.box.write(f"specs/{name}/tasks.md", f"- [ ] T-{form.format(1)} first task\n- [ ] T-{form.format(2)} second task\n")
        self.box.commit_all("dossiers")
        self.box.git("push", "-q", "origin", "main")

    def tick(self, *argv):
        with contextlib.redirect_stdout(io.StringIO()):
            return ticktool.main(list(argv), self.box.root)

    def refused(self, *argv) -> str:
        with self.assertRaises(SystemExit) as raised:
            self.tick(*argv)
        self.assertNotIn(raised.exception.code, (0, None))
        return str(raised.exception)

    def tasks(self, name="186-x") -> bytes:
        return (self.box.root / "specs" / name / "tasks.md").read_bytes()

    def test_ticks_a_task_of_every_directory_form_and_pushes_on_main(self):
        today = datetime.date.today().isoformat()
        for name, form in self.FORMS.items():
            before = self.box.commits()
            self.assertEqual(self.tick(f"specs/{name}", f"T-{form.format(1)}", "cmd: 3 tests OK", f"tick {name}"), 0, name)
            lines = self.tasks(name).decode().splitlines()
            self.assertEqual(lines[0], f"- [X] T-{form.format(1)} first task — Verified {today}: cmd: 3 tests OK", name)
            self.assertEqual(lines[1], f"- [ ] T-{form.format(2)} second task", name)
            self.assertEqual(self.box.commits(), before + 1, name)
            self.assertEqual(self.box.last_message().strip(), f"tick {name}")
            self.assertEqual(self.box.remote_head(), self.box.head(), name)
        self.assertEqual(self.box.git("status", "--short"), "")

    def test_refusals_change_nothing(self):
        self.box.write("specs/186-x/tasks.md", self.tasks().decode() + "- [X] T-U00-003 done — Verified 2026-11-11: x\n"
                       "- [ ] T-U00-004 twice\n- [ ] T-U00-004 twice again\n")
        self.box.commit_all("more tasks")
        before, commits = self.tasks(), self.box.commits()
        cases = {"task list missing": ("specs/190-none", "T-U04-001", "e", "m"), "task missing": ("specs/186-x", "T-U00-099", "e", "m"),
                 "already ticked": ("specs/186-x", "T-U00-003", "e", "m"), "listed twice": ("specs/186-x", "T-U00-004", "e", "m"),
                 "empty evidence": ("specs/186-x", "T-U00-001", "  ", "m"), "evidence with a line break": ("specs/186-x", "T-U00-001", "a\nb", "m")}
        for label, argv in cases.items():
            self.assertTrue(self.refused(*argv), label)
            self.assertEqual(self.tasks(), before, label)
            self.assertEqual(self.box.commits(), commits, label)
        self.assertEqual(self.box.git("status", "--short"), "")

    def test_failed_validation_restores_the_task_list(self):
        self.box.write("specs/186-x/tasks.md", self.tasks().decode() + "- [ ] T-U01-001 a task of another feature\n")
        self.box.commit_all("a foreign task")
        before, commits = self.tasks(), self.box.commits()
        message = self.refused("specs/186-x", "T-U00-001", "e", "m")
        self.assertIn("T-U01-001 outside namespace U00", message)
        self.assertEqual(self.tasks(), before)
        self.assertEqual(self.box.commits(), commits)

    def test_other_branch_commits_without_pushing(self):
        self.box.git("checkout", "-q", "-b", "work")
        remote = self.box.remote_head()
        self.assertEqual(self.tick("specs/186-x", "T-U00-001", "e", "on a branch"), 0)
        self.assertEqual(self.box.last_message().strip(), "on a branch")
        self.assertEqual(self.box.remote_head(), remote)

    def test_no_push_flag_keeps_the_commit_local(self):
        remote = self.box.remote_head()
        self.assertEqual(self.tick("specs/186-x", "T-U00-001", "e", "local only", "--no-push"), 0)
        self.assertEqual(self.box.remote_head(), remote)
        self.assertNotEqual(self.box.head(), remote)

    def test_finding_keeps_the_commit_local(self):
        self.box.write("docs/leak.md", "device 00008120-001A2B3C4D5E6F78\n")
        remote, commits = self.box.remote_head(), self.box.commits()
        message = self.refused("specs/186-x", "T-U00-001", "e", "with a finding")
        self.assertIn("NOT pushed", message)
        self.assertIn("python3 scripts/prepush_scan.py --push", message)
        self.assertEqual(self.box.commits(), commits + 1)
        self.assertEqual(self.box.remote_head(), remote)

    def test_failed_push_keeps_the_commit_local(self):
        self.box.git("remote", "set-url", "origin", str(self.box.remote.parent / "gone.git"))
        commits = self.box.commits()
        message = self.refused("specs/186-x", "T-U00-001", "e", "remote is gone")
        self.assertIn("NOT pushed", message)
        self.assertIn("python3 scripts/prepush_scan.py --push", message)
        self.assertEqual(self.box.commits(), commits + 1)

    def test_excluded_paths_stay_out_of_the_commit(self):
        # Feature 193: files an agent is still writing are left uncommitted and untouched.
        self.box.write("agent/draft.swift", "// not finished\n")
        self.box.write("done/file.txt", "finished\n")
        self.assertEqual(self.tick("specs/186-x", "T-U00-001", "e", "without the draft", "--no-push",
                                   "--exclude", "agent"), 0)
        committed = self.box.git("show", "--name-only", "--format=", "HEAD").split()
        self.assertIn("done/file.txt", committed)
        self.assertNotIn("agent/draft.swift", committed)
        self.assertIn("?? agent/", self.box.git("status", "--short"))
        self.assertTrue((self.box.root / "agent" / "draft.swift").is_file())

    def test_commit_has_no_trailer(self):
        self.assertEqual(self.tick("specs/186-x", "T-U00-001", "e", "subject only", "--no-push"), 0)
        message = self.box.last_message()
        self.assertEqual(message.strip(), "subject only")
        for trailer in ("Co-Authored-By", "Generated with"):
            self.assertNotIn(trailer, message)


class GovernanceTests(unittest.TestCase):
    """Rules about the tools themselves (feature 186): one writer of the ledger, two tools that push, standard
    library only."""

    LEDGER_WRITER = "scripts/migration_ledger.py"
    # Reviewed readers of the migration ledger. Adding a reader is a change to this list (FR-U00-039).
    LEDGER_READERS = {"scripts/validate_autocreator.py", "scripts/render_autocreator.py", "scripts/build_traceability_matrix.py",
                      "scripts/planning_index.py", "scripts/build_catalog.py",
                      "scripts/check_app_targets.py"}  # reads gate status only (UA-F10, FR-U10-011)
    PUSHERS = {"scripts/tick_task.py", "scripts/prepush_scan.py"}
    SCRIPT_SUFFIXES = (".py", ".sh", ".bash", ".zsh", ".command", ".rb", ".yml", ".yaml")
    NOT_OURS = ("External/", "Vendor/", "docs/archive/")
    TOOLS = ("validate_docs", "tick_task", "prepush_scan", "migration_ledger", "planning_index")
    NETWORK_MODULES = {"socket", "ssl", "urllib", "http", "ftplib", "smtplib", "poplib", "imaplib", "xmlrpc", "telnetlib",
                       "asyncio", "socketserver", "webbrowser"}

    @classmethod
    def setUpClass(cls):
        # Every script and workflow of the repository: tracked files and new files that are not ignored (a script
        # written a moment ago is judged too), the Spec Kit scripts under .specify/ included. The read-only reference
        # submodule, the vendored tree and the archive are not this repository's tools.
        listing = subprocess.run(["git", "ls-files", "--cached", "--others", "--exclude-standard"], cwd=ROOT_DIR, capture_output=True,
                                 text=True, check=True).stdout.splitlines()
        cls.files = {rel: (ROOT_DIR / rel).read_text(encoding="utf-8", errors="replace") for rel in listing
                     if rel.endswith(cls.SCRIPT_SUFFIXES) and not rel.startswith(cls.NOT_OURS) and (ROOT_DIR / rel).is_file()}

    def test_only_the_ledger_tool_writes_the_ledger(self):
        names_ledger = re.compile(r"migration/ledger\.json|migration_ledger\.LEDGER")
        naming = {rel for rel, text in self.files.items() if names_ledger.search(text)}
        self.assertEqual(naming - self.LEDGER_READERS - {self.LEDGER_WRITER, "scripts/test_scripts.py"}, set(),
                         "a tracked script or workflow names the migration ledger without being a reviewed reader")
        writes = re.compile(r"write_text|write_bytes|atomic_write|os\.replace|\.unlink\(|\.rename\(|open\([^)]*[\"'][wax]")
        for rel in sorted(naming & self.LEDGER_READERS):
            for number, line in enumerate(self.files[rel].splitlines(), 1):
                if re.search(r"\bLEDGER\b|ledger\.json", line):
                    self.assertIsNone(writes.search(line), f"{rel}:{number} writes the migration ledger")

    def test_only_two_tools_push(self):
        self.assertIn(".specify/scripts/bash/common.sh", self.files)  # the Spec Kit scripts are read too
        self.assertIn(".github/workflows/push-scan.yml", self.files)
        in_argument_list = re.compile(r"""["']git["'],\s*["']push["']""")
        pushing = {rel for rel, text in self.files.items() if rel.endswith(".py") and rel != "scripts/test_scripts.py"
                   and in_argument_list.search(text)}
        self.assertEqual(pushing, self.PUSHERS)
        # A command line: `git push` outside a comment. The two tools mention it only in their descriptions.
        on_command_line = re.compile(r"^(?!\s*#).*\bgit\s+(?:-\S+(?:\s+\S+)?\s+)*push\b", re.M)
        for line, expected in (("git push origin main", True), ("  run: git -C repo push", True), ("echo ok && git -q push", True),
                               ("# git push is done by the tool", False), ("python3 scripts/prepush_scan.py --push", False)):
            self.assertEqual(bool(on_command_line.search(line)), expected, line)
        for rel, text in self.files.items():
            if not rel.endswith(".py"):
                self.assertIsNone(on_command_line.search(text), f"{rel} pushes")

    def test_ci_runs_the_governance_checks(self):
        # FR-U00-050 to FR-U00-052: four validators as steps of ci.yml, the scan of the pushed range in its own workflow.
        ci = self.files[".github/workflows/ci.yml"]
        for command in ("python3 scripts/validate_autocreator.py", "python3 scripts/planning_archive.py verify",
                        "python3 scripts/planning_index.py verify", "python3 scripts/migration_ledger.py validate",
                        "python3 scripts/build_catalog.py --check"):
            self.assertRegex(ci, r"run: " + re.escape(command) + r"\s*\n", command)
        self.assertTrue(".github/workflows/push-scan.yml" in self.files, "the scan workflow does not exist")
        scan = self.files[".github/workflows/push-scan.yml"]
        for needle in ("fetch-depth: 0", "cancel-in-progress: false", "group: push-scan-${{ github.sha }}", "timeout-minutes: 10",
                       "contents: read", "branches: [main]", "pull_request:", "runs-on: ubuntu-latest",
                       'python3 scripts/prepush_scan.py --range "$RANGE"', "github.event.before", "github.event.pull_request.base.sha"):
            self.assertIn(needle, scan, needle)
        self.assertNotIn("cancel-in-progress: true", scan)
        for name in (".github/workflows/ci.yml", ".github/workflows/push-scan.yml"):
            self.assertNotIn("secrets.", self.files[name], f"{name} names a secret")
        self.assertNotRegex(scan, r"run:.*\$\{\{", "event values reach the script through environment variables only")

    def test_tools_use_only_the_standard_library(self):
        allowed = set(sys.stdlib_module_names) | set(self.TOOLS)
        for tool in self.TOOLS:
            tree = ast.parse(self.files[f"scripts/{tool}.py"])
            imported = set()
            for node in ast.walk(tree):
                if isinstance(node, ast.Import):
                    imported |= {alias.name.split(".")[0] for alias in node.names}
                elif isinstance(node, ast.ImportFrom) and node.module and node.level == 0:
                    imported.add(node.module.split(".")[0])
            self.assertEqual(imported - allowed, set(), f"{tool}.py imports a module outside the standard library")
            self.assertEqual(imported & self.NETWORK_MODULES, set(), f"{tool}.py imports a network module")


class PromptCoverageTests(unittest.TestCase):
    """Every pending launch feature has a non-empty prompt for all eight stages, and the override note of an
    archived round feature names its directory and ids (feature 186, FR-U00-040 to FR-U00-042)."""

    FILES = (".autonomy/state.json", ".autonomy/migration/ledger.json", "docs/process/speckit-prompt-manifest.json",
             "docs/catalog/feature-index.json", "docs/catalog/unified-app-features.json")
    KINDS = ("unified-feature", "shared-round-feature", "game-feature")

    def open_gates(self):
        gates = json.loads((ROOT_DIR / ".autonomy/migration/ledger.json").read_text())["gates"]
        return [g for g in gates if g["kind"] in self.KINDS and g["status"] not in ("pass", "superseded")]

    def copy(self) -> Path:
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        root = Path(tmp.name)
        for rel in self.FILES:
            (root / rel).parent.mkdir(parents=True, exist_ok=True)
            (root / rel).write_bytes((ROOT_DIR / rel).read_bytes())
        (root / "docs/archive").symlink_to(ROOT_DIR / "docs/archive")
        return root

    def edit(self, root: Path, rel: str, change) -> None:
        data = json.loads((root / rel).read_text())
        change(data)
        (root / rel).write_text(json.dumps(data))

    def test_every_pending_launch_feature_has_eight_prompts(self):
        legacy = json.loads((ROOT_DIR / ".autonomy/state.json").read_text())
        phases = [g for g in legacy["order"] if re.fullmatch(r"A\d\d-P\d\d", g) and legacy["stages"][g]["status"] != "pass"]
        expected = len(phases) + len(self.open_gates())
        features, prompts, problems = planidx.prompt_coverage(ROOT_DIR)
        self.assertEqual(problems, [])
        self.assertEqual(features, expected)
        self.assertEqual(prompts, 8 * expected)
        self.assertGreater(features, 0)

    def test_a_missing_or_empty_prompt_names_the_feature_and_the_stage(self):
        root = self.copy()
        self.assertEqual(planidx.prompt_coverage(root)[2], [])

        def drop_round_stage(index):
            next(f for f in index["features"] if f["id"] == "R03-G05-07")["prompts"].pop("plan")
            next(f for f in index["features"] if f["id"] == "R02-F01")["prompts"].clear()  # superseded: never walked

        def empty_phase_stage(manifest):
            entry = next(f for f in manifest["features"] if f["gate"] == "A10-P03")
            next(c for c in entry["commands"] if c["command"] == "speckit-tasks")["prompt"] = "  "
            manifest["features"] = [f for f in manifest["features"] if f["gate"] != "A11-P00"]

        self.edit(root, "docs/catalog/feature-index.json", drop_round_stage)
        self.edit(root, "docs/process/speckit-prompt-manifest.json", empty_phase_stage)
        # A brief of a gate that stays open until the device campaign (a passed gate's prompts are not walked).
        self.edit(root, "docs/catalog/unified-app-features.json",
                  lambda briefs: briefs.update(features=[b for b in briefs["features"] if b["id"] != "UA-F13"]))
        features, prompts, problems = planidx.prompt_coverage(root)
        self.assertEqual(prompts, 8 * features - len(problems))
        self.assertEqual(len(problems), 1 + 1 + 8 + 8)
        self.assertTrue(any(p.startswith("R03-G05-07 plan: ") for p in problems), problems[:4])
        self.assertTrue(any(p.startswith("A10-P03 tasks: ") for p in problems))
        for stage in planidx.STAGES:
            self.assertTrue(any(p.startswith(f"A11-P00 {stage}: ") for p in problems), stage)
            self.assertTrue(any(p.startswith(f"UA-F13 {stage}: ") for p in problems), stage)
        self.assertFalse(any(p.startswith("R02-F01 ") for p in problems))

    def test_coverage_command_reports_both_counts(self):
        with contextlib.redirect_stdout(io.StringIO()) as out:
            code = planidx.main(["coverage"])
        self.assertEqual(code, 0)
        self.assertRegex(out.getvalue(), r"PASS: \d+ pending launch features, \d+ stage prompts, 0 problems")

    def test_manifest_is_what_the_phase_prompt_tool_builds(self):
        if not (ROOT_DIR / ".autonomy/context/apps").is_dir():
            self.skipTest("the extraction .autonomy/context is not on this machine (a CI runner): the tracked manifest is used as it is")
        built = {f["gate"]: f for f in phaseprompts.foundation() + phaseprompts.apps()}
        manifest = {f["gate"]: f for f in json.loads((ROOT_DIR / "docs/process/speckit-prompt-manifest.json").read_text())["features"]}
        legacy = json.loads((ROOT_DIR / ".autonomy/state.json").read_text())
        for gate in legacy["order"]:
            if re.fullmatch(r"A\d\d-P\d\d", gate) and legacy["stages"][gate]["status"] != "pass":
                self.assertEqual(manifest[gate], built[gate], gate)

    def test_override_sentence_names_the_directory_and_the_ids(self):
        index = {f["id"]: f for f in json.loads((ROOT_DIR / "docs/catalog/feature-index.json").read_text())["features"]}
        checked = 0
        for g in self.open_gates():
            if g["kind"] == "unified-feature":
                continue
            ns = docs.namespace(Path(g["spec_dir"]))
            self.assertEqual(planidx.override_ids(ROOT_DIR, index[g["id"]]),
                             f"Canonical override: feature directory {g['spec_dir']}; requirement ids FR-{ns}-###, "
                             f"success criteria SC-{ns}-###, task ids T-{ns}-###.", g["id"])
            checked += 1
        self.assertGreater(checked, 700)
        backlog = next(f for f in index.values() if f["kind"] == "game-feature" and f["round"] == 5)
        self.assertIn(f"feature directory {backlog['spec_dir_proposed']};", planidx.override_ids(ROOT_DIR, backlog))

    def test_prompt_with_override_ends_with_the_sentence(self):
        index = {f["id"]: f for f in json.loads((ROOT_DIR / "docs/catalog/feature-index.json").read_text())["features"]}
        feature = index["R02-G01-01"]
        archived = planidx.prompt_text(ROOT_DIR, feature, "specify")
        with contextlib.redirect_stdout(io.StringIO()) as out:
            self.assertEqual(planidx.main(["prompt", "--feature", "R02-G01-01", "--stage", "specify", "--override"]), 0)
        text = out.getvalue()
        sentence = ("Canonical override: feature directory specs/301-aurora-loom-playable-rule-kernel; requirement ids "
                    "FR-R02G0101-###, success criteria SC-R02G0101-###, task ids T-R02G0101-###.")
        self.assertTrue(text.rstrip().endswith(sentence), text[-300:])
        self.assertIn(archived, text)
        paragraph = planidx.OVERRIDE_GAME.format(code="R02-G01", tier="free")
        self.assertLess(text.index(archived), text.index(paragraph))
        self.assertLess(text.index(paragraph), text.index(sentence))
        with contextlib.redirect_stdout(io.StringIO()) as plain:
            planidx.main(["prompt", "--feature", "R02-G01-01", "--stage", "specify"])
        self.assertNotIn("Canonical override", plain.getvalue())
        self.assertIn(archived, plain.getvalue())


class BuildCatalogTests(unittest.TestCase):
    """scripts/build_catalog.py derives the runtime manifest from the planning catalog, the migration ledger and the
    registrations, and proves with --check that the committed files are what it would write (feature 187, UA-F01:
    FR-U01-040 to FR-U01-045, FR-U01-004)."""

    @classmethod
    def setUpClass(cls):
        cls.tool = load("build_catalog")

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        for rel in ("docs/catalog/experience-catalog.json", ".autonomy/migration/ledger.json"):
            (self.root / rel).parent.mkdir(parents=True, exist_ok=True)
            (self.root / rel).write_bytes((ROOT_DIR / rel).read_bytes())
        self.write("Catalog/categories.json", {"schema": 1, "categories": [{"id": i, "title": i.title()} for i in self.tool.CATEGORIES]})
        self.write("Catalog/registrations.json", {"schema": 1, "registrations": {}})
        self.write("Catalog/path-map.json", {"schema": 1, "moves": []})
        self.assertEqual(self.run_tool("--add-golden")[0], 0)

    def write(self, rel, value):
        path = self.root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(value, indent=2) + "\n")

    def edit(self, rel, change):
        data = json.loads((self.root / rel).read_text())
        change(data)
        (self.root / rel).write_text(json.dumps(data))

    def run_tool(self, *argv):
        with contextlib.redirect_stdout(io.StringIO()) as out:
            try:
                code = self.tool.main(list(argv), self.root)
            except SystemExit as stop:
                return 1, out.getvalue() + str(stop)
        return code, out.getvalue()

    def manifest(self):
        return json.loads((self.root / "Catalog/experiences.json").read_text())

    def gate(self, gate_id, status):
        def change(ledger):
            next(g for g in ledger["gates"] if g["id"] == gate_id)["status"] = status
        self.edit(".autonomy/migration/ledger.json", change)

    def tree(self):
        return {p.relative_to(self.root).as_posix(): p.read_bytes() for p in sorted(self.root.rglob("*")) if p.is_file()}

    def test_build_derives_every_field_from_the_planning_catalog(self):
        ledger_before = (self.root / ".autonomy/migration/ledger.json").read_bytes()
        code, out = self.run_tool()
        self.assertEqual(code, 0)
        self.assertIn("100 experiences, 50 free, 50 premium, 0 available", out)
        planning_bytes = (self.root / "docs/catalog/experience-catalog.json").read_bytes()
        planning = {e["id"]: e for e in json.loads(planning_bytes)["experiences"]}
        built = self.manifest()
        self.assertEqual(list(built), ["schema", "catalog_sha256", "experiences"])
        self.assertEqual(built["schema"], 1)
        self.assertEqual(built["catalog_sha256"], hashlib.sha256(planning_bytes).hexdigest())
        entries = built["experiences"]
        self.assertEqual(len(entries), 100)
        self.assertEqual([e["order"] for e in entries], sorted(e["order"] for e in entries))
        self.assertEqual(list(entries[0]), ["id", "code", "title", "summary", "kind", "tier", "category", "family", "tags", "order",
                                            "palette", "tile_seed", "capabilities", "quality_tiers", "content", "available"])
        for e in entries:
            source = planning[e["id"]]
            self.assertEqual((e["code"], e["title"], e["tier"], e["family"], e["order"], e["category"]),
                             (source["code"], source["name"], source["tier"], source["family"], source["order"], source["launcher_category"]))
            self.assertEqual(e["summary"], source["design"].get("summary") or source["design"]["pitch"])
            self.assertEqual(e["kind"], "creative" if source["kind"] == "creative-app" else "game")
            self.assertEqual(e["tags"], [re.sub(r"[^a-z0-9]+", "-", source["family"].lower()).strip("-")])
            self.assertEqual(e["tile_seed"], int.from_bytes(hashlib.sha256(e["id"].encode()).digest()[:4], "big"))
            self.assertEqual((e["palette"], e["capabilities"], e["quality_tiers"], e["content"], e["available"]), ([], [], [], None, False))
        self.assertEqual(sum(e["tier"] == "free" for e in entries), 50)
        self.assertEqual({e["code"] for e in entries if e["tier"] == "premium"},
                         {f"R{r:02d}-G{g:02d}" for r in (3, 4) for g in range(1, 26)})
        fixtures = self.root / self.tool.FIXTURES
        for name in ("experiences.json", "categories.json", "registrations.json", "path-map.json", "experience-ids.golden.txt"):
            self.assertEqual((fixtures / name).read_bytes(), (self.root / "Catalog" / name).read_bytes(), name)
        self.assertEqual((self.root / ".autonomy/migration/ledger.json").read_bytes(), ledger_before)

    def test_only_a_passed_integration_gate_makes_an_experience_available(self):
        for status in ("pending", "blocked", "fail"):
            self.gate("X-A02", status)
            self.assertEqual(self.run_tool()[0], 0, status)
            self.assertEqual(sum(e["available"] for e in self.manifest()["experiences"]), 0, status)
        self.gate("X-A01", "pass")
        before = self.tree()
        code, out = self.run_tool()
        self.assertEqual(code, 1)
        self.assertIn("a01.generative-art-studio", out)
        self.assertIn("registration", out)
        self.assertEqual(self.tree(), before)
        registration = {"capabilities": ["export-image"], "quality_tiers": ["low", "high"], "palette": ["#102030"], "content": None}
        self.edit("Catalog/registrations.json", lambda r: r["registrations"].update({"a01.generative-art-studio": registration}))
        code, out = self.run_tool()
        self.assertEqual(code, 0)
        self.assertIn("1 available", out)
        available = [e for e in self.manifest()["experiences"] if e["available"]]
        self.assertEqual([e["id"] for e in available], ["a01.generative-art-studio"])
        self.assertEqual((available[0]["capabilities"], available[0]["quality_tiers"], available[0]["palette"]),
                         (["export-image"], ["low", "high"], ["#102030"]))

    def test_bad_registrations_are_errors_that_write_nothing(self):
        self.assertEqual(self.run_tool()[0], 0)
        before = self.tree()
        cases = {"an id the planning catalog does not define": lambda r: r["registrations"].update({"a99.nothing": {
                     "capabilities": [], "quality_tiers": [], "palette": [], "content": None}}),
                 "another schema": lambda r: r.update(schema=2),
                 "a missing key": lambda r: r["registrations"].update({"a01.generative-art-studio": {"capabilities": []}}),
                 "an unknown key": lambda r: r["registrations"].update({"a01.generative-art-studio": {
                     "capabilities": [], "quality_tiers": [], "palette": [], "content": None, "price": 1}})}
        good = (self.root / "Catalog/registrations.json").read_bytes()
        for label, change in cases.items():
            self.edit("Catalog/registrations.json", change)
            changed = (self.root / "Catalog/registrations.json").read_bytes()
            code, out = self.run_tool()
            self.assertEqual(code, 1, label)
            self.assertIn("Catalog/registrations.json", out, label)
            after = self.tree()
            after["Catalog/registrations.json"] = before["Catalog/registrations.json"]
            self.assertEqual(after, before, label)
            self.assertEqual((self.root / "Catalog/registrations.json").read_bytes(), changed)
            (self.root / "Catalog/registrations.json").write_bytes(good)

    def test_check_mode_names_the_file_and_writes_nothing(self):
        self.assertEqual(self.run_tool()[0], 0)
        code, out = self.run_tool("--check")
        self.assertEqual(code, 0)
        self.assertIn("PASS: runtime catalog, 0 problems", out)
        fixtures = self.tool.FIXTURES.as_posix()
        for rel in ("Catalog/experiences.json", f"{fixtures}/experiences.json", f"{fixtures}/categories.json"):
            path = self.root / rel
            good = path.read_bytes()
            path.write_bytes(good.replace(b"Generative Art Studio", b"Generative Art Studi0") if b"Generative Art Studio" in good
                             else good + b" ")
            before = self.tree()
            code, out = self.run_tool("--check")
            self.assertEqual(code, 1, rel)
            self.assertIn(f"PROBLEM: {rel}", out, rel)
            self.assertEqual(self.tree(), before, rel)
            path.write_bytes(good)
        golden = self.root / "Catalog/experience-ids.golden.txt"
        good = golden.read_text()
        golden.write_text(good.replace("a05.infinite-geometry", "a05.infinite-geometri"))
        code, out = self.run_tool("--check")
        self.assertEqual(code, 1)
        self.assertIn("a05.infinite-geometry", out)
        self.assertIn("a05.infinite-geometri", out)
        golden.write_text(good)
        self.assertEqual(self.run_tool("--check")[0], 0)

    def test_two_builds_give_identical_bytes(self):
        self.assertEqual(self.run_tool()[0], 0)
        first = self.tree()
        self.assertEqual(self.run_tool()[0], 0)
        self.assertEqual(self.tree(), first)

    def test_golden_list_only_grows(self):
        golden = self.root / "Catalog/experience-ids.golden.txt"
        lines = golden.read_text().splitlines()
        self.assertEqual(len(lines), 300)
        self.assertEqual(lines[0], "a01.generative-art-studio")
        golden.write_text("\n".join(lines[:298]) + "\n")
        code, out = self.run_tool()
        self.assertEqual(code, 1)
        self.assertIn("--add-golden", out)
        code, out = self.run_tool("--add-golden")
        self.assertEqual(code, 0)
        self.assertIn("2 ids added", out)
        self.assertEqual(golden.read_text().splitlines(), lines)
        self.assertIn("0 ids added", self.run_tool("--add-golden")[1])
        golden.write_text("\n".join(lines + ["a99.nothing"]) + "\n")
        for argv in (["--add-golden"], [], ["--check"]):
            code, out = self.run_tool(*argv)
            self.assertEqual(code, 1, argv)
            self.assertIn("a99.nothing", out, argv)

    def test_backlog_round_enters_with_its_gate_and_ids_never_collide(self):
        # Edge cases of the specification: backlog rounds (FR-U01-012) and colliding ids (FR-U01-044).
        self.assertEqual(self.run_tool()[0], 0)
        self.assertEqual(len(self.manifest()["experiences"]), 100)
        self.assertFalse(any(e["code"].startswith("R05") for e in self.manifest()["experiences"]))
        self.edit(".autonomy/migration/ledger.json", lambda ledger: ledger["gates"].append(
            {"id": "X-R05-G01", "kind": "experience", "title": "backlog", "depends": [], "status": "pending", "attempts": []}))
        code, out = self.run_tool()
        self.assertEqual(code, 0)
        self.assertIn("101 experiences, 50 free, 51 premium, 0 available", out)
        last = self.manifest()["experiences"][-1]
        self.assertEqual((last["code"], last["tier"], last["available"], last["order"]), ("R05-G01", "premium", False, 101))
        before = self.tree()

        def collide(catalog):
            first, second = catalog["experiences"][0], catalog["experiences"][1]
            second.update(code=first["code"], slug=first["slug"], id=first["id"])
        self.edit("docs/catalog/experience-catalog.json", collide)
        code, out = self.run_tool()
        self.assertEqual(code, 1)
        self.assertIn("docs/catalog/experience-catalog.json", out)
        self.assertIn("twice", out)
        after = self.tree()
        after["docs/catalog/experience-catalog.json"] = before["docs/catalog/experience-catalog.json"]
        self.assertEqual(after, before)

    def test_unreadable_or_misallocated_planning_catalog_is_an_error(self):
        planning = self.root / "docs/catalog/experience-catalog.json"
        good = planning.read_bytes()
        planning.write_text("{not json")
        code, out = self.run_tool()
        self.assertEqual(code, 1)
        self.assertIn("docs/catalog/experience-catalog.json", out)
        planning.write_bytes(good)
        self.edit("docs/catalog/experience-catalog.json", lambda c: c["experiences"][0].update(tier="premium"))
        code, out = self.run_tool()
        self.assertEqual(code, 1)
        self.assertIn("A01", out)
        self.assertFalse((self.root / "Catalog/experiences.json").exists())
        (self.root / ".autonomy/migration/ledger.json").unlink()
        planning.write_bytes(good)
        code, out = self.run_tool()
        self.assertEqual(code, 1)
        self.assertIn(".autonomy/migration/ledger.json", out)


class ExperienceModuleTests(unittest.TestCase):
    """Source-level rules of the pure module VisualCoreExperience (feature 187, FR-U01-036, FR-U01-024) and the test
    options of the package test tool."""

    SOURCES = ROOT_DIR / "Packages/VisualCore/Sources/VisualCoreExperience"
    FORBIDDEN = ("Locale", "localized", "Date(", "FileManager", "URLSession", "ProcessInfo", "UserDefaults", "NotificationCenter",
                 "DispatchQueue", "Bundle.")
    # UA-F05 (feature 191, research R1 and R2): the storage handle and the saved-state store are the two files of
    # the module that reach files and defaults, each confined to one experience's namespace. Every other word stays
    # forbidden in them, and every other file of the module stays without storage.
    STORAGE_FILES = {"ExperienceStorage.swift": ("FileManager", "UserDefaults"), "SavedStateStore.swift": ("FileManager",)}

    def test_module_reads_no_clock_language_file_or_network(self):
        files = sorted(self.SOURCES.glob("*.swift"))
        self.assertGreaterEqual(len(files), 6)
        for path in files:
            text = path.read_text(encoding="utf-8")
            code = "\n".join(line.split("//")[0] for line in text.splitlines())
            for word in self.FORBIDDEN:
                if word in self.STORAGE_FILES.get(path.name, ()):
                    continue
                self.assertNotIn(word, code, f"{path.name} names {word}")
            imports = set(re.findall(r"^import\s+(\w+)", text, re.M))
            # UA-F02 adds the pure modules the experience contract adapts; nothing else may be imported.
            # UA-F06 adds the diagnostics module: an experience declares its quality profile with it.
            allowed = {"Foundation", "VisualCoreMath", "VisualCoreSimulation", "VisualCorePersistence",
                       "VisualCoreDiagnostics"}
            self.assertLessEqual(imports, allowed, f"{path.name} imports {sorted(imports)}")
        for name in self.STORAGE_FILES:
            self.assertTrue((self.SOURCES / name).is_file(), f"{name} is named as a storage file and does not exist")

    def test_package_test_tool_passes_language_and_region(self):
        tool = load("xcodebuild_package")
        base = ["-test-timeouts-enabled", "YES", "-default-test-execution-time-allowance", "180"]
        self.assertEqual(tool.test_options(None, None), base)
        self.assertEqual(tool.test_options("tr", "TR"), base + ["-testLanguage", "tr", "-testRegion", "TR"])
        self.assertEqual(tool.test_options("de", None), base + ["-testLanguage", "de"])
        for language, region in (("TR", None), ("turkish", None), (None, "tr"), (None, "TUR"), ("t r", None)):
            with self.assertRaises(SystemExit):
                tool.test_options(language, region)

    def test_package_test_tool_passes_only_testing(self):
        """Feature UA-F06 T-U06-002: `--only-testing` ids become `-only-testing:` options; anything that is not
        a target, class or method id is refused."""
        tool = load("xcodebuild_package")
        base = ["-test-timeouts-enabled", "YES", "-default-test-execution-time-allowance", "180"]
        self.assertEqual(tool.test_options(None, None, ["VisualCoreExperienceHostTests/EnduranceTests"]),
                         base + ["-only-testing:VisualCoreExperienceHostTests/EnduranceTests"])
        self.assertEqual(tool.test_options("tr", None, ["A", "B/C/testD"]),
                         base + ["-only-testing:A", "-only-testing:B/C/testD"] + ["-testLanguage", "tr"])
        self.assertEqual(tool.test_options(None, None, []), base)
        for bad in ("A/B/C/D", "A B", "-x", "A/", "A;rm"):
            with self.assertRaises(SystemExit):
                tool.test_options(None, None, [bad])


class ExperienceSymbolsTests(unittest.TestCase):
    """Feature UA-F02 T-U02-031: the pure functions and the exit codes of check_experience_symbols.py. Nothing is
    built: the builds and `nm` are replaced by an injected `run`."""

    tool = load("check_experience_symbols")
    CLEAN = "0000000000000000 T _$s20VisualCoreExperience0C6EngineC4stepyyF\n                 U _swift_release\n"
    MANGLED = "_$s20VisualCoreExperience0C8ScenarioV5stepsSivg"
    DEMANGLED = "VisualCoreExperience.ExperienceScenario.steps.getter : Swift.Int"
    DIRTY = CLEAN + "0000000000000040 T " + MANGLED + "\n"

    def test_object_files_accept_the_toolchain_directory_name(self):
        """Observed with Swift 6.4: the objects of target X lie below `X-t.build`; a similar name of another target
        never counts."""
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for rel in ("a/VisualCoreExperience-t.build/Objects-normal/arm64/One.o", "a/VisualCoreExperience.build/Two.o",
                        "a/VisualCoreExperienceHost-t.build/Three.o", "a/VisualCoreExperienceTests.build/Four.o",
                        "Products/Release/VisualCoreExperience.o"):
                (root / rel).parent.mkdir(parents=True, exist_ok=True)
                (root / rel).write_bytes(b"")
            self.assertEqual([p.name for p in self.tool.object_files(root, "pure")], ["One.o", "Two.o"])
            self.assertEqual([p.name for p in self.tool.object_files(root, "host")], ["Three.o"])

    def fake_run(self, build_code=0, nm_output="", objects=(), nm_code=0, demangle_code=0):
        """A stand-in for subprocess.run: the "build" creates the given object files below the build directory and
        the "demangler" knows the one abbreviated symbol of the fixtures."""
        calls = []

        def run(cmd, cwd=None, capture_output=False, text=False, input=None, **_):
            calls.append((list(cmd), cwd))
            if cmd[:2] == ["xcrun", "swift-demangle"]:
                return subprocess.CompletedProcess(cmd, demangle_code, input.replace(self.MANGLED, self.DEMANGLED), "")
            if cmd[:2] == ["xcrun", "nm"]:
                return subprocess.CompletedProcess(cmd, nm_code, nm_output, "nm error" if nm_code else "")
            self.assertTrue(capture_output and text)
            if build_code == 0:
                where = cmd[cmd.index("--scratch-path") + 1] if "--scratch-path" in cmd else cmd[cmd.index("-derivedDataPath") + 1]
                for rel in objects:
                    path = Path(cwd) / where / rel
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.write_bytes(b"")
            return subprocess.CompletedProcess(cmd, build_code, "\n".join(f"line {i}" for i in range(40)), "error: broken")

        return run, calls

    def run_main(self, argv, **fake):
        run, calls = self.fake_run(**fake)
        out, err = io.StringIO(), io.StringIO()
        with tempfile.TemporaryDirectory() as d, contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = self.tool.main(argv, root=Path(d).resolve(), run=run)
        return code, out.getvalue(), err.getvalue(), calls

    def test_count_symbols(self):
        dirty = self.DIRTY.replace(self.MANGLED, self.DEMANGLED)
        self.assertEqual(self.tool.count_symbols(self.CLEAN), 0)
        self.assertEqual(self.tool.count_symbols(dirty), 1)
        self.assertEqual(self.tool.count_symbols(dirty + "0000 S _$s3App18ExperienceScenarioVMn\n"), 2)
        self.assertEqual(self.tool.count_symbols(self.DIRTY), 0, "the abbreviated mangling needs the demangler")
        self.assertEqual(self.tool.count_symbols(""), 0)

    def test_verdict_in_the_four_combinations(self):
        self.assertTrue(self.tool.verdict(0, False))
        self.assertFalse(self.tool.verdict(3, False))
        self.assertFalse(self.tool.verdict(0, True))
        self.assertTrue(self.tool.verdict(3, True))

    def test_pure_build_commands(self):
        root = Path("/repo")
        cmd, cwd, build_dir = self.tool.build_command("pure", False, root)
        self.assertEqual(cmd, ["swift", "build", "--package-path", "Packages/VisualCore", "-c", "release", "--target",
                               "VisualCoreExperience", "--scratch-path", "Build/experience-symbols/pure"])
        self.assertEqual((cwd, build_dir), (root, root / "Build/experience-symbols/pure"))
        self.assertFalse(any("VISUALCORE_AUTOMATION" in part for part in cmd))
        flagged, cwd, flag_dir = self.tool.build_command("pure", True, root)
        self.assertEqual(flagged[-2:], ["-Xswiftc", "-DVISUALCORE_AUTOMATION"])
        self.assertEqual(flagged[flagged.index("--scratch-path") + 1], "Build/experience-symbols/pure-flag")
        self.assertEqual((cwd, flag_dir), (root, root / "Build/experience-symbols/pure-flag"))
        self.assertNotEqual(build_dir, flag_dir)

    def test_host_build_commands_never_name_a_device(self):
        root = Path("/repo")
        cmd, cwd, build_dir = self.tool.build_command("host", False, root)
        self.assertEqual(cmd[:2], ["xcodebuild", "build"])
        self.assertEqual(cmd[cmd.index("-scheme") + 1], "VisualCoreExperienceHost")
        self.assertEqual(cmd[cmd.index("-configuration") + 1], "Release")
        self.assertEqual(cmd[cmd.index("-destination") + 1], "generic/platform=iOS Simulator")
        self.assertEqual(cmd.count("-destination"), 1)
        self.assertEqual(cmd[cmd.index("-derivedDataPath") + 1], "/repo/Build/experience-symbols/host")
        self.assertEqual((cwd, build_dir), (root / "Packages/VisualCoreRendering", root / "Build/experience-symbols/host"))
        self.assertFalse(any("VISUALCORE_AUTOMATION" in part for part in cmd))
        flagged, cwd, flag_dir = self.tool.build_command("host", True, root)
        self.assertIn("SWIFT_ACTIVE_COMPILATION_CONDITIONS=$(inherited) VISUALCORE_AUTOMATION", flagged)
        self.assertEqual(flagged[flagged.index("-derivedDataPath") + 1], "/repo/Build/experience-symbols/host-flag")
        self.assertEqual(flag_dir, root / "Build/experience-symbols/host-flag")
        self.assertNotEqual(build_dir, flag_dir)
        for command in (cmd, flagged):
            for part in command:
                self.assertNotIn("id=", part)
                self.assertNotIn("platform=iOS,", part)
                self.assertNotEqual(part, "generic/platform=iOS")
        with self.assertRaises(ValueError):
            self.tool.build_command("device", False, root)

    def test_tool_has_no_destination_option(self):
        for option in ("--destination", "--device", "--udid"):
            with self.assertRaises(SystemExit), contextlib.redirect_stderr(io.StringIO()):
                self.tool.main(["--module", "host", option, "x"], run=None)

    def test_object_files_only_below_the_module_build_directory(self):
        with tempfile.TemporaryDirectory() as d:
            base = Path(d)
            self.assertEqual(self.tool.object_files(base / "missing", "pure"), [])
            wanted = ["release/VisualCoreExperience.build/ExperienceEngine.swift.o",
                      "release/VisualCoreExperience.build/nested/ExperienceCore.o"]
            others = ["release/VisualCoreMath.build/StableHash.swift.o",
                      "release/VisualCoreExperienceHost.build/ExperienceShell.o",
                      "release/VisualCoreExperience.build/ExperienceEngine.swiftdeps",
                      "release/VisualCoreExperience.build.o",
                      "release/Other.o"]
            for rel in wanted + others:
                (base / rel).parent.mkdir(parents=True, exist_ok=True)
                (base / rel).write_bytes(b"")
            self.assertEqual(self.tool.object_files(base, "pure"), sorted(base / rel for rel in wanted))
            self.assertEqual(self.tool.object_files(base, "host"), [base / others[1]])

    def test_main_exit_2_when_the_build_fails(self):
        code, out, err, calls = self.run_main(["--module", "pure"], build_code=1)
        self.assertEqual((code, out), (2, ""))
        self.assertEqual(len(calls), 1)
        self.assertIn("error: broken", err)
        self.assertIn("line 39", err)
        self.assertNotIn("line 5\n", err)

    def test_main_exit_2_when_no_object_file_is_found(self):
        code, out, err, calls = self.run_main(["--module", "pure"], objects=["release/VisualCoreMath.build/a.o"])
        self.assertEqual((code, out), (2, ""))
        self.assertIn("no object file", err)
        self.assertEqual(len(calls), 1)
        code, _, _, _ = self.run_main(["--module", "host"])
        self.assertEqual(code, 2)

    def test_main_exit_2_when_nm_fails(self):
        code, out, _, _ = self.run_main(["--module", "pure"], objects=["release/VisualCoreExperience.build/a.o"], nm_code=1)
        self.assertEqual((code, out), (2, ""))

    def test_main_exit_2_when_the_demangler_fails(self):
        code, out, _, _ = self.run_main(["--module", "pure"], objects=["release/VisualCoreExperience.build/a.o"],
                                        nm_output=self.DIRTY, demangle_code=1)
        self.assertEqual((code, out), (2, ""))

    def test_main_without_the_flag(self):
        objects = ["release/VisualCoreExperience.build/a.o"]
        code, out, _, calls = self.run_main(["--module", "pure"], objects=objects, nm_output=self.CLEAN)
        self.assertEqual((code, out), (0, "PASS: pure, release, 0 automation symbols in 1 object files\n"))
        self.assertEqual([c[0][:2] for c in calls], [["swift", "build"], ["xcrun", "nm"], ["xcrun", "swift-demangle"]])
        code, out, _, _ = self.run_main(["--module", "pure"], objects=objects, nm_output=self.DIRTY)
        self.assertEqual(code, 1)
        lines = out.splitlines()
        self.assertEqual(lines[0], "FAIL: pure, release, 1 automation symbols in 1 object files")
        self.assertIn("ExperienceScenario", lines[1])
        two = objects + ["release/VisualCoreExperience.build/b.o"]
        code, out, _, _ = self.run_main(["--module", "pure"], objects=two, nm_output=self.DIRTY * 4)
        self.assertEqual(out.splitlines()[0], "FAIL: pure, release, 8 automation symbols in 2 object files")
        self.assertEqual(len(out.splitlines()), 6)

    def test_main_with_the_flag_is_inverted(self):
        objects = ["Build/Intermediates.noindex/X.build/Release-iphonesimulator/VisualCoreExperienceHost.build/Objects-normal/arm64/a.o"]
        code, out, _, calls = self.run_main(["--module", "host", "--with-flag"], objects=objects, nm_output=self.DIRTY)
        self.assertEqual((code, out),
                         (0, "PASS: host, release with VISUALCORE_AUTOMATION, 1 automation symbols in 1 object files\n"))
        self.assertEqual(calls[0][1].name, "VisualCoreRendering")
        code, out, _, _ = self.run_main(["--module", "host", "--with-flag"], objects=objects, nm_output=self.CLEAN)
        self.assertEqual((code, out),
                         (1, "FAIL: host, release with VISUALCORE_AUTOMATION, 0 automation symbols in 1 object files\n"))
        code, out, _, _ = self.run_main(["--module", "pure", "--with-flag"],
                                        objects=["release/VisualCoreExperience.build/a.o"], nm_output=self.DIRTY)
        self.assertEqual((code, out),
                         (0, "PASS: pure, release with VISUALCORE_AUTOMATION, 1 automation symbols in 1 object files\n"))


verify = load("verify_experiences")


def fake_udid(n: int) -> str:
    """A simulator-identifier-shaped value built at run time, so no tracked file holds one."""
    return "-".join([f"{n:08X}", "AB12", "4C3D", "9E8F", f"{n * 7919:012X}"])


class FakeSim:
    """A stand-in for every external command of verify_experiences.py: simctl, xcodebuild, xcresulttool, git and the
    file commands on the simulator container. The clock only moves when the driver sleeps."""

    RUNTIMES = {"runtimes": [
        {"identifier": "com.apple.CoreSimulator.SimRuntime.iOS-27-2", "version": "27.2", "buildversion": "24B8117",
         "isAvailable": True, "platform": "iOS"},
        {"identifier": "com.apple.CoreSimulator.SimRuntime.iOS-26-5", "version": "26.5", "buildversion": "23F77",
         "isAvailable": True, "platform": "iOS"},
        {"identifier": "com.apple.CoreSimulator.SimRuntime.iOS-26-2", "version": "26.2", "buildversion": "23C1",
         "isAvailable": True, "platform": "iOS"}]}

    FRAME = bytes([0, 16, 32, 255]) * 4          # a 2x2 RGBA frame

    def __init__(self, root: Path, *, failed_tests=0, make_bundle=True, writes_record=True, exits=True, busy=0,
                 lossy_result="fail", save_digest="d" * 64, records=True, commit="a" * 40, save_result="pass",
                 frame=None, writes_frame=True, request_error=None):
        self.root = root
        self.calls: list[tuple[list[str], float, dict | None]] = []
        self.kwargs: list[tuple[list[str], dict]] = []
        self.commit = commit
        self.save_result = save_result
        self.frame = self.FRAME if frame is None else frame
        self.writes_frame = writes_frame
        self.request_error = request_error
        self.sleeps: list[float] = []
        self.time = 0.0
        self.failed_tests = failed_tests
        self.make_bundle = make_bundle
        self.writes_record = writes_record
        self.exits = exits
        self.busy = busy
        self.lossy_result = lossy_result
        self.save_digest = save_digest
        self.records = records
        self.container = root / "sim-container"
        self.udids = {"27.2": fake_udid(1), "26.5": fake_udid(2)}
        self.package_scenarios: list[list[str]] = []

    def clock(self) -> float:
        return self.time

    def sleep(self, seconds: float) -> None:
        self.sleeps.append(seconds)
        self.time += seconds

    def devices(self) -> dict:
        return {"devices": {
            "com.apple.CoreSimulator.SimRuntime.iOS-27-2": [
                {"udid": self.udids["27.2"], "name": "iPhone 18 Pro", "isAvailable": True,
                 "deviceTypeIdentifier": "com.apple.CoreSimulator.SimDeviceType.iPhone-18-Pro"}],
            "com.apple.CoreSimulator.SimRuntime.iOS-26-5": [
                {"udid": self.udids["26.5"],
                 "name": "iPhone 17", "isAvailable": True,
                 "deviceTypeIdentifier": "com.apple.CoreSimulator.SimDeviceType.iPhone-17"}]}}

    @staticmethod
    def record(experience: str, code: str, scenario: str, run_id: str, result: str = "pass",
               failures=None, final: str | None = None) -> dict:
        rec = verify.load_check_evidence().sample_record()
        rec.update({"experience": experience, "code": code, "scenario": scenario, "result": result,
                    "failures": list(failures or [])})
        rec["run"] = {"id": run_id, "attempt": None, "lock_sha256": None}
        rec["environment"] = {"kind": "simulator", "os_version": None, "os_build": None, "device_type": None,
                              "xcode": None, "swift": None, "sdk": None, "host_os": None, "signing": None}
        rec["source"] = {"commit": None, "dirty": None, "tree": None, "submodules": None, "catalog_sha256": None,
                         "app_sha256": None}
        rec["artifacts"] = {"result_bundle": None, "log": None, "log_sha256": None, "record_sha256": None}
        if final:
            rec["digests"]["final"] = final
        rec["frames"][0].update({"path": None, "sha256": hashlib.sha256(FakeSim.FRAME).hexdigest()})
        return rec

    def summary_json(self, total: int) -> str:
        return json.dumps({"result": "Passed" if self.failed_tests == 0 else "Failed", "totalTestCount": total,
                           "passedTests": total - self.failed_tests, "failedTests": self.failed_tests,
                           "skippedTests": 0, "devicesAndConfigurations": [
                               {"device": {"deviceId": self.udids["27.2"], "deviceName": "iPhone 18 Pro",
                                           "modelName": "iPhone 18 Pro", "osVersion": "27.2"}}]})

    def __call__(self, argv, timeout, cwd=None, env=None, **kw):
        argv = [str(a) for a in argv]
        self.calls.append((argv, timeout, env))
        self.kwargs.append((argv, kw))
        if argv[:5] == ["xcrun", "simctl", "list", "-j", "runtimes"]:
            return 0, json.dumps(self.RUNTIMES), ""
        if argv[:5] == ["xcrun", "simctl", "list", "-j", "devices"]:
            return 0, json.dumps(self.devices()), ""
        canned = {("git", "rev-parse", "HEAD"): self.commit + "\n", ("git", "rev-parse", "HEAD^{tree}"): "b" * 40 + "\n",
                  ("git", "status", "--porcelain"): " M scripts/x.py\n",
                  ("git", "submodule", "status"): " " + "c" * 40 + " External/projectm-ios (heads/main)\n",
                  ("xcodebuild", "-version"): "Xcode 27.2\nBuild version 27C100\n",
                  ("swift", "--version"): "Apple Swift version 6.3 (swiftlang-6.3)\nTarget: arm64-apple-macosx27.0\n",
                  ("xcrun", "--sdk", "iphonesimulator", "--show-sdk-build-version"): "24C5057\n",
                  ("sw_vers", "-productVersion"): "27.2.1\n"}
        if tuple(argv) in canned:
            return 0, canned[tuple(argv)], ""
        if len(argv) > 1 and argv[1] == "scripts/xcodebuild_package.py":
            name = argv[argv.index("--result-name") + 1]
            tests = argv[argv.index("--only-testing") + 1:]
            self.package_scenarios.append(tests)
            if self.make_bundle:
                bundle = self.root / ".autonomy" / "xcresults" / f"{name}.xcresult"
                bundle.mkdir(parents=True, exist_ok=True)
                (bundle / "Info.plist").write_bytes(b"bundle info")
            return (0 if self.failed_tests == 0 else 65), "Test Succeeded\n", ""
        if argv[:5] == ["xcrun", "xcresulttool", "get", "test-results", "summary"]:
            tests = self.package_scenarios[-1]
            return 0, self.summary_json(len(tests)), ""
        if argv[:5] == ["xcrun", "xcresulttool", "get", "test-results", "tests"]:
            cases = [{"nodeType": "Test Case", "name": t.rsplit("/", 1)[-1] + "()",
                      "result": "Failed" if i < self.failed_tests else "Passed"}
                     for i, t in enumerate(self.package_scenarios[-1])]
            return 0, json.dumps({"devices": [], "testNodes": [{"nodeType": "Test Plan", "name": "P", "children": [
                {"nodeType": "Unit test bundle", "name": "VisualCoreExperienceHostTests", "children": [
                    {"nodeType": "Test Suite", "name": "ScenarioRunnerTests", "children": cases}]}]}]}), ""
        if argv[:4] == ["xcrun", "xcresulttool", "export", "attachments"]:
            folder = Path(argv[argv.index("--output-path") + 1])
            entries = []
            for test in self.package_scenarios[-1]:
                method = test.rsplit("/", 1)[-1]
                scenario = next((s for s in verify.STANDARD if verify.test_method(s) == method),
                                "endurance" if method == "testEnduranceKeepsResourcesFlat" else None)
                lossy = method == "testALossySnapshotFailsSaveRestoreByName"
                if lossy:
                    scenario = "save-restore"
                if scenario is None or not self.records:
                    continue
                rec = self.record("a99.contract-sample", "sample", scenario, "package-test",
                                  **({"result": self.lossy_result,
                                      "failures": ["after-restore digest differs from the saved digest"]
                                      if self.lossy_result == "fail" else []} if lossy else {}))
                rec["configuration"]["process"] = "single"
                exported = f"{fake_udid(len(entries) + 10)}.json"
                (folder / exported).write_text(json.dumps(rec))
                suggested = f"evidence-a99.contract-sample-{scenario}{'-lossy' if lossy else ''}_0_{fake_udid(99)}.json"
                attachments = [{"exportedFileName": exported, "suggestedHumanReadableName": suggested}]
                if not lossy and self.writes_frame:
                    frame_file = f"{fake_udid(len(entries) + 50)}.rgba"
                    (folder / frame_file).write_bytes(self.frame)
                    attachments.append({"exportedFileName": frame_file, "suggestedHumanReadableName":
                                        f"frame-a99.contract-sample-{scenario}_0_{fake_udid(98)}.rgba"})
                entries.append({"testIdentifier": f"ScenarioRunnerTests/{method}()", "attachments": attachments})
            (folder / "manifest.json").write_text(json.dumps(entries))
            return 0, "", ""
        if argv[:3] == [verify.PY, "scripts/release_check.py", "--only"]:
            return 0, "", ""
        if argv[:2] == ["xcodebuild", "build"]:
            import plistlib
            app = self.root / verify.APP_PATH
            app.mkdir(parents=True, exist_ok=True)
            (app / "Info.plist").write_bytes(plistlib.dumps({"CFBundleExecutable": "VisualCore"}))
            (app / "VisualCore").write_bytes(b"app binary")
            return 0, "BUILD SUCCEEDED\n", ""
        if argv[:3] == ["xcrun", "simctl", "boot"] or argv[:3] == ["xcrun", "simctl", "bootstatus"] \
                or argv[:3] == ["xcrun", "simctl", "install"]:
            return 0, "", ""
        if argv[:3] == ["xcrun", "simctl", "get_app_container"]:
            self.container.mkdir(parents=True, exist_ok=True)
            return 0, str(self.container) + "\n", ""
        if argv[:3] == ["xcrun", "simctl", "launch"]:
            if self.busy:
                self.busy -= 1
                return 1, "", "An error was encountered processing the command: Busy"
            child = {k[len("SIMCTL_CHILD_"):]: v for k, v in (env or {}).items() if k.startswith("SIMCTL_CHILD_")}
            if self.request_error is not None:
                target = self.container / verify.EVIDENCE_DIR / "invalid-request" / "request-error.json"
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text(json.dumps({"result": "error", "failures": [self.request_error]}))
            elif self.writes_record:
                ident, scenario, run_id = (child["VISUALCORE_AUTORUN_EXPERIENCE"], child["VISUALCORE_AUTORUN_SCENARIO"],
                                           child["VISUALCORE_AUTORUN_RUN"])
                phase = child.get("VISUALCORE_AUTORUN_PHASE")
                rec = self.record(ident, "debug", scenario, run_id, final=self.save_digest if phase == "save" else None)
                if phase == "save" and self.save_result != "pass":
                    rec.update({"result": self.save_result,
                                "failures": ["save phase: the snapshot could not be stored (storage.full)"]})
                target = self.container / verify.EVIDENCE_DIR / run_id / f"{ident}.{scenario}.json"
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text(json.dumps(rec))
                if self.writes_frame:
                    (target.parent / f"{ident}.{scenario}.frame.rgba").write_bytes(self.frame)
            return 0, "dev.visualcore.VisualCore: 4242\n", ""
        if argv[:3] == ["xcrun", "simctl", "terminate"]:
            return 0, "", ""
        if argv[:2] == ["test", "-f"]:
            return (0 if Path(argv[2]).is_file() else 1), "", ""
        if argv[:2] == ["ps", "-p"]:
            return (0, "4242\n", "") if not self.exits else (1, "", "")
        if argv[0] == "cp":
            shutil.copyfile(argv[1], argv[2])
            return 0, "", ""
        if argv[:2] == ["rm", "-rf"]:
            shutil.rmtree(argv[2], ignore_errors=True)
            return 0, "", ""
        if argv[:2] == ["rm", "-f"]:
            Path(argv[2]).unlink(missing_ok=True)
            return 0, "", ""
        if argv[:2] == ["git", "ls-files"]:
            return 0, "", ""
        if argv[0] == "swift" or (len(argv) > 1 and argv[1].startswith("scripts/check_")):
            return 0, "ok\n", ""
        raise AssertionError(f"unexpected command: {argv}")

    def commands(self, *prefix) -> list[list[str]]:
        return [c[0] for c in self.calls if c[0][:len(prefix)] == list(prefix)]


class VerifyDriverTests(unittest.TestCase):
    """Feature UA-F09 T-U09-020, T-U09-021, T-U09-023 (FR-U09-020 to FR-U09-025, FR-U09-033, FR-U09-060, FR-U09-061):
    scripts/verify_experiences.py with an injected runner and clock; no simulator is touched."""

    NOW = datetime.datetime(2026, 11, 12, 10, 0, 0)
    RUN = "verify-20261112T100000"

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        (self.root / "Catalog").mkdir()
        (self.root / "Catalog" / "experiences.json").write_text('{"schema": 1}\n')
        (self.root / "Catalog" / "registrations.json").write_text(
            json.dumps({"schema": 1, "registrations": {"a01.generative-art-studio": {}}}))

    def tearDown(self):
        self.tmp.cleanup()

    def main(self, argv, sim=None, alive=lambda pid: False, now=None):
        sim = sim or FakeSim(self.root)
        lines: list[str] = []
        code = verify.main(argv, root=self.root, run=sim, clock=sim.clock, sleep=sim.sleep,
                           now=lambda: now or self.NOW, out=lines.append, pid_alive=alive, pid=4000)
        return code, lines, sim

    def summary(self, ident, runtime):
        return json.loads((self.root / "docs" / "verification" / ident / f"summary-{runtime}.json").read_text())

    # planning
    def test_planning_per_id_and_alias(self):
        items = verify.plan(["a99.contract-sample", "debug", "a01.generative-art-studio"], [], None,
                            ["a01.generative-art-studio"])
        self.assertEqual([(i["id"], i["path"], i["code"]) for i in items],
                         [("a99.contract-sample", "package", "sample"), ("a98.debug-experience", "app", "debug"),
                          ("a01.generative-art-studio", "app", None)])
        self.assertEqual(items[0]["scenarios"], verify.STANDARD)
        self.assertEqual(len(verify.STANDARD), 9)
        self.assertEqual(verify.test_method("launch-first-frame"), "testLaunchFirstFrame")
        self.assertEqual(verify.test_method("cancel-prepare"), "testCancelPrepare")

    def test_unknown_id_or_scenario_and_no_id_exit_2(self):
        for argv in (["--only", "a02.not-registered"], ["--only", "debug", "--scenario", "nope"], [],
                     ["--only", "debug", "--runtime", "x27"], ["--bogus"]):
            with contextlib.redirect_stderr(io.StringIO()):
                code, lines, sim = self.main(argv + ["--dry-run"] if argv and argv[0] != "--bogus" else argv)
            self.assertEqual(code, 2, argv)
            self.assertEqual(sim.calls, [])
        code, lines, _ = self.main(["--only", "a02.not-registered"])
        self.assertIn("unknown experience: a02.not-registered", lines[0])

    def test_only_skip_and_scenario_select(self):
        items = verify.plan(["a99.contract-sample", "debug", "debug"], ["a98.debug-experience"],
                            ["reset", "endurance", "reset"], [])
        self.assertEqual([i["id"] for i in items], ["a99.contract-sample"])
        self.assertEqual(items[0]["scenarios"], ["reset", "endurance"])
        self.assertEqual(verify.plan(["debug"], ["debug"], None, []), [])

    def test_dry_run_runs_nothing(self):
        code, lines, sim = self.main(["--only", "a99.contract-sample", "debug", "--runtime", "27", "26", "--dry-run"])
        self.assertEqual(code, 0)
        self.assertEqual(sim.calls, [])
        text = "\n".join(lines)
        self.assertIn("--destination sim-27.x", text)
        self.assertIn("--destination sim-26.5", text)
        self.assertIn("ScenarioRunnerTests/testLaunchFirstFrame", text)
        self.assertIn("_EXPERIENCE=a98.debug-experience", text)
        self.assertFalse((self.root / ".autonomy").exists())

    def test_runtime_resolution(self):
        runtimes = verify.parse_runtimes(json.dumps(FakeSim.RUNTIMES))
        self.assertEqual(verify.resolve_runtime(runtimes, "27")["version"], "27.2")
        self.assertEqual(verify.resolve_runtime(runtimes, "26")["version"], "26.5")
        self.assertEqual(verify.resolve_runtime(runtimes, "26.2")["build"], "23C1")
        with self.assertRaises(verify.BadInput):
            verify.resolve_runtime(runtimes, "25")

    # the package path
    def test_package_path_passes_completes_records_and_writes_a_summary(self):
        code, lines, sim = self.main(["--only", "a99.contract-sample", "--runtime", "27"])
        self.assertEqual(code, 0, lines)
        self.assertEqual(len(sim.commands("swift", "test")), 1)
        tests = sim.package_scenarios[0]
        self.assertEqual(tests, [f"VisualCoreExperienceHostTests/ScenarioRunnerTests/{verify.test_method(s)}"
                                 for s in verify.STANDARD])
        self.assertEqual(len(sim.commands("xcrun", "xcresulttool", "get", "test-results", "summary")), 1)
        summary = self.summary("a99.contract-sample", "27.2")
        self.assertEqual([r["result"] for r in summary["results"]], ["pass"] * 9)
        self.assertEqual(summary["bundle"], {"result": "Passed", "total": 9, "passed": 9, "failed": 0,
                                             "destination": {"name": "iPhone 18 Pro", "os": "27.2"},
                                             "failed_tests": []})
        self.assertEqual(len(sim.commands("xcrun", "xcresulttool", "get", "test-results", "tests")), 1)
        self.assertEqual((summary["runtime"], summary["runtime_build"]), ("27.2", "24B8117"))
        self.assertEqual(summary["device_type"], "com.apple.CoreSimulator.SimDeviceType.iPhone-18-Pro")
        record_path = self.root / ".autonomy" / "verify" / self.RUN / "27.2" / "a99.contract-sample.reset.json"
        record = json.loads(record_path.read_text())
        self.assertEqual(verify.load_check_evidence().validate(record), [])
        self.assertEqual(record["environment"], {
            "kind": "simulator", "os_version": "27.2", "os_build": "24B8117",
            "device_type": "com.apple.CoreSimulator.SimDeviceType.iPhone-18-Pro", "xcode": "27.2 (27C100)",
            "swift": "Apple Swift version 6.3 (swiftlang-6.3)", "sdk": "24C5057", "host_os": "27.2.1",
            "signing": "none"})
        self.assertEqual(record["source"]["commit"], "a" * 40)
        self.assertEqual(record["source"]["tree"], "b" * 40)
        self.assertTrue(record["source"]["dirty"])
        self.assertEqual(record["source"]["submodules"], {"External/projectm-ios": "c" * 40})
        self.assertEqual(record["source"]["catalog_sha256"],
                         hashlib.sha256((self.root / "Catalog" / "experiences.json").read_bytes()).hexdigest())
        self.assertEqual(record["source"]["app_sha256"], hashlib.sha256(b"bundle info").hexdigest())
        self.assertEqual((record["run"]["id"], record["run"]["attempt"]), (self.RUN, 1))
        self.assertTrue(record["artifacts"]["result_bundle"].startswith(".autonomy/xcresults/verify-a99"))
        sealed = json.loads(json.dumps(record))
        sealed["artifacts"]["record_sha256"] = None
        digest = hashlib.sha256(verify.dump(sealed).encode()).hexdigest()
        self.assertEqual(record["artifacts"]["record_sha256"], digest)
        reset = summary["results"][5]
        self.assertEqual((reset["scenario"], reset["result"], reset["record_sha256"]), ("reset", "pass", digest))
        self.assertIn("commit", reset, "each row names the commit it was made at")
        state = json.loads((self.root / ".autonomy" / "verify" / "state.json").read_text())
        self.assertEqual(state["runs"]["a99.contract-sample|reset|27.2"]["result"], "pass")
        self.assertFalse((self.root / ".autonomy" / "verify" / "lock").exists())

    def test_summary_and_records_carry_no_simulator_identifier(self):
        code, lines, sim = self.main(["--only", "a99.contract-sample", "debug", "--runtime", "27", "26"])
        self.assertEqual(code, 0, lines)
        texts = [p.read_text() for p in (self.root / "docs" / "verification").rglob("*.json")]
        texts += [p.read_text() for p in (self.root / ".autonomy" / "verify" / self.RUN).glob("*/*.json")]
        self.assertEqual(len(list((self.root / "docs" / "verification").rglob("*.json"))), 4)
        for text in texts:
            self.assertIsNone(verify.UDID.search(text))
            for udid in sim.udids.values():
                self.assertNotIn(udid, text)
        for path in (self.root / "docs" / "verification").rglob("*.json"):
            self.assertTrue(path.read_text().endswith("\n"))
        for line in lines:
            self.assertIsNone(verify.UDID.search(line), line)

    def test_a_failed_bundle_fails_every_scenario(self):
        code, lines, sim = self.main(["--only", "a99.contract-sample", "--runtime", "27"], FakeSim(self.root,
                                                                                                   failed_tests=1))
        self.assertEqual(code, 1)
        self.assertEqual(sum(line.startswith("FAIL: a99.contract-sample") and "result bundle did not pass" in line
                             for line in lines), 9)
        self.assertEqual(self.summary("a99.contract-sample", "27.2")["bundle"]["failed"], 1)

    def test_a_missing_bundle_fails(self):
        code, lines, sim = self.main(["--only", "a99.contract-sample", "--runtime", "27", "--scenario", "reset"],
                                     FakeSim(self.root, make_bundle=False))
        self.assertEqual(code, 1)
        self.assertEqual(sim.commands("xcrun", "xcresulttool"), [])
        self.assertIn("FAIL: a99.contract-sample reset 27.2: no record in the result bundle", lines)
        self.assertEqual(self.summary("a99.contract-sample", "27.2")["bundle"]["result"], "missing")

    def test_a_scenario_without_a_record_in_the_bundle_fails_by_name(self):
        code, lines, _ = self.main(["--only", "a99.contract-sample", "--runtime", "27", "--scenario", "reset"],
                                   FakeSim(self.root, records=False))
        self.assertEqual(code, 1)
        self.assertIn("FAIL: a99.contract-sample reset 27.2: no record in the result bundle", lines)

    def test_endurance_is_validated_and_counted_by_its_record(self):
        code, lines, sim = self.main(["--only", "a99.contract-sample", "--scenario", "endurance", "--runtime", "27"])
        self.assertEqual(code, 0, lines)
        self.assertEqual(sim.package_scenarios,
                         [["VisualCoreExperienceHostTests/ScenarioRunnerTests/testEnduranceKeepsResourcesFlat"]])
        rows = self.summary("a99.contract-sample", "27.2")["results"]
        # Every standard scenario is listed (not run here), then the endurance row.
        self.assertEqual([r["scenario"] for r in rows[:9]], verify.STANDARD)
        self.assertTrue(all(r["result"] == "not-run" for r in rows[:9]))
        row = rows[9]
        record_path = self.root / ".autonomy" / "verify" / self.RUN / "27.2" / "a99.contract-sample.endurance.json"
        record = json.loads(record_path.read_text())
        self.assertEqual(verify.load_check_evidence().validate(record), [])
        self.assertEqual((row["scenario"], row["result"], row["record_sha256"]),
                         ("endurance", "pass", record["artifacts"]["record_sha256"]))
        self.assertNotIn("evidence", row)
        self.assertFalse(any("result bundle only" in line for line in lines))
        self.assertTrue(record["artifacts"]["result_bundle"].endswith("-endurance.xcresult"))

    def test_endurance_without_its_record_fails_by_name(self):
        code, lines, _ = self.main(["--only", "a99.contract-sample", "--scenario", "endurance", "--runtime", "27"],
                                   FakeSim(self.root, records=False))
        self.assertEqual(code, 1)
        self.assertIn("FAIL: a99.contract-sample endurance 27.2: no record in the result bundle", lines)

    def test_a_package_run_with_endurance_joins_both_bundles_in_the_block(self):
        code, lines, sim = self.main(["--only", "a99.contract-sample", "--scenario", "reset", "endurance",
                                      "--runtime", "27"])
        self.assertEqual(code, 0, lines)
        self.assertEqual(len(sim.package_scenarios), 2)
        bundle = self.summary("a99.contract-sample", "27.2")["bundle"]
        self.assertEqual((bundle["result"], bundle["total"], bundle["passed"]), ("Passed", 2, 2))

    def make_test_binary(self, data=b"test binary"):
        path = (self.root / "Build" / "DerivedData" / "VisualCoreRendering-sim-27.2" / "Build" / "Products"
                / "Debug-iphonesimulator" / "VisualCoreExperienceHostTests.xctest" / "VisualCoreExperienceHostTests")
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        return path

    def test_state_skips_what_passed_and_fresh_reruns(self):
        self.make_test_binary()
        self.main(["--only", "a99.contract-sample", "--runtime", "27"])
        code, lines, sim = self.main(["--only", "a99.contract-sample", "--runtime", "27"],
                                     now=datetime.datetime(2026, 11, 12, 11, 0, 0))
        self.assertEqual(code, 0)
        self.assertEqual(sim.package_scenarios, [])
        self.assertTrue(any("passed earlier at this commit with this binary, skipped" in line for line in lines))
        code, lines, sim = self.main(["--only", "a99.contract-sample", "--runtime", "27", "--fresh"],
                                     now=datetime.datetime(2026, 11, 12, 12, 0, 0))
        self.assertEqual(code, 0)
        self.assertEqual(len(sim.package_scenarios), 1)
        state = json.loads((self.root / ".autonomy" / "verify" / "state.json").read_text())
        self.assertEqual(state["runs"]["a99.contract-sample|reset|27.2"]["attempt"], 2)

    def test_a_pass_at_another_commit_or_with_another_binary_is_run_again(self):
        self.make_test_binary()
        self.main(["--only", "a99.contract-sample", "--runtime", "27", "--scenario", "reset"])
        state = json.loads((self.root / ".autonomy" / "verify" / "state.json").read_text())
        entry = state["runs"]["a99.contract-sample|reset|27.2"]
        self.assertEqual((entry["result"], entry["commit"]), ("pass", "a" * 40))
        self.assertEqual(entry["binary_sha256"], hashlib.sha256(b"test binary").hexdigest())
        # Same commit, same binary: skipped.
        code, lines, sim = self.main(["--only", "a99.contract-sample", "--runtime", "27", "--scenario", "reset"],
                                     now=datetime.datetime(2026, 11, 12, 11, 0, 0))
        self.assertEqual((code, sim.package_scenarios), (0, []))
        # Another commit: run again.
        code, lines, sim = self.main(["--only", "a99.contract-sample", "--runtime", "27", "--scenario", "reset"],
                                     FakeSim(self.root, commit="e" * 40), now=datetime.datetime(2026, 11, 12, 12))
        self.assertEqual(code, 0, lines)
        self.assertEqual(sim.package_scenarios, [["VisualCoreExperienceHostTests/ScenarioRunnerTests/testReset"]])
        # Same commit as that run, but another binary: run again.
        self.make_test_binary(b"rebuilt test binary")
        code, lines, sim = self.main(["--only", "a99.contract-sample", "--runtime", "27", "--scenario", "reset"],
                                     FakeSim(self.root, commit="e" * 40), now=datetime.datetime(2026, 11, 12, 13))
        self.assertEqual(len(sim.package_scenarios), 1)
        # No binary on disk: nothing can be shown to be the same, so it runs.
        self.make_test_binary().unlink()
        code, lines, sim = self.main(["--only", "a99.contract-sample", "--runtime", "27", "--scenario", "reset"],
                                     FakeSim(self.root, commit="e" * 40), now=datetime.datetime(2026, 11, 12, 14))
        self.assertEqual(len(sim.package_scenarios), 1)

    def test_the_app_path_resume_compares_the_app_binary(self):
        self.main(["--only", "debug", "--runtime", "27", "--scenario", "reset"])
        state = json.loads((self.root / ".autonomy" / "verify" / "state.json").read_text())
        self.assertEqual(state["runs"]["a98.debug-experience|reset|27.2"]["binary_sha256"],
                         hashlib.sha256(b"app binary").hexdigest())
        code, lines, sim = self.main(["--only", "debug", "--runtime", "27", "--scenario", "reset"],
                                     now=datetime.datetime(2026, 11, 12, 11))
        self.assertEqual((code, sim.commands("xcrun", "simctl", "launch")), (0, []))
        (self.root / verify.APP_PATH / "VisualCore").write_bytes(b"another app binary")
        code, lines, sim = self.main(["--only", "debug", "--runtime", "27", "--scenario", "reset"],
                                     now=datetime.datetime(2026, 11, 12, 12))
        self.assertEqual(len(sim.commands("xcrun", "simctl", "launch")), 1)

    def test_resume_runs_only_what_did_not_pass(self):
        self.make_test_binary()
        self.main(["--only", "a99.contract-sample", "--runtime", "27"], FakeSim(self.root, failed_tests=1))
        code, lines, sim = self.main(["--only", "a99.contract-sample", "--runtime", "27", "--scenario", "reset"],
                                     now=datetime.datetime(2026, 11, 12, 11, 0, 0))
        self.assertEqual(code, 0)
        self.assertEqual(sim.package_scenarios, [["VisualCoreExperienceHostTests/ScenarioRunnerTests/testReset"]])

    def test_the_lock_refuses_a_second_run_and_a_stale_lock_is_removed(self):
        lock = self.root / ".autonomy" / "verify" / "lock"
        lock.parent.mkdir(parents=True)
        lock.write_text("3999\n")
        code, lines, sim = self.main(["--only", "a99.contract-sample", "--runtime", "27"], alive=lambda pid: True)
        self.assertEqual(code, 1)
        self.assertEqual(sim.calls, [])
        self.assertIn("holds", lines[0])
        self.assertTrue(lock.exists())
        code, lines, sim = self.main(["--only", "a99.contract-sample", "--runtime", "27"], alive=lambda pid: False)
        self.assertEqual(code, 0, lines)
        self.assertIn("stale lock of pid 3999 removed", lines)
        self.assertFalse(lock.exists())

    def test_environment_and_source_completion_from_canned_outputs(self):
        outputs = {("xcodebuild", "-version"): "Xcode 27.2\nBuild version 27C100\n",
                   ("swift", "--version"): "swift-driver version: 1.120\nApple Swift version 6.3\n",
                   ("xcrun", "--sdk", "iphonesimulator", "--show-sdk-build-version"): "24C5057\n",
                   ("sw_vers", "-productVersion"): "27.2.1\n", ("git", "rev-parse", "HEAD"): "1" * 40 + "\n",
                   ("git", "rev-parse", "HEAD^{tree}"): "2" * 40 + "\n", ("git", "status", "--porcelain"): "",
                   ("git", "submodule", "status"): "+" + "3" * 40 + " External/projectm-ios (v1)\n-" + "4" * 40
                   + " Vendor/x\n"}
        driver = verify.Driver(root=self.root, run=lambda argv, timeout, **kw: (0, outputs[tuple(argv)], ""))
        env = driver.environment({"version": "26.5", "build": "23F77", "identifier": "x"},
                                 {"udid": fake_udid(3), "name": "iPhone 17", "device_type": "dt.iPhone-17"})
        self.assertEqual(env, {"kind": "simulator", "os_version": "26.5", "os_build": "23F77",
                               "device_type": "dt.iPhone-17", "xcode": "27.2 (27C100)",
                               "swift": "swift-driver version: 1.120", "sdk": "24C5057", "host_os": "27.2.1",
                               "signing": "none"})
        source = driver.source("5" * 64)
        self.assertEqual(source["submodules"], {"External/projectm-ios": "3" * 40, "Vendor/x": "4" * 40})
        self.assertEqual((source["commit"], source["tree"], source["dirty"], source["app_sha256"]),
                         ("1" * 40, "2" * 40, False, "5" * 64))

    # result bundles (T-U09-023)
    def test_bundle_summary_parsing(self):
        passed = verify.parse_bundle_summary(json.dumps({
            "result": "Passed", "totalTestCount": 10, "passedTests": 10, "failedTests": 0, "skippedTests": 0,
            "devicesAndConfigurations": [{"device": {"modelName": "iPhone 18 Pro", "osVersion": "27.2",
                                                     "deviceId": fake_udid(4)}}]}))
        self.assertTrue(passed["ok"])
        self.assertEqual(passed["destination"], {"name": "iPhone 18 Pro", "os": "27.2"})
        self.assertNotIn(fake_udid(4), json.dumps(passed))
        failed = verify.parse_bundle_summary(json.dumps({"result": "Failed", "totalTestCount": 10, "passedTests": 9,
                                                         "failedTests": 1}))
        self.assertFalse(failed["ok"])
        self.assertEqual((failed["failed"], failed["passed"]), (1, 9))
        self.assertFalse(verify.parse_bundle_summary(json.dumps({"result": "Passed", "totalTestCount": 3,
                                                                 "failedTests": 1}))["ok"])
        self.assertFalse(verify.parse_bundle_summary(json.dumps({"result": "Passed", "totalTestCount": 0}))["ok"])
        for broken in ("", "not json", "[]", json.dumps({"failedTests": "x"})):
            self.assertFalse(verify.parse_bundle_summary(broken)["ok"])

    def test_attachment_export_parsing(self):
        with tempfile.TemporaryDirectory() as d:
            folder = Path(d)
            (folder / "manifest.json").write_text(json.dumps([
                {"testIdentifier": "T/a()", "attachments": [
                    {"exportedFileName": "one.json",
                     "suggestedHumanReadableName": f"evidence-a99.contract-sample-reset_0_{fake_udid(5)}.json"}]},
                {"testIdentifier": "T/b()", "attachments": [{"exportedFileName": "two.json"}]}]))
            found = verify.parse_attachments(folder)
            self.assertEqual([(n[:37], p.name) for n, p in found],
                             [("evidence-a99.contract-sample-reset_0_", "one.json"), ("two.json", "two.json")])
            (folder / "manifest.json").unlink()
            (folder / "evidence-a99.contract-sample-completion.json").write_text("{}")
            (folder / "other.json").write_text("{}")
            self.assertEqual([n for n, _ in verify.parse_attachments(folder)],
                             ["evidence-a99.contract-sample-completion.json"])
        scen = verify.attachment_scenario
        self.assertEqual(scen(f"evidence-a99.contract-sample-save-restore-lossy_0_{fake_udid(6)}.json",
                              "a99.contract-sample"), "save-restore-lossy")
        self.assertEqual(scen("evidence-a99.contract-sample-launch-first-frame.json", "a99.contract-sample"),
                         "launch-first-frame")
        self.assertIsNone(scen("evidence-a98.debug-experience-reset.json", "a99.contract-sample"))
        self.assertIsNone(scen("screenshot.png", "a99.contract-sample"))

    # the app path
    def test_app_path_passes_with_save_restore_over_two_launches(self):
        code, lines, sim = self.main(["--only", "debug", "--runtime", "27"])
        self.assertEqual(code, 0, lines)
        self.assertEqual(len(sim.commands("xcodebuild", "build")), 1)
        self.assertEqual(sim.commands(verify.PY, "scripts/release_check.py"),
                         [[verify.PY, "scripts/release_check.py", "--only", "xcodegen"]])
        self.assertEqual(sim.commands("xcrun", "simctl", "bootstatus")[0][-1], "-b")
        launches = [c for c in sim.calls if c[0][:3] == ["xcrun", "simctl", "launch"]]
        self.assertEqual(len(launches), 10)
        envs = [{k: v for k, v in c[2].items() if k.startswith("SIMCTL_CHILD_")} for c in launches]
        self.assertTrue(all(c[0][3] == "--terminate-running-process" for c in launches))
        save, restore = [e for e in envs if e["SIMCTL_CHILD_VISUALCORE_AUTORUN_SCENARIO"] == "save-restore"]
        self.assertEqual(save["SIMCTL_CHILD_VISUALCORE_AUTORUN_PHASE"], "save")
        self.assertNotIn("SIMCTL_CHILD_VISUALCORE_AUTORUN_EXPECTED_DIGEST", save)
        self.assertEqual(restore["SIMCTL_CHILD_VISUALCORE_AUTORUN_PHASE"], "restore")
        self.assertEqual(restore["SIMCTL_CHILD_VISUALCORE_AUTORUN_EXPECTED_DIGEST"], "d" * 64)
        self.assertEqual({e["SIMCTL_CHILD_VISUALCORE_AUTORUN"] for e in envs}, {"scenario"})
        self.assertEqual({e["SIMCTL_CHILD_VISUALCORE_AUTORUN_EXPERIENCE"] for e in envs}, {"a98.debug-experience"})
        self.assertEqual({e["SIMCTL_CHILD_VISUALCORE_AUTORUN_RUN"] for e in envs}, {self.RUN})
        storage = [c for c in sim.commands("rm", "-rf") if c[2].endswith("Experiences/a98.debug-experience")]
        self.assertEqual(len(storage), 1, "the saved state is removed before the save phase only")
        out_dir = self.root / ".autonomy" / "verify" / self.RUN / "27.2"
        self.assertTrue((out_dir / "a98.debug-experience.save-restore.save.json").is_file())
        record = json.loads((out_dir / "a98.debug-experience.save-restore.json").read_text())
        self.assertEqual(record["source"]["app_sha256"], hashlib.sha256(b"app binary").hexdigest())
        self.assertIsNone(record["artifacts"]["result_bundle"])
        self.assertEqual(self.summary("a98.debug-experience", "27.2")["bundle"], None)

    def test_the_record_is_removed_from_the_container_after_it_was_copied(self):
        code, lines, sim = self.main(["--only", "debug", "--runtime", "27", "--scenario", "reset"])
        self.assertEqual(code, 0, lines)
        record = f"{sim.container}/{verify.EVIDENCE_DIR}/{self.RUN}/a98.debug-experience.reset.json"
        order = [c[0] for c in sim.calls]
        copy = order.index(["cp", record, str(self.root / ".autonomy" / "verify" / self.RUN / "27.2"
                                               / "a98.debug-experience.reset.json")])
        self.assertEqual(order[copy + 1], ["rm", "-f", record])
        self.assertFalse(Path(record).exists())

    def test_a_scenario_whose_record_never_appears_fails_by_name_after_the_limit(self):
        code, lines, sim = self.main(["--only", "debug", "--runtime", "27", "--scenario", "launch-first-frame"],
                                     FakeSim(self.root, writes_record=False, exits=False))
        self.assertEqual(code, 1)
        self.assertIn("FAIL: a98.debug-experience launch-first-frame 27.2: no record within 120 s", lines)
        terminate = [c for c in sim.calls if c[0][:3] == ["xcrun", "simctl", "terminate"]]
        self.assertEqual([(c[0][3:], c[1]) for c in terminate],
                         [([sim.udids["27.2"], "dev.visualcore.VisualCore"], 30)])
        self.assertIn("a98.debug-experience launch-first-frame 27.2: the app was terminated (xcrun simctl terminate, "
                      "exit 0)", lines)
        self.assertGreaterEqual(sim.time, 120)
        self.assertLess(sim.time, 122)
        self.assertEqual(set(sim.sleeps), {1})
        code, lines, sim = self.main(["--only", "debug", "--runtime", "27", "--scenario", "reset",
                                      "--max-seconds", "15"], FakeSim(self.root, writes_record=False, exits=False))
        self.assertIn("FAIL: a98.debug-experience reset 27.2: no record within 15 s", lines)

    def test_endurance_waits_its_time_plus_120_seconds(self):
        code, lines, sim = self.main(["--only", "debug", "--runtime", "27", "--scenario", "endurance"],
                                     FakeSim(self.root, writes_record=False, exits=False))
        self.assertIn("FAIL: a98.debug-experience endurance 27.2: no record within 720 s", lines)

    def test_a_process_that_does_not_exit_fails_by_name(self):
        code, lines, sim = self.main(["--only", "debug", "--runtime", "27", "--scenario", "reset"],
                                     FakeSim(self.root, exits=False))
        self.assertEqual(code, 1)
        self.assertIn("FAIL: a98.debug-experience reset 27.2: the process did not exit within 30 s", lines)
        self.assertTrue(sim.commands("ps", "-p", "4242"))
        self.assertEqual(sim.commands("xcrun", "simctl", "terminate"),
                         [["xcrun", "simctl", "terminate", sim.udids["27.2"], "dev.visualcore.VisualCore"]])

    def test_a_crash_is_detected_at_once(self):
        code, lines, sim = self.main(["--only", "debug", "--runtime", "27", "--scenario", "reset"],
                                     FakeSim(self.root, writes_record=False, exits=True))
        self.assertEqual(code, 1)
        self.assertIn("FAIL: a98.debug-experience reset 27.2: the app exited without a record (crash)", lines)
        self.assertLess(sim.time, 2, "the wait ends when the process is gone, not after the limit")
        self.assertEqual(sim.commands("xcrun", "simctl", "terminate"), [])

    def test_a_request_error_of_the_app_is_reported(self):
        code, lines, sim = self.main(["--only", "debug", "--runtime", "27", "--scenario", "reset"],
                                     FakeSim(self.root, request_error="request.invalid-run"))
        self.assertEqual(code, 1)
        self.assertIn("FAIL: a98.debug-experience reset 27.2: the request was refused: request.invalid-run", lines)
        code, lines, sim = self.main(["--only", "debug", "--runtime", "27", "--scenario", "reset", "--fresh"],
                                     FakeSim(self.root, request_error="request.invalid-seed", exits=False))
        self.assertIn("FAIL: a98.debug-experience reset 27.2: no record within 120 s; the request was refused: "
                      "request.invalid-seed", lines)

    def test_a_package_test_run_is_its_own_process_group_killed_at_the_limit(self):
        code, lines, sim = self.main(["--only", "a99.contract-sample", "--runtime", "27", "--scenario", "reset"])
        self.assertEqual(code, 0, lines)
        runs = [(argv, kw) for argv, kw in sim.kwargs if argv[1:2] == ["scripts/xcodebuild_package.py"]]
        self.assertEqual([kw for _, kw in runs], [{"kill_group": True}])
        timeouts = [c[1] for c in sim.calls if c[0][1:2] == ["scripts/xcodebuild_package.py"]]
        self.assertEqual(timeouts, [540])
        self.assertEqual(verify.TEST_RUN_LIMIT, 540)

    def test_system_run_kills_the_whole_group_at_the_limit(self):
        with tempfile.TemporaryDirectory() as d:
            pidfile = Path(d) / "child.pid"
            start = time.monotonic()
            code, out, err = verify.system_run(["/bin/sh", "-c", f"sleep 30 & echo $! > {pidfile}; wait"], 1,
                                               kill_group=True)
            self.assertEqual(code, 124)
            self.assertIn("process group killed", err)
            self.assertLess(time.monotonic() - start, 15)
            child = int(pidfile.read_text().strip())
            deadline = time.monotonic() + 5
            gone = False
            while time.monotonic() < deadline and not gone:
                try:
                    os.kill(child, 0)
                    time.sleep(0.05)
                except ProcessLookupError:
                    gone = True
            self.assertTrue(gone, "the background child of the command was killed with its group")
        self.assertEqual(verify.system_run(["/bin/sh", "-c", "echo ok"], 10, kill_group=True), (0, "ok\n", ""))

    def test_busy_is_retried_once_after_20_seconds(self):
        code, lines, sim = self.main(["--only", "debug", "--runtime", "27", "--scenario", "reset"],
                                     FakeSim(self.root, busy=1))
        self.assertEqual(code, 0, lines)
        self.assertEqual(sim.sleeps.count(20), 1)
        self.assertEqual(len(sim.commands("xcrun", "simctl", "launch")), 2)
        code, lines, sim = self.main(["--only", "debug", "--runtime", "27", "--scenario", "reset", "--fresh"],
                                     FakeSim(self.root, busy=2))
        self.assertEqual(code, 1)
        self.assertEqual(len(sim.commands("xcrun", "simctl", "launch")), 2)
        self.assertTrue(any(line.startswith("FAIL: a98.debug-experience reset 27.2: launch failed") for line in lines))

    def test_a_failing_record_makes_the_exit_non_zero(self):
        sim = FakeSim(self.root)
        original = sim.record

        def failing(*args, **kw):
            rec = original(*args, **kw)
            rec.update({"result": "fail", "failures": ["after-reset digest differs"]})
            return rec
        sim.record = failing
        code, lines, _ = self.main(["--only", "debug", "--runtime", "27", "--scenario", "reset"], sim)
        self.assertEqual(code, 1)
        self.assertTrue(any("after-reset digest differs" in line for line in lines))
        row = next(r for r in self.summary("a98.debug-experience", "27.2")["results"] if r["scenario"] == "reset")
        self.assertEqual(row["result"], "fail")

    def test_a_wrong_code_fails(self):
        sim = FakeSim(self.root)
        original = sim.record
        sim.record = lambda *a, **kw: dict(original(*a, **kw), code="sample")
        code, lines, _ = self.main(["--only", "debug", "--runtime", "27", "--scenario", "reset"], sim)
        self.assertEqual(code, 1)
        self.assertTrue(any("code 'sample' is not 'debug'" in line for line in lines))

    # the save phase (T-U09-041)
    def test_a_failing_save_record_fails_save_restore_without_a_restore_launch(self):
        code, lines, sim = self.main(["--only", "debug", "--runtime", "27", "--scenario", "save-restore"],
                                     FakeSim(self.root, save_result="fail"))
        self.assertEqual(code, 1)
        self.assertTrue(any(line.startswith("FAIL: a98.debug-experience save-restore 27.2: save phase: ")
                            and "the snapshot could not be stored" in line for line in lines), lines)
        launches = [c[2] for c in sim.calls if c[0][:3] == ["xcrun", "simctl", "launch"]]
        self.assertEqual([e["SIMCTL_CHILD_VISUALCORE_AUTORUN_PHASE"] for e in launches], ["save"])
        saved = json.loads((self.root / ".autonomy" / "verify" / self.RUN / "27.2"
                            / "a98.debug-experience.save-restore.save.json").read_text())
        self.assertEqual(verify.load_check_evidence().validate(saved), [], "the save record is kept, completed")
        self.assertEqual(saved["source"]["commit"], "a" * 40)
        self.assertIsNotNone(saved["artifacts"]["record_sha256"])
        row = next(r for r in self.summary("a98.debug-experience", "27.2")["results"] if r["scenario"] == "save-restore")
        self.assertEqual(row["result"], "fail")

    def test_an_invalid_save_record_fails_save_restore(self):
        sim = FakeSim(self.root)
        original = sim.record
        sim.record = lambda *a, **kw: dict(original(*a, **kw), unexpected=1) if kw.get("final") else original(*a, **kw)
        code, lines, _ = self.main(["--only", "debug", "--runtime", "27", "--scenario", "save-restore"], sim)
        self.assertEqual(code, 1)
        self.assertTrue(any("save phase: record: unexpected" in line for line in lines), lines)
        self.assertEqual(len(sim.commands("xcrun", "simctl", "launch")), 1)

    # frames (T-U09-049)
    def test_the_app_frame_is_kept_hashed_and_named_in_the_record(self):
        code, lines, sim = self.main(["--only", "debug", "--runtime", "27", "--scenario", "reset", "save-restore"])
        self.assertEqual(code, 0, lines)
        out_dir = self.root / ".autonomy" / "verify" / self.RUN / "27.2"
        frame = out_dir / "a98.debug-experience.reset.frame.rgba"
        self.assertEqual(frame.read_bytes(), FakeSim.FRAME)
        record = json.loads((out_dir / "a98.debug-experience.reset.json").read_text())
        self.assertEqual(record["frames"][0]["path"],
                         f".autonomy/verify/{self.RUN}/27.2/a98.debug-experience.reset.frame.rgba")
        sealed = json.loads(json.dumps(record))
        sealed["artifacts"]["record_sha256"] = None
        self.assertEqual(record["artifacts"]["record_sha256"], hashlib.sha256(verify.dump(sealed).encode()).hexdigest())
        self.assertFalse((sim.container / verify.EVIDENCE_DIR / self.RUN / "a98.debug-experience.reset.frame.rgba")
                         .exists(), "the frame is removed from the container")
        self.assertTrue((out_dir / "a98.debug-experience.save-restore.save.frame.rgba").is_file())
        self.assertTrue((out_dir / "a98.debug-experience.save-restore.frame.rgba").is_file())

    def test_a_frame_with_another_hash_or_no_frame_fails(self):
        code, lines, _ = self.main(["--only", "debug", "--runtime", "27", "--scenario", "reset"],
                                   FakeSim(self.root, frame=b"\x00" * 16))
        self.assertEqual(code, 1)
        self.assertTrue(any(line.startswith("FAIL: a98.debug-experience reset 27.2: frame: SHA-256 of ")
                            for line in lines), lines)
        code, lines, _ = self.main(["--only", "debug", "--runtime", "27", "--scenario", "reset", "--fresh"],
                                   FakeSim(self.root, writes_frame=False))
        self.assertEqual(code, 1)
        self.assertIn("FAIL: a98.debug-experience reset 27.2: frame: no frame file a98.debug-experience.reset.frame.rgba "
                      "beside the record", lines)
        code, lines, _ = self.main(["--only", "a99.contract-sample", "--runtime", "27", "--scenario", "reset"],
                                   FakeSim(self.root, writes_frame=False))
        self.assertIn("FAIL: a99.contract-sample reset 27.2: frame: no frame file a99.contract-sample.reset.frame.rgba "
                      "beside the record", lines)

    def test_the_package_frame_comes_from_the_attachments(self):
        code, lines, _ = self.main(["--only", "a99.contract-sample", "--runtime", "27", "--scenario", "completion"])
        self.assertEqual(code, 0, lines)
        out_dir = self.root / ".autonomy" / "verify" / self.RUN / "27.2"
        self.assertEqual((out_dir / "a99.contract-sample.completion.frame.rgba").read_bytes(), FakeSim.FRAME)
        record = json.loads((out_dir / "a99.contract-sample.completion.json").read_text())
        self.assertEqual(record["frames"][0]["path"],
                         f".autonomy/verify/{self.RUN}/27.2/a99.contract-sample.completion.frame.rgba")
        self.assertEqual(verify.attachment_scenario(f"frame-a99.contract-sample-reset_0_{fake_udid(7)}.rgba",
                                                    "a99.contract-sample", "frame", ".rgba"), "reset")
        self.assertIsNone(verify.attachment_scenario("frame-a99.contract-sample-reset.json", "a99.contract-sample",
                                                     "frame", ".rgba"))

    # the bundle block (T-U09-048)
    def test_failed_test_names_and_the_destination_reach_the_summary(self):
        code, lines, sim = self.main(["--only", "a99.contract-sample", "--runtime", "27", "--scenario", "reset",
                                      "completion"], FakeSim(self.root, failed_tests=1))
        self.assertEqual(code, 1)
        bundle = self.summary("a99.contract-sample", "27.2")["bundle"]
        self.assertEqual(bundle["failed_tests"], ["testReset()"])
        self.assertEqual(bundle["destination"], {"name": "iPhone 18 Pro", "os": "27.2"})
        self.assertTrue(any("result bundle Failed" in line and "(testReset())" in line for line in lines))
        record = json.loads((self.root / ".autonomy" / "verify" / self.RUN / "27.2"
                             / "a99.contract-sample.reset.json").read_text())
        self.assertTrue(record["artifacts"]["result_bundle"].startswith(".autonomy/xcresults/verify-a99"))

    def test_failed_tests_parsing(self):
        passed = json.dumps({"testNodes": [{"nodeType": "Test Plan", "name": "P", "result": "Passed", "children": [
            {"nodeType": "Test Case", "name": "testReset()", "result": "Passed"}]}]})
        self.assertEqual(verify.parse_failed_tests(passed), [])
        failed = json.dumps({"testNodes": [{"nodeType": "Test Plan", "name": "P", "result": "Failed", "children": [
            {"nodeType": "Test Suite", "name": "ScenarioRunnerTests", "result": "Failed", "children": [
                {"nodeType": "Test Case", "name": "testReset()", "result": "Passed"},
                {"nodeType": "Test Case", "name": "testSaveRestore()", "result": "Failed", "children": [
                    {"nodeType": "Failure Message", "name": "XCTAssertEqual failed", "result": "Failed"}]}]}]}]})
        self.assertEqual(verify.parse_failed_tests(failed), ["testSaveRestore()"])
        for broken in ("", "not json", "[]", json.dumps({"testNodes": "x"})):
            self.assertEqual(verify.parse_failed_tests(broken), [])

    # single-process save-restore (T-U09-052)
    def test_a_single_process_save_restore_row_says_so(self):
        self.main(["--only", "a99.contract-sample", "debug", "--runtime", "27", "--scenario", "save-restore"])
        row = next(r for r in self.summary("a99.contract-sample", "27.2")["results"] if r["scenario"] == "save-restore")
        self.assertEqual(row["process"], "single")
        row = next(r for r in self.summary("a98.debug-experience", "27.2")["results"] if r["scenario"] == "save-restore")
        self.assertNotIn("process", row)

    # --audits with --only (T-U09-052)
    def test_audits_with_only_audit_only(self):
        code, lines, sim = self.main(["--only", "debug", "--audits"])
        self.assertEqual(code, 0, lines)
        self.assertFalse(any(c[0][:2] in (["xcrun", "simctl"], ["xcodebuild", "build"]) for c in sim.calls))
        self.assertFalse(any("xcodebuild_package.py" in " ".join(c[0]) for c in sim.calls))
        self.assertIn("SKIP: reducer-bypass (nothing to audit yet: 0 registered experiences)", lines)
        self.assertFalse((self.root / "docs" / "verification").exists())
        code, lines, sim = self.main(["--only", "debug", "--audits", "--dry-run"])
        self.assertEqual((code, sim.calls), (0, []))
        self.assertTrue(any("scoped to a98.debug-experience" in line for line in lines))
        self.assertFalse(any("simctl launch" in line for line in lines))

    # self-test
    def test_self_test_with_a_runtime_detects_the_lossy_record(self):
        code, lines, sim = self.main(["--self-test", "--runtime", "27"])
        self.assertEqual(code, 0, lines)
        self.assertIn("VisualCoreExperienceHostTests/ScenarioRunnerTests/testALossySnapshotFailsSaveRestoreByName",
                      sim.package_scenarios[0])
        self.assertTrue(any(line.startswith("PASS: self-test 27.2: the LossySnapshot record was judged a failure")
                            for line in lines))
        self.assertFalse((self.root / "docs" / "verification").exists())
        code, lines, _ = self.main(["--self-test", "--runtime", "27"], FakeSim(self.root, lossy_result="pass"))
        self.assertEqual(code, 1)
        self.assertTrue(any("was not detected" in line for line in lines))

    def test_self_test_exits_non_zero_when_a_planted_defect_is_missed(self):
        lines: list[str] = []
        self.assertEqual(verify.self_test_offline(lines.append), 0, lines)
        with mock.patch.object(verify, "audit_raster", lambda root, files: []):
            lines = []
            self.assertEqual(verify.self_test_offline(lines.append), 1)
            self.assertTrue(any("x.png" in line for line in lines))
        with mock.patch.object(verify, "audit_bypass", lambda m, r: ["something else"]):
            lines = []
            self.assertEqual(verify.self_test_offline(lines.append), 1)
            self.assertTrue(any("unexpected finding" in line for line in lines))

    def test_release_check_lists_the_new_steps(self):
        steps = {s.name: s.argv for s in relcheck.steps("X")}
        self.assertEqual(steps["evidence-self-test"][1:], ["scripts/check_evidence.py", "--self-test"])
        self.assertEqual(steps["verify-audits"][1:], ["scripts/verify_experiences.py", "--audits"])


class AuditTests(unittest.TestCase):
    """Feature UA-F09 T-U09-025, T-U09-026 (FR-U09-050 to FR-U09-055): the audits of verify_experiences.py on
    temporary copies with planted defects, and on today's repository."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def write(self, rel, text):
        path = self.root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        if isinstance(text, bytes):
            path.write_bytes(text)
        else:
            path.write_text(text)
        return rel

    def markers(self, text, rel="Apps/VisualCore/App/V.swift"):
        return verify.audit_markers(self.root, [self.write(rel, text)])

    def test_todo_in_a_comment_and_fixme_in_a_string(self):
        self.assertEqual(self.markers("// TODO: later\nlet x = 1\n"),
                         ["Apps/VisualCore/App/V.swift:1: TODO in a comment"])
        self.assertEqual(self.markers("let a = 1\nlet s = \"FIXME\"\n"),
                         ["Apps/VisualCore/App/V.swift:2: FIXME in a string"])
        self.assertEqual(self.markers("/* outer /* XXX nested */ still */ let x = 1\n"),
                         ["Apps/VisualCore/App/V.swift:1: XXX in a comment"])
        self.assertEqual(self.markers("let TODOList = 1; let todo = \"todo\"; let xxxy = \"XXXY\"\n"), [])
        self.assertEqual(self.markers("// TODO in GLSL\nvoid main() {}\n", "Packages/VisualCore/Sources/S/a.glsl"),
                         ["Packages/VisualCore/Sources/S/a.glsl:1: TODO in a comment"])

    def test_visible_text_markers(self):
        found = self.markers('Text("Coming soon")\nButton("Lorem ipsum") {}\nx.accessibilityLabel("placeholder")\n'
                             'let t = String(localized: "Placeholder title")\n.navigationTitle("Coming Soon")\n'
                             'Label("A placeholder", systemImage: "star")\n')
        self.assertEqual([f.split(":")[1] for f in found], ["1", "2", "3", "4", "5", "6"])
        self.assertTrue(all("in visible text" in f for f in found))

    def test_placeholder_as_a_technical_term_is_not_a_finding(self):
        self.assertEqual(self.markers(
            "let placeholderSurface = 1\n// the placeholder surface keeps the context current\n"
            "throw RenderHostError.allocation(\"placeholder pbuffer\", error)\n"
            "let s = String(format: \"coming soon %d\", 1)\nText(verbatim: name)\n"
            "let msg = \"\\(Text(\"ok\")) placeholder\"\n"), [])

    def test_the_string_catalog(self):
        catalog = json.dumps({"sourceLanguage": "en", "strings": {
            "vc.soon": {"localizations": {"en": {"stringUnit": {"value": "Coming soon"}}}},
            "vc.placeholder.title": {"localizations": {"en": {"stringUnit": {"value": "Title"}}}},
            "Lorem ipsum dolor": {},
            "vc.count": {"localizations": {"en": {"variations": {"plural": {
                "one": {"stringUnit": {"value": "One"}}, "other": {"stringUnit": {"value": "TODO many"}}}}}}}}})
        found = self.markers(catalog, "Apps/VisualCore/Resources/Localizable.xcstrings")
        self.assertEqual(sorted(found), sorted([
            'Apps/VisualCore/Resources/Localizable.xcstrings: "Coming soon" in the string catalog (visible text)',
            'Apps/VisualCore/Resources/Localizable.xcstrings: "Lorem ipsum" in the string catalog (visible text)',
            'Apps/VisualCore/Resources/Localizable.xcstrings: "TODO" in the string catalog (work marker)']))

    def test_raster_files(self):
        icons = verify.APP_ICON_SET
        self.write("scripts/icon.py", "# generator\n")
        stray = self.write("Apps/VisualCore/Resources/x.png", b"png")
        good = self.write(icons + "icon.png", b"generated")
        bad = self.write(icons + "bad.jpg", b"generated too")
        elsewhere = self.write("Apps/VisualCore/Resources/art.png", b"art")
        no_gen = self.write(icons + "nogen.png", b"no generator")
        missing_gen = self.write(icons + "gone.png", b"gone generator")
        outside_gen = self.write(icons + "out.png", b"outside generator")
        sha = lambda b: hashlib.sha256(b).hexdigest()
        self.write("Catalog/generated-art.json", json.dumps({"schema": 1, "files": [
            {"path": good, "sha256": sha(b"generated"), "generator": "scripts/icon.py"},
            {"path": bad, "sha256": "0" * 64, "generator": "scripts/icon.py"},
            {"path": elsewhere, "sha256": sha(b"art"), "generator": "scripts/icon.py"},
            {"path": no_gen, "sha256": sha(b"no generator")},
            {"path": missing_gen, "sha256": sha(b"gone generator"), "generator": "scripts/gone.py"},
            {"path": outside_gen, "sha256": sha(b"outside generator"), "generator": "../../etc/hosts"}]}))
        found = verify.audit_raster(self.root, [stray, good, bad, elsewhere, no_gen, missing_gen, outside_gen,
                                                "Apps/VisualCore/App/a.swift"])
        self.assertEqual(found, [
            "Apps/VisualCore/Resources/x.png: raster file not listed in Catalog/generated-art.json",
            f"{bad}: SHA-256 differs from Catalog/generated-art.json",
            f"{elsewhere}: a generated raster outside {icons}",
            f"{no_gen}: generator None is not a file of the repository",
            f"{missing_gen}: generator 'scripts/gone.py' is not a file of the repository",
            f"{outside_gen}: generator '../../etc/hosts' is not a file of the repository"])

    def test_completion_expected_without_actions_and_an_undeclared_control(self):
        manifest = {"experience": "a01.x", "controls": ["tap"], "scenarios": [
            {"name": "completion", "entries": [{"steps": 5}], "expect": {"outcome": "done"}},
            {"name": "input-response", "entries": [{"steps": 1, "digest": "a" * 64},
                                                   {"steps": 1, "action": {"control": "swipe"}}], "expect": {}},
            {"name": "launch-first-frame", "entries": [], "expect": {"finalDigest": "a" * 64}},
            {"name": "rejection", "entries": [{"steps": 1, "action": {"control": "tap"}, "digest": "b" * 64}],
             "expect": {"finalDigest": "b" * 64}}]}
        self.assertEqual(verify.audit_bypass([manifest], []), [
            "a01.x completion: an outcome or final digest is expected without actions",
            "a01.x input-response: entry 0 expects a digest without an action before it",
            "a01.x input-response: entry 1 acts on an undeclared control"])

    def test_a_record_whose_engine_handled_fewer_actions_than_sent(self):
        records = [{"experience": "a01.x", "scenario": "input-response", "failures": ["bypass: handled 3 of 4"]},
                   {"experience": "a01.x", "scenario": "reset", "failures": ["after-reset digest differs"]}]
        self.assertEqual(verify.audit_bypass([], records),
                         ["a01.x input-response: the engine handled fewer actions than sent"])

    def test_a_game_manifest_short_by_one_acceptance_scenario(self):
        game = "r02-g01.aurora-loom"
        catalog = {"experiences": [{"id": game, "acceptance_scenarios": {"rows": 80},
                                    "level_manifest": {"rows": 100}, "design": {"fixtures": []}},
                                   {"id": "a01.creative", "design": {"fixtures": ["a", "b"]}}]}
        names = verify.STANDARD + ["full-playthrough", "hero"]
        def manifest(ident, extra, levels=0):
            # A `content` block in a manifest is not read: levels come from the runtime catalog.
            return {"experience": ident, "content": {"levels": 1000},
                    "scenarios": [{"name": n} for n in names + extra]}
        runtime = lambda levels: {"experiences": [{"id": game, "content": {"levels": levels}},
                                                  {"id": "a01.creative", "content": None}]}
        short = manifest(game, [f"acceptance-{i}" for i in range(79)])
        full = manifest(game, [f"acceptance-{i}" for i in range(80)])
        self.assertEqual(verify.audit_content([short], [game], catalog, runtime(100)),
                         [f"{game}: 79 acceptance below the planning catalog's 80"])
        self.assertEqual(verify.audit_content([full], [game], catalog, runtime(100)), [])
        self.assertEqual(verify.audit_content([full], [game], catalog, runtime(99)),
                         [f"{game}: 99 levels below the planning catalog's 100"])
        self.assertEqual(verify.audit_content([full], [game], catalog, {"experiences": [{"id": game, "content": None}]}),
                         [f"{game}: 0 levels below the planning catalog's 100"])
        self.assertEqual(verify.runtime_levels(runtime(7), "a01.creative"), 0)
        self.assertEqual(verify.runtime_levels(runtime(7), game), 7)
        self.assertEqual(verify.audit_content([manifest("a01.creative", ["fixture-a"])], ["a01.creative"], catalog,
                                              runtime(0)),
                         ["a01.creative: 1 fixtures below the planning catalog's 2"])
        self.assertEqual(verify.audit_content([], ["a01.creative"], catalog),
                         ["a01.creative: registered without a scenario manifest"])
        real = json.loads((ROOT_DIR / "docs" / "catalog" / "experience-catalog.json").read_text())
        row = next(e for e in real["experiences"] if e["id"].startswith("r03-g01"))
        self.assertEqual(verify.content_requirement(row)["acceptance"], 80)
        self.assertEqual(verify.content_requirement(row)["faults"], 50)
        self.assertEqual(verify.content_requirement(row)["levels"], 100)

    def registered_game(self, levels, acceptance):
        game = "r02-g01.aurora-loom"
        names = verify.STANDARD + ["full-playthrough", "hero"] + [f"acceptance-{i}" for i in range(acceptance)]
        self.write("Catalog/scenarios/game.json", json.dumps({
            "schema": 1, "experience": game, "kind": "game", "controls": ["tap"],
            "scenarios": [{"name": n, "entries": [{"steps": 1, "action": {"control": "tap"}}], "expect": {}}
                          for n in names]}))
        self.write("Catalog/registrations.json", json.dumps({"schema": 1, "registrations": {
            game: {"manifest": "Catalog/scenarios/game.json"}, "a01.creative": {"manifest": "Catalog/none.json"},
            "a02.without-manifest": {}}}))
        self.write("Catalog/experiences.json", json.dumps({"schema": 1, "experiences": [
            {"id": game, "content": {"levels": levels}}, {"id": "a01.creative", "content": None}]}))
        self.write("docs/catalog/experience-catalog.json", json.dumps({"experiences": [
            {"id": game, "acceptance_scenarios": {"rows": 80}, "level_manifest": {"rows": 100},
             "design": {"fixtures": []}}]}))
        return game

    def audit(self, only=None):
        lines: list[str] = []
        sim = lambda argv, timeout, **kw: (0, "", "")
        return verify.run_audits(self.root, sim, lines.append, only=only), lines

    def test_registered_manifests_are_read_from_their_registration(self):
        game = self.registered_game(levels=100, acceptance=79)
        code, lines = self.audit()
        self.assertEqual(code, 1)
        self.assertIn("FAIL: content-counts: 3 findings", lines)
        self.assertIn(f"    {game}: 79 acceptance below the planning catalog's 80", lines)
        self.assertIn("    a02.without-manifest: registered without a scenario manifest", lines)
        self.assertTrue(any(line.startswith("    a01.creative: standard scenarios missing") for line in lines))
        self.assertTrue(any(line.startswith("    a01.creative: manifest Catalog/none.json cannot be read")
                            for line in lines), lines)
        code, lines = self.audit(only=[game])
        self.assertEqual(code, 1)
        self.assertIn("FAIL: content-counts: 1 findings", lines)
        self.assertIn("PASS: reducer-bypass (1 manifests, 0 records)", lines)

    def test_levels_come_from_the_runtime_catalog(self):
        game = self.registered_game(levels=99, acceptance=80)
        code, lines = self.audit(only=[game])
        self.assertIn(f"    {game}: 99 levels below the planning catalog's 100", lines)
        game = self.registered_game(levels=100, acceptance=80)
        code, lines = self.audit(only=[game])
        self.assertEqual(code, 0, lines)
        self.assertIn("PASS: content-counts (1 registered experiences)", lines)

    def test_nothing_registered_skips_the_bypass_and_content_audits(self):
        self.write("Catalog/registrations.json", json.dumps({"schema": 1, "registrations": {}}))
        code, lines = self.audit()
        self.assertEqual(code, 0, lines)
        self.assertIn("SKIP: reducer-bypass (nothing to audit yet: 0 registered experiences)", lines)
        self.assertIn("SKIP: content-counts (nothing to audit yet: 0 registered experiences)", lines)
        self.assertFalse(any(line.startswith(("PASS: reducer-bypass", "PASS: content-counts")) for line in lines))

    def test_the_audits_ignore_untracked_build_products_and_unshipped_paths(self):
        tracked = self.write("Apps/VisualCore/App/A.swift", "let a = 1\n")
        self.write("Apps/VisualCore/App/Build/Gen.swift", "// TODO: generated\n")
        self.write("Apps/VisualCore/App/Build/x.png", b"png")
        lines: list[str] = []
        sim = lambda argv, timeout, **kw: (0, tracked + "\0", "") if argv[:2] == ["git", "ls-files"] else (0, "", "")
        self.assertEqual(verify.run_audits(self.root, sim, lines.append), 0, lines)
        self.assertIn("PASS: markers (1 shipped files)", lines)
        self.assertIn("entitlement: not yet provided (UA-F08)", lines)
        self.assertFalse(any(line.startswith("PASS: entitlement") for line in lines))
        for path in ("Packages/VisualCore/Sources/VisualCoreTestSupport/S.swift", "Apps/VisualCore/Tests/Unit/T.swift",
                     "Showcase/Resources/checker.png", "Catalog/registrations.json", "docs/x.md"):
            self.assertFalse(verify.shipped(path), path)
        for path in ("Apps/VisualCore/App/A.swift", "Apps/VisualCore/Resources/Localizable.xcstrings",
                     "Catalog/experiences.json", "Packages/VisualCoreRendering/Sources/VisualCoreUI/V.swift"):
            self.assertTrue(verify.shipped(path), path)

    def test_a_failing_tool_audit_fails(self):
        lines: list[str] = []
        def sim(argv, timeout, **kw):
            if argv[:2] == ["git", "ls-files"]:
                return 0, "", ""
            if argv[1] == "scripts/check_compliance.py":
                return 1, "  FAIL Apps/VisualCore/App/A.swift:3: URLSession\n", ""
            return 0, "", ""
        self.assertEqual(verify.run_audits(self.root, sim, lines.append), 1)
        self.assertIn("FAIL: network: 1 findings", lines)
        self.assertIn("PASS: direct-gl (scripts/check_app_isolation.py --app Apps/VisualCore --require-sources)", lines)

    def test_todays_repository_passes(self):
        lines: list[str] = []
        self.assertEqual(verify.run_audits(ROOT_DIR, verify.system_run, lines.append), 0, lines)
        registered = verify.registered_ids(ROOT_DIR)
        self.assertEqual(sum(line.startswith("PASS: ") for line in lines), 6 if registered else 4)
        if not registered:
            self.assertIn("SKIP: reducer-bypass (nothing to audit yet: 0 registered experiences)", lines)
            self.assertIn("SKIP: content-counts (nothing to audit yet: 0 registered experiences)", lines)
        art = json.loads((ROOT_DIR / "Catalog" / "generated-art.json").read_text())
        self.assertEqual(art, {"schema": 1, "files": []})


class ScenarioReleaseSymbolTests(unittest.TestCase):
    """Feature UA-F09 T-U09-019 (FR-U09-012; SC-U09-004): the scenario names in the release checks."""

    def test_release_symbol_lists(self):
        for name in ("ScenarioRunner", "ScenarioLaunch", "ScenarioManifest"):
            self.assertIn(name, relsym.FORBIDDEN_SYMBOLS)
        self.assertIn("VISUALCORE_AUTORUN_EXPERIENCE", relsym.FORBIDDEN_STRINGS)
        nm = ("0000 T _$s24VisualCoreExperienceHost14ScenarioRunnerC3runyyF\n"
              "0000 T _$s10VisualCore14ScenarioLaunchV5startyyFZ\n"
              "0000 T _$s20VisualCoreExperience16ScenarioManifestV6schemaSivg\n"
              "0000 T _$s10VisualCore8AppModelC\n")
        self.assertEqual(len(relsym.automation_symbols(nm)), 3)
        self.assertEqual(relsym.STRING.findall(b"x VISUALCORE_AUTORUN_EXPERIENCE y VISUALCORE_AUTORUN z"),
                         [b"VISUALCORE_AUTORUN_EXPERIENCE", b"VISUALCORE_AUTORUN"])

    def test_release_check_fails_on_a_scenario_symbol(self):
        import plistlib
        with tempfile.TemporaryDirectory() as d:
            app = Path(d) / "VisualCore.app"
            app.mkdir()
            (app / "Info.plist").write_bytes(plistlib.dumps({"CFBundleExecutable": "VisualCore"}))
            (app / "VisualCore").write_bytes(b"\x00plain\x00")
            for nm, expected in (("0000 T _main\n", 0), ("0000 T _$s10VisualCore14ScenarioLaunchV\n", 1)):
                fake = lambda cmd, **kw: subprocess.CompletedProcess(cmd, 0, stdout=nm, stderr="")
                with mock.patch.object(relsym.subprocess, "run", fake), contextlib.redirect_stdout(io.StringIO()):
                    self.assertEqual(relsym.main(["--app", str(app)]), expected)
            (app / "VisualCore").write_bytes(b"\x00VISUALCORE_AUTORUN_EXPERIENCE\x00")
            fake = lambda cmd, **kw: subprocess.CompletedProcess(cmd, 0, stdout="0000 T _main\n", stderr="")
            with mock.patch.object(relsym.subprocess, "run", fake), contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(relsym.main(["--app", str(app)]), 1)

    def test_experience_symbol_names(self):
        tool = load("check_experience_symbols")
        self.assertEqual(tool.NAMES["host"], ("ExperienceScenario", "ScenarioRunner"))
        for name in ("ScenarioManifest", "ScenarioManifestValidator", "ScenarioEvaluator", "ScenarioObservation",
                     "ScenarioRequest", "EvidenceRecord", "FrameChecks"):
            self.assertIn(name, tool.NAMES["pure"])
            self.assertEqual(tool.count_symbols(f"VisualCoreExperience.{name}.x : Int\n", "pure"), 1)
            self.assertEqual(tool.count_symbols(f"VisualCoreExperience.{name}.x : Int\n", "host"), 0)
        self.assertEqual(tool.count_symbols("VisualCoreExperienceHost.ScenarioRunner.run() -> ()\n", "host"), 1)
        self.assertEqual(tool.count_symbols("VisualCoreExperienceHost.ScenarioRunner.run() -> ()\n"), 1)
        self.assertEqual(tool.missing_names(["VisualCoreExperienceHost.ScenarioRunner.run"], "host"),
                         ["ExperienceScenario"])

    def run_tool(self, argv, demangled):
        tool = load("check_experience_symbols")

        def run(cmd, cwd=None, capture_output=False, text=False, input=None, **_):
            if cmd[:2] == ["xcrun", "nm"]:
                return subprocess.CompletedProcess(cmd, 0, "mangled", "")
            if cmd[:2] == ["xcrun", "swift-demangle"]:
                return subprocess.CompletedProcess(cmd, 0, demangled, "")
            where = cmd[cmd.index("--scratch-path") + 1] if "--scratch-path" in cmd else cmd[cmd.index("-derivedDataPath") + 1]
            obj = Path(cwd) / where / "x" / f"{tool.TARGETS[argv[1]]}.build" / "a.o"
            obj.parent.mkdir(parents=True, exist_ok=True)
            obj.write_bytes(b"")
            return subprocess.CompletedProcess(cmd, 0, "", "")

        out = io.StringIO()
        with tempfile.TemporaryDirectory() as d, contextlib.redirect_stdout(out), contextlib.redirect_stderr(io.StringIO()):
            code = tool.main(argv, root=Path(d).resolve(), run=run)
        return code, out.getvalue()

    def test_absent_without_the_flag_and_each_present_with_it(self):
        manifest_only = "VisualCoreExperience.ScenarioManifest.schema.getter : Swift.Int\n"
        code, out = self.run_tool(["--module", "pure"], manifest_only)
        self.assertEqual(code, 1)
        self.assertIn("ScenarioManifest", out)
        code, out = self.run_tool(["--module", "pure", "--with-flag"], manifest_only)
        self.assertEqual(code, 0)
        code, out = self.run_tool(["--module", "pure", "--with-flag", "--require-each"], manifest_only)
        self.assertEqual(code, 1)
        self.assertIn("FrameChecks: not found with VISUALCORE_AUTOMATION", out)
        every = "".join(f"VisualCoreExperience.{n}.x : Int\n" for n in load("check_experience_symbols").NAMES["pure"])
        code, out = self.run_tool(["--module", "pure", "--with-flag", "--require-each"], every)
        self.assertEqual(code, 0, out)
        code, out = self.run_tool(["--module", "host"], "VisualCoreExperienceHost.ScenarioRunner.run() -> ()\n")
        self.assertEqual(code, 1)
        code, out = self.run_tool(["--module", "host"], "VisualCoreExperience.FrameChecks.x : Int\n")
        self.assertEqual(code, 0, "a pure name does not count for the host module")



def ledger_tree_hash() -> str:
    """One hash over every file of the real migration ledger tree (FR-U00-038): the self-tests must not change it."""
    digest = hashlib.sha256()
    base = ROOT_DIR / ".autonomy" / "migration"
    for path in sorted(base.rglob("*")):
        if path.is_file():
            digest.update(path.relative_to(base).as_posix().encode() + b"\0" + path.read_bytes() + b"\0")
    return digest.hexdigest()


def _collect_tool_tests() -> None:
    """Feature 196 (UA-F10): tests written for one tool each live in scripts/tests/test_<tool>.py, so that parallel
    agents never write the same file; their TestCase classes join this suite under the module's name."""
    for path in sorted((HERE / "tests").glob("test_*.py")):
        spec = importlib.util.spec_from_file_location(f"tool_tests_{path.stem}", path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        for name, value in vars(module).items():
            if isinstance(value, type) and issubclass(value, unittest.TestCase) and value.__module__ == module.__name__:
                globals()[f"{path.stem}__{name}"] = value


_collect_tool_tests()


if __name__ == "__main__":
    tree_before = ledger_tree_hash()
    program = unittest.main(verbosity=2, exit=False)
    tree_after = ledger_tree_hash()
    if tree_before != tree_after:
        print("FAIL: the self-tests changed .autonomy/migration/ (FR-U00-038)")
        sys.exit(1)
    print(f"ledger tree unchanged: {tree_before[:16]}")
    sys.exit(0 if program.result.wasSuccessful() else 1)
