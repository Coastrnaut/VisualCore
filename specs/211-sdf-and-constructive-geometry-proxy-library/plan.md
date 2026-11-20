# Implementation Plan: R02-F11 — SDF and constructive geometry proxy library

**Branch**: `211-sdf-and-constructive-geometry-proxy-library` (spec directory only; work on `main`) | **Date**:
2026-11-19 | **Spec**: [spec.md](spec.md)

## Summary

A constructive signed-distance description `SDFShape` in VisualCoreScenes, evaluated on the CPU (distance, normal) and
compiled to GLSL by a pure generator; a sphere-tracing march `SDFMarch` with a conservative and a fast (over-relaxed,
Keinert fallback) option; a deterministic volume sampler `SDFVolume`; a versioned JSON form; and a shader include
`vc/sdfshape.glsl` (plane, rounded box, capsule, hard set operations, march loop, normal) beside the unchanged
`vc/sdf.glsl`. The CPU proxy decides outcomes; the shader draws the same description. Research: [research.md](research.md).
Data: [data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6, GLSL ES 3.00. **Primary dependencies**: VisualCoreMath (`Vec3`, `Quat`, `Mat4`, `Ray3`,
`RayHit3`), VisualCoreScenes (home), VisualCoreRendering (`ShaderBundle.visualCoreLibrary`, `FullScreenShaderScene`,
`RenderHost`, the safe compilation of R02-F06) for the parity tests only. No new module, no new dependency, no
Objective-C++ bridge (no new GL call).
**Seeds**: test fixtures use a local 64-bit LCG with seed 2_011 (the VisualCoreScenes test target may also use
`SeededRandom`); the library itself has no randomness.
**Testing**: `swift test --package-path Packages/VisualCore` (distances, march, volume, stored form); VisualCoreRendering
on sim-27.2 and sim-26.5 (shader parity: distance image and hit mask); ExperiencesCreative on sim-27.2; reference
regression in two chunks; script tests.
**Performance**: bounded by arithmetic — a distance is O(nodes) ≤ 256 node evaluations; a march ≤ 4,096 steps; a 64³
volume is 262,144 distance evaluations (well under 10 s in tests); the generated shader inlines ≤ 256 nodes.
**Shader limits**: fixed loop bound (`VC_SDF_MAX_STEPS`, default 128) as a define; highp; generated function names
prefixed `vc_sdfShape`.
**Constraints**: additive; `vc/sdf.glsl`, `Ray3` and the mesh code unchanged.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I Proven renderer only | PASS — generated GLSL for the existing library and context; no new GL path. |
| II App-neutral API · II-a reference | PASS — generic geometry API; `///`; API baseline; reference regression. |
| III GPU lifecycle | PASS — no new GPU object type; parity tests check zero leaks. |
| IV Host-testable | PASS — all decisions on the CPU, host-tested. |
| IX Bounded input | PASS — 256 nodes, depth 32, finite positive sizes, step budget ≤ 4,096, grid ≤ 256³. |
| X Licensing and provenance | PASS — distance formulas (Quilez, MIT) and Keinert et al. 2014 cited in docs. |
| XI Stable identity | PASS — stored form schema 1; newer refused, never trapped. |
| XIII Code-only visuals | PASS. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/VisualCore/Sources/VisualCoreScenes/SDFShape.swift          new  SDFShape (indirect enum), validation, distance, normal, node count, depth
Packages/VisualCore/Sources/VisualCoreScenes/SDFError.swift          new  SDFError + reasonCode
Packages/VisualCore/Sources/VisualCoreScenes/SDFMarch.swift          new  SDFMarchOptions, SDFMarchResult, SDFMarch.march
Packages/VisualCore/Sources/VisualCoreScenes/SDFVolume.swift         new  SDFVolume.sample (count, volume, digest)
Packages/VisualCore/Sources/VisualCoreScenes/SDFCoding.swift         new  SDFDocument (schema 1 JSON) encode/decode
Packages/VisualCore/Sources/VisualCoreScenes/SDFShaderSource.swift   new  SDFShape.glslFunction(name:) generator
Packages/VisualCore/Tests/VisualCoreScenesTests/SDFShapeTests.swift, SDFMarchTests.swift, SDFVolumeTests.swift, SDFCodingTests.swift   new
Packages/VisualCoreRendering/Sources/VisualCoreRendering/GLSL/vc/sdfshape.glsl   new  vc_sdPlane, vc_sdRoundBox, vc_sdCapsule, vc_opUnion/Intersect/Subtract, vc_opSmoothUnion
Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/SDFShaderParityTests.swift   new
docs/architecture/sdf-proxies.md (new), docs/api/visualcore-public-api.txt, package READMEs, docs/catalog/shared-feature-map.json (lead)
```

**Migration**: none (new stored form, schema 1). **Rollback**: revert the commits.

## Parallel work

Agent A: SDFShape, SDFError, SDFCoding and tests. Agent B (after A's API is in the contract, in parallel on its own
files): SDFMarch, SDFVolume and tests. Agent G (after A): the generator, `vc/sdfshape.glsl` and the parity tests. Lead:
the include list of `ShaderBundleTests.swift`, docs, API baseline, runs, commits.
