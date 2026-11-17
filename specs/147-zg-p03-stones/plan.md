# Implementation Plan: Digital Zen Garden — Phase 03 Stone manipulation and undo

**Branch**: `147-zg-p03-stones` (spec directory only; work on `main`) | **Date**: 2026-11-17 | **Spec**: [spec.md](spec.md)

## Summary

This phase closes three gaps:
- **G-STONES:** the five stone kinds drawn as procedural superellipse domes from a pure `StoneShape`, placed, moved,
  rotated and removed through the existing commands.
- **G-SELECTION:** topmost-in-depth selection by touch, cycling by native controls, an outline and a spoken label.
- **G-SHADOWS:** a soft shadow of each stone on the sand in the relief pass.

The regression fixture proves that a portrait and a landscape view give the same document and tray positions.
VisualCore and ProjectM are unchanged; the experience stays a candidate.

Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contract:
[contracts/stones.md](contracts/stones.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

- **Language:** Swift 6, SwiftUI, GLSL ES 3.00 inside the experience.
- **Dependencies:** unchanged (A20-P02); `RotateRecognizer` from VisualCoreScenes for the two-finger turn.
- **Testing:** the A20 package tests on sim-27.2; the app build and unit tests; the runner on iOS 27.
- **Performance:** at most 24 stones of at most 0.16 × 2 tray widths each are rasterized into 480 × 360 cells per
  stone change (bounded arithmetic: at most 24 × 154 × 154 cell visits); each test under 10 s.
- **Constraints:** iOS 27 only; no VisualCore change. No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I | PASS: one pass through the host's context; a second target bound like the first |
| II | PASS: reuses `GardenHistory`, `RotateRecognizer`, `RenderTarget.upload(rgbaFloats:)`, the GLSL library |
| IV | PASS: `StoneShape` and selection are pure and tested without the GPU |
| IX | PASS: native alternatives for every stone gesture; outline and spoken label, not colour alone |

A20 rules (constitution 2.16.0): PASS: visuals are code, bounded caps, calm by default.

Post-design: PASS.

## Project Structure

```text
Packages/ExperiencesCreative/DigitalZenGarden/Core/StoneShape.swift                        new     superellipse, wobble, contains, height
Packages/ExperiencesCreative/DigitalZenGarden/Core/StoneLayer.swift                        new     rasterized layer in depth order
Packages/ExperiencesCreative/DigitalZenGarden/Core/StoneSelection.swift                    new     topmost hit, cycle
Packages/ExperiencesCreative/DigitalZenGarden/CoreTests/{StoneShapeTests,StoneLayerTests,SelectionTests}.swift   new
Packages/ExperiencesCreative/DigitalZenGarden/Experience/Adapter/GardenCore.swift           modify  stone actions, tool mode, selection
Packages/ExperiencesCreative/DigitalZenGarden/Experience/SandScene.swift                    modify  stone target, stone shading, shadow
Packages/ExperiencesCreative/DigitalZenGarden/Experience/GardenPresenter.swift              modify  stone gestures
Packages/ExperiencesCreative/DigitalZenGarden/Experience/{GardenControls,BrushPreview}.swift modify  stone controls, selection outline
Packages/ExperiencesCreative/DigitalZenGarden/Experience/Adapter/GardenManifest.swift       modify  stone fixtures
Packages/ExperiencesCreative/DigitalZenGarden/ExperienceTests/{StoneActionTests,StoneRenderTests,OrientationTests}.swift   new
Packages/ExperiencesCreative/DigitalZenGarden/scenario-manifest.json                        regenerated
docs/apps/digital-zen-garden/{visualcore-contract.json,licenses.md}                         modify  gaps closed; stone shading row
```

- **Lifecycle:** the stone target is created in setup with the sand target, rebuilt with it, released in teardown.
- **Migration:** none; snapshot schema 1 already holds the stones. **Rollback:** revert the commits.

## Parallel work

- **Agent C:** the core files and their tests.
- **Agent E:** the experience changes and tests (after C hands over).
- **Lead:** manifest regeneration, contract, runs, commits.
