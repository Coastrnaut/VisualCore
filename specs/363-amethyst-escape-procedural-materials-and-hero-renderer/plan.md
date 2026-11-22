# Implementation Plan: R02-G07-03 — Amethyst Escape: procedural materials and hero renderer

**Branch**: `363-amethyst-escape-procedural-materials-and-hero-renderer` (spec directory only; work on `main`) |
**Date**: 2026-11-22 | **Spec**: [spec.md](spec.md)

## Summary

Add Amethyst Escape's hero scene on the pattern of Chrono Constellator's feature 353: an immutable scene snapshot and
palette, generated geometry (backdrop, bevelled wedge prisms per shell with rim openings, platinum wall fins, dark
blocked wedges with cross marks, the pearl and the exit arrow), a fixed fitted camera with a CPU projection reference,
GLSL ES 3.00 sources (translucent amethyst facets with shifting specular highlights; glow), the experience adapter
(`AmethystEscapeExperienceCore`) with its scenario manifest, an iOS experience target (presenter, scene, minimal controls)
on the shared `ShaderMeshRenderer`, and the candidate registration in the one app. Research: [research.md](research.md).
Data: [data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6, GLSL ES 3.00 (strings in Swift sources). **Primary dependencies**: VisualCoreSimulation,
VisualCoreMath, VisualCoreScenes (`MeshBuilder`), VisualCoreExperience, VisualCoreDiagnostics, VisualCorePersistence in
the Core; VisualCoreRendering (`ShaderMeshRenderer`, `MeshRenderer`), VisualCoreExperienceHost and VisualCoreUI in the
Experience. No Objective-C++ bridge; no second renderer; no new VisualCore API.
**Package** (audited 2026-11-22): `Packages/ExperiencesRound02/Package.swift` has `AmethystEscapeCore` and
`AmethystEscapeCoreTests`; it gains `AmethystEscapeExperience` (path `AmethystEscape/Experience`),
`AmethystEscapeExperienceTests` and the product; rendering dependencies carry `condition: .when(platforms: [.iOS])` and
sources sit in `#if os(iOS)`, so the Cores still run on the host. `AmethystEscapeCore` gains VisualCoreScenes,
VisualCoreExperience, VisualCoreDiagnostics and VisualCorePersistence.
**App**: `project.yml` adds the `AmethystEscapeCore` and `AmethystEscapeExperience` products; the registry registers the
candidate; `Catalog/registrations.json` gains the entry (content facts: 100 levels, digest
e65c452967b32b37446b6bff95faa9e7c728931d9af0457b3ddd5bc0772394e6), `build_catalog.py` regenerates `experiences.json` and
the fixtures; `AppModelTests` switches its unregistered example to `r02-g08.faceted-forge`; `scripts/test_scripts.py`
and the package count follow; `xcodegen generate` after `project.yml` changes.
**Seeds**: level (seed mod 100) + 1; tests use seed 2_363 and the catalog's levels 1, 21, 41, 61, 81.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02`; simulator `xcodebuild_package.py … --destination
sim-27.2 --action test`; the app unit tests; regression; script tests alone; audits wait for devices.
**Performance**: the largest level (5 shells × 12 sectors = 60 wedges) at level-0 draws 60 bevelled prisms of ≤ 3 bevel
segments (≤ 120 triangles each, ≈ 7,200), ≤ 60 wall fins (12 triangles each), ≤ 60 cross marks, a pearl sphere of ≤ 320
triangles, the arrow and the backdrop — under 10,000 triangles plus two glow shells; geometry is rebuilt only when the
offsets, pearl, stage or tier change; the highlights move by a time uniform. Device budgets are `{device}` tasks after
ImplementationLock-100.
**Shader limits**: one uniform block of at most 16 vec4s per program; no texture samplers; loops bounded by constants
(at most 3 highlight layers).
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
| X Licensing and provenance | PASS — original shaders and geometry; palette from the project's design (amethyst purple, cool platinum). |
| XI One app and stable identity | PASS — candidate `r02-g07.amethyst-escape`; no app target. |
| XII One purchase, no advertising | PASS — free; no store code. |
| XIII Code-driven visuals | PASS — generated meshes and GLSL only. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/Package.swift                                                    edit (lead)
Packages/ExperiencesRound02/AmethystEscape/Core/AmethystEscapeExperienceCore.swift       new  adapter (agent C)
Packages/ExperiencesRound02/AmethystEscape/Core/AmethystEscapeSceneSnapshot.swift        new  snapshot, palette, tiers (lead)
Packages/ExperiencesRound02/AmethystEscape/Core/AmethystEscapeSceneGeometry.swift        new  geometry, camera, CPU reference (agent B)
Packages/ExperiencesRound02/AmethystEscape/Core/AmethystEscapeShaders.swift              new  GLSL sources (agent A)
Packages/ExperiencesRound02/AmethystEscape/Core/AmethystEscapeScenarios.swift            new  scenario manifest source (lead)
Packages/ExperiencesRound02/AmethystEscape/CoreTests/{…ExperienceCoreTests (C), …SceneGeometryTests (B), …ShaderSourceTests (A),
  …RendererPurityTests (C), …ScenariosTests (lead)}.swift                                        new
Packages/ExperiencesRound02/AmethystEscape/Experience/{AmethystEscapeExperience, …Presenter, …CrystalScene, …Controls}.swift   new (lead)
Packages/ExperiencesRound02/AmethystEscape/ExperienceTests/{…TestSupport, …RenderTests, …TierTests, …FallbackTests, …ExperienceIdentityTests}.swift  new (agent D)
Packages/ExperiencesRound02/AmethystEscape/scenario-manifest.json                                                  new (lead)
Catalog/registrations.json, Catalog/experiences.json, Apps/VisualCore/App/ExperienceRegistry.swift, project.yml,
  Apps/VisualCore/Tests/Unit/AppModelTests.swift, fixtures, scripts/test_scripts.py           edit (lead)
docs/architecture/amethyst-escape.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md   edit (lead)
```

**Dependency graph**: AmethystEscapeCore (kernel, R02-G07-01/02) → snapshot → geometry, shaders, adapter → scenarios →
Experience (presenter, scene, controls) → app registry. **CI checks**: the host package job, the round-two simulator
suite, the catalog/registration checks of `build_catalog.py --check` and `test_scripts.py`. **Migration**: none (snapshot
schema 1 is new). **Rollback**: revert the commits; the catalog entry returns to its pre-registration form; the Core
kernel is untouched.

## Parallel work

Lead: package and snapshot first; then agents A (shader sources), B (geometry, camera, CPU reference) and C (adapter and
purity) in parallel; the lead writes the presenter, scene and controls; D (simulator tests) starts once the presenter
builds. Registration, app links and docs stay with the lead. Checks are recorded only after every agent has reported.
