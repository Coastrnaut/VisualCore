"""UA-F10 T-U10-013/014 (FR-U10-030): rules R6-R8 of scripts/check_dependencies.py on temporary trees."""
from __future__ import annotations

import contextlib
import importlib.util
import sys
import io
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
_spec = importlib.util.spec_from_file_location("check_dependencies", REPO / "scripts" / "check_dependencies.py")
deps = importlib.util.module_from_spec(_spec)
sys.modules[_spec.name] = deps  # dataclasses (Python 3.14) look the module up
_spec.loader.exec_module(deps)

PKG = """// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "ExperiencesTest",
    products: [
        .library(name: "AlphaExperience", targets: ["AlphaExperience"]),
        .library(name: "BetaExperience", targets: ["BetaExperience"]),
    ],
    targets: [
        .target(name: "AlphaCore", path: "Alpha/Core"),
        .testTarget(name: "AlphaCoreTests", dependencies: ["AlphaCore"], path: "Alpha/CoreTests"),
        .target(name: "AlphaExperience", dependencies: ["AlphaCore"], path: "Alpha", exclude: ["Core", "CoreTests"], sources: ["Experience"]),
        .testTarget(name: "AlphaExperienceTests", dependencies: ["AlphaExperience", "AlphaCore"], path: "Alpha/ExperienceTests"),
        .target(name: "BetaCore", path: "Beta/Core"),
        .testTarget(name: "BetaCoreTests", dependencies: ["BetaCore"], path: "Beta/CoreTests"),
        .target(name: "BetaExperience", dependencies: ["BetaCore"], path: "Beta/Experience"),
        .testTarget(name: "BetaExperienceTests", dependencies: ["BetaExperience", "BetaCore"], path: "Beta/ExperienceTests"),
    ]
)
"""


class DependencyRulesR6R8Tests(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)

    def tree(self, extra: dict | None = None, pkg: str = PKG) -> Path:
        root = Path(self._tmp.name)
        files = {
            "Packages/ExperiencesTest/Package.swift": pkg,
            "Packages/ExperiencesTest/Alpha/Core/A.swift": "import Foundation\n",
            "Packages/ExperiencesTest/Alpha/CoreTests/AT.swift": "import XCTest\n@testable import AlphaCore\n",
            "Packages/ExperiencesTest/Alpha/Experience/Adapter/AA.swift": "import AlphaCore\n",
            "Packages/ExperiencesTest/Alpha/ExperienceTests/AET.swift": "import AlphaExperience\nimport AlphaCore\n",
            "Packages/ExperiencesTest/Beta/Core/B.swift": "import Foundation\n",
            "Packages/ExperiencesTest/Beta/Experience/B.swift": "import BetaCore\n",
        }
        files.update(extra or {})
        for rel, text in files.items():
            (root / rel).parent.mkdir(parents=True, exist_ok=True)
            (root / rel).write_text(text)
        return root

    def run_main(self, root: Path) -> tuple[int, str]:
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = deps.main(["--root", str(root)])
        return code, out.getvalue()

    def test_clean_two_experience_package_passes(self):
        code, out = self.run_main(self.tree())
        self.assertEqual(code, 0, out)
        self.assertIn("PASS: R1-R8 hold", out)

    def test_r6_cross_experience_import_fails(self):
        root = self.tree({"Packages/ExperiencesTest/Alpha/Experience/Adapter/AA.swift": "import AlphaCore\nimport BetaCore\n"})
        v = [x for x in deps.check(root) if x["rule"] == "R6"]
        self.assertEqual(len(v), 1, v)
        self.assertEqual(v[0]["path"], "Packages/ExperiencesTest/Alpha/Experience/Adapter/AA.swift:2")
        self.assertIn("Alpha", v[0]["detail"]); self.assertIn("Beta", v[0]["detail"])
        self.assertEqual(self.run_main(root)[0], 1)

    def test_r7_cross_experience_target_dependency_fails(self):
        root = self.tree(pkg=PKG.replace('path: "Beta/Experience"', 'path: "Beta/Experience"').replace(
            '.target(name: "BetaCore", path: "Beta/Core")',
            '.target(name: "BetaCore", dependencies: [.product(name: "AlphaExperience", package: "X")], path: "Beta/Core")'))
        v = [x for x in deps.check(root) if x["rule"] == "R7"]
        self.assertEqual(len(v), 1, v)
        self.assertIn("BetaCore", v[0]["detail"]); self.assertIn("AlphaExperience", v[0]["detail"])
        self.assertEqual(self.run_main(root)[0], 1)

    def test_r8_projectm_import_fails_without_r1_double_report(self):
        root = self.tree({"Packages/ExperiencesTest/Beta/Experience/P.swift": "import ProjectMBridge\n"})
        rules = [x["rule"] for x in deps.check(root)]
        self.assertEqual(rules, ["R8"])
        self.assertEqual(self.run_main(root)[0], 1)

    def test_real_repository_passes(self):
        code, out = self.run_main(REPO)
        self.assertEqual(code, 0, out)


if __name__ == "__main__":
    unittest.main()
