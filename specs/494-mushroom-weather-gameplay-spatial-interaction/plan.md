# Implementation Plan: R02-G20-04 — Mushroom Weather: gameplay spatial interaction

**Branch**: `494-mushroom-weather-gameplay-spatial-interaction` (spec directory only; work on `main`) | **Date**:
2026-11-26 | **Spec**: [spec.md](spec.md)

## Summary

Add Mushroom Weather's gestures on the pattern of Microscopic Aurora's (feature 484): a constrained view orbit and an
orbiting camera (`MushroomWeatherViewOrbit`, `camera(aspect:orbit:)`, the meshes built for the drawn eye); the preview
(the snapshot gains a preview: the pod's slot and target site or removal, or the moonlight level, and the previewed run;
the geometry draws the previewed run, a ghost pod at its target and the moon at the previewed brightness); the cycle
scrubber (a track at y −0.9 between the floor and the gauges with a mark at the shown cycle); an analytic picker
(`MushroomWeatherPicker`: pods, sites, vents and the moon by their projected sizes grown by 12 points, the one drawn last
first; the scrubber within 14 points of its projected track; the floor inside the projected floor rectangle; the finger
cast onto the floor plane for the target site); a host-tested gesture controller (`MushroomWeatherGestureController`:
taps on empty sites that place, pod drags that move or remove on release, vent taps that toggle, moon drags that set the
moonlight on release, scrubber taps and drags that show a cycle, double taps off the floor that reset the view,
two-finger orbit, cancellation, no kernel action on a finished play); the presenter's pointer entry and the panel's
"Reset view"; and tests: 500 seeded gestures against an independent pick, all 100 certified levels won through panel
actions, and simulator wiring tests. Research: [research.md](research.md). Data: [data-model.md](data-model.md). API:
[contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Audit (2026-11-26)**: after R02-G20-03, `Packages/ExperiencesRound02/Package.swift` has `MushroomWeatherCore` (with
VisualCoreScenes, VisualCoreMath, VisualCoreExperience), `MushroomWeatherExperience` and their test targets, and
`project.yml` links both products into the one app (feature 493's plan); no new target or scheme is needed.
`MushroomWeatherSceneGeometry` has `camera(aspect:)`, `project(_:camera:)`, `cellCentre`, `scale(rows:columns:)`,
`capCentre`, `moonCentre`, `forestMesh`/`glowMesh` (built for the authored camera); the adapter declares nine controls.
**Language/Version**: Swift 6, GLSL ES 3.00. **Primary dependencies**: VisualCoreScenes (`PointerEvent`,
`PointerPhase`) and VisualCoreMath (`Vec2`); the Mushroom Weather Core of R02-G20-01 … 03; VisualCoreExperienceHost
(pointer events) in the experience. No new package, target, Objective-C++ or VisualCore API. **Testing**: host `swift
test --package-path Packages/ExperiencesRound02`; simulator package tests on sim-27.2; the app unit tests; regression;
script tests alone. Seed 2_494. **Constraints**: presentation-only view orbit, shown cycle and preview; tap distance 10
points, drag distance 16 points, pod, site, vent and moon allowance 12 points, scrubber band 14 points, target-site
reach 24 points, moon step 40 points per level, tap duration 0.5 s, double tap 0.35 s and 22 points by event
timestamps; yaw ±60°, pitch −20° … +35°; the scrubber at y −0.9 lies inside feature 493's camera box (y −1.5 … 1.2
unchanged); the orbit refit keeps the box extended to the moon's depth (z −0.5 … 0.3) inside the view, never moving the
eye closer than the authored distance, so orbit 0 is the authored camera; the previewed run is the kernel's `MushroomWeatherForest.run` of the previewed arrangement (a catalog run
of at most 40 cycles over at most 90 cells is well under a millisecond, so a preview per drag move is affordable);
tests under 10 s.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| II App-neutral API | PASS — game code stays in ExperiencesRound02; VisualCore API unchanged. |
| IV Host-testable | PASS — picking, preview geometry and gestures in the Core with host tests; wiring tested on the simulator. |
| V Implementation before devices | PASS — touch feel and latency are `{device}` tasks. |
| VII Determinism | PASS — only event timestamps are read; actions are sent through the kernel's declared controls. |
| IX Bounded input | PASS — pointer events bounded by the view; orbit clamped; sites, levels and cycles clamped; actions validated by the kernel. |
| XI One app | PASS — candidate experience only. |
| XIII Code-driven visuals | PASS — the ghost pod, preview and scrubber are generated geometry and shader code. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/MushroomWeather/Core/MushroomWeatherSceneSnapshot.swift      edit  preview (agent B)
Packages/ExperiencesRound02/MushroomWeather/Core/MushroomWeatherSceneGeometry.swift      edit  view orbit, camera(aspect:orbit:), scrubber, preview, meshes for the drawn camera (agent B)
Packages/ExperiencesRound02/MushroomWeather/Core/MushroomWeatherShaders.swift            edit  ghost pod and scrubber materials (agent B)
Packages/ExperiencesRound02/MushroomWeather/Core/MushroomWeatherPicker.swift             new   projection, pods, sites, vents, moon, scrubber, floor, plane cast, target site, scrub cycle, moon level (agent B)
Packages/ExperiencesRound02/MushroomWeather/Core/MushroomWeatherGestureController.swift  new   arbitration, taps, pod drags, vent taps, moon drags, scrubs, orbit (agent C)
Packages/ExperiencesRound02/MushroomWeather/CoreTests/{MushroomWeatherPickerTests (B), MushroomWeatherGestureControllerTests (C), MushroomWeatherPanelWinTests (D)}.swift  new
Packages/ExperiencesRound02/MushroomWeather/CoreTests/{MushroomWeatherSceneGeometryTests, MushroomWeatherShaderSourceTests}.swift  edit (B)
Packages/ExperiencesRound02/MushroomWeather/Experience/{MushroomWeatherPresenter, MushroomWeatherForestScene, MushroomWeatherControls}.swift  edit (lead)
Packages/ExperiencesRound02/MushroomWeather/ExperienceTests/MushroomWeatherGestureWiringTests.swift   new   (agent E)
docs/architecture/mushroom-weather.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md   edit (lead)
```

**Dependency graph**: snapshot, geometry, shader, view orbit and picker (B, one agent because they share the vertex
contract) → gesture controller (C) → presenter wiring (lead) → wiring tests (E); the panel win test (D) needs only the
adapter. **CI checks**: the package host tests, the simulator package tests, app-unit, the reference regression and the
script tests. **Migration**: none (snapshot schema 1; orbit, shown cycle and preview are not saved). **Rollback**:
revert the commits; the panel remains a complete control path.

## Parallel work

Agents B, C and D draft in isolated copies (C against the picker contract, D against the adapter); the lead wires the
presenter, scene and panel after B and C report; E writes the simulator wiring tests from the wired presenter. Agents
build only in their copies; the lead runs every repository build and test and records checks after every agent has
reported.
