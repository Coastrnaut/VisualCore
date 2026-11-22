# Implementation Plan: R02-G06-03 — Chrono Constellator: procedural materials and hero renderer

**Branch**: `353-chrono-constellator-procedural-materials-and-hero-renderer` (spec directory only; work on `main`) |
**Date**: 2026-11-21 | **Spec**: [spec.md](spec.md)

## Summary

Add Chrono Constellator's hero scene on the pattern of Colorfall Canyons's feature 343: an immutable scene snapshot and
palette, generated geometry (field, tracks, star nodes with shapes, target rings, history ribbons with alpha decay, hold
and collision marks), a fixed fitted camera with a CPU projection reference, GLSL ES 3.00 sources, the experience adapter
(`ChronoConstellatorExperienceCore`) with its scenario manifest, an iOS experience target (presenter, scene, minimal
controls) on the shared `ShaderMeshRenderer`, and the candidate registration in the one app. Research:
[research.md](research.md). Data: [data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md). Quickstart:
[quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6, GLSL ES 3.00 (strings in Swift sources). **Primary dependencies**: VisualCoreSimulation,
VisualCoreMath, VisualCoreScenes (`MeshBuilder`), VisualCoreExperience, VisualCoreDiagnostics, VisualCorePersistence in
the Core; VisualCoreRendering (`ShaderMeshRenderer`, `MeshRenderer`), VisualCoreExperienceHost and VisualCoreUI in the
Experience. No Objective-C++ bridge; no second renderer; no new VisualCore API.
**Package**: `Packages/ExperiencesRound02/Package.swift` gains `ChronoConstellatorExperience` (path
`ChronoConstellator/Experience`), `ChronoConstellatorExperienceTests` and the product; rendering dependencies carry
`condition: .when(platforms: [.iOS])` and sources sit in `#if os(iOS)`, so the Cores still run on the host.
`ChronoConstellatorCore` gains VisualCoreScenes, VisualCoreExperience, VisualCoreDiagnostics and VisualCorePersistence.
**App**: `project.yml` adds the `ChronoConstellatorCore` and `ChronoConstellatorExperience` products; the registry
registers the candidate; `Catalog/registrations.json` gains the entry (content facts: 100 levels, digest
6483b20ee7d44efad49b5cc0607c8c62d38a177ace8a5390fceb9b637a986ffc), `build_catalog.py` regenerates `experiences.json` and the
fixtures; `AppModelTests` switches its unregistered example to `r02-g07.amethyst-escape`; `scripts/test_scripts.py` and
the package count follow; `xcodegen generate` after `project.yml` changes.
**Seeds**: level (seed mod 100) + 1; tests use seed 2_353 and the catalog's levels 1, 21, 41, 61, 81.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02`; simulator `xcodebuild_package.py … --destination
sim-27.2 --action test`; the app unit tests; regression; script tests alone; audits wait for devices.
**Performance**: the largest level (8 × 7 grid, 5 stars, loops ≤ 14 cells) at level-0 draws 5 ribbons of 24 ticks × 4
segments (≈ 1,000 triangles), 5 tracks (≤ 70 quads), 5 star nodes of ≤ 48 triangles, 5 target rings and the field — under
4,000 triangles plus two glow shells; geometry is rebuilt only when the tick, timeline, stage or tier change; the shimmer
moves by a time uniform. Device budgets are `{device}` tasks after ImplementationLock-100.
**Shader limits**: one uniform block of at most 16 vec4s per program; no texture samplers; loops bounded by constants.
**Constraints**: additive; denylisted names (ProjectM, PresetLibrary, MilkDrop …) avoided; scenarios only under
`#if DEBUG || VISUALCORE_AUTOMATION`; the presenter declares frame probes (round-two X gate rule).

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I Proven renderer only | PASS — existing GL path and `ShaderMeshRenderer`; no second renderer. |
| II App-neutral API | PASS — game code in the experience package; VisualCore API unchanged. |
| IV Host-testable | PASS — adapter, geometry and CPU reference in the Core; GL code tested on the simulator. |
| V Implementation before devices | PASS — device budgets are `{device}` tasks. |
| IX Bounded input | PASS — snapshot values bounded; actions validated by declared controls and the kernel. |
| X Licensing and provenance | PASS — original shaders and geometry; palette from the project's design (indigo, silver, rose). |
| XI One app and stable identity | PASS — candidate `r02-g06.chrono-constellator`; no app target. |
| XII One purchase, no advertising | PASS — free; no store code. |
| XIII Code-driven visuals | PASS — generated meshes and GLSL only. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/Package.swift                                                          edit (lead)
Packages/ExperiencesRound02/ChronoConstellator/Core/ChronoConstellatorExperienceCore.swift     new  adapter (agent C)
Packages/ExperiencesRound02/ChronoConstellator/Core/ChronoConstellatorSceneSnapshot.swift      new  snapshot, palette, shapes, tiers (lead)
Packages/ExperiencesRound02/ChronoConstellator/Core/ChronoConstellatorSceneGeometry.swift      new  geometry, camera, CPU reference (agent B)
Packages/ExperiencesRound02/ChronoConstellator/Core/ChronoConstellatorShaders.swift            new  GLSL sources (agent A)
Packages/ExperiencesRound02/ChronoConstellator/Core/ChronoConstellatorScenarios.swift          new  scenario manifest source (lead)
Packages/ExperiencesRound02/ChronoConstellator/CoreTests/{…ExperienceCoreTests (C), …SceneGeometryTests (B), …ShaderSourceTests (A),
  …RendererPurityTests (C), …ScenariosTests (lead)}.swift                                              new
Packages/ExperiencesRound02/ChronoConstellator/Experience/{ChronoConstellatorExperience, …Presenter, …SkyScene, …Controls}.swift   new (lead)
Packages/ExperiencesRound02/ChronoConstellator/ExperienceTests/{…TestSupport, …RenderTests, …TierTests, …FallbackTests, …ExperienceIdentityTests}.swift  new (agent D)
Packages/ExperiencesRound02/ChronoConstellator/scenario-manifest.json                                                       new (lead)
Catalog/registrations.json, Catalog/experiences.json, Apps/VisualCore/App/ExperienceRegistry.swift, project.yml,
  Apps/VisualCore/Tests/Unit/AppModelTests.swift, fixtures, scripts/test_scripts.py                 edit (lead)
docs/architecture/chrono-constellator.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md   edit (lead)
```

**Migration**: none (snapshot schema 1 is new). **Rollback**: revert the commits; the catalog entry returns to its
pre-registration form; the Cores are untouched.

## Parallel work

Lead: package and snapshot first; then agents A (shader sources), B (geometry, camera, CPU reference) and C (adapter and
purity) in parallel; the lead writes the presenter, scene and controls; D (simulator tests) starts once the presenter
builds. Registration, app links and docs stay with the lead. Checks are recorded only after every agent has reported.
