# Implementation Plan: R02-G18-04 — Apsides Workshop: gameplay spatial interaction

**Branch**: `474-apsides-workshop-gameplay-spatial-interaction` (spec directory only; work on `main`) | **Date**:
2026-11-25 | **Spec**: [spec.md](spec.md)

## Summary

Add Apsides Workshop's gestures on the pattern of Celestial Eclipse Lab's (feature 464): a constrained view orbit and an
orbiting camera (`ApsidesWorkshopViewOrbit`, `camera(aspect:orbit:)`, the meshes built for the drawn eye); the tuning
preview (the snapshot gains `previewOrbit`, its kernel positions and its gauges' readings; the geometry draws the
previewed orbit as a dashed ghost loop with its apsis markers, and the gauges show the previewed readings); an analytic
picker (`ApsidesWorkshopPicker`: the orbiter's projected disc grown by 8 points, the apoapsis square and periapsis diamond
grown by 12 points, the one drawn last first; the orbit loop within 10 points of its projected chords; the finger cast
onto the sky plane for the knob and size steps); a host-tested gesture controller (`ApsidesWorkshopGestureController`:
knob drags that set the periapsis and size drags that set the size on release, crank drags and loop taps that show a
tick, empty double taps that reset the view, two-finger orbit, cancellation, no kernel action on a finished play); the
presenter's pointer entry, the pending text, "Reset view" and the panel's pending orbit with "Set periapsis" and "Set
size"; and tests: 500 seeded gestures against an independent pick, all 100 certified levels won through panel actions,
and simulator wiring tests. Research: [research.md](research.md). Data: [data-model.md](data-model.md). API:
[contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Audit (2026-11-25)**: `Packages/ExperiencesRound02/Package.swift` has `ApsidesWorkshopCore` (with VisualCoreScenes,
VisualCoreMath, VisualCoreExperience since R02-G18-03 T-002), `ApsidesWorkshopExperience` and their test targets;
`project.yml` links both products into the one app; no new target or scheme is needed. `ApsidesWorkshopSceneGeometry`
has `camera(aspect:)`, `project(_:camera:)`, `world(_:depth:)`, `scale`, `orbiterCentre`, `paintOrder`,
`referencePoints`, `compassMesh`/`glowMesh` (built for the authored camera); `ApsidesWorkshopShaders` has 22 material
codes (0 … 21); the adapter declares seven controls.
**Language/Version**: Swift 6, GLSL ES 3.00. **Primary dependencies**: VisualCoreScenes (`PointerEvent`,
`PointerPhase`) and VisualCoreMath (`Vec2`); the Apsides Workshop Core of R02-G18-01 … 03; VisualCoreExperienceHost
(pointer events) in the experience. No new package, target, Objective-C++ or VisualCore API.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02`; simulator package tests on sim-27.2; the app
unit tests; regression; script tests alone. Seed 2_474.
**Constraints**: presentation-only view orbit, shown tick and preview; tap distance 10 points, drag distance 16 points,
orbiter allowance 8 points, marker allowance 12 points, loop band 10 points, tap duration 0.5 s, double tap 0.35 s and 22
points by event timestamps; yaw ±60°, pitch −20° … +35°; the box fit holds for every valid preview orbit (inside the
sky bound by the kernel's rule); tests under 10 s.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| II App-neutral API | PASS — game code stays in ExperiencesRound02; VisualCore API unchanged. |
| IV Host-testable | PASS — picking, preview geometry and gestures in the Core with host tests; wiring tested on the simulator. |
| V Implementation before devices | PASS — touch feel and latency are `{device}` tasks. |
| VII Determinism | PASS — only event timestamps are read; actions are sent through the kernel's declared controls. |
| IX Bounded input | PASS — pointer events bounded by the view; orbit clamped; steps and ticks clamped; actions validated by the kernel. |
| XI One app | PASS — candidate experience only. |
| XIII Code-driven visuals | PASS — the ghost is generated geometry and shader code. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/ApsidesWorkshop/Core/ApsidesWorkshopSceneSnapshot.swift        edit  preview orbit, positions, readings (agent B)
Packages/ExperiencesRound02/ApsidesWorkshop/Core/ApsidesWorkshopSceneGeometry.swift        edit  view orbit, camera(aspect:orbit:), ghost, meshes for the drawn camera (agent B)
Packages/ExperiencesRound02/ApsidesWorkshop/Core/ApsidesWorkshopShaders.swift              edit  ghost preview material (agent B)
Packages/ExperiencesRound02/ApsidesWorkshop/Core/ApsidesWorkshopPicker.swift               new   projection, handles, loop band, sky-plane cast, steps, crank tick (agent B)
Packages/ExperiencesRound02/ApsidesWorkshop/Core/ApsidesWorkshopGestureController.swift    new   arbitration, taps, knob, size and crank drags, orbit (agent C)
Packages/ExperiencesRound02/ApsidesWorkshop/CoreTests/{ApsidesWorkshopPickerTests (B), ApsidesWorkshopGestureControllerTests (C), ApsidesWorkshopPanelWinTests (D)}.swift  new
Packages/ExperiencesRound02/ApsidesWorkshop/CoreTests/{ApsidesWorkshopSceneGeometryTests, ApsidesWorkshopShaderSourceTests}.swift  edit (B)
Packages/ExperiencesRound02/ApsidesWorkshop/Experience/{ApsidesWorkshopPresenter, ApsidesWorkshopCompassScene, ApsidesWorkshopControls}.swift  edit (lead)
Packages/ExperiencesRound02/ApsidesWorkshop/ExperienceTests/ApsidesWorkshopGestureWiringTests.swift   new   (agent E)
docs/architecture/apsides-workshop.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md   edit (lead)
```

**Dependency graph**: snapshot, geometry, shader, view orbit and picker (B, one agent because they share the vertex
contract) → gesture controller (C) → presenter wiring (lead) → wiring tests (E); the panel win test (D) needs only the
adapter and the pending-orbit rule. **CI checks**: the package host tests, the simulator package tests, app-unit, the
reference regression and the script tests. **Migration**: none (snapshot schema 1; orbit, shown tick and preview are not
saved). **Rollback**: revert the commits; the panel remains a complete control path.

## Parallel work

Agents B (snapshot preview fields, ghost geometry and material, view orbit, camera, picker) and D (panel win test) start
at once; agent C writes the gesture controller on B's picker contract (fixed in [contracts/api.md](contracts/api.md));
the lead wires the presenter, scene and controls; agent E writes the simulator wiring tests. The lead retests every
result.
