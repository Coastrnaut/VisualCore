# Implementation Plan: R02-G03-08 — Wave Knot Keeper: visual golden and solver regression

**Branch**: `328-wave-knot-keeper-visual-golden-solver-regression` (spec directory only; work on `main`) | **Date**:
2026-11-21 | **Spec**: [spec.md](spec.md)

## Summary

Add a regression net around Wave Knot Keeper without changing its rules, following feature 318. In the host-tested
`WaveKnotKeeperCore`: a solver regression over the 100 certified levels (witness replay with fingerprints, exact
re-solve with work at most 3,661, thirteen kinds of alteration detected and named) and `WaveKnotKeeperGolden`
(DEBUG or VISUALCORE_AUTOMATION only), which computes the code-only description of 16 golden frames (5 levels × 3 tiers
plus the hero frame) at 1,152 × 768 and its SHA-256 digests; descriptions and digests are pinned in
`golden-frames.json` (an equal digest passes, else positions within one 1/8-pixel quantum and equal colours; each pinned
digest must match its pinned description) and rewritten only with `WAVE_KNOT_KEEPER_WRITE_GOLDEN=1`. In the iOS
experience tests: the 16 golden frames rendered and checked against their descriptions, and 12 open-draw-warn-close
memory cycles measured with `ProcessMemory.footprint()` while the rope scene reports zero live renderers after each
close and warning (the footprint bound applied only when the class runs alone). A local script runs every part with one
summary; CI gains a named host step; the Release symbol check forbids `WaveKnotKeeperGolden`. Research:
[research.md](research.md). Data: [data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md). Quickstart:
[quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6. **Primary dependencies**: WaveKnotKeeperCore (solver, generator, witness, scene
geometry, palette); CryptoKit's SHA-256 for digests (as `AuroraLoomGolden`); VisualCoreRendering's
`ProcessMemory.footprint()` in the experience tests. No new package.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02 --filter WaveKnotKeeperRegression`;
simulator `xcodebuild_package.py --only-testing` for the golden-frame and memory classes; script tests (alone).
**Performance**: the solver regression is split into five bands; each re-solve is a breadth-first search of at most 3,661
expanded ropes (well under 0.1 s per level in a debug build).
**Constraints**: no rule, state or digest change; no wall-clock assertion; the golden file is never rewritten without the
switch.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I Proven renderer only | PASS — frames come from the existing scene; nothing new is drawn. |
| III Deterministic, testable core | PASS — descriptions are computed from fixed snapshots. |
| IV Host-testable | PASS — solver regression and golden digests run on the host. |
| V Implementation before devices | PASS — frame time and memory on hardware wait for D1–D3. |
| VI Evidence Over Assertion | PASS — pinned digests, counted work, measured footprints. |
| X Licensing and provenance | PASS — baselines are code-computed descriptions, never pictures. |
| XIII Code-driven visuals | PASS — no stored images. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/WaveKnotKeeper/Core/WaveKnotKeeperGolden.swift                                     new   golden set, descriptions, digests (lead)
Packages/ExperiencesRound02/WaveKnotKeeper/golden-frames.json                                                      new   16 pinned descriptions and digests
Packages/ExperiencesRound02/WaveKnotKeeper/CoreTests/WaveKnotKeeperRegressionSolverTests.swift                 new   100 levels, 12 alterations (agent A)
Packages/ExperiencesRound02/WaveKnotKeeper/CoreTests/WaveKnotKeeperRegressionGoldenTests.swift                 new   descriptions vs pinned digests (agent B)
Packages/ExperiencesRound02/WaveKnotKeeper/Experience/WaveKnotKeeperRopeScene.swift                          edit  live renderer count (lead)
Packages/ExperiencesRound02/WaveKnotKeeper/ExperienceTests/WaveKnotKeeperRegressionGoldenFrameTests.swift      new   16 frames rendered (agent C)
Packages/ExperiencesRound02/WaveKnotKeeper/ExperienceTests/WaveKnotKeeperRegressionMemoryTests.swift           new   12 cycles (agent C)
scripts/wave_knot_keeper_regression.py, scripts/test_scripts.py          new/edit  local command and its test (agent D)
scripts/release_check.py                                                    edit  RELEASE_FORBIDDEN + WaveKnotKeeperGolden (lead)
.github/workflows/ci.yml                                                    edit  named host step (lead)
docs/architecture/wave-knot-keeper.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md   edit (lead)
```

**Migration**: none (no state change). **Rollback**: revert the commits; nothing persists.

## Parallel work

The lead writes `WaveKnotKeeperGolden`, the scene count, the release list and the workflow step; agents A and B
write the host tests, agent C the two simulator test files, agent D the script and its test; the lead regenerates
`golden-frames.json`, retests every part and records checks after every agent has reported.
