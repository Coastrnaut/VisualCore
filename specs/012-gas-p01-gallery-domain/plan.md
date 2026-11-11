# Implementation Plan: Generative Art Studio — Phase 01 Gallery and domain contract

**Branch**: `012-gas-p01-gallery-domain` | **Date**: 2026-11-10 | **Spec**: [spec.md](spec.md) | **Gate**: A01-P01

## Summary

This is the smallest vertical slice: a gallery of four scene families, a deterministic and versioned composition
document, and live rendering through the VisualCore host. Reusable parts are built in VisualCore first (Principle II):

- new pure module `VisualCoreParameters`: schemas, resolution, palettes, presets, stable hash;
- `VisualCoreRendering`: `ShaderBundle` for bundle loading, plus the bundled GLSL include library `vc/*.glsl`;
  `FullScreenShaderScene`; and the uniform-array setter `ShaderProgram.set(_:vec3Array:)`;
- `VisualCoreUI`: `RenderSurface`;
- `VisualCoreTestSupport`: `ImageComparison`.

The app adds the product content: four families with presets and shaders, the document rules, and the gallery and
scene screens. The Showcase migrates to `ShaderBundle`.

## Technical Context

**Language/Version**: Swift 6.4.2, GLSL ES 3.00 · **Primary Dependencies**: VisualCore packages only ·
**Storage**: none (documents encode and decode in memory; files arrive in Phase 03) · **Testing**:
- host `swift test` for VisualCore and `GenerativeArtStudioCore`;
- simulator package tests for VisualCoreRendering, VisualCoreUI and Effects;
- app unit tests (hosted, pixel comparisons) and UI tests on iOS 27.2 and 26.5;
- Showcase tests, the reference regression, and the public/documented API and contract checks.

**Target Platform**: iOS/iPadOS 26.0+ · **Performance Goals**: none claimed (constitution V); preview work is bounded
(particles replay ≤ 7,200 fixed steps, ≤ 10,000 particles; full-screen shaders are a single pass) · **Constraints**:
- main-thread GL through `RenderHost` only;
- no permissions or networking;
- no ProjectM linkage.

**Scale/Scope**: 1 new VisualCore module, 4 extended modules, 1 app package, 4 shaders, 2 screens.

## Constitution Check

| Principle | Status |
|---|---|
| I Proven renderer | PASS: every draw goes through RenderHost and ResourceRegistry; no EGL in the app |
| II Maximize reuse | PASS: the six reusable pieces are VisualCore modules with tests, docs and a baseline update |
| II-a Reference | PASS: the reference regression reruns after the VisualCore changes |
| III GPU lifecycle | PASS: scenes rebuild from the document on context loss; leak sweep per family |
| IV Host-testable | PASS: `VisualCoreParameters` and `GenerativeArtStudioCore` are pure |
| V Simulator only | PASS |
| VI Evidence | PASS: run-check for every task |
| VII Accessible UI | PASS: labels, hints, canvas description, Dynamic Type |
| VIII Privacy | PASS: offline, no permissions |
| IX Bounded input | PASS: documents validated, values clamped, non-finite rejected, sizes capped |
| X Licensing | PASS: all shaders and palettes are original, recorded in the app credits note |
| A01 rules | PASS |

## Project Structure

```text
Packages/VisualCore/Package.swift                                   # + VisualCoreParameters target/product/tests
Packages/VisualCore/Sources/VisualCoreParameters/{Module,ParameterSchema,Palette,Preset,ParameterHash}.swift
Packages/VisualCore/Tests/VisualCoreParametersTests/*.swift
Packages/VisualCore/Sources/VisualCoreTestSupport/ImageComparison.swift (+ tests in VisualCoreScaffoldTests or new target)
Packages/VisualCoreRendering/Package.swift                          # Rendering resources (GLSL), deps (Parameters), UI deps
Packages/VisualCoreRendering/Sources/VisualCoreRendering/{ShaderBundle,FullScreenShaderScene}.swift, ShaderProgram.swift (+vec3Array)
Packages/VisualCoreRendering/Sources/VisualCoreRendering/GLSL/vc/{hash,noise,palette,sdf,color}.glsl
Packages/VisualCoreRendering/Sources/VisualCoreUI/RenderSurface.swift
Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/{ShaderBundleTests,FullScreenShaderSceneTests}.swift
Showcase/App/BundleShaders.swift → uses ShaderBundle (migration)
Apps/GenerativeArtStudio/Core/Package.swift                         # GenerativeArtStudioCore (macOS 15 + iOS 26)
Apps/GenerativeArtStudio/Core/Sources/GenerativeArtStudioCore/{SceneFamily,FamilyCatalog,ArtDocument,ParticleReplay,SeedOffsets}.swift
Apps/GenerativeArtStudio/Core/Tests/GenerativeArtStudioCoreTests/*.swift
Apps/GenerativeArtStudio/App/{GenerativeArtStudioApp,GalleryView,SceneScreen,ArtSceneFactory,ParticlesArtScene}.swift
Apps/GenerativeArtStudio/Shaders/{gradient-noise,raymarched-shapes,geometric-tiling,particles-background}.frag
Apps/GenerativeArtStudio/Tests/Unit/{RenderDeterminismTests,FamilyDistinctnessTests,SceneCleanupTests}.swift
Apps/GenerativeArtStudio/Tests/UI/{LaunchSmokeUITests,GalleryUITests}.swift
project.yml                                                         # + Core package, VisualCore products, Shaders resources, unit-test target
docs/apps/generative-art-studio/visualcore-contract.json            # gaps closed → available (FR-A01-113)
```

**Dependency direction**: App → GenerativeArtStudioCore → VisualCoreParameters and VisualCoreSimulation (pure). App →
VisualCoreRendering, VisualCoreUI → pure modules. Tests → VisualCoreTestSupport. VisualCoreParameters depends only
on Foundation (rule R2). VisualCoreRendering gains a dependency on VisualCoreParameters, so `FullScreenShaderScene`
can bind palettes; this is a pure→iOS direction, allowed by the package map. The package-map row is amended.

**Lifecycle contract**:
1. `SceneScreen` creates one `RenderHost(scene:)` per opened family and shows it in `RenderSurface`.
2. On disappear it calls `host.destroy()`.
3. Context loss calls the scene's `teardown` and then `setup`. The scene rebuilds programs and particle buffers from
   its immutable document snapshot.
4. All GL runs on the main thread inside the scene callbacks.

**Migration and rollback**: VisualCore additions are additive (new module, new types, one new setter). The Showcase
switches `BundleShaders` to `ShaderBundle` with the same behavior (its tests cover it). Rollback means reverting the
phase commits; there is no persisted data yet.

## Complexity Tracking

None.
