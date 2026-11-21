# Implementation Plan: R02-G05-05 — Colorfall Canyons: progression and player teaching

**Branch**: `345-colorfall-canyons-progression-and-player-teaching` (spec directory only; work on `main`) | **Date**:
2026-11-21 | **Spec**: [spec.md](spec.md)

## Summary

Teach and pace Colorfall Canyons on Hue Compass's feature-335 pattern: `ColorfallCanyonsHints` (a smallest winning edit
set applied now from the current fluid, searched like the solver; an empty plan means "run") with
`ColorfallCanyonsFailureExplanation` (basin, colour and amounts of the failing tick); `ColorfallCanyonsProgress` (best
actions and stars, open frontier, daily level × 53), `ColorfallCanyonsMode` and `ColorfallCanyonsTutorialStep`; the
adapter gains `level.select`, `mode.daily`, `mode.practice`, `mode.campaign` and `tutorial.dismiss`, codes
`r02-g05.locked` and `r02-g05.date`, and snapshot schema 2 with a migration from 1; the presenter shows the tutorial,
hints and failure text and the panel gains Hint and mode controls. Research: [research.md](research.md). Data:
[data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6. **Primary dependencies**: the Colorfall Canyons Core (`ColorfallCanyonsSolver` and its
`FastFlow`, `ColorfallCanyonsPlay`, `ColorfallCanyonsFluid`, `ColorfallCanyonsLevel`, the generator's certified catalog),
VisualCoreExperience (controls, snapshot migrations). No new package, target, GLSL or VisualCore API; no Objective-C++.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02`; simulator package tests on sim-27.2; the app
unit tests; regression; script tests alone. Seed 2_345.
**Performance**: a hint from any reachable state of a certified level within 0.5 s on the debug host build (measured by
the hint tests; no wall-clock assertion on CI).
**Constraints**: the core reads no clock (the date comes as an action); practice budget 30 (the kernel's maximum); hints
read only; tests under 10 s.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| II App-neutral API | PASS — game code stays in ExperiencesRound02; VisualCore unchanged. |
| IV Host-testable | PASS — hints, failure text, progress and modes in the Core with host tests. |
| V Implementation before devices | PASS — no device work. |
| IX Bounded input | PASS — level numbers, dates and modes validated; schema migration refuses newer payloads. |
| XII One purchase, no advertising | PASS — every level free; no paywall. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/ColorfallCanyons/Core/ColorfallCanyonsSolver.swift            edit  plan(from:) over a fluid state (agent B)
Packages/ExperiencesRound02/ColorfallCanyons/Core/ColorfallCanyonsHints.swift             new   hints, failure explanation (agent B)
Packages/ExperiencesRound02/ColorfallCanyons/Core/ColorfallCanyonsProgress.swift          new   progress, stars, daily, mode, tutorial steps (agent C)
Packages/ExperiencesRound02/ColorfallCanyons/Core/ColorfallCanyonsExperienceCore.swift    edit  actions, modes, schema 2, migration (lead)
Packages/ExperiencesRound02/ColorfallCanyons/Core/ColorfallCanyonsScenarios.swift         edit  new controls, regenerated manifest (lead)
Packages/ExperiencesRound02/ColorfallCanyons/CoreTests/{ColorfallCanyonsHintsTests (B), ColorfallCanyonsProgressTests (C)}.swift   new
Packages/ExperiencesRound02/ColorfallCanyons/CoreTests/ColorfallCanyonsExperienceCoreTests.swift                                   edit (lead)
Packages/ExperiencesRound02/ColorfallCanyons/Experience/{ColorfallCanyonsPresenter, ColorfallCanyonsControls}.swift               edit (lead)
Packages/ExperiencesRound02/ColorfallCanyons/ExperienceTests/ColorfallCanyonsTeachingTests.swift                                  new (agent D)
docs/architecture/colorfall-canyons.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md                           edit (lead)
```

**Migration**: snapshot schema 1 → 2 (level 1 and the restored level open, campaign mode, tutorial at step 1 on tutorial
levels). **Rollback**: revert the commits; schema 2 payloads would then be refused as newer, the documented behaviour.
**CI**: the existing `ci` workflow runs the host tests; no new job.

## Parallel work

Agents B (plan search, hints, failure explanation) and C (progress, stars, daily, mode, tutorial) work in parallel in
isolated copies; the lead edits the adapter and scenarios against their contracts, then the presenter and panel; agent
D writes the simulator tests; the lead runs every check and records only after every agent has reported.
