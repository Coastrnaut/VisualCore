# Implementation Plan: R02-G13-07 — Acoustic Constellator: persistence and replay

**Branch**: `427-acoustic-constellator-persistence-and-replay` (spec directory only; work on `main`) | **Date**: 2026-11-23 |
**Spec**: [spec.md](spec.md)

## Summary

Make Acoustic Constellator's saves reconcilable on Harmonic Bridges' feature-417 pattern: results gain the winning
trace (the effective actions of the play) and `verified`; `AcousticConstellatorReconciliation` replays each trace on its certified level
on restore and drops results that do not verify; the adapter writes snapshot schema 3 (`{level, mode, progress,
records, sound, tutorial}`) with a 2 → 3 migration, adds replay (`replay.start/step/stop`, mode `replay(level)`) and
`settings.sound`; the presenter announces dropped results, replay steps and the replay refusals and applies the saved
sound choice; the panel gains replay controls. Research: [research.md](research.md). Data: [data-model.md](data-model.md).
API: [contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Audit (2026-11-23)**: the adapter writes schema 2 with a 1 → 2 step; `AcousticConstellatorProgress.Result` holds
`actionsSpent` (link, unlink, nudge and listen records, undone ones included) and `stars`; the play's records carry link, unlink,
nudge, listen, undo and redo; the shared `SavedStateStore` (VisualCorePersistence) writes atomically and refuses newer schemas;
no new target is needed. Prerequisite: R02-G13-06 (the feedback plan `AcousticConstellatorFeedbackPlan` and the presenter's
sound choice) is recorded first, as the ledger's gate order requires.
**Language/Version**: Swift 6. **Primary dependencies**: the Acoustic Constellator Core (play, records, progress,
generator), VisualCoreExperience (`MigrationChain`, snapshots), VisualCorePersistence (the shared store). No new
package, target, GLSL or VisualCore API; no Objective-C++.
**Seeds**: tests use seed 2_417.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02`; simulator package tests on sim-27.2; app unit
tests; regression; script tests alone.
**Performance**: reconciliation replays at most 100 traces, each bounded (R6), on restore only.
**Constraints**: no clock or random source in the state; the sound choice is snapshotted, never digested; a restored
replay must be exactly the first actions of its level's verified trace, or the payload is refused as `damaged`.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| II App-neutral API | PASS — game code in ExperiencesRound02; the shared store is reused unchanged. |
| IV Host-testable | PASS — traces, reconciliation, migrations and replay in the Core with host tests. |
| V Implementation before devices | PASS — a save surviving termination on hardware waits for D1–D3. |
| VI Evidence Over Assertion | PASS — reconciliation proves every kept score by replay. |
| VII Determinism | PASS — fixed seeds, the date action and recorded actions only. |
| IX Bounded input | PASS — trace bounds, damaged and newer payloads refused. |
| XII One purchase, no advertising | PASS — free; no network or accounts. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/AcousticConstellator/Core/AcousticConstellatorProgress.swift                   edit  Result trace + verified; record(..., trace:); drop; replay mode (agent A)
Packages/ExperiencesRound02/AcousticConstellator/Core/AcousticConstellatorReconciliation.swift             new   replay-verify results; net trace from records (agent A)
Packages/ExperiencesRound02/AcousticConstellator/CoreTests/AcousticConstellatorReconciliationTests.swift   new   (agent A)
Packages/ExperiencesRound02/AcousticConstellator/Core/AcousticConstellatorExperienceCore.swift             edit  schema 3, migration 2 → 3, traces, reconcile, replay, sound (lead)
Packages/ExperiencesRound02/AcousticConstellator/Core/AcousticConstellatorScenarios.swift, Packages/ExperiencesRound02/AcousticConstellator/scenario-manifest.json   edit (lead)
Packages/ExperiencesRound02/AcousticConstellator/CoreTests/AcousticConstellatorExperienceCoreTests.swift   edit  schema 3, migrations, replay (lead)
Packages/ExperiencesRound02/AcousticConstellator/CoreTests/AcousticConstellatorPersistenceTests.swift      new   500 round trips, 100 migrations, 200 edited saves (agent B)
Packages/ExperiencesRound02/AcousticConstellator/Core/AcousticConstellatorFeedbackPlan.swift               edit  replay refusal words, replay step and dropped texts (lead)
Packages/ExperiencesRound02/AcousticConstellator/Experience/{AcousticConstellatorPresenter, AcousticConstellatorControls}.swift   edit  replay buttons, dropped announcement, saved sound (lead)
Packages/ExperiencesRound02/AcousticConstellator/ExperienceTests/AcousticConstellatorReplayTests.swift     new   replay through the port (agent C)
docs/architecture/acoustic-constellator.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md   edit (lead)
```

**Dependency graph**: progress and reconciliation → adapter (schema 3, replay, sound) → scenarios, feedback, presenter
and panel → persistence and replay tests. **Migration**: schema 2 → 3 (results with empty traces, unverified; sound
off). **Rollback**: revert the commits; a schema-3 save would then be refused as newer by the reverted build and the
opening state used (the store keeps the file). **CI**: the round-two host suite, the script tests and the steering
validators on every push; simulator suites run locally. The app's schema-example rule applies at R02-G13-09 (examples of
schemas 1 and 2 registered then).

## Parallel work

Agent A (progress traces, reconciliation) first; then the lead edits the adapter while agent B writes the persistence
tests against the contract; the lead wires feedback, presenter and panel; agent C writes the simulator replay tests; the
lead runs every check and records only after every agent has reported.
