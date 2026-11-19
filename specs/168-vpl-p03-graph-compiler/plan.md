# Implementation Plan: Visual Programming Lab — Phase 03 Bounded graph compiler and preview

**Branch**: `168-vpl-p03-graph-compiler` (spec directory only; work on `main`) | **Date**: 2026-11-18 | **Spec**: [spec.md](spec.md)

## Summary

This phase draws the graph's picture and closes G-COMPILE, G-OPERATORS and G-BUDGET:
- **Core (pure):** `GraphCompiler` (accepted graph → `PassSchedule` of passes with operators, inputs by slot, values
  and output slots; slot reuse by lifetime; the 6-slot budget; content keys and `changed(from:to:)`) and
  `PreviewValues` (Time and Constant resolved per frame).
- **Experience:** `Operators` (the seven fragment programs as text), `PreviewPipeline` (programs, slots and passes in
  the host's context; compile at the next draw; `PreviewState`), presenter and overlay changes (the bottom-left inset,
  its frame and message, the preview switch).

Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contract:
[contracts/preview.md](contracts/preview.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

- **Language:** Swift 6, SwiftUI, GLSL ES 3.00 (operator texts).
- **Dependencies:** unchanged products; the experience uses `FieldPass`, `FieldUniform`, `RenderTarget`,
  `ResourceRegistry.makeRenderTarget`, `TextureFormat`, `ShaderBundle.visualCoreIncludes` (all verified in this phase's
  clarification) besides the A23-P02 set.
- **Testing:** `VisualProgrammingLabCoreTests` and `VisualProgrammingLabExperienceTests` on sim-27.2; the app build and
  unit tests; the runner on iOS 27.
- **Constraints:** no GL call outside VisualCore; at most one compile per frame; 256 × 256 rgba8 slots, at most 6;
  30 frames per second; each test under 10 s.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I | PASS: every pass runs through `FieldPass` inside the presenter's calls; no GL call of the experience |
| II | PASS: reuses `FieldPass`, render targets, the budget and the `vc/` library; operators are app-local text (the VisualCore blur is internal) |
| III | PASS: compile at the next draw on the main actor; never from a control |
| IV | PASS: schedule, slots, budget, keys and values tested without the GPU |
| VI | PASS: pixel references on the simulator; no device claim |
| A23 (2.19.0) | PASS: validate before GPU work; static budget before allocation; bounded blur; no feedback nodes |

Post-design: PASS.

## Project Structure

```text
Packages/ExperiencesCreative/VisualProgrammingLab/Core/{GraphCompiler,PreviewValues}.swift              new
Packages/ExperiencesCreative/VisualProgrammingLab/CoreTests/{CompilerTests,SlotTests,ContentKeyTests,PreviewValuesTests}.swift new
Packages/ExperiencesCreative/VisualProgrammingLab/Experience/{Operators,PreviewPipeline}.swift          new
Packages/ExperiencesCreative/VisualProgrammingLab/Experience/{LabPresenter,CanvasOverlay,LabControls}.swift  modify (inset, state, switch)
Packages/ExperiencesCreative/VisualProgrammingLab/ExperienceTests/{OperatorPixelTests,PreviewStateTests,BudgetTests,
  CompileQueueTests,PreviewRebuildTests}.swift                                                     new
Packages/ExperiencesCreative/VisualProgrammingLab/Experience/Adapter/LabManifest.swift; scenario-manifest.json  modify if a fixture changes
docs/apps/visual-programming-lab/visualcore-contract.json (G-COMPILE, G-OPERATORS, G-BUDGET closed)        modify
```

- **Dependency direction:** app → experience → core → VisualCore.
- **Lifecycle:**
  - `setup`: the grid, then the pipeline from the current schedule (programs and slots);
  - `draw`: compile if the fingerprint changed (once), then the grid, the passes and the inset;
  - `resize`: the grid and the inset position (slots stay 256 × 256);
  - `teardown`: release every pass and slot; a context rebuild runs `setup` again.
- **Migration:** none (no stored data changes). **Rollback:** revert the commits.

## Parallel work

- **Agent K:** `GraphCompiler`, `PreviewValues` and their tests (core).
- **Agent P:** `Operators`, `PreviewPipeline`, the presenter/overlay/controls changes and the experience tests,
  against [data-model.md](data-model.md) and [contracts/preview.md](contracts/preview.md).
- **Lead:** the contract, runs and commits.
