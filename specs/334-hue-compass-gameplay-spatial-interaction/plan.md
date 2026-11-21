# Implementation Plan: R02-G04-04 — Hue Compass: gameplay spatial interaction

**Branch**: `334-hue-compass-gameplay-spatial-interaction` (spec directory only; work on `main`) | **Date**: 2026-11-21 |
**Spec**: [spec.md](spec.md)

## Summary

Give Hue Compass its touch controls on Wave Knot Keeper's feature-324 pattern: an orbit for the camera
(`HueCompassOrbit`, `HueCompassSceneGeometry.camera(aspect:orbit:)`), a pure swipe-and-hub reader (`HueCompassDial`:
projected centre, accumulated angle, preview steps, hub hit), and a host-tested `HueCompassGestureController` (idle,
swiping, orbiting, cancelled; at most one action per gesture); the presenter routes pointer events, draws a ghost needle
at the preview and keeps the orbit; the panel gains "Reset view". Research: [research.md](research.md). Data:
[data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6. **Primary dependencies**: VisualCoreScenes (`PointerEvent`) and VisualCoreMath (
`Vec2` as Wave Knot Keeper's gesture controller uses them), the Hue Compass Core of R02-G04-01 … 03,
VisualCoreExperienceHost (pointer events) in the experience. No new package, target or VisualCore API.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02`; simulator package tests on sim-27.2; the app
unit tests; regression; script tests alone. Seed 2_334.
**Constraints**: presentation-only orbit; one `compass.turn` or `compass.probe` per gesture at most; tap distance 10
points; hub at least 30 points; tests under 10 s.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| II App-neutral API | PASS — game code stays in ExperiencesRound02; VisualCore API unchanged. |
| IV Host-testable | PASS — gesture logic in the Core with host tests; wiring tested on the simulator. |
| V Implementation before devices | PASS — touch feel and latency are `{device}` tasks. |
| IX Bounded input | PASS — pointer events bounded by the view; turns wrapped into −47 … 48; orbit clamped. |
| XI One app | PASS — candidate experience only. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/HueCompass/Core/HueCompassSceneGeometry.swift            edit  orbit, camera(aspect:orbit:) (agent B)
Packages/ExperiencesRound02/HueCompass/Core/HueCompassDial.swift                      new   centre, angles, preview steps, hub (agent B)
Packages/ExperiencesRound02/HueCompass/Core/HueCompassGestureController.swift        new   arbitration, swipes, taps, orbit (agent C)
Packages/ExperiencesRound02/HueCompass/CoreTests/{HueCompassDialTests (B), HueCompassGestureControllerTests (C), HueCompassPanelWinTests (D)}.swift  new
Packages/ExperiencesRound02/HueCompass/CoreTests/HueCompassSceneGeometryTests.swift  edit  orbit framing (agent B)
Packages/ExperiencesRound02/HueCompass/Experience/{HueCompassPresenter, HueCompassCompassScene, HueCompassControls}.swift  edit (lead)
Packages/ExperiencesRound02/HueCompass/ExperienceTests/HueCompassGestureWiringTests.swift   new   (agent E)
docs/architecture/hue-compass.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md   edit (lead)
```

**Migration**: none. **Rollback**: revert the commits; the panel remains a complete control path.

## Parallel work

Agent B (orbit and dial) first, then agents C (gesture controller) and D (panel win test) in parallel; the lead wires the
presenter, scene and controls; agent E writes the simulator wiring tests. The lead retests every result.
