# Implementation Plan: Visual Programming Lab — Phase 04 Save/load, examples and diagnostics

**Branch**: `169-vpl-p04-library-diagnostics` (spec directory only; work on `main`) | **Date**: 2026-11-18 | **Spec**: [spec.md](spec.md)

## Summary

This phase closes G-LIBRARY:
- **Core (pure):** `GraphDiagnostics` (checker issues mapped to nodes with their sentences).
- **Experience:** `GraphLibrary` (named graph files and index over `ExperienceStorage`), `LabExamples` (three graphs in
  code), presenter wiring (save, open by restore, rename, remove, examples), overlay marks and list-form sentences,
  the library view.
- **Records:** `docs/apps/visual-programming-lab/licenses.md`; a committed schema-1 sample.

Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contract:
[contracts/library.md](contracts/library.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

- **Language:** Swift 6, SwiftUI.
- **Dependencies:** unchanged products; the experience uses `ExperienceStorage`, `StorageError`, `StorageQuota`,
  `MigrationChain` and `ExperienceShell.restore(_:)` besides the A23-P03 set (verified in this phase's clarification).
- **Testing:** both A23 test targets on sim-27.2; the app build and unit tests; the runner on iOS 27.
- **Constraints:** no network; no automatic deletion; atomic writes; each test under 10 s.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I | PASS: no new drawing path; the preview compiles an opened graph at the next frame |
| II | PASS: reuses `ExperienceStorage`, `MigrationChain`, the shell's restore; the library is app-local (NamedLibrary works on a raw directory) |
| IV | PASS: diagnostics mapping is pure and tested without the GPU; the library is tested with a temporary storage |
| VII–VIII | PASS: offline; nothing leaves the device; no permission |
| IX | PASS: marks not by colour alone (dashed outline and badge), spoken sentences |
| XIII | PASS: examples written here, recorded in licenses.md |
| A23 (2.19.0) | PASS: versioned files through the migration chain; damaged and newer files kept |

Post-design: PASS.

## Project Structure

```text
Packages/ExperiencesCreative/VisualProgrammingLab/Core/GraphDiagnostics.swift                    new
Packages/ExperiencesCreative/VisualProgrammingLab/CoreTests/DiagnosticsTests.swift               new
Packages/ExperiencesCreative/VisualProgrammingLab/Experience/{GraphLibrary,LabExamples,LabLibraryView}.swift   new
Packages/ExperiencesCreative/VisualProgrammingLab/Experience/{LabPresenter,CanvasOverlay,LabControls,VisualProgrammingLabExperience}.swift  modify
Packages/ExperiencesCreative/VisualProgrammingLab/ExperienceTests/{LibraryTests,LibraryRefusalTests,MigrationTests,
  ExampleTests,DiagnosticsDisplayTests,StoredSampleTests}.swift                                    new
Packages/ExperiencesCreative/VisualProgrammingLab/ExperienceTests/Fixtures/graph-sample.json      new  (target resources)
Packages/ExperiencesCreative/Package.swift (ExperienceTests resources: Fixtures)                    modify (lead)
docs/apps/visual-programming-lab/licenses.md; README.md; visualcore-contract.json (G-LIBRARY closed)   new / modify
```

- **Dependency direction:** app → experience → core → VisualCore.
- **Lifecycle:** the library reads storage on demand; writes only on save, rename and remove; opening restores the
  core and the preview compiles at the next draw.
- **Migration:** graph file schema 1 through `MigrationChain`; library schema 1. **Rollback:** revert the commits;
  stored files remain readable by schema 1.

## Parallel work

- **Agent D:** `GraphDiagnostics` and its tests (core); the overlay marks and list-form sentences, with
  `DiagnosticsDisplayTests`.
- **Agent B:** `GraphLibrary`, `LabExamples`, `LabLibraryView`, presenter and factory wiring, and the library,
  refusal, migration, example and stored-sample tests.
- **Lead:** Package.swift resources, licenses.md, README, the contract, runs, commits.
