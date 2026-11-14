"""Tests for scripts/check_usage_descriptions.py and the permissions of scripts/build_catalog.py (UA-F11 T-U11-007)."""
import contextlib
import importlib.util
import io
import json
import plistlib
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "scripts"))


def load(name):
    spec = importlib.util.spec_from_file_location(name, REPO / "scripts" / f"{name}.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


cud = load("check_usage_descriptions")
bc = load("build_catalog")

PHOTO = "Saves exported artwork to your photo library when you choose Save Image."
VOCAB = {"schema": 1, "words": {
    "photo-library-add": {"key": "NSPhotoLibraryAddUsageDescription", "text": PHOTO},
    "microphone": {"key": "NSMicrophoneUsageDescription", "text": "Listens to sound in the room to drive the visuals."}}}


def run(tool, argv):
    with contextlib.redirect_stdout(io.StringIO()) as out, contextlib.redirect_stderr(io.StringIO()) as err:
        try:
            code = tool.main(argv)
        except SystemExit as stop:
            code = stop.code
    return code, out.getvalue() + err.getvalue()


class UsageDescriptionTests(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.dir = Path(tmp.name)
        self.vocab = self.write("vocab.json", VOCAB)
        self.regs = self.write("regs.json", {"schema": 1, "registrations": {
            "a01.x": {"permissions": ["photo-library-add"]}, "a02.y": {}}})
        self.plist = self.dir / "Info.plist"
        self.write_plist({"CFBundleName": "X", "NSPhotoLibraryAddUsageDescription": PHOTO})

    def write(self, name, value):
        path = self.dir / name
        path.write_text(json.dumps(value))
        return path

    def write_plist(self, value, path=None, fmt=plistlib.FMT_XML):
        (path or self.plist).write_bytes(plistlib.dumps(value, fmt=fmt))

    def check(self, *extra):
        return run(cud, ["--plist", str(self.plist), "--registrations", str(self.regs), "--vocabulary", str(self.vocab), *extra])

    def test_matching_fixture_passes(self):
        code, out = self.check()
        self.assertEqual(code, 0, out)
        self.assertTrue(out.strip().splitlines()[-1].startswith("PASS:"))

    def test_extra_key_fails(self):
        self.write_plist({"NSPhotoLibraryAddUsageDescription": PHOTO, "NSCameraUsageDescription": "Uses the camera a lot."})
        code, out = self.check()
        self.assertEqual(code, 1)
        self.assertIn("extra-key", out)
        self.assertTrue(out.strip().splitlines()[-1].startswith("FAIL:"))

    def test_missing_key_fails(self):
        self.write_plist({"CFBundleName": "X"})
        code, out = self.check()
        self.assertEqual(code, 1)
        self.assertIn("missing-key", out)

    def test_unknown_word_fails(self):
        self.regs = self.write("regs.json", {"schema": 1, "registrations": {"a01.x": {"permissions": ["photo-library-add", "bluetooth"]}}})
        code, out = self.check()
        self.assertEqual(code, 1)
        self.assertIn("unknown-word", out)
        self.assertIn("bluetooth", out)

    def test_text_different_from_vocabulary_fails(self):
        self.write_plist({"NSPhotoLibraryAddUsageDescription": PHOTO + " Also more."})
        code, out = self.check()
        self.assertEqual(code, 1)
        self.assertIn("text-differs", out)

    def test_json_report(self):
        self.write_plist({"CFBundleName": "X"})
        report = self.dir / "out" / "report.json"
        code, _ = self.check("--json", str(report))
        self.assertEqual(code, 1)
        data = json.loads(report.read_text())
        self.assertEqual((data["schema"], data["check"], data["verdict"]), (1, "usage-descriptions", "FAIL"))
        self.assertIsNone(data["meta"]["executable_sha256"])
        self.assertEqual([f["kind"] for f in data["findings"]], ["missing-key"])

    def test_app_bundle_with_binary_plist(self):
        app = self.dir / "X.app"
        app.mkdir()
        self.write_plist({"CFBundleExecutable": "X", "NSPhotoLibraryAddUsageDescription": PHOTO},
                         path=app / "Info.plist", fmt=plistlib.FMT_BINARY)
        (app / "X").write_bytes(b"binary")
        report = self.dir / "app.json"
        code, out = run(cud, ["--app", str(app), "--registrations", str(self.regs), "--vocabulary", str(self.vocab),
                              "--json", str(report)])
        self.assertEqual(code, 0, out)
        self.assertEqual(len(json.loads(report.read_text())["meta"]["executable_sha256"]), 64)

    def test_newer_vocabulary_schema_is_refused(self):
        self.vocab = self.write("vocab.json", dict(VOCAB, schema=2))
        code, out = self.check()
        self.assertEqual(code, 2)
        self.assertIn("vocab.json", out)

    def test_missing_plist_is_a_usage_error(self):
        self.plist.unlink()
        code, out = self.check()
        self.assertEqual(code, 2)
        self.assertIn("Info.plist", out)

    def project(self, body):
        path = self.dir / "project.yml"
        path.write_text("name: X\npackages:\n  VisualCore:\n    path: P\ntargets:\n  Other:\n    type: framework\n"
                        "    info:\n      properties:\n        NSCameraUsageDescription: not this target\n"
                        "  VisualCore:\n    type: application\n    info:\n      properties:\n" + body +
                        "  Next:\n    type: framework\n")
        return path

    def test_project_source_reads_only_the_app_target(self):
        path = self.project(f"        # a comment\n        NSPhotoLibraryAddUsageDescription: {PHOTO}\n")
        code, out = run(cud, ["--project", str(path), "--registrations", str(self.regs), "--vocabulary", str(self.vocab)])
        self.assertEqual(code, 0, out)

    def test_project_source_extra_key_fails(self):
        path = self.project(f"        NSPhotoLibraryAddUsageDescription: \"{PHOTO}\"\n        NSMicrophoneUsageDescription: x y\n")
        code, out = run(cud, ["--project", str(path), "--registrations", str(self.regs), "--vocabulary", str(self.vocab)])
        self.assertEqual(code, 1, out)
        self.assertIn("extra-key", out)

    def test_project_without_the_target_is_unusable(self):
        path = self.dir / "project.yml"
        path.write_text("targets:\n  Other:\n    type: framework\n")
        code, out = run(cud, ["--project", str(path), "--registrations", str(self.regs), "--vocabulary", str(self.vocab)])
        self.assertEqual(code, 2, out)

    def test_real_repository_passes_with_two_keys(self):
        # Feature 047 (A06-P01): VisualCore Music Lab declares the microphone permission (live input).
        code, out = run(cud, [])
        self.assertEqual(code, 0, out)
        last = out.strip().splitlines()[-1]
        self.assertTrue(last.startswith("PASS:"), last)
        self.assertIn("2 keys (NSMicrophoneUsageDescription, NSPhotoLibraryAddUsageDescription)", last)

    def test_real_vocabulary_is_well_formed(self):
        with contextlib.redirect_stdout(io.StringIO()):
            words = bc.load_vocabulary(REPO)
        self.assertEqual(sorted(words), ["camera", "microphone", "photo-library-add"])
        self.assertEqual(words["photo-library-add"]["text"], PHOTO)


class BuildCatalogPermissionTests(unittest.TestCase):
    """build_catalog accepts an optional permissions list of 0-8 distinct vocabulary words and never copies it."""

    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name)
        for rel in ("docs/catalog/experience-catalog.json", "Catalog/categories.json", "Catalog/path-map.json",
                    "Configs/permission-vocabulary.json", "Catalog/experience-ids.golden.txt"):
            (self.root / rel).parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(REPO / rel, self.root / rel)
        # A copy of the gate list with every X- gate pending; the repository's ledger is only read.
        ledger_rel = Path(".autonomy") / "migration" / "ledger.json"
        ledger = json.loads((REPO / ledger_rel).read_text())
        for gate in ledger["gates"]:
            if gate["id"].startswith("X-"):
                gate["status"] = "pending"
        (self.root / ledger_rel).parent.mkdir(parents=True)
        (self.root / ledger_rel).write_text(json.dumps(ledger))
        self.entry = {"capabilities": ["still export"], "quality_tiers": ["level-0"], "palette": ["#112233"], "content": None}

    def build(self, **extra):
        regs = {"schema": 1, "registrations": {"a01.generative-art-studio": dict(self.entry, **extra)}}
        (self.root / "Catalog/registrations.json").write_text(json.dumps(regs))
        with contextlib.redirect_stdout(io.StringIO()) as out:
            try:
                code = bc.main([], self.root)
            except SystemExit as stop:
                return 1, out.getvalue() + str(stop)
        return code, out.getvalue()

    def assertRejected(self, permissions, phrase):
        code, out = self.build(permissions=permissions)
        self.assertEqual(code, 1, out)
        self.assertIn(phrase, out)

    def test_absent_permissions_accepted(self):
        self.assertEqual(self.build()[0], 0)

    def test_empty_and_valid_permissions_accepted_and_not_in_the_runtime_catalog(self):
        self.assertEqual(self.build(permissions=[])[0], 0)
        code, out = self.build(permissions=["photo-library-add", "microphone"])
        self.assertEqual(code, 0, out)
        text = (self.root / "Catalog/experiences.json").read_text()
        self.assertNotIn("permissions", text)
        self.assertNotIn("photo-library-add", text)
        entry = next(e for e in json.loads(text)["experiences"] if e["id"] == "a01.generative-art-studio")
        self.assertNotIn("permissions", entry)

    def test_permissions_not_a_list_rejected(self):
        self.assertRejected("photo-library-add", "permissions must be a list")

    def test_more_than_eight_words_rejected(self):
        self.assertRejected([f"word-{n}" for n in range(9)], "at most 8")

    def test_duplicate_words_rejected(self):
        self.assertRejected(["camera", "camera"], "distinct")

    def test_unknown_word_rejected(self):
        self.assertRejected(["bluetooth"], "bluetooth is not in Configs/permission-vocabulary.json")

    def test_newer_vocabulary_schema_rejected(self):
        path = self.root / "Configs/permission-vocabulary.json"
        path.write_text(json.dumps(dict(json.loads(path.read_text()), schema=2)))
        self.assertRejected(["camera"], "schema 2 is not supported")


if __name__ == "__main__":
    unittest.main()
