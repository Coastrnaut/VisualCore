# Implementation Plan: R02-G03-03 — Wave Knot Keeper: procedural materials and hero renderer

**Branch**: `323-wave-knot-keeper-procedural-materials-and-hero-renderer` (spec directory only; work on `main`) |
**Date**: 2026-11-21 | **Spec**: [spec.md](spec.md)

## Summary

Give Wave Knot Keeper its experience, following Lissajous Labyrinth's R02-G02-03 in the same package: in the host-tested
`WaveKnotKeeperCore`, the adapter `WaveKnotKeeperExperienceCore` (shared experience contract), the immutable
`WaveKnotKeeperSceneSnapshot` with palette and tiers, `WaveKnotKeeperSceneGeometry` (rope tube with rounded corners and
parallel-transport frames, handle spheres, gate cubes, camera and the CPU projection reference) and `WaveKnotKeeperShaders` (GLSL ES 3.00
sources); in a new iOS-only target `WaveKnotKeeperExperience`, the presenter, the GL scene drawn with the shared
`ShaderMeshRenderer`, the fallback and a minimal control panel; simulator tests comparing offscreen frames with the CPU
reference; and the candidate registration in the catalog and the one app. Research: [research.md](research.md). Data:
[data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6, GLSL ES 3.00 (strings in Swift sources). **Primary dependencies**: VisualCoreSimulation,
VisualCoreMath, VisualCoreScenes (`MeshBuilder`), VisualCoreExperience, VisualCoreDiagnostics, VisualCorePersistence in
the Core; VisualCoreRendering (`ShaderMeshRenderer`, `MeshRenderer`), VisualCoreExperienceHost and VisualCoreUI in the
Experience. No Objective-C++ bridge; no second renderer; no new VisualCore API.
**Package**: `Packages/ExperiencesRound02/Package.swift` gains `WaveKnotKeeperExperience` (path
`WaveKnotKeeper/Experience`), `WaveKnotKeeperExperienceTests` and the product; rendering dependencies carry
`condition: .when(platforms: [.iOS])` and sources sit in `#if os(iOS)` (the R02-G01-03 pattern), so the Cores still run on
the host. `WaveKnotKeeperCore` gains VisualCoreScenes, VisualCoreExperience, VisualCoreDiagnostics and
VisualCorePersistence.
**App**: `project.yml` adds the `WaveKnotKeeperCore` and `WaveKnotKeeperExperience` products; the registry
registers the candidate; `Catalog/registrations.json` gains the entry (content facts: 100 levels, digest
12c8ecb8aae7135ff939d99b41a6dc8cf17fb4b7380fb5e4c18347ac5987933f), `build_catalog.py` regenerates `experiences.json` and
the fixtures; `AppModelTests` switches its unregistered example to `r02-g04.hue-compass`; `scripts/test_scripts.py`
and the package count follow; `xcodegen generate` after `project.yml` changes.
**Seeds**: level (seed mod 100) + 1; tests use seed 2_323 and the catalog's levels 1, 21, 41, 61, 81.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02`; simulator `xcodebuild_package.py … --destination
sim-27.2 --action test`; the app unit tests; regression; script tests alone; audits wait for devices.
**Performance**: level-0 draws at most 16 segments × (1 straight + 8 corner rings) × 16 sides × 2 triangles of tube
(≈ 4,600) plus a glow shell of the same size, 16 handle icospheres (≤ 320 triangles each) and 4 gate cubes — about 15,000
triangles; geometry rebuilt only when the points, level, selection or tier change; the caustic pulses move by uniforms. Device budgets are `{device}` tasks after ImplementationLock-100.
**Constraints**: additive; denylisted names avoided; scenarios only under `#if DEBUG || VISUALCORE_AUTOMATION`.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I Proven renderer only | PASS — existing GL path and `ShaderMeshRenderer`; no second renderer. |
| II App-neutral API | PASS — game code in the experience package; VisualCore API unchanged. |
| IV Host-testable | PASS — adapter, geometry and CPU reference in the Core; GL code tested on the simulator. |
| V Implementation before devices | PASS — device budgets are `{device}` tasks. |
| IX Bounded input | PASS — snapshot values bounded; actions validated by declared controls and the kernel. |
| X Licensing and provenance | PASS — original shaders and geometry; palette chosen by the project. |
| XI One app and stable identity | PASS — candidate `r02-g03.wave-knot-keeper`; no app target. |
| XII One purchase, no advertising | PASS — free; no store code. |
| XIII Code-driven visuals | PASS — generated meshes and GLSL only. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/Package.swift                                                    edit (lead)
Packages/ExperiencesRound02/WaveKnotKeeper/Core/WaveKnotKeeperExperienceCore.swift   new  adapter (agent C)
Packages/ExperiencesRound02/WaveKnotKeeper/Core/WaveKnotKeeperSceneSnapshot.swift    new  snapshot, palette, tiers (lead)
Packages/ExperiencesRound02/WaveKnotKeeper/Core/WaveKnotKeeperSceneGeometry.swift    new  geometry, camera, CPU reference (agent B)
Packages/ExperiencesRound02/WaveKnotKeeper/Core/WaveKnotKeeperShaders.swift          new  GLSL sources (agent A)
Packages/ExperiencesRound02/WaveKnotKeeper/Core/WaveKnotKeeperScenarios.swift        new  scenario manifest source (lead)
Packages/ExperiencesRound02/WaveKnotKeeper/CoreTests/{…ExperienceCoreTests (C), …SceneGeometryTests (B),
  …ShaderSourceTests (A), …RendererPurityTests, …ScenariosTests (lead)}.swift                new
Packages/ExperiencesRound02/WaveKnotKeeper/Experience/{…Experience, …Presenter, …RopeScene, …Controls}.swift  new (lead)
Packages/ExperiencesRound02/WaveKnotKeeper/ExperienceTests/{…TestSupport, …RenderTests, …TierTests,
  …FallbackTests, …ExperienceIdentityTests}.swift                                            new (agent D)
Packages/ExperiencesRound02/WaveKnotKeeper/scenario-manifest.json                        new (lead)
Catalog/registrations.json, Catalog/experiences.json, Apps/VisualCore/App/ExperienceRegistry.swift, project.yml,
  Apps/VisualCore/Tests/Unit/AppModelTests.swift, fixtures, scripts/test_scripts.py                         edit (lead)
docs/architecture/lissajous-labyrinth.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md     edit (lead)
```

**Migration**: none (snapshot schema 1 is new). **Rollback**: revert the commits; the catalog entry returns to its
pre-registration form; the Cores are untouched.

## Parallel work

Lead: package and snapshot first; then agents A (shader sources), B (geometry, camera, CPU reference) and C (adapter) in
parallel; the lead writes the presenter, scene and controls; D (simulator tests) starts once the presenter builds.
Registration, app links and docs stay with the lead. Checks are recorded only after every agent has reported.
