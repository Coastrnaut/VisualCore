# Implementation Plan: Phase 5 — Input, Animation, Scenes and Procedural Graphics

**Branch**: `006-input-animation-scenes` | **Date**: 2026-11-10 | **Spec**: [spec.md](spec.md)

## Summary

Fill the three pure stub modules from the package map: `VisualCoreMath` (vectors/matrices/quaternions,
2D and orbit cameras, easing), `VisualCoreSimulation` (fixed-step clock, xoshiro256** RNG, tweens and
timelines, particle pool/emitters/forces with NaN guard) and `VisualCoreScenes` (coordinate mapping,
pointer tracking, gesture recognizers, 2D scene graph and hit testing, mesh generators). Add GL drawing
for primitives, particles and meshes plus a touch adapter on `RenderView` in `VisualCoreRendering`,
and a standalone `Harnesses/InteractiveDemo` app with a UI test. Each subsystem is its own task with
tests written first.

## Technical Context

**Language/Version**: Swift 6.4.2 (language mode 6), GLSL ES 3.00 · **Primary Dependencies**: F02–F04
packages (`RenderHost`, `ResourceRegistry`, program cache); `simd` allowed by R2 · **Storage**: none ·
**Testing**: `swift test` (host, Swift Testing) for all pure logic incl. golden RNG sequence and
determinism checksums; XCTest simulator pixel tests (iOS 27.2 + 26.5); XCUITest for the demo ·
**Target Platform**: iOS/iPadOS 26.0+; host macOS 15 for pure modules · **Project Type**: library
packages + one harness app (XcodeGen 2.46.0, `Harnesses/InteractiveDemo/InteractiveDemo.yml`) ·
**Performance Goals**: functional only in the simulator; per-device particle/primitive cost is a
campaign-II `{device}` item (constitution V) · **Constraints**: ≤ 10 touches, particle capacity
default 10,000 / max 100,000, ≤ 8 steps per frame, main-thread GL, no ProjectM, no UIKit in pure
modules (R2) · **Scale/Scope**: ~9 subsystems, ~60 host tests, ~8 simulator tests, 1 UI test.

## Constitution Check

I PASS (drawing through the existing GLES/ANGLE host) · II PASS (app-neutral types; no ProjectM;
demo links no reference module) · II-a PASS (reference untouched; reference regression rerun) ·
III PASS (renderers allocate via the registry per generation, rebuilt on recreation, released on
teardown) · IV PASS (all math, timing, gestures, scene, particles host-tested first) · V PASS (device
cost deferred to T-F5 `{device}` task) · VI PASS (every task ticked with run-check evidence) ·
VII PASS (demo honors Reduce Motion; diagnostics readout has accessibility identifiers/labels) ·
VIII PASS (public UIKit touch APIs only; no permissions needed) · IX PASS (touch, particle, step and
mesh-resolution bounds) · X PASS (no new third-party code; algorithms from public literature, noted
in research). Post-design re-check: PASS.

## Project Structure

### Documentation (this feature)

```text
specs/006-input-animation-scenes/
├── plan.md  research.md  data-model.md  quickstart.md
├── contracts/interaction-api.md
└── tasks.md
```

### Source Code

```text
Packages/VisualCore/Sources/VisualCoreMath/{Vectors,Matrix,Quaternion,Camera2D,OrbitCamera,Easing}.swift
Packages/VisualCore/Sources/VisualCoreSimulation/{FixedStepClock,SeededRandom,Timeline (Tween + Timeline),ParticleSystem}.swift
Packages/VisualCore/Sources/VisualCoreScenes/{ViewMetrics,PointerTracker,GestureRecognizers,SceneGraph,MeshGenerators}.swift
Packages/VisualCore/Tests/{VisualCoreMathTests,VisualCoreSimulationTests,VisualCoreScenesTests}/
Packages/VisualCoreRendering/Sources/VisualCoreRendering/{RenderView+Touches,DynamicVertexBuffer,PrimitiveRenderer,ParticleRenderer,MeshRenderer}.swift
Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/{PrimitiveRendererTests,ParticleRendererTests,MeshRendererTests,TouchAdapterTests}.swift
Harnesses/InteractiveDemo/{InteractiveDemo.yml,Sources/{InteractiveDemoApp,DemoScene,DemoModel}.swift,UITests/InteractiveDemoUITests.swift}
```

**Structure Decision**: follows the package map (Math / Simulation / Scenes ownership). The map's
`VisualCoreRendering` row gains "primitive/particle/mesh drawing, touch adapter" and the dependency on
`VisualCoreSimulation` and `VisualCoreScenes` (both pure; allowed "pure modules"); the contract is
amended in the same task that adds the dependency.

Subsystem order (one task group each, tests first): math & cameras → coordinates → pointer tracking &
gestures → clock & RNG → easing & timelines → 2D scene graph → particles → GL primitives → GL particles
→ meshes & 3D draw → touch adapter → demo harness + UI test → verification.

## Complexity Tracking

None.
