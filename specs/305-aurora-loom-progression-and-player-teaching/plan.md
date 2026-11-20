# Implementation Plan: R02-G01-05 — Aurora Loom: progression and player teaching

**Branch**: `305-aurora-loom-progression-and-player-teaching` (spec directory only; work on `main`) | **Date**: 2026-11-20 |
**Spec**: [spec.md](spec.md)

## Summary

Teach and pace Aurora Loom. In the host-tested `AuroraLoomCore`: progressive hints from the solver run on the current
steps (`AuroraLoomHints`, using a new `AuroraLoomSolver.solve(_:from:)`), the tutorial's instruction sequence
(`AuroraLoomTutorial`), progress with stars, unlocking, the daily level and practice mode (`AuroraLoomProgress`), failure
explanations (`AuroraLoomCoaching`), and the adapter's new actions and snapshot schema 2 with a migration from schema 1.
In the iOS `AuroraLoomExperience`: the panel shows the instruction, a Hint button that reveals the next hint level, the
failure explanation, a level picker of open levels, and Daily/Practice/Campaign choices; the presenter sends the local
calendar date with `mode.daily`. Research: [research.md](research.md). Data: [data-model.md](data-model.md). API:
[contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6. **Primary dependencies**: AuroraLoomCore's kernel, solver and generator;
VisualCoreExperience (`MigrationChain`, `ExperienceControl`, `ExperienceAction`); SwiftUI in the Experience. No GPU work,
no VisualCore change.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02` (2,000 seeded hint states over all 100 levels,
tutorial scripts on levels 1 … 3, 500 seeded failures, scripted progress through 100 levels, every date 2026 … 2036,
schema 1 → 2 migration, conformance); simulator: the panel's hint, failure text, picker and modes through the presenter;
app unit tests (candidate); regression as R02-G01-04; script tests (alone). The scenario manifest is regenerated (new
controls, schema 2 digests).
**Performance**: a hint is one solve: ≤ 768 + 3,072 setting evaluations, each a 4-gate test at tick 0 for ribbons turning
with Ω — well under a millisecond in release.
**Constraints**: the core never reads a clock (the date arrives in the action); progress is state (digest, snapshot);
writing it to disk is R02-G01-07.

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
Packages/ExperiencesRound02/AuroraLoom/Core/AuroraLoomSolver.swift              edit  solve(_:from:) (agent B)
Packages/ExperiencesRound02/AuroraLoom/Core/AuroraLoomHints.swift               new   hints, coaching (agent B)
Packages/ExperiencesRound02/AuroraLoom/Core/AuroraLoomProgress.swift            new   progress, stars, daily, tutorial steps (agent C)
Packages/ExperiencesRound02/AuroraLoom/Core/AuroraLoomExperienceCore.swift      edit  actions, modes, schema 2, migration (lead)
Packages/ExperiencesRound02/AuroraLoom/Core/AuroraLoomScenarios.swift           edit  new controls, regenerated manifest (lead)
Packages/ExperiencesRound02/AuroraLoom/CoreTests/{AuroraLoomHintsTests (B), AuroraLoomProgressTests (C)}.swift   new
Packages/ExperiencesRound02/AuroraLoom/CoreTests/AuroraLoomExperienceCoreTests.swift                              edit (lead)
Packages/ExperiencesRound02/AuroraLoom/Experience/{AuroraLoomPresenter, AuroraLoomControls}.swift                edit (lead)
Packages/ExperiencesRound02/AuroraLoom/ExperienceTests/AuroraLoomTeachingTests.swift                             new (agent D)
docs/architecture/aurora-loom.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md                edit (lead)
```

**Migration**: snapshot schema 1 → 2 (progress empty, campaign mode, tutorial at step 1). **Rollback**: revert the commits;
schema 2 payloads would then be refused as newer, which is the documented behaviour.

## Parallel work

Agents B (solver-from-steps, hints, coaching) and C (progress, stars, daily, tutorial) work in parallel; the lead edits
the adapter and scenarios against their contracts, then the presenter and panel; agent D writes the simulator tests; the
lead runs every check and records only after every agent has reported.
