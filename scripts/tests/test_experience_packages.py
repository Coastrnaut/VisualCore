"""Tests of scripts/check_experience_packages.py (feature UA-F10, T-U10-010): fixture roots and the real repository."""
from __future__ import annotations

import contextlib
import importlib.util
import io
import json
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
_spec = importlib.util.spec_from_file_location("check_experience_packages",
                                               REPO / "scripts" / "check_experience_packages.py")
tool = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(tool)

CATALOG = {"schema": 1, "experiences": [
    {"code": "A01", "name": "Generative Art Studio", "id": "a01.generative-art-studio"},
    {"code": "R02-G01", "name": "Aurora Loom", "id": "r02-g01.aurora-loom"},
    {"code": "R05-G01", "name": "Later Thing", "id": "r05-g01.later-thing"},
]}


def package_swift(names: list[str], extra_targets: tuple[str, ...] = (), skip: tuple[str, ...] = ()) -> str:
    products = "\n".join(f'        .library(name: "{n}Experience", targets: ["{n}Experience"]),' for n in names)
    targets = []
    for n in names:
        for kind, suffix in (("target", "Core"), ("testTarget", "CoreTests"), ("target", "Experience"),
                             ("testTarget", "ExperienceTests")):
            if n + suffix in skip:
                continue
            targets.append(f'        .{kind}(\n            name: "{n}{suffix}",\n            path: "{n}/{suffix}"),')
    for t in extra_targets:
        targets.append(f'        .target(name: "{t}", path: "{t}"),')
    return ("// swift-tools-version: 6.0\nimport PackageDescription\nlet package = Package(\n    name: \"X\",\n"
            f"    products: [\n{products}\n    ],\n    targets: [\n" + "\n".join(targets) + "\n    ]\n)\n")


def project_yml(links: list[tuple[str, str]]) -> str:
    deps = "".join(f"      - package: {p}\n        product: {q}\n" for p, q in links)
    return ("name: VisualCore\npackages:\n  VisualCore:\n    path: Packages/VisualCore\n"
            "  ExperiencesCreative:\n    path: Packages/ExperiencesCreative\n"
            "targets:\n  Other:\n    type: application\n    dependencies:\n"
            "      - package: ExperiencesCreative\n        product: GenerativeArtStudioCore\n"
            "  VisualCore:\n    type: application\n    dependencies:\n"
            "      - package: VisualCore\n        product: VisualCoreExperience\n"
            "      # comment\n" + deps + "    postBuildScripts: []\nschemes: {}\n")


class Fixture:
    def __init__(self, root: Path) -> None:
        self.root = root
        self.write("docs/catalog/experience-catalog.json", json.dumps(CATALOG))
        self.registrations(["a01.generative-art-studio", "r02-g01.aurora-loom"])
        self.write("Packages/ExperiencesCreative/Package.swift", package_swift(["GenerativeArtStudio"]))
        self.write("Packages/ExperiencesRound02/Package.swift", package_swift(["AuroraLoom"]))
        self.write("project.yml", project_yml([("ExperiencesCreative", "GenerativeArtStudioExperience"),
                                               ("ExperiencesRound02", "AuroraLoomExperience")]))

    def write(self, rel: str, text: str) -> None:
        path = self.root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")

    def registrations(self, ids: list[str]) -> None:
        self.write("Catalog/registrations.json", json.dumps({"schema": 1, "registrations": {i: {} for i in ids}}))


class CheckExperiencePackagesTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.fx = Fixture(Path(self._tmp.name))

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def run_tool(self, root: Path | None = None) -> tuple[int, str]:
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = tool.main(["--root", str(root or self.fx.root)])
        return code, out.getvalue() + err.getvalue()

    def test_pass(self) -> None:
        code, out = self.run_tool()
        self.assertEqual(code, 0, out)
        self.assertIn("PASS: 2 experiences in 2 packages", out)

    def test_missing_test_target(self) -> None:
        self.fx.write("Packages/ExperiencesRound02/Package.swift",
                      package_swift(["AuroraLoom"], skip=("AuroraLoomCoreTests",)))
        code, out = self.run_tool()
        self.assertEqual(code, 1)
        self.assertIn("MISSING_TARGET Packages/ExperiencesRound02/Package.swift", out)
        self.assertIn("AuroraLoomCoreTests", out)

    def test_extra_target(self) -> None:
        self.fx.write("Packages/ExperiencesCreative/Package.swift",
                      package_swift(["GenerativeArtStudio"], extra_targets=("StrayCore",)))
        code, out = self.run_tool()
        self.assertEqual(code, 1)
        self.assertIn("EXTRA_TARGET Packages/ExperiencesCreative/Package.swift: StrayCore", out)

    def test_unknown_registered_id(self) -> None:
        self.fx.registrations(["a01.generative-art-studio", "r02-g01.aurora-loom", "zz.nowhere"])
        code, out = self.run_tool()
        self.assertEqual(code, 1)
        self.assertIn("UNKNOWN_ID Catalog/registrations.json: zz.nowhere", out)

    def test_out_of_scope_code(self) -> None:
        self.fx.registrations(["a01.generative-art-studio", "r02-g01.aurora-loom", "r05-g01.later-thing"])
        code, out = self.run_tool()
        self.assertEqual(code, 1)
        self.assertIn("OUT_OF_SCOPE", out)

    def test_registered_but_not_linked(self) -> None:
        self.fx.write("project.yml", project_yml([("ExperiencesCreative", "GenerativeArtStudioExperience")]))
        code, out = self.run_tool()
        self.assertEqual(code, 1)
        self.assertIn("NOT_LINKED project.yml", out)
        self.assertIn("ExperiencesRound02/AuroraLoomExperience", out)

    def test_linked_product_not_registered(self) -> None:
        self.fx.write("project.yml", project_yml([("ExperiencesCreative", "GenerativeArtStudioExperience"),
                                                  ("ExperiencesRound02", "AuroraLoomExperience"),
                                                  ("ExperiencesCreative", "GhostExperience")]))
        code, out = self.run_tool()
        self.assertEqual(code, 1)
        self.assertIn("EXTRA_LINK project.yml", out)
        self.assertIn("GhostExperience", out)

    def test_empty_package(self) -> None:
        self.fx.registrations(["a01.generative-art-studio"])
        self.fx.write("project.yml", project_yml([("ExperiencesCreative", "GenerativeArtStudioExperience")]))
        code, out = self.run_tool()
        self.assertEqual(code, 1)
        self.assertIn("EMPTY_PACKAGE Packages/ExperiencesRound02/Package.swift", out)

    def test_absent_package_without_experiences_passes(self) -> None:
        self.fx.registrations(["a01.generative-art-studio"])
        (self.fx.root / "Packages/ExperiencesRound02/Package.swift").unlink()
        self.fx.write("project.yml", project_yml([("ExperiencesCreative", "GenerativeArtStudioExperience")]))
        code, out = self.run_tool()
        self.assertEqual(code, 0, out)
        self.assertIn("PASS: 1 experiences in 1 packages", out)

    def test_damaged_registrations(self) -> None:
        self.fx.write("Catalog/registrations.json", "{not json")
        code, out = self.run_tool()
        self.assertEqual(code, 2)
        self.assertIn("ERROR: registrations is damaged", out)
        self.assertNotIn("Traceback", out)

    def test_registrations_wrong_schema(self) -> None:
        self.fx.write("Catalog/registrations.json", json.dumps({"schema": 2, "registrations": {}}))
        code, out = self.run_tool()
        self.assertEqual(code, 2)
        self.assertIn("schema is not 1", out)

    def test_catalog_without_experiences(self) -> None:
        self.fx.write("docs/catalog/experience-catalog.json", json.dumps({"schema": 1}))
        code, out = self.run_tool()
        self.assertEqual(code, 2)
        self.assertIn("no `experiences`", out)

    def test_type_names(self) -> None:
        self.assertEqual(tool.type_name("Generative Art Studio"), "GenerativeArtStudio")
        self.assertEqual(tool.type_name("Wave-Knot keeper!"), "WaveKnotKeeper")

    def test_real_repository(self) -> None:
        code, out = self.run_tool(REPO)
        self.assertEqual(code, 0, out)
        self.assertIn("PASS: 4 experiences in 1 packages", out)


if __name__ == "__main__":
    unittest.main()
