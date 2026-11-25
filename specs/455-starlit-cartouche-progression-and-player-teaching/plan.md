# Implementation Plan: R02-G16-05 — Starlit Cartouche: progression and player teaching

**Branch**: `455-starlit-cartouche-progression-and-player-teaching` (spec directory only; work on `main`) |
**Date**: 2026-11-24 | **Spec**: [spec.md](spec.md)

## Summary

Give Starlit Cartouche its teaching and progression, following Voxel Origami's R02-G15-05 (feature 445) in the same
package: in the host-tested Core a solver entry point that computes the minimal plan from a given star, beat and set of
drawn strokes (`plan(_:from:)`), the hint plan and its three levels (the stroke, the destination, the exact leg), the
failure explanation (a departure or arrival window, a hazard, the deadline, a stray stroke, or the leg that exhausted
the budget), the tutorial steps (levels 1 … 3), progress with stars, the daily level (× 37) and the practice mode (budget
24); the adapter gains `level.select`, `mode.daily`, `mode.practice`, `mode.campaign` and `tutorial.dismiss` and
snapshot schema 2 with a migration from 1; the presenter shows the tutorial, hints (searched off the main actor), failure
text, stars and modes in the panel. Research: [research.md](research.md). Data: [data-model.md](data-model.md). API:
[contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Audit (2026-11-24)**: `StarlitCartoucheCore` (Core, CoreTests) and `StarlitCartoucheExperience` (Experience,
ExperienceTests) exist in `Packages/ExperiencesRound02/Package.swift` and are linked by `project.yml`; no new target.
The generator sets the tutorial flag on levels 1 … 3; the adapter dismisses the kernel's tutorial stage at opening.
`StarlitCartoucheSolver.plan(_:maxLegs:workBound:)` searches breadth first from the start star at beat 0; the new entry
point takes the star, beat and drawn strokes as parameters, so the hint never builds a derived level. The adapter keeps
the chosen destination and wait outside the play (presentation).
**Language/Version**: Swift 6. **Primary dependencies**: the Starlit Cartouche Core (`StarlitCartoucheSolver`,
`StarlitCartouchePlay`, `StarlitCartoucheLevel`, `StarlitCartoucheChart`, the certified catalog), VisualCoreExperience
(controls, snapshot migrations). No new package, target, GLSL, Objective-C++ or VisualCore API.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02` (round02-host split in three by filter);
simulator package tests on sim-27.2; the app unit tests; regression; script tests alone. Seed 2_455.
**Performance**: a hint search is bounded by the solver's work limit (300,000 legs tried, at most 7 legs); the
certification already ran it from every level's opening (at most 19,792 legs tried); measured by the hint tests; no
wall-clock assertion on CI.
**Constraints**: the core reads no clock (the date comes as an action); practice budget 24 (the kernel's maximum);
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
Packages/ExperiencesRound02/StarlitCartouche/Core/StarlitCartoucheSolver.swift          edit  plan from a given state (agent B)
Packages/ExperiencesRound02/StarlitCartouche/Core/StarlitCartoucheHints.swift           new   plan, hints, failure explanation (agent B)
Packages/ExperiencesRound02/StarlitCartouche/Core/StarlitCartoucheProgress.swift        new   progress, stars, daily, mode, tutorial steps (agent C)
Packages/ExperiencesRound02/StarlitCartouche/Core/StarlitCartoucheExperienceCore.swift  edit  actions, modes, schema 2, migration (lead)
Packages/ExperiencesRound02/StarlitCartouche/Core/StarlitCartoucheScenarios.swift       edit  new controls, regenerated manifest (lead)
Packages/ExperiencesRound02/StarlitCartouche/CoreTests/{StarlitCartoucheHintsTests (B), StarlitCartoucheProgressTests (C)}.swift   new
Packages/ExperiencesRound02/StarlitCartouche/CoreTests/StarlitCartoucheExperienceCoreTests.swift                                edit (lead)
Packages/ExperiencesRound02/StarlitCartouche/Experience/{StarlitCartouchePresenter, StarlitCartoucheControls}.swift              edit (lead)
Packages/ExperiencesRound02/StarlitCartouche/ExperienceTests/StarlitCartoucheTeachingTests.swift                                new (agent D)
docs/architecture/starlit-cartouche.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md   edit (lead)
```

**Dependency graph**: hints and progress (independent) → adapter (schema 2, new controls) → scenarios and manifest →
presenter and panel → teaching tests. **Migration**: snapshot schema 1 → 2 (level 1 and the restored level open,
campaign mode, tutorial at step 1 on tutorial levels); the AppModelTests schema-example rule applies only at the X gate,
so the schema-1 example is registered at R02-G16-09. **Rollback**: revert the commits; schema 2 payloads would then be
refused as newer, the documented behaviour. **CI**: the existing `ci` workflow runs the host tests; no new job.

## Parallel work

Agents B (solver entry point, plan, hints, failure explanation) and C (progress, stars, daily, mode, tutorial) work in
parallel; the lead edits the adapter and scenarios against their contracts, then the presenter and panel; agent D
writes the simulator tests with the presenter's exact texts in its brief; the lead runs every check and records only
after every agent has reported.
