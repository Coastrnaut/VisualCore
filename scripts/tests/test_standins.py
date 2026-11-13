"""Agent-side tests for scripts/make_ci_angle_standins.py (UA-F10 T-U10-003/T-U10-004)."""
from __future__ import annotations

import contextlib
import importlib.util
import io
import re
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOL = ROOT / "scripts" / "make_ci_angle_standins.py"
HEADER = ROOT / "Packages/VisualCoreRendering/Sources/CVisualCoreEGL/include/CVisualCoreEGL.h"
# The header declares 15 egl* functions (lines 71-87 include two continuation lines); research.md R1 and
# tasks.md T-U10-003 say 16, which is a miscount of that line range.
EGL_COUNT = 15

spec = importlib.util.spec_from_file_location("make_ci_angle_standins", TOOL)
tool = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tool)


def quiet(argv):
    with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
        return tool.main(argv)


class StandinTests(unittest.TestCase):
    def test_parse_real_header(self):
        protos = tool.parse_prototypes(HEADER.read_text())
        names = [n for _, n, _ in protos]
        self.assertEqual(len(names), EGL_COUNT)
        independent = [l for l in HEADER.read_text().splitlines() if re.match(r"^[^#/ ].* egl[A-Za-z]+\(", l)]
        self.assertEqual(len(independent), EGL_COUNT)
        self.assertEqual(names[0], "eglGetPlatformDisplay")
        self.assertEqual(names[-1], "eglGetProcAddress")
        self.assertNotIn("vcEGLLoadProc", names)
        self.assertNotIn("vcEGLShimVersion", names)
        choose = dict((n, p) for _, n, p in protos)["eglChooseConfig"]
        self.assertIn("num_config", choose)

    def test_generate_c(self):
        protos = tool.parse_prototypes(HEADER.read_text())
        c = tool.generate_c(HEADER, protos)
        self.assertEqual(c.count("abort();"), EGL_COUNT)
        for _, name, _ in protos:
            self.assertIn(f" {name}(", c)
        self.assertIn("vc_ci_angle_standin", c)
        self.assertIn(tool.MARKER, c)

    def test_refuses_real_framework(self):
        with tempfile.TemporaryDirectory() as tmp:
            fake = Path(tmp) / "libEGL.xcframework/x/libEGL.framework/libEGL"
            fake.parent.mkdir(parents=True)
            fake.write_bytes(b"real ANGLE binary")
            self.assertEqual(quiet(["--out", tmp, "--dry-run"]), 2)
            self.assertEqual(fake.read_bytes(), b"real ANGLE binary")

    def test_dry_run_writes_c_only(self):
        with tempfile.TemporaryDirectory() as tmp:
            self.assertEqual(quiet(["--out", tmp, "--dry-run"]), 0)
            self.assertEqual(sorted(p.name for p in Path(tmp).iterdir()), ["libEGL-standin.c"])

    def test_bad_input(self):
        with tempfile.TemporaryDirectory() as tmp:
            self.assertEqual(quiet(["--out", tmp, "--header", "missing.h"]), 2)
            self.assertEqual(quiet(["--out", tmp, "--min-ios", "x"]), 2)
            self.assertEqual(quiet([]), 2)


@unittest.skipUnless(shutil.which("xcrun"), "needs Xcode")
class RealGenerationTest(unittest.TestCase):
    def test_full_generation(self):
        out = ROOT / "Build/standin-agent-check"
        self.assertEqual(quiet(["--out", str(out)]), 0)
        # Replacing existing stand-ins is allowed.
        self.assertEqual(quiet(["--out", str(out)]), 0)
        for name in tool.FRAMEWORKS:
            self.assertTrue((out / f"{name}.xcframework").is_dir())
        binaries = tool.framework_binaries(out / "libEGL.xcframework", "libEGL")
        self.assertEqual(len(binaries), 1)
        strings = subprocess.run(["strings", str(binaries[0])], capture_output=True, text=True).stdout
        self.assertIn(tool.MARKER, strings)
        nm = subprocess.run(["nm", "-gU", str(binaries[0])], capture_output=True, text=True).stdout
        egl = {line.split()[-1] for line in nm.splitlines() if line.split() and line.split()[-1].startswith("_egl")}
        print(f"\nnm egl symbols per binary (both archs merged): {len(egl)}")
        self.assertEqual(egl, {"_" + n for _, n, _ in tool.parse_prototypes(HEADER.read_text())})
        lipo = subprocess.run(["lipo", "-archs", str(binaries[0])], capture_output=True, text=True).stdout
        self.assertEqual(set(lipo.split()), {"arm64", "x86_64"})


if __name__ == "__main__":
    unittest.main()
