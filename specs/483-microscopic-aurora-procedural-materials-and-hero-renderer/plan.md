# Implementation Plan: R02-G19-03 — Microscopic Aurora: procedural materials and hero renderer

**Branch**: `483-microscopic-aurora-procedural-materials-and-hero-renderer` (spec directory only; work on `main`) |
**Date**: 2026-11-26 | **Spec**: [spec.md](spec.md)

## Summary

Add Microscopic Aurora's hero renderer on the pattern of Apsides Workshop's (feature 473): an immutable scene snapshot
(the predicted swim's positions and velocities by tick, the ticks swum, the shown tick, the density and lit cells, the
stencil, the sites, the wells, coverage and coherence with their requirements; stage, failure, actions left, budget,
level number, presentation time); the dish geometry (the still water backdrop, the dish field, L-system fronds at the
two richer tiers, the rim, stencil outlines, lit cells, site rings, well spirals with sense arrows, ribbon trails through
the kernel's exact positions of the last L ticks, tapered capsule swimmers oriented along their velocity, the coverage
and coherence gauges and the actions bars) mapped by one fixed scale s = 0.9 / 2816, a fixed authored camera, a
painter's order by kind and a CPU reference of the projection and palette; GLSL ES 3.00 dish and glow programs; three
tiers (capsule detail, trail length, fronds, glow); the adapter `MicroscopicAuroraExperienceCore` (place, remove, play,
undo, redo, next level, show tick; digest = level number + play fingerprint; snapshot schema 1); the iOS experience
(presenter with tier log, fallback, Reduce Motion and Reduce Flashing, scene, minimal control panel); the scenario
manifest with 80 acceptance scenarios; and the candidate registration in the one app. Research:
[research.md](research.md). Data: [data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md).
Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6, GLSL ES 3.00 (strings in Swift sources). **Primary dependencies**: VisualCoreSimulation,
VisualCoreMath, VisualCoreScenes (`MeshBuilder`), VisualCoreExperience, VisualCoreDiagnostics, VisualCorePersistence in
the Core; VisualCoreRendering (`ShaderMeshRenderer`, `MeshRenderer`), VisualCoreExperienceHost and VisualCoreUI in the
Experience (audited 2026-11-26: `ApsidesWorkshopCore` and `ApsidesWorkshopExperience` link exactly these in
`Packages/ExperiencesRound02/Package.swift`). No Objective-C++ bridge; no second renderer; no new VisualCore API.
**Package**: the Core gains VisualCoreScenes, VisualCoreExperience, VisualCoreDiagnostics and VisualCorePersistence; the
package gains `MicroscopicAuroraExperience` (path `MicroscopicAurora/Experience`), `MicroscopicAuroraExperienceTests`
and the product; rendering dependencies carry `condition: .when(platforms: [.iOS])` and sources sit in `#if os(iOS)`,
so the Cores still run on the host. **App**: `project.yml` adds the `MicroscopicAuroraCore` and
`MicroscopicAuroraExperience` products; the registry registers the candidate; `Catalog/registrations.json` gains the
entry (content facts: 100 levels and the catalog digest pinned at R02-G19-02); `build_catalog.py` regenerates
`experiences.json` and the fixtures; `AppModelTests` switches its synthetic unregistered candidate to
`r02-g20.mushroom-weather`; `scripts/test_scripts.py` and the package count follow; `xcodegen generate` after
`project.yml` changes. **Seeds**: level (seed mod 100) + 1; tests use seed 2_483 and the catalog's levels 1, 21, 41,
61, 81. **Exact to float**: the snapshot keeps the kernel's integer positions, density and report; world positions are
dish units times s about the dish centre; every swimmer and ribbon point is a kernel position (no interpolation); the
fronds are decoration only; no rule is evaluated on Doubles. **Testing**: host `swift test --package-path
Packages/ExperiencesRound02`; simulator `xcodebuild_package.py … --destination sim-27.2 --action test`; the app unit
tests; regression; script tests alone; audits wait for devices. **Performance**: at most 8 swimmers × 64 ribbon points,
576 cell squares at most (60 stencil, the lit ones), 6 sites, 3 well spirals, 8 capsules of 12 segments, fronds of three
generations, 2 gauges and 19 bars: under 12,000 triangles plus two glow shells; geometry is rebuilt only when the wells,
the shown tick, the stage or the tier change. Device budgets are `{device}` tasks after ImplementationLock-100.
**Shader limits**: one uniform block of at most 16 vec4s per program; no texture samplers; no unbounded loops.
**Constraints**: additive; denylisted names (ProjectM, PresetLibrary, MilkDrop …) avoided; no `import MetalKit` text in
any file (compliance scan); scenarios only under `#if DEBUG || VISUALCORE_AUTOMATION`; the presenter declares frame
probes (round-two X gate rule); the Core declares its quality tiers (X gate rule).

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I Proven renderer only | PASS — existing GL path and `ShaderMeshRenderer`; no second renderer. |
| II App-neutral API | PASS — game code in the experience package; VisualCore API unchanged. |
| IV Host-testable | PASS — adapter, geometry and CPU reference in the Core; GL code tested on the simulator. |
| V Implementation before devices | PASS — device budgets are `{device}` tasks. |
| IX Bounded input | PASS — snapshot values bounded; actions validated by declared controls and the kernel. |
| X Licensing and provenance | PASS — original shaders and geometry; palette from the project's design (sea glass green, heliotrope, white). |
| XI One app and stable identity | PASS — candidate `r02-g19.microscopic-aurora`; no app target. |
| XII One purchase, no advertising | PASS — free; no store code. |
| XIII Code-driven visuals | PASS — generated meshes and GLSL only. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/Package.swift                                                    edit (lead)
Packages/ExperiencesRound02/MicroscopicAurora/Core/MicroscopicAuroraExperienceCore.swift     new  adapter (agent C)
Packages/ExperiencesRound02/MicroscopicAurora/Core/MicroscopicAuroraSceneSnapshot.swift      new  snapshot, palette, tiers (lead)
Packages/ExperiencesRound02/MicroscopicAurora/Core/MicroscopicAuroraSceneGeometry.swift      new  geometry, camera, CPU reference (agent B)
Packages/ExperiencesRound02/MicroscopicAurora/Core/MicroscopicAuroraShaders.swift            new  GLSL sources (agent A)
Packages/ExperiencesRound02/MicroscopicAurora/Core/MicroscopicAuroraScenarios.swift          new  scenario manifest source (lead)
Packages/ExperiencesRound02/MicroscopicAurora/CoreTests/{…ExperienceCoreTests (C), …SceneGeometryTests (B),
  …ShaderSourceTests (A), …RendererPurityTests (C), …ScenariosTests (lead)}.swift             new
