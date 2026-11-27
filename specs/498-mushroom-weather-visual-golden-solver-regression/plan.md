# Implementation Plan: R02-G20-08 — Mushroom Weather: visual golden and solver regression

**Branch**: `498-mushroom-weather-visual-golden-solver-regression` (spec directory only; work on `main`) |
**Date**: 2026-11-26 | **Spec**: [spec.md](spec.md)

## Summary

Add Mushroom Weather's regression net on Microscopic Aurora's feature-488 pattern: a host solver regression over all
100 levels (exact witness replay with per-action fingerprints and digests, a win on exactly the final run, exact
re-plan to the witness's actions with `arrangementsByDepth[size − 1]` equal to the counterexample's arrangements and
`work` at most `workBound`, twelve named alterations); a code-only golden set of 16 frame descriptions
(`MushroomWeatherGolden`, DEBUG or VISUALCORE_AUTOMATION only, pinned in `golden-frames.json` with SHA-256 digests,
1/8-pixel quantum fallback and a self-check); simulator tests that render the 16 frames against their descriptions and
bound memory over 12 open–draw–warn–close cycles; a named CI step and a local command. The release check's
forbidden-symbol list gains `MushroomWeatherGolden`. Research: [research.md](research.md). Data:
[data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Audit (2026-11-26)**: `MushroomWeatherSolver.plan` returns `actions`, `arrangement`, `arrangementsByDepth`,
`nearestMiss` and `work` (`workBound` 1,500); `MushroomWeatherWitness` decodes the 100 witness files (level, actions
ending with the run, digests, fingerprints after begin, after the tutorial on tutorial levels and after each action,
report, counterexample `depth`, `arrangements` and `nearestMiss`); after R02-G20-03, `MushroomWeatherSceneGeometry`
has `camera`, `project`, `floorCentre`, `capCentre`, `moonCentre`, `gaugeTrackCentre`, `actionsBar`, `litActions`,
`paintOrder`, `referencePoints` and the palette (`MushroomWeatherPalette`, 21 colours); the forest scene's
`release()` and `liveObjectCount` exist (feature 493); CI's `round02-host-tests` job has per-game regression steps
(Microscopic Aurora's the latest). **Language/Version**: Swift 6 and Python 3. **Primary dependencies**: the Mushroom
Weather Core, `StableHash.sha256Hex` of VisualCoreMath (no CryptoKit), VisualCoreRendering (`ProcessMemory.footprint()`,
iOS tests). No new package or target.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02`; simulator package tests on sim-27.2; app unit
tests; reference regression; script tests alone. Seed 2_498.
**Constraints**: no wall-clock assertion; each test under 10 s (the 100-level solver checks in 10 groups of 10); the
golden manifest is rewritten only with `MUSHROOM_WEATHER_WRITE_GOLDEN=1`; the memory bound applies only when the memory
class runs alone; the round-two host regression runs in its five chunks (Mushroom Weather in 3f).

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
Packages/ExperiencesRound02/MushroomWeather/Core/MushroomWeatherGolden.swift                       new  golden (lead)
Packages/ExperiencesRound02/MushroomWeather/golden-frames.json                                        new  16 frames
Packages/ExperiencesRound02/MushroomWeather/CoreTests/MushroomWeatherRegressionSolverTests.swift   new  100 levels (A)
Packages/ExperiencesRound02/MushroomWeather/CoreTests/MushroomWeatherRegressionGoldenTests.swift   new  digests (B)
Packages/ExperiencesRound02/MushroomWeather/ExperienceTests/MushroomWeatherRegressionGoldenFrameTests.swift  new (C)
Packages/ExperiencesRound02/MushroomWeather/ExperienceTests/MushroomWeatherRegressionMemoryTests.swift       new (C)
scripts/mushroom_weather_regression.py, scripts/test_scripts.py                new/edit  local command, test (D)
scripts/release_check.py                                                         edit  RELEASE_FORBIDDEN (lead)
.github/workflows/ci.yml                                                         edit  named step (lead)
docs/architecture/mushroom-weather.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md  edit (lead)
```

**Migration**: none (no state change). **Rollback**: revert the commits; nothing persists.

## Parallel work

The lead writes `MushroomWeatherGolden` and pins the manifest; agents A (solver regression), B (golden digests), C
(simulator golden frames and memory) and D (local command and its script test) write their new files in isolated
copies in parallel; the lead edits the shared release check, CI workflow and docs, and retests every result. No agent
runs `swift test` while a baseline or a chain of the lead runs.
