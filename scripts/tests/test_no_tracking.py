"""Tests for scripts/check_no_tracking.py (UA-F11 T-U11-012; FR-U11-020..023, 025, 080, 081, 083).

Fixture apps are temporary directories (`X.app` with an Info.plist naming a fake executable, plus bundled files);
linked libraries and symbols are planted through `--libraries-file` and `--symbols-file`, so no Mach-O tool runs.
"""
import contextlib
import importlib.util
import io
import json
import plistlib
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

REPO = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("check_no_tracking", REPO / "scripts" / "check_no_tracking.py")
nt = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = nt
SPEC.loader.exec_module(nt)

REAL_DENYLIST = REPO / "Configs" / "tracking-denylist.json"
KINDS = ("advertising", "analytics", "attribution", "crash-reporting")


class NoTrackingTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.app = self.root / "X.app"
        self.app.mkdir()
        (self.app / "Info.plist").write_bytes(plistlib.dumps({"CFBundleExecutable": "X"}))
        (self.app / "X").write_bytes(b"\x00fake executable\x00")
        (self.app / "res").mkdir()
        (self.app / "res" / "notes.txt").write_text("Adjustable BranchSDKx settings, nothing to see\n")
        self.denylist = self.root / "denylist.json"
        self.write_denylist()

    def tearDown(self):
        self.tmp.cleanup()

    def write_denylist(self, **changes):
        data = json.loads(REAL_DENYLIST.read_text())
        data.update(changes)
        self.denylist.write_text(json.dumps(data))

    def run_tool(self, *extra, denylist=None):
        out, err = io.StringIO(), io.StringIO()
        argv = ["--app", str(self.app), "--denylist", str(denylist or self.denylist), *extra]
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = nt.main(argv)
        return code, out.getvalue(), err.getvalue()

    def report(self, *extra):
        path = self.root / "report.json"
        code, out, _ = self.run_tool(*extra, "--json", str(path))
        return code, out, json.loads(path.read_text())

    # --- clean -------------------------------------------------------------------------------------------

    def test_clean_fixture_passes_with_report(self):
        code, out, report = self.report()
        self.assertEqual(code, 0, out)
        self.assertTrue(out.strip().splitlines()[-1].startswith("PASS: "), out)
        self.assertEqual(report["schema"], 1)
        self.assertEqual(report["check"], "no-tracking")
        self.assertEqual(report["findings"], [])
        self.assertEqual(report["verdict"], "PASS")
        self.assertEqual(len(report["meta"]["executable_sha256"]), 64)

    def test_whole_identifier_only(self):
        """'Adjustable BranchSDKx' must not match AdjustSdk or BranchSDK."""
        data = b"Adjustable BranchSDKx AdjustSdkY _BranchSDK"
        self.assertEqual(nt.library_hits_in_bytes(data, ["AdjustSdk", "BranchSDK"]), set())
        self.assertEqual(nt.library_hits_in_bytes(b"(BranchSDK) AdjustSdk.", ["AdjustSdk", "BranchSDK"]),
                         {"AdjustSdk", "BranchSDK"})

    def test_chunk_boundaries(self):
        path = self.root / "blob.bin"
        libs, syms = ["GoogleMobileAds", "BranchSDK"], ["ASIdentifierManager"]
        # GoogleMobileAds and ASIdentifierManager straddle a 16-byte boundary; BranchSDK is followed by "x" in the next chunk.
        path.write_bytes(b"0123456789 Googl" + b"eMobileAds ASIde" + b"ntifierManager  " + b"       BranchSDK" + b"x")
        libs_found, syms_found = nt.scan_bytes(path, libs, syms, chunk=16)
        self.assertEqual(libs_found, {"GoogleMobileAds"})
        self.assertEqual(syms_found, {"ASIdentifierManager"})

    # --- planted defects (FR-U11-025, FR-U11-083) ----------------------------------------------------------

    def test_linked_adsupport_fails_and_names_file(self):
        libs = self.root / "libs.txt"
        libs.write_text("/System/Library/Frameworks/AdSupport.framework/AdSupport "
                        "(compatibility version 1.0.0, current version 1.0.0)\n"
                        "/usr/lib/libSystem.B.dylib (compatibility version 1.0.0)\n")
        code, out, report = self.report("--libraries-file", str(libs))
        self.assertEqual(code, 1, out)
        self.assertIn({"file": "X", "kind": "framework", "text": "AdSupport"}, report["findings"])
        self.assertEqual(len(report["findings"]), 1, report)
        self.assertTrue(out.strip().splitlines()[-1].startswith("FAIL: "), out)
        self.assertIn("X", out)

    def test_identifier_symbol_fails_and_names_file(self):
        syms = self.root / "syms.txt"
        syms.write_text("                 (undefined) external _OBJC_CLASS_$_ASIdentifierManager (from AdSupport)\n"
                        "0000000100000000 (__TEXT,__text) external _main\n")
        code, out, report = self.report("--symbols-file", str(syms))
        self.assertEqual(code, 1, out)
        self.assertEqual(report["findings"], [{"file": "X", "kind": "symbol", "text": "ASIdentifierManager"}])
        self.assertEqual(report["verdict"], "FAIL")

    def test_library_name_in_bundled_file_fails_and_names_file(self):
        (self.app / "res" / "sdk.json").write_text('{"module": "GoogleMobileAds", "v": 1}')
        code, out, report = self.report()
        self.assertEqual(code, 1, out)
        self.assertEqual(report["findings"], [{"file": "res/sdk.json", "kind": "library", "text": "GoogleMobileAds"}])
        self.assertIn("res/sdk.json", out)

    def test_symbol_text_in_bundled_file_fails(self):
        (self.app / "res" / "a.bin").write_bytes(b"\x00\x0121advertisingIdentifier\x00")
        code, out, report = self.report()
        self.assertEqual(code, 1, out)
        self.assertEqual(report["findings"], [{"file": "res/a.bin", "kind": "symbol", "text": "advertisingIdentifier"}])

    def test_unused_allowance_fails(self):
        self.write_denylist(allowances=[{"text": "GoogleMobileAds", "file_pattern": "res/*.json",
                                         "reason": "fixture: nothing matches"}])
        code, out, report = self.report()
        self.assertEqual(code, 1, out)
        self.assertEqual(report["findings"], [{"file": str(self.denylist), "kind": "unused-allowance",
                                               "text": "GoogleMobileAds"}])

    def test_used_allowance_suppresses_only_its_pattern(self):
        (self.app / "res" / "sdk.json").write_text("GoogleMobileAds")
        (self.app / "res" / "other.txt").write_text("GoogleMobileAds")
        self.write_denylist(allowances=[{"text": "GoogleMobileAds", "file_pattern": "res/*.json",
                                         "reason": "fixture"}])
        code, out, report = self.report()
        self.assertEqual(code, 1, out)
        self.assertEqual(report["findings"], [{"file": "res/other.txt", "kind": "library", "text": "GoogleMobileAds"}])

    # --- unusable input (exit 2) ---------------------------------------------------------------------------

    def test_schema_2_denylist_refused(self):
        self.write_denylist(schema=2)
        code, _, err = self.run_tool()
        self.assertEqual(code, 2)
        self.assertIn(str(self.denylist), err)

    def test_invalid_denylist_refused(self):
        for changes in ({"allowances": [{"text": "GoogleMobileAds", "file_pattern": "*", "reason": ""}]},
                        {"symbols": ["ab"]},
                        {"libraries": {"advertising": ["Ads"]}}):
            with self.subTest(changes=changes):
                self.write_denylist(**changes)
                code, _, err = self.run_tool()
                self.assertEqual(code, 2, err)

    def test_missing_app_refused_with_path(self):
        missing = self.root / "Missing.app"
        out, errio = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(errio):
            code = nt.main(["--app", str(missing), "--denylist", str(self.denylist)])
        self.assertEqual(code, 2)
        self.assertIn(str(missing), errio.getvalue())

    def test_macho_without_tools_refused(self):
        (self.app / "X").write_bytes(b"\xcf\xfa\xed\xfe" + b"\x00" * 64)
        with mock.patch.object(nt.shutil, "which", return_value=None):
            code, _, err = self.run_tool()
        self.assertEqual(code, 2)
        self.assertIn("X", err)

    # --- the real deny list --------------------------------------------------------------------------------

    def test_real_denylist_loads_and_covers_four_kinds(self):
        data = nt.load_denylist(REAL_DENYLIST)
        for name in ("AdSupport", "AppTrackingTransparency", "iAd", "AdServices"):
            self.assertIn(name, data["frameworks"])
        for name in ("ASIdentifierManager", "advertisingIdentifier", "ATTrackingManager",
                     "requestTrackingAuthorization"):
            self.assertIn(name, data["symbols"])
        for kind in KINDS:
            self.assertGreaterEqual(len(data["libraries"][kind]), 3, kind)
            for name in data["libraries"][kind]:
                self.assertGreaterEqual(len(name), 6, name)
        self.assertEqual(data["allowances"], [])


if __name__ == "__main__":
    unittest.main()
