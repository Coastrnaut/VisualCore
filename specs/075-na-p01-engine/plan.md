# Implementation Plan: Neon Arcade — Phase 01 Fixed-step engine and collision fixtures

**Branch**: `075-na-p01-engine` (spec directory only; work on `main`) | **Date**: 2026-11-14 | **Spec**: [spec.md](spec.md)

## Summary

Close G-COLLISION2D upstream in `VisualCoreSimulation` (`CollisionCircle`, `CollisionCapsule`,
`Collision2D.overlaps(_:_:)` for circle–circle and circle–capsule, `Collision2D.sweep(...)` for two linearly moving
circles over one step; pure, deterministic, host-tested) and the Phase 01 part of G-GAMERULES in the new experience
`a10.neon-arcade` in `Packages/ExperiencesCreative/NeonArcade`: Core (`ArcadeCatalog` with licensed content and a
validating decoder, `LicenseAudit`, `GameRun` schema 1 with `PlayerState`, `FallingObject`, `CollisionEvent`,
`GameSimulation.advance` — steering, spawning, swept collision, scoring, lives, game over), Experience (adapter
`ArcadeCore`, manifest, presenter drawing the field, player, hazards, orbs, score and lives through
`PrimitiveRenderer`, controls and the drag gesture), registered as a candidate with nine standard scenarios and seven
fixtures. Generated `docs/apps/neon-arcade/content-licenses.md`. Research: [research.md](research.md). Data:
[data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md).

## Technical Context

**Language**: Swift 6. **Dependencies**: `VisualCoreMath` (`Vec2`: `+ - *`, `dot`, `length`, `isFinite`; `Camera2D`),
`VisualCoreSimulation` (`SeededRandom` and its saved `State`; new collision API), `VisualCoreScenes` (`SceneNode`,
`Primitive.circle/.polygon/.rect/.line`, `DragRecognizer`, `GestureArbiter`), `VisualCoreRendering`
(`PrimitiveRenderer`), `VisualCoreExperience` (`ExperienceCore`, `ExperienceAction` with `step`, `MigrationChain`),
`VisualCoreExperienceHost`, `VisualCoreUI`. **Storage**: experience snapshot (`ArcadeState` schema 1); no files
written. **Testing**: host `swift test --package-path Packages/VisualCore --filter Collision2DTests`; ExperiencesCreative
on sim-27.2 (`NeonArcadeCoreTests`, `NeonArcadeExperienceTests`); public API check; app build and unit; runner iOS 27;
experience package check; contract; script tests. **Performance**: ≤ 24 objects × 1 swept test per step; ≤ 30 shapes
per frame plus field and HUD; 10,000-step runs measured, bounded by arithmetic (no wall-clock assert on CI).
**Constraints**: tests < 10 s; iOS 27 only; reference regression and iOS 26 at X-A10 (owner ruling 2026-11-14); no
NEEDS CLARIFICATION remains.

## Constitution Check

I PASS (draws through the host's `PrimitiveRenderer`; no context) · II PASS (generic overlap and swept tests in
VisualCore; rules, spawning, scoring and content in the experience) · II-a PASS (VisualCore change documented, API
baseline updated; seven-step reference regression at X-A10) · III PASS (the game advances only by host steps;
suspension stops it) · IV PASS (collision host-tested; run, catalog, audit and simulation tested without GPU) · V PASS
(snapshot schema 1 with migration chain) · VI PASS (render tests on the simulator) · VII PASS (controls for every action;
spoken state; Reduce Motion halves drawn motion only) · VIII PASS (no permission, no network) · IX PASS (objects ≤ 24,
events ≤ 256, score capped) · X PASS (all content original, MIT, recorded) · XI–XIII PASS. A10 rules (2.6.0):
authoritative GPU-free rules, readability (collision shapes drawn at rule size), visuals as code, offline, truthful,
bounded — PASS. Post-design: PASS.

## Project Structure

```text
Packages/VisualCore/Sources/VisualCoreSimulation/Collision2D.swift                                        new
Packages/VisualCore/Tests/VisualCoreSimulationTests/Collision2DTests.swift                                new
Packages/VisualCore/README.md (collision section), API baseline (check_public_api.py --update)           modify
Packages/ExperiencesCreative/NeonArcade/Core/{ArcadeCatalog,LicenseAudit,GameRun,GameSimulation}.swift    new domain
Packages/ExperiencesCreative/NeonArcade/CoreTests/{ArcadeCatalogTests,LicenseAuditTests,GameRunTests,
  GameSimulationTests,ReplayTests}.swift                                                                  new
Packages/ExperiencesCreative/NeonArcade/Experience/{Adapter/ArcadeCore.swift,Adapter/ArcadeManifest.swift,
  ArcadePresenter.swift,ArcadeControls.swift,NeonArcadeExperience.swift}                                  new
Packages/ExperiencesCreative/NeonArcade/ExperienceTests/{ArcadeCoreTests,ArcadeManifestTests,ArcadeSessionTests,
  ArcadeRenderTests,ArcadeTestSupport}.swift; NeonArcade/scenario-manifest.json                          new
Packages/ExperiencesCreative/Package.swift, Catalog/registrations.json, Apps/VisualCore/App/ExperienceRegistry.swift
  (candidate), project.yml (dependency), scripts/test_scripts.py (products list), RealCatalogTests (registrations),
  AppModelTests (synthetic candidate id moves past a10)                                                   modify
docs/apps/neon-arcade/{content-licenses.md (generated), visualcore-contract.json (G-COLLISION2D closed, G-GAMERULES
  progress)}                                                                                              new/modify
```

**Dependency direction** (targets `NeonArcadeCore`, `NeonArcadeExperience`, their test targets and the product
`NeonArcadeExperience`, as `scripts/check_experience_packages.py` requires; the adapter type is `ArcadeCore` so it does
not shadow the module): NeonArcadeExperience → NeonArcadeCore → VisualCoreSimulation, VisualCoreMath; the experience →
scenes, rendering, host, UI; nothing in VisualCore depends on the experience.

**Lifecycle**: the core holds the `GameRun` and the generator; `update(step:)` advances one fixed step (1/60 s,
`stepDuration`) unless paused or over; actions apply at their step, so the applied `run.steer` list with the seed is
the replay; the host steps only while running, so suspension never catches up. The presenter owns one
`PrimitiveRenderer` created when the host's context is current and released in teardown; it rebuilds the node tree
from the run each frame and never writes to it. **Migration**: none (new schema 1). **Rollback**: revert the commits
(the VisualCore file is additive).

## Parallel work

Agent A: `Collision2D.swift` + `Collision2DTests.swift` (contracts/api.md). Agent B: NeonArcade Core + CoreTests
(uses the collision API by its contract). Agent C: Experience target + tests after A and B land. Lead: README, API
baseline, Package.swift, registrations, registry, project.yml, xcodegen, manifest regeneration, license document,
contract, runs, commits.
