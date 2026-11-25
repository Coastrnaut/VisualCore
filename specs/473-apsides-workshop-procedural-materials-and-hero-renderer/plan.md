# Implementation Plan: R02-G18-03 — Apsides Workshop: procedural materials and hero renderer

**Branch**: `473-apsides-workshop-procedural-materials-and-hero-renderer` (spec directory only; work on `main`) |
**Date**: 2026-11-25 | **Spec**: [spec.md](spec.md)

## Summary

Add Apsides Workshop's hero renderer on the pattern of Celestial Eclipse Lab's (feature 463): an immutable scene
snapshot (the current orbit's positions, the starting orbit's positions, the orbiter at the shown tick, the shares, the
apsis readings, the planets, the targets with bands, readings, deviations and met flags; stage, failure, actions left,
budget, level number, shown tick, presentation time); the compass geometry (the midnight backdrop with sparse specks,
swept-area wedges per tick tinted for target sectors, the compass spokes and notched rim with target brackets, the ghost
loop of the starting orbit, the glacial orbit loop through the kernel's exact positions with presentation-only
refinement between ticks, the apsis diamond and square, hatched planets, the star, the orbiter, the target gauges and
the actions bars) mapped by one fixed scale s = 0.9 / 16 384, a fixed authored camera, a painter's order by kind and a
CPU reference of the projection and palette; GLSL ES 3.00 compass and glow programs; three tiers (sphere detail,
orbit refinement, glow); the adapter `ApsidesWorkshopExperienceCore` (periapsis, size, play, undo, redo, next level,
show tick; digest = level number + play fingerprint; snapshot schema 1); the iOS experience (presenter with tier log,
fallback, Reduce Motion and Reduce Flashing, scene, minimal control panel); the scenario manifest with 80 acceptance
scenarios; and the candidate registration in the one app. Research: [research.md](research.md). Data:
[data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6, GLSL ES 3.00 (strings in Swift sources). **Primary dependencies**: VisualCoreSimulation,
VisualCoreMath, VisualCoreScenes (`MeshBuilder`), VisualCoreExperience, VisualCoreDiagnostics, VisualCorePersistence in
the Core; VisualCoreRendering (`ShaderMeshRenderer`, `MeshRenderer`), VisualCoreExperienceHost and VisualCoreUI in the
Experience. No Objective-C++ bridge; no second renderer; no new VisualCore API.
**Package**: `Packages/ExperiencesRound02/Package.swift` has `ApsidesWorkshopCore` and its tests; the Core gains the
dependencies the adapter needs (VisualCoreScenes, VisualCoreExperience, VisualCoreDiagnostics, VisualCorePersistence)
and the package gains `ApsidesWorkshopExperience` (path `ApsidesWorkshop/Experience`), `ApsidesWorkshopExperienceTests`
and the product; rendering dependencies carry `condition: .when(platforms: [.iOS])` and sources sit in `#if os(iOS)`,
so the Cores still run on the host.
**App**: `project.yml` adds the `ApsidesWorkshopCore` and `ApsidesWorkshopExperience` products; the registry registers
the candidate; `Catalog/registrations.json` gains the entry (content facts: 100 levels and the catalog digest pinned at
R02-G18-02), `build_catalog.py` regenerates `experiences.json` and the fixtures; `AppModelTests` switches its synthetic
unregistered candidate to `r02-g19.microscopic-aurora`; `scripts/test_scripts.py` and the package count follow;
`xcodegen generate` after `project.yml` changes.
**Seeds**: level (seed mod 100) + 1; tests use seed 2_473 and the catalog's levels 1, 21, 41, 61, 81.
**Exact to float**: the snapshot keeps the kernel's integer positions, shares, readings and report; world positions are
the kernel's sky units times s; the orbit loop passes through every kernel position (refinement points between ticks
are presentation only, computed from the analytic ellipse in `Double`, and never judged); the glow pulse is
presentation only; no rule is evaluated on Doubles.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02`; simulator `xcodebuild_package.py …
--destination sim-27.2 --action test`; the app unit tests; regression; script tests alone; audits wait for devices.
**Performance**: at most 96 ticks: 96 wedge triangles, an orbit ribbon of at most 96 × 5 points, a ghost ribbon of 96
points, 8 spokes, the rim, 4 spheres (star, orbiter, up to 3 catalog planets; 6 by the kernel) at 24 × 16 segments,
up to 6 gauges and 19 bars: under 9,000 triangles plus two glow shells; geometry is rebuilt only when the orbit, the
shown tick, the stage or the tier change. Device budgets are `{device}` tasks after ImplementationLock-100.
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
| X Licensing and provenance | PASS — original shaders and geometry; palette from the project's design (glacial white, deep rose, midnight). |
| XI One app and stable identity | PASS — candidate `r02-g18.apsides-workshop`; no app target. |
| XII One purchase, no advertising | PASS — free; no store code. |
| XIII Code-driven visuals | PASS — generated meshes and GLSL only. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/Package.swift                                                 edit (lead)
Packages/ExperiencesRound02/ApsidesWorkshop/Core/ApsidesWorkshopExperienceCore.swift      new  adapter (agent C)
Packages/ExperiencesRound02/ApsidesWorkshop/Core/ApsidesWorkshopSceneSnapshot.swift       new  snapshot, palette, tiers (lead)
Packages/ExperiencesRound02/ApsidesWorkshop/Core/ApsidesWorkshopSceneGeometry.swift       new  geometry, camera, CPU reference (agent B)
Packages/ExperiencesRound02/ApsidesWorkshop/Core/ApsidesWorkshopShaders.swift             new  GLSL sources (agent A)
Packages/ExperiencesRound02/ApsidesWorkshop/Core/ApsidesWorkshopScenarios.swift           new  scenario manifest source (lead)
Packages/ExperiencesRound02/ApsidesWorkshop/CoreTests/{…ExperienceCoreTests (C), …SceneGeometryTests (B),
  …ShaderSourceTests (A), …RendererPurityTests (C), …ScenariosTests (lead)}.swift          new
Packages/ExperiencesRound02/ApsidesWorkshop/Experience/{ApsidesWorkshopExperience, …Presenter, …CompassScene,
  …Controls}.swift                                                                         new (lead)
Packages/ExperiencesRound02/ApsidesWorkshop/ExperienceTests/{…TestSupport, …RenderTests, …TierTests,
  …FallbackTests, …ExperienceIdentityTests}.swift                                          new (agent D)
Packages/ExperiencesRound02/ApsidesWorkshop/scenario-manifest.json                        new (lead)
Catalog/registrations.json, Catalog/experiences.json, Apps/VisualCore/App/ExperienceRegistry.swift, project.yml,
  Apps/VisualCore/Tests/Unit/AppModelTests.swift, fixtures, scripts/test_scripts.py            edit (lead)
docs/architecture/apsides-workshop.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md   edit (lead)
```

**Dependency graph**: ApsidesWorkshopCore (kernel and catalog, R02-G18-01/02) → snapshot → geometry, shaders, adapter
→ scenarios → Experience (presenter, scene, controls) → app registry. **CI checks**: the host package job, the
round-two simulator suite, the catalog/registration checks of `build_catalog.py --check` and `test_scripts.py`.
**Migration**: none (snapshot schema 1 is new). **Rollback**: revert the commits; the catalog entry returns to its
pre-registration form; the Core kernel is untouched.

## Parallel work

Lead: package and snapshot first; then agents A (shader sources), B (geometry, camera, CPU reference) and C (adapter
and purity) in parallel, each modelled on Celestial Eclipse Lab's files as recorded at R02-G17-03 (`git show
<R02-G17-03 record>:<path>`); the lead writes the presenter, scene, controls and scenarios; D (simulator tests) starts
once the presenter builds. Registration, app links and docs stay with the lead. Checks are recorded only after every
agent has reported.
