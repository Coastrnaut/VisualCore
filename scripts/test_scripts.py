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
import re
import subprocess
import sys
import tempfile
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
appcontract = load("check_app_contract")
enumeration = load("check_test_enumeration")
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
        for required in ["documented-api-generative-art-studio", "documented-api-fluid-art-playground",
                         "host-fluid-art-playground-core", "host-generative-art-studio-core", "app-generative-art-studio-ios27", "app-fluid-art-playground-ios26"]:
            self.assertIn(required, names)

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
        self.refuses("legacy:A04-P04", "run-check", "--gate", "X-A04", "--name", "x", "--", sys.executable, "ok.py")

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
            text = ("[ok](other.md) [web](https://example.com) [gone](missing.md)\n`scripts/real.py` `scripts/verify_experiences.py` "
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
                      "scripts/planning_index.py"}
    PUSHERS = {"scripts/tick_task.py", "scripts/prepush_scan.py"}
    TOOLS = ("validate_docs", "tick_task", "prepush_scan", "migration_ledger", "planning_index")
    NETWORK_MODULES = {"socket", "ssl", "urllib", "http", "ftplib", "smtplib", "poplib", "imaplib", "xmlrpc", "telnetlib",
                       "asyncio", "socketserver", "webbrowser"}

    @classmethod
    def setUpClass(cls):
        listing = subprocess.run(["git", "ls-files", "scripts", "Tools/python", ".github"], cwd=ROOT_DIR, capture_output=True,
                                 text=True, check=True).stdout.splitlines()
        cls.files = {rel: (ROOT_DIR / rel).read_text(encoding="utf-8", errors="replace") for rel in listing
                     if (ROOT_DIR / rel).is_file()}

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
        pushes = re.compile(r"""["']git["'],\s*["']push["']""")
        pushing = {rel for rel, text in self.files.items() if rel.endswith(".py") and rel != "scripts/test_scripts.py" and pushes.search(text)}
        self.assertEqual(pushing, self.PUSHERS)
        for rel, text in self.files.items():
            if rel.startswith(".github/"):
                self.assertNotRegex(text, r"git\s+push", f"{rel} pushes")

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
        self.edit(root, "docs/catalog/unified-app-features.json",
                  lambda briefs: briefs.update(features=[b for b in briefs["features"] if b["id"] != "UA-F05"]))
        features, prompts, problems = planidx.prompt_coverage(root)
        self.assertEqual(prompts, 8 * features - len(problems))
        self.assertEqual(len(problems), 1 + 1 + 8 + 8)
        self.assertTrue(any(p.startswith("R03-G05-07 plan: ") for p in problems), problems[:4])
        self.assertTrue(any(p.startswith("A10-P03 tasks: ") for p in problems))
        for stage in planidx.STAGES:
            self.assertTrue(any(p.startswith(f"A11-P00 {stage}: ") for p in problems), stage)
            self.assertTrue(any(p.startswith(f"UA-F05 {stage}: ") for p in problems), stage)
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


def ledger_tree_hash() -> str:
    """One hash over every file of the real migration ledger tree (FR-U00-038): the self-tests must not change it."""
    digest = hashlib.sha256()
    base = ROOT_DIR / ".autonomy" / "migration"
    for path in sorted(base.rglob("*")):
        if path.is_file():
            digest.update(path.relative_to(base).as_posix().encode() + b"\0" + path.read_bytes() + b"\0")
    return digest.hexdigest()


if __name__ == "__main__":
    tree_before = ledger_tree_hash()
    program = unittest.main(verbosity=2, exit=False)
    tree_after = ledger_tree_hash()
    if tree_before != tree_after:
        print("FAIL: the self-tests changed .autonomy/migration/ (FR-U00-038)")
        sys.exit(1)
    print(f"ledger tree unchanged: {tree_before[:16]}")
    sys.exit(0 if program.result.wasSuccessful() else 1)
