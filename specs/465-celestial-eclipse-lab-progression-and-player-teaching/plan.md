# Implementation Plan: R02-G17-05 — Celestial Eclipse Lab: progression and player teaching

**Branch**: `465-celestial-eclipse-lab-progression-and-player-teaching` (spec directory only; work on `main`) |
**Date**: 2026-11-25 | **Spec**: [spec.md](spec.md)

## Summary

Give Celestial Eclipse Lab its teaching and progression, following Starlit Cartouche's R02-G16-05 (feature 455) in the
same package: in the host-tested Core a solver entry point that computes the minimal plan from given phases
(`plan(_:from:)`), the hint plan and its three levels (the planet, the way and distance, the exact phase), the failure
explanation (an unwanted eclipse, a target outside its window, or the horizon), the tutorial steps (levels 1 … 3),
progress with stars, the daily level (× 29) and the practice mode (budget 24); the adapter gains `level.select`,
`mode.daily`, `mode.practice`, `mode.campaign` and `tutorial.dismiss` and snapshot schema 2 with a migration from 1; the
presenter shows the tutorial, hints (searched off the main actor), failure text, stars and modes in the panel.
Research: [research.md](research.md). Data: [data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md).
Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Audit (2026-11-25)**: `CelestialEclipseLabCore` (Core, CoreTests) and `CelestialEclipseLabExperience` (Experience,
ExperienceTests) exist in `Packages/ExperiencesRound02/Package.swift` and are linked by `project.yml`; no new target.
The generator sets the tutorial flag on levels 1 … 3; the adapter dismisses the kernel's tutorial stage at opening.
`CelestialEclipseLabSolver.plan(_:maxChanges:workBound:)` searches from the level's starting phases; the new entry point
takes the phases as a parameter, so the hint never builds a derived level. The adapter keeps the chosen body, shown
tick and pending phase outside the play (presentation).
**Language/Version**: Swift 6. **Primary dependencies**: the Celestial Eclipse Lab Core (`CelestialEclipseLabSolver`,
`CelestialEclipseLabPlay`, `CelestialEclipseLabLevel`, `CelestialEclipseLabSky`, the certified catalog),
VisualCoreExperience (controls, snapshot migrations). No new package, target, GLSL, Objective-C++ or VisualCore API.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02` (round02-host split by filter); simulator
package tests on sim-27.2; the app unit tests; regression; script tests alone. Seed 2_465.
**Performance**: a hint search is bounded by the solver's work limit (60,000 settings judged, at most 5 changes); the
certification already ran it from every level's opening (at most 10,291 settings judged); measured by the hint tests;
no wall-clock assertion on CI.
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
Packages/ExperiencesRound02/CelestialEclipseLab/Core/CelestialEclipseLabSolver.swift          edit  plan from given phases (agent B)
Packages/ExperiencesRound02/CelestialEclipseLab/Core/CelestialEclipseLabHints.swift           new   plan, hints, failure explanation (agent B)
Packages/ExperiencesRound02/CelestialEclipseLab/Core/CelestialEclipseLabProgress.swift        new   progress, stars, daily, mode, tutorial steps (agent C)
Packages/ExperiencesRound02/CelestialEclipseLab/Core/CelestialEclipseLabExperienceCore.swift  edit  actions, modes, schema 2, migration (lead)
Packages/ExperiencesRound02/CelestialEclipseLab/Core/CelestialEclipseLabScenarios.swift       edit  new controls, regenerated manifest (lead)
Packages/ExperiencesRound02/CelestialEclipseLab/CoreTests/{CelestialEclipseLabHintsTests (B), CelestialEclipseLabProgressTests (C)}.swift   new
Packages/ExperiencesRound02/CelestialEclipseLab/CoreTests/CelestialEclipseLabExperienceCoreTests.swift                                   edit (lead)
Packages/ExperiencesRound02/CelestialEclipseLab/Experience/{CelestialEclipseLabPresenter, CelestialEclipseLabControls}.swift              edit (lead)
Packages/ExperiencesRound02/CelestialEclipseLab/ExperienceTests/CelestialEclipseLabTeachingTests.swift                                   new (agent D)
docs/architecture/celestial-eclipse-lab.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md   edit (lead)
```

**Dependency graph**: hints and progress (independent) → adapter (schema 2, new controls) → scenarios and manifest →
presenter and panel → teaching tests. **Migration**: snapshot schema 1 → 2 (level 1 and the restored level open,
campaign mode, tutorial at step 1 on tutorial levels); the schema-example rule applies only at the X gate.
**Rollback**: revert the commits; schema 2 payloads would then be refused as newer, the documented behaviour. **CI**:
the existing `ci` workflow runs the host tests; no new job.

## Parallel work

Agents B (solver entry point, plan, hints, failure explanation) and C (progress, stars, daily, mode, tutorial) work in
parallel; the lead edits the adapter and scenarios against their contracts, then the presenter and panel; agent D
writes the simulator tests with the presenter's exact texts in its brief; the lead runs every check and records only
after every agent has reported.
