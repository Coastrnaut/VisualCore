# Implementation Plan: Particle Universe — Phase 04 Scene editor and persistence

**Branch**: `036-pu-p04-scene-editor` (spec directory only; work on `main`) | **Date**: 2026-11-13 | **Spec**: [spec.md](spec.md)

## Summary

Add a versioned `SceneDocument` with v1 migration, an open sequence of small logged actions, `emitter.move`, and a
named scene library in the experience's storage, wired into the one app's registration and controls. Audit and
decisions: [research.md](research.md).

## Technical Context

**Language**: Swift 6. **Dependencies**: existing VisualCore packages (no change). **Storage**: `ExperienceStorage`
(app-owned area of the experience). **Testing**: ExperiencesCreative package tests on sim-27.2 and sim-26.5 (Core and
Experience tests); app UI test on the iOS 27.x phone; A04 scenario verification. **Performance**: each test < 10 s.
**Constraints**: replay determinism; digests regenerated only where state changes; no standalone-app changes.

## Constitution Check

| Principle | Result |
|---|---|
| I Renderer | PASS — unchanged drawing path. |
| II App-neutral API / II-a Reference | PASS — no VisualCore change; regression not triggered (D7). |
| III Lifecycle and threads | PASS — library I/O on the main actor like `FractalBookmarks`; the core stays pure. |
| IV Test-first | PASS. V Devices | PASS — device timings {device}. VI Evidence | PASS. |
| VII Native, accessible UI | PASS — buttons with labels and identifiers; system audits deferred to the device campaign. |
| VIII Privacy | PASS — local storage only. IX Bounded input | PASS — validated, versioned files. X–XIII | PASS. |

## Project Structure

```text
PU/Core/SceneDocument.swift                       new   SceneDocument, SavedForce, open actions, v1 migration
PU/CoreTests/SceneDocumentTests.swift             new
PU/CoreTests/Fixtures/scene-v1.json, scene-v2.json, scene-newer.json, scene-nan.json, scene-truncated.json   new
PU/Experience/Adapter/ParticleCore.swift          modify  controls scene.begin, emitter.define, force.define, look.define, emitter.move
PU/Experience/Adapter/ParticleManifest.swift      modify  "save and open" scenario; digests regenerated
PU/scenario-manifest.json                         modify  (regenerated)
PU/ExperienceTests/ParticleEditorTests.swift      new   open sequence, replay digest, move, rejection
PU/Experience/ParticleLibrary.swift               new   named library over ExperienceStorage
PU/ExperienceTests/ParticleLibraryTests.swift     new
PU/Experience/ParticleControls.swift              modify  Library and Move sections
PU/Experience/ParticleExperience.swift            modify  make(id:storage:reduceMotion:reduceFlashing:)
PU/Experience/ParticlePresenter.swift             modify  hold the library; emit open actions
Apps/VisualCore/App/ExperienceRegistry.swift      modify  pass launch.storage (lead)
Apps/VisualCore/Tests/UI/ParticleUniverse/PUSceneLibraryUITests.swift   new  save, open, relaunch
scripts/release_check.py                          modify  add PUSceneLibraryUITests to chunk j3 (lead)
```

**Dependency direction**: Core (pure) ← Adapter ← Experience/Presenter/Controls ← App registry. **Lifecycle**:
library reads on open of the sheet, writes on save; storage errors shown as a message. **Schema**: SceneDocument v2;
v1 migrates; newer refused. **Rollback**: revert commits; saved files are ignored by older builds (separate names).

## Tests by layer

Core: SceneDocumentTests. Experience (simulator): ParticleEditorTests, ParticleLibraryTests, existing PU tests.
App UI: PUSceneLibraryUITests (one pass on the iOS 27.x phone). Verification: `verify_experiences.py --only
a04.particle-universe` if registered for verification, else ExperiencesCreative tests carry the manifest digests.

## Parallel work

Agent A: SceneDocument + fixtures + tests (first; others code against its API in data-model.md). Agent B (after A):
ParticleCore + manifest + ParticleEditorTests. Agent C (after A): ParticleLibrary + tests. Lead: controls, presenter,
experience, registry, UI test, release-check chunk, digests.

## Complexity Tracking — none.
