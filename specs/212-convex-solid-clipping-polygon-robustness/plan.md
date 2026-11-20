# Implementation Plan: R02-F12 — Convex solid clipping & polygon robustness

**Branch**: `212-convex-solid-clipping-polygon-robustness` (spec directory only; work on `main`) | **Date**: 2026-11-19 |
**Spec**: [spec.md](spec.md)

## Summary

A pure `ConvexSolid` in VisualCoreScenes (vertices plus outward convex polygon faces) made from a box, a set of planes
bounded by a box, or a closed convex mesh; `cut(by:)` splits it by a `ClipPlane` into the kept and removed parts and
the cap polygon with exact volumes, under a size-relative tolerance with merging and degenerate removal; a
`VolumeLedger` that balances after every cut; `PolygonCleanup` for 3D polygons; a schema-1 stored form; and conversion
to `Mesh` that the existing validation accepts. No GPU code. Research: [research.md](research.md). Data:
[data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6. **Primary dependencies**: VisualCoreMath (`Vec3`), VisualCoreScenes (`Mesh`,
`MeshBuilder`, `Mesh.validate(requireClosed:)`). No new module or dependency; no GL, GLSL or Objective-C++.
**Seeds**: fixtures use the `SDFTestRandom` LCG of the VisualCoreScenes tests with seed 2_012; the library has no
randomness.
**Testing**: `swift test --package-path Packages/VisualCore` (all of it); VisualCoreRendering on sim-27.2 and sim-26.5
and ExperiencesCreative on sim-27.2 as regression (no rendering change); reference regression in two chunks; script
tests.
**Performance**: bounded by arithmetic — a cut is O(V + Σ face corners) ≤ 4,096 + 1,024 × 256 operations; 1,000 seeded
cuts on a box stay small (a box cut 1,000 times by random planes through its interior keeps at most ~1,000 faces, capped
at 1,024 and refused beyond); each test < 10 s.
**Constraints**: additive; mesh code and its tests unchanged.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I Proven renderer only | PASS — no rendering change. |
| II App-neutral API · II-a reference | PASS — generic geometry; `///`; API baseline; reference regression. |
| III GPU lifecycle | PASS — no GPU object. |
| IV Host-testable | PASS — pure, host-tested. |
| IX Bounded input | PASS — 4,096 vertices, 1,024 faces, 256 corners, 65,536 ledger entries, finite inputs. |
| X Licensing and provenance | PASS — standard polygon clipping (Sutherland–Hodgman 1974) and the divergence theorem, cited. |
| XI Stable identity | PASS — stored form schema 1. |
| XIII Code-only visuals | PASS. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/VisualCore/Sources/VisualCoreScenes/ConvexSolidError.swift    new  ConvexSolidError + reasonCode
Packages/VisualCore/Sources/VisualCoreScenes/ClipPlane.swift           new  ClipPlane (unit normal, offset), signed distance
Packages/VisualCore/Sources/VisualCoreScenes/PolygonCleanup.swift      new  PolygonCleanup.clean(_:normal:tolerance:)
Packages/VisualCore/Sources/VisualCoreScenes/ConvexSolid.swift         new  ConvexSolid (box, planes, mesh), volume, tolerance, cut(by:), mesh()
Packages/VisualCore/Sources/VisualCoreScenes/VolumeLedger.swift        new  VolumeLedger (record, balance)
Packages/VisualCore/Sources/VisualCoreScenes/ConvexSolidCoding.swift   new  ConvexSolidDocument (schema 1)
Packages/VisualCore/Tests/VisualCoreScenesTests/ConvexSolidTests.swift, ConvexCutTests.swift, PolygonCleanupTests.swift, VolumeLedgerTests.swift, ConvexSolidCodingTests.swift   new
docs/architecture/convex-cutting.md (new), docs/api/visualcore-public-api.txt, Packages/VisualCore/README.md, docs/catalog/shared-feature-map.json (lead)
```

**Migration**: none. **Rollback**: revert the commits.

## Parallel work

Agent A: ConvexSolidError, ClipPlane, PolygonCleanup and their tests (no dependency). Agent B (after A): ConvexSolid
and the cut with tests. Agent C (after B): VolumeLedger, the stored form and their tests. Lead: docs, API baseline,
runs, commits.
