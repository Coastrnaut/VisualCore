# Implementation Plan: R02-G03-05 — Wave Knot Keeper: progression and player teaching

**Branch**: `325-wave-knot-keeper-progression-and-player-teaching` (spec directory only; work on `main`) | **Date**:
2026-11-21 | **Spec**: [spec.md](spec.md)

## Summary

Teach and pace Wave Knot Keeper, following feature 315. In the host-tested `WaveKnotKeeperCore`: the shortest
remaining solution from any rope (`WaveKnotKeeperSolver.solve(_:from:depth:)`, the certified breadth-first search
started from the current rope, depth at most 3), progressive hints (`WaveKnotKeeperHints`), failure explanations from
the kernel's summary (`WaveKnotKeeperFailureExplanation`), the tutorial's instruction sequence
(`WaveKnotKeeperTutorialStep`), progress with stars, unlocking, the daily level and practice mode
(`WaveKnotKeeperProgress`, `WaveKnotKeeperMode`), and the adapter's new actions and snapshot schema 2 with a
migration from schema 1. In the iOS `WaveKnotKeeperExperience`: the panel shows the instruction, a Hint button that
reveals the next hint level, the failure explanation with Undo and Retry, a level picker of open levels with stars and
bands, and Campaign/Daily/Practice choices; the presenter sends the local calendar date with `mode.daily`. Research:
[research.md](research.md). Data: [data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md). Quickstart:
[quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6. **Primary dependencies**: WaveKnotKeeperCore's kernel, solver and generator;
VisualCoreExperience (`MigrationChain`, `ExperienceControl`, `ExperienceAction`); SwiftUI in the Experience. No GPU work,
no VisualCore change.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02` (2,000 seeded hint states over all 100 levels,
tutorial scripts on levels 1 … 3, 500 seeded failures, scripted progress through 100 levels, every date 2026 … 2036,
schema 1 → 2 migration, conformance; levels generated once per band and cached, to keep each test under 10 s); simulator: the panel's hint, failure text, picker and modes through the presenter; app unit
tests (candidate); regression as R02-G03-04; script tests (alone). The scenario manifest is regenerated (new controls,
schema 2 digests).
**Performance**: a hint is one breadth-first search from the current rope, depth at most 3: at most 3,661 ropes expanded
for 10 points (feature 322's bound), well under 0.1 s on a debug host.
**Constraints**: the core never reads a clock (the date arrives in the action); progress is state (digest, snapshot);
writing it to disk is R02-G03-07.

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
Packages/ExperiencesRound02/WaveKnotKeeper/Core/WaveKnotKeeperSolver.swift          edit  solve(_:from:winning:) (agent B)
Packages/ExperiencesRound02/WaveKnotKeeper/Core/WaveKnotKeeperHints.swift           new   hints, failure explanation (agent B)
Packages/ExperiencesRound02/WaveKnotKeeper/Core/WaveKnotKeeperProgress.swift        new   progress, stars, daily, mode, tutorial steps (agent C)
Packages/ExperiencesRound02/WaveKnotKeeper/Core/WaveKnotKeeperExperienceCore.swift  edit  actions, modes, schema 2, migration (lead)
Packages/ExperiencesRound02/WaveKnotKeeper/Core/WaveKnotKeeperScenarios.swift       edit  new controls, regenerated manifest (lead)
Packages/ExperiencesRound02/WaveKnotKeeper/CoreTests/{WaveKnotKeeperHintsTests (B), WaveKnotKeeperProgressTests (C)}.swift   new
Packages/ExperiencesRound02/WaveKnotKeeper/CoreTests/WaveKnotKeeperExperienceCoreTests.swift                                    edit (lead)
Packages/ExperiencesRound02/WaveKnotKeeper/Experience/{WaveKnotKeeperPresenter, WaveKnotKeeperControls}.swift              edit (lead)
Packages/ExperiencesRound02/WaveKnotKeeper/ExperienceTests/WaveKnotKeeperTeachingTests.swift                                   new (agent D)
docs/architecture/wave-knot-keeper.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md                              edit (lead)
```

**Migration**: snapshot schema 1 → 2 (progress empty, campaign mode, tutorial at step 1 on tutorial levels).
**Rollback**: revert the commits; schema 2 payloads would then be refused as newer, which is the documented behaviour.

## Parallel work

Agents B (solver-from-rope, hints, failure explanation) and C (progress, stars, daily, mode, tutorial) work in parallel;
the lead edits the adapter and scenarios against their contracts, then the presenter and panel; agent D writes the
simulator tests; the lead runs every check and records only after every agent has reported.
