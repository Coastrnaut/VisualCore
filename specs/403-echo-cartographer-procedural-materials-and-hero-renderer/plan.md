# Implementation Plan: R02-G11-03 — Echo Cartographer: procedural materials and hero renderer

**Branch**: `403-echo-cartographer-procedural-materials-and-hero-renderer` (spec directory only; work on `main`) |
**Date**: 2026-11-23 | **Spec**: [spec.md](spec.md)

## Summary

Add Echo Cartographer's hero renderer on the pattern of Backwards Aurora's (feature 393): an immutable scene snapshot
(the chamber size, the knowledge per cell, the entry, the markers, the located beacons, the last pulse's echo report,
stage, failure, energy and budget, level number, presentation time — never an unknown wall or an unlocated beacon); the
chamber geometry (abyss ground, opal floor tiles on known-open cells, the entry diamond, marker rings, the last pulse's
rays, the expanding pulse ring and returning echo rings, known walls as dark blocks with sonar-mint edge strips that
flare as the pulse reaches them, located beacons as pillars, the energy gauge) with a fixed authored camera from above
and in front and a CPU reference of the projection and palette; GLSL ES 3.00 chamber and glow programs with
signed-distance shading of tiles, rings and edges; three tiers (rings, flare trails, glow); the adapter
`EchoCartographerExperienceCore` (pulse, claim, mark, undo, redo, next level; digest = level number + play fingerprint;
snapshot schema 1); the iOS experience (presenter with tier log, fallback, Reduce Motion and Reduce Flashing, scene,
minimal control panel with a cursor); the scenario manifest with 80 acceptance scenarios; and the candidate
registration in the one app. Research: [research.md](research.md). Data: [data-model.md](data-model.md). API:
[contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6, GLSL ES 3.00 (strings in Swift sources). **Primary dependencies**: VisualCoreSimulation,
VisualCoreMath, VisualCoreScenes (`MeshBuilder`), VisualCoreExperience, VisualCoreDiagnostics, VisualCorePersistence in
the Core; VisualCoreRendering (`ShaderMeshRenderer`, `MeshRenderer`), VisualCoreExperienceHost and VisualCoreUI in the
Experience. No Objective-C++ bridge; no second renderer; no new VisualCore API.
**Package** (audited 2026-11-23): `Packages/ExperiencesRound02/Package.swift` has `EchoCartographerCore` and
`EchoCartographerCoreTests`; it gains `EchoCartographerExperience` (path `EchoCartographer/Experience`),
`EchoCartographerExperienceTests` and the product; rendering dependencies carry `condition: .when(platforms: [.iOS])`
and sources sit in `#if os(iOS)`, so the Cores still run on the host. `EchoCartographerCore` gains VisualCoreScenes,
VisualCoreExperience, VisualCoreDiagnostics and VisualCorePersistence.
**App**: `project.yml` adds the `EchoCartographerCore` and `EchoCartographerExperience` products; the registry registers
the candidate; `Catalog/registrations.json` gains the entry (content facts: 100 levels, digest
a32a593b898acf77bd86c25509a68e0b5f8a1227f356d2d3b91c8cfff5c8dca9), `build_catalog.py` regenerates `experiences.json`
and the fixtures; `AppModelTests` switches its unregistered example to `r02-g12.harmonic-bridges`;
`scripts/test_scripts.py` and the package count follow; `xcodegen generate` after `project.yml` changes.
**Seeds**: level (seed mod 100) + 1; tests use seed 2_403 and the catalog's levels 1, 21, 41, 61, 81.
**Exact to float**: the snapshot keeps the kernel's integer cells and knowledge; world positions are computed once from
them (X = (x + 0.5 − W / 2)·s, Z = (y + 0.5 − H / 2)·s, s = 1.8 / max(W, H)); no rule is evaluated on Doubles.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02`; simulator `xcodebuild_package.py …
--destination sim-27.2 --action test`; the app unit tests; regression; script tests alone; audits wait for devices.
**Performance**: a chamber has at most 16 × 16 = 256 cells (a floor tile is 2 triangles; a wall block 10 face
triangles and 12 edge strips of 2 triangles; at most 4 pillars, 8 markers, 4 rays and 60 gauge bars): the largest scene
stays under 10,000 triangles plus two glow shells over the edges and pillars; geometry is rebuilt only when the
knowledge, markers, located beacons, stage or tier change; rings and flares move by uniforms. Device budgets are `{device}` tasks after
ImplementationLock-100.
**Shader limits**: one uniform block of at most 16 vec4s per program; no texture samplers; loops bounded by constants
(at most 4 echo rings, one per beacon).
**Constraints**: additive; denylisted names (ProjectM, PresetLibrary, MilkDrop …) avoided; no `import MetalKit` text in
any file (compliance scan); scenarios only under `#if DEBUG || VISUALCORE_AUTOMATION`; the presenter declares frame
probes (round-two X gate rule); new UI test files need `xcodegen generate` (later features).

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I Proven renderer only | PASS — existing GL path and `ShaderMeshRenderer`; no second renderer. |
| II App-neutral API | PASS — game code in the experience package; VisualCore API unchanged. |
| IV Host-testable | PASS — adapter, geometry and CPU reference in the Core; GL code tested on the simulator. |
| V Implementation before devices | PASS — device budgets are `{device}` tasks. |
| IX Bounded input | PASS — snapshot values bounded; actions validated by declared controls and the kernel. |
| X Licensing and provenance | PASS — original shaders and geometry; palette from the project's design (abyss black, sonar mint and opal). |
| XI One app and stable identity | PASS — candidate `r02-g11.echo-cartographer`; no app target. |
| XII One purchase, no advertising | PASS — free; no store code. |
| XIII Code-driven visuals | PASS — generated meshes and GLSL only. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/Package.swift                                                   edit (lead)
Packages/ExperiencesRound02/EchoCartographer/Core/EchoCartographerExperienceCore.swift     new  adapter (agent C)
Packages/ExperiencesRound02/EchoCartographer/Core/EchoCartographerSceneSnapshot.swift      new  snapshot, palette, tiers (lead)
Packages/ExperiencesRound02/EchoCartographer/Core/EchoCartographerSceneGeometry.swift      new  geometry, camera, CPU reference (agent B)
Packages/ExperiencesRound02/EchoCartographer/Core/EchoCartographerShaders.swift            new  GLSL sources (agent A)
Packages/ExperiencesRound02/EchoCartographer/Core/EchoCartographerScenarios.swift          new  scenario manifest source (lead)
Packages/ExperiencesRound02/EchoCartographer/CoreTests/{…ExperienceCoreTests (C), …SceneGeometryTests (B), …ShaderSourceTests (A),
  …RendererPurityTests (C), …ScenariosTests (lead)}.swift                                       new
Packages/ExperiencesRound02/EchoCartographer/Experience/{EchoCartographerExperience, …Presenter, …ChamberScene, …Controls}.swift   new (lead)
Packages/ExperiencesRound02/EchoCartographer/ExperienceTests/{…TestSupport, …RenderTests, …TierTests, …FallbackTests, …ExperienceIdentityTests}.swift  new (agent D)
Packages/ExperiencesRound02/EchoCartographer/scenario-manifest.json                                                new (lead)
Catalog/registrations.json, Catalog/experiences.json, Apps/VisualCore/App/ExperienceRegistry.swift, project.yml,
  Apps/VisualCore/Tests/Unit/AppModelTests.swift, fixtures, scripts/test_scripts.py          edit (lead)
docs/architecture/echo-cartographer.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md   edit (lead)
```

**Dependency graph**: EchoCartographerCore (kernel and catalog, R02-G11-01/02) → snapshot → geometry, shaders, adapter →
scenarios → Experience (presenter, scene, controls) → app registry. **CI checks**: the host package job, the round-two
simulator suite, the catalog/registration checks of `build_catalog.py --check` and `test_scripts.py`. **Migration**:
none (snapshot schema 1 is new). **Rollback**: revert the commits; the catalog entry returns to its pre-registration
form; the Core kernel is untouched.

## Parallel work

Lead: package and snapshot first; then agents A (shader sources), B (geometry, camera, CPU reference) and C (adapter and
purity) in parallel; the lead writes the presenter, scene and controls; D (simulator tests) starts once the presenter
builds. Registration, app links and docs stay with the lead. Checks are recorded only after every agent has reported.
