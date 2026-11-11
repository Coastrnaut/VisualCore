# Implementation Plan: Phase 6 — Standalone VisualCore Showcase Application

**Branch**: `007-showcase-app` | **Date**: 2026-11-10 | **Spec**: [spec.md](spec.md)

## Summary

A SwiftUI iOS/iPadOS app under `Showcase/` (target and scheme in the repository-root XcodeGen `project.yml`)
with five scenes built only from VisualCore packages on the ANGLE render host: (1) gradient + texture from
bundled `.glsl` shaders with an include and a generated PNG, (2) animated geometry (meshes + timeline),
(3) touch-interactive distortion (drag drives a `distort`-style ripple pass), (4) particles (drag/pinch),
(5) multi-pass post-processing (`EffectScene`, ≥ 3 passes, toggle, Reduce Flashing). A diagnostics overlay
shows live host/ledger state and simulates context loss. A four-layer dependency audit script proves no
ProjectM engine/preset/bridge dependency, with contaminated fixtures. XCUITest smoke tests run on iOS 27.2
and 26.5. One small framework addition: `Texture.upload(rgba:)` in VisualCoreRendering.

## Technical Context

**Language/Version**: Swift 6.4.2 (language mode 6), GLSL ES 3.00, Python 3 (audit) · **Primary
Dependencies**: VisualCoreRendering, VisualCoreEffects, VisualCoreMath/Simulation/Scenes/ShaderSource/
Diagnostics/EffectsGraph (F02–F05); no third-party code · **Storage**: none (settings in `@AppStorage`) ·
**Testing**: XCUITest smoke tests (iOS 27.2 + 26.5 simulators), simulator unit tests for the scene catalog
and texture upload, Python tests for the audit (`scripts/test_scripts.py`) · **Target Platform**:
iOS/iPadOS 26.0+ · **Project Type**: iOS app + XcodeGen root `project.yml` (2.46.0) · **Performance
Goals**: functional only in the simulator; device frame rate/thermal are campaign-II `{device}` items ·
**Constraints**: zero ProjectM dependency (R1 + audit), main-thread GL, public APIs only, no network, no
permissions · **Scale/Scope**: 5 scenes, ~12 source files, 1 audit script, ~8 UI tests.

## Constitution Check

I PASS (only `RenderHost`/ANGLE path) · II PASS (app-neutral APIs; audit enforces no ProjectM) · II-a PASS
(reference read-only, regression rerun) · III PASS (one host per open scene, destroyed on close; scenes
release resources in teardown; context loss tested) · IV PASS (catalog and audit logic unit-tested; GPU
via simulator tests) · V PASS (device metrics deferred, T-F6 `{device}`) · VI PASS (run-check evidence per
task) · VII PASS (SwiftUI, VoiceOver, Dynamic Type, Reduce Motion/Flashing) · VIII PASS (public APIs, no
permissions, compliance script) · IX PASS (bounded touch/particles via F05 bounds; bundled inputs only) · X
PASS (original generated texture and shaders; no third-party assets). Post-design: PASS.

## Project Structure

### Documentation

```text
specs/007-showcase-app/{plan,research,data-model,quickstart}.md, contracts/showcase-contract.md, tasks.md
```

### Source Code

```text
project.yml                                   # root XcodeGen spec: Showcase + ShowcaseTests + ShowcaseUITests
Showcase/README.md
Showcase/App/{ShowcaseApp,SceneCatalog,SceneHostView,DiagnosticsOverlay,ShowcaseSettings}.swift
Showcase/App/Scenes/{GradientTextureScene,AnimatedGeometryScene,DistortionScene,ParticleShowcaseScene,PostProcessingScene}.swift
Showcase/App/BundleShaders.swift              # loads Shaders/*.glsl into a ShaderLibrary
Showcase/Shaders/{common.glsl,gradient.vert,gradient.frag,broken.frag}
Showcase/Resources/{checker.png,Assets.xcassets}
Showcase/Tests/Unit/{SceneCatalogTests,BundleShaderTests}.swift
Showcase/Tests/UI/ShowcaseSmokeUITests.swift
scripts/audit_showcase_dependencies.py + tests/fixtures in scripts/fixtures/showcase_audit/
Packages/VisualCoreRendering/Sources/VisualCoreRendering/GPUObjects.swift   # + Texture.upload(rgba:)
```

**Structure Decision**: README §4 layout (`Showcase/App, Resources, Shaders, Tests`) and root `project.yml`
(README §8). Scenes are implemented one per task.

## Complexity Tracking

None.
