# Implementation Plan: R02-G20-05 — Mushroom Weather: progression and player teaching

**Branch**: `495-mushroom-weather-progression-and-player-teaching` (spec directory only; work on `main`) |
**Date**: 2026-11-26 | **Spec**: [spec.md](spec.md)

## Summary

Give Mushroom Weather its teaching and progression, following Microscopic Aurora's R02-G19-05 (feature 485) in the same
package: in the host-tested Core a hint rule from the current arrangement (`MushroomWeatherHints.plan`: the certified
witness's next remaining action while the arrangement lies on the way to the witness's and the actions left cover the
rest, otherwise a bounded search of at most min(actions left, 2) pod, vent or moonlight actions, at most 1,500
arrangements judged) and its three levels (the kind of change, where, the exact action), the failure explanation
(dried, mold, unstable), the tutorial steps (levels 1 … 3), progress with stars, the daily level (× 17) and the practice
mode (budget 24); the adapter gains `level.select`, `mode.daily`, `mode.practice`, `mode.campaign` and
`tutorial.dismiss` and snapshot schema 2 with a migration from 1; the presenter shows the tutorial, hints (searched off
the main actor), failure text, stars and modes in the panel. Research: [research.md](research.md). Data:
[data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Audit (2026-11-26)**: after R02-G20-03 and 04, `MushroomWeatherCore` (Core, CoreTests) and
`MushroomWeatherExperience` (Experience, ExperienceTests) exist in `Packages/ExperiencesRound02/Package.swift` and are
linked by `project.yml`; no new target. The generator sets the tutorial flag on levels 1 … 3; the adapter dismisses the
kernel's tutorial stage at opening and keeps each prepared level's certified `MushroomWeatherGenerated` (its
`plan.arrangement` and `plan.actions`), so the hint and the stars read the certified plan without re-solving.
`MushroomWeatherSolver.plan` searches only from a level without pods; the hint search is a new bounded search from any
arrangement (a report depends only on the arrangement). The adapter keeps the shown cycle outside the play and the
presenter keeps a drag's preview and the orbit (presentation). The presenter's failure words are replaced by the Core's
explanation with the clarified wording.
**Language/Version**: Swift 6. **Primary dependencies**: the Mushroom Weather Core (`MushroomWeatherForest`,
`MushroomWeatherPlay`, `MushroomWeatherLevel`, the certified catalog), VisualCoreExperience (controls, snapshot
migrations). No new package, target, GLSL, Objective-C++ or VisualCore API.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02` (round02-host split by filter); simulator
package tests on sim-27.2; the app unit tests; regression; script tests alone. Seed 2_495.
**Performance**: a hint search judges at most 1,500 arrangements (a catalog run of at most 40 cycles over at most 90
cells is well under a millisecond in release; the search is off the main actor); following exact hints from a level's
start replays the certified plan with no search; no wall-clock assertion on CI.
**Constraints**: the core reads no clock (the date comes as an action); practice budget 24 (the kernel's maximum);
practice plays a copy of the level with that budget; hints read only; tests under 10 s.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| II App-neutral API | PASS — game code stays in ExperiencesRound02; VisualCore unchanged. |
| IV Host-testable | PASS — hints, failure text, progress and modes in the Core with host tests. |
| V Implementation before devices | PASS — no device work. |
| VII Determinism | PASS — no clock in the core; daily level from the date action; bounded search in a fixed order. |
| IX Bounded input | PASS — level numbers, dates and modes validated; schema migration refuses newer payloads. |
| XII One purchase, no advertising | PASS — every level free; no paywall. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/MushroomWeather/Core/MushroomWeatherHints.swift           new   hint rule and search, hints, failure explanation (agent B)
Packages/ExperiencesRound02/MushroomWeather/Core/MushroomWeatherProgress.swift        new   progress, stars, daily, mode, tutorial steps (agent C)
Packages/ExperiencesRound02/MushroomWeather/Core/MushroomWeatherExperienceCore.swift  edit  actions, modes, schema 2, migration (lead)
Packages/ExperiencesRound02/MushroomWeather/Core/MushroomWeatherScenarios.swift       edit  new controls, regenerated manifest (lead)
Packages/ExperiencesRound02/MushroomWeather/CoreTests/{MushroomWeatherHintsTests (B), MushroomWeatherProgressTests (C)}.swift   new
Packages/ExperiencesRound02/MushroomWeather/CoreTests/MushroomWeatherProgressionCoreTests.swift                              new (lead)
Packages/ExperiencesRound02/MushroomWeather/Experience/{MushroomWeatherPresenter, MushroomWeatherControls}.swift              edit (lead)
Packages/ExperiencesRound02/MushroomWeather/ExperienceTests/MushroomWeatherTeachingTests.swift                                  new (agent D)
docs/architecture/mushroom-weather.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md   edit (lead)
```

**Dependency graph**: hints and progress (independent) → adapter (schema 2, new controls) → scenarios and manifest →
presenter and panel → teaching tests. **Migration**: snapshot schema 1 → 2 (level 1 and the restored level open,
campaign mode, tutorial at step 1 on tutorial levels); the schema-example rule applies only at the X gate.
**Rollback**: revert the commits; schema 2 payloads would then be refused as newer, the documented behaviour. **CI**:
the existing `ci` workflow runs the host tests; no new job.

## Parallel work

Agents B (hint rule and search, hints, failure explanation) and C (progress, stars, daily, mode, tutorial) work in
parallel; the lead edits the adapter and scenarios against their contracts, then the presenter and panel; agent D
writes the simulator tests with the presenter's exact texts in its brief; the lead runs every check and records only
after every agent has reported.
