# Implementation Plan: R02-G09-04 — Nocturne Garden: gameplay spatial interaction

**Branch**: `384-nocturne-garden-gameplay-spatial-interaction` (spec directory only; work on `main`) | **Date**:
2026-11-22 | **Spec**: [spec.md](spec.md)

## Summary

Give Nocturne Garden its gestures, following Faceted Forge's R02-G08-04 in the same package: in the host-tested Core an
orbit (`NocturneGardenOrbit`, `camera(_:aspect:orbit:)`), an analytic picker (`NocturneGardenPicker`: the touch ray
against the lantern, the blooms' heads and feet and the bed plane, the 22-point minimum target, the bed cell under a
point, the lantern's elevation steps and the pinch's size), the drag preview (`NocturneGardenDragPreview`: the would-be
mask, match and leak computed with the kernel's own cells) and the gesture controller
(`NocturneGardenGestureController`: idle, bed press, bloom press, bloom drag, lantern drag, pinch, orbiting,
cancelled; plant, move, remove, resize, sun, choose and view reset); the snapshot gains the preview cells, drawn as a
pale dashed outline (a new material code in the garden program); in the experience the presenter's pointer entry, the
preview while dragging, and "Reset view" in the panel; host tests with an independent pick and step, a host test that
wins all 100 levels through panel actions, and simulator wiring tests. Research: [research.md](research.md). Data:
[data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Audit (2026-11-22)**: `Packages/ExperiencesRound02/Package.swift` already has `NocturneGardenCore` (with
VisualCoreScenes, VisualCoreMath, VisualCoreExperience), `NocturneGardenExperience` (iOS rendering dependencies) and
their test targets (R02-G09-03); `project.yml` links both products into the one app; no new target or scheme is needed.
**Language/Version**: Swift 6, GLSL ES 3.00. **Primary dependencies**: VisualCoreScenes (`PointerEvent`,
`PointerPhase`) and VisualCoreMath (`Vec2`, `Mat4`) as Faceted Forge's gesture controller uses them; the Nocturne
Garden Core of R02-G09-01 … 03; VisualCoreExperienceHost (pointer events) in the experience. No new package, target,
Objective-C++ or VisualCore API.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02`; simulator package tests on sim-27.2; the app
unit tests; regression; script tests alone. Seed 2_384.
**Constraints**: presentation-only orbit, picks and preview; tap distance 10 points, drag distance 16 points, minimum
target 22 points, tap duration 0.5 s and double tap 0.35 s by event timestamps; 48 points per sun step; yaw ±35°,
pitch 0° … 30°; tests under 10 s.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| II App-neutral API | PASS — game code stays in ExperiencesRound02; VisualCore API unchanged. |
| IV Host-testable | PASS — picking, preview and gestures in the Core with host tests; wiring tested on the simulator. |
| V Implementation before devices | PASS — touch feel and latency are `{device}` tasks. |
| VII Determinism | PASS — only event timestamps are read; actions are sent through the kernel's declared controls. |
| IX Bounded input | PASS — pointer events bounded by the view; orbit clamped; targets clamped; actions validated by the kernel. |
| XI One app | PASS — candidate experience only. |
| XIII Code-driven visuals | PASS — the preview outline is generated geometry with a shader material. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/NocturneGarden/Core/NocturneGardenSceneGeometry.swift      edit  orbit, camera(_:aspect:orbit:), preview outline (agent B)
Packages/ExperiencesRound02/NocturneGarden/Core/NocturneGardenSceneSnapshot.swift      edit  preview cells (lead)
Packages/ExperiencesRound02/NocturneGarden/Core/NocturneGardenShaders.swift            edit  preview material code 12 (lead)
Packages/ExperiencesRound02/NocturneGarden/Core/NocturneGardenPicker.swift             new   ray, lantern, blooms, bed cell, sun steps, pinch size (agent B)
Packages/ExperiencesRound02/NocturneGarden/Core/NocturneGardenDragPreview.swift        new   would-be mask, match and leak (agent C)
Packages/ExperiencesRound02/NocturneGarden/Core/NocturneGardenGestureController.swift  new   arbitration, taps, drags, pinch, lantern, double taps, orbit (agent C)
Packages/ExperiencesRound02/NocturneGarden/CoreTests/{NocturneGardenPickerTests (B), NocturneGardenGestureControllerTests (C), NocturneGardenPanelWinTests (D)}.swift  new
Packages/ExperiencesRound02/NocturneGarden/CoreTests/{NocturneGardenSceneGeometryTests, NocturneGardenShaderSourceTests}.swift  edit (B; lead)
Packages/ExperiencesRound02/NocturneGarden/Experience/{NocturneGardenPresenter, NocturneGardenGardenScene, NocturneGardenControls}.swift  edit (lead)
Packages/ExperiencesRound02/NocturneGarden/ExperienceTests/NocturneGardenGestureWiringTests.swift   new   (agent E)
docs/architecture/nocturne-garden.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md   edit (lead)
```

**Dependency graph**: snapshot preview field and shader code (lead) → orbit, picker and preview outline (B) and drag
preview (C) → gesture controller (C) → presenter wiring → wiring tests (E); the panel win test (D) needs only the
adapter. **CI checks**: the package host tests, the simulator package tests, app-unit, the reference regression and the
script tests, as for R02-G09-03. **Migration**: none (snapshot schema 1; orbit, picks and previews are not saved).
**Rollback**: revert the commits; the panel remains a complete control path.

## Parallel work

The lead adds the snapshot's preview field and the shader's preview material first; then agent B (orbit, picker,
preview outline), agent C (drag preview, then the gesture controller on B's picker) and agent D (panel win test) in
parallel; the lead wires the presenter, scene and controls; agent E writes the simulator wiring tests. The lead retests
every result.
