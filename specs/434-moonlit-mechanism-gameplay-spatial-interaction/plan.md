# Implementation Plan: R02-G14-04 — Moonlit Mechanism: gameplay spatial interaction

**Branch**: `434-moonlit-mechanism-gameplay-spatial-interaction` (spec directory only; work on `main`) | **Date**:
2026-11-24 | **Spec**: [spec.md](spec.md)

## Summary

Add Moonlit Mechanism's gestures on the pattern of Acoustic Constellator's (feature 424): a constrained orbit and an
orbiting camera (`MoonlitMechanismOrbit`, `camera(_:aspect:orbit:)`); an analytic picker (`MoonlitMechanismPicker`:
the lamp and ladder, the key-frame cards and the gear discs projected through the drawn camera, in that order); a
host-tested gesture controller (`MoonlitMechanismGestureController`: rotary gear drags that turn the train in whole
teeth, vertical lamp drags that step the lamp 24 points per rung, gear taps that choose, double taps that re-seat, card
taps that show a key frame, lamp taps that run, empty double taps that reset the view, two-finger orbit, cancellation,
no kernel action on a finished play); the presenter's pointer entry, the pending-turn and pending-lamp texts and "Reset
view"; and tests: 500 seeded gestures against an independent pick, all 100 certified levels won through panel actions,
and simulator wiring tests. Research: [research.md](research.md). Data: [data-model.md](data-model.md). API:
[contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Audit (2026-11-24)**: `Packages/ExperiencesRound02/Package.swift` already has `MoonlitMechanismCore` (with
VisualCoreScenes, VisualCoreMath, VisualCoreExperience since R02-G14-03 T-002), `MoonlitMechanismExperience` and their
test targets; `project.yml` links both products into the one app; no new target or scheme is needed.
`MoonlitMechanismSceneGeometry` has `camera(_:aspect:)`, `project(_:camera:)`, `gearCentre`, `rimRadius`, `card`,
`cardWidth`, `lampCentre`, `turnSense` and the ladder constants; the adapter declares the eight controls.
**Language/Version**: Swift 6. **Primary dependencies**: VisualCoreScenes (`PointerEvent`, `PointerPhase`) and
VisualCoreMath (`Vec2`); the Moonlit Mechanism Core of R02-G14-01 … 03; VisualCoreExperienceHost (pointer events) in
the experience. No new package, target, Objective-C++ or VisualCore API, and no shader change: the pending turn and
lamp steps are shown in words, not drawn.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02`; simulator package tests on sim-27.2; the app
unit tests; regression; script tests alone. Seed 2_434.
**Constraints**: presentation-only orbit, chosen gear and pending gestures; tap distance 10 points, drag distance 16
points, touch target 22 points, gear target radius 3.75 s + 8 points, centre dead zone 12 points, 24 points per lamp
rung, tap duration 0.5 s, double tap 0.35 s by event timestamps; yaw ±25°, pitch −10° … +15°; tests under 10 s.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| II App-neutral API | PASS — game code stays in ExperiencesRound02; VisualCore API unchanged. |
| IV Host-testable | PASS — picking and gestures in the Core with host tests; wiring tested on the simulator. |
| V Implementation before devices | PASS — touch feel and latency are `{device}` tasks. |
| VII Determinism | PASS — only event timestamps are read; actions are sent through the kernel's declared controls. |
| IX Bounded input | PASS — pointer events bounded by the view; orbit clamped; turns capped at the actions left; actions validated by the kernel. |
| XI One app | PASS — candidate experience only. |
| XIII Code-driven visuals | PASS — no new visual asset; the camera only orbits. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/MoonlitMechanism/Core/MoonlitMechanismSceneGeometry.swift       edit  orbit, camera(_:aspect:orbit:) (agent B)
Packages/ExperiencesRound02/MoonlitMechanism/Core/MoonlitMechanismPicker.swift              new   projection, lamp, ladder, cards, gears, swept angle (agent B)
Packages/ExperiencesRound02/MoonlitMechanism/Core/MoonlitMechanismGestureController.swift   new   arbitration, taps, double taps, gear and lamp drags, orbit (agent C)
Packages/ExperiencesRound02/MoonlitMechanism/CoreTests/{MoonlitMechanismPickerTests (B), MoonlitMechanismGestureControllerTests (C), MoonlitMechanismPanelWinTests (D)}.swift  new
Packages/ExperiencesRound02/MoonlitMechanism/CoreTests/MoonlitMechanismSceneGeometryTests.swift  edit (B)
Packages/ExperiencesRound02/MoonlitMechanism/Experience/{MoonlitMechanismPresenter, MoonlitMechanismClockworkScene, MoonlitMechanismControls}.swift  edit (lead)
Packages/ExperiencesRound02/MoonlitMechanism/ExperienceTests/MoonlitMechanismGestureWiringTests.swift   new   (agent E)
docs/architecture/moonlit-mechanism.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md   edit (lead)
```

**Dependency graph**: orbit and picker (B) → gesture controller (C) → presenter wiring (lead) → wiring tests (E); the
panel win test (D) needs only the adapter. **CI checks**: the package host tests, the simulator package tests, app-unit,
the reference regression and the script tests, as for R02-G14-03. **Migration**: none (snapshot schema 1; orbit, chosen
gear and pending gestures are not saved). **Rollback**: revert the commits; the panel remains a complete control path.

## Parallel work

Agents B (orbit, camera, picker) and D (panel win test) start at once; agent C writes the gesture controller on B's
picker contract (fixed in [contracts/api.md](contracts/api.md) before either starts); the lead wires the presenter,
scene and controls; agent E writes the simulator wiring tests with the presenter's status texts given in its brief. The
lead retests every result.
