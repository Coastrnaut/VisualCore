# Implementation Plan: R02-G03-04 — Wave Knot Keeper: gameplay spatial interaction

**Branch**: `324-wave-knot-keeper-gameplay-spatial-interaction` (spec directory only; work on `main`) | **Date**:
2026-11-21 | **Spec**: [spec.md](spec.md)

## Summary

Give Wave Knot Keeper tactile play, following Lissajous Labyrinth's feature 314: in the host-tested Core, an orbit and an
orbit-aware camera in `WaveKnotKeeperSceneGeometry`, handle picking and the drag-to-direction mapping
(`WaveKnotKeeperHandles`), and the gesture controller `WaveKnotKeeperGestureController` (idle, dragging, orbiting,
cancelled; one action per gesture); in the experience, the presenter's pointer entry, the ghost preview of the dragged
handle, "Reset view" and the orbit in the scene; tests for the mapping, arbitration, orbit framing, a host win of all
100 levels through panel actions and simulator wiring. Research: [research.md](research.md). Data:
[data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6. **Primary dependencies**: VisualCoreSimulation (`SpatialHandle`, `HandlePicker`,
`HandleDrag`, `AssistiveStep` of R02-F22), VisualCoreMath, the Wave Knot Keeper Core of R02-G03-01 … 03,
VisualCoreExperienceHost (pointer events) in the experience. No new package, target or VisualCore API.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02`; simulator package tests on sim-27.2; the app
unit tests; regression; script tests alone. Seed 2_324.
**Constraints**: presentation-only orbit; one `point.move` per gesture at most; drag snap at least 6 points; tests
under 10 s.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| II App-neutral API | PASS — game code in the experience package; VisualCore API unchanged. |
| IV Host-testable | PASS — picking, mapping, orbit and arbitration live in the Core with host tests. |
| V Implementation before devices | PASS — gesture feel is a {device} task. |
| VII Native, accessible UI | PASS — the panel remains a complete control path; every action is reachable without gestures. |
| IX Bounded input | PASS — pointer events bounded to the view; one action per gesture. |
| XIII Code-driven visuals | PASS — the ghost handle is a generated mesh. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/WaveKnotKeeper/Core/WaveKnotKeeperSceneGeometry.swift            edit  orbit, camera(for:aspect:orbit:) (agent B)
Packages/ExperiencesRound02/WaveKnotKeeper/Core/WaveKnotKeeperHandles.swift                  new   picking, projected steps, drag → direction (agent B)
Packages/ExperiencesRound02/WaveKnotKeeper/Core/WaveKnotKeeperGestureController.swift        new   arbitration, drags, orbit, selection (agent C)
Packages/ExperiencesRound02/WaveKnotKeeper/CoreTests/{WaveKnotKeeperHandlesTests (B), WaveKnotKeeperGestureControllerTests (C), WaveKnotKeeperPanelWinTests (D)}.swift  new
Packages/ExperiencesRound02/WaveKnotKeeper/CoreTests/WaveKnotKeeperSceneGeometryTests.swift  edit  orbit framing (agent B)
Packages/ExperiencesRound02/WaveKnotKeeper/Experience/{WaveKnotKeeperPresenter, WaveKnotKeeperRopeScene, WaveKnotKeeperControls}.swift  edit (lead)
Packages/ExperiencesRound02/WaveKnotKeeper/ExperienceTests/WaveKnotKeeperGestureWiringTests.swift   new   (agent E)
docs/architecture/wave-knot-keeper.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md   edit (lead)
```

**Migration**: none. **Rollback**: revert the commits; the panel remains a complete control path.

## Parallel work

Agent B (geometry orbit and handles), then agents C (gesture controller) and D (panel win test) in parallel; the lead
wires the presenter, scene and controls; agent E writes the simulator wiring tests. The lead retests every result.
