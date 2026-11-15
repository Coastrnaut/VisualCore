# Implementation Plan: Physics Playground — Phase 05 Numerical stability and performance audit

**Branch**: `086-pp-p05-stability` (spec directory only; work on `main`) | **Date**: 2026-11-15 | **Spec**: [spec.md](spec.md)

## Summary

Close G-STABILITY in the experience, with no VisualCore change: the world (schema 4) gains per-body sleep state with
the clarified thresholds and wake triggers, the tick skips sleeping bodies and their pairs and counts its work
(`WorkCount`, derived); stress, energy, replay and budget fixtures audit the physics; the adapter becomes state schema
5 (its world at schema 4) with the 4 → 5 migration, declares three quality tiers and forwards the host's quality
profile; the presenter maps tier and Low Power Mode to drawing budgets; the registration lists three levels and a
truthful summary; a claims scan, a capability table and the device-campaign document complete the storefront and the
device plan. Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contract:
[contracts/stability.md](contracts/stability.md).

## Technical Context

**Language**: Swift 6. **Dependencies**: unchanged (`VisualCoreExperience` `QualityProfile` and the host's quality
tiers; `ProcessInfo.isLowPowerModeEnabled` injected as in Neon Arcade). **Storage**: snapshot state schema 5 (world
schema 4). **Testing**: ExperiencesCreative on sim-27.2; app build and unit; runner iOS 27; experience packages;
contract; claims scan; catalog check; script tests. **Performance**: counted work per tick (≤ 1,320 narrow-phase
tests at 48 bodies); host median tick time measured over 600 ticks and recorded, never asserted. **Constraints**: tests
< 10 s; iOS 27 only; reference regression and iOS 26 at X-A11; no NEEDS CLARIFICATION remains.

## Constitution Check

I PASS · II PASS (sleep, budgets and levels are app-local as the contract assigns; host quality tiers reused) · II-a N/A
· III PASS (Low Power Mode lowers drawing only) · IV PASS (stress, sleep, budget and replay tested without GPU) · V PASS
(world schema 4 and state schema 5 with migrations and a stored schema-4 state example) · VI PASS · VII PASS (levels
never remove labels or controls) · VIII PASS · IX PASS (stated work budget, caps under stress) · X PASS · XI–XIII PASS.
A11 rules: stable and bounded, truthful claims (scan), authoritative physics independent of quality — PASS. Post-design:
PASS.

## Project Structure

```text
Packages/ExperiencesCreative/PhysicsPlayground/Core/{Sleep,WorkCount,DrawingBudget}.swift                          new
Packages/ExperiencesCreative/PhysicsPlayground/Core/{PhysicsWorld,WorldSimulation,WorldEditing}.swift               modify
Packages/ExperiencesCreative/PhysicsPlayground/CoreTests/{SleepTests,StressTests,WorkBudgetTests,DrawingBudgetTests}.swift new
Packages/ExperiencesCreative/PhysicsPlayground/Experience/{Adapter/PlaygroundCore,Adapter/PlaygroundManifest,
  PlaygroundPresenter,PhysicsPlaygroundExperience}.swift                                                           modify
Packages/ExperiencesCreative/PhysicsPlayground/ExperienceTests/{PlaygroundQualityTests}.swift                       new; others updated
Packages/ExperiencesCreative/PhysicsPlayground/scenario-manifest.json                                               regenerate
Catalog/registrations.json (summary, capabilities, quality_tiers level-0…2), Apps/VisualCore/App/ExperienceRegistry.swift
  (schema-4 state example)                                                                                         modify
docs/apps/physics-playground/{README.md (capability → test table), device-campaign.md}                             new/modify
specs/086-pp-p05-stability/scan-claims.sh                                                                          new
docs/apps/physics-playground/visualcore-contract.json (G-STABILITY closed; M13, M15 notes)                           modify
```

**Dependency direction**: unchanged. **Lifecycle**: the experience wrapper forwards `qualityProfile` and
`setQualityTier`; the presenter re-evaluates its drawing budget each frame from the tier and Low Power Mode; the core
stores no tier. **Migration**: world 3 → 4 (`asleep` false, `restTicks` 0) inside the state migration 4 → 5;
`schemaFourExample()` stored for the registry. **Rollback**: revert the commits.

## Parallel work

Agent A: core sleep, work count, drawing budgets and their tests. Agent B (after A): adapter, presenter, wrapper,
manifest and experience tests. Agent C (parallel to A): README capability table, device-campaign document, claims scan
(documents only). Lead: registration, registry, contract, regeneration, runs, commits.
