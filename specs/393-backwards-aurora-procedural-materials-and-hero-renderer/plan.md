# Implementation Plan: R02-G10-03 — Backwards Aurora: procedural materials and hero renderer

**Branch**: `393-backwards-aurora-procedural-materials-and-hero-renderer` (spec directory only; work on `main`) |
**Date**: 2026-11-22 | **Spec**: [spec.md](spec.md)

## Summary

Add Backwards Aurora's hero scene on the pattern of Nocturne Garden's feature 383: an immutable scene snapshot and
palette, generated geometry (the midnight ground, the aurora ribbon tessellated through the kernel's exact samples with
its trailing layers, the lilac ghost trail of the target, checkpoint ticks with rings filled when matched, kink crosses
at sharp bends and a tear cross at a broken seam, the chosen section's dashed band and the reversal gauge), a fixed
fitted camera with a CPU projection reference, GLSL ES 3.00 sources (shimmering ribbon with direction-coded pulses,
ghost, markers; glow), the experience adapter (`BackwardsAuroraExperienceCore`) with its scenario manifest, an iOS
experience target (presenter, scene, minimal controls) on the shared `ShaderMeshRenderer`, and the candidate
registration in the one app. Research: [research.md](research.md). Data: [data-model.md](data-model.md). API:
[contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6, GLSL ES 3.00 (strings in Swift sources). **Primary dependencies**: VisualCoreSimulation,
VisualCoreMath, VisualCoreScenes (`MeshBuilder`), VisualCoreExperience, VisualCoreDiagnostics, VisualCorePersistence in
the Core; VisualCoreRendering (`ShaderMeshRenderer`, `MeshRenderer`), VisualCoreExperienceHost and VisualCoreUI in the
Experience. No Objective-C++ bridge; no second renderer; no new VisualCore API.
**Package** (audited 2026-11-22): `Packages/ExperiencesRound02/Package.swift` has `BackwardsAuroraCore` and
`BackwardsAuroraCoreTests`; it gains `BackwardsAuroraExperience` (path `BackwardsAurora/Experience`),
`BackwardsAuroraExperienceTests` and the product; rendering dependencies carry `condition: .when(platforms: [.iOS])`
and sources sit in `#if os(iOS)`, so the Cores still run on the host. `BackwardsAuroraCore` gains VisualCoreScenes,
VisualCoreExperience, VisualCoreDiagnostics and VisualCorePersistence.
**App**: `project.yml` adds the `BackwardsAuroraCore` and `BackwardsAuroraExperience` products; the registry registers
the candidate; `Catalog/registrations.json` gains the entry (content facts: 100 levels, digest
6eb242e60a77f39d9ce23f4d28909b827608b19138329c4b18100eebe1e2d06e), `build_catalog.py` regenerates `experiences.json`
and the fixtures; `AppModelTests` switches its unregistered example to `r02-g11.echo-cartographer`;
`scripts/test_scripts.py` and the package count follow; `xcodegen generate` after `project.yml` changes.
**Seeds**: level (seed mod 100) + 1; tests use seed 2_393 and the catalog's levels 1, 21, 41, 61, 81.
**Exact to float**: the snapshot keeps the kernel's integer samples; world positions are computed once from them
(x = −1 + (k + 0.5)·2/N, y = 0.6·s / 64); no rule is evaluated on Doubles.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02`; simulator `xcodebuild_package.py …
--destination sim-27.2 --action test`; the app unit tests; regression; script tests alone; audits wait for devices.
**Performance**: a wave has at most 32 samples (31 segments × 4 steps × 2 triangles for the ribbon, the same for each
of at most 3 trailing layers and the ghost), at most 30 kink crosses, 8 checkpoints and 40 gauge bars: the largest
scene stays under 3,000 triangles plus two glow shells over the ribbon; geometry is rebuilt only when the samples,
section, stage or tier change; pulses and shimmer move by uniforms. Device budgets are `{device}` tasks after
ImplementationLock-100.
**Shader limits**: one uniform block of at most 16 vec4s per program; no texture samplers; loops bounded by constants
(at most 2 pulses per section of the timeline).
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
| X Licensing and provenance | PASS — original shaders and geometry; palette from the project's design (deep ocean cyan, pale lilac, midnight). |
| XI One app and stable identity | PASS — candidate `r02-g10.backwards-aurora`; no app target. |
| XII One purchase, no advertising | PASS — free; no store code. |
| XIII Code-driven visuals | PASS — generated meshes and GLSL only. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/Package.swift                                                   edit (lead)
Packages/ExperiencesRound02/BackwardsAurora/Core/BackwardsAuroraExperienceCore.swift     new  adapter (agent C)
Packages/ExperiencesRound02/BackwardsAurora/Core/BackwardsAuroraSceneSnapshot.swift      new  snapshot, palette, tiers (lead)
Packages/ExperiencesRound02/BackwardsAurora/Core/BackwardsAuroraSceneGeometry.swift      new  geometry, camera, CPU reference (agent B)
Packages/ExperiencesRound02/BackwardsAurora/Core/BackwardsAuroraShaders.swift            new  GLSL sources (agent A)
Packages/ExperiencesRound02/BackwardsAurora/Core/BackwardsAuroraScenarios.swift          new  scenario manifest source (lead)
Packages/ExperiencesRound02/BackwardsAurora/CoreTests/{…ExperienceCoreTests (C), …SceneGeometryTests (B), …ShaderSourceTests (A),
  …RendererPurityTests (C), …ScenariosTests (lead)}.swift                                       new
Packages/ExperiencesRound02/BackwardsAurora/Experience/{BackwardsAuroraExperience, …Presenter, …AuroraScene, …Controls}.swift   new (lead)
Packages/ExperiencesRound02/BackwardsAurora/ExperienceTests/{…TestSupport, …RenderTests, …TierTests, …FallbackTests, …ExperienceIdentityTests}.swift  new (agent D)
Packages/ExperiencesRound02/BackwardsAurora/scenario-manifest.json                                                new (lead)
Catalog/registrations.json, Catalog/experiences.json, Apps/VisualCore/App/ExperienceRegistry.swift, project.yml,
  Apps/VisualCore/Tests/Unit/AppModelTests.swift, fixtures, scripts/test_scripts.py          edit (lead)
docs/architecture/backwards-aurora.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md   edit (lead)
```

**Dependency graph**: BackwardsAuroraCore (kernel and catalog, R02-G10-01/02) → snapshot → geometry, shaders, adapter →
scenarios → Experience (presenter, scene, controls) → app registry. **CI checks**: the host package job, the round-two
simulator suite, the catalog/registration checks of `build_catalog.py --check` and `test_scripts.py`. **Migration**:
none (snapshot schema 1 is new). **Rollback**: revert the commits; the catalog entry returns to its pre-registration
form; the Core kernel is untouched.

## Parallel work

Lead: package and snapshot first; then agents A (shader sources), B (geometry, camera, CPU reference) and C (adapter and
purity) in parallel; the lead writes the presenter, scene and controls; D (simulator tests) starts once the presenter
builds. Registration, app links and docs stay with the lead. Checks are recorded only after every agent has reported.
