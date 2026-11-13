"""Tests for scripts/check_doc_names.py (R02-F03 T-R02F03-018): temporary documents against a temporary baseline."""
import contextlib
import importlib.util
import io
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("check_doc_names", REPO / "scripts" / "check_doc_names.py")
cdn = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = cdn
SPEC.loader.exec_module(cdn)

BASELINE = """# VisualCore public API baseline
VisualCoreSimulation | struct | public struct SeededRandom: RandomNumberGenerator, Sendable, Equatable
VisualCoreSimulation | func | public mutating func next() -> UInt64
VisualCoreSimulation | struct | public struct FixedStepClock: Sendable, Equatable
VisualCoreSimulation | let | public let maxSteps: Int
VisualCoreMath | struct | public struct Mat4: Sendable, Equatable
"""


class CheckDocNamesTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.baseline = self.root / "baseline.txt"
        self.baseline.write_text(BASELINE, encoding="utf-8")

    def tearDown(self):
        self.tmp.cleanup()

    def run_doc(self, text, baseline=None):
        doc = self.root / "doc.md"
        doc.write_text(text, encoding="utf-8")
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = cdn.main([str(doc), "--baseline", str(baseline or self.baseline)])
        return code, out.getvalue() + err.getvalue()

    def test_unknown_name_fails(self):
        code, out = self.run_doc("Use `SeededRandom` and `MysteryClock` here.\n")
        self.assertEqual(code, 1)
        self.assertIn("MysteryClock", out)
        self.assertTrue(out.strip().splitlines()[-1].startswith("FAIL"))

    def test_known_names_pass(self):
        code, out = self.run_doc("`SeededRandom`, `FixedStepClock` and `Mat4` exist.\n")
        self.assertEqual(code, 0, out)
        self.assertTrue(out.strip().splitlines()[-1].startswith("PASS"))

    def test_member_form_checks_both_parts(self):
        self.assertEqual(self.run_doc("`SeededRandom.next()` and `FixedStepClock.maxSteps`.\n")[0], 0)
        code, out = self.run_doc("`SeededRandom.shuffle(_:)` is new.\n")
        self.assertEqual(code, 1)
        self.assertIn("shuffle", out)
        code, out = self.run_doc("`Unknown.next()` is new.\n")
        self.assertEqual(code, 1)
        self.assertIn("Unknown", out)

    def test_non_names_are_ignored(self):
        text = (
            "Paths `docs/api/visualcore-public-api.txt` and `vc/hash.glsl`, numbers `120` and `1/120`, "
            "operators `==` and `-z`, lowercase `step` and `seedStep`, snippets `y_gl = height - y_uikit` "
            "and `Mat4 m[c][r]`, file `README.md`.\n"
        )
        code, out = self.run_doc(text)
        self.assertEqual(code, 0, out)

    def test_names_extracted(self):
        names = cdn.cited_names("`SeededRandom` `a/b` `Mat4.identity` `x y` `FixedStepClock.advance(by:)`")
        self.assertEqual(names, ["SeededRandom", "Mat4.identity", "FixedStepClock.advance(by:)"])

    def test_whole_word_match(self):
        code, out = self.run_doc("`Seeded` is only a prefix.\n")
        self.assertEqual(code, 1)
        self.assertIn("Seeded", out)

    def test_baseline_option_and_unusable_input(self):
        other = self.root / "other.txt"
        other.write_text("VisualCoreMath | struct | public struct MysteryClock\n", encoding="utf-8")
        self.assertEqual(self.run_doc("`MysteryClock`\n", baseline=other)[0], 0)
        self.assertEqual(self.run_doc("`MysteryClock`\n", baseline=self.root / "missing.txt")[0], 2)
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(cdn.main([str(self.root / "missing.md"), "--baseline", str(self.baseline)]), 2)

    def test_default_baseline_is_repository_file(self):
        self.assertEqual(cdn.DEFAULT_BASELINE, Path("docs/api/visualcore-public-api.txt"))


if __name__ == "__main__":
    unittest.main()
