"""Tests for scripts/check_licenses.py --app and --json (UA-F11 T-U11-018; FR-U11-031, 080, 083).

Fixture apps get a `Licenses/` folder produced by `bundle_licenses.bundle()` from the real inventory; the exact bundle
passes, and each planted defect (missing shipped text, extra text, differing text byte, differing index) fails naming
the file. An unusable app path (missing, or without a main executable) is exit 2; an app without `Licenses/` is a FAIL
naming the folder.
"""
import contextlib
import importlib.util
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]


def load(name):
    if name in sys.modules:
        return sys.modules[name]
    spec = importlib.util.spec_from_file_location(name, REPO / "scripts" / f"{name}.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


cl = load("check_licenses")
bl = load("bundle_licenses")
INVENTORY = json.loads((REPO / "docs" / "legal" / "third-party.json").read_text())
SHIPPED = sorted(c["id"] for c in INVENTORY["components"] if c.get("scope") == "shipped")


def make_app(parent: Path, licenses: bool = True) -> Path:
    import plistlib
    app = parent / "X.app"
    app.mkdir()
    (app / "Info.plist").write_bytes(plistlib.dumps({"CFBundleExecutable": "X"}))
    (app / "X").write_bytes(b"\xcf\xfa\xed\xfe fixture executable")
    if licenses:
        problems = bl.bundle(INVENTORY, app / "Licenses", REPO)
        assert not problems, problems
    return app


class LicensesAppTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)
        self.addCleanup(self.tmp.cleanup)

    def run_check(self, *argv):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = cl.main(["--root", str(REPO), *argv])
        return code, out.getvalue() + err.getvalue()

    def test_inventory_has_shipped_entries(self):
        self.assertIn("angle", SHIPPED)

    def test_exact_bundle_passes(self):
        app = make_app(self.dir)
        code, out = self.run_check("--app", str(app))
        self.assertEqual(code, 0, out)
        self.assertIn("PASS", out.splitlines()[-1])

    def test_missing_shipped_text_fails_naming_it(self):
        app = make_app(self.dir)
        (app / "Licenses" / f"{SHIPPED[0]}.txt").unlink()
        code, out = self.run_check("--app", str(app))
        self.assertEqual(code, 1, out)
        self.assertIn(f"missing Licenses/{SHIPPED[0]}.txt", out)
        self.assertTrue(out.splitlines()[-1].startswith("FAIL"))

    def test_extra_text_fails_naming_it(self):
        app = make_app(self.dir)
        (app / "Licenses" / "stray.txt").write_text("not inventoried\n")
        code, out = self.run_check("--app", str(app))
        self.assertEqual(code, 1, out)
        self.assertIn("extra Licenses/stray.txt", out)

    def test_extra_nested_file_fails_naming_it(self):
        app = make_app(self.dir)
        (app / "Licenses" / "sub").mkdir()
        (app / "Licenses" / "sub" / "a.txt").write_text("x")
        code, out = self.run_check("--app", str(app))
        self.assertEqual(code, 1, out)
        self.assertIn("extra Licenses/sub/a.txt", out)

    def test_differing_text_byte_fails_naming_it(self):
        app = make_app(self.dir)
        path = app / "Licenses" / f"{SHIPPED[-1]}.txt"
        data = bytearray(path.read_bytes())
        data[0] ^= 0x01
        path.write_bytes(bytes(data))
        code, out = self.run_check("--app", str(app))
        self.assertEqual(code, 1, out)
        self.assertIn(f"differs Licenses/{SHIPPED[-1]}.txt", out)

    def test_differing_index_fails_naming_it(self):
        app = make_app(self.dir)
        index = app / "Licenses" / "licenses.json"
        entries = json.loads(index.read_text())
        entries[0]["name"] += " (edited)"
        index.write_text(json.dumps(entries, indent=2) + "\n")
        code, out = self.run_check("--app", str(app))
        self.assertEqual(code, 1, out)
        self.assertIn("differs Licenses/licenses.json", out)

    def test_missing_licenses_folder_fails_naming_it(self):
        app = make_app(self.dir, licenses=False)
        code, out = self.run_check("--app", str(app))
        self.assertEqual(code, 1, out)
        self.assertIn("Licenses", out)
        self.assertIn("missing", out)

    def test_missing_app_is_usage_error(self):
        code, out = self.run_check("--app", str(self.dir / "Nope.app"))
        self.assertEqual(code, 2, out)
        self.assertIn("Nope.app", out)

    def test_app_without_executable_is_usage_error(self):
        app = make_app(self.dir)
        (app / "X").unlink()
        code, out = self.run_check("--app", str(app))
        self.assertEqual(code, 2, out)

    def test_json_report_on_pass(self):
        app = make_app(self.dir)
        report = self.dir / "out" / "licenses-app.json"
        code, out = self.run_check("--app", str(app), "--json", str(report))
        self.assertEqual(code, 0, out)
        data = json.loads(report.read_text())
        self.assertEqual(data["schema"], 1)
        self.assertEqual(data["check"], "licenses-app")
        self.assertEqual(data["verdict"], "PASS")
        self.assertEqual(data["findings"], [])
        self.assertRegex(data["meta"]["executable_sha256"], r"^[0-9a-f]{64}$")
        self.assertIsNone(data["meta"]["configuration"])

    def test_json_report_on_fail_lists_findings(self):
        app = make_app(self.dir)
        (app / "Licenses" / "stray.txt").write_text("x")
        report = self.dir / "r.json"
        code, _ = self.run_check("--app", str(app), "--json", str(report))
        self.assertEqual(code, 1)
        data = json.loads(report.read_text())
        self.assertEqual(data["verdict"], "FAIL")
        self.assertIn({"file": "Licenses/stray.txt", "kind": "extra",
                       "text": "extra Licenses/stray.txt (not produced from the inventory)"}, data["findings"])

    def test_json_report_without_app(self):
        report = self.dir / "inv.json"
        code, out = self.run_check("--json", str(report))
        self.assertEqual(code, 0, out)
        data = json.loads(report.read_text())
        self.assertEqual(data["check"], "licenses")
        self.assertIsNone(data["meta"]["executable_sha256"])
        self.assertEqual(data["verdict"], "PASS")

    def test_inventory_checks_still_run_with_app(self):
        app = make_app(self.dir)
        code, out = self.run_check("--app", str(app))
        self.assertEqual(code, 0, out)
        self.assertIn("binary libEGL", out)


if __name__ == "__main__":
    unittest.main()
