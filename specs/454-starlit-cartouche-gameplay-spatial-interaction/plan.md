# Implementation Plan: R02-G16-04 — Starlit Cartouche: gameplay spatial interaction

**Branch**: `454-starlit-cartouche-gameplay-spatial-interaction` (spec directory only; work on `main`) | **Date**:
2026-11-24 | **Spec**: [spec.md](spec.md)

## Summary

Add Starlit Cartouche's gestures on the pattern of Voxel Origami's (feature 444): a constrained orbit and an orbiting
camera (`StarlitCartoucheOrbit`, `camera(_:aspect:orbit:)`, the meshes built for the drawn eye); the launch preview (the
snapshot gains the launch beat L = beat + chosen wait and every star's position at L; the geometry draws the stars and
the ship at L and, while playing and when a corridor joins them, a dashed sapphire preview ribbon 0.03 wide from the
ship's star at L to the destination at L + travel, with a new shader material); an analytic picker
(`StarlitCartouchePicker`: each star's projected ring radius grown by 8 points, the front-most first; the ship's star as
the ship; the slider as the projected wait pips' box grown by 8 points); a host-tested gesture controller
(`StarlitCartoucheGestureController`: taps that choose a destination, double taps that fly to it, slider drags that
choose the wait, ship drags that fly on release, empty double taps that reset the view, two-finger orbit, cancellation,
no kernel action on a finished play); the presenter's pointer entry, the pending text and "Reset view"; and tests: 500
seeded gestures against an independent pick, all 100 certified levels won through panel actions, and simulator wiring
tests. Research: [research.md](research.md). Data: [data-model.md](data-model.md). API:
[contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Audit (2026-11-24)**: `Packages/ExperiencesRound02/Package.swift` has `StarlitCartoucheCore` (with VisualCoreScenes,
VisualCoreMath, VisualCoreExperience since R02-G16-03 T-002), `StarlitCartoucheExperience` and their test targets;
`project.yml` links both products into the one app; no new target or scheme is needed. `StarlitCartoucheSceneGeometry`
has `camera(_:aspect:)`, `project(_:camera:)`, `starCentre`, `world`, `scale`, `paintOrder`, `waitPip`,
`chartMesh`/`glowMesh` (built for the authored camera); `StarlitCartoucheShaders.Material` has 22 codes; the adapter
declares the five controls.
**Language/Version**: Swift 6, GLSL ES 3.00. **Primary dependencies**: VisualCoreScenes (`PointerEvent`,
`PointerPhase`) and VisualCoreMath (`Vec2`); the Starlit Cartouche Core of R02-G16-01 … 03; VisualCoreExperienceHost
(pointer events) in the experience. No new package, target, Objective-C++ or VisualCore API.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02`; simulator package tests on sim-27.2; the app
unit tests; regression; script tests alone. Seed 2_454.
**Constraints**: presentation-only orbit, choice and preview; tap distance 10 points, drag distance 16 points, star
allowance 8 points, tap duration 0.5 s, double tap 0.35 s and 22 points by event timestamps; yaw ±60°, pitch −20° …
+35°; the box fit holds for stars at every launch beat (positions are orbit positions, all inside the R02-G16-03 box);
tests under 10 s.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| II App-neutral API | PASS — game code stays in ExperiencesRound02; VisualCore API unchanged. |
| IV Host-testable | PASS — picking, preview geometry and gestures in the Core with host tests; wiring tested on the simulator. |
| V Implementation before devices | PASS — touch feel and latency are `{device}` tasks. |
| VII Determinism | PASS — only event timestamps are read; actions are sent through the kernel's declared controls. |
| IX Bounded input | PASS — pointer events bounded by the view; orbit clamped; waits clamped 0 … 8; actions validated by the kernel. |
| XI One app | PASS — candidate experience only. |
| XIII Code-driven visuals | PASS — the preview is generated geometry and shader code. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/StarlitCartouche/Core/StarlitCartoucheSceneSnapshot.swift      edit  launch beat and positions (agent B)
Packages/ExperiencesRound02/StarlitCartouche/Core/StarlitCartoucheSceneGeometry.swift      edit  orbit, camera(_:aspect:orbit:), launch positions, preview ribbon, meshes for the drawn camera (agent B)
Packages/ExperiencesRound02/StarlitCartouche/Core/StarlitCartoucheShaders.swift            edit  preview material (agent B)
Packages/ExperiencesRound02/StarlitCartouche/Core/StarlitCartouchePicker.swift             new   projection, star discs, ship and slider regions, front-most pick, slider wait (agent B)
Packages/ExperiencesRound02/StarlitCartouche/Core/StarlitCartoucheGestureController.swift  new   arbitration, taps, double taps, slider and ship drags, orbit (agent C)
Packages/ExperiencesRound02/StarlitCartouche/CoreTests/{StarlitCartouchePickerTests (B), StarlitCartoucheGestureControllerTests (C), StarlitCartouchePanelWinTests (D)}.swift  new
Packages/ExperiencesRound02/StarlitCartouche/CoreTests/{StarlitCartoucheSceneGeometryTests, StarlitCartoucheShaderSourceTests}.swift  edit (B)
Packages/ExperiencesRound02/StarlitCartouche/Experience/{StarlitCartouchePresenter, StarlitCartoucheChartScene, StarlitCartoucheControls}.swift  edit (lead)
Packages/ExperiencesRound02/StarlitCartouche/ExperienceTests/StarlitCartoucheGestureWiringTests.swift   new   (agent E)
docs/architecture/starlit-cartouche.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md   edit (lead)
```

**Dependency graph**: snapshot, geometry, shader, orbit and picker (B, one agent because they share the vertex contract
— the lesson of R02-G16-03) → gesture controller (C) → presenter wiring (lead) → wiring tests (E); the panel win test (D)
needs only the adapter. **CI checks**: the package host tests, the simulator package tests, app-unit, the reference
regression and the script tests, as for R02-G16-03. **Migration**: none (snapshot schema 1; orbit, choice and preview
are not saved). **Rollback**: revert the commits; the panel remains a complete control path.

## Parallel work

Agents B (snapshot launch fields, preview geometry and material, orbit, camera, picker) and D (panel win test) start at
once; agent C writes the gesture controller on B's picker contract (fixed in [contracts/api.md](contracts/api.md) before
either starts); the lead wires the presenter, scene and controls; agent E writes the simulator wiring tests with the
presenter's status texts given in its brief. The lead retests every result.
