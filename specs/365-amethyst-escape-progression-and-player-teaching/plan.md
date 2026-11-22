# Implementation Plan: R02-G07-05 — Amethyst Escape: progression and player teaching

**Branch**: `365-amethyst-escape-progression-and-player-teaching` (spec directory only; work on `main`) | **Date**:
2026-11-22 | **Spec**: [spec.md](spec.md)

## Summary

Teach and pace Amethyst Escape on Chrono Constellator's feature-355 pattern: `AmethystEscapeHints` (the plan from the
current state: the first action of the shortest escape that fits in the moves left, by a breadth-first search from the
current crystal) with `AmethystEscapeFailureExplanation` (the blocked wedge's shell and sector and the move, or the moves
spent and the pearl's pocket); `AmethystEscapeProgress` (best moves and stars, open frontier, daily level × 61),
`AmethystEscapeMode` and `AmethystEscapeTutorialStep`; the solver gains a search from a given crystal; the adapter gains
`level.select`, `mode.daily`, `mode.practice`, `mode.campaign` and `tutorial.dismiss`, codes `r02-g07.locked` and
`r02-g07.date`, and snapshot schema 2 with a migration from 1; the presenter shows the tutorial, hints and failure text
and the panel gains Hint and mode controls. Research: [research.md](research.md). Data: [data-model.md](data-model.md).
API: [contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Audit (2026-11-22)**: `AmethystEscapeCore` (Core, CoreTests) and `AmethystEscapeExperience` (Experience,
ExperienceTests) exist in `Packages/ExperiencesRound02/Package.swift` and are linked by `project.yml`; no new target.
**Language/Version**: Swift 6. **Primary dependencies**: the Amethyst Escape Core (`AmethystEscapeSolver`,
`AmethystEscapePlay`, `AmethystEscapeCrystal`, `AmethystEscapeLevel`, the certified catalog), VisualCoreExperience
(controls, snapshot migrations). No new package, target, GLSL, Objective-C++ or VisualCore API.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02`; simulator package tests on sim-27.2; the app
unit tests; regression; script tests alone. Seed 2_365.
**Performance**: a hint from any reachable state of a certified level within 0.5 s on the debug host build (the state
space is at most 12⁵ offsets × 60 pockets; measured by the hint tests; no wall-clock assertion on CI).
**Constraints**: the core reads no clock (the date comes as an action); practice budget 60 (the kernel's maximum); hints
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
Packages/ExperiencesRound02/AmethystEscape/Core/AmethystEscapeSolver.swift                 edit  search from a given crystal within a depth (agent B)
Packages/ExperiencesRound02/AmethystEscape/Core/AmethystEscapeHints.swift                  new   plan, hints, failure explanation (agent B)
Packages/ExperiencesRound02/AmethystEscape/Core/AmethystEscapeProgress.swift               new   progress, stars, daily, mode, tutorial steps (agent C)
Packages/ExperiencesRound02/AmethystEscape/Core/AmethystEscapeExperienceCore.swift         edit  actions, modes, schema 2, migration (lead)
Packages/ExperiencesRound02/AmethystEscape/Core/AmethystEscapeScenarios.swift              edit  new controls, regenerated manifest (lead)
Packages/ExperiencesRound02/AmethystEscape/CoreTests/{AmethystEscapeHintsTests (B), AmethystEscapeProgressTests (C)}.swift   new
Packages/ExperiencesRound02/AmethystEscape/CoreTests/AmethystEscapeExperienceCoreTests.swift                                  edit (lead)
Packages/ExperiencesRound02/AmethystEscape/Experience/{AmethystEscapePresenter, AmethystEscapeControls}.swift                edit (lead)
Packages/ExperiencesRound02/AmethystEscape/ExperienceTests/AmethystEscapeTeachingTests.swift                                 new (agent D)
docs/architecture/amethyst-escape.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md   edit (lead)
```

**Dependency graph**: hints and progress (independent) → adapter (schema 2, new controls) → scenarios and manifest →
presenter and panel → teaching tests. **Migration**: snapshot schema 1 → 2 (level 1 and the restored level open,
campaign mode, tutorial at step 1 on tutorial levels); the AppModelTests schema-example rule applies only at the X gate,
so the schema-1 example is registered at R02-G07-09 (as Chrono did). **Rollback**: revert the commits; schema 2 payloads
would then be refused as newer, the documented behaviour. **CI**: the existing `ci` workflow runs the host tests; no new
job.

## Parallel work

Agents B (solver entry point, plan, hints, failure explanation) and C (progress, stars, daily, mode, tutorial) work in
parallel in isolated copies; the lead edits the adapter and scenarios against their contracts, then the presenter and
panel; agent D writes the simulator tests; the lead runs every check and records only after every agent has reported.
