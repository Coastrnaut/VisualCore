# Implementation Plan: R02-G22-05 — Mycelium Architect: progression and player teaching

**Branch**: `515-mycelium-architect-progression-and-player-teaching` (spec directory only; work on `main`) |
**Date**: 2026-11-27 | **Spec**: [spec.md](spec.md)

## Summary

Give Mycelium Architect its teaching and progression, following Binary Gardens' R02-G21-05 (feature 505) in the same
package: in the host-tested Core a hint rule from the current arrangement (`MyceliumArchitectHints.plan`: the certified
witness's remaining actions while the arrangement lies on the way from the start to the certified arrangement and the
actions left cover them, otherwise a bounded breadth-first search of at most min(actions left, 2) legal arrangement
moves, at most 2,000 arrangements judged) and its three levels (the kind of change, where, the exact action), the
failure explanation (toxic, starved, unreached, overweight), the tutorial steps (levels 1 … 3: place, grow, recover),
progress with stars, the daily level (× 11) and the practice mode (budget 24); the adapter gains `level.select`,
`mode.daily`, `mode.practice`, `mode.campaign` and `tutorial.dismiss`, `level.next` stops wrapping, the digest domain
becomes `"r02-g22.mycelium-architect.v2"` and the snapshot becomes schema 2 with a migration from 1; the presenter shows
the tutorial, hints (searched off the main actor with a generation counter), failure text, stars and modes in the panel.
Research: [research.md](research.md). Data: [data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md).
Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Audit (2026-11-27)**: after R02-G22-04 (recorded), `MyceliumArchitectCore` (Core, Core/Content, Core/Presentation,
CoreTests) and `MyceliumArchitectExperience` (Experience, ExperienceTests) exist in
`Packages/ExperiencesRound02/Package.swift` and are linked by `project.yml`; no new target. The generator sets the
tutorial flag on levels 1 … 3; the adapter dismisses the kernel's tutorial stage at opening and
`MyceliumArchitectExperienceCore.generated(number:)` gives each level's certified `MyceliumArchitectGeneratedLevel`
(its `solution.actions`: the minimal plan, then `run`), so the hint and the stars read the certified plan without
re-solving. A report depends only on the arrangement (`MyceliumArchitectGrowth.report`), so the hint search judges
arrangements exactly; `MyceliumArchitectPuzzle(level:).moves(in:)` gives the legal moves in the fixed order. The adapter
keeps the shown pulse, the tool, the preview, the orbit and the inspected cell outside the play (presentation). The
presenter's tutorial sentence and failure words are replaced by the Core's step text and explanation. The kernel
invariant test scans every `.swift` file directly in `Core/` for clock and random tokens (at least 4 files), so the two
new Core files are scanned too, which they pass by design.
**Language/Version**: Swift 6. **Primary dependencies**: the Mycelium Architect Core (`MyceliumArchitectGrowth`,
`MyceliumArchitectPlay`, `MyceliumArchitectLevel`, `MyceliumArchitectPuzzle`, the certified catalog), VisualCoreExperience
(controls, snapshot migrations). No new package, target, GLSL, Objective-C++ or VisualCore API.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02 --filter MyceliumArchitect`; simulator package
tests on sim-27.2; the app unit tests; regression; script tests alone. Seed 2_515.
**Performance**: a hint search judges at most 2,000 arrangements (a catalog level's two-action space is at most
34 + 34 × 34 = 1,190; one growth report on a board of at most 16 × 16 over at most 112 pulses; the search is off the
main actor); following exact hints from a level's start replays the certified witness with no search; no wall-clock
assertion on CI.
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
| XII One purchase, no advertising | PASS — every level free (R02-G22 is a free experience); locked means not yet won. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/MyceliumArchitect/Core/MyceliumArchitectHints.swift                       new   hint rule and search, hints, failure explanation (agent B)
Packages/ExperiencesRound02/MyceliumArchitect/Core/MyceliumArchitectProgress.swift                    new   progress, stars, daily, mode, tutorial steps (agent C)
Packages/ExperiencesRound02/MyceliumArchitect/Core/Presentation/MyceliumArchitectExperienceCore.swift edit  actions, modes, digest v2, schema 2, migration (lead)
Packages/ExperiencesRound02/MyceliumArchitect/Core/Presentation/MyceliumArchitectScenarios.swift      edit  new controls, level.next without wrap, regenerated manifest (lead)
Packages/ExperiencesRound02/MyceliumArchitect/CoreTests/{MyceliumArchitectHintsTests (B), MyceliumArchitectProgressTests (C)}.swift   new
Packages/ExperiencesRound02/MyceliumArchitect/CoreTests/MyceliumArchitectProgressionCoreTests.swift                                     new (lead)
Packages/ExperiencesRound02/MyceliumArchitect/CoreTests/MyceliumArchitectExperienceCoreTests.swift (and any test pinning the control list, schema or wrap)  edit (lead)
Packages/ExperiencesRound02/MyceliumArchitect/Experience/{MyceliumArchitectPresenter, MyceliumArchitectControls}.swift                    edit (lead)
Packages/ExperiencesRound02/MyceliumArchitect/CoreTests/MyceliumArchitectPanelWinTests.swift                                            edit (lead: panel model keeps level.next semantics)
Packages/ExperiencesRound02/MyceliumArchitect/ExperienceTests/MyceliumArchitectTeachingTests.swift                                      new (agent D)
docs/architecture/mycelium-architect.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md   edit (lead)
```

**Dependency graph**: hints and progress (independent) → adapter (digest v2, schema 2, new controls) → scenarios and
manifest → presenter and panel → teaching tests. **Migration**: snapshot schema 1 → 2 (levels 1 … the restored level
open, no won levels, campaign mode, tutorial at `place` on levels 1 … 3, else `done`); the schema-example rule applies
only at the X gate. **Rollback**: revert the commits; schema 2 payloads would then be refused as newer, the documented
behaviour. **CI**: the existing `ci` workflow's round02 half b filter already includes `MyceliumArchitect`; no new job.

## Parallel work

Agents B (hint rule and search, hints, failure explanation) and C (progress, stars, daily, mode, tutorial) draft in
parallel in isolated copies; the lead edits the adapter and scenarios against their contracts, then the presenter and
panel; agent D writes the simulator tests with the presenter's exact texts in its brief; the lead runs every check and
records only after every agent has reported and every draft is retested in the repository.
