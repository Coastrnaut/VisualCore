"""Tests for the UA-F11 privacy-manifest report (specs/197-ua-f11-compliance T-U11-004; FR-U11-001..004, 080..083).

Planted defects (undeclared category, unused category, tracking, tracking domains, collected data types) each fail;
a matching manifest passes; `--json` writes the data-model §7 report with `meta`. `collect()` is replaced by a fake,
so no `nm` or `strings` runs.
"""
import hashlib
import importlib.util
import io
import json
import plistlib
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "scripts"))
SPEC = importlib.util.spec_from_file_location("check_privacy_manifest", REPO / "scripts" / "check_privacy_manifest.py")
privacy = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = privacy
SPEC.loader.exec_module(privacy)

UD = "NSPrivacyAccessedAPICategoryUserDefaults"
CLEAN = {"NSPrivacyTracking": False, "NSPrivacyTrackingDomains": [], "NSPrivacyCollectedDataTypes": [],
         "NSPrivacyAccessedAPITypes": [{"NSPrivacyAccessedAPIType": UD, "NSPrivacyAccessedAPITypeReasons": ["CA92.1"]}]}
EXECUTABLE = b"\xcf\xfa\xed\xfe fixture executable"


def ok(report: dict) -> bool:
    return not (report["undeclared"] or report["unused"] or report["violations"])


class CompareTests(unittest.TestCase):
    detected = {UD: ["_OBJC_CLASS_$_NSUserDefaults"]}

    def test_matching_manifest_passes(self):
        self.assertTrue(ok(privacy.compare(self.detected, CLEAN)))

    def test_undeclared_category_fails(self):
        r = privacy.compare(dict(self.detected, NSPrivacyAccessedAPICategoryDiskSpace=["_statfs"]), CLEAN)
        self.assertEqual(r["undeclared"], ["NSPrivacyAccessedAPICategoryDiskSpace"])
        self.assertFalse(ok(r))

    def test_unused_category_fails(self):
        r = privacy.compare({}, CLEAN)
        self.assertEqual(r["unused"], [UD])
        self.assertFalse(ok(r))

    def test_tracking_true_fails(self):
        self.assertFalse(ok(privacy.compare(self.detected, dict(CLEAN, NSPrivacyTracking=True))))

    def test_tracking_missing_fails(self):
        manifest = {k: v for k, v in CLEAN.items() if k != "NSPrivacyTracking"}
        self.assertFalse(ok(privacy.compare(self.detected, manifest)))

    def test_tracking_domains_fail(self):
        r = privacy.compare(self.detected, dict(CLEAN, NSPrivacyTrackingDomains=["example.com"]))
        self.assertTrue(any("NSPrivacyTrackingDomains" in v for v in r["violations"]))

    def test_collected_data_types_fail(self):
        r = privacy.compare(self.detected, dict(CLEAN, NSPrivacyCollectedDataTypes=[{"NSPrivacyCollectedDataType": "x"}]))
        self.assertTrue(any("NSPrivacyCollectedDataTypes" in v for v in r["violations"]))


class MainReportTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)
        self.app = self.dir / "X.app"
        self.app.mkdir()
        with open(self.app / "Info.plist", "wb") as f:
            plistlib.dump({"CFBundleExecutable": "X"}, f)
        (self.app / "X").write_bytes(EXECUTABLE)
        self.original = privacy.collect
        privacy.collect = lambda binary: (["_OBJC_CLASS_$_NSUserDefaults"], [])

    def tearDown(self):
        privacy.collect = self.original
        self.tmp.cleanup()

    def run_main(self, manifest: dict | None) -> tuple[int, dict | None, str]:
        if manifest is not None:
            with open(self.app / "PrivacyInfo.xcprivacy", "wb") as f:
                plistlib.dump(manifest, f)
        out = self.dir / "report.json"
        out.unlink(missing_ok=True)
        buf = io.StringIO()
        with redirect_stdout(buf), redirect_stderr(io.StringIO()):
            code = privacy.main(["--app", str(self.app), "--json", str(out)])
        return code, (json.loads(out.read_text()) if out.exists() else None), buf.getvalue()

    def test_matching_manifest_report(self):
        code, report, text = self.run_main(CLEAN)
        self.assertEqual(code, 0)
        self.assertEqual(report["schema"], 1)
        self.assertEqual(report["check"], "privacy-manifest")
        self.assertEqual(report["verdict"], "PASS")
        self.assertEqual(report["findings"], [])
        self.assertEqual(report["meta"]["executable_sha256"], hashlib.sha256(EXECUTABLE).hexdigest())
        self.assertIsNone(report["meta"]["configuration"])
        for key in ("revision", "clean"):
            self.assertIn(key, report["meta"])
        for key in ("detected", "declared", "undeclared", "unused", "violations", "binaries"):
            self.assertIn(key, report, "existing fields are kept")
        self.assertEqual(report["binaries"], ["X"])
        self.assertIn("PASS", text.strip().splitlines()[-1])

    def assert_fails(self, manifest: dict, kind: str):
        code, report, text = self.run_main(manifest)
        self.assertEqual(code, 1)
        self.assertEqual(report["verdict"], "FAIL")
        self.assertIn(kind, {f["kind"] for f in report["findings"]})
        self.assertIn("FAIL", text.strip().splitlines()[-1])

    def test_undeclared_category_fails(self):
        self.assert_fails(dict(CLEAN, NSPrivacyAccessedAPITypes=[]), "undeclared")

    def test_unused_category_fails(self):
        extra = {"NSPrivacyAccessedAPIType": "NSPrivacyAccessedAPICategoryDiskSpace",
                 "NSPrivacyAccessedAPITypeReasons": ["E174.1"]}
        self.assert_fails(dict(CLEAN, NSPrivacyAccessedAPITypes=CLEAN["NSPrivacyAccessedAPITypes"] + [extra]), "unused")

    def test_tracking_true_fails(self):
        self.assert_fails(dict(CLEAN, NSPrivacyTracking=True), "violation")

    def test_tracking_domains_fail(self):
        self.assert_fails(dict(CLEAN, NSPrivacyTrackingDomains=["tracker.example"]), "violation")

    def test_collected_data_types_fail(self):
        self.assert_fails(dict(CLEAN, NSPrivacyCollectedDataTypes=[{"NSPrivacyCollectedDataType": "x"}]), "violation")

    def test_missing_manifest_exits_2(self):
        code, report, _ = self.run_main(None)
        self.assertEqual(code, 2)
        self.assertIsNone(report)

    def test_missing_app_exits_2(self):
        with redirect_stderr(io.StringIO()):
            self.assertEqual(privacy.main(["--app", str(self.dir / "Missing.app")]), 2)


if __name__ == "__main__":
    unittest.main()
