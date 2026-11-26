# Implementation Plan: R02-G18-08 — Apsides Workshop: visual golden and solver regression

**Branch**: `478-apsides-workshop-visual-golden-solver-regression` (spec directory only; work on `main`) |
**Date**: 2026-11-26 | **Spec**: [spec.md](spec.md)

## Summary

Add Apsides Workshop's regression net on Apsides Workshop's feature-468 pattern: a host solver regression over
all 100 levels (exact witness replay with per-action fingerprints and digests, a win on exactly the final play, exact
re-plan to the witness's tunings with `orbitsByDepth[size − 1]` equal to the counterexample's orbits and `work` at
most `workBound`, twelve named alterations); a code-only golden set of 16 frame descriptions
(`ApsidesWorkshopGolden`, DEBUG or VISUALCORE_AUTOMATION only, pinned in `golden-frames.json` with SHA-256
digests, 1/8-pixel quantum fallback and a self-check); simulator tests that render the 16 frames against their
descriptions and bound memory over 12 open–draw–warn–close cycles; a named CI step and a local command. The release
check's forbidden-symbol list gains `ApsidesWorkshopGolden`. Research: [research.md](research.md). Data:
[data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Audit (2026-11-26)**: `ApsidesWorkshopSolver.plan` returns `actions`, `orbit`, `orbitsByDepth` and `work` (`workBound`
16,000, `maxTunings` 2); `ApsidesWorkshopWitness` decodes the 100 witness files (level, actions ending with the
play, digests, fingerprints after begin, after the tutorial on tutorial levels and after each action, report,
counterexample `depth` and `orbits`); `ApsidesWorkshopSceneGeometry` has `camera`, `project`, `world`,
`starCentre`, `orbiterCentre`, `planetCentre`, `actionsBar`, `litActions`, `paintOrder` (the periapsis marker at the
position of tick 0, the apoapsis marker at tick T / 2), `referencePoints` and the palette (`ApsidesWorkshopPalette`,
18 colours); the compass scene's `release()` and `liveObjectCount` exist (feature 473); CI's
`round02-host-tests` job has per-game regression steps (Apsides Workshop's the latest).
**Language/Version**: Swift 6 and Python 3. **Primary dependencies**: the Apsides Workshop Core, `StableHash.sha256Hex`
of VisualCoreMath (no CryptoKit), VisualCoreRendering (`ProcessMemory.footprint()`, iOS tests). No new package or
target.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02`; simulator package tests on sim-27.2; app unit
tests; reference regression; script tests alone. Seed 2_478.
**Constraints**: no wall-clock assertion; each test under 10 s (the 100-level solver checks in 10 groups of 10); the
golden manifest is rewritten only with `APSIDES_WORKSHOP_WRITE_GOLDEN=1`; the memory bound applies only when the
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
Packages/ExperiencesRound02/ApsidesWorkshop/Core/ApsidesWorkshopGolden.swift                       new  golden (lead)
Packages/ExperiencesRound02/ApsidesWorkshop/golden-frames.json                                          new  16 frames
Packages/ExperiencesRound02/ApsidesWorkshop/CoreTests/ApsidesWorkshopRegressionSolverTests.swift   new  100 levels (A)
Packages/ExperiencesRound02/ApsidesWorkshop/CoreTests/ApsidesWorkshopRegressionGoldenTests.swift   new  digests (B)
Packages/ExperiencesRound02/ApsidesWorkshop/ExperienceTests/ApsidesWorkshopRegressionGoldenFrameTests.swift  new (C)
Packages/ExperiencesRound02/ApsidesWorkshop/ExperienceTests/ApsidesWorkshopRegressionMemoryTests.swift       new (C)
scripts/apsides_workshop_regression.py, scripts/test_scripts.py                new/edit  local command, test (D)
scripts/release_check.py                                                            edit  RELEASE_FORBIDDEN (lead)
.github/workflows/ci.yml                                                            edit  named step (lead)
docs/architecture/apsides-workshop.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md  edit (lead)
```

**Migration**: none (no state change). **Rollback**: revert the commits; nothing persists.

## Parallel work

The lead writes `ApsidesWorkshopGolden` and pins the manifest; agents A (solver regression), B (golden digests), C
(simulator golden frames and memory) and D (local command and its script test) write their new files in isolated
copies in parallel; the lead edits the shared release check, CI workflow and docs, and retests every result. No agent
runs `swift test` while a baseline or a chain of the lead runs.
