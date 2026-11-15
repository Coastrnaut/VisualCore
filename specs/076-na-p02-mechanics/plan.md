# Implementation Plan: Neon Arcade — Phase 02 Neon Dodge complete mechanics

**Branch**: `076-na-p02-mechanics` (spec directory only; work on `main`) | **Date**: 2026-11-14 | **Spec**: [spec.md](spec.md)

## Summary

Finish G-GAMERULES (app-local). In `NeonArcadeCore`: `Lanes` (five centres), `SpawnPattern` and `PatternTable`
(rain, wall, zigzag, orb-trail; licensed data), `Difficulty` (level, fall-speed range, spawn gap, orb multiplier, with
the ceiling), `WaveDirector` (wave sequencing, pattern choice from the seeded generator, the spawns of a wave step);
`GameRun` schema 2 (`wave`, `waveStep`, `patternId`, `freeLane`, `patternCursor`) with `migrated()` from schema 1;
`GameSimulation.advance` spawns through the wave director and adds survival points and the orb multiplier;
`LicenseAudit` lists the patterns. In the experience: `ArcadeState` snapshot schema 2 (`MigrationChain(currentVersion:
2)`, step 1→2, `schemaOneExample()`), lane guides, the wave digits and "wave n" in the description; manifest fixtures
8–11. No VisualCore change. Research: [research.md](research.md). Data: [data-model.md](data-model.md). API:
[contracts/api.md](contracts/api.md).

## Technical Context

**Language**: Swift 6. **Dependencies**: as A10-P01 (`VisualCoreSimulation` `SeededRandom`, `Collision2D`;
`VisualCoreMath`; `VisualCoreScenes`; `VisualCoreRendering` `PrimitiveRenderer`; `VisualCoreExperience`
`MigrationChain`, `MigrationExample`; `VisualCoreExperienceHost`; `VisualCoreUI`). **Storage**: experience snapshot
(`ArcadeState` schema 2, migrating schema 1). **Testing**: ExperiencesCreative on sim-27.2 (`NeonArcadeCoreTests`,
`NeonArcadeExperienceTests`); app build and unit; runner iOS 27; package check; contract; script tests.
**Performance**: ≤ 5 spawns per step (a wall row), ≤ 24 objects; 10,000 steps × 20 seeds measured, bounded by
arithmetic. **Constraints**: tests < 10 s; iOS 27 only; reference regression and iOS 26 at X-A10; no NEEDS
CLARIFICATION remains.

## Constitution Check

I PASS (no context; lane guides and digits through `PrimitiveRenderer`) · II PASS (rules, patterns and difficulty are
experience domain; generator and collision reused) · II-a PASS (no VisualCore change) · III PASS (steps only while
running; suspension never catches up — fixture) · IV PASS (director, difficulty, patterns and migration tested without
GPU) · V PASS (schema 2 with schema-1 migration and stored example) · VI PASS (render tests on sim-27.2) · VII PASS
(wave spoken; Reduce Motion unchanged) · VIII PASS (no new data, permission or network) · IX PASS (spawn caps, object
cap, speed ceiling) · X PASS (patterns MIT, project author, in the license document) · XI–XIII PASS. A10 rules:
authoritative GPU-free rules, readability, bounded resources, truthful — PASS. Post-design: PASS.

## Project Structure

```text
Packages/ExperiencesCreative/NeonArcade/Core/{Lanes,SpawnPattern,Difficulty,WaveDirector}.swift            new
Packages/ExperiencesCreative/NeonArcade/Core/{GameRun,GameSimulation,LicenseAudit}.swift                   modify
Packages/ExperiencesCreative/NeonArcade/CoreTests/{WaveDirectorTests,DifficultyTests,GameRunMigrationTests}.swift new
Packages/ExperiencesCreative/NeonArcade/CoreTests/{GameSimulationTests,ReplayTests,GameRunTests,
  LicenseAuditTests}.swift                                                                                 modify
Packages/ExperiencesCreative/NeonArcade/Experience/Adapter/{ArcadeCore,ArcadeManifest}.swift               modify
Packages/ExperiencesCreative/NeonArcade/Experience/ArcadePresenter.swift (lanes, wave digits, description) modify
Packages/ExperiencesCreative/NeonArcade/ExperienceTests/{ArcadeCoreTests,ArcadeSessionTests,ArcadeRenderTests,
  ArcadeManifestTests}.swift; NeonArcade/scenario-manifest.json (regenerated)                              modify
Apps/VisualCore/App/ExperienceRegistry.swift (schema-1 example)                                            modify
docs/apps/neon-arcade/{content-licenses.md (regenerated), visualcore-contract.json (G-GAMERULES closed)}  modify
```

**Dependency direction**: unchanged (NeonArcadeExperience → NeonArcadeCore → VisualCoreSimulation, VisualCoreMath).
**Lifecycle**: unchanged; the wave advances only with host steps. **Migration**: snapshot 1 → 2 and `GameRun` 1 → 2
(wave 1, step 0, `rain`, no free lane, cursor 0). **Rollback**: revert the commits; a schema-2 snapshot is refused by
the Phase 01 build (newer schema), which then opens a new run.

## Parallel work

Agent A: Core (new files, GameRun schema 2, simulation, audit) + core tests. Agent B: Experience (snapshot schema 2,
presenter, manifest fixtures) + tests after A. Lead: registry example, manifest and license regeneration, contract,
runs, commits.
