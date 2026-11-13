"""Tests for scripts/check_app_targets.py (feature UA-F10, T-U10-007/008, FR-U10-010/011)."""

from __future__ import annotations

import contextlib
import importlib.util
import io
import json
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
_spec = importlib.util.spec_from_file_location("check_app_targets", REPO / "scripts" / "check_app_targets.py")
tool = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(tool)

PROJECT = """\
name: Demo
settings:
  base:
    PRODUCT_BUNDLE_IDENTIFIER: wrong.top.level
targets:
  Showcase:
    type: application
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: dev.visualcore.Showcase
  ShowcaseTests:
    type: bundle.unit-test
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: dev.visualcore.ShowcaseTests
  ParticleUniverse:
    # comment line
    type: application
    info:
      path: Info.plist
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: dev.visualcore.ParticleUniverse
  VisualCore:
    type: application
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: "dev.visualcore.VisualCore"
schemes: {}
"""


def good_list():
    return {"schema": 1, "targets": [
        {"name": "VisualCore", "bundle": "dev.visualcore.VisualCore", "ships": True},
        {"name": "Showcase", "bundle": "dev.visualcore.Showcase", "ships": False, "reason": "harness"},
        {"name": "ParticleUniverse", "bundle": "dev.visualcore.ParticleUniverse", "ships": False,
         "reason": "kept", "until_gate": "X-A04"}]}


class CheckAppTargetsTests(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)
        (self.root / "Configs").mkdir()
        (self.root / ".autonomy" / "migration").mkdir(parents=True)
        (self.root / "project.yml").write_text(PROJECT, encoding="utf-8")
        self.write_ledger("pending")
        self.write_list(good_list())

    def tearDown(self):
        self._tmp.cleanup()

    def write_list(self, data):
        text = data if isinstance(data, str) else json.dumps(data)
        (self.root / "Configs" / "app-targets.json").write_text(text, encoding="utf-8")

    def write_ledger(self, status):
        ledger = {"schema": 1, "gates": [{"id": "X-A04", "status": status}]}
        (self.root / ".autonomy" / "migration" / "ledger.json").write_text(json.dumps(ledger), encoding="utf-8")

    def run_tool(self, root=None):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = tool.main(["--root", str(root or self.root)])
        return code, out.getvalue(), err.getvalue()

    def test_reader_finds_application_targets_only(self):
        self.assertEqual(tool.read_application_targets(PROJECT), {
            "Showcase": "dev.visualcore.Showcase",
            "ParticleUniverse": "dev.visualcore.ParticleUniverse",
            "VisualCore": "dev.visualcore.VisualCore"})

    def test_pass(self):
        code, out, _ = self.run_tool()
        self.assertEqual(code, 0, out)
        self.assertIn("PASS: 1 shippable app (VisualCore); 2 non-shipping: Showcase, ParticleUniverse", out)

    def test_second_shippable_target(self):
        data = good_list()
        data["targets"][1]["ships"] = True
        self.write_list(data)
        code, out, _ = self.run_tool()
        self.assertEqual(code, 1)
        self.assertIn("ONE-SHIPPING", out)

    def test_undeclared_target(self):
        data = good_list()
        del data["targets"][1]
        self.write_list(data)
        code, out, _ = self.run_tool()
        self.assertEqual(code, 1)
        self.assertIn("UNDECLARED project.yml#Showcase", out)

    def test_reused_bundle(self):
        data = good_list()
        data["targets"][1]["bundle"] = "dev.visualcore.VisualCore"
        self.write_list(data)
        code, out, _ = self.run_tool()
        self.assertEqual(code, 1)
        self.assertIn("UNIQUE-BUNDLE", out)
        self.assertIn("SHIPPING-BUNDLE", out)

    def test_missing_reason(self):
        data = good_list()
        data["targets"][1]["reason"] = "  "
        self.write_list(data)
        code, out, _ = self.run_tool()
        self.assertEqual(code, 1)
        self.assertIn("REASON Configs/app-targets.json#Showcase", out)

    def test_until_gate_pass(self):
        self.write_ledger("pass")
        code, out, _ = self.run_tool()
        self.assertEqual(code, 1)
        self.assertIn("remove the target", out)

    def test_unknown_until_gate(self):
        data = good_list()
        data["targets"][2]["until_gate"] = "X-NOPE"
        self.write_list(data)
        code, out, _ = self.run_tool()
        self.assertEqual(code, 1)
        self.assertIn("unknown gate X-NOPE", out)

    def test_damaged_json(self):
        self.write_list("{not json")
        code, _, err = self.run_tool()
        self.assertEqual(code, 2)
        self.assertIn("damaged", err)
        self.assertNotIn("Traceback", err)

    def test_schema_2(self):
        data = good_list()
        data["schema"] = 2
        self.write_list(data)
        code, _, err = self.run_tool()
        self.assertEqual(code, 2)
        self.assertIn("schema", err)

    def test_real_repository_passes(self):
        code, out, err = self.run_tool(REPO)
        self.assertEqual(code, 0, out + err)
        self.assertTrue(out.startswith("PASS: 1 shippable app (VisualCore)"), out)


if __name__ == "__main__":
    unittest.main()
