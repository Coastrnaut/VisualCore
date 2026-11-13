"""The verification driver keeps the app's renderer record when it completes a record (feature 202, R02-F02,
FR-R02F02-006, T-R02F02-010)."""

from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
_spec = importlib.util.spec_from_file_location("verify_experiences_for_tests", REPO / "scripts" / "verify_experiences.py")
driver = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(driver)


class DriverKeepsRendererTests(unittest.TestCase):
    def complete(self, record):
        return driver.complete_record(record, run_id="verify-x", attempt=1, environment={"kind": "simulator"},
                                      source={}, artifacts={})

    def test_the_renderer_of_the_app_is_kept(self):
        out = self.complete({"environment": {"kind": "simulator", "renderer": {"max_samples": 4}}})
        self.assertEqual(out["environment"], {"kind": "simulator", "renderer": {"max_samples": 4}})

    def test_a_record_without_renderer_gets_none(self):
        out = self.complete({"environment": {"kind": "simulator"}})
        self.assertNotIn("renderer", out["environment"])


if __name__ == "__main__":
    unittest.main()
