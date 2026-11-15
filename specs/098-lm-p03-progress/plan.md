# Implementation Plan: Light Maze — Phase 03 Core levels and progress

**Branch**: `098-lm-p03-progress` (spec directory only; work on `main`) | **Date**: 2026-11-15 | **Spec**: [spec.md](spec.md)

## Summary

Close G-LEVELS in the experience, with no VisualCore change: a pure `Progress` document (schema 1, validating codec) and
`MazeState` schema 2 with the bounded move list and `move.undo` in the core; a `ProgressStore` over `ExperienceStorage`
(as `ExperimentStore`) owned by the presenter, which records a level solved on the frame the solved state appears,
opens the next one and saves; locked levels refused where a person chooses them (Level menu, Next level); Undo and
Restart controls. Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contract:
[contracts/progress.md](contracts/progress.md).

## Technical Context

**Language**: Swift 6. **Dependencies**: `VisualCoreExperience` (`ExperienceStorage` with atomic `write(_:to:)`,
`StorageError`, `MigrationChain`), the A13-P01/P02 core and experience. **Storage**: `progress.json` (schema 1, ≤ 16 KB)
in the experience's storage; snapshot state schema 2. **Testing**: ExperiencesCreative on sim-27.2; app build and unit;
runner iOS 27; packages; contract; script tests. **Performance**: one save per progress change; at most 64 moves.
**Constraints**: tests < 10 s; iOS 27 only; no NEEDS CLARIFICATION remains.

## Constitution Check

I PASS · II PASS (storage reused; nothing new upstream) · II-a N/A · III PASS · IV PASS (progress and moves tested
without GPU) · V PASS (state schema 2 with migration; progress file versioned, refusals untouched) · VI PASS · VII PASS
(Undo, Restart, Level menu with labels and lock words) · VIII PASS (device-only file, no network) · IX PASS (bounded
moves and file size) · X PASS · XI–XIII PASS. A13 rules: deterministic rules unaffected by progress (replay unchanged),
offline and private — PASS. Post-design: PASS.

## Project Structure

```text
Packages/ExperiencesCreative/LightMaze/Core/Progress.swift                                                 new
Packages/ExperiencesCreative/LightMaze/Core/MazeState.swift (schema 2: moves, undo)                         modify
Packages/ExperiencesCreative/LightMaze/CoreTests/{ProgressTests,MovesTests,SolutionReplayTests}.swift       new
Packages/ExperiencesCreative/LightMaze/CoreTests/MazeStateTests.swift                                       modify
Packages/ExperiencesCreative/LightMaze/Experience/ProgressStore.swift                                       new
Packages/ExperiencesCreative/LightMaze/Experience/{Adapter/MazeCore,Adapter/MazeManifest,MazePresenter,MazeControls,
  LightMazeExperience}.swift                                                                                modify
Packages/ExperiencesCreative/LightMaze/ExperienceTests/{ProgressStoreTests,MazeProgressTests}.swift         new
Packages/ExperiencesCreative/LightMaze/scenario-manifest.json                                               regenerate
Apps/VisualCore/App/ExperienceRegistry.swift (schema-1 example)                                             modify
docs/apps/light-maze/visualcore-contract.json (G-LEVELS closed by A13-P03; rows M06, M09, M20)               modify
```

**Dependency direction**: unchanged. **Lifecycle**: the presenter loads progress once at creation (refusals reported,
fresh progress used), compares each frame's solved state with the last, records and saves on change, and never writes
the engine state; the engine holds the moves. **Migration**: state 1 → 2 (no moves); `MazeCore.schemaOneExample()`
stored for the registry. **Rollback**: revert the commits; a progress file written by this phase is ignored by older
builds (they never read it).

## Parallel work

Agent A: core (`Progress`, `MazeState` schema 2, core tests). Agent B (after A): experience (`ProgressStore`, presenter,
controls, adapter, manifest, tests). Lead: registry example, regeneration, contract, runs, commits.
