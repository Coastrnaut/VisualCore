# Implementation Plan: R02-G02-08 — Lissajous Labyrinth: visual golden and solver regression

**Branch**: `318-lissajous-labyrinth-visual-golden-solver-regression` (spec directory only; work on `main`) | **Date**:
2026-11-21 | **Spec**: [spec.md](spec.md)

## Summary

Add a regression net around Lissajous Labyrinth without changing its rules, following feature 308. In the host-tested
`LissajousLabyrinthCore`: a solver regression over the 100 certified levels (witness replay with fingerprints, exact
re-solve with work at most 14,080, twelve kinds of alteration detected and named) and `LissajousLabyrinthGolden`
(DEBUG or VISUALCORE_AUTOMATION only), which computes the code-only description of 16 golden frames (5 levels × 3 tiers
plus the hero frame) at 1,152 × 768 and its SHA-256 digests; descriptions and digests are pinned in
`golden-frames.json` (an equal digest passes, else positions within one 1/8-pixel quantum and equal colours; each pinned
digest must match its pinned description) and rewritten only with `LISSAJOUS_LABYRINTH_WRITE_GOLDEN=1`. In the iOS
experience tests: the 16 golden frames rendered and checked against their descriptions, and 12 open-draw-warn-close
memory cycles measured with `ProcessMemory.footprint()` while the thread scene reports zero live renderers after each
close and warning (the footprint bound applied only when the class runs alone). A local script runs every part with one
summary; CI gains a named host step; the Release symbol check forbids `LissajousLabyrinthGolden`. Research:
[research.md](research.md). Data: [data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md). Quickstart:
[quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6. **Primary dependencies**: LissajousLabyrinthCore (solver, generator, witness, scene
geometry, palette); CryptoKit's SHA-256 for digests (as `AuroraLoomGolden`); VisualCoreRendering's
`ProcessMemory.footprint()` in the experience tests. No new package.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02 --filter LissajousLabyrinthRegression`;
simulator `xcodebuild_package.py --only-testing` for the golden-frame and memory classes; script tests (alone).
**Performance**: the solver regression is split into five bands; each re-solve is one prefiltered decision pass and a
breadth-first search (about 0.1 s per level in a debug build).
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
Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthGolden.swift                                     new   golden set, descriptions, digests (lead)
Packages/ExperiencesRound02/LissajousLabyrinth/golden-frames.json                                                      new   16 pinned descriptions and digests
Packages/ExperiencesRound02/LissajousLabyrinth/CoreTests/LissajousLabyrinthRegressionSolverTests.swift                 new   100 levels, 12 alterations (agent A)
Packages/ExperiencesRound02/LissajousLabyrinth/CoreTests/LissajousLabyrinthRegressionGoldenTests.swift                 new   descriptions vs pinned digests (agent B)
Packages/ExperiencesRound02/LissajousLabyrinth/Experience/LissajousLabyrinthThreadScene.swift                          edit  live renderer count (lead)
Packages/ExperiencesRound02/LissajousLabyrinth/ExperienceTests/LissajousLabyrinthRegressionGoldenFrameTests.swift      new   16 frames rendered (agent C)
Packages/ExperiencesRound02/LissajousLabyrinth/ExperienceTests/LissajousLabyrinthRegressionMemoryTests.swift           new   12 cycles (agent C)
scripts/lissajous_labyrinth_regression.py, scripts/test_scripts.py          new/edit  local command and its test (agent D)
scripts/release_check.py                                                    edit  RELEASE_FORBIDDEN + LissajousLabyrinthGolden (lead)
.github/workflows/ci.yml                                                    edit  named host step (lead)
docs/architecture/lissajous-labyrinth.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md   edit (lead)
```

**Migration**: none (no state change). **Rollback**: revert the commits; nothing persists.

## Parallel work

The lead writes `LissajousLabyrinthGolden`, the scene count, the release list and the workflow step; agents A and B
write the host tests, agent C the two simulator test files, agent D the script and its test; the lead regenerates
`golden-frames.json`, retests every part and records checks after every agent has reported.
