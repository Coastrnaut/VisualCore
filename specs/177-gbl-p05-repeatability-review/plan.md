# Implementation Plan: Graphics Benchmark Lab — Phase 05 Repeatability, thermal and methodology review

**Branch**: `177-gbl-p05-repeatability-review` (spec directory only; work on `main`) | **Date**: 2026-11-19 | **Spec**: [spec.md](spec.md)

## Summary

Every ended run is qualified (valid, qualified, invalid) from its state, report and summary; trials of a case are
compared for repeatability; "About these numbers" explains the limits; the first interface tests prove a run, saving,
opening, the explanation and a background interruption; a device plan lists the hardware checks. Gaps G-DEVICE and
G-EXPLAIN close.

Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contract:
[contracts/review.md](contracts/review.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

- **Language:** Swift 6, SwiftUI, Swift Testing, XCTest for the interface tests.
- **Dependencies:** the A24 core and experience; the app's UI test target.
- **Testing:** the A24 package tests on sim-27.2; the app build, unit tests and the new interface chunk `f3` on the iOS
  27.2 phone; the runner on iOS 27.2.
- **Constraints:** no VisualCore change; no device run; interface tests under 60 s; no ranking or invented number.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I–III | PASS: no rendering change |
| IV | PASS: qualification and repeatability pure and tested with fixtures |
| V | PASS: device checks planned and pending; simulator results are not device evidence |
| VI | PASS: no measured claim in copy; the explanation states the limits |
| VII | PASS: spoken headings, Dynamic Type text, no colour-only meaning |
| VIII–XIII | PASS |

A24 rules: truthful claims, provenance, comparability caveats. PASS. Post-design: PASS.

## Project Structure

```text
Packages/ExperiencesCreative/GraphicsBenchmarkLab/Core/{RunQualification,Repeatability}.swift   new
Packages/ExperiencesCreative/GraphicsBenchmarkLab/Core/RunCSV.swift                         modify  version 2: qualification rows
Packages/ExperiencesCreative/GraphicsBenchmarkLab/CoreTests/{RunQualificationTests,RepeatabilityTests}.swift new; RunCSVTests, golden-run.csv modify
Packages/ExperiencesCreative/GraphicsBenchmarkLab/Experience/{GBLExplanation,ExplanationView,RepeatabilityView}.swift new
Packages/ExperiencesCreative/GraphicsBenchmarkLab/Experience/{ResultsView,BenchPresenter,GBLControls}.swift   modify
Packages/ExperiencesCreative/GraphicsBenchmarkLab/ExperienceTests/{QualificationDisplayTests,ExplanationTests}.swift new
Apps/VisualCore/Tests/UI/GraphicsBenchmarkLab/{GBLSupport,GBLRunUITests}.swift              new
scripts/release_check.py                                                                     modify  chunk f3
docs/apps/graphics-benchmark-lab/device-campaign.md                                          new     GBL-D1…D6 × D1, D2, D3
docs/apps/graphics-benchmark-lab/visualcore-contract.json (G-DEVICE, G-EXPLAIN closed)       modify
```

- **Lifecycle:** none new; qualification is computed on display and export.
- **Migration:** CSV format version 2 (exports are not read back); no stored-data change. **Rollback:** revert.

## Parallel work

- **Agent C:** `RunQualification`, `Repeatability`, the CSV change and their tests.
- **Agent E (after C):** the explanation, the repeatability and qualification display and their tests.
- **Agent U:** `GBLSupport`, `GBLRunUITests` (lead adds chunk `f3`).
- **Agent D:** `device-campaign.md`.
- **Lead:** `release_check.py`, runs, contract, commits.
