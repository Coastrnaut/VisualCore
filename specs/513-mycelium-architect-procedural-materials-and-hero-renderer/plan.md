# Implementation Plan: R02-G22-03 — Mycelium Architect: procedural materials and hero renderer

**Branch**: `513-mycelium-architect-procedural-materials-and-hero-renderer` (spec directory only; work on `main`) |
**Date**: 2026-11-27 | **Spec**: [spec.md](spec.md)

## Summary

Give Mycelium Architect its experience on the pattern of feature 503: an adapter (`MyceliumArchitectExperienceCore`)
over the kernel and the certified catalog, an immutable scene snapshot, the board geometry (floor, cells, rocks,
toxins, nutrients, blockers, sites, root and terminal caps, instanced tapered vein tubes, gauges and actions bars) with a
CPU projection reference and palette, GLSL ES 3.00 programs with materials in the uv stream, three quality tiers, a
fallback, a scenario manifest, an iOS-only experience target (experience, presenter with frame probes and tier log,
scene, minimal control panel) and the candidate registration in the one app. Research: [research.md](research.md).
Data: [data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6, GLSL ES 3.00 (strings in Swift sources). **Primary dependencies**: VisualCoreSimulation,
VisualCoreMath, VisualCoreScenes (`MeshBuilder`, `Mesh`), VisualCoreExperience, VisualCoreDiagnostics and
VisualCorePersistence in the Core; VisualCoreRendering (`ShaderMeshRenderer`, `MeshRenderer`), VisualCoreExperienceHost
and VisualCoreUI in the Experience, as `BinaryGardensCore` and `BinaryGardensExperience` link them. No second renderer,
no new VisualCore API. **Package**: `MyceliumArchitectCore` gains VisualCoreScenes, VisualCoreExperience,
VisualCoreDiagnostics and VisualCorePersistence; its tests gain VisualCoreScenes, VisualCoreExperience and
VisualCoreDiagnostics; the package gains `MyceliumArchitectExperience` (path `MyceliumArchitect/Experience`),
`MyceliumArchitectExperienceTests` (path `MyceliumArchitect/ExperienceTests`) and the product; rendering dependencies
carry `condition: .when(platforms: [.iOS])` and experience sources sit in `#if os(iOS)`, so the Cores still run on the
host. The kernel's source scans (feature 511's invariant tests, feature 512's generator test scanning `Core/Content`)
must keep reading only the kernel's files: the presentation sources (adapter, snapshot, geometry, shaders, scenarios)
go into a new `Core/Presentation/` folder; both scans list a single directory without recursion (checked
2026-11-27), so they keep reading only the kernel's files (research R2). **App**: `project.yml` adds the two products; the registry registers the candidate
(`ExperienceRegistry.candidates`, opening seed 0); `Catalog/registrations.json` gains the entry; `build_catalog.py`
regenerates the catalog and the VisualCore test fixtures; `RealCatalogTests` lists the new registration;
`AppModelTests` switches its synthetic unregistered candidate to `r02-g23.erosion-painter`; `scripts/test_scripts.py`
lists the two products; `xcodegen generate` after the `project.yml` change. CI's round02 host filter already names
`MyceliumArchitect`. **Seeds**: level (seed mod 100) + 1; tests use seed 2_513 and catalog levels 1, 21, 41, 61, 81.
**Exact to float**: the snapshot keeps the kernel's integer cells, network, pulses, path weights and weights; drawn
positions come from one fit rule (s = 1.9 / max(W, H)); no rule is evaluated on Doubles. **Testing**: host `swift test
--package-path Packages/ExperiencesRound02 --filter MyceliumArchitect`; simulator `xcodebuild_package.py … --destination
sim-27.2 --action test --only-testing MyceliumArchitectExperienceTests`; the app unit tests; regression; script tests
alone; audits wait for devices. **Performance**: a 16 × 16 catalog board has at most 256 cells and a network of at most a
few hundred segments; tubes of 8 sides give under 6,000 triangles for the veins and under 12,000 in all at level-0;
geometry is rebuilt only when the arrangement, the shown pulse, the stage, the failure, the actions left, the tier, the
aspect or the fallback change; vein pulses, ripples and spores move by a uniform time only. Device budgets are
`{device}` tasks. **Shader limits**: at most 16 vec4 uniforms per program (board: `u_mvp`, `u_time`, `u_motion`,
`u_won` = 7 slots; glow: `u_mvp`, `u_glowGain`, `u_glowLimit`, `u_won` = 7); no texture samplers; constant-bounded
loops; fixed hash. **Constraints**: additive; denylisted names avoided; no `import MetalKit` text; scenarios only under
`#if DEBUG || VISUALCORE_AUTOMATION`; the presenter declares frame probes and quality levels equal to the Core's
`qualityTiers`; snapshot schema 1. **Prerequisite**: R02-G22-02 recorded.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I Proven Renderer Only | PASS — the shared OpenGL ES → ANGLE → Metal path through `ShaderMeshRenderer`; no second renderer. |
| II App-Neutral Public API | PASS — all game geometry and shaders stay in the experience package; no VisualCore API change. |
| II-a Preserve the Reference and Prove It | PASS — reference regression in two chunks. |
| III Explicit GPU Lifecycle and Thread Ownership | PASS — the shared renderer owns GL objects; the presenter follows the established lifecycle (prepare, resize, memory warning, teardown). |
| IV Host-Testable Domain Logic, Test-First | PASS — adapter, snapshot, geometry and CPU reference are host-tested; simulator frame checks for the GPU path. |
| V Implementation Before Devices | PASS — frame-time budgets are `{device}` tasks. |
| VI Evidence Over Assertion | PASS — run-check records. |
| VII Native, Accessible UI | PASS — labelled control panel; non-colour twins; Reduce Motion and Reduce Flashing. |
| VIII Public Apple APIs, Privacy | PASS — no network, no telemetry. |
| IX Bounded Untrusted Input | PASS — adapter ranges declared; snapshot schema 1 restored through the kernel's replay. |
| X Licensing and Provenance | PASS — original code; no assets. |
| XI One App | PASS — a candidate registration in the one app. |
| XII One Purchase, No Advertising | PASS — free tier. |
| XIII Code-Driven Visuals | PASS — generated meshes and shaders only. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/Package.swift                                                    edit  dependencies, Experience target and tests, product (lead)
Packages/ExperiencesRound02/MyceliumArchitect/Core/Presentation/MyceliumArchitectExperienceCore.swift   new  adapter (lead)
Packages/ExperiencesRound02/MyceliumArchitect/Core/Presentation/MyceliumArchitectSceneSnapshot.swift    new  snapshot, palette, tiers (lead)
Packages/ExperiencesRound02/MyceliumArchitect/Core/Presentation/MyceliumArchitectSceneGeometry.swift    new  fit, camera, meshes, CPU reference (agent A)
Packages/ExperiencesRound02/MyceliumArchitect/Core/Presentation/MyceliumArchitectShaders.swift          new  GLSL sources (agent B)
Packages/ExperiencesRound02/MyceliumArchitect/Core/Presentation/MyceliumArchitectScenarios.swift        new  scenario helpers (lead)
Packages/ExperiencesRound02/MyceliumArchitect/scenario-manifest.json                                   new  (lead)
Packages/ExperiencesRound02/MyceliumArchitect/CoreTests/MyceliumArchitectExperienceCoreTests.swift      new  adapter, snapshot, purity (lead)
Packages/ExperiencesRound02/MyceliumArchitect/CoreTests/MyceliumArchitectSceneGeometryTests.swift       new  geometry bounds, order, reference (agent A)
Packages/ExperiencesRound02/MyceliumArchitect/CoreTests/MyceliumArchitectShaderSourceTests.swift        new  uniform counts, palette, loops (agent B)
Packages/ExperiencesRound02/MyceliumArchitect/Experience/MyceliumArchitectExperience.swift              new  (agent C)
Packages/ExperiencesRound02/MyceliumArchitect/Experience/MyceliumArchitectPresenter.swift               new  (agent C)
Packages/ExperiencesRound02/MyceliumArchitect/Experience/MyceliumArchitectBoardScene.swift              new  (agent C)
Packages/ExperiencesRound02/MyceliumArchitect/Experience/MyceliumArchitectControls.swift                new  (agent C)
Packages/ExperiencesRound02/MyceliumArchitect/ExperienceTests/MyceliumArchitectRenderTests.swift        new  simulator frame checks (agent C)
Packages/ExperiencesRound02/MyceliumArchitect/ExperienceTests/MyceliumArchitect{TestSupport,FallbackTests,TierTests,ExperienceIdentityTests}.swift  new  (agent C, as feature 503)
Catalog/registrations.json, Catalog/experiences.json, VisualCore test fixtures, project.yml, Apps/VisualCore/App/ExperienceRegistry.swift,
Apps/VisualCore/Tests/Unit/AppModelTests.swift, Packages/VisualCore/Tests/VisualCoreExperienceTests/RealCatalogTests.swift,
scripts/test_scripts.py                                                                       edit  registration (lead)
docs/architecture/mycelium-architect.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md          edit (lead)
```

**Migration**: none (snapshot schema 1 is new). **Rollback**: revert the feature's commits; the candidate stays
unavailable, so removing it touches no player.

Recorded at convergence (T-R02G2203-016): the glow gain per tier, the Reduce Flashing cap and the motion switch are statics
on `MyceliumArchitectBoardScene`; the shaders keep their own material table (`MyceliumArchitectShaderMaterial`), pinned
equal to the geometry's (`MyceliumArchitectMaterial`) by `theShaderAndGeometryMaterialTablesAgree`.

## Implementation order

1. Baselines after R02-G22-02 is recorded. 2. Package, adapter, snapshot, palette, tiers, scenarios and their host
tests (lead). 3. Geometry and CPU reference (agent A) and shaders (agent B) in parallel. 4. Experience target and
simulator frame checks (agent C). 5. Registration in the one app (lead), app unit tests. 6. Docs, chunks, chain,
reference, script tests. 7. Converge.

## Complexity Tracking

None.
