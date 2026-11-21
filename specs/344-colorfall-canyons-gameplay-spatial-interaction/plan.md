# Implementation Plan: R02-G05-04 — Colorfall Canyons: gameplay spatial interaction

**Branch**: `344-colorfall-canyons-gameplay-spatial-interaction` (spec directory only; work on `main`) | **Date**:
2026-11-21 | **Spec**: [spec.md](spec.md)

## Summary

Give Colorfall Canyons its gestures, following Hue Compass's R02-G04-04 in the same package: in the host-tested Core an
orbit (`ColorfallCanyonsOrbit`, `camera(_:aspect:orbit:)`), an analytic picker (`ColorfallCanyonsPicker`: the touch ray
against block tops and emitter columns, the 22-point minimum target) and the gesture controller
(`ColorfallCanyonsGestureController`: idle, dragging, orbiting, cancelled; one carve or valve per gesture; double-tap
reset); in the experience the presenter's pointer entry, a pearl outline of the picked cell, "Reset view" in the panel;
host tests with an independent pick, a host test that wins all 100 levels through panel actions, and simulator wiring
tests. Research: [research.md](research.md). Data: [data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md).
Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6. **Primary dependencies**: VisualCoreScenes (`PointerEvent`, `PointerPhase`) and
VisualCoreMath (`Vec2`, `Mat4`) as Hue Compass's gesture controller uses them; the Colorfall Canyons Core of
R02-G05-01 … 03; VisualCoreExperienceHost (pointer events) in the experience. No new package, target, GLSL or VisualCore
API; no Objective-C++.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02`; simulator package tests on sim-27.2; the app
unit tests; regression; script tests alone. Seed 2_344.
**Constraints**: presentation-only orbit; at most one `canyon.carve` or `canyon.valve` per gesture; tap distance 10
points, drag distance 16 points, minimum target 22 points; tests under 10 s.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| II App-neutral API | PASS — game code stays in ExperiencesRound02; VisualCore API unchanged. |
| IV Host-testable | PASS — picking and gestures in the Core with host tests; wiring tested on the simulator. |
| V Implementation before devices | PASS — touch feel and latency are `{device}` tasks. |
| IX Bounded input | PASS — pointer events bounded by the view; orbit clamped; actions validated by the kernel. |
| XI One app | PASS — candidate experience only. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/ColorfallCanyons/Core/ColorfallCanyonsSceneGeometry.swift            edit  orbit, camera(_:aspect:orbit:) (agent B)
Packages/ExperiencesRound02/ColorfallCanyons/Core/ColorfallCanyonsPicker.swift                    new   touch ray, block-top and emitter hits, minimum target (agent B)
Packages/ExperiencesRound02/ColorfallCanyons/Core/ColorfallCanyonsGestureController.swift         new   arbitration, drags, taps, orbit, reset (agent C)
Packages/ExperiencesRound02/ColorfallCanyons/CoreTests/{ColorfallCanyonsPickerTests (B), ColorfallCanyonsGestureControllerTests (C), ColorfallCanyonsPanelWinTests (D)}.swift  new
Packages/ExperiencesRound02/ColorfallCanyons/CoreTests/ColorfallCanyonsSceneGeometryTests.swift   edit  orbit framing (agent B)
Packages/ExperiencesRound02/ColorfallCanyons/Experience/{ColorfallCanyonsPresenter, ColorfallCanyonsCanyonScene, ColorfallCanyonsControls}.swift  edit (lead)
Packages/ExperiencesRound02/ColorfallCanyons/ExperienceTests/ColorfallCanyonsGestureWiringTests.swift   new   (agent E)
docs/architecture/colorfall-canyons.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md   edit (lead)
```

**Migration**: none. **Rollback**: revert the commits; the panel remains a complete control path.

## Parallel work

Agent B (orbit and picker) first, then agents C (gesture controller) and D (panel win test) in parallel; the lead wires the
presenter, scene and controls; agent E writes the simulator wiring tests. The lead retests every result.
