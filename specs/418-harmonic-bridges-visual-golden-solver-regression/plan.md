# Implementation Plan: R02-G12-08 — Harmonic Bridges: visual golden and solver regression

**Branch**: `418-harmonic-bridges-visual-golden-solver-regression` (spec directory only; work on `main`) | **Date**:
2026-11-23 | **Spec**: [spec.md](spec.md)

## Summary

Add a regression net around Harmonic Bridges without changing its rules, following feature 408. In the host-tested
`HarmonicBridgesCore`: a solver regression over the 100 certified levels (witness replay with per-action fingerprints and
per-step bridge digests, exact re-plan to the witness's tunings and smaller-choices count with `work` at most `workBound`,
eleven kinds of alteration detected and named) and `HarmonicBridgesGolden` (DEBUG or VISUALCORE_AUTOMATION only), which computes the
code-only description of 16 golden frames (5 levels × 3 tiers plus the hero frame) at 1,152 × 768 and its SHA-256
digests; descriptions and digests are pinned in `golden-frames.json` (an equal digest passes, else positions within one
1/8-pixel quantum and equal counts and colours; each pinned digest must match its pinned description) and rewritten only
with `HARMONIC_BRIDGES_WRITE_GOLDEN=1`. In the iOS experience tests: the 16 golden frames rendered and checked against
their descriptions, and 12 open-draw-warn-close memory cycles measured with `ProcessMemory.footprint()` while the bridge
scene reports zero live GPU objects after each close and warning (the footprint bound applied only when the class runs
alone). A local script runs every part with one summary; CI's `round02-host-tests` job gains a named step; the Release
symbol check forbids `HarmonicBridgesGolden`. Research: [research.md](research.md). Data: [data-model.md](data-model.md).
API: [contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6. **Primary dependencies**: HarmonicBridgesCore (solver, generator, witness, play, scene
geometry, palette); CryptoKit's SHA-256 for digests (as `EchoCartographerGolden`); VisualCoreRendering's
`ProcessMemory.footprint()` in the experience tests. No new package.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02 --filter HarmonicBridgesRegression`; simulator
`xcodebuild_package.py --only-testing` for the golden-frame and memory classes; script tests (alone).
**Performance**: the solver regression is split into tests of 10 levels; work is counted (choices tried), not timed.
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
Packages/ExperiencesRound02/HarmonicBridges/Core/HarmonicBridgesGolden.swift                       new   golden set (lead)
Packages/ExperiencesRound02/HarmonicBridges/golden-frames.json                                     new   16 pinned frames
Packages/ExperiencesRound02/HarmonicBridges/CoreTests/HarmonicBridgesRegressionSolverTests.swift   new   100 levels (A)
Packages/ExperiencesRound02/HarmonicBridges/CoreTests/HarmonicBridgesRegressionGoldenTests.swift   new   digests (B)
Packages/ExperiencesRound02/HarmonicBridges/ExperienceTests/HarmonicBridgesRegressionGoldenFrameTests.swift  new  (C)
Packages/ExperiencesRound02/HarmonicBridges/ExperienceTests/HarmonicBridgesRegressionMemoryTests.swift       new  (C)
scripts/harmonic_bridges_regression.py, scripts/test_scripts.py                    new/edit  local command, test (D)
scripts/release_check.py                                                           edit  RELEASE_FORBIDDEN (lead)
.github/workflows/ci.yml                                                           edit  named step (lead)
docs/architecture/harmonic-bridges.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md  edit (lead)
```

**Migration**: none (no state change). **Rollback**: revert the commits; nothing persists.

## Parallel work

The lead writes `HarmonicBridgesGolden`, the release list and the workflow step; agents A and B write the host tests,
agent C the two simulator test files, agent D the script and its test; the lead regenerates `golden-frames.json`,
retests every part and records checks after every agent has reported.
