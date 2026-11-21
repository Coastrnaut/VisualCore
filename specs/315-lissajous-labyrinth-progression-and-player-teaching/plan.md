# Implementation Plan: R02-G02-05 — Lissajous Labyrinth: progression and player teaching

**Branch**: `315-lissajous-labyrinth-progression-and-player-teaching` (spec directory only; work on `main`) | **Date**:
2026-11-21 | **Spec**: [spec.md](spec.md)

## Summary

Teach and pace Lissajous Labyrinth, following feature 305. In the host-tested `LissajousLabyrinthCore`: the shortest
remaining solution from any dials (`LissajousLabyrinthSolver.solve(_:from:winning:)`, the certified breadth-first search
started from given dials over a level's winning settings), progressive hints (`LissajousLabyrinthHints`), failure
explanations from the kernel's verdict (`LissajousLabyrinthFailureExplanation`), the tutorial's instruction sequence
(`LissajousLabyrinthTutorialStep`), progress with stars, unlocking, the daily level and practice mode
(`LissajousLabyrinthProgress`, `LissajousLabyrinthMode`), and the adapter's new actions and snapshot schema 2 with a
migration from schema 1. In the iOS `LissajousLabyrinthExperience`: the panel shows the instruction, a Hint button that
reveals the next hint level, the failure explanation with Undo and Retry, a level picker of open levels with stars and
bands, and Campaign/Daily/Practice choices; the presenter sends the local calendar date with `mode.daily`. Research:
[research.md](research.md). Data: [data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md). Quickstart:
[quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6. **Primary dependencies**: LissajousLabyrinthCore's kernel, solver and generator;
VisualCoreExperience (`MigrationChain`, `ExperienceControl`, `ExperienceAction`); SwiftUI in the Experience. No GPU work,
no VisualCore change.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02` (2,000 seeded hint states over all 100 levels,
tutorial scripts on levels 1 … 3, 500 seeded failures, scripted progress through 100 levels, every date 2026 … 2036,
schema 1 → 2 migration, conformance; fixtures from the committed witness files, as `LissajousLabyrinthPendingTests`, to
keep each test under 10 s); simulator: the panel's hint, failure text, picker and modes through the presenter; app unit
tests (candidate); regression as R02-G02-04; script tests (alone). The scenario manifest is regenerated (new controls,
schema 2 digests).
**Performance**: a level's winning settings are computed once when the level opens (the solver's prefiltered exact
decision) and kept as derived, undigested state; a hint is then one breadth-first search over at most 55 · 256 = 14,080
legal settings.
**Constraints**: the core never reads a clock (the date arrives in the action); progress is state (digest, snapshot);
writing it to disk is R02-G02-07.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I Proven renderer only | PASS — no rendering change. |
| II App-neutral API | PASS — game code in the experience package. |
| IV Host-testable | PASS — hints, tutorial, progress, daily and migration in the Core. |
| V Implementation before devices | PASS — no device work. |
| IX Bounded input | PASS — level numbers, dates and modes validated by declared controls and refusal codes. |
| X Licensing and provenance | PASS — original teaching text. |
| XI One app and stable identity | PASS — the registered candidate; snapshot versioned with a migration. |
| XII One purchase, no advertising | PASS — all levels free; no prompts. |
| XIII Code-driven visuals | PASS — nothing drawn beyond SwiftUI text and buttons. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthSolver.swift          edit  solve(_:from:winning:) (agent B)
Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthHints.swift           new   hints, failure explanation (agent B)
Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthProgress.swift        new   progress, stars, daily, mode, tutorial steps (agent C)
Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthExperienceCore.swift  edit  actions, modes, schema 2, migration (lead)
Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthScenarios.swift       edit  new controls, regenerated manifest (lead)
Packages/ExperiencesRound02/LissajousLabyrinth/CoreTests/{LissajousLabyrinthHintsTests (B), LissajousLabyrinthProgressTests (C)}.swift   new
Packages/ExperiencesRound02/LissajousLabyrinth/CoreTests/LissajousLabyrinthExperienceCoreTests.swift                                    edit (lead)
Packages/ExperiencesRound02/LissajousLabyrinth/Experience/{LissajousLabyrinthPresenter, LissajousLabyrinthControls}.swift              edit (lead)
Packages/ExperiencesRound02/LissajousLabyrinth/ExperienceTests/LissajousLabyrinthTeachingTests.swift                                   new (agent D)
docs/architecture/lissajous-labyrinth.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md                              edit (lead)
```

**Migration**: snapshot schema 1 → 2 (progress empty, campaign mode, tutorial at step 1 on tutorial levels).
**Rollback**: revert the commits; schema 2 payloads would then be refused as newer, which is the documented behaviour.

## Parallel work

Agents B (solver-from-dials, hints, failure explanation) and C (progress, stars, daily, mode, tutorial) work in parallel;
the lead edits the adapter and scenarios against their contracts, then the presenter and panel; agent D writes the
simulator tests; the lead runs every check and records only after every agent has reported.
