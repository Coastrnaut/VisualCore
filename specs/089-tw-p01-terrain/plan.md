# Implementation Plan: Tiny Worlds — Phase 01 Procedural seed and mesh fixtures

**Branch**: `089-tw-p01-terrain` (spec directory only; work on `main`) | **Date**: 2026-11-15 | **Spec**: [spec.md](spec.md)

## Summary

Close G-TERRAIN upstream in `VisualCoreScenes` (`GradientNoise2D`, `FractalNoise2D`, `HeightField` with sampler,
field normals and mesh; pure, deterministic, host-tested) and G-CONTENTLICENSES in the new experience
`a12.tiny-worlds` in `Packages/ExperiencesCreative/TinyWorlds`: Core (`ContentCatalog` with the three presets and their
palettes and a validating decoder, `LicenseAudit`, `WorldPreset` recipes, `TerrainGenerator`, `WorldView`, `WorldState`
schema 1), Experience (adapter `WorldsCore`, manifest, presenter drawing the world's parts through `DepthMeshPass` and
`MeshRenderer` with an `OrbitCamera`, native controls), registered as a candidate with nine standard scenarios and nine
fixtures. Generated `docs/apps/tiny-worlds/content-licenses.md`. Research: [research.md](research.md). Data:
[data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md).

## Technical Context

**Language**: Swift 6. **Dependencies**: `VisualCoreMath` (`Vec3`, `Mat4`, `OrbitCamera`, `OrbitBounds`),
`VisualCoreSimulation` (`SeededRandom` and its saved state; `SplitMix64`), `VisualCoreScenes` (`Mesh`, `MeshBudget`,
`MeshError`, `MeshGenerators.plane`, `Mesh.digest`; the new noise and height-field API), `VisualCoreRendering`
(`MeshRenderer` with `lightDirection` and `ambient`, `DepthMeshPass` with `Item`), `VisualCoreExperience`
(`ExperienceCore`, `ExperienceAction`, `MigrationChain`), `VisualCoreExperienceHost`, `VisualCoreUI`. **Storage**:
experience snapshot (`WorldState` schema 1); no files written. **Testing**: host `swift test --package-path
Packages/VisualCore --filter "GradientNoise2DTests|HeightFieldTests"`; ExperiencesCreative on sim-27.2
(`TinyWorldsCoreTests`, `TinyWorldsExperienceTests`); public API check; app build and unit; runner iOS 27; experience
package check; contract; script tests. **Performance**: at most 65 × 65 = 4,225 vertices and 24,576 indices per terrain
plus one sea plane (within `MeshBudget.default`); generation once per preset or seed change, never per frame; at most 3
draws per frame. **Constraints**: tests < 10 s; iOS 27 only; reference regression and iOS 26 at X-A12 (owner ruling
2026-11-14); no NEEDS CLARIFICATION remains.

## Constitution Check

I PASS (draws through the host's `DepthMeshPass` and `MeshRenderer`; no context of its own) · II PASS (generic noise and
height field in VisualCore; presets, palettes, shaping and the view in the experience) · II-a PASS (VisualCore change
documented, API baseline updated, existing meshes and digests unchanged; seven-step reference regression at X-A12) ·
III PASS (generation only on actions; suspension stops nothing that moves) · IV PASS (noise, field and terrains tested
without GPU) · V PASS (snapshot schema 1 with a migration chain) · VI PASS (render tests on the simulator) · VII PASS
(native controls for every action; spoken description; no decorative motion) · VIII PASS (no permission, no network) ·
IX PASS (vertex, index and draw caps) · X PASS (all content original, MIT, recorded) · XI–XIII PASS. A12 rules (2.8.0):
deterministic GPU-free worlds, bounded, visuals as code, offline, truthful, licenses — PASS. Post-design: PASS.

## Project Structure

```text
Packages/VisualCore/Sources/VisualCoreScenes/{GradientNoise2D,HeightField}.swift                          new
Packages/VisualCore/Tests/VisualCoreScenesTests/{GradientNoise2DTests,HeightFieldTests}.swift             new
Packages/VisualCore/README.md (terrain section), API baseline (check_public_api.py --update)              modify
Packages/ExperiencesCreative/TinyWorlds/Core/{ContentCatalog,LicenseAudit,WorldPreset,TerrainGenerator,
  WorldView,WorldState}.swift                                                                             new domain
Packages/ExperiencesCreative/TinyWorlds/CoreTests/{ContentCatalogTests,LicenseAuditTests,TerrainGeneratorTests,
  TerrainFixtureTests,WorldViewTests,WorldStateTests}.swift                                               new
Packages/ExperiencesCreative/TinyWorlds/Experience/{Adapter/WorldsCore.swift,Adapter/WorldsManifest.swift,
  WorldsPresenter.swift,WorldsControls.swift,TinyWorldsExperience.swift}                                  new
Packages/ExperiencesCreative/TinyWorlds/ExperienceTests/{WorldsCoreTests,WorldsManifestTests,WorldsSessionTests,
  WorldsRenderTests,WorldsTestSupport}.swift; TinyWorlds/scenario-manifest.json                            new
Packages/ExperiencesCreative/Package.swift, Catalog/registrations.json, Apps/VisualCore/App/ExperienceRegistry.swift
  (candidate), project.yml (dependency), scripts/test_scripts.py (products list), RealCatalogTests (registrations),
  AppModelTests (synthetic candidate id moves past a12)                                                   modify
docs/apps/tiny-worlds/{content-licenses.md (generated), visualcore-contract.json (G-TERRAIN, G-CONTENTLICENSES closed
  by A12-P01; rows M03, M08, M14, M21 updated), README}                                                   new/modify
```

**Dependency direction** (targets `TinyWorldsCore`, `TinyWorldsExperience`, their test targets and the product
`TinyWorldsExperience`, as `scripts/check_experience_packages.py` requires; the adapter type is `WorldsCore` so it does
not shadow the module): TinyWorldsExperience → TinyWorldsCore → VisualCoreScenes, VisualCoreSimulation, VisualCoreMath;
the experience → rendering, host, UI; nothing in VisualCore depends on the experience.

**Lifecycle**: the core holds the `WorldState` (preset, seed, view, generator state); actions apply at their step and
regenerate the terrain only when the preset or seed changes (the meshes are a cache of the state, never saved); the
host's steps change nothing else. The presenter owns one `DepthMeshPass` and up to three `MeshRenderer`s created when
the host's context is current, rebuilt when the world's digest changes or after a context recreation, and released in
teardown; it reads the state and never writes it. **Migration**: none (new schema 1). **Rollback**: revert the commits
(the VisualCore files are additive).

## Parallel work

Agent A: `GradientNoise2D.swift`, `HeightField.swift` and their tests (contracts/api.md). Agent B: TinyWorlds Core and
CoreTests (uses the terrain API by its contract). Agent C: Experience target and tests after A and B land. Lead:
README, API baseline, Package.swift, registrations, registry, project.yml, xcodegen, manifest regeneration, license
document, contract, runs, commits.
