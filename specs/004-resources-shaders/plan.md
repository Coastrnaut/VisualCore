# Implementation Plan: Phase 3 — Shared GPU Resource and Shader Services

**Branch**: `004-resources-shaders` | **Date**: 2026-11-10 | **Spec**: [spec.md](spec.md)

## Summary

Pure, host-tested shader preprocessing (includes, line maps, version/defines, limits, info-log
parsing) and resource accounting (budgets, counters, stale/leak detection) in `Packages/VisualCore`;
GL-backed `ResourceRegistry`, `Texture`, `Buffer`, `RenderTarget`, `ShaderProgram` (uniform table,
cache) in `VisualCoreRendering`, owned one-per-`RenderHost`. Sample scenes move onto them.

## Technical Context

**Language/Version**: Swift 6.4.2 · **Primary Dependencies**: generated `CVisualCoreGL`, `CryptoKit`-free SHA-256 (pure Swift, host-testable) · **Storage**: N/A ·
**Testing**: `swift test` (ShaderSource, ResourceLedger); simulator tests iOS 27.2 + 26.5 (compile errors from real ANGLE logs, leaks, budgets, cache, uniforms, framebuffer readback) ·
**Target**: iOS 26+ · **Constraints**: main-thread GL; no ProjectM; no dlsym ·
**Scale**: ~8 Swift files + tests.

## Public APIs (contracts/resources-shaders-api.md)

`VisualCoreShaderSource`: `ShaderLibrary`, `ExpandedShader`, `LineMap`, `ShaderDiagnostic`,
`ShaderSourceError`, `InfoLogParser`, `SHA256` (internal).
`VisualCoreDiagnostics`: `ResourceKind`, `ResourceBudget`, `ResourceLedger`.
`VisualCoreRendering`: `RenderContext.resources` → `ResourceRegistry` (`makeTexture`, `makeBuffer`,
`makeRenderTarget`, `program(vertex:fragment:defines:library:)`, `release`, `stats`, `trimPools`),
`GPUHandle`, `Texture`, `GPUBuffer`, `RenderTarget`, `ShaderProgram` (`use`, `set(_:float/vec2/vec3/vec4/int/mat4)`),
`ShaderError`.

## Package dependencies

`VisualCoreRendering` → `VisualCoreShaderSource`, `VisualCoreDiagnostics` (already declared). No new
external dependencies. R1–R5 unchanged.

## Test strategy

Host: include expansion/line map/limits/cycles/version/defines/variants, info-log parsing (fixture
strings captured from real ANGLE output in a simulator test), SHA-256 vectors, ledger budgets/stale/leaks.
Simulator: real compile errors mapped to file/line, failed replacement keeps old program, cache hit
counting + clear on recreation + LRU bound, uniform validation, budget refusal, framebuffer render +
readback, leak-free after 100 recreations, sample scenes unchanged (existing pixel tests).

## Incremental ProjectM migration

Reference unchanged (II-a). Migration-log boundary **2a (planned F07)**: the engine renders through the
VisualCore host while VisualCore services allocate in the same context; regression = reference tests
+ harness pixel check.

## Constitution Check

I PASS (ANGLE GL table only) · II/II-a PASS · III PASS (per-host registry, generations) · IV PASS
(pure parts host-tested) · V PASS · VI PASS · IX PASS (64 KiB/depth 8/cycle limits) · X PASS
(color-space policy documented). Post-design: PASS.

## Project Structure

```text
Packages/VisualCore/Sources/VisualCoreShaderSource/{ShaderLibrary,LineMap,InfoLogParser,SHA256}.swift
Packages/VisualCore/Sources/VisualCoreDiagnostics/ResourceLedger.swift
Packages/VisualCore/Tests/VisualCoreShaderSourceTests/*.swift, VisualCoreDiagnosticsTests/ResourceLedgerTests.swift
Packages/VisualCoreRendering/Sources/VisualCoreRendering/{ResourceRegistry,GPUObjects,ShaderProgram}.swift
Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/{ShaderProgramTests,ResourceRegistryTests}.swift
docs/rendering/color-space.md
```

## Complexity Tracking

None.
