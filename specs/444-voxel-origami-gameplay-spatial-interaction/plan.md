# Implementation Plan: R02-G15-04 — Voxel Origami: gameplay spatial interaction

**Branch**: `444-voxel-origami-gameplay-spatial-interaction` (spec directory only; work on `main`) | **Date**:
2026-11-24 | **Spec**: [spec.md](spec.md)

## Summary

Add Voxel Origami's gestures on the pattern of Moonlit Mechanism's (feature 434): a constrained orbit and an orbiting
camera (`VoxelOrigamiOrbit`, `camera(_:aspect:orbit:)`, the meshes built for the drawn eye); an analytic picker
(`VoxelOrigamiPicker`: each cube's eight corners projected through the drawn camera, the convex outline grown by
8 points, the front-most first); a host-tested gesture controller (`VoxelOrigamiGestureController`: drags on a cube that
turn its hinge by the step whose predicted on-screen motion of the swinging cubes best matches the finger, one quarter
turn per drag from 24 points; taps that choose a hinge; double taps that turn it +1; empty double taps that reset the
view; two-finger orbit; cancellation; no kernel action on a finished play); the presenter's pointer entry, the pending
text and "Reset view"; and tests: 500 seeded gestures against an independent pick and prediction, all 100 certified
levels won through panel actions, and simulator wiring tests. Research: [research.md](research.md). Data:
[data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Audit (2026-11-24)**: `Packages/ExperiencesRound02/Package.swift` already has `VoxelOrigamiCore` (with
VisualCoreScenes, VisualCoreMath, VisualCoreExperience since R02-G15-03 T-002), `VoxelOrigamiExperience` and their test
targets; `project.yml` links both products into the one app; no new target or scheme is needed.
`VoxelOrigamiSceneGeometry` has `camera(_:aspect:)`, `project(_:camera:)`, `cubeCentre`, `world`, `scale`,
`paintOrder`, `cubeSide`, `voxelMesh`/`glowMesh` (built for the authored camera); `VoxelOrigamiLattice` has `pose`,
`swinging` and `turned`; the adapter declares the five controls.
**Language/Version**: Swift 6. **Primary dependencies**: VisualCoreScenes (`PointerEvent`, `PointerPhase`) and
VisualCoreMath (`Vec2`); the Voxel Origami Core of R02-G15-01 … 03; VisualCoreExperienceHost (pointer events) in the
experience. No new package, target, Objective-C++ or VisualCore API and no shader change: the pending turn is shown in
words.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02`; simulator package tests on sim-27.2; the app
unit tests; regression; script tests alone. Seed 2_444.
**Constraints**: presentation-only orbit, chosen hinge and pending gestures; tap distance 10 points, drag distance 16
points, cube allowance 8 points, turn threshold 24 points, tap duration 0.5 s, double tap 0.35 s and 22 points by event
timestamps; yaw ±60°, pitch −20° … +35°; tests under 10 s.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| II App-neutral API | PASS — game code stays in ExperiencesRound02; VisualCore API unchanged. |
| IV Host-testable | PASS — picking, prediction and gestures in the Core with host tests; wiring tested on the simulator. |
| V Implementation before devices | PASS — touch feel and latency are `{device}` tasks. |
| VII Determinism | PASS — only event timestamps are read; actions are sent through the kernel's declared controls. |
| IX Bounded input | PASS — pointer events bounded by the view; orbit clamped; one turn per drag; actions validated by the kernel. |
| XI One app | PASS — candidate experience only. |
| XIII Code-driven visuals | PASS — no new visual asset; the camera only orbits. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/VoxelOrigami/Core/VoxelOrigamiSceneGeometry.swift       edit  orbit, camera(_:aspect:orbit:), meshes for the drawn camera (agent B)
Packages/ExperiencesRound02/VoxelOrigami/Core/VoxelOrigamiPicker.swift              new   projection, cube outlines, front-most pick, turn prediction (agent B)
Packages/ExperiencesRound02/VoxelOrigami/Core/VoxelOrigamiGestureController.swift   new   arbitration, taps, double taps, cube drags, orbit (agent C)
Packages/ExperiencesRound02/VoxelOrigami/CoreTests/{VoxelOrigamiPickerTests (B), VoxelOrigamiGestureControllerTests (C), VoxelOrigamiPanelWinTests (D)}.swift  new
Packages/ExperiencesRound02/VoxelOrigami/CoreTests/VoxelOrigamiSceneGeometryTests.swift  edit (B)
Packages/ExperiencesRound02/VoxelOrigami/Experience/{VoxelOrigamiPresenter, VoxelOrigamiVoxelScene, VoxelOrigamiControls}.swift  edit (lead)
Packages/ExperiencesRound02/VoxelOrigami/ExperienceTests/VoxelOrigamiGestureWiringTests.swift   new   (agent E)
docs/architecture/voxel-origami.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md   edit (lead)
```

**Dependency graph**: orbit and picker (B) → gesture controller (C) → presenter wiring (lead) → wiring tests (E); the
panel win test (D) needs only the adapter. **CI checks**: the package host tests, the simulator package tests, app-unit,
the reference regression and the script tests, as for R02-G15-03. **Migration**: none (snapshot schema 1; orbit, chosen
hinge and pending gestures are not saved). **Rollback**: revert the commits; the panel remains a complete control path.

## Parallel work

Agents B (orbit, camera, picker, prediction) and D (panel win test) start at once; agent C writes the gesture controller
on B's picker contract (fixed in [contracts/api.md](contracts/api.md) before either starts); the lead wires the
presenter, scene and controls; agent E writes the simulator wiring tests with the presenter's status texts given in its
brief. The lead retests every result.