Packages/ExperiencesRound02/MicroscopicAurora/Experience/{MicroscopicAuroraExperience, …Presenter, …DishScene,
  …Controls}.swift                                                                            new (lead)
Packages/ExperiencesRound02/MicroscopicAurora/ExperienceTests/{…TestSupport, …RenderTests, …TierTests,
  …FallbackTests, …ExperienceIdentityTests}.swift                                             new (agent D)
Packages/ExperiencesRound02/MicroscopicAurora/scenario-manifest.json                         new (lead)
Catalog/registrations.json, Catalog/experiences.json, Apps/VisualCore/App/ExperienceRegistry.swift, project.yml,
  Apps/VisualCore/Tests/Unit/AppModelTests.swift, fixtures, scripts/test_scripts.py            edit (lead)
docs/architecture/microscopic-aurora.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md   edit (lead)
```

**Dependency graph**: MicroscopicAuroraCore (kernel and catalog, R02-G19-01/02) → snapshot → geometry, shaders, adapter
→ scenarios → Experience (presenter, scene, controls) → app registry. **CI checks**: the host package job, the
round-two simulator suite, the catalog/registration checks of `build_catalog.py --check` and `test_scripts.py`.
**Migration**: none (snapshot schema 1 is new). **Rollback**: revert the commits; the catalog entry returns to its
pre-registration form; the Core kernel is untouched.

## Parallel work

Lead: package and snapshot first; then agents A (shader sources), B (geometry, camera, CPU reference) and C (adapter
and purity) in parallel, each modelled on Apsides Workshop's files as recorded at R02-G18-03; the lead writes the
presenter, scene, controls and scenarios; D (simulator tests) starts once the presenter builds. Registration, app links
and docs stay with the lead. Checks are recorded only after every agent has reported.
