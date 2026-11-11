# Implementation Plan: Generative Art Studio — Phase 02 Shader scenes and parameter controls

**Branch**: `013-gas-p02-scene-controls` | **Date**: 2026-11-10 | **Spec**: [spec.md](spec.md) | **Gate**: A01-P02

## Summary

This slice adds live, constrained parameter editing, preset, palette and seed selection, time control, and
recoverable loading of compositions. The reusable parts are built in VisualCore first (Principle II):

- `SceneClock` (VisualCoreSimulation), closing gap G-CLOCK;
- `ParameterEditor` (VisualCoreParameters);
- `ParameterPanel` (VisualCoreUI, which gains a dependency on the pure VisualCoreParameters).

The app adds three pieces:
- `CompositionEditor` (Core): the current composition, notes, and classification of opened data;
- a clocked scene wrapper;
- the controls UI.

## Technical Context

**Language/Version**: Swift 6.4.2 · **Primary Dependencies**: VisualCore packages only · **Storage**: none (Phase 03) ·
**Testing**:
- host `swift test` for SceneClock, ParameterEditor and CompositionEditor;
- simulator package tests for ParameterPanel accessibility;
- hosted app pixel tests (parameter change, reset, scrub determinism) and UI tests on iOS 27.2 and 26.5;
- the ProjectM regression; API, documented-API and contract checks.

**Target Platform**: iOS/iPadOS 26.0+ · **Performance Goals**: none claimed. Control changes only update uniforms; a
change of seed or palette for the particles family rebuilds the replay cursor, which is bounded by 7,200 steps ·
**Constraints**: offline, no permissions, launch composition data only in DEBUG (≤ 64 KiB) · **Scale/Scope**: 3
VisualCore types, 1 domain type, 1 scene wrapper, 2 views.

## Constitution Check

| Principle | Status |
|---|---|
| I Proven renderer | PASS: uniforms only, one host per screen |
| II Maximize reuse | PASS: clock, editor and panel live in VisualCore |
| II-a Reference | PASS: regression after the VisualCore changes |
| III Lifecycle | PASS: the clock is CPU state; scenes rebuild from the composition |
| IV Host-testable | PASS |
| V Simulator only | PASS |
| VI Evidence | PASS |
| VII Accessible UI | PASS: adjustable sliders with values and units, labelled controls, Dynamic Type |
| VIII Privacy | PASS |
| IX Bounded input | PASS: launch data size-capped, validated, DEBUG-only; slider positions clamped |
| X Licensing | PASS: no new assets |
| A01 rules | PASS |

## Project Structure

```text
Packages/VisualCore/Sources/VisualCoreSimulation/SceneClock.swift            (+ tests in VisualCoreSimulationTests)
Packages/VisualCore/Sources/VisualCoreParameters/ParameterEditor.swift       (+ tests in VisualCoreParametersTests)
Packages/VisualCoreRendering/Sources/VisualCoreUI/ParameterPanel.swift       (+ VisualCoreUITests/ParameterPanelTests.swift)
Packages/VisualCoreRendering/Package.swift                                   # VisualCoreUI → VisualCoreParameters
specs/002-architecture-contracts/contracts/package-map.md                    # VisualCoreUI row: + Parameters
Apps/GenerativeArtStudio/Core/Sources/GenerativeArtStudioCore/CompositionEditor.swift (+ tests)
Apps/GenerativeArtStudio/App/{SceneScreen,ClockedArtScene,ControlsSheet,LaunchComposition}.swift; ArtSceneFactory.swift (apply updates)
Apps/GenerativeArtStudio/Tests/Unit/ControlsRenderTests.swift; Tests/UI/{ControlsUITests,RecoveryUITests}.swift
project.yml                                                                  # app + VisualCoreParameters already linked; no change expected
docs/apps/generative-art-studio/visualcore-contract.json                    # G-CLOCK closed; M02/M10 updated
```

**Dependency direction**:
- App → GenerativeArtStudioCore → VisualCoreParameters and VisualCoreSimulation.
- App → VisualCoreUI → VisualCoreParameters and VisualCoreRendering.
- No cycles (rule R3). VisualCoreParameters stays Foundation-only.

**Lifecycle contract**:
1. `SceneModel` owns one `RenderHost`, one `SceneClock` and the `CompositionEditor`.
2. The host renders a `ClockedArtScene`, which on each frame advances the clock by `frame.delta` and sets the
   inner ArtScene's `fixedTime = clock.time`.
3. Editor changes are pushed with `ArtSceneFactory.apply(composition, to: scene)`: uniforms, palette and seed
   offsets for shader families; a new replay cursor for particles.
4. On disappear, the model calls `host.destroy()`. Context loss rebuilds from the current composition and keeps the
   clock time.

**Data**: no new persistent schema. Compositions keep `ArtDocument` v1.

**Migration and rollback**:
- The VisualCore additions are additive.
- `ParameterPanel` is new; VisualCoreUI gains one dependency.
- Rollback means reverting the phase commits; nothing is persisted.

## Complexity Tracking

None.
