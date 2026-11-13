"""Tests for scripts/check_distinctiveness.py (UA-F11 T-U11-023, story 6, FR-U11-060..066 and 080..083).

Planted defects run on temporary copies of the real catalog, so the six close pairs and all three design schemas
are always present.
"""
import contextlib
import copy
import importlib.util
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("check_distinctiveness", REPO / "scripts" / "check_distinctiveness.py")
cd = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = cd
SPEC.loader.exec_module(cd)

CATALOG = REPO / "docs" / "catalog" / "experience-catalog.json"
FORBIDDEN = ("merge", "drop", "remove", "replace", "reorder")


def entry(catalog, code):
    return next(e for e in catalog["experiences"] if e["code"] == code)


class Workspace:
    """A temporary catalog, title list and matrix pair; `run` calls main() and captures its output."""

    def __init__(self, test, catalog=None, titles=("Tetris", "Monument Valley")):
        self.dir = Path(tempfile.mkdtemp())
        test.addCleanup(lambda: __import__("shutil").rmtree(self.dir, ignore_errors=True))
        self.catalog_data = catalog if catalog is not None else json.loads(CATALOG.read_text())
        self.catalog = self.dir / "catalog.json"
        self.titles = self.dir / "titles.json"
        self.matrix = self.dir / "legal" / "matrix.json"
        self.summary = self.dir / "legal" / "matrix.md"
        self.report = self.dir / "report.json"
        self.save_catalog()
        self.titles.write_text(json.dumps({"schema": 1, "titles": list(titles)}))

    def save_catalog(self):
        self.catalog.write_text(json.dumps(self.catalog_data, indent=2))

    def run(self, mode, *extra):
        argv = [mode, "--catalog", str(self.catalog), "--titles", str(self.titles), "--matrix", str(self.matrix),
                "--summary", str(self.summary), "--json", str(self.report), *extra]
        out = io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(out):
            code = cd.main(argv)
        return code, out.getvalue()


class Normalization(unittest.TestCase):
    def test_three_schemas(self):
        catalog = json.loads(CATALOG.read_text())
        r03 = entry(catalog, "R03-G01")
        self.assertEqual(cd.normalize_triple(r03), {
            "core_abstraction": r03["design"]["core_abstraction"],
            "player_action": r03["design"]["player_action"],
            "win_rule": r03["design"]["win_predicate"]})
        r04 = entry(catalog, "R04-G25")
        self.assertEqual(cd.normalize_triple(r04)["win_rule"], r04["design"]["win_predicate"])
        r02 = entry(catalog, "R02-G01")
        self.assertEqual(cd.normalize_triple(r02), {
            "core_abstraction": r02["design"]["core_abstraction"],
            "player_action": r02["design"]["roster_core_action"],
            "win_rule": r02["design"]["victory"]})
        a01 = entry(catalog, "A01")
        self.assertEqual(cd.normalize_triple(a01), {
            "core_abstraction": a01["launcher_category"],
            "player_action": a01["design"]["primary_capability"],
            "win_rule": "open-ended"})

    def test_missing_field_is_refused(self):
        catalog = json.loads(CATALOG.read_text())
        r03 = copy.deepcopy(entry(catalog, "R03-G01"))
        del r03["design"]["win_predicate"]
        with self.assertRaises(cd.ReportError):
            cd.normalize_triple(r03)

    def test_words(self):
        self.assertEqual(cd.action_words("Drag THE Points, into 3D wave-knots and an arc"),
                         frozenset({"drag", "point", "wave", "knot", "arc"}))
        self.assertEqual(cd.action_words("GLSL art, export/presets"), frozenset({"glsl", "art", "export", "preset"}))
        self.assertEqual(cd.action_words("a an of to by"), frozenset())

    def test_jaccard(self):
        self.assertEqual(cd.score("typed node graph and effect composition",
                                  "multi-pass effect graph, reusable composition"), 0.375)
        self.assertEqual(cd.score("zephyr quokka marmot", "zephyr quokka walrus"), 0.5)
        self.assertEqual(cd.score("", ""), 0.0)
        self.assertEqual(cd.score("one third split", "one"), round(1 / 3, 4))

    def test_verdict_reasons(self):
        t = {"core_abstraction": "x", "player_action": "Drag a point", "win_rule": "w"}
        self.assertEqual(cd.compare(t, dict(t))[1:], ("shares-mechanic", "triple"))
        self.assertEqual(cd.compare(t, {**t, "win_rule": "other"})[1:], ("shares-mechanic", "action"))
        self.assertEqual(cd.compare(t, {**t, "player_action": "  drag A   point ", "win_rule": "x"})[1:], ("shares-mechanic", "action"))
        self.assertEqual(cd.compare(t, {**t, "player_action": "Steer a comet"})[1:], ("distinct", None))


