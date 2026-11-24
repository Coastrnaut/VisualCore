# Implementation Plan: R02-G13-04 — Acoustic Constellator: gameplay spatial interaction

**Branch**: `424-acoustic-constellator-gameplay-spatial-interaction` (spec directory only; work on `main`) | **Date**:
2026-11-23 | **Spec**: [spec.md](spec.md)

## Summary

Add Acoustic Constellator's gestures on the pattern of Harmonic Bridges' (feature 414): a constrained orbit and an
orbiting camera (`AcousticConstellatorOrbit`, `camera(_:aspect:orbit:)`); an analytic picker
(`AcousticConstellatorPicker`: coherence bars and hold pips, star centres and link splines projected through the drawn
camera, each with a 22-point target, in that order); a host-tested gesture controller
(`AcousticConstellatorGestureController`: star taps that nudge, link taps that choose a pair, gauge taps that listen,
drags from a star that preview a filament and link or unlink on release, double taps that reset the view, two-finger
orbit, cancellation, nothing sent on a finished play); the presenter's pointer entry, the drag filament and "Reset
view"; and tests: 500 seeded gestures against an independent pick, all 100 certified levels won through panel actions,
and simulator wiring tests. Research: [research.md](research.md). Data: [data-model.md](data-model.md). API:
[contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Audit (2026-11-23)**: `Packages/ExperiencesRound02/Package.swift` already has `AcousticConstellatorCore` (with
VisualCoreScenes, VisualCoreMath, VisualCoreExperience), `AcousticConstellatorExperience` (iOS rendering dependencies)
and their test targets (R02-G13-03); `project.yml` links both products into the one app; no new target or scheme is
needed. `AcousticConstellatorSceneGeometry` has `camera(_:aspect:)`, `project(_:camera:)`, `starCentre`,
`splinePoint(_:_:u:)`, `coherenceBar` and `holdPip`.
**Language/Version**: Swift 6. **Primary dependencies**: VisualCoreScenes (`PointerEvent`, `PointerPhase`) and
VisualCoreMath (`Vec2`) as Harmonic Bridges' gesture controller uses them; the Acoustic Constellator Core of
R02-G13-01 … 03; VisualCoreExperienceHost (pointer events) in the experience. No new package, target, Objective-C++ or
VisualCore API. The drag filament is drawn from the geometry as one extra strip (constellation material `teal`), no
shader change.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02`; simulator package tests on sim-27.2; the app
unit tests; regression; script tests alone. Seed 2_424.
**Constraints**: presentation-only orbit, chosen pair and drag preview; tap distance 10 points, drag distance 16 points,
minimum target 22 points, tap duration 0.5 s, double tap 0.35 s by event timestamps; yaw ±35°, pitch −15° … +20°;
tests under 10 s.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| II App-neutral API | PASS — game code stays in ExperiencesRound02; VisualCore API unchanged. |
| IV Host-testable | PASS — picking and gestures in the Core with host tests; wiring tested on the simulator. |
| V Implementation before devices | PASS — touch feel and latency are `{device}` tasks. |
| VII Determinism | PASS — only event timestamps are read; actions are sent through the kernel's declared controls. |
| IX Bounded input | PASS — pointer events bounded by the view; orbit clamped; actions validated by the kernel. |
| XI One app | PASS — candidate experience only. |
| XIII Code-driven visuals | PASS — no new visual asset; the camera only orbits and the filament is generated. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/AcousticConstellator/Core/AcousticConstellatorSceneGeometry.swift       edit  orbit, camera(_:aspect:orbit:), drag filament (agent B)
Packages/ExperiencesRound02/AcousticConstellator/Core/AcousticConstellatorPicker.swift              new   projection, gauges, stars, links (agent B)
Packages/ExperiencesRound02/AcousticConstellator/Core/AcousticConstellatorGestureController.swift   new   arbitration, taps, link drags, double taps, orbit (agent C)
Packages/ExperiencesRound02/AcousticConstellator/CoreTests/{AcousticConstellatorPickerTests (B), AcousticConstellatorGestureControllerTests (C), AcousticConstellatorPanelWinTests (D)}.swift  new
Packages/ExperiencesRound02/AcousticConstellator/CoreTests/AcousticConstellatorSceneGeometryTests.swift  edit (B)
Packages/ExperiencesRound02/AcousticConstellator/Experience/{AcousticConstellatorPresenter, AcousticConstellatorConstellationScene, AcousticConstellatorControls}.swift  edit (lead)
Packages/ExperiencesRound02/AcousticConstellator/ExperienceTests/AcousticConstellatorGestureWiringTests.swift   new   (agent E)
docs/architecture/acoustic-constellator.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md   edit (lead)
```

**Dependency graph**: orbit and picker (B) → gesture controller (C) → presenter wiring (lead) → wiring tests (E); the
panel win test (D) needs only the adapter. **CI checks**: the package host tests, the simulator package tests, app-unit,
the reference regression and the script tests, as for R02-G13-03. **Migration**: none (snapshot schema 1; orbit, chosen
pair and drag preview are not saved). **Rollback**: revert the commits; the panel remains a complete control path.

## Parallel work

Agents B (orbit, camera, picker, filament) and D (panel win test) start at once; agent C writes the gesture controller
on B's picker contract (fixed in [contracts/api.md](contracts/api.md) before either starts); the lead wires the
presenter, scene and controls; agent E writes the simulator wiring tests with the presenter's status texts given in its
brief (lesson of R02-G13-03). The lead retests every result.
