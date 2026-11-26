# Implementation Plan: R02-G19-08 — Microscopic Aurora: visual golden and solver regression

**Branch**: `488-microscopic-aurora-visual-golden-solver-regression` (spec directory only; work on `main`) |
**Date**: 2026-11-26 | **Spec**: [spec.md](spec.md)

## Summary

Add Microscopic Aurora's regression net on Microscopic Aurora's feature-468 pattern: a host solver regression over
all 100 levels (exact witness replay with per-action fingerprints and digests, a win on exactly the final play, exact
re-plan to the witness's placements with `setsByDepth[size − 1]` equal to the counterexample's sets and `work` at
most `workBound`, twelve named alterations); a code-only golden set of 16 frame descriptions
(`MicroscopicAuroraGolden`, DEBUG or VISUALCORE_AUTOMATION only, pinned in `golden-frames.json` with SHA-256
digests, 1/8-pixel quantum fallback and a self-check); simulator tests that render the 16 frames against their
descriptions and bound memory over 12 open–draw–warn–close cycles; a named CI step and a local command. The release
check's forbidden-symbol list gains `MicroscopicAuroraGolden`. Research: [research.md](research.md). Data:
[data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Audit (2026-11-26)**: `MicroscopicAuroraSolver.plan` returns `actions`, `wells`, `setsByDepth`, `nearestMiss` and `work`
(`workBound` 1,200); `MicroscopicAuroraWitness` decodes the 100 witness files (level, actions ending with the
play, digests, fingerprints after begin, after the tutorial on tutorial levels and after each action, report,
counterexample `depth`, `sets` and `nearestMiss`); `MicroscopicAuroraSceneGeometry` has `camera`, `project`, `world`,
`dishCentre`, `swimmerCentre`, `siteCentre`, `wellCentre`, `actionsBar`, `litActions`, `paintOrder`,
`referencePoints` and the palette (`MicroscopicAuroraPalette`,
18 colours); the dish scene's `release()` and `liveObjectCount` exist (feature 483); CI's
`round02-host-tests` job has per-game regression steps (Apsides Workshop's the latest).
**Language/Version**: Swift 6 and Python 3. **Primary dependencies**: the Microscopic Aurora Core, `StableHash.sha256Hex`
of VisualCoreMath (no CryptoKit), VisualCoreRendering (`ProcessMemory.footprint()`, iOS tests). No new package or
target.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02`; simulator package tests on sim-27.2; app unit
tests; reference regression; script tests alone. Seed 2_488.
**Constraints**: no wall-clock assertion; each test under 10 s (the 100-level solver checks in 10 groups of 10); the
golden manifest is rewritten only with `MICROSCOPIC_AURORA_WRITE_GOLDEN=1`; the memory bound applies only when the
memory class runs alone; the round-two host regression runs in its five chunks.

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
Packages/ExperiencesRound02/MicroscopicAurora/Core/MicroscopicAuroraGolden.swift                       new  golden (lead)
Packages/ExperiencesRound02/MicroscopicAurora/golden-frames.json                                          new  16 frames
Packages/ExperiencesRound02/MicroscopicAurora/CoreTests/MicroscopicAuroraRegressionSolverTests.swift   new  100 levels (A)
Packages/ExperiencesRound02/MicroscopicAurora/CoreTests/MicroscopicAuroraRegressionGoldenTests.swift   new  digests (B)
Packages/ExperiencesRound02/MicroscopicAurora/ExperienceTests/MicroscopicAuroraRegressionGoldenFrameTests.swift  new (C)
Packages/ExperiencesRound02/MicroscopicAurora/ExperienceTests/MicroscopicAuroraRegressionMemoryTests.swift       new (C)
scripts/microscopic_aurora_regression.py, scripts/test_scripts.py                new/edit  local command, test (D)
scripts/release_check.py                                                            edit  RELEASE_FORBIDDEN (lead)
.github/workflows/ci.yml                                                            edit  named step (lead)
docs/architecture/microscopic-aurora.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md  edit (lead)
```

**Migration**: none (no state change). **Rollback**: revert the commits; nothing persists.

## Parallel work

The lead writes `MicroscopicAuroraGolden` and pins the manifest; agents A (solver regression), B (golden digests), C
(simulator golden frames and memory) and D (local command and its script test) write their new files in isolated
copies in parallel; the lead edits the shared release check, CI workflow and docs, and retests every result. No agent
runs `swift test` while a baseline or a chain of the lead runs.
