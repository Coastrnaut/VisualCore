# Implementation Plan: R02-G21-07 — Binary Gardens: persistence and replay

**Branch**: `507-binary-gardens-persistence-and-replay` (spec directory only; work on `main`) | **Date**:
2026-11-27 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/507-binary-gardens-persistence-and-replay/spec.md`

## Summary

Make Binary Gardens' saves reconcilable on Mushroom Weather's feature-497 pattern: results gain the winning trace (the
effective ring, phase, luminosity and tilt actions of the play, then the run) and `verified`;
`BinaryGardensReconciliation` replays each trace on its certified level on restore and drops results that do not
verify; the adapter writes snapshot schema 3 (`{level, mode, progress, records, sound, tutorial}`) with a 2 → 3
migration and digest domain `"r02-g21.binary-gardens.v3"`, adds replay (`replay.start/step/stop`, mode `replay(level)`,
stepping by action and keeping the shown tick) and `settings.sound`; the presenter announces dropped results, replay
steps and the replay refusals and applies the saved sound choice in place of R02-G21-06's presenter-held one; the panel
gains replay controls. Research: [research.md](research.md). Data: [data-model.md](data-model.md). API:
[contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Audit (2026-11-27, read-only)**: the committed adapter (`BinaryGardensExperienceCore`, feature 503) writes snapshot
schema 1 `{"level", "records"}` with no migration steps, digests `"r02-g21.binary-gardens.v1"` (level number, play
fingerprint), declares nine controls and refuses a restore as `BinaryGardensRestoreRefusal` (`damaged`,
`levelNumber(n)`, `kernel(error)`); `BinaryGardensRecord.Kind` is ring, phase, luminosity, tilt, run, undo, redo,
begin, dismissTutorial, pause, resume and showResult; `BinaryGardensPlay.apply(_:expecting:)` accepts an arrangement
action or the run only while `playing`, undo returns a failed play to playing, a won play is final, undo and redo
restore the play's own `actionsSpent` (so the play's count is the net count, not the progress's), and
`BinaryGardensPlay.replay(level:records:)` reproduces every record or throws `r02-g21.malformed`; the budget is 1 … 24
(`BinaryGardensLevel.budgets`), worlds 1 … 5; `generated(number:)` certifies a level once per process (the solver,
at most 5,000 arrangements judged, `BinaryGardensSolver.workBound`) and caches it; `BinaryGardensPlan.size` is the
plan's arrangement actions. The shared `SavedStateStore` (VisualCoreExperience) writes atomically, quarantines
unreadable files (at most 3) and reports `snapshot.newer-schema`; `MigrationChain` (VisualCorePersistence) runs the
steps; both are reused unchanged and no new target is needed. Feature 497's committed Mushroom Weather code
(`MushroomWeatherReconciliation`, schema 3 with `migratedToSchemaThree`, the replay branch of `apply`, the replay
prefix check in `restore`, `soundOn`, `reconciliationDropped`, the presenter's `absorbSaved`) is the model.
**Prerequisites recorded first** (planned, not in code): R02-G21-04 (feature 504: the presenter's `send` and
`refusalLog`, the panel's pickers), R02-G21-05 (feature 505: `BinaryGardensProgress` with its results, frontier and
stars rule, `BinaryGardensMode` campaign, practice and daily, `BinaryGardensTutorialStep` with `tutorial.dismiss`,
`level.select`, the mode controls, the codes `r02-g21.locked` and `r02-g21.date`, snapshot schema 2 with the 1 → 2
step, digest domain v2, the certified plan of the prepared level) and R02-G21-06 (feature 506:
`BinaryGardensFeedbackPlan` with the announcement kinds, the presenter's `route`, `feedbackLog`, `setSound(on:)` and
sound player, the panel's labelled controls and Sound toggle, `BinaryGardensAccessibilityTests`). Builders on them:
`BinaryGardensProgress.swift` and the reconciliation extend 505's progress, mode and stars rule; the adapter extends
505's schema 2, migration chain, modes, tutorial and digest; `BinaryGardensFeedbackPlan.swift` extends 506's plan;
the presenter extends 504's `send` and 506's route and sound; the panel extends 506's labelled controls; the edited
tests are 505's `BinaryGardensProgressTests` and `BinaryGardensProgressionCoreTests` and 506's
`BinaryGardensFeedbackPlanTests` and `BinaryGardensAccessibilityTests`. **Language/Version**: Swift 6. **Primary
dependencies**: the Binary Gardens Core (play, records, progress, certified catalog), VisualCoreExperience (snapshots,
the shared store), VisualCorePersistence (`MigrationChain`). No new package, target, GLSL, Objective-C++ or VisualCore
API (no API baseline change). **Storage**: the one state file of the shared store. **Seeds**: tests use seed 2_507.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02 --filter BinaryGardens`; simulator package
tests on sim-27.2; app unit tests; the reference regression in two chunks; script tests alone; each new test under
10 s (asserted locally only). **Target platform**: iOS 27.x and 26.5 simulators now; devices after
ImplementationLock-100. **Performance (counted, never timed)**: a restore reconciles at most 100 results, each a replay
of at most 64 kernel actions on a fresh play (at most 6,400 actions, each one report over 48 + E ≤ 60 ticks for at
most 5 worlds; an honest save needs at most 100 × 25 = 2,500); the levels come from the per-process cache, so only the
first restore in a process certifies them (at most 100 certifications, each at most 5,000 arrangements judged); a
restored replay is checked by one pass over its records; `replay.step` applies one kernel action and counts the records
once (a replay holds at most 2 event records and 64 actions); the replay catalog test certifies the 100 levels
once (10 groups of 10).
**Constraints**: no clock or random source in the state; the sound choice is snapshotted and in `==`, never digested;
the dropped count is in neither; a restored replay must be exactly the first actions of its level's verified trace, or
the payload is refused as `damaged`.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| II App-neutral API | PASS — game code in ExperiencesRound02; the shared store and migration chain reused unchanged. |
| II-a Preserve the reference | PASS — the reference regression runs in two chunks (7 of 7). |
| IV Host-testable | PASS — traces, reconciliation, migrations, replay and the sound setting in the Core, host-tested. |
| V Implementation before devices | PASS — a save surviving termination on hardware waits for D1–D3. |
| VI Evidence over assertion | PASS — reconciliation proves every kept score by replay; agent results retested. |
| VII Native, accessible UI | PASS — replay controls with labels, values and identifiers; refusals announced in words. |
| VIII Privacy | PASS — the save stays in the app's container; no network, accounts or identifiers. |
| IX Bounded input | PASS — trace bound 64, damaged and newer payloads refused, replay prefix checked. |
| XI One app | PASS — the candidate experience only; no target, bundle or scheme. |
| XII One purchase, no advertising | PASS — tier free; nothing sold or shown. |
| XIII Code-driven visuals | PASS — no art, shader or model change. |

