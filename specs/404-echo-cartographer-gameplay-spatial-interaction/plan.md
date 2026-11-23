# Implementation Plan: R02-G11-04 — Echo Cartographer: gameplay spatial interaction

**Branch**: `404-echo-cartographer-gameplay-spatial-interaction` (spec directory only; work on `main`) | **Date**:
2026-11-23 | **Spec**: [spec.md](spec.md)

## Summary

Add Echo Cartographer's gestures on the pattern of Backwards Aurora's (feature 394): a constrained orbit and an orbiting
camera (`EchoCartographerOrbit`, `camera(_:aspect:orbit:)`); an analytic picker (`EchoCartographerPicker`: the touch
ray against the floor plane y = 0, markers within 22 points first, then the cell under the point); a host-tested gesture
controller (`EchoCartographerGestureController`: taps that pulse from known-open cells or move the cursor, drags that
place or move markers, held presses that claim, double taps that reset the view, two-finger orbit, cancellation, nothing
on a finished play); the presenter's pointer entry and "Reset view"; and tests: 500 seeded gestures against an
independent pick, all 100 certified levels won through panel actions, and simulator wiring tests. Research:
[research.md](research.md). Data: [data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md). Quickstart:
[quickstart.md](quickstart.md).

## Technical Context

**Audit (2026-11-23)**: `Packages/ExperiencesRound02/Package.swift` already has `EchoCartographerCore` (with
VisualCoreScenes, VisualCoreMath, VisualCoreExperience), `EchoCartographerExperience` (iOS rendering dependencies) and
their test targets (R02-G11-03); `project.yml` links both products into the one app; no new target or scheme is needed.
**Language/Version**: Swift 6. **Primary dependencies**: VisualCoreScenes (`PointerEvent`, `PointerPhase`) and
VisualCoreMath (`Vec2`, `Mat4`) as Backwards Aurora's gesture controller uses them; the Echo Cartographer Core of
R02-G11-01 … 03; VisualCoreExperienceHost (pointer events) in the experience. No new package, target, Objective-C++ or
VisualCore API; no shader change.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02`; simulator package tests on sim-27.2; the app
unit tests; regression; script tests alone. Seed 2_404.
**Constraints**: presentation-only orbit and cursor; tap distance 10 points, drag distance 16 points, minimum marker
target 22 points, tap duration 0.5 s, hold 0.5 s and double tap 0.35 s by event timestamps; yaw ±35°, pitch −15° …
+20°; tests under 10 s.

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
| XIII Code-driven visuals | PASS — no new visual asset; the camera only orbits. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/EchoCartographer/Core/EchoCartographerSceneGeometry.swift        edit  orbit, camera(_:aspect:orbit:) (agent B)
Packages/ExperiencesRound02/EchoCartographer/Core/EchoCartographerPicker.swift               new   ray, markers, cell (agent B)
Packages/ExperiencesRound02/EchoCartographer/Core/EchoCartographerGestureController.swift    new   arbitration, taps, drags, holds, double taps, orbit (agent C)
Packages/ExperiencesRound02/EchoCartographer/CoreTests/{EchoCartographerPickerTests (B), EchoCartographerGestureControllerTests (C), EchoCartographerPanelWinTests (D)}.swift  new
Packages/ExperiencesRound02/EchoCartographer/CoreTests/EchoCartographerSceneGeometryTests.swift  edit (B)
Packages/ExperiencesRound02/EchoCartographer/Experience/{EchoCartographerPresenter, EchoCartographerChamberScene, EchoCartographerControls}.swift  edit (lead)
Packages/ExperiencesRound02/EchoCartographer/ExperienceTests/EchoCartographerGestureWiringTests.swift   new   (agent E)
docs/architecture/echo-cartographer.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md   edit (lead)
```

**Dependency graph**: orbit and picker (B) → gesture controller (C) → presenter wiring (lead) → wiring tests (E); the
panel win test (D) needs only the adapter. **CI checks**: the package host tests, the simulator package tests, app-unit,
the reference regression and the script tests, as for R02-G11-03. **Migration**: none (snapshot schema 1; orbit and
cursor are not saved). **Rollback**: revert the commits; the panel remains a complete control path.

## Parallel work

Agents B (orbit, camera, picker) and D (panel win test) start at once; agent C writes the gesture controller on B's
picker contract; the lead wires the presenter, scene and controls; agent E writes the simulator wiring tests. The lead
retests every result.
