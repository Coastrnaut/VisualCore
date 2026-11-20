# Implementation Plan: R02-G01-03 — Aurora Loom: procedural materials and hero renderer

**Branch**: `303-aurora-loom-procedural-materials-and-hero-renderer` (spec directory only; work on `main`) | **Date**:
2026-11-20 | **Spec**: [spec.md](spec.md)

## Summary

Give Aurora Loom its experience: in the pure `AuroraLoomCore` (host-tested) an `ExperienceCore` adapter
(`AuroraLoomExperienceCore`) over the R02-G01-01 kernel and the R02-G01-02 catalog, an immutable scene snapshot, the ribbon
and gate geometry built with R02-F08's curve sampling, parallel-transport frames and ribbon meshes, and a CPU reference of
projection and palette; in a new iOS-only `AuroraLoomExperience` target the presenter, the GL scenes and GLSL ES programs
(wave displacement, bevel edge shading, interference shimmer, emissive glow), three quality tiers, the shader fallback and
a minimal control panel; simulator tests that compare offscreen frames with the CPU reference; and the candidate
registration in the catalog and the one app. Research: [research.md](research.md). Data: [data-model.md](data-model.md).
API: [contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6, GLSL ES 3.00 (strings in Swift sources, as A21's `SkyShader`). **Primary dependencies**:
VisualCoreSimulation, VisualCoreMath, VisualCoreScenes (`CurveSampler`, `CatmullRomSpline`, `CurveFrames`, `Mesh.ribbon`),
VisualCoreExperience (`ExperienceCore`, `QualityProfile`, `ExperienceConformance`) in the Core; VisualCoreRendering,
VisualCoreExperienceHost, VisualCoreEffects (emissive and bloom) and VisualCoreUI in the Experience. No Objective-C++
bridge (the existing GL wrappers are used); no second renderer. One additive VisualCoreRendering type,
`ShaderMeshRenderer` (research R8), draws a generated mesh with a caller-supplied program on the same GL path.
**Package**: `Packages/ExperiencesRound02/Package.swift` gains `AuroraLoomExperience` (path `AuroraLoom/Experience`) and
`AuroraLoomExperienceTests` (path `AuroraLoom/ExperienceTests`) and the product `AuroraLoomExperience`; their rendering
dependencies carry `condition: .when(platforms: [.iOS])` and their sources are wrapped in `#if os(iOS)`, so `swift test`
on the macOS host still builds and runs the Cores (verified with a probe package, research R1). `AuroraLoomCore` gains
VisualCoreScenes and VisualCoreExperience (both macOS-capable).
**App**: `project.yml` adds the `ExperiencesRound02` package and the `AuroraLoomExperience` product to the VisualCore
target; `Apps/VisualCore/App/ExperienceRegistry.swift` registers the candidate; `Catalog/registrations.json`,
`Catalog/experiences.json` (palette, capabilities, quality tiers; `available` stays false), the app test fixtures and the
script tests follow the A25-P02 candidate registration (commit 6dc6d995).
**Seeds**: the adapter prepares level (seed mod 100) + 1; tests use seeds 2_303 and the catalog's levels 1, 21, 41, 61, 81.
**Testing**: host: `swift test --package-path Packages/ExperiencesRound02` (adapter conformance, geometry, CPU reference,
purity); simulator: `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme
ExperiencesRound02-Package --destination sim-27.2 --action test` (offscreen frames vs reference, tiers, fallback, resize,
reduce motion); app: the app unit tests that open candidates; regression as before; script tests (alone).
**Performance**: tier 2 draws 3 ribbons × 5 layers × 128 segments × 2 triangles = 3,840 triangles plus 4 gate rings;
geometry is rebuilt only when steps or tier change; frame budgets on devices are `{device}` tasks after
ImplementationLock-100.
**Constraints**: additive; existing experiences unchanged; denylisted names avoided; scenario names only under
`#if DEBUG || VISUALCORE_AUTOMATION`.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I Proven renderer only | PASS — the existing OpenGL ES → ANGLE → Metal path and its wrappers; no second renderer. |
| II App-neutral API | PASS — game code in the experience package; VisualCore API unchanged. |
| IV Host-testable | PASS — adapter, geometry and CPU reference in the host-tested Core; GL code tested on the simulator. |
| V Implementation before devices | PASS — device frame budgets are `{device}` tasks after ImplementationLock-100. |
| IX Bounded input | PASS — snapshot values bounded; geometry finite; actions validated by declared controls. |
| X Licensing and provenance | PASS — original shaders and geometry; palette chosen by the project. |
| XI One app and stable identity | PASS — candidate registration of `r02-g01.aurora-loom`; no app target. |
| XII One purchase, no advertising | PASS — free tier; no store code. |
| XIII Code-driven visuals | PASS — generated meshes and GLSL only, no image assets. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/Package.swift                                         edit  Core deps; Experience + tests; product (lead)
Packages/ExperiencesRound02/AuroraLoom/Core/AuroraLoomExperienceCore.swift        new   ExperienceCore adapter (agent C)
Packages/ExperiencesRound02/AuroraLoom/Core/AuroraLoomSceneSnapshot.swift         new   immutable snapshot, palette, tiers (lead)
Packages/ExperiencesRound02/AuroraLoom/Core/AuroraLoomSceneGeometry.swift         new   ribbon and gate geometry, camera, CPU reference (agent B)
Packages/ExperiencesRound02/AuroraLoom/Core/AuroraLoomShaders.swift               new   GLSL ES sources and uniform names (agent A)
Packages/ExperiencesRound02/AuroraLoom/CoreTests/{AuroraLoomExperienceCoreTests (C), AuroraLoomSceneGeometryTests (B),
  AuroraLoomShaderSourceTests (A), AuroraLoomRendererPurityTests (lead)}.swift                                       new
Packages/ExperiencesRound02/AuroraLoom/Experience/{AuroraLoomExperience, AuroraLoomPresenter, AuroraLoomRibbonScene,
  AuroraLoomControls}.swift                                                       new   (lead; scene with agent A)
Packages/ExperiencesRound02/AuroraLoom/ExperienceTests/{AuroraLoomTestSupport, AuroraLoomRenderTests, AuroraLoomTierTests,
  AuroraLoomFallbackTests}.swift                                                  new   (agent D)
Packages/ExperiencesRound02/AuroraLoom/scenario-manifest.json                     new   (lead)
Packages/VisualCoreRendering/Sources/VisualCoreRendering/ShaderMeshRenderer.swift   new   custom-program mesh draw (lead; research R8)
Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/ShaderMeshRendererTests.swift new (lead)
docs/api/visualcore-public-api.txt                                                 edit  baseline update (lead)
Catalog/registrations.json, Catalog/experiences.json, Apps/VisualCore/App/ExperienceRegistry.swift, project.yml,
  app test fixtures, scripts/test_scripts.py, docs/migration/path-map.json                                     edit (lead)
.github/workflows/ci.yml (simulator step for ExperiencesRound02), docs/architecture/aurora-loom.md, package README,
  docs/automatedtesting.md                                                                                     edit (lead)
```

**Migration**: none (snapshot schema 1 is new). **Rollback**: revert the commits; the catalog entry returns to its
pre-registration form; the Cores are untouched.

## Parallel work

Lead: package and snapshot first; then agents A (shader sources and their host checks, then the GL scene), B (geometry,
camera, CPU reference), C (adapter and conformance) work in parallel; D (simulator tests) starts once the presenter
builds. Registration, app links, CI and docs stay with the lead. Checks are recorded only after every agent has reported.
