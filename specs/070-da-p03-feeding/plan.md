# Implementation Plan: Digital Aquarium — Phase 03 Editing, feeding and save system

**Branch**: `070-da-p03-feeding` (spec directory only; work on `main`) | **Date**: 2026-11-14 | **Spec**: [spec.md](spec.md)

## Summary

Close G-FEEDPLACE in the experience, with no VisualCore change. In `DigitalAquariumCore`: `HabitatDocument` schema 3
adds `food` (pellet positions, ≤ 12); `Feeding` drops, sinks, eats and removes pellets and gives each fish a seek force
toward its nearest pellet within 4 units; `AquariumSimulation.advance` adds the seek force before the existing cap and
runs the feeding step; `DecorEditing` places, moves and removes decor inside the tank with the 12-piece limit. In the
experience: `AquariumCore` gains the actions `food.drop`, `decor.kind`, `decor.place`, `decor.move`,
`decor.remove`, the state field `decorKind` and snapshot schema 3; `AquariumGestures` turns pointer events into those
actions through `GestureArbiter` (tap → feed, long press → place, drag on a piece → move); the presenter draws pellets
and forwards touches; the controls offer every gesture action natively; the manifest adds fixtures for feeding, decor
editing and no fast-forward with food. Research: [research.md](research.md). Data: [data-model.md](data-model.md).
API: [contracts/api.md](contracts/api.md).

## Technical Context

**Language**: Swift 6. **Dependencies**: as A09-P02; additionally `VisualCoreScenes` (`GestureArbiter`,
`GestureDeclaration`, `GestureOutcome`, `PointerEvent`; verified in the clarification session) in the experience
target. **Storage**: experience snapshot (`AquariumState` schema 3 with `decorKind`; `HabitatDocument` schema 3 with
`food`; both migrate schemas 1 and 2). **Testing**: ExperiencesCreative on sim-27.2 (`DigitalAquariumCoreTests`,
`DigitalAquariumExperienceTests`); app build and unit; runner iOS 27; script tests. **Performance**: ≤ 12 pellets ×
≤ 24 fish distance checks per step. **Constraints**: tests < 10 s; iOS 27 only; no VisualCore change (no reference
regression needed beyond X-A09); no NEEDS CLARIFICATION remains.

## Constitution Check

I PASS (no context; pellets are circles of the existing primitive path) · II PASS (feeding, editing and gestures are
experience domain over the shared arbiter) · II-a PASS (no VisualCore change) · III PASS (a suspension stops host
steps; the session already never fast-forwards; a fixture proves it with food) · IV PASS (pure core functions,
host-testable) · V PASS (schema 3 with migrations from 1 and 2, stored examples) · VI PASS (render and session tests on
sim-27.2) · VII PASS (every gesture action has a labelled native control; `GestureAlternatives`) · VIII PASS (no new
data, permission or network) · IX PASS (pellet and decor limits, clamped positions, refusals with reasons) · X–XIII
PASS. A09 rules: bounded agents, procedural content, no realism claims — PASS. Post-design: PASS.

## Project Structure

```text
Packages/ExperiencesCreative/DigitalAquarium/Core/HabitatDocument.swift (schema 3, FoodPellet, food)     modify
Packages/ExperiencesCreative/DigitalAquarium/Core/Feeding.swift                                           new
Packages/ExperiencesCreative/DigitalAquarium/Core/DecorEditing.swift                                      new
Packages/ExperiencesCreative/DigitalAquarium/Core/AquariumSimulation.swift (seek force, feeding step)     modify
Packages/ExperiencesCreative/DigitalAquarium/CoreTests/{FeedingTests,DecorEditingTests}.swift             new
Packages/ExperiencesCreative/DigitalAquarium/CoreTests/{HabitatMigrationTests,HabitatDocumentTests}.swift modify
Packages/ExperiencesCreative/DigitalAquarium/Experience/AquariumGestures.swift                            new
Packages/ExperiencesCreative/DigitalAquarium/Experience/Adapter/AquariumCore.swift (actions, schema 3)    modify
Packages/ExperiencesCreative/DigitalAquarium/Experience/Adapter/AquariumManifest.swift (fixtures 8–10)    modify
Packages/ExperiencesCreative/DigitalAquarium/Experience/{AquariumPresenter,AquariumControls}.swift        modify
Packages/ExperiencesCreative/DigitalAquarium/ExperienceTests/AquariumGestureTests.swift                   new
Packages/ExperiencesCreative/DigitalAquarium/ExperienceTests/{AquariumCoreTests,AquariumSessionTests,
  AquariumRenderTests,AquariumManifestTests}.swift                                                         modify
Packages/ExperiencesCreative/DigitalAquarium/scenario-manifest.json                                       regenerate
Packages/ExperiencesCreative/Package.swift (VisualCoreScenes for the experience target, if not present)   modify
Apps/VisualCore/App/ExperienceRegistry.swift (schema-2 example)                                           modify
Catalog/registrations.json (a09 controls, if listed there)                                                modify
docs/apps/digital-aquarium/visualcore-contract.{json,md} (G-FEEDPLACE closed; M10 available)             modify
```

**Dependency direction**: experience → DigitalAquariumCore → VisualCoreSimulation, VisualCoreMath; experience →
VisualCoreScenes (arbiter), VisualCore host; nothing in VisualCore depends on the aquarium.

**Lifecycle**: unchanged; the gesture state lives in the presenter (main actor), is reset on teardown and sends
actions only through the port; a suspension stops host steps, so pellets stop sinking with the fish. **Migration**:
snapshot chain 1 → 2 (unchanged payload), 2 → 3 (adds `decorKind` 0); the document's `migrated(catalog:)` brings 1 and
2 to 3 (`food` missing → none). Stored examples: `schemaOneExample()` (kept) and `schemaTwoExample()` (new).
**Rollback**: revert the commits; no VisualCore API changes.

## Build and evidence

See [quickstart.md](quickstart.md); each command runs through
`python3 Tools/python/desktop_runbook.py run-check --stage A09-P03 --timeout 600 --name <check> -- <command>`.

## Parallel work

Agent A: document schema 3, `Feeding`, seek in `AquariumSimulation`, `FeedingTests`, migration tests. Agent B:
`DecorEditing` + `DecorEditingTests` and `AquariumGestures` + `AquariumGestureTests` (pure; no core actions).
Agent C (after A, B and the lead's core actions): presenter pellets and touch forwarding, controls, render tests. Lead:
`AquariumCore` actions and schema 3, registry example, manifest, Package.swift, docs, contract, runs, commits.
