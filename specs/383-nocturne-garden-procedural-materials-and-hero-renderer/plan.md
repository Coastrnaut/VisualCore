# Implementation Plan: R02-G09-03 — Nocturne Garden: procedural materials and hero renderer

**Branch**: `383-nocturne-garden-procedural-materials-and-hero-renderer` (spec directory only; work on `main`) |
**Date**: 2026-11-22 | **Spec**: [spec.md](spec.md)

## Summary

Add Nocturne Garden's hero scene on the pattern of Faceted Forge's feature 373: an immutable scene snapshot and
palette, generated geometry (the midnight ground, the bed as an upright mist plane, the kernel's exact shadow cells
with a feathered edge, the gold target rim, the coral forbidden hatch and leak crosses, every bloom grown as an L-system
stem with leaf pairs and its kind's outline as an extruded head with a glowing rim, the sun lantern and the move gauge),
a fixed fitted camera with a CPU projection reference, GLSL ES 3.00 sources (pearlescent drifting mist, shadows, hatch,
botanical bodies with rims; glow), the experience adapter (`NocturneGardenExperienceCore`) with its scenario manifest,
an iOS experience target (presenter, scene, minimal controls) on the shared `ShaderMeshRenderer`, and the candidate
registration in the one app. Research: [research.md](research.md). Data: [data-model.md](data-model.md). API:
[contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6, GLSL ES 3.00 (strings in Swift sources). **Primary dependencies**: VisualCoreSimulation,
VisualCoreMath, VisualCoreScenes (`MeshBuilder`), VisualCoreExperience, VisualCoreDiagnostics, VisualCorePersistence in
the Core; VisualCoreRendering (`ShaderMeshRenderer`, `MeshRenderer`), VisualCoreExperienceHost and VisualCoreUI in the
Experience. No Objective-C++ bridge; no second renderer; no new VisualCore API.
**Package** (audited 2026-11-22): `Packages/ExperiencesRound02/Package.swift` has `NocturneGardenCore` and
`NocturneGardenCoreTests`; it gains `NocturneGardenExperience` (path `NocturneGarden/Experience`),
`NocturneGardenExperienceTests` and the product; rendering dependencies carry `condition: .when(platforms: [.iOS])` and
sources sit in `#if os(iOS)`, so the Cores still run on the host. `NocturneGardenCore` gains VisualCoreScenes,
VisualCoreExperience, VisualCoreDiagnostics and VisualCorePersistence.
**App**: `project.yml` adds the `NocturneGardenCore` and `NocturneGardenExperience` products; the registry registers
the candidate; `Catalog/registrations.json` gains the entry (content facts: 100 levels, digest
ce13750aa652c528fe9655fbf4b8fac374bc4782059391b27db5c2cdcbfc52dd), `build_catalog.py` regenerates `experiences.json`
and the fixtures; `AppModelTests` switches its unregistered example to `r02-g10.backwards-aurora`;
`scripts/test_scripts.py` and the package count follow; `xcodegen generate` after `project.yml` changes.
**Seeds**: level (seed mod 100) + 1; tests use seed 2_383 and the catalog's levels 1, 21, 41, 61, 81.
**Exact to float**: the snapshot keeps the kernel's integer cells and bloom anchors; world positions are computed once
from them (cell size u = 2 / W); no rule is evaluated on Doubles.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02`; simulator `xcodebuild_package.py …
--destination sim-27.2 --action test`; the app unit tests; regression; script tests alone; audits wait for devices.
**Performance**: a bed has at most 32 × 24 = 768 cells (two triangles each for the shadow, hatch and cross layers, with
a feather band of at most 8 triangles per shadow boundary edge) and at most 12 blooms (a head of at most 15 outline
corners extruded, a stem of at most 3 segments with a leaf pair each); the largest scene stays under 20,000 triangles
plus two glow shells over the heads; geometry is rebuilt only when the cells, blooms, sun, stage or tier change; mist
drift and sway move by uniforms. Device budgets are `{device}` tasks after ImplementationLock-100.
**Shader limits**: one uniform block of at most 16 vec4s per program; no texture samplers; loops bounded by constants
(at most 3 mist layers).
**Constraints**: additive; denylisted names (ProjectM, PresetLibrary, MilkDrop …) avoided; no `import MetalKit` text in
any file (compliance scan); scenarios only under `#if DEBUG || VISUALCORE_AUTOMATION`; the presenter declares frame
probes (round-two X gate rule).

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I Proven renderer only | PASS — existing GL path and `ShaderMeshRenderer`; no second renderer. |
| II App-neutral API | PASS — game code in the experience package; VisualCore API unchanged. |
| IV Host-testable | PASS — adapter, geometry and CPU reference in the Core; GL code tested on the simulator. |
| V Implementation before devices | PASS — device budgets are `{device}` tasks. |
| IX Bounded input | PASS — snapshot values bounded; actions validated by declared controls and the kernel. |
| X Licensing and provenance | PASS — original shaders and geometry; palette from the project's design (midnight blue, lantern coral, parchment gold). |
| XI One app and stable identity | PASS — candidate `r02-g09.nocturne-garden`; no app target. |
| XII One purchase, no advertising | PASS — free; no store code. |
| XIII Code-driven visuals | PASS — generated meshes and GLSL only. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/Package.swift                                                   edit (lead)
Packages/ExperiencesRound02/NocturneGarden/Core/NocturneGardenExperienceCore.swift     new  adapter (agent C)
Packages/ExperiencesRound02/NocturneGarden/Core/NocturneGardenSceneSnapshot.swift      new  snapshot, palette, tiers (lead)
Packages/ExperiencesRound02/NocturneGarden/Core/NocturneGardenSceneGeometry.swift      new  geometry, camera, CPU reference (agent B)
Packages/ExperiencesRound02/NocturneGarden/Core/NocturneGardenShaders.swift            new  GLSL sources (agent A)
Packages/ExperiencesRound02/NocturneGarden/Core/NocturneGardenScenarios.swift          new  scenario manifest source (lead)
Packages/ExperiencesRound02/NocturneGarden/CoreTests/{…ExperienceCoreTests (C), …SceneGeometryTests (B), …ShaderSourceTests (A),
  …RendererPurityTests (C), …ScenariosTests (lead)}.swift                                       new
Packages/ExperiencesRound02/NocturneGarden/Experience/{NocturneGardenExperience, …Presenter, …GardenScene, …Controls}.swift   new (lead)
Packages/ExperiencesRound02/NocturneGarden/ExperienceTests/{…TestSupport, …RenderTests, …TierTests, …FallbackTests, …ExperienceIdentityTests}.swift  new (agent D)
Packages/ExperiencesRound02/NocturneGarden/scenario-manifest.json                                                new (lead)
Catalog/registrations.json, Catalog/experiences.json, Apps/VisualCore/App/ExperienceRegistry.swift, project.yml,
  Apps/VisualCore/Tests/Unit/AppModelTests.swift, fixtures, scripts/test_scripts.py          edit (lead)
docs/architecture/nocturne-garden.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md   edit (lead)
```

**Dependency graph**: NocturneGardenCore (kernel and catalog, R02-G09-01/02) → snapshot → geometry, shaders, adapter →
scenarios → Experience (presenter, scene, controls) → app registry. **CI checks**: the host package job, the round-two
simulator suite, the catalog/registration checks of `build_catalog.py --check` and `test_scripts.py`. **Migration**:
none (snapshot schema 1 is new). **Rollback**: revert the commits; the catalog entry returns to its pre-registration
form; the Core kernel is untouched.

## Parallel work

Lead: package and snapshot first; then agents A (shader sources), B (geometry, camera, CPU reference) and C (adapter and
purity) in parallel; the lead writes the presenter, scene and controls; D (simulator tests) starts once the presenter
builds. Registration, app links and docs stay with the lead. Checks are recorded only after every agent has reported.