Determinism (fixed seeds, the date action and recorded actions only; the shown tick never moved by time) is checked
under IV and IX. Post-design re-check: PASS (the data model and contract add no dependency, target or public
VisualCore name; the digest change is a game-local domain string).

## Project Structure

```text
Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensProgress.swift
    edit  Result trace + verified; record(..., mode:, trace:); drop(level:); mode replay(level) (agent B)
Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensReconciliation.swift
    new   netTrace(records), verifies(level:result:), reconcile(progress) (agent B)
Packages/ExperiencesRound02/BinaryGardens/CoreTests/BinaryGardensReconciliationTests.swift
    new   honest and edited traces, net traces with undo, redo and an undone failed run (agent B)
Packages/ExperiencesRound02/BinaryGardens/CoreTests/BinaryGardensProgressTests.swift
    edit  traced records, ties keep the earlier trace, replay records nothing, Codable with traces (agent B)
Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensExperienceCore.swift
    edit  schema 3, migration 2 → 3, digest v3, traces, reconcile, replay, settings.sound (lead)
Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensScenarios.swift
Packages/ExperiencesRound02/BinaryGardens/scenario-manifest.json
    edit  wrong value counts of the four controls; manifest regenerated (UPDATE_SCENARIO_MANIFEST=1) (lead)
Packages/ExperiencesRound02/BinaryGardens/CoreTests/BinaryGardensExperienceCoreTests.swift
    edit  control list, schema 3, digest v3, newer-schema literal 4 / 3; schema 3, migrations, replay (lead)
Packages/ExperiencesRound02/BinaryGardens/CoreTests/BinaryGardensProgressionCoreTests.swift
    edit  replay and sound beside the modes; 1 → 2 → 3 migration of every level (lead)
Packages/ExperiencesRound02/BinaryGardens/CoreTests/BinaryGardensSceneSnapshotTests.swift
    edit  the schema version assertion only (lead)
Packages/ExperiencesRound02/BinaryGardens/CoreTests/BinaryGardensPersistenceTests.swift
    new   500 round trips, 100 schema-1 and schema-2 migrations, 200 honest and edited saves (agent C)
Packages/ExperiencesRound02/BinaryGardens/CoreTests/BinaryGardensReplayCatalogTests.swift
    new   every certified level won, then replayed against its witness fingerprints, 10 groups (agent C)
Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensFeedbackPlan.swift
    edit  replay refusal words, replay step, replay start and stop, dropped text (lead)
Packages/ExperiencesRound02/BinaryGardens/CoreTests/BinaryGardensFeedbackPlanTests.swift
    edit  added cases for the three codes and the replay step (lead)
Packages/ExperiencesRound02/BinaryGardens/Experience/BinaryGardensPresenter.swift
Packages/ExperiencesRound02/BinaryGardens/Experience/BinaryGardensControls.swift
    edit  replay buttons and position, dropped announcement, saved sound (lead)
Packages/ExperiencesRound02/BinaryGardens/ExperienceTests/BinaryGardensExperienceIdentityTests.swift
Packages/ExperiencesRound02/BinaryGardens/ExperienceTests/BinaryGardensAccessibilityTests.swift
    edit  control list and schema 3; the sound choice from the state (lead)
Packages/ExperiencesRound02/BinaryGardens/ExperienceTests/BinaryGardensReplayTests.swift
    new   replay through the port, dropped count once, restored sound applied on open (agent C)
docs/architecture/binary-gardens.md
Packages/ExperiencesRound02/README.md
docs/automatedtesting.md
README.md
    edit  schema 3, reconciliation, replay, sound setting, the new tests (lead)
```