class PlantedDefects(unittest.TestCase):
    def assert_redesign(self, out, pair, later, ws):
        out = out.replace(str(ws.dir), "<tmp>")
        self.assertIn(pair, out)
        self.assertIn(f"redesign {later} inside its concept", out)
        for word in FORBIDDEN:
            self.assertNotIn(word, out.lower())

    def test_equal_action_fails_with_redesign(self):
        ws = Workspace(self)
        a = entry(ws.catalog_data, "R03-G01")["design"]["player_action"]
        entry(ws.catalog_data, "R04-G10")["design"]["player_action"] = a
        ws.save_catalog()
        code, out = ws.run("--write")
        self.assertEqual(code, 1, out)
        code, out = ws.run("--check")
        self.assertEqual(code, 1, out)
        self.assert_redesign(out, "R03-G01/R04-G10", "R04-G10", ws)
        self.assertIn("(action)", out)
        self.assertTrue(out.rstrip().endswith("FAIL"), out)
        report = json.loads(ws.report.read_text())
        self.assertEqual((report["schema"], report["check"], report["verdict"]), (1, "distinctiveness", "FAIL"))
        self.assertIn("meta", report)
        self.assertTrue(any(f["kind"] == "shares-mechanic" for f in report["findings"]))

    def test_redesign_names_later_queue_code_even_when_listed_first(self):
        ws = Workspace(self)
        entry(ws.catalog_data, "R02-G12")["design"]["roster_core_action"] = \
            entry(ws.catalog_data, "R02-G13")["design"]["roster_core_action"]
        ws.save_catalog()
        ws.run("--write")
        code, out = ws.run("--check")
        self.assertEqual(code, 1, out)
        self.assert_redesign(out, "R02-G13/R02-G12", "R02-G13", ws)

    def test_score_at_threshold_fails(self):
        ws = Workspace(self)
        entry(ws.catalog_data, "A24")["design"]["primary_capability"] = "zephyr quokka marmot"
        entry(ws.catalog_data, "A25")["design"]["primary_capability"] = "zephyr quokka walrus"
        ws.save_catalog()
        ws.run("--write")
        code, out = ws.run("--check")
        self.assertEqual(code, 1, out)
        self.assert_redesign(out, "A24/A25", "A25", ws)
        self.assertIn("(score)", out)
        matrix = json.loads(ws.matrix.read_text())
        self.assertIn(["A24", "A25", 0.5, "shares-mechanic", "score"], matrix["rows"])

    def test_shared_abstraction_and_win_template_alone_pass(self):
        ws = Workspace(self)
        for code in ("R03-G01", "R03-G02"):
            entry(ws.catalog_data, code)["design"]["core_abstraction"] = "harmonic field"
            entry(ws.catalog_data, code)["design"]["win_predicate"] = "reach every target in order"
        ws.save_catalog()
        self.assertEqual(ws.run("--write")[0], 0)
        code, out = ws.run("--check")
        self.assertEqual(code, 0, out)
        row = next(r for r in json.loads(ws.matrix.read_text())["rows"] if r[:2] == ["R03-G01", "R03-G02"])
        self.assertEqual(row[3], "distinct")

    def test_known_title_fails(self):
        ws = Workspace(self)
        entry(ws.catalog_data, "A01")["name"] = "  monument   VALLEY "
        ws.save_catalog()
        ws.run("--write")
        code, out = ws.run("--check")
        self.assertEqual(code, 1, out)
        self.assertIn("A01", out)
        self.assertIn("known-title", out)

    def test_duplicate_slug_and_name_fail(self):
        ws = Workspace(self)
        entry(ws.catalog_data, "A02")["slug"] = entry(ws.catalog_data, "A01")["slug"]
        entry(ws.catalog_data, "A04")["name"] = entry(ws.catalog_data, "A03")["name"].upper()
        ws.save_catalog()
        ws.run("--write")
        code, out = ws.run("--check")
        self.assertEqual(code, 1, out)
        self.assertIn("duplicate-slug", out)
        self.assertIn("duplicate-name", out)

    def test_changed_catalog_makes_matrix_stale(self):
        ws = Workspace(self)
        self.assertEqual(ws.run("--write")[0], 0)
        self.assertEqual(ws.run("--check")[0], 0)
        entry(ws.catalog_data, "A01")["design"]["summary"] += " Changed."
        ws.save_catalog()
        code, out = ws.run("--check")
        self.assertEqual(code, 1, out)
        self.assertIn("stale", out)

    def test_edited_summary_fails(self):
        ws = Workspace(self)
        ws.run("--write")
        ws.summary.write_text(ws.summary.read_text() + "extra\n")
        code, out = ws.run("--check")
        self.assertEqual(code, 1, out)
        self.assertIn(str(ws.summary), out)

    def test_missing_matrix_fails(self):
        ws = Workspace(self)
        code, out = ws.run("--check")
        self.assertEqual(code, 1, out)
        self.assertIn("--write", out)


