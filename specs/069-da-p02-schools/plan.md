# Implementation Plan: Digital Aquarium — Phase 02 Fish movement and visual prototype

**Branch**: `069-da-p02-schools` (spec directory only; work on `main`) | **Date**: 2026-11-14 | **Spec**: [spec.md](spec.md)

## Summary

Close G-STEERING upstream in `VisualCoreSimulation` (`SteeringAgent`, `SteeringBounds`, `SteeringParameters`,
`NeighbourSearch.neighbours(of:in:radius:limit:)` and `Steering.force(for:agents:neighbours:parameters:bounds:)`;
pure, deterministic, host-tested) and G-FISHSWIM in the experience (body wave, tail swing and turn bend drawn from
the state). In `DigitalAquariumCore`, `AquariumSimulation.advance` replaces the Phase 01 free wander with schooling
(VisualCore steering with species tuning, a reduced seeded wander turn, the Phase 01 speed cap and bound clamp kept),
`FishAgent` gains `turn`, `DecorPlacement` gains `rotation` and `scale`, the catalog gains licensed decor kinds and
starter decor, and `HabitatDocument` moves to schema 2 with a schema-1 migration. `AquariumState` (snapshot) moves to
schema 2 and restores schema 1. The manifest adds fixtures for schooling and for save/load of species, decor transforms
and lighting. Research: [research.md](research.md). Data: [data-model.md](data-model.md). API:
[contracts/api.md](contracts/api.md).

## Technical Context

**Language**: Swift 6. **Dependencies**: as A09-P01 (`VisualCoreMath`, `VisualCoreSimulation`, `VisualCoreExperience`,
`VisualCoreExperienceHost`, `VisualCoreScenes`, `VisualCorePersistence`, `VisualCoreUI`); new VisualCore API only in
`VisualCoreSimulation`, depending on `VisualCoreMath.Vec2` (verified: `+ - * /`, `dot`, `length`, `normalized`,
`distance(to:)`, `isFinite`). **Storage**: experience snapshot (`AquariumState` schema 2, `HabitatDocument` schema 2,
both migrating schema 1). **Testing**: host `swift test --package-path Packages/VisualCore --filter SteeringTests`
(VisualCore); ExperiencesCreative on sim-27.2 (`DigitalAquariumCoreTests`, `DigitalAquariumExperienceTests`); app build
and unit; runner iOS 27; public API; script tests. **Performance**: 24 fish × at most 6 neighbours per step (linear scan
of 24); 10,000 steps × 20 seeds measured on the host and bounded by arithmetic, no wall-clock assertions on CI.
**Constraints**: tests < 10 s; iOS 27 only; reference regression at X-A09; no NEEDS CLARIFICATION remains.

## Constitution Check

I PASS (no context, no renderer change; fish and decor are polygons of the existing scene path) · II PASS (generic
steering in VisualCore, species tuning, decor and animation in the experience) · II-a PASS (VisualCore change; the
seven-step reference regression runs at X-A09) · III PASS (lifecycle unchanged from A09-P01; steps only while running)
· IV PASS (steering and search host-tested; aquarium on the simulator) · V PASS (schema 2 with schema-1 migration and
stored schema-1 example) · VI PASS (render tests on sim-27.2) · VII PASS (Reduce Motion halves drawn motion only; no new
control) · VIII PASS (no new data, permission or network) · IX PASS (neighbour limit, force cap, speed cap, clamp,
count caps, refused decor) · X–XIII PASS. A09 rules (constitution 2.5.0): procedural content with recorded licenses
(decor kinds MIT, project author), bounded agents, no realism claims — PASS. Post-design: PASS.

## Project Structure

