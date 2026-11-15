# Implementation Plan: Physics Playground — Phase 02 Contacts and spring solver

**Branch**: `083-pp-p02-springs` (spec directory only; work on `main`) | **Date**: 2026-11-15 | **Spec**: [spec.md](spec.md)

## Summary

Close G-SPRINGS and G-BROADPHASE upstream in `VisualCoreSimulation`: `SpringAnchor2D`, `Spring2D`, `Springs2D.apply`
(impulses with stiffness and damping clamped to the stable bound for the tick), `AABB2D` and `Shape2D.bounds(at:)`,
`BroadPhase2D.pairs` (sweep and prune, equal to brute force) and warm starting in `ImpulseSolver2D` (stored impulses on
`Contact2D`, an `inout` solve; the Phase 01 solve unchanged). In the experience: world schema 2 (springs, gravity, drag
and stiffness levels) with the 1 → 2 migration, the tick order gravity and drag → springs → broad-phase contacts with
a warm-start cache → solve → integrate, the starting scene's hanging box and joined circles, spring drawing, three new
actions and controls, and the new fixtures. Research: [research.md](research.md). Data: [data-model.md](data-model.md).
API: [contracts/api.md](contracts/api.md).

## Technical Context

**Language**: Swift 6. **Dependencies**: as A11-P01 (`VisualCoreMath`, `VisualCoreSimulation` with `Contacts2D` and
`ImpulseSolver2D`, `VisualCoreScenes` with `Primitive.polyline`, `VisualCoreRendering`, `VisualCoreExperience`,
`VisualCorePersistence` (`MigrationChain`), `VisualCoreExperienceHost`, `VisualCoreUI`). **Storage**: snapshot schema 2.
**Testing**: host `swift test --package-path Packages/VisualCore --filter "Springs2DTests|BroadPhase2DTests|ImpulseSolver2DTests|Contacts2DTests"`;
ExperiencesCreative on sim-27.2; public API; app build and unit; runner iOS 27; experience packages; contract; script
tests. **Performance**: ≤ 48 bodies, ≤ 16 springs; broad-phase pairs only; 10 iterations; 10 s fixtures (1,200 ticks)
measured, longer runs bounded by arithmetic. **Constraints**: tests < 10 s; iOS 27 only; reference regression and iOS
26 at X-A11; no NEEDS CLARIFICATION remains.

## Constitution Check

I PASS (drawing through the host's renderer) · II PASS (springs, broad phase and warm starting are generic and go to
VisualCore; levels, scene and drawing stay in the experience) · II-a PASS (additive API, baseline update; reference
regression at X-A11) · III PASS · IV PASS (all physics host-tested without GPU) · V PASS (schema 2 with a 1 → 2
migration and a stored schema-1 example) · VI PASS · VII PASS (native controls with labels and values; spoken
description extended) · VIII PASS · IX PASS (springs ≤ 16, stiffness and damping clamped) · X PASS · XI–XIII PASS. A11
rules: authoritative CPU physics, stable and bounded (clamped springs, bounded stack), truthful — PASS. Post-design:
PASS.

## Project Structure

```text
Packages/VisualCore/Sources/VisualCoreSimulation/{Springs2D,BroadPhase2D}.swift                            new
Packages/VisualCore/Sources/VisualCoreSimulation/{Contacts2D,ImpulseSolver2D}.swift                         modify (additive)
Packages/VisualCore/Tests/VisualCoreSimulationTests/{Springs2DTests,BroadPhase2DTests}.swift                new
Packages/VisualCore/Tests/VisualCoreSimulationTests/ImpulseSolver2DTests.swift                              modify (warm start, stack)
Packages/VisualCore/README.md, API baseline                                                               modify
Packages/ExperiencesCreative/PhysicsPlayground/Core/{PhysicsWorld,StartingScene,WorldSimulation,WorldDiagnostics}.swift modify
Packages/ExperiencesCreative/PhysicsPlayground/Core/ForceLevels.swift                                      new
Packages/ExperiencesCreative/PhysicsPlayground/CoreTests/{SpringWorldTests,StackFixtureTests,MigrationTests}.swift new; others updated
Packages/ExperiencesCreative/PhysicsPlayground/Experience/{Adapter/PlaygroundCore,Adapter/PlaygroundManifest,
  PlaygroundPresenter,PlaygroundControls}.swift                                                            modify
Packages/ExperiencesCreative/PhysicsPlayground/ExperienceTests/*                                           modify
Packages/ExperiencesCreative/PhysicsPlayground/scenario-manifest.json                                      regenerate
Apps/VisualCore/App/ExperienceRegistry.swift (schema-1 example), Catalog/registrations.json (capabilities)   modify
docs/apps/physics-playground/visualcore-contract.json (G-SPRINGS, G-BROADPHASE closed; M06, M07 available)  modify
```

**Dependency direction**: unchanged (experience → core → VisualCoreSimulation, VisualCoreMath). **Lifecycle**: the
warm-start cache is saved with the world (research D3), so a restore continues exactly and the digest covers it. **Migration**: the
schema 1 → 2 step in `PlaygroundCore.migrations`; `schemaOneExample()` stored for the registry's migration check.
**Rollback**: revert the commits (VisualCore additions are additive).

## Parallel work

Agent A: `Springs2D`, `BroadPhase2D`, the warm-start additions and their tests. Agent B: the core changes and tests
(against contracts/api.md). Agent C: the experience changes after A and B. Lead: README, API baseline, registry,
registration, manifest regeneration, contract, runs, commits.
