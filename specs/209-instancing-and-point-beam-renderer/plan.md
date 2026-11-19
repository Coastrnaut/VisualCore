# Implementation Plan: R02-F09 — Instancing and point/beam renderer

**Branch**: `209-instancing-and-point-beam-renderer` (spec directory only; work on `main`) | **Date**: 2026-11-19 |
**Spec**: [spec.md](spec.md)

## Summary

Two renderers on the existing context and registry: `InstancedMeshRenderer` (one mesh, many transforms and colours,
one instanced draw, the lighting and fog of `MeshRenderer`) and `BeamRenderer` (view-facing beams and points with a
Gaussian cross-section and round ends), plus a pure back-to-front ordering and a pure beam profile reference.
Research: [research.md](research.md). Data: [data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md).
Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6, GLSL ES 3.00. **Primary dependencies**: VisualCoreRendering (registry, buffers,
`ShaderProgram`, `vcglDrawElementsInstanced`, `vcglDrawArraysInstanced`, `vcglVertexAttribDivisor`), VisualCoreScenes
(`Mesh`), VisualCoreMath (`Vec3`, `Vec4`, `Mat4`). No new dependency.
**Testing**: `swift test --package-path Packages/VisualCore` (ordering, profile); VisualCoreRendering on sim-27.2 and
sim-26.5 (renderers); ExperiencesCreative on sim-27.2; reference regression in two chunks.
**Performance goals**: bounded by arithmetic: one draw per call; at most 16,384 mesh instances (64 B + 16 B each) and
65,536 beams (48 B each) per call; each test < 10 s. **Constraints**: additive; existing renderers unchanged.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I Proven renderer only | PASS — same context, registry and state handling; no second renderer path. |
| II App-neutral API · II-a reference | PASS — generic; `///`; API baseline; reference regression. |
| III GPU lifecycle | PASS — programs and buffers from the registry, rebuilt after a context rebuild, released. |
| IV Host-testable | PASS — ordering and profile pure and host-tested. |
| IX Bounded input | PASS — instance limits; finite inputs; positive widths. |
| XIII Code-only visuals | PASS. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/VisualCore/Sources/VisualCoreScenes/InstanceOrder.swift        new  InstanceOrder.backToFront(depths:)
Packages/VisualCore/Sources/VisualCoreScenes/BeamProfile.swift          new  BeamProfile.falloff, coverage, distanceToSegment
Packages/VisualCore/Tests/VisualCoreScenesTests/InstanceOrderTests.swift, BeamProfileTests.swift   new
Packages/VisualCoreRendering/Sources/VisualCoreRendering/InstancedMeshRenderer.swift   new  MeshInstance, InstancedMeshRenderer
Packages/VisualCoreRendering/Sources/VisualCoreRendering/BeamRenderer.swift            new  BeamInstance, BeamBlend, BeamRenderer
Packages/VisualCoreRendering/Sources/VisualCoreRendering/InstancingError.swift         new  InstancingError
Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/InstancedMeshRendererTests.swift, BeamRendererTests.swift   new
docs/api/visualcore-public-api.txt, Packages/VisualCoreRendering/README.md, docs/catalog/shared-feature-map.json (lead)
```

**Migration**: none. **Rollback**: revert the commits.

## Parallel work

Agent P: the pure ordering and profile with tests. Agent G (after P): both renderers and their tests. Lead: docs,
API baseline, runs, commits.
