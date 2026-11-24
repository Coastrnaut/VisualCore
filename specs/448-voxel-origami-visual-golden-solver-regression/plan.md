# Implementation Plan: R02-G15-08 — Voxel Origami: visual golden and solver regression

**Branch**: `448-voxel-origami-visual-golden-solver-regression` (spec directory only; work on `main`) | **Date**:
2026-11-24 | **Spec**: [spec.md](spec.md)

## Summary

Add Voxel Origami's regression net on Moonlit Mechanism's feature-438 pattern: a host solver regression over all 100
levels (exact witness replay with per-action fingerprints and digests, a win on exactly the last turn, exact re-plan to
the witness's turns with `statesByDepth[size − 1]` equal to the counterexample's states and `work` at most
`workBound`, eleven named alterations); a code-only golden set of 16 frame descriptions (`VoxelOrigamiGolden`, DEBUG
or VISUALCORE_AUTOMATION only, pinned in `golden-frames.json` with SHA-256 digests, 1/8-pixel quantum fallback and a
self-check); simulator tests that render the 16 frames against their descriptions and bound memory over 12
open–draw–warn–close cycles; a named CI step and a local command. The release check's forbidden-symbol list gains
`VoxelOrigamiGolden`. Research: [research.md](research.md). Data: [data-model.md](data-model.md). API:
[contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Audit (2026-11-24)**: `VoxelOrigamiSolver.plan` returns `turns`, `statesByDepth` and `work` (`workBound` 300,000);
`VoxelOrigamiWitness` decodes the 100 witness files (level, actions, digests, fingerprints after begin, after the
tutorial on tutorial levels and after each action, counterexample `depth` and `states`); `VoxelOrigamiSceneGeometry`
has `camera(_:aspect:)`, `project`, `world`, `cubeCentre`, `hingeMark`, `coveredPip`, `litPips`, `movesBar`,
`litMoves`, `paintOrder` and the palette (`VoxelOrigamiPalette`); the scene's `release()` and `liveObjectCount` exist
(feature 443); CI's `round02-host-tests` job has per-game regression steps (Moonlit Mechanism's the latest).
**Language/Version**: Swift 6 and Python 3. **Primary dependencies**: the Voxel Origami Core, `StableHash.sha256Hex` of
VisualCoreMath (no CryptoKit), VisualCoreDiagnostics (`ProcessMemory.footprint()`). No new package or target.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02`; simulator package tests on sim-27.2; app unit
tests; reference regression; script tests alone. Seed 2_448.
**Constraints**: no wall-clock assertion; each test under 10 s (the 100-level solver checks in 20 groups of 5, since a
six-turn band-5 search costs over a second in a debug build); the golden manifest is rewritten only with
`VOXEL_ORIGAMI_WRITE_GOLDEN=1`; the memory bound applies only when the memory class runs alone.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| IV Host-testable | PASS — solver and golden-description checks on the host; rendering and memory on the simulator. |
| VII Determinism | PASS — counted work and digests, never seconds. |
| X No stored pictures / XIII Code-driven visuals | PASS — baselines are code-computed descriptions, not images. |
| XI One app | PASS — the golden set is test-only and forbidden in the Release binary. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/VoxelOrigami/Core/VoxelOrigamiGolden.swift                         new   golden set (lead)
Packages/ExperiencesRound02/VoxelOrigami/golden-frames.json                                    new   16 pinned frames
Packages/ExperiencesRound02/VoxelOrigami/CoreTests/VoxelOrigamiRegressionSolverTests.swift     new   100 levels (A)
Packages/ExperiencesRound02/VoxelOrigami/CoreTests/VoxelOrigamiRegressionGoldenTests.swift     new   digests (B)
Packages/ExperiencesRound02/VoxelOrigami/ExperienceTests/VoxelOrigamiRegressionGoldenFrameTests.swift  new  (C)
Packages/ExperiencesRound02/VoxelOrigami/ExperienceTests/VoxelOrigamiRegressionMemoryTests.swift       new  (C)
scripts/voxel_origami_regression.py, scripts/test_scripts.py                         new/edit  local command, test (D)
scripts/release_check.py                                                             edit  RELEASE_FORBIDDEN (lead)
.github/workflows/ci.yml                                                             edit  named step (lead)
docs/architecture/voxel-origami.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md  edit (lead)
```

**Migration**: none (no state change). **Rollback**: revert the commits; nothing persists.

## Parallel work

The lead writes `VoxelOrigamiGolden` and pins the manifest; agents A (solver regression), B (golden digests), C
(simulator golden frames and memory) and D (local command and its script test) write their new files in parallel; the
lead edits the shared release check, CI workflow and docs, and retests every result.
