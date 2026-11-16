# Implementation Plan: Simulation Lab — Phase 01 Algorithm specifications and CPU fixtures

**Branch**: `117-sl-p01-algorithms` (spec directory only; work on `main`) | **Date**: 2026-11-16 | **Spec**: [spec.md](spec.md)

## Summary

Build G-RULES, G-SPEC and G-SCHEDULER and the first candidate experience, with no VisualCore change:
- **Core** (GPU-free): the versioned `SimulationSpec` with validation, the parameter definitions of each family over
  `VisualCoreParameters` `ParameterDefinition`, seeded starts over `SeededRandom`, three CPU steppers (`AutomatonRule`,
  `GrayScott`, `WaveField`) over `VisualCoreSimulation` `FieldGrid` with `StoragePrecision`, the `SimulationScheduler`
  and the `SimulationState` codec (spec, scheduler, field bits as base64), joined by the GPU-free
  `SimulationModel` aggregate (spec, scheduler, field; step, advance, reset, digest) that the adapter wraps.
- **Experience**: `SimulationCore` (the `ExperienceCore` with the family, preset, run, pause, step, reset and speed
  actions, refusals `a16.invalid-choice` and `a16.unstable`), `SimulationPresenter` (colour-maps the CPU field and
  uploads it into a 64 × 64 `RenderTarget`, drawn full-screen by a `FieldPass` with `texelFetch`), controls, a scenario
  manifest (nine standard scenarios and five fixtures: one per family plus the HighLife and Mazes presets, as the
  planning catalog's content count asks), and a candidate registration.

Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contract: [contracts/core.md](contracts/core.md).

## Technical Context

**Language**: Swift 6, GLSL ES 3.00 (one display shader). **Dependencies** (verified in clarification):
`VisualCoreParameters`, `VisualCoreSimulation` (`FieldGrid`, `StoragePrecision`, `SeededRandom`), `VisualCoreMath`
(`NumericHygiene`), `VisualCoreExperience` (`ExperienceCore`, scenario manifests, quality tiers, the engine's fixed
step), `VisualCoreRendering` (`ResourceRegistry`, `RenderTarget`, `Texture.upload(rgba:)`, `FieldPass`),
`VisualCoreExperienceHost` (`ExperiencePresenter`, `ExperienceShell`). **Storage**: none (the session state holds the
field). **Testing**: core and experience tests in ExperiencesCreative on sim-27.2; app build and unit; runner iOS 27;
packages; contract; documented API; script tests. **Performance**: 64 × 64 CPU grids; at most 16 iterations per host
step (bounded by arithmetic: 64² × 16 cells per step). **Constraints**: tests < 10 s; iOS 27 only. No NEEDS
CLARIFICATION remains.

## Constitution Check

I PASS (one renderer; the display goes through `FieldPass`) · II PASS (field grid, storage precision, seeded random,
parameter definitions, numeric hygiene, field passes reused; no upstream change) · III PASS (deterministic, seeded) ·
IV PASS (all rules GPU-free in Core) · V PASS (spec and state versioned, refusals typed) · VI PASS (every rule has a
fixture) · VII PASS (controls with labels and values) · VIII PASS (no permission, no network) · IX PASS (grid, speed
and iteration caps) · X–XIII PASS (no assets). A16 rules: deterministic CPU truth, validity safeguards, resource
separation (the display reads a target it never writes in the same pass), bounded, truthful labels — PASS.
Post-design: PASS.

## Project Structure

```text
Packages/ExperiencesCreative/SimulationLab/Core/{SimulationSpec,ParameterCatalog,Seeding,AutomatonRule,GrayScott,
  WaveField,SimulationScheduler,SimulationState,SimulationModel}.swift                                         new
Packages/ExperiencesCreative/SimulationLab/CoreTests/{SimulationSpecTests,AutomatonRuleTests,GrayScottTests,
  WaveFieldTests,SchedulerTests,SimulationStateTests}.swift                                                    new
Packages/ExperiencesCreative/SimulationLab/Experience/{Adapter/SimulationCore,Adapter/SimulationManifest,
  SimulationPresenter,SimulationPalette,SimulationControls,SimulationLabExperience}.swift                       new
Packages/ExperiencesCreative/SimulationLab/ExperienceTests/{SimulationCoreTests,SimulationSessionTests,
  SimulationRenderTests,SimulationManifestTests,SimulationTestSupport}.swift                                     new
Packages/ExperiencesCreative/SimulationLab/scenario-manifest.json (generated)                                    new
Packages/ExperiencesCreative/Package.swift (four targets, product SimulationLabExperience)                       modify
Catalog/registrations.json, Packages/VisualCore/Tests/VisualCoreExperienceTests/Fixtures/Catalog/registrations.json,
  Apps/VisualCore/App/ExperienceRegistry.swift (candidate)                                                       modify
docs/apps/simulation-lab/visualcore-contract.json (G-RULES, G-SPEC, G-SCHEDULER closed)                          modify
```

**Dependency direction**: Experience → Core → VisualCoreSimulation, VisualCoreParameters, VisualCoreMath and
Foundation; the presenter → VisualCoreRendering and VisualCoreExperienceHost; nothing in VisualCore depends on it.

**Lifecycle**: the presenter creates its target, texture upload and display pass on setup, uploads the field after
each state change, rebuilds them after a context recreation from the CPU field, and releases them together on
teardown. **Migration**: none (schema 1). **Rollback**: revert the commits; the candidate disappears.

## Parallel work

Agent A: Core and CoreTests. Agent B (after A's types): Experience and ExperienceTests. Lead: Package.swift,
registration, manifest generation, contract, runs, commits.
