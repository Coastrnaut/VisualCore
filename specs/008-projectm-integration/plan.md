# Implementation Plan: Phase 7 — ProjectM Integration and Regression Hardening

**Branch**: `008-projectm-integration` | **Date**: 2026-11-10 | **Spec**: [spec.md](spec.md)

## Summary

Build `Harnesses/ProjectMReference` (own `ProjectMReference.yml`), the only target allowed to link the reference
`ProjectMBridge` (rule R1). A `ProjectMScene: RenderScene` creates the **unmodified** `ProjectMEngine` with
VisualCore's `vcEGLLoadProc`, feeds a deterministic synthesized signal, sizes the viewport from the host and renders
into the host framebuffer; it recreates the engine (and reloads the preset) per context generation and releases it
with its context current. Batch 2a adds an app-neutral `GLState.resetForVisualCore(...)` helper to
VisualCoreRendering and proves VisualCore effects (EffectScene with color swap / flash limiter) run over the engine
output. Batch 2 adds the lockstep A/B baseline (path A = reference sequence into an offscreen framebuffer, path B =
VisualCore host) and lifecycle stress tests. Each batch records before/after evidence in the migration log; the
full reference regression runs before and after. The reference stays untouched.

## Technical Context

**Language/Version**: Swift 6.4.2 (language mode 6), Objective-C (reference bridge, unmodified) · **Primary
Dependencies**: VisualCoreRendering + VisualCoreEffects (local), reference `ProjectMBridge` (local path, read-only)
with `Build/ProjectM.xcframework` built by the reference's own script at `c88894e` · **Storage**: none · **Testing**:
hosted XCTest in the harness app on iOS 27.2 and 26.5 simulators; VisualCoreRendering simulator tests for the GL
state helper; reference baseline sequence; `check_dependencies.py` (R1) · **Target Platform**: iOS 26.0+ simulators
(device runs in campaign II) · **Project Type**: harness app (XcodeGen 2.46.0) + one small framework addition ·
**Performance Goals**: functional only (constitution V) · **Constraints**: reference read-only and pins unchanged
(FR-F709, FR-F110), main-thread GL, LGPL engine stays a dynamic framework, harness not distributed · **Scale/Scope**:
~6 harness source files, ~8 harness tests, 1 framework helper + test, 2 migration-log rows.

## Constitution Check

I PASS (engine on the existing ANGLE path through RenderHost; ANGLE revision untouched) · II PASS (ProjectM types
only in the harness; R1 enforced) · II-a PASS (reference read-only; clean checks and full regression before/after;
pin change already covered by ADR-0005) · III PASS (engine per context generation, released with context current;
GL state handoff explicit) · IV PASS (pure parts — PCM generator, image diff — unit-tested; GPU paths
simulator-tested) · V PASS (device behavior deferred) · VI PASS (before/after evidence per batch) · VIII PASS
(no capture, no permissions, public APIs; reference's `OpenGLES` link is the reference's own unchanged choice) · X
PASS (LGPL: engine framework dynamic, harness not distributed, recorded in research). Post-design: PASS.

## Project Structure

```text
specs/008-projectm-integration/{plan,research,data-model,quickstart}.md, contracts/projectm-adapter.md, tasks.md
Harnesses/ProjectMReference/ProjectMReference.yml
Harnesses/ProjectMReference/Sources/{ProjectMReferenceApp,ProjectMScene,SyntheticSignal,EngineFramebufferPath,ImageDiff}.swift
Harnesses/ProjectMReference/Tests/{HarnessLinkTests,ProjectMSceneTests,BaselineComparisonTests,EngineNoiseFloorTests,LifecycleStressTests,EffectsOverEngineTests,SyntheticSignalTests}.swift
Harnesses/ProjectMReference/README.md
Packages/VisualCoreRendering/Sources/VisualCoreRendering/GLState.swift          # batch 2a helper
Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/GLStateTests.swift
Packages/VisualCoreRendering/Sources/VisualCoreRendering/RenderScene.swift      # RenderContext.redirected (T-F706)
Packages/VisualCoreRendering/Sources/VisualCoreEffects/EffectScene.swift         # content rendered into its scene target
docs/architecture/migration-log.md                                              # rows 2a, 2 + retained section
```

**Structure Decision**: contract `tests-adapter-submodule-regression.md` (FR-F109): harness-only, own spec. Batches
in order: 2a (helper + effects over engine) then 2 (engine on host + baseline + lifecycle).

## Complexity Tracking

None.
