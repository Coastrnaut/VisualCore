# Implementation Plan: R02-G20-03 — Mushroom Weather: procedural materials and hero renderer

**Branch**: `493-mushroom-weather-procedural-materials-and-hero-renderer` (spec directory only; work on `main`) |
**Date**: 2026-11-26 | **Spec**: [spec.md](spec.md)

## Summary

Add Mushroom Weather's hero renderer on the pattern of Microscopic Aurora's (feature 483): an immutable scene snapshot
(the predicted run's humidity field by cycle, the cycles run, the shown cycle, the floor and blocked cells, the colonies
with bands, floors and runs, the pods with growth cycles, the sites, the vents with states, the moonlight; stage,
failure, actions left, budget, level number, presentation time); the forest geometry (the midnight backdrop, the moon
with phase ticks, the floor cells, logs and stones, L-system fronds at the two richer tiers, the mist squares sized and
shaded by humidity, site rings, lathed stalks and umbrella caps with band rings, lathed amber pods, droplets and spore
motes at the richer tiers, slatted vents, the colony gauges and the actions bars) mapped by s = min(1.8 / C, 1.6 / R)
about the floor's centre, a fixed authored camera, depth-tested solids and a CPU reference of the projection and
palette; GLSL ES 3.00 forest and glow programs (translucent caps with an SDF moisture sparkle); three tiers (lathe
detail, droplets, fronds, motes, glow); the adapter `MushroomWeatherExperienceCore` (place, remove, vent, moonlight, run,
undo, redo, next level, show cycle; digest = level number + play fingerprint; snapshot schema 1); the iOS experience
(presenter with tier log, fallback, Reduce Motion and Reduce Flashing, scene, minimal control panel); the scenario
manifest with 80 acceptance scenarios; and the candidate registration in the one app. Research:
[research.md](research.md). Data: [data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md).
Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6, GLSL ES 3.00 (strings in Swift sources). **Primary dependencies**: VisualCoreSimulation,
VisualCoreMath, VisualCoreScenes (`MeshBuilder`), VisualCoreExperience, VisualCoreDiagnostics, VisualCorePersistence in
the Core; VisualCoreRendering (`ShaderMeshRenderer`, `MeshRenderer`), VisualCoreExperienceHost and VisualCoreUI in the
Experience (as `MicroscopicAuroraCore` and `MicroscopicAuroraExperience` link them in
`Packages/ExperiencesRound02/Package.swift`). No Objective-C++ bridge; no second renderer; no new VisualCore API.
**Package**: the Core gains VisualCoreScenes, VisualCoreExperience, VisualCoreDiagnostics and VisualCorePersistence; the
package gains `MushroomWeatherExperience` (path `MushroomWeather/Experience`), `MushroomWeatherExperienceTests` and the
product; rendering dependencies carry `condition: .when(platforms: [.iOS])` and sources sit in `#if os(iOS)`, so the
Cores still run on the host. **App**: `project.yml` adds the `MushroomWeatherCore` and `MushroomWeatherExperience`
products; the registry registers the candidate; `Catalog/registrations.json` gains the entry (content facts: 100 levels
and the catalog digest pinned at R02-G20-02); `build_catalog.py` regenerates `experiences.json` and the fixtures;
`AppModelTests` switches its synthetic unregistered candidate to `r02-g21.binary-gardens`; `scripts/test_scripts.py` and
the package count follow; `xcodegen generate` after `project.yml` changes. **Seeds**: level (seed mod 100) + 1; tests
use seed 2_493 and the catalog's levels 1, 21, 41, 61, 81. **Exact to float**: the snapshot keeps the kernel's integer
humidity, bands and report; world positions are cell indices times s about the floor centre; the mist's size and shade
are h/M of the kernel's value at the shown cycle (no smoothing between cycles); droplets, motes and fronds are
decoration only; no rule is evaluated on Doubles. **Testing**: host `swift test --package-path
Packages/ExperiencesRound02`; simulator `xcodebuild_package.py … --destination sim-27.2 --action test`; the app unit
tests; regression; script tests alone; audits wait for devices. **Performance**: at most 168 floor cells (catalog
levels at most 90), 6 colonies with stalk and cap of 16 segments, 6 pods, 3 vents of 8 slats, 12 droplets per pod, 8
motes, fronds of three generations, 6 gauge rows and 24 bars: under 20,000 triangles plus two glow shells; geometry is
rebuilt only when the arrangement, the shown cycle, the stage or the tier change, and the droplets move by a uniform
time only. Device budgets are `{device}` tasks after ImplementationLock-100. **Shader limits**: one uniform block of at
most 16 vec4s per program; no texture samplers; no unbounded loops. **Constraints**: additive; denylisted names
(ProjectM, PresetLibrary, MilkDrop …) avoided; no `import MetalKit` text in any file (compliance scan); scenarios only
under `#if DEBUG || VISUALCORE_AUTOMATION`; the presenter declares frame probes (round-two X gate rule); the Core
declares its quality tiers (X gate rule).

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I Proven renderer only | PASS — existing GL path and `ShaderMeshRenderer`; no second renderer. |
| II App-neutral API | PASS — game code in the experience package; VisualCore API unchanged. |
| IV Host-testable | PASS — adapter, geometry and CPU reference in the Core; GL code tested on the simulator. |
| V Implementation before devices | PASS — device budgets are `{device}` tasks. |
| IX Bounded input | PASS — snapshot values bounded; actions validated by declared controls and the kernel. |
| X Licensing and provenance | PASS — original shaders and geometry; palette from the project's design (fern jade, amber spores, deep blue). |
| XI One app and stable identity | PASS — candidate `r02-g20.mushroom-weather`; no app target. |
| XII One purchase, no advertising | PASS — free; no store code. |
| XIII Code-driven visuals | PASS — generated meshes and GLSL only. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/Package.swift                                                  edit (lead)
Packages/ExperiencesRound02/MushroomWeather/Core/MushroomWeatherExperienceCore.swift       new  adapter (agent C)
Packages/ExperiencesRound02/MushroomWeather/Core/MushroomWeatherSceneSnapshot.swift        new  snapshot, palette, tiers (lead)
Packages/ExperiencesRound02/MushroomWeather/Core/MushroomWeatherSceneGeometry.swift        new  geometry, camera, CPU reference (agent B)
Packages/ExperiencesRound02/MushroomWeather/Core/MushroomWeatherShaders.swift              new  GLSL sources (agent A)
Packages/ExperiencesRound02/MushroomWeather/Core/MushroomWeatherScenarios.swift            new  scenario manifest source (lead)
Packages/ExperiencesRound02/MushroomWeather/CoreTests/{…ExperienceCoreTests (C), …SceneGeometryTests (B),
  …ShaderSourceTests (A), …RendererPurityTests (C), …ScenariosTests (lead)}.swift           new
