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


class ReleaseCheckTests(unittest.TestCase):
    """Feature 010 T-F908: release-check runner logic (step list, selection, logs, summary, failure handling)."""

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


if __name__ == "__main__":
    unittest.main(verbosity=2)
