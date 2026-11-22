# Implementation Plan: R02-G08-08 — Faceted Forge: visual golden and solver regression

**Branch**: `378-faceted-forge-visual-golden-solver-regression` (spec directory only; work on `main`) | **Date**:
2026-11-22 | **Spec**: [spec.md](spec.md)

## Summary

Add a regression net around Faceted Forge without changing its rules, following feature 368. In the host-tested
`FacetedForgeCore`: a solver regression over the 100 certified levels (witness replay with per-cut digests and
fingerprints, exact re-solve to the witness's cuts and smallest cut count, equal to the lower bound, with `work` at most
`workBound`, ten kinds of alteration detected and named) and `FacetedForgeGolden` (DEBUG or VISUALCORE_AUTOMATION only),
which computes the code-only description of 16 golden frames (5 levels × 3 tiers plus the hero frame) at 1,152 × 768 and
its SHA-256 digests; descriptions and digests are pinned in `golden-frames.json` (an equal digest passes, else positions
within one 1/8-pixel quantum and equal colours; each pinned digest must match its pinned description) and rewritten only
with `FACETED_FORGE_WRITE_GOLDEN=1`. In the iOS experience tests: the 16 golden frames rendered and checked against
their descriptions, and 12 open-draw-warn-close memory cycles measured with `ProcessMemory.footprint()` while the crystal
scene reports zero live GPU objects after each close and warning (the footprint bound applied only when the class runs
alone). A local script runs every part with one summary; CI gains a named host step; the Release symbol check forbids
`FacetedForgeGolden`. Research: [research.md](research.md). Data: [data-model.md](data-model.md). API:
[contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6. **Primary dependencies**: FacetedForgeCore (solver, generator, witness, play, scene
geometry, palette); CryptoKit's SHA-256 for digests (as `AmethystEscapeGolden`); VisualCoreRendering's
`ProcessMemory.footprint()` in the experience tests. No new package.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02 --filter FacetedForgeRegression`; simulator
`xcodebuild_package.py --only-testing` for the golden-frame and memory classes; script tests (alone).
**Performance**: the solver regression is split into tests of 10 levels (the catalog tests of feature 372 never
re-solve the whole catalog); work is counted, not timed.
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
Packages/ExperiencesRound02/FacetedForge/Core/FacetedForgeGolden.swift                       new   golden set (lead)
Packages/ExperiencesRound02/FacetedForge/golden-frames.json                                    new   16 pinned frames
Packages/ExperiencesRound02/FacetedForge/CoreTests/FacetedForgeRegressionSolverTests.swift   new   100 levels (A)
Packages/ExperiencesRound02/FacetedForge/CoreTests/FacetedForgeRegressionGoldenTests.swift   new   digests (B)
Packages/ExperiencesRound02/FacetedForge/Experience/FacetedForgeCrystalScene.swift           edit  live count (lead)
Packages/ExperiencesRound02/FacetedForge/ExperienceTests/FacetedForgeRegressionGoldenFrameTests.swift  new  (C)
Packages/ExperiencesRound02/FacetedForge/ExperienceTests/FacetedForgeRegressionMemoryTests.swift       new  (C)
scripts/faceted_forge_regression.py, scripts/test_scripts.py                   new/edit  local command, test (D)
scripts/release_check.py                                                         edit  RELEASE_FORBIDDEN (lead)
.github/workflows/ci.yml                                                         edit  named host step (lead)
docs/architecture/faceted-forge.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md  edit (lead)
```

**Migration**: none (no state change). **Rollback**: revert the commits; nothing persists.

## Parallel work

The lead writes `FacetedForgeGolden`, the scene count, the release list and the workflow step; agents A and B write
the host tests, agent C the two simulator test files, agent D the script and its test; the lead regenerates
`golden-frames.json`, retests every part and records checks after every agent has reported.