Packages/ExperiencesRound02/MushroomWeather/Experience/{MushroomWeatherExperience, …Presenter, …ForestScene,
  …Controls}.swift                                                                          new (lead)
Packages/ExperiencesRound02/MushroomWeather/ExperienceTests/{…TestSupport, …RenderTests, …TierTests,
  …FallbackTests, …ExperienceIdentityTests}.swift                                           new (agent D)
Packages/ExperiencesRound02/MushroomWeather/scenario-manifest.json                         new (lead)
Catalog/registrations.json, Catalog/experiences.json, Apps/VisualCore/App/ExperienceRegistry.swift, project.yml,
  Apps/VisualCore/Tests/Unit/AppModelTests.swift, fixtures, scripts/test_scripts.py          edit (lead)
docs/architecture/mushroom-weather.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md   edit (lead)
```

**Dependency graph**: MushroomWeatherCore (kernel and catalog, R02-G20-01/02) → snapshot → geometry, shaders, adapter →
scenarios → Experience (presenter, scene, controls) → app registry. **CI checks**: the host package job, the round-two
simulator suite, the catalog/registration checks of `build_catalog.py --check` and `test_scripts.py`. **Migration**:
none (snapshot schema 1 is new). **Rollback**: revert the commits; the catalog entry returns to its pre-registration
form; the Core kernel is untouched.

## Parallel work

Lead: package and snapshot first; then agents A (shader sources), B (geometry, camera, CPU reference) and C (adapter
and purity) in parallel, each modelled on Microscopic Aurora's files as recorded at R02-G19-03; the lead writes the
presenter, scene, controls and scenarios; D (simulator tests) starts once the presenter builds. Registration, app links
and docs stay with the lead. Checks are recorded only after every agent has reported.
