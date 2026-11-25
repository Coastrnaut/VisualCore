# Implementation Plan: R02-G17-03 — Celestial Eclipse Lab: procedural materials and hero renderer

**Branch**: `463-celestial-eclipse-lab-procedural-materials-and-hero-renderer` (spec directory only; work on `main`) |
**Date**: 2026-11-25 | **Spec**: [spec.md](spec.md)

## Summary

Add Celestial Eclipse Lab's hero renderer on the pattern of Starlit Cartouche's (feature 453): an immutable scene
snapshot (the bodies' positions at the shown tick for the current phases, radii and fixed flags; the orbits; the
eclipses under way at the shown tick with their classes; the target and windows; the predicted intervals and matched
count; the shown tick and horizon; the chosen body; stage, failure, actions left, budget, level number, presentation
time); the sky geometry (the ink-navy backdrop with sparse specks, orbital ring ribbons with notches and fixed frames,
ivory body spheres with layered shading, the signed-circle crescent mask cut by each nearer disc, corona-gold halos for
total and annular eclipses, the chosen ring, the timeline strip with window brackets, event marks and the playhead, and
the actions bars) mapped from the kernel's lattice positions by w(v) = (v − m) · s, with a fixed authored camera, a
painter's order by camera distance and a CPU reference of the projection and palette; GLSL ES 3.00 sky and glow
programs; three tiers (sphere detail, glow); the adapter `CelestialEclipseLabExperienceCore` (phase, run, undo, redo,
next level, choose body, show tick; digest = level number + play fingerprint; snapshot schema 1); the iOS experience
(presenter with tier log, fallback, Reduce Motion and Reduce Flashing, scene, minimal control panel); the scenario
manifest with 80 acceptance scenarios; and the candidate registration in the one app. Research:
[research.md](research.md). Data: [data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md).
Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6, GLSL ES 3.00 (strings in Swift sources). **Primary dependencies**: VisualCoreSimulation,
VisualCoreMath, VisualCoreScenes (`MeshBuilder`), VisualCoreExperience, VisualCoreDiagnostics, VisualCorePersistence in
the Core; VisualCoreRendering (`ShaderMeshRenderer`, `MeshRenderer`), VisualCoreExperienceHost and VisualCoreUI in the
Experience. No Objective-C++ bridge; no second renderer; no new VisualCore API.
**Package**: `Packages/ExperiencesRound02/Package.swift` has `CelestialEclipseLabCore` and its tests; the Core gains
the dependencies the adapter needs (VisualCoreScenes, VisualCoreExperience, VisualCoreDiagnostics,
VisualCorePersistence) and the package gains `CelestialEclipseLabExperience` (path `CelestialEclipseLab/Experience`),
`CelestialEclipseLabExperienceTests` and the product; rendering dependencies carry `condition: .when(platforms:
[.iOS])` and sources sit in `#if os(iOS)`, so the Cores still run on the host.
**App**: `project.yml` adds the `CelestialEclipseLabCore` and `CelestialEclipseLabExperience` products; the registry
registers the candidate; `Catalog/registrations.json` gains the entry (content facts: 100 levels and the catalog digest
pinned at R02-G17-02), `build_catalog.py` regenerates `experiences.json` and the fixtures; `AppModelTests` switches its
synthetic unregistered candidate to `r02-g18.apsides-workshop`; `scripts/test_scripts.py` and the package count
follow; `xcodegen generate` after `project.yml` changes.
**Seeds**: level (seed mod 100) + 1; tests use seed 2_463 and the catalog's levels 1, 21, 41, 61, 81.
**Exact to float**: the snapshot keeps the kernel's integer positions, ticks, intervals and timeline; world positions
are computed once from the lattice positions (s = 1.5 / (e + 1)); the crescent mask uses the kernel's x and y scaled by
s, so the crescent drawn is the overlap judged; the glow and halo pulse are presentation only; no rule is evaluated on
Doubles.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02`; simulator `xcodebuild_package.py …
--destination sim-27.2 --action test`; the app unit tests; regression; script tests alone; audits wait for devices.
**Performance**: at most 6 bodies at 24 × 16 segments (768 triangles each), 6 ring ribbons of at most 8 positions, up to
15 halos, the timeline (up to 6 brackets and the predicted events) and up to 19 bars: the largest scene stays under
8,000 triangles plus two glow shells; geometry is rebuilt only when the phases, the shown tick, the chosen body, the
stage or the tier change. Device budgets are `{device}` tasks after ImplementationLock-100.
**Shader limits**: one uniform block of at most 16 vec4s per program; the crescent mask's front circles are per-vertex
attributes of each back body's mesh (at most 5 nearer discs, unrolled); no texture samplers; no unbounded loops.
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
| X Licensing and provenance | PASS — original shaders and geometry; palette from the project's design (corona gold, ink navy, muted ember). |
| XI One app and stable identity | PASS — candidate `r02-g17.celestial-eclipse-lab`; no app target. |
| XII One purchase, no advertising | PASS — free; no store code. |
| XIII Code-driven visuals | PASS — generated meshes and GLSL only. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/Package.swift                                                     edit (lead)
Packages/ExperiencesRound02/CelestialEclipseLab/Core/CelestialEclipseLabExperienceCore.swift  new  adapter (agent C)
Packages/ExperiencesRound02/CelestialEclipseLab/Core/CelestialEclipseLabSceneSnapshot.swift   new  snapshot, palette, tiers (lead)
Packages/ExperiencesRound02/CelestialEclipseLab/Core/CelestialEclipseLabSceneGeometry.swift   new  geometry, camera, CPU reference (agent B)
Packages/ExperiencesRound02/CelestialEclipseLab/Core/CelestialEclipseLabShaders.swift         new  GLSL sources (agent A)
Packages/ExperiencesRound02/CelestialEclipseLab/Core/CelestialEclipseLabScenarios.swift       new  scenario manifest source (lead)
Packages/ExperiencesRound02/CelestialEclipseLab/CoreTests/{…ExperienceCoreTests (C), …SceneGeometryTests (B),
  …ShaderSourceTests (A), …RendererPurityTests (C), …ScenariosTests (lead)}.swift              new
Packages/ExperiencesRound02/CelestialEclipseLab/Experience/{CelestialEclipseLabExperience, …Presenter, …SkyScene,
  …Controls}.swift                                                                             new (lead)
Packages/ExperiencesRound02/CelestialEclipseLab/ExperienceTests/{…TestSupport, …RenderTests, …TierTests,
  …FallbackTests, …ExperienceIdentityTests}.swift                                              new (agent D)
Packages/ExperiencesRound02/CelestialEclipseLab/scenario-manifest.json                        new (lead)
Catalog/registrations.json, Catalog/experiences.json, Apps/VisualCore/App/ExperienceRegistry.swift, project.yml,
  Apps/VisualCore/Tests/Unit/AppModelTests.swift, fixtures, scripts/test_scripts.py                edit (lead)
docs/architecture/celestial-eclipse-lab.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md   edit (lead)
```

**Dependency graph**: CelestialEclipseLabCore (kernel and catalog, R02-G17-01/02) → snapshot → geometry, shaders,
adapter → scenarios → Experience (presenter, scene, controls) → app registry. **CI checks**: the host package job, the
round-two simulator suite, the catalog/registration checks of `build_catalog.py --check` and `test_scripts.py`.
**Migration**: none (snapshot schema 1 is new). **Rollback**: revert the commits; the catalog entry returns to its
pre-registration form; the Core kernel is untouched.

## Parallel work

Lead: package and snapshot first; then agents A (shader sources), B (geometry, camera, CPU reference) and C (adapter
and purity) in parallel; the lead writes the presenter, scene and controls; D (simulator tests) starts once the
presenter builds. Registration, app links and docs stay with the lead. Checks are recorded only after every agent has
reported.
