"""Tests for scripts/check_audio_hot_path.py (feature 049, A06-P03, T-A06-303; FR-A06-320, SC-A06-305)."""
import contextlib
import importlib.util
import io
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]


def load(name):
    spec = importlib.util.spec_from_file_location(name, REPO / "scripts" / f"{name}.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


hot = load("check_audio_hot_path")

CLEAN = """final class Sink {
    func consume(_ pcm: AVAudioPCMBuffer) {
        // vc:hot-path begin
        guard let channels = pcm.floatChannelData else { return }
        // A comment with "quotes" and .append( is ignored.
        var sum: Float = 0 // trailing "comment" is stripped
        for channel in 0..<count { sum += channels[channel][0] }
        mono.withUnsafeMutableBufferPointer { out in
            out[0] = sum
        }
        mono.withUnsafeBufferPointer { buffer.write(UnsafeBufferPointer(rebasing: $0[0..<1])) }
        // vc:hot-path end
    }
}
"""
BODY_LINE = 7  # the `for channel` line, replaced by a planted construct


def run(argv):
    with contextlib.redirect_stdout(io.StringIO()) as out, contextlib.redirect_stderr(io.StringIO()) as err:
        code = hot.main(argv)
    return code, out.getvalue() + err.getvalue()


class AudioHotPathTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def check(self, text):
        (self.root / "Source.swift").write_text(text)
        return run(["--root", str(self.root), "Source.swift"])

    def plant(self, line):
        lines = CLEAN.split("\n")
        lines[BODY_LINE - 1] = "        " + line
        return self.check("\n".join(lines))

    def test_repository_passes(self):
        code, out = run(["--root", str(REPO)])
        self.assertEqual(code, 0, out)
        self.assertIn("PASS: audio hot path", out)
        self.assertIn("in 3 files, 0 problems", out)

    def test_clean_file_passes(self):
        code, out = self.check(CLEAN)
        self.assertEqual(code, 0, out)
        self.assertIn("PASS: audio hot path, 1 regions in 1 files, 0 problems", out)

    def test_planted_constructs_fail_on_their_line(self):
        planted = {
            "append": ("values.append(sum)", ".append"),
            "array literal": ("let values = [sum, sum]", "array or dictionary literal"),
            "interpolation": ('let label = "\\(sum)"', "string interpolation"),
            "closure literal": ("let f = { [weak self] in self?.tick() }", "closure literal"),
            "allocate": ("let p = UnsafeMutablePointer<Float>.allocate(capacity: 4)", ".allocate"),
        }
        for name, (line, reason) in planted.items():
            with self.subTest(name):
                code, out = self.plant(line)
                self.assertEqual(code, 1, out)
                self.assertIn(f"Source.swift:{BODY_LINE}: {reason}", out)
                self.assertIn("FAIL: audio hot path", out)

    def test_parameter_closure_outside_with_unsafe_fails(self):
        code, out = self.plant("let g = { x in x * 2 }")
        self.assertEqual(code, 1, out)
        self.assertIn(f"Source.swift:{BODY_LINE}: closure literal", out)

    def test_cold_line_with_string_passes(self):
        code, out = self.plant('throw Failure.undecodable("name") // vc:cold')
        self.assertEqual(code, 0, out)

    def test_unbalanced_begin_fails(self):
        code, out = self.check(CLEAN.replace("        // vc:hot-path end\n", ""))
        self.assertEqual(code, 1, out)
        self.assertIn("Source.swift:3: hot-path begin without end", out)

    def test_end_without_begin_fails(self):
        code, out = self.check(CLEAN.replace("        // vc:hot-path begin\n", ""))
        self.assertEqual(code, 1, out)
        self.assertIn("hot-path end without begin", out)

    def test_nested_begin_fails(self):
        code, out = self.plant("// vc:hot-path begin")
        self.assertEqual(code, 1, out)
        self.assertIn(f"Source.swift:{BODY_LINE}: nested hot-path begin", out)

    def test_file_without_region_fails(self):
        code, out = self.check("final class Empty {\n    func f() {}\n}\n")
        self.assertEqual(code, 1, out)
        self.assertIn("Source.swift:1: no hot-path region", out)

    def test_missing_file_is_usage_error(self):
        code, out = run(["--root", str(self.root), "Missing.swift"])
        self.assertEqual(code, 2, out)


if __name__ == "__main__":
    unittest.main()
