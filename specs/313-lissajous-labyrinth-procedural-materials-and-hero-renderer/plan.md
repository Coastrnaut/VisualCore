# Implementation Plan: R02-G02-03 — Lissajous Labyrinth: procedural materials and hero renderer

**Branch**: `313-lissajous-labyrinth-procedural-materials-and-hero-renderer` (spec directory only; work on `main`) |
**Date**: 2026-11-20 | **Spec**: [spec.md](spec.md)

## Summary

Give Lissajous Labyrinth its experience, following Aurora Loom's R02-G01-03 in the same package: in the host-tested
`LissajousLabyrinthCore`, the adapter `LissajousLabyrinthExperienceCore` (shared experience contract), the immutable
`LissajousLabyrinthSceneSnapshot` with palette and tiers, `LissajousLabyrinthSceneGeometry` (thread, checkpoint rings,
obstacle icospheres, tracer head, camera and the CPU projection reference) and `LissajousLabyrinthShaders` (GLSL ES 3.00
sources); in a new iOS-only target `LissajousLabyrinthExperience`, the presenter, the GL scene drawn with the shared
`ShaderMeshRenderer`, the fallback and a minimal control panel; simulator tests comparing offscreen frames with the CPU
reference; and the candidate registration in the catalog and the one app. Research: [research.md](research.md). Data:
[data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6, GLSL ES 3.00 (strings in Swift sources). **Primary dependencies**: VisualCoreSimulation,
VisualCoreMath, VisualCoreScenes (`MeshBuilder`), VisualCoreExperience, VisualCoreDiagnostics, VisualCorePersistence in
the Core; VisualCoreRendering (`ShaderMeshRenderer`, `MeshRenderer`), VisualCoreExperienceHost and VisualCoreUI in the
Experience. No Objective-C++ bridge; no second renderer; no new VisualCore API.
**Package**: `Packages/ExperiencesRound02/Package.swift` gains `LissajousLabyrinthExperience` (path
`LissajousLabyrinth/Experience`), `LissajousLabyrinthExperienceTests` and the product; rendering dependencies carry
`condition: .when(platforms: [.iOS])` and sources sit in `#if os(iOS)` (the R02-G01-03 pattern), so the Cores still run on
the host. `LissajousLabyrinthCore` gains VisualCoreScenes, VisualCoreExperience, VisualCoreDiagnostics and
VisualCorePersistence.
**App**: `project.yml` adds the `LissajousLabyrinthCore` and `LissajousLabyrinthExperience` products; the registry
registers the candidate; `Catalog/registrations.json` gains the entry (content facts: 100 levels, digest
9c1d5652c1dc2badac0568fc25a79ef3a0a4683d2db290e1b1699b120430e96e), `build_catalog.py` regenerates `experiences.json` and
the fixtures; `AppModelTests` switches its unregistered example to `r02-g03.wave-knot-keeper`; `scripts/test_scripts.py`
and the package count follow; `xcodegen generate` after `project.yml` changes.
**Seeds**: level (seed mod 100) + 1; tests use seed 2_313 and the catalog's levels 1, 21, 41, 61, 81.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02`; simulator `xcodebuild_package.py … --destination
sim-27.2 --action test`; the app unit tests; regression; script tests alone; audits wait for devices.
**Performance**: level-0 draws 4,096 samples × 2 triangles of thread plus up to 6 rings and 8 icospheres (≤ 320
triangles each) — about 12,000 triangles; geometry rebuilt only when the dials, level or tier change; the head and trail
move by uniforms. Device budgets are `{device}` tasks after ImplementationLock-100.
**Constraints**: additive; denylisted names avoided; scenarios only under `#if DEBUG || VISUALCORE_AUTOMATION`.

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
| XI One app and stable identity | PASS — candidate `r02-g02.lissajous-labyrinth`; no app target. |
| XII One purchase, no advertising | PASS — free; no store code. |
| XIII Code-driven visuals | PASS — generated meshes and GLSL only. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/Package.swift                                                    edit (lead)
Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthExperienceCore.swift   new  adapter (agent C)
Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthSceneSnapshot.swift    new  snapshot, palette, tiers (lead)
Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthSceneGeometry.swift    new  geometry, camera, CPU reference (agent B)
Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthShaders.swift          new  GLSL sources (agent A)
Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthScenarios.swift        new  scenario manifest source (lead)
Packages/ExperiencesRound02/LissajousLabyrinth/CoreTests/{…ExperienceCoreTests (C), …SceneGeometryTests (B),
  …ShaderSourceTests (A), …RendererPurityTests, …ScenariosTests (lead)}.swift                new
Packages/ExperiencesRound02/LissajousLabyrinth/Experience/{…Experience, …Presenter, …ThreadScene, …Controls}.swift  new (lead)
Packages/ExperiencesRound02/LissajousLabyrinth/ExperienceTests/{…TestSupport, …RenderTests, …TierTests,
  …FallbackTests, …ExperienceIdentityTests}.swift                                            new (agent D)
Packages/ExperiencesRound02/LissajousLabyrinth/scenario-manifest.json                        new (lead)
Catalog/registrations.json, Catalog/experiences.json, Apps/VisualCore/App/ExperienceRegistry.swift, project.yml,
  Apps/VisualCore/Tests/Unit/AppModelTests.swift, fixtures, scripts/test_scripts.py                         edit (lead)
docs/architecture/lissajous-labyrinth.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md     edit (lead)
```

**Migration**: none (snapshot schema 1 is new). **Rollback**: revert the commits; the catalog entry returns to its
pre-registration form; the Cores are untouched.

## Parallel work

Lead: package and snapshot first; then agents A (shader sources), B (geometry, camera, CPU reference) and C (adapter) in
parallel; the lead writes the presenter, scene and controls; D (simulator tests) starts once the presenter builds.
Registration, app links and docs stay with the lead. Checks are recorded only after every agent has reported.
