# Implementation Plan: R02-G21-05 — Binary Gardens: progression and player teaching

**Branch**: `505-binary-gardens-progression-and-player-teaching` (spec directory only; work on `main`) |
**Date**: 2026-11-27 | **Spec**: [spec.md](spec.md)

## Summary

Give Binary Gardens its teaching and progression, following Mushroom Weather's R02-G20-05 (feature 495) in the same
package: in the host-tested Core a hint rule from the current arrangement (`BinaryGardensHints.plan`: the certified
witness's remaining actions while every control holds its starting or its certified value and the actions left cover
them, otherwise a bounded breadth-first search of at most min(actions left, 2) legal arrangement moves, at most 2,000
arrangements judged) and its three levels (the kind of change, which star and which way, the exact action), the failure
explanation (frozen, scorched, unstable, wilted, bleached), the tutorial steps (levels 1 … 3: adjust, balance, recover),
progress with stars, the daily level (× 13) and the practice mode (budget 24); the adapter gains `level.select`,
`mode.daily`, `mode.practice`, `mode.campaign` and `tutorial.dismiss`, `level.next` stops wrapping, the digest domain
becomes `"r02-g21.binary-gardens.v2"` and the snapshot becomes schema 2 with a migration from 1; the presenter shows the
tutorial, hints (searched off the main actor with a generation counter), failure text, stars and modes in the panel.
Research: [research.md](research.md). Data: [data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md).
Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Audit (2026-11-27)**: after R02-G21-03 (recorded) and the R02-G21-04 additions, `BinaryGardensCore` (Core, Content,
CoreTests) and `BinaryGardensExperience` (Experience, ExperienceTests) exist in `Packages/ExperiencesRound02/Package.swift`
and are linked by `project.yml`; no new target. The generator sets the tutorial flag on levels 1 … 3; the adapter
dismisses the kernel's tutorial stage at opening and `BinaryGardensExperienceCore.generated(number:)` gives each level's
certified `BinaryGardensGenerated` (its `plan.arrangement` and `plan.actions`), so the hint and the stars read the
certified plan without re-solving. A report depends only on the arrangement (`BinaryGardensSky.report`), so the hint
search judges arrangements exactly; `BinaryGardensPuzzle(level:).moves(in:)` gives the legal moves in the fixed control
order. The adapter keeps the shown tick, the preview, the orbit and the inspected world outside the play (presentation).
The presenter's tutorial sentence and failure words are replaced by the Core's step text and explanation.
**Language/Version**: Swift 6. **Primary dependencies**: the Binary Gardens Core (`BinaryGardensSky`,
`BinaryGardensPlay`, `BinaryGardensLevel`, `BinaryGardensPuzzle`, the certified catalog), VisualCoreExperience
(controls, snapshot migrations). No new package, target, GLSL, Objective-C++ or VisualCore API.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02 --filter BinaryGardens`; simulator package
tests on sim-27.2; the app unit tests; regression; script tests alone. Seed 2_505.
**Performance**: a hint search judges at most 2,000 arrangements (a catalog level's two-action space is at most 650;
one report over 48 + E ticks for two worlds is microseconds in release; the search is off the main actor); following
exact hints from a level's start replays the certified witness with no search; no wall-clock assertion on CI.
**Constraints**: the core reads no clock (the date comes as an action); practice budget 24 (the kernel's maximum) on a
copy of the level; hints read only; tests under 10 s.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| II App-neutral API | PASS — game code stays in ExperiencesRound02; VisualCore unchanged. |
| IV Host-testable | PASS — hints, failure text, tutorial, progress and modes in the Core with host tests. |
| V Implementation before devices | PASS — no device work. |
| VII Determinism | PASS — no clock in the core; daily level from the date action; bounded search in a fixed order. |
| IX Bounded input | PASS — level numbers, dates and modes validated; schema migration refuses damaged and newer payloads. |
| XII One purchase, no advertising | PASS — every level free (R02-G21 is a free experience); locked means not yet won. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensHints.swift            new   hint rule and search, hints, failure explanation (agent B)
Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensProgress.swift         new   progress, stars, daily, mode, tutorial steps (agent C)
Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensExperienceCore.swift   edit  actions, modes, digest v2, schema 2, migration (lead)
Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensScenarios.swift        edit  new controls, level.next without wrap, regenerated manifest (lead)
Packages/ExperiencesRound02/BinaryGardens/CoreTests/{BinaryGardensHintsTests (B), BinaryGardensProgressTests (C)}.swift    new
Packages/ExperiencesRound02/BinaryGardens/CoreTests/BinaryGardensProgressionCoreTests.swift                               new (lead)
Packages/ExperiencesRound02/BinaryGardens/CoreTests/{BinaryGardensExperienceCoreTests, BinaryGardensScenariosTests}.swift  edit (lead: control list, schema 2, digest v2, no wrap)
Packages/ExperiencesRound02/BinaryGardens/Experience/{BinaryGardensPresenter, BinaryGardensControls}.swift                 edit (lead)
Packages/ExperiencesRound02/BinaryGardens/ExperienceTests/BinaryGardensTeachingTests.swift                                 new (agent D)
docs/architecture/binary-gardens.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md   edit (lead)
```

The two new Core files sit in `Core/` beside the kernel; the invariant test's fixed 10-file list (feature 501) names
only the kernel files and is unchanged.

**Dependency graph**: hints and progress (independent) → adapter (digest v2, schema 2, new controls) → scenarios and
manifest → presenter and panel → teaching tests. **Migration**: snapshot schema 1 → 2 (levels 1 … the restored level
open, no won levels, campaign mode, tutorial at `adjust` on levels 1 … 3, else `done`); the schema-example rule applies
only at the X gate. **Rollback**: revert the commits; schema 2 payloads would then be refused as newer, the documented
behaviour. **CI**: the existing `ci` workflow's round02 half b filter already includes `BinaryGardens`; no new job.

## Parallel work

Agents B (hint rule and search, hints, failure explanation) and C (progress, stars, daily, mode, tutorial) draft in
parallel in isolated copies; the lead edits the adapter and scenarios against their contracts, then the presenter and
panel; agent D writes the simulator tests with the presenter's exact texts in its brief; the lead runs every check and
records only after every agent has reported and every draft is retested in the repository.
