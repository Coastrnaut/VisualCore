# Implementation Plan: Simulation Lab — Phase 04 Experiment UI, presets and capture

**Branch**: `120-sl-p04-ui-presets-capture` (spec directory only; work on `main`) | **Date**: 2026-11-16 | **Spec**: [spec.md](spec.md)

## Summary

Build G-UI, G-LEGEND, G-PRESETS and G-CAPTURE with no VisualCore change:
- **Core (pure, `SimulationLabCore`)**:
  - `SimulationBrush`: `SimulationModel.paint(x:y:mode:)` per clarification Q1.
  - `SimulationHistogram`: 16 bins, the display range, the non-finite count.
  - `ExperimentPreset`: schema 1, with validation.
  - `BundledPresets`: the six presets, with source and license.
- **Adapter (`SimulationCore`)**: the actions `sim.paint [x, y, mode]` and `sim.spec [family, a, b, Δt]`. Both are
  recorded and digested like every action, and the manifest is regenerated.
- **Experience**:
  - `SimulationPresetStore`: `ExperienceStorage` files `preset-<uuid>.json`, cap 24, problems for damaged, newer or
    refused files.
  - `SimulationCapture`: `TemporaryFolder("a16-captures")`, the host's still renderer at 1024 × 1024 and
    `StillImageEncoder`; one file, replaced.
  - In the presenter:
    - pointer mapping to cells (`pointer`, `gestureActions = ["sim.paint"]`);
    - the motion caps (`reduceMotion`, `reduceFlashing`, `a16.reduced-motion`);
    - the histogram gate (once every 15 frames while running, at the next frame after a non-step change);
    - the inspector and approximation words.
  - In the controls: the inspector section, the approximation label, the Seed row, the Presets section (bundled and
    saved, with save and delete), and Capture with a ShareLink.
  - The legend overlay draws the 16 histogram bars.
  - The factory passes `storage` and `reduceFlashing`.
- **Tests**: brush per family and its control alternative; one paused step = one CPU iteration through the controls,
  per family; histogram counts and update gate; preset round trip, cap, damaged, newer and refused files; bundled
  presets valid with an allowed license; capture writes one PNG, replaces it, fails cleanly and leaves the state
  unchanged; motion caps; the CPU reference fixtures (A16-P01) still asserted.

Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contract: [contracts/ui.md](contracts/ui.md).
Quickstart: [quickstart.md](quickstart.md).

## Technical Context

- **Language:** Swift 6, SwiftUI.
- **Dependencies** (verified at clarify and plan):
  - host: `ExperiencePresenter.pointer(_:viewSize:port:)`, `gestureActions`, `cancelPointers()`, `PointerEvent`,
    `makeCanvasOverlay(_:)`, `@Environment(\.experienceStillRenderer)` and `ExperienceSession.renderStill(width:height:)`;
  - persistence and storage: `ExperienceStorage` (`write(_:to:)`, `read`, `list()`, `remove`, quota 64 files),
    `MigrationChain` and `TemporaryFolder` (`makeFileURL`, `removeAll`, `fileCount`);
  - rendering: `StillImageEncoder.pngData`;
  - the A16-P01 to P03 code.
- **Storage:** the preset files in the experience's storage; no change to the state schema (the field already holds
  painted cells).
- **Testing:** core host tests (`swift test` of the package's core target through the package scheme on the simulator);
  experience tests on iOS 27.2; app build and unit; runner; packages; contract; documented API; script tests.
- **Performance:** a paint action touches at most 21 cells; the histogram is one pass over 4,096 cells, at most 4
  times a second; a capture is one off-screen render.
- **Constraints:** tests under 10 s; iOS 27 only; no prompt. No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I One renderer | PASS: the capture renders on the host's context |
| II Reuse | PASS: the host's pointer, overlay and still renderer, `ExperienceStorage`, `TemporaryFolder` and the encoder |
| III Determinism | PASS: paint and spec are actions in the digest; the histogram and the caps read state only |
| IV Pure core | PASS: brush, histogram and preset schema are GPU-free and UI-free |
| V Persistence | PASS: versioned preset files, refusal of damaged and newer files, quota-bounded |
| VI Tests | PASS: one test file per gap |
| VII Accessibility | PASS: control alternative, spoken state, approximation label, motion caps |
| VIII Privacy | PASS: no permission, no usage string, no network; files stay in the app's storage and temporary folder |
| IX Performance | PASS: bounded per-frame work |
| X–XIII | PASS |

The A16 rules pass: truthful labels (the approximation label), no silent 8-bit run (unchanged), the presets carry
source and license. Post-design: PASS.

## Project Structure

```text
Packages/ExperiencesCreative/SimulationLab/Core/{SimulationBrush,SimulationHistogram,ExperimentPreset}.swift        new
Packages/ExperiencesCreative/SimulationLab/Core/SimulationModel.swift                                               modify (paint, respec)
Packages/ExperiencesCreative/SimulationLab/CoreTests/{SimulationBrushTests,SimulationHistogramTests,
  ExperimentPresetTests}.swift                                                                                       new
Packages/ExperiencesCreative/SimulationLab/Experience/{SimulationPresetStore,SimulationCapture}.swift               new
Packages/ExperiencesCreative/SimulationLab/Experience/Adapter/SimulationCore.swift                                  modify (sim.paint, sim.spec)
Packages/ExperiencesCreative/SimulationLab/Experience/{SimulationPresenter,SimulationControls,SimulationLegend,
  SimulationLabExperience}.swift                                                                                     modify
Packages/ExperiencesCreative/SimulationLab/scenario-manifest.json                                                   regenerate
Packages/ExperiencesCreative/SimulationLab/ExperienceTests/{PaintTests,StepExactTests,HistogramGateTests,
  PresetStoreTests,CaptureTests,MotionCapTests}.swift                                                                new
docs/apps/simulation-lab/visualcore-contract.json (G-UI, G-LEGEND, G-PRESETS, G-CAPTURE closed)                     modify
```

**Dependency direction:** unchanged. Core ← adapter ← experience; the experience depends on the host and
VisualCoreRendering.

**Lifecycle:**
- The capture folder is emptied when the experience opens. The preset store reads its files when the controls
  first appear and after every save or delete.
- Pointer drags keep the last painted cell per pointer id; `cancelPointers` forgets them.
- The motion caps apply in `send`, and on activation and family changes through the wrapper.

**Migration:** preset schema 1 is new; the state schema is unchanged. **Rollback:** revert the commits. Saved preset
files are left in storage and are ignored by older code (it does not list them).

## Parallel work

- **Agent A:** core brush, histogram and preset schema, with their core tests.
- **Agent B:** `SimulationPresetStore` and `SimulationCapture`, with their tests.
- **Lead:** adapter actions, presenter, controls, legend, factory, manifest, contract, runs and commits.
