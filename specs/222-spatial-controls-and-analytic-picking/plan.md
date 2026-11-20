# Implementation Plan: R02-F22 — Spatial controls and analytic picking

**Branch**: `222-spatial-controls-and-analytic-picking` (spec directory only; work on `main`) | **Date**: 2026-11-20 |
**Spec**: [spec.md](spec.md)

## Summary

Beside the unchanged gesture recognizers, cameras, `Ray3` and Effects Composer: in VisualCoreMath a `Plane3`, a
`Ray3.intersect(plane:)` extension and `ScreenProjection` (screen point to world ray and back for any view-projection);
in VisualCoreScenes `SpatialHandle` and `HandleKind` with `HandlePicker` (depth-aware picking within a touch radius of at
least 22 points), `DragConstraint` and `HandleDrag` (offset-keeping, grazing-safe drags along an axis or across a plane),
`ControlHistory` (bounded, coalescing undo and redo of any `Codable` value; JSON schema 1) and `AssistiveStep` (exact
discrete steps with a spoken description). Failures are `SpatialControlError` with `r2-f22.*` codes. Research:
[research.md](research.md). Data: [data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md). Quickstart:
[quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6. **Primary dependencies**: VisualCoreMath (`Vec2`, `Vec3`, `Mat4`, `Ray3`, `RayHit3`,
`OrbitCamera`), VisualCoreScenes. No new module, dependency, GPU, GLSL or Objective-C++ code; handles are drawn by the
consuming experiences.
**Seeds**: fixtures use a fileprivate SplitMix generator seeded 2_022 (VisualCoreMathTests and VisualCoreScenesTests do
not depend on VisualCoreSimulation).
**Testing**: `swift test --package-path Packages/VisualCore`; VisualCoreRendering on sim-27.2 and sim-26.5 and
ExperiencesCreative on sim-27.2 as regression; reference regression in two chunks; script tests (run alone); isolated
timing run.
**Performance**: a pick projects each of at most 1,024 handles once; a drag update is one intersection; history and steps
are O(1) per call.
**Constraints**: additive; existing types unchanged; every result finite or nil.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I Proven renderer only | PASS — no rendering change. |
| II App-neutral API · II-a reference | PASS — generic controls; `///`; API baseline; reference regression. |
| III GPU lifecycle | PASS — none. |
| IV Host-testable | PASS — pure, host-tested. |
| VI Accessibility | PASS — 44-point minimum target; assistive steps with spoken values as an alternative to every drag. |
| IX Bounded input | PASS — handles, history depth, step ranges and viewports refused or bounded by code. |
| X Licensing and provenance | PASS — ray-plane and line-line closest points, unprojection and undo stacks are textbook; original code. |
| XI Stable identity | PASS — schema 1 stored history; newer refused. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/VisualCore/Sources/VisualCoreMath/Plane3.swift              new  Plane3, Ray3.intersect(plane:) (lead)
Packages/VisualCore/Sources/VisualCoreMath/ScreenProjection.swift    new  ScreenProjection (lead)
Packages/VisualCore/Sources/VisualCoreScenes/SpatialControlError.swift new SpatialControlError (lead)
Packages/VisualCore/Sources/VisualCoreScenes/SpatialHandles.swift    new  SpatialHandle, HandleKind, HandlePicker (agent A)
Packages/VisualCore/Sources/VisualCoreScenes/HandleDrag.swift        new  DragConstraint, HandleDrag (agent B)
Packages/VisualCore/Sources/VisualCoreScenes/ControlHistory.swift    new  ControlHistory (agent C)
Packages/VisualCore/Sources/VisualCoreScenes/AssistiveStep.swift     new  AssistiveStep (agent D)
Packages/VisualCore/Tests/VisualCoreMathTests/ScreenProjectionTests.swift (lead); VisualCoreScenesTests/HandlePickerTests.swift (A),
  HandleDragTests.swift (B), ControlHistoryTests.swift (C), AssistiveStepTests.swift (D)   new
docs/architecture/spatial-controls.md (new), docs/api/visualcore-public-api.txt, Packages/VisualCore/README.md, docs/catalog/shared-feature-map.json (lead)
```

**Migration**: none of existing data. **Rollback**: revert the commits (additive files only).

## Parallel work

Lead writes the math types and the error with their test; agents A, B, C and D write the four VisualCoreScenes files in
parallel against the contract. Lead: docs, API baseline, runs, commits.
