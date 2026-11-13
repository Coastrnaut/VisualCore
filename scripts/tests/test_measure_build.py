"""Tests for scripts/measure_build.py (UA-F10 T-U10-019): fake runner, fake clock, temporary roots."""
import importlib.util
import sys
import json
import subprocess
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace

REPO = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("measure_build", REPO / "scripts" / "measure_build.py")
mb = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = mb  # dataclasses (Python 3.14) look the module up
SPEC.loader.exec_module(mb)

COMMIT = "a" * 40


class FakeRunner:
    def __init__(self, root, fail=None, timeout=None):
        self.root, self.fail, self.timeout, self.calls = root, fail, timeout, []

    def __call__(self, argv, **kwargs):
        self.calls.append(list(argv))
        if argv[:2] == ["git", "rev-parse"]:
            return SimpleNamespace(returncode=0, stdout=COMMIT + "\n")
        if argv == ["xcodebuild", "-version"]:
            return SimpleNamespace(returncode=0, stdout="Xcode 27.1\nBuild version 27B52\n")
        if "Release" in argv:
            if self.timeout == "release":
                raise subprocess.TimeoutExpired(argv, kwargs.get("timeout"))
            app = Path(self.root) / mb.RELEASE_DD / mb.APP_REL
            (app / "sub").mkdir(parents=True, exist_ok=True)
            (app / "VisualCore").write_bytes(b"x" * 100)
            (app / "sub" / "a.bin").write_bytes(b"y" * 23)
        if self.fail and self.fail in argv:
            return SimpleNamespace(returncode=65, stdout="")
        return SimpleNamespace(returncode=0, stdout="")

    def builds(self):
        return [c for c in self.calls if c[0] == "xcodebuild" and c != ["xcodebuild", "-version"]]


class FakeClock:
    def __init__(self):
        self.t = 0.0

    def __call__(self):
        self.t += 12.345
        return self.t


class MeasureBuildTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.file = self.root / mb.MEASUREMENTS
        self.file.parent.mkdir(parents=True)
        self.write({"schema": 1, "records": []})
        core = self.root / mb.TOUCH_DIR
        core.mkdir(parents=True)
        (core / "B.swift").write_text("let b = 2\n")
        self.touched = core / "A.swift"
        self.touched.write_text("let a = 1\n")

    def tearDown(self):
        self.tmp.cleanup()

    def write(self, obj):
        self.file.write_text(obj if isinstance(obj, str) else json.dumps(obj))

    def call(self, *args, run=None):
        run = run or FakeRunner(self.root)
        return mb.main(["--root", str(self.root), *args], run=run, clock=FakeClock()), run

    def test_appends_one_record(self):
        code, run = self.call("--milestone", "UA-F10")
        self.assertEqual(code, 0)
        records = json.loads(self.file.read_text())["records"]
        self.assertEqual(len(records), 1)
        r = records[0]
        self.assertEqual(set(r), set(mb.FIELDS))
        self.assertEqual(r["commit"], COMMIT)
        self.assertEqual(r["xcode_build"], "27B52")
        self.assertEqual(r["milestone"], "UA-F10")
        self.assertEqual(r["clean_build_s"], 12.3)
        self.assertEqual(r["incremental_build_s"], 12.3)
        self.assertEqual(r["release_app_bytes"], 123)
        self.assertEqual(len(run.builds()), 3)
        self.assertIn("clean", run.builds()[0])
        self.assertNotIn("clean", run.builds()[1])
        self.assertTrue(self.file.read_text().endswith("\n"))
        self.assertEqual(mb.load(self.file)["schema"], 1)

    def test_touch_keeps_content(self):
        before = self.touched.read_bytes()
        self.call("--milestone", "UA-F10")
        self.assertEqual(self.touched.read_bytes(), before)

    def test_same_commit_skipped(self):
        self.call("--milestone", "UA-F10")
        before = self.file.read_text()
        code, run = self.call("--milestone", "UA-F10")
        self.assertEqual(code, 0)
        self.assertEqual(run.builds(), [])
        self.assertEqual(self.file.read_text(), before)

    def test_damaged_file_refused(self):
        self.write("{not json")
        code, run = self.call("--milestone", "UA-F10")
        self.assertEqual(code, 2)
        self.assertEqual(run.calls, [])
        self.assertEqual(self.file.read_text(), "{not json")

    def test_newer_schema_refused(self):
        self.write({"schema": 2, "records": []})
        before = self.file.read_text()
        code, _ = self.call("--milestone", "UA-F10")
        self.assertEqual(code, 2)
        self.assertEqual(self.file.read_text(), before)

    def test_bad_record_refused(self):
        self.write({"schema": 1, "records": [{"commit": COMMIT}]})
        self.assertEqual(self.call("--check")[0], 2)
        self.write({"schema": 1, "records": {}})
        self.assertEqual(self.call("--check")[0], 2)

    def test_failing_build_no_write(self):
        before = self.file.read_text()
        code, _ = self.call("--milestone", "UA-F10", run=FakeRunner(self.root, fail="clean"))
        self.assertEqual(code, 1)
        self.assertEqual(self.file.read_text(), before)

    def test_timeout_no_write(self):
        before = self.file.read_text()
        code, _ = self.call("--milestone", "UA-F10", run=FakeRunner(self.root, timeout="release"))
        self.assertEqual(code, 1)
        self.assertEqual(self.file.read_text(), before)

    def test_check_valid(self):
        self.call("--milestone", "UA-F10")
        code, run = self.call("--check")
        self.assertEqual(code, 0)
        self.assertEqual(run.calls, [])

    def test_dry_run_runs_nothing(self):
        code, run = self.call("--milestone", "UA-F10", "--dry-run")
        self.assertEqual(code, 0)
        self.assertEqual(run.calls, [])


if __name__ == "__main__":
    unittest.main()
