# Implementation Plan: R02-G05-03 — Colorfall Canyons: procedural materials and hero renderer

**Branch**: `343-colorfall-canyons-procedural-materials-and-hero-renderer` (spec directory only; work on `main`) |
**Date**: 2026-11-21 | **Spec**: [spec.md](spec.md)

## Summary

Give Colorfall Canyons its experience, following Hue Compass's R02-G04-03 in the same package: in the host-tested
`ColorfallCanyonsCore`, the adapter `ColorfallCanyonsExperienceCore` (shared experience contract), the immutable
`ColorfallCanyonsSceneSnapshot` with palette, colour patterns and tiers, `ColorfallCanyonsSceneGeometry` (terrain blocks,
rock slabs, drains, basin rims with target arcs, spring emitters, fluid sheets and flow bands, camera and the CPU
projection reference) and `ColorfallCanyonsShaders` (GLSL ES 3.00 sources); in a new iOS-only target
`ColorfallCanyonsExperience`, the presenter, the GL scene drawn with the shared `ShaderMeshRenderer`, the fallback and a
minimal control panel; simulator tests comparing offscreen frames with the CPU reference; and the candidate registration
in the catalog and the one app. Research: [research.md](research.md). Data: [data-model.md](data-model.md). API:
[contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6, GLSL ES 3.00 (strings in Swift sources). **Primary dependencies**: VisualCoreSimulation,
VisualCoreMath, VisualCoreScenes (`MeshBuilder`), VisualCoreExperience, VisualCoreDiagnostics, VisualCorePersistence in
the Core; VisualCoreRendering (`ShaderMeshRenderer`, `MeshRenderer`), VisualCoreExperienceHost and VisualCoreUI in the
Experience. No Objective-C++ bridge; no second renderer; no new VisualCore API.
**Package**: `Packages/ExperiencesRound02/Package.swift` gains `ColorfallCanyonsExperience` (path
`ColorfallCanyons/Experience`), `ColorfallCanyonsExperienceTests` and the product; rendering dependencies carry
`condition: .when(platforms: [.iOS])` and sources sit in `#if os(iOS)`, so the Cores still run on the host.
`ColorfallCanyonsCore` gains VisualCoreScenes, VisualCoreExperience, VisualCoreDiagnostics and VisualCorePersistence.
**App**: `project.yml` adds the `ColorfallCanyonsCore` and `ColorfallCanyonsExperience` products; the registry registers
the candidate; `Catalog/registrations.json` gains the entry (content facts: 100 levels, digest
68eec7b5df5790cd52979d6f01fdcad576fefe02436c2c0b655813fc8f55f019), `build_catalog.py` regenerates `experiences.json` and the
fixtures; `AppModelTests` switches its unregistered example to `r02-g06.chrono-constellator`; `scripts/test_scripts.py`
and the package count follow; `xcodegen generate` after `project.yml` changes.
**Seeds**: level (seed mod 100) + 1; tests use seed 2_343 and the catalog's levels 1, 21, 41, 61, 81.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02`; simulator `xcodebuild_package.py … --destination
sim-27.2 --action test`; the app unit tests; regression; script tests alone; audits wait for devices.
**Performance**: the largest grid (8 × 6 = 48 cells) at level-0 draws 48 blocks of 4 × 4 top quads with bevels (≈ 3,500
triangles), at most 48 fluid sheets with 3 flow bands each, 3 emitters and 3 rims with arcs — under 8,000 triangles plus a
glow shell; geometry is rebuilt only when heights, fluid, valves, stage or tier change, flow bands move by a time
uniform. Device budgets are `{device}` tasks after ImplementationLock-100.
**Shader limits**: one uniform block of at most 16 vec4s per program; no texture samplers; loops bounded by constants.
**Constraints**: additive; denylisted names (ProjectM, PresetLibrary, MilkDrop …) avoided; scenarios only under
`#if DEBUG || VISUALCORE_AUTOMATION`; presenter must declare probes (round-two X gate rule) once the presenter exists.

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
| XI One app and stable identity | PASS — candidate `r02-g05.colorfall-canyons`; no app target. |
| XII One purchase, no advertising | PASS — free; no store code. |
| XIII Code-driven visuals | PASS — generated meshes and GLSL only. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/Package.swift                                                    edit (lead)
Packages/ExperiencesRound02/ColorfallCanyons/Core/ColorfallCanyonsExperienceCore.swift   new  adapter (agent C)
Packages/ExperiencesRound02/ColorfallCanyons/Core/ColorfallCanyonsSceneSnapshot.swift    new  snapshot, palette, patterns, tiers (lead)
Packages/ExperiencesRound02/ColorfallCanyons/Core/ColorfallCanyonsSceneGeometry.swift    new  geometry, camera, CPU reference (agent B)
Packages/ExperiencesRound02/ColorfallCanyons/Core/ColorfallCanyonsShaders.swift          new  GLSL sources (agent A)
Packages/ExperiencesRound02/ColorfallCanyons/Core/ColorfallCanyonsScenarios.swift        new  scenario manifest source (lead)
Packages/ExperiencesRound02/ColorfallCanyons/CoreTests/{…ExperienceCoreTests (C), …SceneGeometryTests (B), …ShaderSourceTests (A), …RendererPurityTests (C),
  …ScenariosTests (lead)}.swift                                                                new
Packages/ExperiencesRound02/ColorfallCanyons/Experience/{ColorfallCanyonsExperience, …Presenter, …CanyonScene, …Controls}.swift              new (lead)
Packages/ExperiencesRound02/ColorfallCanyons/ExperienceTests/{…TestSupport, …RenderTests, …TierTests, …FallbackTests, …ExperienceIdentityTests}.swift  new (agent D)
Packages/ExperiencesRound02/ColorfallCanyons/scenario-manifest.json                                                                       new (lead)
Catalog/registrations.json, Catalog/experiences.json, Apps/VisualCore/App/ExperienceRegistry.swift, project.yml,
  Apps/VisualCore/Tests/Unit/AppModelTests.swift, fixtures, scripts/test_scripts.py                    edit (lead)
docs/architecture/colorfall-canyons.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md   edit (lead)
```

**Migration**: none (snapshot schema 1 is new). **Rollback**: revert the commits; the catalog entry returns to its
pre-registration form; the Cores are untouched.

## Parallel work

Lead: package and snapshot first; then agents A (shader sources), B (geometry, camera, CPU reference) and C (adapter and
purity) in parallel; the lead writes the presenter, scene and controls; D (simulator tests) starts once the presenter
builds. Registration, app links and docs stay with the lead. Checks are recorded only after every agent has reported.
