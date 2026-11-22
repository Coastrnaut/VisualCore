# Implementation Plan: R02-G06-08 — Chrono Constellator: visual golden and solver regression

**Branch**: `358-chrono-constellator-visual-golden-solver-regression` (spec directory only; work on `main`) | **Date**:
2026-11-22 | **Spec**: [spec.md](spec.md)

## Summary

Add a regression net around Chrono Constellator without changing its rules, following feature 348. In the host-tested
`ChronoConstellatorCore`: a solver regression over the 100 certified levels (witness replay with per-tick digests and fingerprints,
exact re-solve with the witness's phase changes, lower bound, window, windows and blocked count, twelve kinds of alteration detected and named) and `ChronoConstellatorGolden`
(DEBUG or VISUALCORE_AUTOMATION only), which computes the code-only description of 16 golden frames (5 levels × 3 tiers
plus the hero frame) at 1,152 × 768 and its SHA-256 digests; descriptions and digests are pinned in
`golden-frames.json` (an equal digest passes, else positions within one 1/8-pixel quantum and equal colours; each pinned
digest must match its pinned description) and rewritten only with `CHRONO_CONSTELLATOR_WRITE_GOLDEN=1`. In the iOS
experience tests: the 16 golden frames rendered and checked against their descriptions, and 12 open-draw-warn-close
memory cycles measured with `ProcessMemory.footprint()` while the sky scene reports zero live GPU objects after each
close and warning (the footprint bound applied only when the class runs alone). A local script runs every part with one
summary; CI gains a named host step; the Release symbol check forbids `ChronoConstellatorGolden`. Research:
[research.md](research.md). Data: [data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md). Quickstart:
[quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6. **Primary dependencies**: ChronoConstellatorCore (solver, generator, witness, scene
geometry, palette); CryptoKit's SHA-256 for digests (as `ColorfallCanyonsGolden`); VisualCoreRendering's
`ProcessMemory.footprint()` in the experience tests. No new package.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02 --filter ChronoConstellatorRegression`;
simulator `xcodebuild_package.py --only-testing` for the golden-frame and memory classes; script tests (alone).
**Performance**: the solver regression is split into tests of 10 levels (each band of 20 is one catalog test in feature 352); work is counted, not timed.
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
Packages/ExperiencesRound02/ChronoConstellator/Core/ChronoConstellatorGolden.swift                                     new   golden set, descriptions, digests (lead)
Packages/ExperiencesRound02/ChronoConstellator/golden-frames.json                                                      new   16 pinned descriptions and digests
Packages/ExperiencesRound02/ChronoConstellator/CoreTests/ChronoConstellatorRegressionSolverTests.swift                 new   100 levels, 12 alterations (agent A)
Packages/ExperiencesRound02/ChronoConstellator/CoreTests/ChronoConstellatorRegressionGoldenTests.swift                 new   descriptions vs pinned digests (agent B)
Packages/ExperiencesRound02/ChronoConstellator/Experience/ChronoConstellatorSkyScene.swift                          edit  live GPU object count (lead)
Packages/ExperiencesRound02/ChronoConstellator/ExperienceTests/ChronoConstellatorRegressionGoldenFrameTests.swift      new   16 frames rendered (agent C)
Packages/ExperiencesRound02/ChronoConstellator/ExperienceTests/ChronoConstellatorRegressionMemoryTests.swift           new   12 cycles (agent C)
scripts/chrono_constellator_regression.py, scripts/test_scripts.py          new/edit  local command and its test (agent D)
scripts/release_check.py                                                    edit  RELEASE_FORBIDDEN + ChronoConstellatorGolden (lead)
.github/workflows/ci.yml                                                    edit  named host step (lead)
docs/architecture/chrono-constellator.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md   edit (lead)
```

**Migration**: none (no state change). **Rollback**: revert the commits; nothing persists.

## Parallel work

The lead writes `ChronoConstellatorGolden`, the scene count, the release list and the workflow step; agents A and B
write the host tests, agent C the two simulator test files, agent D the script and its test; the lead regenerates
`golden-frames.json`, retests every part and records checks after every agent has reported.
