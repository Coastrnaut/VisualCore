# Implementation Plan: R02-G16-03 — Starlit Cartouche: procedural materials and hero renderer

**Branch**: `453-starlit-cartouche-procedural-materials-and-hero-renderer` (spec directory only; work on `main`) |
**Date**: 2026-11-24 | **Spec**: [spec.md](spec.md)

## Summary

Add Starlit Cartouche's hero renderer on the pattern of Voxel Origami's (feature 443): an immutable scene snapshot (the
stars' positions at the current beat, glyph points and windows; corridors; hazards and which are active; the flown legs
with their departure and arrival positions; the drawn strokes and the symbol; the ship's star and beat; the beacon; the
deadline; the chosen destination and wait; the route report; stage, failure, actions left, budget, level number,
presentation time); the chart geometry (the turning ultramarine firmament, corridor ribbons with undrawn symbol strokes
dashed, striped hazard tubes, meteor-gold trail ribbons with motion-blur ghosts, pearl star spheres with notched rings,
the sapphire ship arrow, the beacon and chosen rings, the cartouche, actions bars, beat track and wait pips) mapped from
the kernel's lattice positions by w(v) = (v − m) · s, with a fixed authored camera, a painter's order by camera distance
and a CPU reference of the projection and palette; GLSL ES 3.00 chart and glow programs with layered star shading and
signed-distance shading of dashes, stripes, notches and rings; three tiers (sphere detail, trail ghosts, glow); the
adapter `StarlitCartoucheExperienceCore` (fly a leg, undo, redo, next level, choose destination and wait; digest =
level number + play fingerprint; snapshot schema 1); the iOS experience (presenter with tier log, fallback, Reduce
Motion and Reduce Flashing, scene, minimal control panel); the scenario manifest with 80 acceptance scenarios; and the
candidate registration in the one app. Research: [research.md](research.md). Data: [data-model.md](data-model.md).
API: [contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6, GLSL ES 3.00 (strings in Swift sources). **Primary dependencies**: VisualCoreSimulation,
VisualCoreMath, VisualCoreScenes (`MeshBuilder`), VisualCoreExperience, VisualCoreDiagnostics, VisualCorePersistence in
the Core; VisualCoreRendering (`ShaderMeshRenderer`, `MeshRenderer`), VisualCoreExperienceHost and VisualCoreUI in the
Experience. No Objective-C++ bridge; no second renderer; no new VisualCore API.
**Package**: `Packages/ExperiencesRound02/Package.swift` has `StarlitCartoucheCore` and `StarlitCartoucheCoreTests`;
the Core gains the dependencies the adapter needs (VisualCoreScenes, VisualCoreExperience, VisualCoreDiagnostics,
VisualCorePersistence) and the package gains `StarlitCartoucheExperience` (path `StarlitCartouche/Experience`),
`StarlitCartoucheExperienceTests` and the product; rendering dependencies carry `condition: .when(platforms: [.iOS])`
and sources sit in `#if os(iOS)`, so the Cores still run on the host.
**App**: `project.yml` adds the `StarlitCartoucheCore` and `StarlitCartoucheExperience` products; the registry
registers the candidate; `Catalog/registrations.json` gains the entry (content facts: 100 levels and the catalog digest
pinned at R02-G16-02), `build_catalog.py` regenerates `experiences.json` and the fixtures; `AppModelTests` switches its
synthetic unregistered candidate to `r02-g17.celestial-eclipse-lab`; `scripts/test_scripts.py` and the package count
follow; `xcodegen generate` after `project.yml` changes.
**Seeds**: level (seed mod 100) + 1; tests use seed 2_453 and the catalog's levels 1, 21, 41, 61, 81.
**Exact to float**: the snapshot keeps the kernel's integer positions, beats, corridors and route report; world
positions are computed once from the lattice positions (s = 1.5 / (e + 1)); the firmament's turn, the ship's glide and
the glow are presentation only; no rule is evaluated on Doubles.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02`; simulator `xcodebuild_package.py …
--destination sim-27.2 --action test`; the app unit tests; regression; script tests alone; audits wait for devices.
**Performance**: at most 10 stars in the catalog (12 by the kernel) at 16 × 12 segments (384 triangles each), 24
corridor ribbons, 8 hazard tubes, 7 trail ribbons with 3 ghosts, the cartouche (25 grid dots and 12 strokes), 19 bars
and 9 pips: the largest scene stays under 8,000 triangles plus two glow shells; geometry is rebuilt only when the beat,
the legs, the chosen destination or wait, the stage or the tier change (the firmament turns by a uniform). Device
budgets are `{device}` tasks after ImplementationLock-100.
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
| X Licensing and provenance | PASS — original shaders and geometry; palette from the project's design (deep ultramarine, meteor gold, pearl). |
| XI One app and stable identity | PASS — candidate `r02-g16.starlit-cartouche`; no app target. |
| XII One purchase, no advertising | PASS — free; no store code. |
| XIII Code-driven visuals | PASS — generated meshes and GLSL only. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/Package.swift                                               edit (lead)
Packages/ExperiencesRound02/StarlitCartouche/Core/StarlitCartoucheExperienceCore.swift  new  adapter (agent C)
Packages/ExperiencesRound02/StarlitCartouche/Core/StarlitCartoucheSceneSnapshot.swift   new  snapshot, palette, tiers (lead)
Packages/ExperiencesRound02/StarlitCartouche/Core/StarlitCartoucheSceneGeometry.swift   new  geometry, camera, CPU reference (agent B)
Packages/ExperiencesRound02/StarlitCartouche/Core/StarlitCartoucheShaders.swift         new  GLSL sources (agent A)
Packages/ExperiencesRound02/StarlitCartouche/Core/StarlitCartoucheScenarios.swift       new  scenario manifest source (lead)
Packages/ExperiencesRound02/StarlitCartouche/CoreTests/{…ExperienceCoreTests (C), …SceneGeometryTests (B),
  …ShaderSourceTests (A), …RendererPurityTests (C), …ScenariosTests (lead)}.swift         new
Packages/ExperiencesRound02/StarlitCartouche/Experience/{StarlitCartoucheExperience, …Presenter, …ChartScene,
  …Controls}.swift                                                                       new (lead)
Packages/ExperiencesRound02/StarlitCartouche/ExperienceTests/{…TestSupport, …RenderTests, …TierTests, …FallbackTests,
  …ExperienceIdentityTests}.swift                                                        new (agent D)
Packages/ExperiencesRound02/StarlitCartouche/scenario-manifest.json                     new (lead)
Catalog/registrations.json, Catalog/experiences.json, Apps/VisualCore/App/ExperienceRegistry.swift, project.yml,
  Apps/VisualCore/Tests/Unit/AppModelTests.swift, fixtures, scripts/test_scripts.py           edit (lead)
docs/architecture/starlit-cartouche.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md   edit (lead)
```

**Dependency graph**: StarlitCartoucheCore (kernel and catalog, R02-G16-01/02) → snapshot → geometry, shaders,
adapter → scenarios → Experience (presenter, scene, controls) → app registry. **CI checks**: the host package job, the
round-two simulator suite, the catalog/registration checks of `build_catalog.py --check` and `test_scripts.py`.
**Migration**: none (snapshot schema 1 is new). **Rollback**: revert the commits; the catalog entry returns to its
pre-registration form; the Core kernel is untouched.

## Parallel work

Lead: package and snapshot first; then agents A (shader sources), B (geometry, camera, CPU reference) and C (adapter
and purity) in parallel; the lead writes the presenter, scene and controls; D (simulator tests) starts once the
presenter builds. Registration, app links and docs stay with the lead. Checks are recorded only after every agent has
reported.
