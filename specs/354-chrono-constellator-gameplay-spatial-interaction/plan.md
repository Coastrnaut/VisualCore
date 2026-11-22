# Implementation Plan: R02-G06-04 — Chrono Constellator: gameplay spatial interaction

**Branch**: `354-chrono-constellator-gameplay-spatial-interaction` (spec directory only; work on `main`) | **Date**:
2026-11-21 | **Spec**: [spec.md](spec.md)

## Summary

Give Chrono Constellator its gestures, following Colorfall Canyons's R02-G05-04 in the same package: in the host-tested
Core an orbit (`ChronoConstellatorOrbit`, `camera(_:aspect:orbit:)`), an analytic picker (`ChronoConstellatorPicker`:
the touch ray against the star node spheres and the field plane, loop cells and the timeline band, the 22-point minimum
target) and the gesture controller (`ChronoConstellatorGestureController`: idle, star drag, scrub, press, orbiting,
cancelled; a phase change per star drag, a step or rewind-and-step per scrub, a hold toggle per long press, star
selection on a tap, double-tap reset); in the experience the presenter's pointer entry, a pearl outline of the
candidate cell, the scrub preview and "Reset view" in the panel; host tests with an independent pick, a host test that
wins all 100 levels through panel actions, and simulator wiring tests. Research: [research.md](research.md). Data:
[data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Audit (2026-11-21)**: `Packages/ExperiencesRound02/Package.swift` already has `ChronoConstellatorCore` (with
VisualCoreScenes, VisualCoreMath, VisualCoreExperience), `ChronoConstellatorExperience` (iOS rendering dependencies) and
their test targets; `project.yml` links both products into the one app; no new target or scheme is needed.
**Language/Version**: Swift 6. **Primary dependencies**: VisualCoreScenes (`PointerEvent`, `PointerPhase`,
`PointerTracker`) and VisualCoreMath (`Vec2`, `Mat4`) as Colorfall Canyons's gesture controller uses them; the Chrono
Constellator Core of R02-G06-01 … 03; VisualCoreExperienceHost (pointer events) in the experience. No new package,
target, GLSL, Objective-C++ or VisualCore API.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02`; simulator package tests on sim-27.2; the app
unit tests; regression; script tests alone. Seed 2_354.
**Constraints**: presentation-only orbit; tap distance 10 points, drag distance 16 points, minimum target 22 points,
long press 0.5 s by event timestamps, double tap 0.35 s; at most two actions per gesture (rewind then step); tests under
10 s.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| II App-neutral API | PASS — game code stays in ExperiencesRound02; VisualCore API unchanged. |
| IV Host-testable | PASS — picking and gestures in the Core with host tests; wiring tested on the simulator. |
| V Implementation before devices | PASS — touch feel and latency are `{device}` tasks. |
| VII Determinism | PASS — only event timestamps are read; scrubs end in the plain replay's digest. |
| IX Bounded input | PASS — pointer events bounded by the view; orbit clamped; actions validated by the kernel. |
| XI One app | PASS — candidate experience only. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/ChronoConstellator/Core/ChronoConstellatorSceneGeometry.swift            edit  orbit, camera(_:aspect:orbit:), candidate ring part (agent B)
Packages/ExperiencesRound02/ChronoConstellator/Core/ChronoConstellatorPicker.swift                    new   touch ray, star spheres, field plane, timeline band, minimum target (agent B)
Packages/ExperiencesRound02/ChronoConstellator/Core/ChronoConstellatorGestureController.swift         new   arbitration, star drag, scrub, press, taps, orbit, reset (agent C)
Packages/ExperiencesRound02/ChronoConstellator/CoreTests/{ChronoConstellatorPickerTests (B), ChronoConstellatorGestureControllerTests (C), ChronoConstellatorPanelWinTests (D)}.swift  new
Packages/ExperiencesRound02/ChronoConstellator/CoreTests/ChronoConstellatorSceneGeometryTests.swift   edit  orbit framing (agent B)
Packages/ExperiencesRound02/ChronoConstellator/Experience/{ChronoConstellatorPresenter, ChronoConstellatorSkyScene, ChronoConstellatorControls}.swift  edit (lead)
Packages/ExperiencesRound02/ChronoConstellator/ExperienceTests/ChronoConstellatorGestureWiringTests.swift   new   (agent E)
docs/architecture/chrono-constellator.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md   edit (lead)
```

**Dependency graph**: orbit and picker → gesture controller → presenter wiring → wiring tests; the panel win test needs
only the adapter. **CI checks**: the package host tests, the simulator package tests, app-unit, the reference
regression and the script tests, as for R02-G06-03. **Migration**: none (snapshot schema 1; the orbit is not saved).
**Rollback**: revert the commits; the panel remains a complete control path.

## Parallel work

Agent B (orbit and picker) first, then agents C (gesture controller) and D (panel win test) in parallel; the lead wires the
presenter, scene and controls; agent E writes the simulator wiring tests. The lead retests every result.
