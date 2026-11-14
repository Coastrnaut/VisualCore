# Implementation Plan: R02-F05 — Procedural mesh compiler and mesh validation

**Branch**: `205-procedural-mesh-compiler-and-mesh-validation` (spec directory only; work on `main`) | **Date**: 2026-11-13 | **Spec**: [spec.md](spec.md)

## Summary

Extend VisualCoreScenes' existing `Mesh` with a welding builder, five shape families (parametric surface, revolution,
extrusion, tube, bevelled box), crease-aware and flat normals, bounds, a content digest and a validator with a bounded,
ordered report. Everything is pure CPU code in the VisualCore package; the existing `MeshRenderer` draws the results.
Research: [research.md](research.md).

## Technical Context

**Language/Version**: Swift 6 (strict concurrency; value types, `Sendable`). **Primary Dependencies**: VisualCoreMath
(`Vec2`, `Vec3`, `StableHash`); no Foundation in the new files. **Storage**: none (meshes are rebuilt, never stored).
**Testing**: host `swift test --package-path Packages/VisualCore` (VisualCoreScenesTests); a runtime digest and draw
test in VisualCoreRenderingTests on sim-27.2 and sim-26.5. **Target Platform**: iOS 26+ (host tests on macOS).
**Performance Goals**: a mesh at the budget builds and validates in < 1 s on the host; each test < 10 s.
**Constraints**: additive public API only; existing generators' outputs unchanged; deterministic, no clock or GPU.
**Scale/Scope**: 6 new source files, 7 new test files, 1 runtime test; README, API baseline, determinism doc.

## Constitution Check

| Principle | Result |
|---|---|
| I Proven renderer only | PASS — no new draw path; `MeshRenderer` draws compiled meshes. |
| II App-neutral API | PASS — generic geometry; `///` on every public symbol; API baseline updated. |
| II-a Preserve the reference | PASS — reference regression in two chunks. |
| III GPU lifecycle and threads | PASS — pure value types; no GPU state. |
| IV Host-testable, test-first | PASS — host tests written before each file. |
| V Implementation before devices | PASS — no device step. |
| VI Evidence | PASS — committed digests; run-checks. |
| VII UI and accessibility | N/A (no interface). |
| VIII Public APIs only | PASS. IX Bounded input | PASS — budgets, clamped resolutions. X Licensing | PASS — original code. |
| XI One app · XII No ads · XIII Code-only visuals | PASS. |

Post-design re-check: PASS (no new module, dependency direction VisualCoreScenes → VisualCoreMath unchanged).

## Project Structure

```text
Packages/VisualCore/Sources/VisualCoreScenes/
  MeshBuilder.swift          new   MeshBuilder (welding), MeshBudget, MeshError
  MeshShapes.swift           new   Mesh.surface, .revolution, .extrusion, .tube, .bevelledBox; PathFrames
  MeshNormals.swift          new   Mesh.withSmoothNormals(creaseAngle:), .withFlatNormals()
  MeshBounds.swift           new   MeshBounds (.empty / box + sphere), Mesh.bounds
  MeshDigest.swift           new   Mesh.digest (SHA-256 hex via StableHash)
  MeshValidation.swift       new   MeshProblem, MeshProblem.Kind, MeshReport, MeshSummary, Mesh.validate(...)
  MeshGenerators.swift       unchanged
Packages/VisualCore/Tests/VisualCoreScenesTests/
  MeshBuilderTests.swift, MeshShapeTests.swift, MeshNormalsTests.swift, MeshBoundsTests.swift,
  MeshDigestTests.swift, MeshValidationTests.swift, MeshCompatibilityTests.swift     new
Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/
  MeshCompilerRuntimeTests.swift   new   committed digests on the simulator; a tube drawn by MeshRenderer
docs/api/visualcore-public-api.txt, Packages/VisualCore/README.md, docs/architecture/determinism.md   modify (lead)
```

**Dependency direction**: VisualCoreScenes → VisualCoreMath (existing). **Public API**: [contracts/api.md](contracts/api.md).
**Errors**: typed `MeshError` (budget, invalid input) from builders; validation never throws, it reports.
**Migration**: none (no stored data). **Rollback**: revert the feature's commits; nothing existing changes.

## Tests by layer

Host: all VisualCoreScenesTests (new and existing `MeshTests`). Simulators 27.2/26.5: whole VisualCoreRendering scheme
(including MeshRendererTests and the new runtime test). Regression: ExperiencesCreative on 27.2; reference regression in
two chunks.

## Parallel work

Agent A: MeshBuilder + MeshDigest + MeshBounds and their tests. Agent B: MeshNormals + MeshValidation and tests.
Agent C: MeshShapes and MeshShapeTests (uses A's builder API from contracts/api.md). Lead: compatibility and runtime
tests, README, API baseline, determinism doc, every run and commit.
