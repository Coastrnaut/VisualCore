# Implementation Plan: R02-G16-08 — Starlit Cartouche: visual golden and solver regression

**Branch**: `458-starlit-cartouche-visual-golden-solver-regression` (spec directory only; work on `main`) | **Date**:
2026-11-25 | **Spec**: [spec.md](spec.md)

## Summary

Add Starlit Cartouche's regression net on Voxel Origami's feature-448 pattern: a host solver regression over all 100
levels (exact witness replay with per-action fingerprints and digests, a win on exactly the last leg, exact re-plan to
the witness's legs with `statesByDepth[size − 1]` equal to the counterexample's states and `work` at most
`workBound`, thirteen named alterations); a code-only golden set of 16 frame descriptions (`StarlitCartoucheGolden`,
DEBUG or VISUALCORE_AUTOMATION only, pinned in `golden-frames.json` with SHA-256 digests, 1/8-pixel quantum fallback
and a self-check); simulator tests that render the 16 frames against their descriptions and bound memory over 12
open–draw–warn–close cycles; a named CI step and a local command. The release check's forbidden-symbol list gains
`StarlitCartoucheGolden`. Research: [research.md](research.md). Data: [data-model.md](data-model.md). API:
[contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Audit (2026-11-25)**: `StarlitCartoucheSolver.plan` returns `legs`, `statesByDepth` and `work` (`workBound` 300,000,
`maxLegs` 7); `StarlitCartoucheWitness` decodes the 100 witness files (level, actions, digests, fingerprints after
begin, after the tutorial on tutorial levels and after each action, counterexample `depth` and `states`);
`StarlitCartoucheSceneGeometry` has `camera(_:aspect:)`, `project(_:camera:)`, `starCentre`, `shipCentre`,
`trailMidpoint`, `actionsBar`, `litActions`, `paintOrder`, `referencePoints` and the palette
(`StarlitCartouchePalette`, 22 colours); the chart scene's `release()` and `liveObjectCount` exist (feature 453); CI's
`round02-host-tests` job has per-game regression steps (Voxel Origami's the latest).
**Language/Version**: Swift 6 and Python 3. **Primary dependencies**: the Starlit Cartouche Core,
`StableHash.sha256Hex` of VisualCoreMath (no CryptoKit), VisualCoreDiagnostics (`ProcessMemory.footprint()`). No new
package or target.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02`; simulator package tests on sim-27.2; app unit
tests; reference regression; script tests alone. Seed 2_458.
**Constraints**: no wall-clock assertion; each test under 10 s (the 100-level solver checks in 10 groups of 10, since
certifying one level takes milliseconds in a debug build); the golden manifest is rewritten only with
`STARLIT_CARTOUCHE_WRITE_GOLDEN=1`; the memory bound applies only when the memory class runs alone; the round-two host
regression runs in the five chunks of feature 457 (chunk 3 split in three).

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
Packages/ExperiencesRound02/StarlitCartouche/Core/StarlitCartoucheGolden.swift                       new  golden (lead)
Packages/ExperiencesRound02/StarlitCartouche/golden-frames.json                                      new  16 frames
Packages/ExperiencesRound02/StarlitCartouche/CoreTests/StarlitCartoucheRegressionSolverTests.swift   new  100 levels (A)
Packages/ExperiencesRound02/StarlitCartouche/CoreTests/StarlitCartoucheRegressionGoldenTests.swift   new  digests (B)
Packages/ExperiencesRound02/StarlitCartouche/ExperienceTests/StarlitCartoucheRegressionGoldenFrameTests.swift  new (C)
Packages/ExperiencesRound02/StarlitCartouche/ExperienceTests/StarlitCartoucheRegressionMemoryTests.swift       new (C)
scripts/starlit_cartouche_regression.py, scripts/test_scripts.py                    new/edit  local command, test (D)
scripts/release_check.py                                                            edit  RELEASE_FORBIDDEN (lead)
.github/workflows/ci.yml                                                            edit  named step (lead)
docs/architecture/starlit-cartouche.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md  edit (lead)
```

**Migration**: none (no state change). **Rollback**: revert the commits; nothing persists.

## Parallel work

The lead writes `StarlitCartoucheGolden` and pins the manifest; agents A (solver regression), B (golden digests), C
(simulator golden frames and memory) and D (local command and its script test) write their new files in isolated
copies in parallel; the lead edits the shared release check, CI workflow and docs, and retests every result. No agent
runs `swift test` while a baseline or a chain of the lead runs (feature 457's lesson: contention timed the chunks out).
