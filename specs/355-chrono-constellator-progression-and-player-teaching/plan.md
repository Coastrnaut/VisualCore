# Implementation Plan: R02-G06-05 — Chrono Constellator: progression and player teaching

**Branch**: `355-chrono-constellator-progression-and-player-teaching` (spec directory only; work on `main`) | **Date**:
2026-11-21 | **Spec**: [spec.md](spec.md)

## Summary

Teach and pace Chrono Constellator on Colorfall Canyons's feature-345 pattern: `ChronoConstellatorHints` (the plan from
the current state: run, rewind, remove a hold, or the solver's phase changes from the current phases within the budget)
with `ChronoConstellatorFailureExplanation` (the colliding stars, cell and tick, or the stars off target at the tick
limit); `ChronoConstellatorProgress` (best edits and stars, open frontier, daily level × 59),
`ChronoConstellatorMode` and `ChronoConstellatorTutorialStep`; the adapter gains `level.select`, `mode.daily`,
`mode.practice`, `mode.campaign` and `tutorial.dismiss`, codes `r02-g06.locked` and `r02-g06.date`, and snapshot
schema 2 with a migration from 1; the presenter shows the tutorial, hints and failure text and the panel gains Hint and
mode controls. Research: [research.md](research.md). Data: [data-model.md](data-model.md). API:
[contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Audit (2026-11-21)**: `ChronoConstellatorCore` (Core, CoreTests) and `ChronoConstellatorExperience` (Experience,
ExperienceTests) exist in `Packages/ExperiencesRound02/Package.swift` and are linked by `project.yml`; no new target.
**Language/Version**: Swift 6. **Primary dependencies**: the Chrono Constellator Core (`ChronoConstellatorSolver`,
`ChronoConstellatorGenerator.winTick`, `ChronoConstellatorPlay`, `ChronoConstellatorTimeline`,
`ChronoConstellatorLevel`, the certified catalog), VisualCoreExperience (controls, snapshot migrations). No new
package, target, GLSL, Objective-C++ or VisualCore API.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02`; simulator package tests on sim-27.2; the app
unit tests; regression; script tests alone. Seed 2_355.
**Performance**: a hint from any reachable state of a certified level within 0.5 s on the debug host build (measured by
the hint tests; no wall-clock assertion on CI).
**Constraints**: the core reads no clock (the date comes as an action); practice budget 20 (the kernel's maximum); hints
read only; tests under 10 s.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| II App-neutral API | PASS — game code stays in ExperiencesRound02; VisualCore unchanged. |
| IV Host-testable | PASS — hints, failure text, progress and modes in the Core with host tests. |
| V Implementation before devices | PASS — no device work. |
| VII Determinism | PASS — no clock in the core; daily level from the date action. |
| IX Bounded input | PASS — level numbers, dates and modes validated; schema migration refuses newer payloads. |
| XII One purchase, no advertising | PASS — every level free; no paywall. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/ChronoConstellator/Core/ChronoConstellatorHints.swift                 new   plan, hints, failure explanation (agent B)
Packages/ExperiencesRound02/ChronoConstellator/Core/ChronoConstellatorProgress.swift              new   progress, stars, daily, mode, tutorial steps (agent C)
Packages/ExperiencesRound02/ChronoConstellator/Core/ChronoConstellatorExperienceCore.swift        edit  actions, modes, schema 2, migration (lead)
Packages/ExperiencesRound02/ChronoConstellator/Core/ChronoConstellatorScenarios.swift             edit  new controls, regenerated manifest (lead)
Packages/ExperiencesRound02/ChronoConstellator/CoreTests/{ChronoConstellatorHintsTests (B), ChronoConstellatorProgressTests (C)}.swift   new
Packages/ExperiencesRound02/ChronoConstellator/CoreTests/ChronoConstellatorExperienceCoreTests.swift                                     edit (lead)
Packages/ExperiencesRound02/ChronoConstellator/Experience/{ChronoConstellatorPresenter, ChronoConstellatorControls}.swift               edit (lead)
Packages/ExperiencesRound02/ChronoConstellator/ExperienceTests/ChronoConstellatorTeachingTests.swift                                    new (agent D)
docs/architecture/chrono-constellator.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md   edit (lead)
```

**Dependency graph**: hints and progress (independent) → adapter (schema 2, new controls) → scenarios and manifest →
presenter and panel → teaching tests. **Migration**: snapshot schema 1 → 2 (level 1 and the restored level open,
campaign mode, tutorial at step 1 on tutorial levels); the AppModelTests schema-example rule applies only at the X gate,
so the schema-1 example is registered at R02-G06-09 (as Colorfall did). **Rollback**: revert the commits; schema 2
payloads would then be refused as newer, the documented behaviour. **CI**: the existing `ci` workflow runs the host
tests; no new job.

## Parallel work

Agents B (plan, hints, failure explanation) and C (progress, stars, daily, mode, tutorial) work in parallel in isolated
copies; the lead edits the adapter and scenarios against their contracts, then the presenter and panel; agent D writes
the simulator tests; the lead runs every check and records only after every agent has reported.
