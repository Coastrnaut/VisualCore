# Implementation Plan: Light Maze — Phase 01 Grid/ray reflection solver and fixtures

**Branch**: `096-lm-p01-solver` (spec directory only; work on `main`) | **Date**: 2026-11-15 | **Spec**: [spec.md](spec.md)

## Summary

Close G-RAYCAST2D upstream in `VisualCoreMath` (`Ray2`, `Segment2`, `RayHit2`, `Ray2.cast(against:excluding:
minimumDistance:)`, `Vec2.reflected(about:)`; pure, host-tested) and G-BOARD in the new experience `a13.light-maze` in
`Packages/ExperiencesCreative/LightMaze`: Core (`Board` with tiles, `BeamTracer` over the generic cast with bounce,
segment and branch caps and cycle detection, `LevelCatalog` with the 20 handcrafted levels as Swift data and a
validating JSON codec, `LicenseAudit`, `MazeState` schema 1), Experience (adapter `MazeCore`, manifest, presenter
drawing the board and the beam through `PrimitiveRenderer`, native controls), registered as a candidate with nine
standard scenarios and fixtures. Generated `docs/apps/light-maze/content-licenses.md`. Research:
[research.md](research.md). Data: [data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md).

## Technical Context

**Language**: Swift 6. **Dependencies**: `VisualCoreMath` (`Vec2`, `Camera2D`; the new 2D ray API),
`VisualCoreScenes` (`Primitive`, `SceneNode`), `VisualCoreRendering` (`PrimitiveRenderer`), `VisualCoreExperience`
(`ExperienceCore`, `ExperienceAction`, `MigrationChain`), `VisualCoreExperienceHost`, `VisualCoreUI`. **Storage**:
experience snapshot (`MazeState` schema 1); no files written. **Testing**: host `swift test --package-path
Packages/VisualCore --filter Ray2Tests`; ExperiencesCreative on sim-27.2 (`LightMazeCoreTests`,
`LightMazeExperienceTests`); public API check; app build and unit; runner iOS 27; experience package check; contract;
script tests. **Performance**: at most 12 × 12 cells, 144 tiles, 4 segments per tile and the board's 4 edges per cast;
at most 256 beam segments, 64 bounces per branch and 16 branches per trace; tracing once per state change, never per
frame. **Constraints**: tests < 10 s; iOS 27 only; reference regression and iOS 26 at X-A13 (owner ruling 2026-11-14);
no NEEDS CLARIFICATION remains.

## Constitution Check

I PASS (draws through the host's `PrimitiveRenderer`; no context of its own) · II PASS (generic 2D ray cast and
reflection in VisualCore; board, rules, levels in the experience) · II-a PASS (VisualCore change documented, API
baseline updated, nothing existing changes; seven-step reference regression at X-A13) · III PASS (tracing only on
actions) · IV PASS (ray, tracer and levels tested without GPU) · V PASS (snapshot schema 1 with a migration chain) · VI
PASS (render tests on the simulator) · VII PASS (native controls for every action; spoken description; no decorative
motion) · VIII PASS (no permission, no network) · IX PASS (board, segment, bounce and branch caps) · X PASS (all levels
original, MIT, recorded) · XI–XIII PASS. A13 rules (2.9.0): deterministic GPU-free rules, the beam from the CPU tracer
only, bounded, visuals as code, offline, truthful, licenses — PASS. Post-design: PASS.

## Project Structure

```text
Packages/VisualCore/Sources/VisualCoreMath/Ray2.swift                                                      new
Packages/VisualCore/Tests/VisualCoreMathTests/Ray2Tests.swift                                              new
Packages/VisualCore/README.md (2D ray section), API baseline (check_public_api.py --update)                modify
Packages/ExperiencesCreative/LightMaze/Core/{Board,BeamTracer,LevelCatalog,LicenseAudit,MazeState}.swift  new domain
Packages/ExperiencesCreative/LightMaze/CoreTests/{BoardTests,BeamTracerTests,BeamFixtureTests,LevelCatalogTests,
  LicenseAuditTests,MazeStateTests}.swift                                                                  new
Packages/ExperiencesCreative/LightMaze/Experience/{Adapter/MazeCore.swift,Adapter/MazeManifest.swift,
  MazePresenter.swift,MazeControls.swift,LightMazeExperience.swift}                                        new
Packages/ExperiencesCreative/LightMaze/ExperienceTests/{MazeCoreTests,MazeManifestTests,MazeSessionTests,
  MazeRenderTests,MazeTestSupport}.swift; LightMaze/scenario-manifest.json                                  new
Packages/ExperiencesCreative/Package.swift, Catalog/registrations.json, Apps/VisualCore/App/ExperienceRegistry.swift
  (candidate), project.yml (dependency), scripts/test_scripts.py (products list), RealCatalogTests (registrations),
  AppModelTests (synthetic candidate id moves past a13)                                                    modify
docs/apps/light-maze/{content-licenses.md (generated), visualcore-contract.json (G-RAYCAST2D and G-BOARD closed by
  A13-P01; rows updated), README}                                                                          new/modify
```

**Dependency direction** (targets `LightMazeCore`, `LightMazeExperience`, their test targets and the product
`LightMazeExperience`, as `scripts/check_experience_packages.py` requires; the adapter type is `MazeCore` so it does
not shadow the module): LightMazeExperience → LightMazeCore → VisualCoreMath; the experience → scenes, rendering, host,
UI; nothing in VisualCore depends on the experience.

**Lifecycle**: the core holds the `MazeState` (level index, orientations of turnable tiles, selection); actions apply at
their step and retrace the beam (the beam is a cache of the state, never saved); the host's steps change nothing else.
The presenter owns one `PrimitiveRenderer`, created when the host's context is current, given a scene-node tree rebuilt
when the state's digest changes, recreated after a context recreation and released in teardown; it reads the state and
never writes it. **Migration**: none (new schema 1). **Rollback**: revert the commits (the VisualCore file is
additive).

## Parallel work

Agent A: `Ray2.swift` and `Ray2Tests.swift` (contracts/api.md). Agent B: LightMaze Core and CoreTests including the 20
levels (uses the ray API by its contract). Agent C: Experience target and tests after A and B land. Lead: README, API
baseline, Package.swift, registrations, registry, project.yml, xcodegen, manifest regeneration, license document,
contract, runs, commits.
