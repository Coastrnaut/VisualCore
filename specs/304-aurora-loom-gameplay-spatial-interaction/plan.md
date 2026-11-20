# Implementation Plan: R02-G01-04 — Aurora Loom: gameplay spatial interaction

**Branch**: `304-aurora-loom-gameplay-spatial-interaction` (spec directory only; work on `main`) | **Date**: 2026-11-20 |
**Spec**: [spec.md](spec.md)

## Summary

Give Aurora Loom its touch controls. In the host-tested `AuroraLoomCore`: the handle layout (`AuroraLoomHandles`: an
anchor rail and a dial per ribbon, step ↔ position mappings, R02-F22 `SpatialHandle`s), the camera orbit
(`AuroraLoomOrbit` and an orbit-aware `AuroraLoomSceneGeometry.camera(aspect:orbit:)` whose fitted content box now includes
the rails and dials) and the gesture controller (`AuroraLoomGestureController`: pointer events in, at most one move per
gesture out, with preview, selection and orbit). In the iOS `AuroraLoomExperience`: the presenter routes
`pointer(_:viewSize:port:)` through the controller and sends `ribbon.move`, the scene draws rails, anchors, dials, the
selection outline and the drag preview, the controls gain "Reset view" and announce the selection. Research:
[research.md](research.md). Data: [data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md). Quickstart:
[quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6. **Primary dependencies**: VisualCoreScenes (`SpatialHandle`, `HandleKind`, `HandlePicker`,
`HandleDrag`, `DragConstraint`, `PointerEvent`, `PointerTracker`), VisualCoreMath (`ScreenProjection`, `Ray3`, `Mat4`),
VisualCoreExperience (actions); the Experience's existing rendering dependencies. No new package, no shader change beyond
reusing the gate program for rails and dials. No VisualCore change.
**Testing**: host: `swift test --package-path Packages/ExperiencesRound02` (handles, orbit framing, 500 scripted drags,
1,000 arbitration scripts); simulator: `xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme
ExperiencesRound02-Package --destination sim-27.2 --action test` (pointer wiring end to end, selection outline, undo after
a gesture, orbit limits keep the frame checks); app unit tests (candidate unchanged); regression as R02-G01-03; script
tests (alone).
**Performance**: a pick is ≤ 6 handles; a drag update is one ray–constraint intersection; nothing per frame beyond drawing 6
handle meshes.
**Constraints**: the camera and the gesture state are presentation only (never in the digest or the snapshot payload);
existing tests unchanged except the framing constants that the larger content box moves (the simulator reference follows
the geometry, so its checks stand).

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I Proven renderer only | PASS — the existing GL path, programs and `ShaderMeshRenderer`. |
| II App-neutral API | PASS — game code in the experience package; VisualCore unchanged. |
| IV Host-testable | PASS — handles, orbit and gesture logic in the Core with scripted-touch tests. |
| V Implementation before devices | PASS — touch feel and latency are `{device}` after ImplementationLock-100. |
| IX Bounded input | PASS — touches bounded by `PointerTracker.maxPointers`; steps clamped or wrapped; orbit clamped. |
| X Licensing and provenance | PASS — original controls and code. |
| XI One app and stable identity | PASS — the registered candidate; no app target. |
| XII One purchase, no advertising | PASS — free tier. |
| XIII Code-driven visuals | PASS — rails, dials and outlines are generated meshes. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/AuroraLoom/Core/AuroraLoomHandles.swift              new   handle layout and mappings (agent B)
Packages/ExperiencesRound02/AuroraLoom/Core/AuroraLoomSceneGeometry.swift         edit  orbit, camera(aspect:orbit:), content box (agent B)
Packages/ExperiencesRound02/AuroraLoom/Core/AuroraLoomGestureController.swift     new   arbitration, drags, orbit, selection (agent C)
Packages/ExperiencesRound02/AuroraLoom/CoreTests/{AuroraLoomHandlesTests (B), AuroraLoomGestureControllerTests (C)}.swift   new
Packages/ExperiencesRound02/AuroraLoom/CoreTests/AuroraLoomSceneGeometryTests.swift edit  orbit framing (agent B)
Packages/ExperiencesRound02/AuroraLoom/Experience/{AuroraLoomPresenter, AuroraLoomRibbonScene, AuroraLoomControls}.swift  edit (lead)
Packages/ExperiencesRound02/AuroraLoom/ExperienceTests/AuroraLoomGestureWiringTests.swift   new   (agent D)
docs/architecture/aurora-loom.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md                       edit (lead)
```

**Migration**: none. **Rollback**: revert the commits; the steppers remain a complete control path.

## Parallel work

Agent B (handles, orbit, geometry tests) and agent C (gesture controller and its tests, against the contract) work in
parallel; the lead then wires the presenter, scene and controls; agent D writes the simulator wiring tests; the lead
runs every check and records only after every agent has reported.
