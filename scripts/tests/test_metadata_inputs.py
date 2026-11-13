"""Tests for scripts/metadata_inputs.py (UA-F11 T-U11-027): fixture ledgers, catalogs and reports in temp dirs."""
import importlib.util
import io
import json
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("metadata_inputs", REPO / "scripts" / "metadata_inputs.py")
mi = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = mi
SPEC.loader.exec_module(mi)

DIGEST = "a" * 64
OTHER = "b" * 64


def experience(code, order, release="launch", tier="free"):
    return {"code": code, "id": f"{code.lower()}.thing-{order}", "name": f"Thing {code}", "tier": tier,
            "launcher_category": "create", "order": order, "release": release}


class MetadataInputsTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)
        self.ledger = self.dir / "ledger.json"
        self.catalog = self.dir / "catalog.json"
        self.registrations = self.dir / "registrations.json"
        self.out = self.dir / "out" / "metadata-inputs.json"
        self.write_ledger({"X-A01": "pass", "X-A02": "pending"})
        self.write_json(self.catalog, {"experiences": [
            experience("A02", 2), experience("A01", 1), experience("A03", 3),
            experience("R05-G01", 400, release="backlog")]})
        self.write_json(self.registrations, {"schema": 1, "registrations": {
            "a01.thing-1": {"permissions": ["photo-library-add"]}, "a02.thing-2": {}}})

    def tearDown(self):
        self.tmp.cleanup()

    def write_json(self, path, data):
        path.write_text(json.dumps(data))

    def write_ledger(self, statuses, extra=None):
        gates = [{"id": gid, "kind": "experience" if gid.startswith("X-") else "feature", "status": status}
                 for gid, status in statuses.items()]
        self.write_json(self.ledger, {"schema": 1, "gates": gates + (extra or [])})

    def report(self, name, verdict="PASS", digest=DIGEST, schema=1, check=None):
        path = self.dir / name
        check = check or {"privacy.json": "privacy-manifest", "tracking.json": "no-tracking"}.get(name, name.removesuffix(".json"))
        self.write_json(path, {"schema": schema, "check": check,
                               "meta": {"executable_sha256": digest}, "findings": [], "verdict": verdict})
        return path

    def run_tool(self, *args, reports=None):
        argv = ["--ledger", str(self.ledger), "--catalog", str(self.catalog),
                "--registrations", str(self.registrations), "--out", str(self.out), *args]
        if reports:
            argv += ["--privacy-report", str(reports[0]), "--tracking-report", str(reports[1])]
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            code = mi.main(argv)
        return code, out.getvalue(), err.getvalue()

    def generated(self):
        return json.loads(self.out.read_text())

    def codes(self):
        return [e["code"] for e in self.generated()["experiences"]]

    def test_only_passing_gate_listed(self):
        code, out, _ = self.run_tool("--write")
        self.assertEqual(code, 0)
        self.assertTrue(out.strip().splitlines()[-1].startswith("PASS"))
        data = self.generated()
        self.assertEqual(data["schema"], 1)
        self.assertEqual(data["experiences"], [{"id": "a01.thing-1", "code": "A01", "name": "Thing A01",
                                                "tier": "free", "category": "create",
                                                "permissions": ["photo-library-add"]}])
        self.assertEqual(len(data["ledger_sha256"]), 64)

    def test_failed_and_absent_gates_excluded(self):
        self.write_ledger({"X-A01": "fail", "X-A02": "pass"})  # X-A03 absent
        self.run_tool("--write")
        self.assertEqual(self.codes(), ["A02"])
        self.assertEqual(self.generated()["experiences"][0]["permissions"], [])

    def test_queue_order(self):
        self.write_ledger({"X-A03": "pass", "X-A02": "pass", "X-A01": "pass"})
        self.run_tool("--write")
        self.assertEqual(self.codes(), ["A01", "A02", "A03"])

    def test_backlog_excluded_even_if_gate_passes(self):
        self.write_ledger({"X-A01": "pass", "X-R05-G01": "pass"})
        self.run_tool("--write")
        self.assertEqual(self.codes(), ["A01"])

    def test_unproven_without_reports(self):
        self.run_tool("--write")
        self.assertEqual(self.generated()["privacy_answers"], "unproven")

    def test_unproven_when_a_report_is_from_another_check(self):
        self.run_tool("--write", reports=(self.report("privacy.json", check="no-tracking"), self.report("tracking.json")))
        self.assertEqual(json.loads(self.out.read_text())["privacy_answers"], "unproven")

    def test_unproven_with_failing_report(self):
        self.run_tool("--write", reports=(self.report("privacy.json", verdict="FAIL"), self.report("tracking.json")))
        self.assertEqual(self.generated()["privacy_answers"], "unproven")

    def test_unproven_with_different_digests(self):
        self.run_tool("--write", reports=(self.report("privacy.json"), self.report("tracking.json", digest=OTHER)))
        self.assertEqual(self.generated()["privacy_answers"], "unproven")

    def test_unproven_with_null_digest(self):
        self.run_tool("--write", reports=(self.report("privacy.json", digest=None),
                                          self.report("tracking.json", digest=None)))
        self.assertEqual(self.generated()["privacy_answers"], "unproven")

    def test_proven_with_two_passing_reports_of_one_digest(self):
        code, _, _ = self.run_tool("--write", reports=(self.report("privacy.json"), self.report("tracking.json")))
        self.assertEqual(code, 0)
        answers = self.generated()["privacy_answers"]
        self.assertEqual(answers["data_collected"], "none")
        self.assertEqual(answers["tracking"], "no")
        self.assertEqual(answers["proof"]["executable_sha256"], DIGEST)
        self.assertTrue(answers["proof"]["privacy_report"].endswith("privacy.json"))
        self.assertTrue(answers["proof"]["tracking_report"].endswith("tracking.json"))

    def test_check_passes_on_fresh_file(self):
        self.run_tool("--write")
        code, out, _ = self.run_tool("--check")
        self.assertEqual(code, 0, out)

    def test_check_passes_on_proven_file_without_reports(self):
        self.run_tool("--write", reports=(self.report("privacy.json"), self.report("tracking.json")))
        code, out, _ = self.run_tool("--check")
        self.assertEqual(code, 0, out)

    def test_check_fails_on_stale_file(self):
        self.run_tool("--write")
        self.write_ledger({"X-A01": "pass", "X-A02": "pass"})
        code, out, _ = self.run_tool("--check")
        self.assertEqual(code, 1)
        self.assertTrue(out.strip().splitlines()[-1].startswith("FAIL"))

    def test_check_fails_on_edited_experiences(self):
        self.run_tool("--write")
        data = self.generated()
        data["experiences"][0]["name"] = "Something Else"
        self.write_json(self.out, data)
        self.assertEqual(self.run_tool("--check")[0], 1)

    def test_check_fails_on_malformed_privacy_answers(self):
        self.run_tool("--write")
        data = self.generated()
        data["privacy_answers"] = {"data_collected": "none", "tracking": "no"}  # no proof
        self.write_json(self.out, data)
        self.assertEqual(self.run_tool("--check")[0], 1)

    def test_check_with_reports_compares_privacy_answers(self):
        self.run_tool("--write")  # unproven
        code, _, _ = self.run_tool("--check", reports=(self.report("privacy.json"), self.report("tracking.json")))
        self.assertEqual(code, 1)

    def test_check_fails_on_missing_file(self):
        code, out, _ = self.run_tool("--check")
        self.assertEqual(code, 1)
        self.assertIn("missing", out)

    def test_unrelated_ledger_change_keeps_file_fresh(self):
        self.run_tool("--write")
        self.write_ledger({"X-A01": "pass", "X-A02": "pending"}, extra=[{"id": "UA-F11", "kind": "feature",
                                                                          "status": "pass"}])
        self.assertEqual(self.run_tool("--check")[0], 0)

    def test_newer_report_schema_refused(self):
        code, _, err = self.run_tool("--write", reports=(self.report("privacy.json", schema=2),
                                                         self.report("tracking.json")))
        self.assertEqual(code, 2)
        self.assertIn("privacy.json", err)
        self.assertFalse(self.out.exists())

    def test_newer_output_schema_refused_by_check(self):
        self.run_tool("--write")
        data = self.generated()
        data["schema"] = 2
        self.write_json(self.out, data)
        self.assertEqual(self.run_tool("--check")[0], 2)

    def test_only_one_report_is_usage_error(self):
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            code = mi.main(["--write", "--ledger", str(self.ledger), "--catalog", str(self.catalog),
                            "--registrations", str(self.registrations), "--out", str(self.out),
                            "--privacy-report", str(self.report("privacy.json"))])
        self.assertEqual(code, 2)

    def test_mode_required(self):
        with redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as raised:
            mi.main(["--out", str(self.out)])
        self.assertEqual(raised.exception.code, 2)

    def test_generation_deterministic(self):
        self.run_tool("--write")
        first = self.out.read_bytes()
        self.run_tool("--write")
        self.assertEqual(first, self.out.read_bytes())

    def test_json_report(self):
        path = self.dir / "report.json"
        self.run_tool("--write")
        code, _, _ = self.run_tool("--check", "--json", str(path))
        self.assertEqual(code, 0)
        report = json.loads(path.read_text())
        self.assertEqual(report["schema"], 1)
        self.assertEqual(report["check"], "metadata-inputs")
        self.assertEqual(report["verdict"], "PASS")
        self.assertIsNone(report["meta"]["executable_sha256"])

    def test_registrations_without_permissions_absent_file_is_error(self):
        self.registrations.unlink()
        code, _, err = self.run_tool("--write")
        self.assertEqual(code, 2)
        self.assertIn("registrations", err)


if __name__ == "__main__":
    unittest.main()
