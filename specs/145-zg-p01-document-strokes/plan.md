# Implementation Plan: Digital Zen Garden — Phase 01 Document and stroke math with fixtures

**Branch**: `145-zg-p01-document-strokes` (spec directory only; work on `main`) | **Date**: 2026-11-17 | **Spec**: [spec.md](spec.md)

## Summary

This phase builds Digital Zen Garden's pure core and closes three gaps:
- **G-DOCUMENT:** the garden document (tray, sand tone, stones, strokes) with its envelope, caps and refusals, and the
  stone palette.
- **G-STROKES:** stroke resampling to uniform spacing with a cap, and the two rake styles with their footprints.
- **G-UNDO:** commands, exact undo and redo, a bounded history with a checkpoint.

A reference sand field rebuilt from the commands without the GPU proves the manual's regression rule: undo and redo
give an identical command list and the same sand. Nothing is drawn, no experience is registered, and VisualCore and
ProjectM are unchanged.

Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contract:
[contracts/core.md](contracts/core.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

- **Language:** Swift 6 (strict concurrency), Foundation only in the core.
- **Dependencies:** `DigitalZenGardenCore` → `VisualCoreMath` (`Vec2`) and `VisualCoreExperience`;
  `DigitalZenGardenCoreTests` → the core and `VisualCoreMath`.
- **Storage:** none in this phase; the document is pure `Data` in and out.
- **Testing:** `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme
  ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing DigitalZenGardenCoreTests`.
- **Performance:** each test under 10 s; the reference field is 160 × 120 cells, and a replay of 100 strokes of 512
  points stamps at most 51,200 footprints.
- **Constraints:** no GL call, UIKit or SwiftUI in the core; no clock; no VisualCore change, so no API baseline update
  and no reference regression; iOS 27 only. No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I | PASS: no renderer, no GL call; context ownership stays in the host |
| II | PASS: reuses `Vec2`; the garden rules, rakes and undo stay app-local (contract clarification Q4) |
| II-a | PASS: no VisualCore change, regression not required |
| IV | PASS: pure, versioned models tested without a GPU |
| VI | PASS: evidence by run-check |
| VIII | PASS: no permission, no network |
| XIII | PASS: rakes, stones and tones written here, recorded in `licenses.md` |

A20 rules (constitution 2.16.0): PASS.
- testable without the GPU: normalized tray coordinates, the field rebuilt from the command log, undo by command;
- bounded: caps on points, strokes, stones and file size; refusals for damaged, newer and out-of-range files.

Post-design: PASS.

## Project Structure

```text
Packages/ExperiencesCreative/Package.swift                                                    modify  two targets
Packages/ExperiencesCreative/DigitalZenGarden/Core/GardenPalette.swift                         new     tray, sand tones, rake styles, stone kinds
Packages/ExperiencesCreative/DigitalZenGarden/Core/GardenDocument.swift                        new     document, stroke, stone, envelope, refusals
Packages/ExperiencesCreative/DigitalZenGarden/Core/StrokeResampler.swift                       new     uniform spacing, cap, clamping
Packages/ExperiencesCreative/DigitalZenGarden/Core/RakeBrush.swift                             new     groove profile, footprint stamp
Packages/ExperiencesCreative/DigitalZenGarden/Core/SandField.swift                             new     reference field, replay
Packages/ExperiencesCreative/DigitalZenGarden/Core/GardenHistory.swift                         new     commands, undo, redo, checkpoint
Packages/ExperiencesCreative/DigitalZenGarden/CoreTests/{PaletteTests,DocumentTests,ResamplerTests,RakeTests,HistoryTests,ReplayFixtureTests}.swift   new
docs/apps/digital-zen-garden/licenses.md                                                       new     rakes, stones, tones written here
docs/apps/digital-zen-garden/visualcore-contract.json                                          modify  G-DOCUMENT, G-STROKES, G-UNDO closed
```

- **Dependency direction:** core → VisualCore products, never the reverse. The experience target (A20-P02) will
  depend on the core.
- **Lifecycle:** none in this phase; the core holds values only.
- **Migration:** document schema 1, the first version. **Rollback:** revert the commits; no stored data exists yet.

## Parallel work

- **Agent G:** `GardenPalette`, `GardenDocument` and their tests.
- **Agent S:** `StrokeResampler`, `RakeBrush`, `SandField` and their tests.
- **Agent H:** `GardenHistory`, its tests and the replay fixture (after G and S hand over).
- **Agent D:** `licenses.md`.
- **Lead:** Package.swift, the contract, the runs and the commits.
