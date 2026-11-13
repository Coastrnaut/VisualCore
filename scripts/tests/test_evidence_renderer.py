"""Tests for the optional environment.renderer of scripts/check_evidence.py (feature 202 R02-F02 T-R02F02-008)."""
from __future__ import annotations

import copy
import importlib.util
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOL = ROOT / "scripts" / "check_evidence.py"

spec = importlib.util.spec_from_file_location("check_evidence", TOOL)
check_evidence = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = check_evidence  # dataclasses (Python 3.14) look the module up
spec.loader.exec_module(check_evidence)

RENDERER = {
    "gl_version": "OpenGL ES 3.0 (ANGLE)", "glsl_version": "OpenGL ES GLSL ES 3.00", "renderer": "ANGLE (Metal)",
    "vendor": "Google Inc.", "egl_version": "1.5", "max_texture_size": 16384, "max_samples": 4,
    "max_draw_buffers": 8, "max_color_attachments": 8, "missing_entry_points": 0, "generation": 1,
    "floor_findings": [],
}


def record_with(renderer=..., kind: str = "simulator") -> dict:
    record = copy.deepcopy(check_evidence.sample_record(kind))
    if renderer is not ...:
        record["environment"]["renderer"] = renderer
    return record


class EvidenceRendererTests(unittest.TestCase):
    def test_valid_record_with_renderer_passes(self):
        self.assertEqual(check_evidence.validate(record_with(RENDERER)), [])
        self.assertEqual(check_evidence.validate(record_with(RENDERER, kind="device")), [])

    def test_valid_record_without_renderer_passes(self):
        self.assertEqual(check_evidence.validate(record_with()), [])

    def test_non_object_renderer_fails(self):
        for bad in ("ANGLE", ["ANGLE"], 3, None):
            problems = check_evidence.validate(record_with(bad))
            self.assertTrue(any("environment.renderer: expected an object" in p for p in problems), problems)

    def test_udid_inside_renderer_fails(self):
        udid = "-".join(["0A1B2C3D", "0000", "4000", "8000", "0000" + "0000ABCD"])
        problems = check_evidence.validate(record_with(dict(RENDERER, renderer=udid)))
        self.assertTrue(any("environment.renderer.renderer: value looks like a UDID" in p for p in problems),
                        problems)
        self.assertFalse(any(udid in p for p in problems))


if __name__ == "__main__":
    unittest.main()
