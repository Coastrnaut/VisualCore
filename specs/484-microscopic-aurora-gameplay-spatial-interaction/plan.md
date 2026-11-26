# Implementation Plan: R02-G19-04 — Microscopic Aurora: gameplay spatial interaction

**Branch**: `484-microscopic-aurora-gameplay-spatial-interaction` (spec directory only; work on `main`) | **Date**:
2026-11-26 | **Spec**: [spec.md](spec.md)

## Summary

Add Microscopic Aurora's gestures on the pattern of Apsides Workshop's (feature 474): a constrained view orbit and an
orbiting camera (`MicroscopicAuroraViewOrbit`, `camera(aspect:orbit:)`, the meshes built for the drawn eye); the well
preview (the snapshot gains a preview: the slot, the target site or removal and the previewed swim; unfrozen the
geometry draws the previewed swim and a ghost well at the target, frozen only the gauges show the previewed readings);
the swim scrubber (a track at y −1.31 with a mark at the shown tick); an analytic picker (`MicroscopicAuroraPicker`:
wells and sites by their projected radii grown by 12 points, the one drawn last first; the scrubber within 14 points of
its projected track; the dish field inside the projected enclosure; the finger cast onto the dish plane for the target
site); a host-tested gesture controller (`MicroscopicAuroraGestureController`: taps on empty sites that place, well
drags that move or remove on release, scrubber taps and drags that show a tick, field taps that toggle the freeze,
empty double taps that reset the view, two-finger orbit, cancellation, no kernel action on a finished play); the
presenter's pointer entry, the panel's "Freeze" and "Reset view"; and tests: 500 seeded gestures against an independent
pick, all 100 certified levels won through panel actions, and simulator wiring tests. Research:
[research.md](research.md). Data: [data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md).
Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Audit (2026-11-26)**: `Packages/ExperiencesRound02/Package.swift` has `MicroscopicAuroraCore` (with VisualCoreScenes,
VisualCoreMath, VisualCoreExperience since R02-G19-03 T-002), `MicroscopicAuroraExperience` and their test targets;
`project.yml` links both products into the one app; no new target or scheme is needed. `MicroscopicAuroraSceneGeometry`
has `camera(aspect:)`, `project(_:camera:)`, `world(_:depth:)`, `scale`, `siteCentre`, `cellCentre`, `rimRadius`,
`paintOrder`, `referencePoints`, `dishMesh`/`glowMesh` (built for the authored camera); `MicroscopicAuroraShaders` has 20
material codes (0 … 19); the adapter declares seven controls. **Language/Version**: Swift 6, GLSL ES 3.00. **Primary
dependencies**: VisualCoreScenes (`PointerEvent`, `PointerPhase`) and VisualCoreMath (`Vec2`); the Microscopic Aurora
Core of R02-G19-01 … 03; VisualCoreExperienceHost (pointer events) in the experience. No new package, target,
Objective-C++ or VisualCore API. **Testing**: host `swift test --package-path Packages/ExperiencesRound02`; simulator
package tests on sim-27.2; the app unit tests; regression; script tests alone. Seed 2_484. **Constraints**:
presentation-only view orbit, shown tick, freeze and preview; tap distance 10 points, drag distance 16 points, well and
site allowance 12 points, scrubber band 14 points, target-site reach 24 points, tap duration 0.5 s, double tap 0.35 s
and 22 points by event timestamps; yaw ±60°, pitch −20° … +35°; the camera box includes the scrubber at y −1.31 (box y
−1.35 … 1.0 unchanged); the previewed swim is the kernel's `MicroscopicAuroraDish.swim` of the previewed wells (a
catalog swim costs well under 2 ms in release, so a preview per drag move is affordable); tests under 10 s.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| II App-neutral API | PASS — game code stays in ExperiencesRound02; VisualCore API unchanged. |
| IV Host-testable | PASS — picking, preview geometry and gestures in the Core with host tests; wiring tested on the simulator. |
| V Implementation before devices | PASS — touch feel and latency are `{device}` tasks. |
| VII Determinism | PASS — only event timestamps are read; actions are sent through the kernel's declared controls. |
| IX Bounded input | PASS — pointer events bounded by the view; orbit clamped; sites and ticks clamped; actions validated by the kernel. |
| XI One app | PASS — candidate experience only. |
| XIII Code-driven visuals | PASS — the ghost well, preview and scrubber are generated geometry and shader code. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/MicroscopicAurora/Core/MicroscopicAuroraSceneSnapshot.swift      edit  preview (agent B)
Packages/ExperiencesRound02/MicroscopicAurora/Core/MicroscopicAuroraSceneGeometry.swift      edit  view orbit, camera(aspect:orbit:), scrubber, preview, meshes for the drawn camera (agent B)
Packages/ExperiencesRound02/MicroscopicAurora/Core/MicroscopicAuroraShaders.swift            edit  ghost well and scrubber materials (agent B)
Packages/ExperiencesRound02/MicroscopicAurora/Core/MicroscopicAuroraPicker.swift             new   projection, wells, sites, scrubber, field, plane cast, target site, scrub tick (agent B)
Packages/ExperiencesRound02/MicroscopicAurora/Core/MicroscopicAuroraGestureController.swift  new   arbitration, taps, well drags, scrubs, freeze, orbit (agent C)
Packages/ExperiencesRound02/MicroscopicAurora/CoreTests/{MicroscopicAuroraPickerTests (B), MicroscopicAuroraGestureControllerTests (C), MicroscopicAuroraPanelWinTests (D)}.swift  new
Packages/ExperiencesRound02/MicroscopicAurora/CoreTests/{MicroscopicAuroraSceneGeometryTests, MicroscopicAuroraShaderSourceTests}.swift  edit (B)
Packages/ExperiencesRound02/MicroscopicAurora/Experience/{MicroscopicAuroraPresenter, MicroscopicAuroraDishScene, MicroscopicAuroraControls}.swift  edit (lead)
Packages/ExperiencesRound02/MicroscopicAurora/ExperienceTests/MicroscopicAuroraGestureWiringTests.swift   new   (agent E)
docs/architecture/microscopic-aurora.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md   edit (lead)
```

**Dependency graph**: snapshot, geometry, shader, view orbit and picker (B, one agent because they share the vertex
contract) → gesture controller (C) → presenter wiring (lead) → wiring tests (E); the panel win test (D) needs only the
adapter. **CI checks**: the package host tests, the simulator package tests, app-unit, the reference regression and the
script tests. **Migration**: none (snapshot schema 1; orbit, shown tick, freeze and preview are not saved).
**Rollback**: revert the commits; the panel remains a complete control path.

## Parallel work

Agents B, C and D draft in isolated copies (C against the picker contract, D against the adapter); the lead wires the
presenter, scene and panel after B and C report; E writes the simulator wiring tests from the wired presenter. Agents
build only in their copies; the lead runs every repository build and test and records checks after every agent has
reported.
