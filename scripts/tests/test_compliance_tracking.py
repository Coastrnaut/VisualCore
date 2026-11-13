"""Tests for the advertising/tracking rule of scripts/check_compliance.py (UA-F11 T-U11-015; FR-U11-022)."""
import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("check_compliance", REPO / "scripts" / "check_compliance.py")
cc = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = cc
SPEC.loader.exec_module(cc)

LABEL = "advertising or tracking API (Constitution XII)"


class ComplianceTrackingTests(unittest.TestCase):
    def scan_source(self, source: str, name: str = "a.swift") -> list[str]:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "Packages" / "X" / "Sources" / name
            path.parent.mkdir(parents=True)
            path.write_text(source)
            return cc.scan(Path(tmp))

    def test_planted_tracking_code_fails(self):
        cases = {
            "import AdSupport\n": "a.swift",
            "import AppTrackingTransparency\n": "a.swift",
            "let id = ASIdentifierManager.shared().advertisingIdentifier\n": "a.swift",
            "ATTrackingManager.requestTrackingAuthorization { _ in }\n": "a.swift",
            "#import <AdSupport/AdSupport.h>\n": "a.m",
            "#import <AppTrackingTransparency/AppTrackingTransparency.h>\n": "a.m",
        }
        for source, name in cases.items():
            with self.subTest(source=source):
                self.assertEqual(self.scan_source(source, name), [f"Packages/X/Sources/{name}: {LABEL}"])

    def test_deny_listed_library_imports_fail(self):
        for source, name in {"import GoogleMobileAds\n": "a.swift", "@_implementationOnly import FirebaseAnalytics\n": "a.swift",
                             "#import <AppsFlyerLib/AppsFlyerLib.h>\n": "a.m"}.items():
            with self.subTest(source=source):
                self.assertEqual(self.scan_source(source, name),
                                 [f"Packages/X/Sources/{name}: {cc.TRACKING_LIBRARY_LABEL}"])

    def test_clean_and_commented_sources_pass(self):
        self.assertEqual(self.scan_source("// import AdSupport\nlet advertisingIdentifiers2 = 1\nimport Foundation\n"), [])

    def test_repository_passes(self):
        self.assertEqual(cc.scan(), [])


if __name__ == "__main__":
    unittest.main()
