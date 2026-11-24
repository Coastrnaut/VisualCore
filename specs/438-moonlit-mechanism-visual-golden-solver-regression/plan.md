# Implementation Plan: R02-G14-08 — Moonlit Mechanism: visual golden and solver regression

**Branch**: `438-moonlit-mechanism-visual-golden-solver-regression` (spec directory only; work on `main`) | **Date**:
2026-11-24 | **Spec**: [spec.md](spec.md)

## Summary

Add Moonlit Mechanism's regression net on Acoustic Constellator's feature-428 pattern: a host solver regression over
all 100 levels (exact witness replay with per-action fingerprints and digests, exact re-plan to the witness's turns,
lamp steps and re-seats and smaller-vectors count with `work` at most `workBound`, thirteen named alterations); a
code-only golden set of 16 frame descriptions (`MoonlitMechanismGolden`, DEBUG or VISUALCORE_AUTOMATION only, pinned in
`golden-frames.json` with SHA-256 digests, 1/8-pixel quantum fallback and a self-check); simulator tests that render the
16 frames against their descriptions and bound memory over 12 open–draw–warn–close cycles; a named CI step and a local
command. The release check's forbidden-symbol list gains `MoonlitMechanismGolden`. Research: [research.md](research.md).
Data: [data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Audit (2026-11-24)**: `MoonlitMechanismSolver.plan` returns `turns`, `lamp`, `reseats`, `smallerVectors` and `work`
(`workBound` 400,000); `MoonlitMechanismWitness` decodes the 100 witness files (level, actions, fingerprints, digests,
counterexample `norm` and `vectors`); `MoonlitMechanismSceneGeometry` has `camera(_:aspect:)`, `project`, `cellCentre`,
`gearCentre`, `gearRimCheckPoint`, `card`, `alignmentPip`, `lampCentre`, `movesBar` and the palette; the scene's
`release()` and `liveObjectCount` exist (feature 433); CI's `round02-host-tests` job has per-game regression steps.
**Language/Version**: Swift 6 and Python 3. **Primary dependencies**: the Moonlit Mechanism Core, `StableHash.sha256Hex` of
VisualCoreMath (no CryptoKit, as feature 428), VisualCoreDiagnostics (`ProcessMemory.footprint()`). No new package or target.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02`; simulator package tests on sim-27.2; app unit
tests; regression; script tests alone. Seed 2_438.
**Constraints**: no wall-clock assertion; each test under 10 s (the 100-level checks split into groups of 10); the golden
manifest is rewritten only with `MOONLIT_MECHANISM_WRITE_GOLDEN=1`; the memory bound applies only when the memory class
runs alone.

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
Packages/ExperiencesRound02/MoonlitMechanism/Core/MoonlitMechanismGolden.swift                       new   golden set (lead)
Packages/ExperiencesRound02/MoonlitMechanism/golden-frames.json                                     new   16 pinned frames
Packages/ExperiencesRound02/MoonlitMechanism/CoreTests/MoonlitMechanismRegressionSolverTests.swift   new   100 levels (A)
Packages/ExperiencesRound02/MoonlitMechanism/CoreTests/MoonlitMechanismRegressionGoldenTests.swift   new   digests (B)
Packages/ExperiencesRound02/MoonlitMechanism/ExperienceTests/MoonlitMechanismRegressionGoldenFrameTests.swift  new  (C)
Packages/ExperiencesRound02/MoonlitMechanism/ExperienceTests/MoonlitMechanismRegressionMemoryTests.swift       new  (C)
scripts/moonlit_mechanism_regression.py, scripts/test_scripts.py                    new/edit  local command, test (D)
scripts/release_check.py                                                             edit  RELEASE_FORBIDDEN (lead)
.github/workflows/ci.yml                                                             edit  named step (lead)
docs/architecture/moonlit-mechanism.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md  edit (lead)
```

**Migration**: none (no state change). **Rollback**: revert the commits; nothing persists.

## Parallel work

The lead writes `MoonlitMechanismGolden` and pins the manifest; agents A (solver regression), B (golden digests), C
(simulator golden frames and memory) and D (local command and its script test) write their new files in parallel; the
lead edits the shared release check, CI workflow and docs, and retests every result.
