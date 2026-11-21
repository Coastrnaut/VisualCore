# Implementation Plan: R02-G04-05 — Hue Compass: progression and player teaching

**Branch**: `335-hue-compass-progression-and-player-teaching` (spec directory only; work on `main`) | **Date**: 2026-11-21
| **Spec**: [spec.md](spec.md)

## Summary

Teach and pace Hue Compass on Wave Knot Keeper's feature-325 pattern: `HueCompassHints` (the consistent set from the
clues seen; a selection when it settles, else a settling or best-splitting probe, else a best guess on the last unit)
with `HueCompassFailureExplanation`; `HueCompassProgress` (best units and stars, open frontier, daily level × 47),
`HueCompassMode` and `HueCompassTutorialStep`; the adapter gains `level.select`, `mode.daily`, `mode.practice`,
`mode.campaign`, `tutorial.dismiss` and `tutorial.hint`, codes `r02-g04.locked` and `r02-g04.date`, and snapshot schema 2
with a migration from 1; the presenter shows the tutorial, hints and failure text and the panel gains Hint and mode
controls. Research: [research.md](research.md). Data: [data-model.md](data-model.md). API:
[contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6. **Primary dependencies**: the Hue Compass Core (`HueCompassSolver`, `HueCompassPlay`,
`HueCompassLevel`, the generator's certified catalog), VisualCoreExperience (controls, snapshot migrations). No new
package, target or VisualCore API.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02`; simulator package tests on sim-27.2; the app
unit tests; regression; script tests alone. Seed 2_335.
**Constraints**: the core reads no clock (the date comes as an action); practice allowance 24 (the kernel's maximum);
hints read only; tests under 10 s.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| II App-neutral API | PASS — game code stays in ExperiencesRound02. |
| IV Host-testable | PASS — hints, progress and modes in the Core with host tests. |
| V Implementation before devices | PASS — no device work. |
| IX Bounded input | PASS — level numbers, dates and modes validated; schema migration refuses newer payloads. |
| XII One purchase, no advertising | PASS — every level free; no paywall. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/HueCompass/Core/HueCompassHints.swift            new   hints, failure explanation (agent B)
Packages/ExperiencesRound02/HueCompass/Core/HueCompassProgress.swift         new   progress, stars, daily, mode, tutorial steps (agent C)
Packages/ExperiencesRound02/HueCompass/Core/HueCompassExperienceCore.swift   edit  actions, modes, schema 2, migration (lead)
Packages/ExperiencesRound02/HueCompass/Core/HueCompassScenarios.swift        edit  new controls, regenerated manifest (lead)
Packages/ExperiencesRound02/HueCompass/CoreTests/{HueCompassHintsTests (B), HueCompassProgressTests (C)}.swift   new
Packages/ExperiencesRound02/HueCompass/CoreTests/HueCompassExperienceCoreTests.swift                            edit (lead)
Packages/ExperiencesRound02/HueCompass/Experience/{HueCompassPresenter, HueCompassControls}.swift              edit (lead)
Packages/ExperiencesRound02/HueCompass/ExperienceTests/HueCompassTeachingTests.swift                           new (agent D)
docs/architecture/hue-compass.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md                edit (lead)
```

**Migration**: snapshot schema 1 → 2 (progress empty, campaign mode, tutorial at step 1 on tutorial levels).
**Rollback**: revert the commits; schema 2 payloads would then be refused as newer, which is the documented behaviour.

## Parallel work

Agents B (hints, failure explanation) and C (progress, stars, daily, mode, tutorial) work in parallel; the lead edits the
adapter and scenarios against their contracts, then the presenter and panel; agent D writes the simulator tests; the lead
runs every check and records only after every agent has reported.
