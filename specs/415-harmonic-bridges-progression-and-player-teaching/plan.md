# Implementation Plan: R02-G12-05 — Harmonic Bridges: progression and player teaching

**Branch**: `415-harmonic-bridges-progression-and-player-teaching` (spec directory only; work on `main`) | **Date**:
2026-11-23 | **Spec**: [spec.md](spec.md)

## Summary

Give Harmonic Bridges its teaching and progression, following Echo Cartographer's R02-G11-05 (feature 405) in the same
package: in the host-tested Core a solver entry point that computes the minimal plan from the current pegs (the level
with every string at its current peg, locks kept), the hint plan and its three levels (kind, string, peg), the failure
explanation (a broken test's step and string, or the move that exhausted the budget, with the steps that held), the
tutorial steps (levels 1 … 3), progress with stars, the daily level (× 83) and the practice mode (budget 60); the
adapter gains `level.select`, `mode.daily`, `mode.practice`, `mode.campaign` and `tutorial.dismiss` and snapshot schema 2
with a migration from 1; the presenter shows the tutorial, hints (searched off the main actor), failure text, stars and
modes in the panel. Research: [research.md](research.md). Data: [data-model.md](data-model.md). API:
[contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Audit (2026-11-23)**: `HarmonicBridgesCore` (Core, CoreTests) and `HarmonicBridgesExperience` (Experience,
ExperienceTests) exist in `Packages/ExperiencesRound02/Package.swift` and are linked by `project.yml`; no new target.
The generator sets the tutorial flag on levels 1 … 3; the adapter dismisses the kernel's tutorial stage at opening.
**Language/Version**: Swift 6. **Primary dependencies**: the Harmonic Bridges Core (`HarmonicBridgesSolver`,
`HarmonicBridgesPlay`, `HarmonicBridgesLevel`, `HarmonicBridgesResonance`, the certified catalog), VisualCoreExperience
(controls, snapshot migrations). No new package, target, GLSL, Objective-C++ or VisualCore API.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02`; simulator package tests on sim-27.2; the app
unit tests; regression; script tests alone. Seed 2_415.
**Performance**: a hint search is bounded by the solver's work limit (400,000 choices, at most 6 retuned strings); the
certification already ran it from every level's opening; measured by the hint tests; no wall-clock assertion on CI.
**Constraints**: the core reads no clock (the date comes as an action); practice budget 60 (the kernel's maximum);
practice plays a copy of the level with that budget; hints read only; tests under 10 s.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| II App-neutral API | PASS — game code stays in ExperiencesRound02; VisualCore unchanged. |
| IV Host-testable | PASS — hints, failure text, progress and modes in the Core with host tests. |
| V Implementation before devices | PASS — no device work. |
| VII Determinism | PASS — no clock in the core; daily level from the date action; bounded search. |
| IX Bounded input | PASS — level numbers, dates and modes validated; schema migration refuses newer payloads. |
| XII One purchase, no advertising | PASS — every level free; no paywall. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/HarmonicBridges/Core/HarmonicBridgesSolver.swift                 edit  plan from given pegs (agent B)
Packages/ExperiencesRound02/HarmonicBridges/Core/HarmonicBridgesHints.swift                  new   plan, hints, failure explanation (agent B)
Packages/ExperiencesRound02/HarmonicBridges/Core/HarmonicBridgesProgress.swift               new   progress, stars, daily, mode, tutorial steps (agent C)
Packages/ExperiencesRound02/HarmonicBridges/Core/HarmonicBridgesExperienceCore.swift         edit  actions, modes, schema 2, migration (lead)
Packages/ExperiencesRound02/HarmonicBridges/Core/HarmonicBridgesScenarios.swift              edit  new controls, regenerated manifest (lead)
Packages/ExperiencesRound02/HarmonicBridges/CoreTests/{HarmonicBridgesHintsTests (B), HarmonicBridgesProgressTests (C)}.swift   new
Packages/ExperiencesRound02/HarmonicBridges/CoreTests/HarmonicBridgesExperienceCoreTests.swift                                 edit (lead)
Packages/ExperiencesRound02/HarmonicBridges/Experience/{HarmonicBridgesPresenter, HarmonicBridgesControls}.swift                 edit (lead)
Packages/ExperiencesRound02/HarmonicBridges/ExperienceTests/HarmonicBridgesTeachingTests.swift                                 new (agent D)
docs/architecture/harmonic-bridges.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md   edit (lead)
```

**Dependency graph**: hints and progress (independent) → adapter (schema 2, new controls) → scenarios and manifest →
presenter and panel → teaching tests. **Migration**: snapshot schema 1 → 2 (level 1 and the restored level open,
campaign mode, tutorial at step 1 on tutorial levels); the AppModelTests schema-example rule applies only at the X gate,
so the schema-1 example is registered at R02-G12-09. **Rollback**: revert the commits; schema 2 payloads would then be
refused as newer, the documented behaviour. **CI**: the existing `ci` workflow runs the host tests; no new job.

## Parallel work

Agents B (solver entry point, plan, hints, failure explanation) and C (progress, stars, daily, mode, tutorial) work in
parallel; the lead edits the adapter and scenarios against their contracts, then the presenter and panel; agent D
writes the simulator tests; the lead runs every check and records only after every agent has reported.
