# Implementation Plan: Physics Playground — Phase 04 Saved experiments and tutorials

**Branch**: `085-pp-p04-experiments` (spec directory only; work on `main`) | **Date**: 2026-11-15 | **Spec**: [spec.md](spec.md)

## Summary

Close G-EXPERIMENTS in the experience, with no VisualCore change: the core gains `Presets` (free play, pendulum,
spring chain, stacked objects, licensed), `Tutorials` (two tutorials with conditions), an `ExperimentDocument` codec and
state schema 4 (origin, starting world, tutorial progress) with the 3 → 4 migration; reset restores the starting world;
the adapter gains `experiment.preset`, `tutorial.start`, `tutorial.stop`; an `ExperimentStore` over `ExperienceStorage`
saves, reads, refuses and clears four slots; the presenter opens a slot by restoring a snapshot; the controls add the
preset picker, the slot list with save/open/clear, and the tutorial card. Research: [research.md](research.md). Data:
[data-model.md](data-model.md). Actions and files: [contracts/experiments.md](contracts/experiments.md).

## Technical Context

**Language**: Swift 6. **Dependencies**: unchanged (`VisualCoreExperience` `ExperienceStorage`, `ExperienceSnapshot`;
`VisualCoreExperienceHost` `ExperienceShell.snapshot()`/`restore(_:)`). **Storage**: snapshot schema 4; four files
`experiment-<slot>.json` in the experience's storage. **Testing**: ExperiencesCreative on sim-27.2 (core and experience
tests, storage in a temporary directory, sample files under `ExperienceTests/Fixtures`); app build and unit; runner iOS
27; experience packages; contract; script tests. **Performance**: a document ≤ 48 bodies and 16 springs (a few KB);
energy fixtures 1,200 and 600 ticks. **Constraints**: tests < 10 s; iOS 27 only; no NEEDS CLARIFICATION remains.

## Constitution Check

I PASS · II PASS (ExperienceStorage and the shell's restore reused; content and rules app-local as the contract
assigns) · II-a N/A (no VisualCore change) · III PASS (saving never blocks the world; restore through the host) · IV
PASS (presets, tutorials and documents tested without GPU) · V PASS (schema 4 with migration and stored examples;
documents versioned, refused when damaged or newer) · VI PASS · VII PASS (tutorial steps spoken; every control labelled)
· VIII PASS (files only in the experience's own storage; no network) · IX PASS (four slots, bounded documents) · X PASS
(presets and tutorial texts licensed and listed) · XI–XIII PASS. Post-design: PASS.

## Project Structure

```text
Packages/ExperiencesCreative/PhysicsPlayground/Core/{Presets,Tutorials,ExperimentDocument}.swift                  new
Packages/ExperiencesCreative/PhysicsPlayground/Core/{LicenseAudit,PhysicsWorld}.swift                              modify
Packages/ExperiencesCreative/PhysicsPlayground/CoreTests/{PresetTests,TutorialTests,ExperimentDocumentTests,
  SpringEnergyFixtureTests}.swift                                                                                  new
Packages/ExperiencesCreative/PhysicsPlayground/Experience/ExperimentStore.swift                                    new
Packages/ExperiencesCreative/PhysicsPlayground/Experience/{Adapter/PlaygroundCore,Adapter/PlaygroundManifest,
  PlaygroundPresenter,PlaygroundControls,PhysicsPlaygroundExperience}.swift                                        modify
Packages/ExperiencesCreative/PhysicsPlayground/ExperienceTests/{ExperimentStoreTests,ExperimentSampleFileTests}.swift new
Packages/ExperiencesCreative/PhysicsPlayground/ExperienceTests/Fixtures/experiment-{valid,newer,damaged,truncated}.json new
Packages/ExperiencesCreative/Package.swift (resources: [.copy("Fixtures")] for PhysicsPlaygroundExperienceTests)    modify
Packages/ExperiencesCreative/PhysicsPlayground/scenario-manifest.json, docs/apps/physics-playground/content-licenses.md regenerate
Apps/VisualCore/App/ExperienceRegistry.swift (schema-3 example), Catalog/registrations.json (capabilities)           modify
docs/apps/physics-playground/visualcore-contract.json (G-EXPERIMENTS closed; M10, M14 notes)                          modify
```

**Dependency direction**: unchanged. **Lifecycle**: the store reads a slot only on request and writes atomically;
opening a slot restores a snapshot through the shell (the engine validates it); a refused document leaves the world and
the file unchanged. **Migration**: 3 → 4 in `PlaygroundCore.migrations`; `schemaThreeExample()` stored for the
registry. **Rollback**: revert the commits; saved files of schema 1 stay readable by later versions.

## Parallel work

Agent A: core presets, tutorials, document codec, schema 4, license rows and their tests. Agent B (after A): store,
adapter, presenter, controls, manifest, sample files and experience tests. Lead: Package.swift, registry, registration,
contract, regeneration, runs, commits.