class Generation(unittest.TestCase):
    def test_interrupted_write_keeps_the_previous_files(self):
        from unittest import mock
        ws = Workspace(self)
        ws.run("--write")
        before = (ws.matrix.read_bytes(), ws.summary.read_bytes())
        ws.catalog_data["experiences"][0]["name"] = ws.catalog_data["experiences"][0]["name"] + " Two"
        ws.save_catalog()
        with mock.patch.object(cd.os, "replace", side_effect=KeyboardInterrupt):
            with self.assertRaises(KeyboardInterrupt):
                ws.run("--write")
        self.assertEqual((ws.matrix.read_bytes(), ws.summary.read_bytes()), before)
        self.assertEqual(sorted(p.name for p in ws.matrix.parent.iterdir()), sorted([ws.matrix.name, ws.summary.name]))

    def test_close_pairs_first_and_rest_sorted(self):
        ws = Workspace(self)
        ws.run("--write")
        matrix = json.loads(ws.matrix.read_text())
        expected = [["R02-G01", "R02-G10"], ["R02-G02", "R02-G03"], ["R02-G09", "R02-G14"],
                    ["R02-G08", "R02-G24"], ["R02-G17", "R02-G18"], ["R02-G13", "R02-G12"]]
        self.assertEqual([r[:2] for r in matrix["rows"][:6]], expected)
        self.assertEqual(matrix["close_pairs"], expected)
        rest = matrix["rows"][6:]
        self.assertEqual(rest, sorted(rest, key=lambda r: (-r[2], r[0], r[1])))
        md = ws.summary.read_text()
        for a, b in expected:
            self.assertIn(f"{a} / {b}", md)

    def test_two_generations_byte_identical(self):
        one, two = Workspace(self), Workspace(self)
        one.run("--write")
        two.run("--write")
        self.assertEqual(one.matrix.read_bytes(), two.matrix.read_bytes())
        self.assertEqual(one.summary.read_bytes(), two.summary.read_bytes())
        self.assertNotIn(b"\r", one.matrix.read_bytes() + one.summary.read_bytes())
        one.run("--write")
        self.assertEqual(one.matrix.read_bytes(), two.matrix.read_bytes())

    def test_catalog_digest(self):
        import hashlib
        ws = Workspace(self)
        ws.run("--write")
        matrix = json.loads(ws.matrix.read_text())
        self.assertEqual(matrix["catalog_sha256"], hashlib.sha256(ws.catalog.read_bytes()).hexdigest())
        self.assertEqual((matrix["schema"], matrix["threshold"], matrix["measure"]),
                         (1, 0.5, "jaccard-player-action-words"))


class Versions(unittest.TestCase):
    def test_newer_matrix_refused(self):
        ws = Workspace(self)
        ws.run("--write")
        data = json.loads(ws.matrix.read_text())
        data["schema"] = 2
        ws.matrix.write_text(json.dumps(data))
        code, out = ws.run("--check")
        self.assertEqual(code, 2, out)
        self.assertIn("schema 2", out)

    def test_newer_titles_refused(self):
        ws = Workspace(self)
        ws.titles.write_text(json.dumps({"schema": 2, "titles": []}))
        self.assertEqual(ws.run("--write")[0], 2)
        self.assertEqual(ws.run("--check")[0], 2)

    def test_missing_catalog(self):
        ws = Workspace(self)
        ws.catalog.unlink()
        code, out = ws.run("--check")
        self.assertEqual(code, 2, out)
        self.assertIn("missing", out)

    def test_modes_are_exclusive_and_required(self):
        with contextlib.redirect_stderr(io.StringIO()):
            with self.assertRaises(SystemExit) as ctx:
                cd.main([])
            self.assertEqual(ctx.exception.code, 2)
            with self.assertRaises(SystemExit) as ctx:
                cd.main(["--write", "--check"])
            self.assertEqual(ctx.exception.code, 2)


class RealCatalog(unittest.TestCase):
    def test_launch_matrix(self):
        matrix, _, _ = cd.generate(CATALOG.read_bytes())
        self.assertEqual(len(matrix["experiences"]), 100)
        self.assertEqual(len(matrix["rows"]), 4950)
        self.assertEqual(len({tuple(r[:2]) for r in matrix["rows"]}), 4950)
        self.assertEqual(matrix["summary"], {"pairs": 4950, "shared": 0, "max_score": 0.375})
        self.assertEqual(matrix["rows"][6][:3], ["A23", "A25", 0.375])

    def test_shipped_titles_file(self):
        titles = json.loads((REPO / "Configs" / "known-game-titles.json").read_text())
        self.assertEqual(titles["schema"], 1)
        self.assertGreaterEqual(len(titles["titles"]), 50)
        self.assertEqual(len({cd.normal_name(t) for t in titles["titles"]}), len(titles["titles"]))


if __name__ == "__main__":
    unittest.main()
