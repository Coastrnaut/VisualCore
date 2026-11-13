"""Tests for the unified-app steps of scripts/release_check.py (feature UA-F10, T-U10-016/017, FR-U10-040 to 042)."""

from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
_spec = importlib.util.spec_from_file_location("release_check_for_tests", REPO / "scripts" / "release_check.py")
rc = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(rc)


class UnifiedAppStepTests(unittest.TestCase):
    def steps(self, root=REPO):
        return rc.unified_app_steps("STAMP", root)

    def test_every_step_is_limited_below_ten_minutes(self):
        for step in self.steps():
            self.assertLess(step.timeout, 600, step.name)

    def test_the_named_steps_exist(self):
        names = {s.name for s in self.steps()}
        for name in ("app-build-for-testing-ios27", "app-unit-ios27", "app-release-build", "app-release-symbols",
                     "app-privacy-manifest", "measure-build-check"):
            self.assertIn(name, names)
        self.assertTrue(any(n.startswith("app-ui-ios27-") for n in names))

    def test_no_interface_chunk_runs_an_accessibility_audit_class(self):
        for step in self.steps():
            if step.name.startswith("app-ui-"):
                self.assertFalse(any("AccessibilityAudit" in a for a in step.argv), step.name)
                self.assertIn("test-without-building", step.argv)

    def test_release_symbols_forbid_the_ci_standin_marker(self):
        step = next(s for s in self.steps() if s.name == "app-release-symbols")
        self.assertIn("vc_ci_angle_standin", step.argv)

    def test_verification_steps_follow_the_registrations(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            (root / "Catalog").mkdir()
            (root / "Catalog" / "registrations.json").write_text(json.dumps(
                {"schema": 1, "registrations": {"a01.one": {}, "r02-g01.two": {}}}))
            names = {s.name for s in self.steps(root)}
        for name in ("verify-a01.one-ios27", "verify-a01.one-ios26", "verify-r02-g01.two-ios27",
                     "verify-r02-g01.two-ios26"):
            self.assertIn(name, names)

    def test_the_whole_scheme_app_test_steps_of_visualcore_are_gone(self):
        names = {s.name for s in rc.app_test_steps("27.2", "STAMP")}
        self.assertNotIn("app-visual-core-ios27", names)


if __name__ == "__main__":
    unittest.main()
