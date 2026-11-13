# Implementation Plan: R02-F04 — GPU resource ownership and pipeline lifetime

**Branch**: `204-gpu-resource-ownership-and-pipeline-lifetime` (spec directory only; work on `main`) | **Date**: 2026-11-13 | **Spec**: [spec.md](spec.md)

## Summary

Reuse the existing ownership rules and prove them on both runtimes; fix the program-cache eviction defect with a
retired set; add a pure `RenderState` with presets and a rendering `Pipeline` applied by `GLState.apply`; add
depth-capable offscreen targets. Audit: [research.md](research.md) §0.

## Technical Context

**Language/Version**: Swift 6. **Primary Dependencies**: existing packages; OpenGL ES 3.0 via ANGLE (CVisualCoreGL).
**Storage**: none. **Testing**: host `swift test --package-path Packages/VisualCore` (RenderState);
`VisualCoreRenderingTests` on sim-27.2 and sim-26.5 (cache, pipeline, depth); ExperiencesCreative on sim-27.2.
**Target Platform**: iOS 26+. **Performance Goals**: each new test < 5 s. **Constraints**: no device steps;
existing callers unchanged (defaults). **Scale/Scope**: 2 new source files, 3 modified, 3 test files.

## Constitution Check

| Principle | Result |
|---|---|
| I Proven renderer only | PASS — OpenGL ES through ANGLE only. |
| II App-neutral API | PASS — generic state/targets; `///`; API baseline. |
| II-a Preserve the reference | PASS — reference regression in two chunks. |
| III GPU lifecycle and threads | PASS — core of the feature; main-thread `@MainActor` APIs; generation checks; retired set released at context end. |
| IV Host-testable, test-first | PASS — pure RenderState host tests; GPU tests before code. |
| V Implementation before devices | PASS — device memory measurement is a {device} task. |
| VI Evidence | PASS. VII UI | N/A. VIII Public APIs | PASS. IX Bounded input | PASS (size limits). X Licensing | PASS. XI One app | PASS. XII No ads | PASS. XIII Code visuals | PASS. |

## Project Structure

```text
Packages/VisualCore/Sources/VisualCoreShaderSource/RenderState.swift                    new
Packages/VisualCore/Tests/VisualCoreShaderSourceTests/RenderStateTests.swift            new
Packages/VisualCoreRendering/Sources/VisualCoreRendering/Pipeline.swift                 new   Pipeline
Packages/VisualCoreRendering/Sources/VisualCoreRendering/GLState.swift                  modify  apply(_:resources:)
Packages/VisualCoreRendering/Sources/VisualCoreRendering/ResourceRegistry.swift         modify  retired set, evictionCount, depth option, pool key
Packages/VisualCoreRendering/Sources/VisualCoreRendering/GPUObjects.swift               modify  RenderTarget.depthRenderbuffer
Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/ProgramCacheTests.swift     modify  amended eviction test + held-program draw test
Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/PipelineTests.swift         new
Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/DepthTargetTests.swift      new
docs/api/visualcore-public-api.txt, Packages/VisualCoreRendering/README.md, Auto-Creator.md §13   modify (lead)
```

**Dependency direction**: VisualCoreRendering → VisualCoreShaderSource (existing). **Public API**:
[contracts/api.md](contracts/api.md). **Lifecycle/threads**: all new GPU APIs are `@MainActor`; retired programs and
depth renderbuffers carry the context generation and are released in `contextWillEnd()` before `abandonAll()`.
**Schemas**: none persisted.

## Tests by layer

Host: RenderStateTests. Simulators 27.2/26.5: whole VisualCoreRenderingTests target (existing ownership tests prove
story 4). App/experiences: ExperiencesCreative on 27.2 and A01–A03 verification (no regression).

## Commands — see [quickstart.md](quickstart.md). Rollback: revert the feature's commits; defaults keep old behavior.

## Parallel work

Agent A: RenderState + tests, then Pipeline.swift, GLState.apply, PipelineTests (one chain). Agent B:
ResourceRegistry.swift, GPUObjects.swift, ProgramCacheTests.swift, DepthTargetTests.swift. Lead: baseline, README,
section 13, builds, regression.

## Complexity Tracking — none.
