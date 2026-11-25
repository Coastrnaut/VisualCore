# Implementation Plan: R02-G17-04 — Celestial Eclipse Lab: gameplay spatial interaction

**Branch**: `464-celestial-eclipse-lab-gameplay-spatial-interaction` (spec directory only; work on `main`) | **Date**:
2026-11-25 | **Spec**: [spec.md](spec.md)

## Summary

Add Celestial Eclipse Lab's gestures on the pattern of Starlit Cartouche's (feature 454): a constrained orbit and an
orbiting camera (`CelestialEclipseLabOrbit`, `camera(_:aspect:orbit:)`, the meshes built for the drawn eye); the phase
preview (the snapshot gains `previewBody`, `previewOffset` and the predicted timeline of the previewed phases; the
geometry draws the dragged body's ghost, a dashed copy of its disc, at the previewed orbit position, and the timeline
shows the preview's events); an analytic picker (`CelestialEclipseLabPicker`: each body's projected disc radius grown by
8 points, the front-most first; the time dial as the projected strip and brackets' box grown by 8 points); a host-tested
gesture controller (`CelestialEclipseLabGestureController`: taps that choose a planet, phase drags along the ring that
set the phase on release, dial taps and drags that show a tick, empty double taps that reset the view, two-finger orbit,
cancellation, no kernel action on a finished play); the presenter's pointer entry, the pending text, "Reset view" and
the panel's "Set phase" (phase − and + move a previewed pending offset, committed as one action); and tests: 500 seeded
gestures against an independent pick, all 100 certified levels won through panel actions, and simulator wiring tests.
Research: [research.md](research.md). Data: [data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md).
Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Audit (2026-11-25)**: `Packages/ExperiencesRound02/Package.swift` has `CelestialEclipseLabCore` (with
VisualCoreScenes, VisualCoreMath, VisualCoreExperience since R02-G17-03 T-002), `CelestialEclipseLabExperience` and
their test targets; `project.yml` links both products into the one app; no new target or scheme is needed.
`CelestialEclipseLabSceneGeometry` has `camera(_:aspect:)`, `project(_:camera:)`, `bodyCentre`, `bodyRadius`, `world`,
`scale`, `paintOrder`, `tickPosition`, `bracketEnds`, `skyMesh`/`glowMesh` (built for the authored camera);
`CelestialEclipseLabShaders` has 17 material codes; the adapter declares seven controls.
**Language/Version**: Swift 6, GLSL ES 3.00. **Primary dependencies**: VisualCoreScenes (`PointerEvent`,
`PointerPhase`) and VisualCoreMath (`Vec2`); the Celestial Eclipse Lab Core of R02-G17-01 … 03; VisualCoreExperienceHost
(pointer events) in the experience. No new package, target, Objective-C++ or VisualCore API.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02`; simulator package tests on sim-27.2; the app
unit tests; regression; script tests alone. Seed 2_464.
**Constraints**: presentation-only orbit, choice, shown tick and preview; tap distance 10 points, drag distance 16
points, body allowance 8 points, tap duration 0.5 s, double tap 0.35 s and 22 points by event timestamps; yaw ±60°,
pitch −20° … +35°; the box fit holds for a ghost at every orbit position (positions are orbit positions, all inside the
widened R02-G17-03 box); tests under 10 s.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| II App-neutral API | PASS — game code stays in ExperiencesRound02; VisualCore API unchanged. |
| IV Host-testable | PASS — picking, preview geometry and gestures in the Core with host tests; wiring tested on the simulator. |
| V Implementation before devices | PASS — touch feel and latency are `{device}` tasks. |
| VII Determinism | PASS — only event timestamps are read; actions are sent through the kernel's declared controls. |
| IX Bounded input | PASS — pointer events bounded by the view; orbit clamped; offsets and ticks clamped; actions validated by the kernel. |
| XI One app | PASS — candidate experience only. |
| XIII Code-driven visuals | PASS — the ghost is generated geometry and shader code. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/CelestialEclipseLab/Core/CelestialEclipseLabSceneSnapshot.swift      edit  preview body, offset and timeline (agent B)
Packages/ExperiencesRound02/CelestialEclipseLab/Core/CelestialEclipseLabSceneGeometry.swift      edit  orbit, camera(_:aspect:orbit:), ghost, meshes for the drawn camera (agent B)
Packages/ExperiencesRound02/CelestialEclipseLab/Core/CelestialEclipseLabShaders.swift            edit  ghost material (agent B)
Packages/ExperiencesRound02/CelestialEclipseLab/Core/CelestialEclipseLabPicker.swift             new   projection, body discs, dial region, front-most pick, dial tick, ring offset (agent B)
Packages/ExperiencesRound02/CelestialEclipseLab/Core/CelestialEclipseLabGestureController.swift  new   arbitration, taps, phase and dial drags, orbit (agent C)
Packages/ExperiencesRound02/CelestialEclipseLab/CoreTests/{CelestialEclipseLabPickerTests (B), CelestialEclipseLabGestureControllerTests (C), CelestialEclipseLabPanelWinTests (D)}.swift  new
Packages/ExperiencesRound02/CelestialEclipseLab/CoreTests/{CelestialEclipseLabSceneGeometryTests, CelestialEclipseLabShaderSourceTests}.swift  edit (B)
Packages/ExperiencesRound02/CelestialEclipseLab/Experience/{CelestialEclipseLabPresenter, CelestialEclipseLabSkyScene, CelestialEclipseLabControls}.swift  edit (lead)
Packages/ExperiencesRound02/CelestialEclipseLab/ExperienceTests/CelestialEclipseLabGestureWiringTests.swift   new   (agent E)
docs/architecture/celestial-eclipse-lab.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md   edit (lead)
```

**Dependency graph**: snapshot, geometry, shader, orbit and picker (B, one agent because they share the vertex contract)
→ gesture controller (C) → presenter wiring (lead) → wiring tests (E); the panel win test (D) needs only the adapter.
**CI checks**: the package host tests, the simulator package tests, app-unit, the reference regression and the script
tests. **Migration**: none (snapshot schema 1; orbit, choice, shown tick and preview are not saved). **Rollback**:
revert the commits; the panel remains a complete control path.

## Parallel work

Agents B (snapshot preview fields, ghost geometry and material, orbit, camera, picker) and D (panel win test) start at
once; agent C writes the gesture controller on B's picker contract (fixed in [contracts/api.md](contracts/api.md)); the
lead wires the presenter, scene and controls; agent E writes the simulator wiring tests. The lead retests every result.