The new Core file sits in `Core/` beside the kernel; the invariant test's fixed 10-file kernel list is unchanged.
Files are picked up by path; no app file is added, so `xcodegen generate` is not needed.

**Dependency graph**: features 504, 505 and 506 recorded → progress traces and reconciliation (B) → adapter (schema 3,
digest v3, replay, sound) → scenarios and manifest, feedback plan → presenter and panel → persistence and replay
catalog tests (C, against the contract from the adapter step) → simulator replay tests (C) → docs. **Migration**:
schema 2 → 3: every stored result gains an empty trace and `verified: false`, the sound choice is off, everything else
is copied; schema 1 runs 505's step first. **Rollback**: revert the feature's commits; a schema-3 save would then be
reported as newer (`snapshot.newer-schema`) by the reverted build and the opening state used, while the store keeps the
file; the schema-2 shape is untouched, so nothing else needs undoing. **CI**: the `ci` workflow's round02 half b filter
already includes `BinaryGardens` (no new job); the script tests and the steering validators run on every push; the
simulator suite and the reference regression run locally. The app's schema-example rule applies at R02-G21-09
(examples of schemas 1 and 2 registered then).

## Parallel work

Implementation starts after R02-G21-04, 05 and 06 are recorded. Agent B (progress traces, reconciliation and their
tests) drafts first in an isolated copy against the contract; the lead then edits the adapter, scenarios and manifest
while agent C writes the persistence and replay catalog tests against the contract; the lead wires the feedback plan,
presenter and panel; agent C writes the simulator replay tests with the presenter's exact texts in its brief. One
writer per file; agents do not build in the repository, commit or push; the lead runs every check, retests each agent
result and records only after every agent has reported.
