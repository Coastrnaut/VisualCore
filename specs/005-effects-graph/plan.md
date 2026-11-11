# Implementation Plan: Phase 4 — Reusable Effects and Render Pipelines

**Branch**: `005-effects-graph` | **Date**: 2026-11-10 | **Spec**: [spec.md](spec.md)

## Summary

Pure `VisualCoreEffectsGraph`: Codable graph description, validation (all FR-F402 errors), Kahn
ordering with declaration-order tie-break, memory estimate, parameter schemas, and a flash-limiter
model. iOS `VisualCoreEffects`: one `EffectPass` per built-in type (GLSL ES 3.00 programs from the
registry, full-screen triangle), an `EffectRenderer` that runs a validated graph with pooled targets
and feedback histories, pass-through on failure, and `EffectScene` wrapping any `RenderScene`.

## Technical Context

Swift 6.4.2; packages from F02/F03 (`ResourceRegistry`, `ShaderLibrary`, pool) · Testing: `swift test`
(graph fixtures, limiter model); simulator pixel tests per pass on iOS 27.2 + 26.5 · Constraints:
≤ 32 passes, 256 MiB quota, main-thread GL, no ProjectM · Device performance: `{device}` campaign II only.

## Constitution Check

I PASS (GLES via ANGLE) · II PASS (no ProjectM) · III PASS (targets/programs per generation, rebuilt on recreation) ·
IV PASS (validation + limiter model host-tested) · V PASS (perf deferred) · VI PASS · VII PASS (Reduce Flashing) ·
IX PASS (pass/memory quotas, cycle rejection). Post-design: PASS.

## Project Structure

```text
Packages/VisualCore/Sources/VisualCoreEffectsGraph/{EffectGraph,EffectGraphValidation,PassSchemas,FlashLimiterModel}.swift
Packages/VisualCore/Tests/VisualCoreEffectsGraphTests/{ValidationTests,FlashLimiterModelTests}.swift + Fixtures/*.json
Packages/VisualCoreRendering/Sources/VisualCoreEffects/{EffectPasses,EffectShaders,EffectRenderer,EffectScene}.swift
Packages/VisualCoreRendering/Tests/VisualCoreEffectsTests/{PassPixelTests,EffectRendererTests}.swift
```

Effects are implemented one per task (copy → colorMatrix → blur → bloom → distort → composite →
feedback → flashLimit), each with its pixel test before the next.

## Complexity Tracking

None.
