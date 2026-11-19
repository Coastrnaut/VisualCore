# Implementation Plan: Graphics Benchmark Lab — Phase 04 Results persistence/export

**Branch**: `176-gbl-p04-results-export` (spec directory only; work on `main`) | **Date**: 2026-11-19 | **Spec**: [spec.md](spec.md)

## Summary

The run file stores the case's full settings (version 3); finished runs are saved in a result library in the
experience's storage and listed, opened and removed; an opened result exports as JSON or CSV through the share sheet
only on the person's action. Gaps G-RESULTS and G-EXPORT close.

Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contract:
[contracts/results.md](contracts/results.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

- **Language:** Swift 6, SwiftUI for the list and export controls, Swift Testing.
- **Dependencies:** the A24 core; VisualCoreExperience (`ExperienceStorage`), VisualCorePersistence
  (`MigrationChain`, `TemporaryFolder`); CoreTransferable and UniformTypeIdentifiers for the share item.
- **Testing:** the A24 package tests on sim-27.2 with golden JSON and CSV files; the app build and unit tests; the
  runner on iOS 27.2.
- **Constraints:** no graphics in saving or exporting; no VisualCore change; no automatic export.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I–III | PASS: no rendering change; saving and exporting issue no GL call |
| IV | PASS: CSV writer, run file version 3 and library rules pure or storage-only, tested |
| VI | PASS: golden files; no measured claim |
| VIII | PASS: export only on the person's action; no network |
| IX | PASS: versioned files, migrations, unreadable files kept |
| XI–XIII | PASS |

A24 rules: provenance kept with every result; refusal of damaged, newer and non-finite files. PASS. Post-design: PASS.

## Project Structure

```text
Packages/ExperiencesCreative/GraphicsBenchmarkLab/Core/BenchmarkRun.swift            modify  version 3: full case, migration 2 → 3
Packages/ExperiencesCreative/GraphicsBenchmarkLab/Core/RunCSV.swift                  new     the CSV writer
Packages/ExperiencesCreative/GraphicsBenchmarkLab/CoreTests/{RunCSVTests}.swift; RunDocumentTests modify; Fixtures/golden-run.{json,csv} new
Packages/ExperiencesCreative/GraphicsBenchmarkLab/Experience/{ResultLibrary,ResultExportFile,ResultsView}.swift  new
Packages/ExperiencesCreative/GraphicsBenchmarkLab/Experience/{BenchPresenter,GBLControls}.swift                   modify  save, open, export
Packages/ExperiencesCreative/GraphicsBenchmarkLab/ExperienceTests/{ResultLibraryTests,ExportTests}.swift          new
docs/apps/graphics-benchmark-lab/visualcore-contract.json (G-RESULTS, G-EXPORT closed)  modify
```

- **Dependency direction:** experience → core → VisualCore pure products.
- **Lifecycle:** the library reads on open of the results sheet and writes on save or remove; export files live in a
  temporary folder emptied at session close.
- **Migration:** run file 2 → 3; library files version 1. **Rollback:** revert the commits.

## Parallel work

- **Agent C:** run file version 3, `RunCSV`, golden files and their tests.
- **Agent E:** `ResultLibrary`, `ResultExportFile`, `ResultsView`, the presenter and controls changes and their tests.
- **Lead:** runs, contract, commits.