```text
Packages/VisualCore/Sources/VisualCoreSimulation/Steering.swift                                       new
Packages/VisualCore/Tests/VisualCoreSimulationTests/SteeringTests.swift                               new
Packages/ExperiencesCreative/DigitalAquarium/Core/SpeciesCatalog.swift (DecorKind, DecorShape,
  DecorSpot, StarterHabitat.decor, catalog.decor, bundled decor)                                      modify
Packages/ExperiencesCreative/DigitalAquarium/Core/CatalogDecoder.swift (decor kinds validated)        modify
Packages/ExperiencesCreative/DigitalAquarium/Core/LicenseAudit.swift (decor kinds audited)            modify
Packages/ExperiencesCreative/DigitalAquarium/Core/HabitatDocument.swift (schema 2, turn, rotation,
  scale, starter decor, migration, validation)                                                        modify
Packages/ExperiencesCreative/DigitalAquarium/Core/AquariumSimulation.swift (schooling)                modify
Packages/ExperiencesCreative/DigitalAquarium/Core/SchoolMetrics.swift (cohesion, agreement)           new
Packages/ExperiencesCreative/DigitalAquarium/CoreTests/{SchoolingTests,HabitatMigrationTests}.swift   new
Packages/ExperiencesCreative/DigitalAquarium/CoreTests/{AquariumSimulationTests,HabitatDocumentTests,
  SpeciesCatalogTests,LicenseAuditTests}.swift                                                        modify
Packages/ExperiencesCreative/DigitalAquarium/Experience/Adapter/AquariumCore.swift (snapshot schema 2) modify
Packages/ExperiencesCreative/DigitalAquarium/Experience/Adapter/AquariumManifest.swift (fixtures 6, 7) modify
Packages/ExperiencesCreative/DigitalAquarium/Experience/AquariumPresenter.swift (wave, swing, bend,
  decor drawing)                                                                                      modify
Packages/ExperiencesCreative/DigitalAquarium/ExperienceTests/{AquariumCoreTests,AquariumManifestTests,
  AquariumRenderTests,AquariumSessionTests}.swift                                                     modify
Packages/ExperiencesCreative/DigitalAquarium/ExperienceTests/Fixtures/aquarium-schema1.json           new
Packages/ExperiencesCreative/DigitalAquarium/scenario-manifest.json                                   regenerate
docs/apps/digital-aquarium/content-licenses.md                                                        regenerate
docs/api/visualcore-public-api.txt, Packages/VisualCore/README.md,
  docs/apps/digital-aquarium/visualcore-contract.{json,md} (G-STEERING, G-FISHSWIM closed)            modify
```

**Dependency direction**: experience → DigitalAquariumCore → VisualCoreSimulation (Steering) → VisualCoreMath; nothing
in VisualCore depends on the aquarium.

**Lifecycle**: as A09-P01; a host step runs one `AquariumSimulation.advance` unless paused; drawing reads the state
and the Reduce Motion factor and never writes the state. **Migration**: `HabitatDocument` and `AquariumState` decode
schema 1 (missing `turn`, `rotation`, `scale` take 0, 0, 1; empty decor gets the habitat's starter decor) and write
schema 2; a schema-1 example is stored as a test fixture. **Rollback**: revert the commits; the VisualCore API is
additive; a schema-2 state is not readable by the Phase 01 build (acceptable: no release exists).

## Build and evidence

See [quickstart.md](quickstart.md); each command runs through
`python3 Tools/python/desktop_runbook.py run-check --stage A09-P02 --timeout 600 --name <check> -- <command>`.

## Parallel work

Agent A: `Steering.swift` + `SteeringTests.swift` (VisualCore host). Agent B: catalog decor, decoder, license audit,
document schema 2 and migration with their tests (core files other than `AquariumSimulation`). Agent C (after A and
B): `AquariumSimulation` schooling, `SchoolMetrics`, `SchoolingTests`. Agent D (after B): presenter animation and decor
drawing with render tests. Lead: `AquariumCore` snapshot schema 2, manifest fixtures, schema-1 fixture file, docs,
API baseline, contract, regeneration, runs, commits.
