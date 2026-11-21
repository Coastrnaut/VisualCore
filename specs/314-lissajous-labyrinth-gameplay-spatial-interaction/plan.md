# Implementation Plan: R02-G02-04 — Lissajous Labyrinth: gameplay spatial interaction

**Branch**: `314-lissajous-labyrinth-gameplay-spatial-interaction` (spec directory only; work on `main`) | **Date**: 2026-11-21 |
**Spec**: [spec.md](spec.md)

## Summary

Give Lissajous Labyrinth its touch controls and a panel that can win every level within its allowance, following
feature 304 (Aurora Loom). In the host-tested `LissajousLabyrinthCore`: a dial-independent stage (`stageBounds(level:)`)
and the four dial rings beside it (`LissajousLabyrinthHandles`: ring centres, knob positions, value ↔ angle mappings,
R02-F22 `SpatialHandle`s), the camera orbit (`LissajousLabyrinthOrbit` and `camera(aspect:snapshot:orbit:)`, whose fitted
sphere now holds the stage and the rings), the gesture controller (`LissajousLabyrinthGestureController`: pointer events
in, at most one `dial.set` per gesture out, with preview, selection and orbit) and the pending-value planner
(`LissajousLabyrinthPending`: the ordered actions Apply sends, frequencies swapped when only that keeps every
intermediate pair coprime). In the iOS `LissajousLabyrinthExperience`: the presenter routes `pointer(_:viewSize:port:)`
through the controller, the scene draws the rings, knobs, selection outline and turn preview, the controls set pending
values with Apply and Clear, gain "Reset view" and announce the selection. Research: [research.md](research.md). Data:
[data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6. **Primary dependencies**: VisualCoreScenes (`SpatialHandle`, `HandleKind`, `HandlePicker`,
`HandleDrag`, `DragConstraint`, `PointerEvent`, `PointerTracker`), VisualCoreMath (`ScreenProjection`, `Ray3`, `Mat4`,
`Vec3`), VisualCoreExperience (actions); the Experience's existing rendering dependencies. No new package; rings, knobs
and outlines reuse the existing ring and sphere programs and `MeshBuilder`. No VisualCore change.
**Testing**: host: `swift test --package-path Packages/ExperiencesRound02` (ring mappings round trip, orbit framing at
every limit and aspect 0.4 … 2.5, 400 scripted turns, 1,000 arbitration scripts, the pending planner over all 100
certified levels); simulator: `xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme
ExperiencesRound02-Package --destination sim-27.2 --action test` (pointer wiring end to end, selection outline, undo after
a gesture, pending Apply wins all 100 levels through the presenter, frame checks at orbit limits); app unit tests
(candidate); regression as R02-G02-03; script tests (alone).
**Performance**: a pick is ≤ 4 handles; a turn update is one ray–plane intersection; per frame 4 rings + 4 knobs + one
outline drawn (≤ 1,000 extra vertices).
**Constraints**: the camera, the gesture state and the pending values are presentation only (never in the digest, the
snapshot payload or the kernel). The camera now fits a dial-independent sphere (stage and rings), so framing constants
in `LissajousLabyrinthSceneGeometryTests` move; the simulator render checks follow the geometry and stand.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I Proven renderer only | PASS — the existing GL path, programs and `ShaderMeshRenderer`. |
| II App-neutral API | PASS — game code in the experience package; VisualCore unchanged. |
| IV Host-testable | PASS — handles, orbit, gestures and the pending planner in the Core with scripted tests. |
| V Implementation before devices | PASS — touch feel and latency are `{device}` after ImplementationLock-100. |
| IX Bounded input | PASS — touches bounded by `PointerTracker.maxPointers`; values clamped or wrapped; orbit clamped. |
| X Licensing and provenance | PASS — original controls and code. |
| XI One app and stable identity | PASS — the registered candidate; no app target. |
| XII One purchase, no advertising | PASS — free tier. |
| XIII Code-driven visuals | PASS — rings, knobs and outlines are generated meshes. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthHandles.swift            new   rings, knobs, mappings (agent B)
Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthSceneGeometry.swift       edit  stageBounds, orbit, camera(aspect:snapshot:orbit:) (agent B)
Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthGestureController.swift   new   arbitration, turns, orbit, selection (agent C)
Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthPending.swift             new   pending values and Apply order (agent D)
Packages/ExperiencesRound02/LissajousLabyrinth/CoreTests/{LissajousLabyrinthHandlesTests (B), LissajousLabyrinthGestureControllerTests (C), LissajousLabyrinthPendingTests (D)}.swift  new
Packages/ExperiencesRound02/LissajousLabyrinth/CoreTests/LissajousLabyrinthSceneGeometryTests.swift   edit  orbit framing (agent B)
Packages/ExperiencesRound02/LissajousLabyrinth/Experience/{LissajousLabyrinthPresenter, LissajousLabyrinthThreadScene, LissajousLabyrinthControls}.swift  edit (lead)
Packages/ExperiencesRound02/LissajousLabyrinth/ExperienceTests/LissajousLabyrinthGestureWiringTests.swift   new   (agent E)
docs/architecture/lissajous-labyrinth.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md          edit (lead)
```

**Migration**: none. **Rollback**: revert the commits; the panel remains a complete control path.

## Parallel work

Agents B (handles, stage, orbit, geometry tests), C (gesture controller and its tests, against the contract) and D
(pending planner and its tests) work in parallel; the lead then wires the presenter, scene and controls; agent E writes
the simulator wiring tests; the lead runs every check and records only after every agent has reported.
