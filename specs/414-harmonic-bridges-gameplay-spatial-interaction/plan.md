# Implementation Plan: R02-G12-04 — Harmonic Bridges: gameplay spatial interaction

**Branch**: `414-harmonic-bridges-gameplay-spatial-interaction` (spec directory only; work on `main`) | **Date**:
2026-11-23 | **Spec**: [spec.md](spec.md)

## Summary

Add Harmonic Bridges' gestures on the pattern of Echo Cartographer's (feature 404): a constrained orbit and an orbiting
camera (`HarmonicBridgesOrbit`, `camera(_:aspect:orbit:)`); an analytic picker (`HarmonicBridgesPicker`: step pips,
the goal island's top centre and the string segments projected through the drawn camera, each with a 22-point target, in
that order); a host-tested gesture controller (`HarmonicBridgesGestureController`: taps that choose a string or test the
crossing, drags that preview and tune a peg, double taps that reset the view, two-finger orbit, cancellation, nothing
sent on a finished play); the presenter's pointer entry and "Reset view"; and tests: 500 seeded gestures against an
independent pick, all 100 certified levels won through panel actions, and simulator wiring tests. Research:
[research.md](research.md). Data: [data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md). Quickstart:
[quickstart.md](quickstart.md).

## Technical Context

**Audit (2026-11-23)**: `Packages/ExperiencesRound02/Package.swift` already has `HarmonicBridgesCore` (with
VisualCoreScenes, VisualCoreMath, VisualCoreExperience), `HarmonicBridgesExperience` (iOS rendering dependencies) and
their test targets (R02-G12-03); `project.yml` links both products into the one app; no new target or scheme is needed.
`HarmonicBridgesSceneGeometry` has `camera(_:aspect:)`, `project(_:camera:)`, `islandTop`, `stringEnds` and `stepPip`.
**Language/Version**: Swift 6. **Primary dependencies**: VisualCoreScenes (`PointerEvent`, `PointerPhase`) and
VisualCoreMath (`Vec2`) as Echo Cartographer's gesture controller uses them; the Harmonic Bridges Core of
R02-G12-01 … 03; VisualCoreExperienceHost (pointer events) in the experience. No new package, target, Objective-C++ or
VisualCore API; no shader change.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02`; simulator package tests on sim-27.2; the app
unit tests; regression; script tests alone. Seed 2_414.
**Constraints**: presentation-only orbit, chosen string and previewed peg; tap distance 10 points, drag distance 16
points, minimum target 22 points, tap duration 0.5 s, double tap 0.35 s by event timestamps; 24 points of upward
movement per peg, rounded half away from zero, clamped 1 … 12; yaw ±35°, pitch −15° … +20°; tests under 10 s.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| II App-neutral API | PASS — game code stays in ExperiencesRound02; VisualCore API unchanged. |
| IV Host-testable | PASS — picking and gestures in the Core with host tests; wiring tested on the simulator. |
| V Implementation before devices | PASS — touch feel and latency are `{device}` tasks. |
| VII Determinism | PASS — only event timestamps are read; actions are sent through the kernel's declared controls. |
| IX Bounded input | PASS — pointer events bounded by the view; orbit and peg clamped; actions validated by the kernel. |
| XI One app | PASS — candidate experience only. |
| XIII Code-driven visuals | PASS — no new visual asset; the camera only orbits. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/HarmonicBridges/Core/HarmonicBridgesSceneGeometry.swift        edit  orbit, camera(_:aspect:orbit:) (agent B)
Packages/ExperiencesRound02/HarmonicBridges/Core/HarmonicBridgesPicker.swift               new   projection, pips, goal, strings (agent B)
Packages/ExperiencesRound02/HarmonicBridges/Core/HarmonicBridgesGestureController.swift    new   arbitration, taps, peg drags, double taps, orbit (agent C)
Packages/ExperiencesRound02/HarmonicBridges/CoreTests/{HarmonicBridgesPickerTests (B), HarmonicBridgesGestureControllerTests (C), HarmonicBridgesPanelWinTests (D)}.swift  new
Packages/ExperiencesRound02/HarmonicBridges/CoreTests/HarmonicBridgesSceneGeometryTests.swift  edit (B)
Packages/ExperiencesRound02/HarmonicBridges/Experience/{HarmonicBridgesPresenter, HarmonicBridgesBridgeScene, HarmonicBridgesControls}.swift  edit (lead)
Packages/ExperiencesRound02/HarmonicBridges/ExperienceTests/HarmonicBridgesGestureWiringTests.swift   new   (agent E)
docs/architecture/harmonic-bridges.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md   edit (lead)
```

**Dependency graph**: orbit and picker (B) → gesture controller (C) → presenter wiring (lead) → wiring tests (E); the
panel win test (D) needs only the adapter. **CI checks**: the package host tests, the simulator package tests, app-unit,
the reference regression and the script tests, as for R02-G12-03. **Migration**: none (snapshot schema 1; orbit, chosen
string and previewed peg are not saved). **Rollback**: revert the commits; the panel remains a complete control path.

## Parallel work

Agents B (orbit, camera, picker) and D (panel win test) start at once; agent C writes the gesture controller on B's
picker contract (fixed in [contracts/api.md](contracts/api.md) before either starts); the lead wires the presenter,
scene and controls; agent E writes the simulator wiring tests. The lead retests every result.
