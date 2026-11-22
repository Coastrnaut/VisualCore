# Implementation Plan: R02-G08-03 — Faceted Forge: procedural materials and hero renderer

**Branch**: `373-faceted-forge-procedural-materials-and-hero-renderer` (spec directory only; work on `main`) |
**Date**: 2026-11-22 | **Spec**: [spec.md](spec.md)

## Summary

Add Faceted Forge's hero scene on the pattern of Amethyst Escape's feature 363: an immutable scene snapshot and
palette, generated geometry (the ground, every piece as a bevelled convex solid built from its exact faces and opened
about the crystal's centre, cut faces with an amber interior and lattice, the ruby preview plane with its dashed rim and
the cut mark), a fixed fitted camera with a CPU projection reference, GLSL ES 3.00 sources (ice glass with fresnel and
faux dispersion; incandescent cut faces; glow), the experience adapter (`FacetedForgeExperienceCore`) with its scenario
manifest, an iOS experience target (presenter, scene, minimal controls) on the shared `ShaderMeshRenderer`, and the
candidate registration in the one app. Research: [research.md](research.md). Data: [data-model.md](data-model.md). API:
[contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6, GLSL ES 3.00 (strings in Swift sources). **Primary dependencies**: VisualCoreSimulation,
VisualCoreMath, VisualCoreScenes (`MeshBuilder`), VisualCoreExperience, VisualCoreDiagnostics, VisualCorePersistence in
the Core; VisualCoreRendering (`ShaderMeshRenderer`, `MeshRenderer`), VisualCoreExperienceHost and VisualCoreUI in the
Experience. No Objective-C++ bridge; no second renderer; no new VisualCore API.
**Package** (audited 2026-11-22): `Packages/ExperiencesRound02/Package.swift` has `FacetedForgeCore` and
`FacetedForgeCoreTests`; it gains `FacetedForgeExperience` (path `FacetedForge/Experience`),
`FacetedForgeExperienceTests` and the product; rendering dependencies carry `condition: .when(platforms: [.iOS])` and
sources sit in `#if os(iOS)`, so the Cores still run on the host. `FacetedForgeCore` gains VisualCoreScenes,
VisualCoreExperience, VisualCoreDiagnostics and VisualCorePersistence.
**App**: `project.yml` adds the `FacetedForgeCore` and `FacetedForgeExperience` products; the registry registers the
candidate; `Catalog/registrations.json` gains the entry (content facts: 100 levels, digest
ceb59042752490ceef76b62163e9f05414950788c74d2a95d80ef337a28a924c), `build_catalog.py` regenerates `experiences.json`
and the fixtures; `AppModelTests` switches its unregistered example to `r02-g09.nocturne-garden`;
`scripts/test_scripts.py` and the package count follow; `xcodegen generate` after `project.yml` changes.
**Seeds**: level (seed mod 100) + 1; tests use seed 2_373 and the catalog's levels 1, 21, 41, 61, 81.
**Exact to float**: the snapshot converts the kernel's exact corners to Doubles once (numerator / denominator); faces
keep the kernel's corner order; no rule is evaluated on Doubles.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02`; simulator `xcodebuild_package.py …
--destination sim-27.2 --action test`; the app unit tests; regression; script tests alone; audits wait for devices.
**Performance**: a play has at most budget + 1 ≤ 20 pieces of at most 34 faces; a face of k corners is a fan of k − 2
triangles plus a bevel band of 2·k·segments triangles; with at most 3 segments the largest scene stays under 30,000
triangles plus two glow shells over the cut faces; geometry is rebuilt only when the pieces, preview choice, stage or
tier change; shimmer and opening move by uniforms. Device budgets are `{device}` tasks after ImplementationLock-100.
**Shader limits**: one uniform block of at most 16 vec4s per program; no texture samplers; loops bounded by constants
(at most 3 dispersion layers).
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
| X Licensing and provenance | PASS — original shaders and geometry; palette from the project's design (ice glass, ruby, inner amber). |
| XI One app and stable identity | PASS — candidate `r02-g08.faceted-forge`; no app target. |
| XII One purchase, no advertising | PASS — free; no store code. |
| XIII Code-driven visuals | PASS — generated meshes and GLSL only. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/Package.swift                                                   edit (lead)
Packages/ExperiencesRound02/FacetedForge/Core/FacetedForgeExperienceCore.swift        new  adapter (agent C)
Packages/ExperiencesRound02/FacetedForge/Core/FacetedForgeSceneSnapshot.swift         new  snapshot, palette, tiers (lead)
Packages/ExperiencesRound02/FacetedForge/Core/FacetedForgeSceneGeometry.swift         new  geometry, camera, CPU reference (agent B)
Packages/ExperiencesRound02/FacetedForge/Core/FacetedForgeShaders.swift               new  GLSL sources (agent A)
Packages/ExperiencesRound02/FacetedForge/Core/FacetedForgeScenarios.swift             new  scenario manifest source (lead)
Packages/ExperiencesRound02/FacetedForge/CoreTests/{…ExperienceCoreTests (C), …SceneGeometryTests (B), …ShaderSourceTests (A),
  …RendererPurityTests (C), …ScenariosTests (lead)}.swift                                       new
Packages/ExperiencesRound02/FacetedForge/Experience/{FacetedForgeExperience, …Presenter, …CrystalScene, …Controls}.swift   new (lead)
Packages/ExperiencesRound02/FacetedForge/ExperienceTests/{…TestSupport, …RenderTests, …TierTests, …FallbackTests, …ExperienceIdentityTests}.swift  new (agent D)
Packages/ExperiencesRound02/FacetedForge/scenario-manifest.json                                                  new (lead)
Catalog/registrations.json, Catalog/experiences.json, Apps/VisualCore/App/ExperienceRegistry.swift, project.yml,
  Apps/VisualCore/Tests/Unit/AppModelTests.swift, fixtures, scripts/test_scripts.py          edit (lead)
docs/architecture/faceted-forge.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md   edit (lead)
```

**Dependency graph**: FacetedForgeCore (kernel, R02-G08-01/02) → snapshot → geometry, shaders, adapter → scenarios →
Experience (presenter, scene, controls) → app registry. **CI checks**: the host package job, the round-two simulator
suite, the catalog/registration checks of `build_catalog.py --check` and `test_scripts.py`. **Migration**: none
(snapshot schema 1 is new). **Rollback**: revert the commits; the catalog entry returns to its pre-registration form;
the Core kernel is untouched.

## Parallel work

Lead: package and snapshot first; then agents A (shader sources), B (geometry, camera, CPU reference) and C (adapter and
purity) in parallel; the lead writes the presenter, scene and controls; D (simulator tests) starts once the presenter
builds. Registration, app links and docs stay with the lead. Checks are recorded only after every agent has reported.
