"""Tests for scripts/report_meta.py (UA-F11 T-U11-002): report metadata, atomic writes, versioned reads."""
import hashlib
import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

REPO = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("report_meta", REPO / "scripts" / "report_meta.py")
rm = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = rm
SPEC.loader.exec_module(rm)


class MetaTests(unittest.TestCase):
    def test_meta_without_app(self):
        m = rm.meta(None, "Release")
        self.assertEqual(m["schema"], 1)
        self.assertRegex(m["revision"], r"^[0-9a-f]{40}$")
        self.assertIsInstance(m["clean"], bool)
        self.assertEqual(m["configuration"], "Release")
        self.assertIsNone(m["executable_sha256"])

    def test_meta_hashes_the_main_executable(self):
        with tempfile.TemporaryDirectory() as tmp:
            app = Path(tmp) / "Demo.app"
            app.mkdir()
            (app / "Demo").write_bytes(b"binary")
            m = rm.meta(app, "Debug")
            self.assertEqual(m["executable_sha256"], hashlib.sha256(b"binary").hexdigest())

    def test_meta_refuses_an_app_without_executable(self):
        with tempfile.TemporaryDirectory() as tmp:
            app = Path(tmp) / "Demo.app"
            app.mkdir()
            with self.assertRaises(rm.ReportError):
                rm.meta(app, "Release")


class WriteReadTests(unittest.TestCase):
    def test_write_then_read(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "sub" / "r.json"
            rm.write_report(path, {"schema": 1, "verdict": "PASS"})
            self.assertEqual(rm.read_versioned(path)["verdict"], "PASS")
            self.assertEqual([p.name for p in path.parent.iterdir()], ["r.json"])

    def test_interrupted_write_leaves_no_file(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "r.json"
            with mock.patch.object(rm.os, "replace", side_effect=KeyboardInterrupt):
                with self.assertRaises(KeyboardInterrupt):
                    rm.write_report(path, {"schema": 1})
            self.assertEqual(list(Path(tmp).iterdir()), [])

    def test_read_refuses_newer_missing_or_bad_schema_and_bad_json(self):
        with tempfile.TemporaryDirectory() as tmp:
            for name, text in [("newer", json.dumps({"schema": 2})), ("missing", "{}"),
                               ("string", json.dumps({"schema": "1"})), ("bool", json.dumps({"schema": True})),
                               ("broken", "{not json"), ("list", "[]")]:
                path = Path(tmp) / f"{name}.json"
                path.write_text(text)
                with self.assertRaises(rm.ReportError) as ctx:
                    rm.read_versioned(path)
                self.assertIn(str(path), str(ctx.exception))

    def test_read_refuses_a_missing_file(self):
        with self.assertRaises(rm.ReportError):
            rm.read_versioned(Path("/nonexistent/x.json"))


if __name__ == "__main__":
    unittest.main()
