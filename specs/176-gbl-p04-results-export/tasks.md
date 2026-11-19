# Tasks: Graphics Benchmark Lab — Phase 04 Results persistence/export

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/results.md](contracts/results.md), [quickstart.md](quickstart.md). Gate A24-P04 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A24-P04 --timeout 595 --name <check> -- <command>`.
- **Commits:** one after every task, with no trailers.
- **Checks:** read every check's exit before ticking, never in the same command.
- **Scope:** iOS 27 only; no VisualCore change.
- **Precedent:** `specs/169-vpl-p04-library-diagnostics/tasks.md`.
- **Rollback:** revert the commits.

## Phase 1: Setup

- [X] T-A24-401 Baseline: cite the A24-P03 evidence (`.autonomy/checks/A24-P03.{gbl-ios27,app-unit,verify-27}.json`) on — Verified 2026-11-19: 2026-11-19: .autonomy/checks/A24-P03.{gbl-ios27,app-unit,verify-27}.json exit 0 at A24-P03; Packages unchanged since fbaad7d9
  the tree recorded at A24-P03 (`fbaad7d9`), whose Packages are unchanged since (owner ruling of 2026-11-14)

## Phase 2: Story 1 — settings stored with the run (P1) 🎯

- [X] T-A24-402 [US1] Run file version 3 in `Core/BenchmarkRun.swift` per clarification Q1 (FR-A24-401): the whole case — Verified 2026-11-19: 2026-11-19: .autonomy/checks/A24-P04.gbl-core.json exit 0 (79 core and 42 experience tests); run file version 3 stores the whole case with its fingerprint recomputed on read; 2 to 3 from the built-in case; tampered setting damaged; version 4 newer
  in the body's `case`, the fingerprint recomputed on read ("a mismatch is `damaged`"), migration 2 → 3 from the
  built-in case of the same id and version; `CoreTests/RunDocumentTests.swift`: version 3 round-trips byte-identically
  with every setting; a version 2 file of a built-in case opens with its settings; a tampered setting is `damaged`;
  version 4 is refused as newer

## Phase 3: Story 3 — the exports (P1)

- [X] T-A24-403 [P] [US3] `Core/RunCSV.swift` per clarification Q4 (FR-A24-404) and `CoreTests/RunCSVTests.swift` with — Verified 2026-11-19: 2026-11-19: .autonomy/checks/A24-P04.gbl-core.json exit 0 (79 core and 42 experience tests); RunCSV (two parts, CRLF, RFC 4180) and RunCSVTests match golden-run.json and golden-run.csv byte for byte; .gitattributes keeps the CSV's CRLF
  committed golden files `CoreTests/Fixtures/golden-run.json` and `golden-run.csv` of a fixture run (with a GPU time
  on some samples and none on others, a report and a quote and comma in a field): the JSON is the run file, the CSV
  matches byte for byte (CRLF, RFC 4180), an absent value is empty, never 0

## Phase 4: Story 2 — the library (P1)

- [X] T-A24-404 [US2] `Experience/ResultLibrary.swift` per clarification Q2 (FR-A24-402, 403): `result-<n>.json` and — Verified 2026-11-19: 2026-11-19: .autonomy/checks/A24-P04.gbl-ios27.json exit 0 (79 core and 53 experience tests); ResultLibrary (result-<n>.json and results.json, at most 12 results of 2,162,688 bytes, refusal codes, read-only newer index, messages)
  `results.json`, "at most 12 results", files of "at most 2,162,688 bytes", refusal codes, a newer index read only, a
  damaged index rebuilt only by the next change, the two messages, newest first by order
- [X] T-A24-405 [US2] `ExperienceTests/ResultLibraryTests.swift` (SC-A24-401, 402): save and open in a new session — Verified 2026-11-19: 2026-11-19: .autonomy/checks/A24-P04.gbl-ios27.json exit 0 (79 core and 53 experience tests); ResultLibraryTests (round trip, cap, unreadable files kept, full storage, remove, repeated save, unknown case version)
  give equal runs; the 13th save is refused and nothing is removed; damaged, truncated, newer, oversized and
  non-finite files are listed with their reason and stay byte-identical; a full storage refuses with the message;
  remove deletes only the chosen file; a repeated save of the same run is refused; a saved result of a case version the app does not
  build in (for example `quads` version 9 with its own settings) opens and shows its stored settings

## Phase 5: The interface and export action (P1)

- [X] T-A24-406 [US1] [US2] [US3] `Experience/{ResultExportFile,ResultsView}.swift` and the `BenchPresenter` and — Verified 2026-11-19: 2026-11-19: .autonomy/checks/A24-P04.gbl-ios27.json exit 0 (79 core and 53 experience tests); ResultExportFile, ResultExporter (on tap only, temporary folder emptied at teardown), ResultsView (inline list, opened result with settings and report), save after a run ends
  `GBLControls` changes (FR-A24-404, 405; contracts/results.md identifiers): `result-save` after a run ends, the results
  sheet with rows, open (summary and report shown), remove, `result-export-json` and `result-export-csv` writing to
  `TemporaryFolder(name: "GraphicsBenchmarkLab-Export")` only on the tap, then `result-share` (a `ShareLink` of a
  `ResultExportFile`); the folder emptied at session close; native controls with spoken labels, no system menu
- [X] T-A24-407 [US3] `ExperienceTests/ExportTests.swift` (SC-A24-403, 404): no export file exists before the action; — Verified 2026-11-19: 2026-11-19: .autonomy/checks/A24-P04.gbl-ios27.json exit 0 (79 core and 53 experience tests); ExportTests (no file before the tap, bytes equal the encoders, content types, folder emptied at close)
  the tap writes the JSON or CSV equal to `RunDocument.encode` or `RunCSV.text`; the share item's content type matches;
  closing the session empties the folder

## Phase 6: Evidence

- [X] T-A24-408 Review checkpoint: `--name gbl-ios27` (both A24 test targets on sim-27.2, each test under 10 s), the — Verified 2026-11-19: 2026-11-19: review checkpoint: .autonomy/checks/A24-P04.{gbl-ios27,documented-api,isolation,core-purity,scan-identifiers}.json exit 0
  documented API, isolation, core purity and `--name scan-identifiers`
- [X] T-A24-409 Contract: G-RESULTS and G-EXPORT closed by "A24-P04", rows whose gaps are all closed available — Verified 2026-11-19: 2026-11-19: G-RESULTS and G-EXPORT closed by A24-P04, M10, M20 and M21 available; .autonomy/checks/A24-P04.contract.json exit 0; README updated
  (`--name contract`); the experience README updated
- [X] T-A24-410 The catalog, packages, script tests, app and runner: `--name catalog`, `experience-packages`, — Verified 2026-11-19: 2026-11-19: .autonomy/checks/A24-P04.{catalog,experience-packages,script-tests,app-unit,verify-27}.json exit 0 (runner 9 of 9 on iOS 27.2)
  `script-tests`; `xcodegen generate --spec project.yml`, then `--name app-unit`; `--name verify-27`
- [ ] T-A24-411 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record
  A24-P04; update README.md (rule 16) and `docs/automatedtesting.md` (rule 17)

## Dependencies

401 → 402 → {403, 404}; 404 → 405; {403, 405} → 406 → 407 → 408 → 409 → 410 → 411.

## Parallel examples

- **Agent C:** 402, 403. **Agent E (after 402):** 404–407.
- **Lead:** 401, runs, contract, commits.

## Implementation strategy

- **MVP:** 402, 404. **Review checkpoint:** at 408. **Commits:** one per task.
