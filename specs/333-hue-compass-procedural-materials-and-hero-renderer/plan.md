# Implementation Plan: R02-G04-03 — Hue Compass: procedural materials and hero renderer

**Branch**: `333-hue-compass-procedural-materials-and-hero-renderer` (spec directory only; work on `main`) |
**Date**: 2026-11-21 | **Spec**: [spec.md](spec.md)

## Summary

Give Hue Compass its experience, following Wave Knot Keeper's R02-G03-03 in the same package: in the host-tested
`HueCompassCore`, the adapter `HueCompassExperienceCore` (shared experience contract), the immutable
`HueCompassSceneSnapshot` with palette, band colours, glyphs and tiers, `HueCompassSceneGeometry` (needle prism, ticks,
band wheel with glyphs, fog prisms, probe, selection and target marks, camera and the CPU projection reference) and
`HueCompassShaders` (GLSL ES 3.00 sources); in a new iOS-only target `HueCompassExperience`, the presenter, the GL scene
drawn with the shared `ShaderMeshRenderer`, the fallback and a minimal control panel; simulator tests comparing offscreen
frames with the CPU reference; and the candidate registration in the catalog and the one app. Research:
[research.md](research.md). Data: [data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md). Quickstart:
[quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6, GLSL ES 3.00 (strings in Swift sources). **Primary dependencies**: VisualCoreSimulation,
VisualCoreMath, VisualCoreScenes (`MeshBuilder`), VisualCoreExperience, VisualCoreDiagnostics, VisualCorePersistence in
the Core; VisualCoreRendering (`ShaderMeshRenderer`, `MeshRenderer`), VisualCoreExperienceHost and VisualCoreUI in the
Experience. No Objective-C++ bridge; no second renderer; no new VisualCore API.
**Package**: `Packages/ExperiencesRound02/Package.swift` gains `HueCompassExperience` (path `HueCompass/Experience`),
`HueCompassExperienceTests` and the product; rendering dependencies carry `condition: .when(platforms: [.iOS])` and
sources sit in `#if os(iOS)`, so the Cores still run on the host. `HueCompassCore` gains VisualCoreScenes,
VisualCoreExperience, VisualCoreDiagnostics and VisualCorePersistence.
**App**: `project.yml` adds the `HueCompassCore` and `HueCompassExperience` products; the registry registers the
candidate; `Catalog/registrations.json` gains the entry (content facts: 100 levels, digest
fcb10a906350344bf23c9126d1c9cd2fd26bde25458cdc2924edb75a0bae8b15), `build_catalog.py` regenerates `experiences.json` and
the fixtures; `AppModelTests` switches its unregistered example to `r02-g05.colorfall-canyons`; `scripts/test_scripts.py`
and the package count follow; `xcodegen generate` after `project.yml` changes.
**Seeds**: level (seed mod 100) + 1; tests use seed 2_333 and the catalog's levels 1, 21, 41, 61, 81.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02`; simulator `xcodebuild_package.py … --destination
sim-27.2 --action test`; the app unit tests; regression; script tests alone; audits wait for devices.
**Performance**: level-0 draws a 12-facet needle prism, 96 ticks, 24 band segments of 8 arc steps with their glyphs, 96
fog prisms × 3 layers (≈ 20 triangles each) and at most 24 marks — about 8,000 triangles, plus a glow shell of the needle
and wheel; geometry rebuilt only when the level, clues, selection, stage or tier change; the needle angle and fog drift
move by uniforms. Device budgets are `{device}` tasks after ImplementationLock-100.
**Constraints**: additive; denylisted names avoided; scenarios only under `#if DEBUG || VISUALCORE_AUTOMATION`; the
target is never in a snapshot of a playing level.

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
| XI One app and stable identity | PASS — candidate `r02-g04.hue-compass`; no app target. |
| XII One purchase, no advertising | PASS — free; no store code. |
| XIII Code-driven visuals | PASS — generated meshes and GLSL only. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/Package.swift                                              edit (lead)
Packages/ExperiencesRound02/HueCompass/Core/HueCompassExperienceCore.swift   new  adapter (agent C)
Packages/ExperiencesRound02/HueCompass/Core/HueCompassSceneSnapshot.swift    new  snapshot, palette, band colours, glyphs, tiers (lead)
Packages/ExperiencesRound02/HueCompass/Core/HueCompassSceneGeometry.swift    new  geometry, camera, CPU reference (agent B)
Packages/ExperiencesRound02/HueCompass/Core/HueCompassShaders.swift          new  GLSL sources (agent A)
Packages/ExperiencesRound02/HueCompass/Core/HueCompassScenarios.swift        new  scenario manifest source (lead)
Packages/ExperiencesRound02/HueCompass/CoreTests/{…ExperienceCoreTests (C), …SceneGeometryTests (B),
  …ShaderSourceTests (A), …RendererPurityTests, …ScenariosTests (lead)}.swift          new
Packages/ExperiencesRound02/HueCompass/Experience/{HueCompassExperience, …Presenter, …CompassScene, …Controls}.swift  new (lead)
Packages/ExperiencesRound02/HueCompass/ExperienceTests/{…TestSupport, …RenderTests, …TierTests, …FallbackTests,
  …ExperienceIdentityTests}.swift                                                      new (agent D)
Packages/ExperiencesRound02/HueCompass/scenario-manifest.json                      new (lead)
Catalog/registrations.json, Catalog/experiences.json, Apps/VisualCore/App/ExperienceRegistry.swift, project.yml,
  Apps/VisualCore/Tests/Unit/AppModelTests.swift, fixtures, scripts/test_scripts.py                    edit (lead)
docs/architecture/hue-compass.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md         edit (lead)
```

**Migration**: none (snapshot schema 1 is new). **Rollback**: revert the commits; the catalog entry returns to its
pre-registration form; the Cores are untouched.

## Parallel work

Lead: package and snapshot first; then agents A (shader sources), B (geometry, camera, CPU reference) and C (adapter) in
parallel; the lead writes the presenter, scene and controls; D (simulator tests) starts once the presenter builds.
Registration, app links and docs stay with the lead. Checks are recorded only after every agent has reported.
