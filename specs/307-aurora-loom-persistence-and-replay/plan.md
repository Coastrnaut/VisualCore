# Implementation Plan: R02-G01-07 — Aurora Loom: persistence and replay

**Branch**: `307-aurora-loom-persistence-and-replay` (spec directory only; work on `main`) | **Date**: 2026-11-20 |
**Spec**: [spec.md](spec.md)

## Summary

Make Aurora Loom's saved state complete, checkable and replayable. In the host-tested `AuroraLoomCore`: results in
`AuroraLoomProgress` gain the winning trace and `verified`; a new `AuroraLoomReconciliation` replays each trace on its
certified level and keeps only the results it proves; the adapter writes snapshot schema 3 with a 2 → 3 migration,
records traces on campaign and daily wins, reconciles on restore and adds replay (`replay.start`, `replay.step`,
`replay.stop`, mode `replay(level)`). In the iOS experience: replay buttons in the panel and a one-time announcement of
dropped results. Saving to disk stays with the app's shared `SavedStateStore` (atomic, quarantine, newer-schema
refusal). Research: [research.md](research.md). Data: [data-model.md](data-model.md). API:
[contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6. **Primary dependencies**: AuroraLoomCore (kernel, generator, progress, adapter);
VisualCoreExperience (`MigrationChain`, `ExperienceCore`) and VisualCorePersistence; the experience host for the panel.
No new package, target, VisualCore API or app change.
**Seeds**: no new randomness; tests use seed 2_307.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02`; simulator round-two suite; regression as in 306.
**Performance**: reconciliation replays at most 100 traces of at most 64 moves (≤ 6,400 kernel moves plus 100 level
generations) on restore; measured on the host, well under a second outside debug builds.
**Constraints**: additive; snapshot schema 3; scenario manifest regenerated; existing tests updated where they pin
schema 2.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| II App-neutral API | PASS — game code stays in ExperiencesRound02; the shared store is reused. |
| IV Host-testable | PASS — traces, reconciliation, migration and replay in the Core with host tests. |
| V Implementation before devices | PASS — termination on hardware is a D1–D3 observation. |
| VII Persistence and migration | PASS — versioned schema 3 with tested 1 → 2 → 3 migrations; damaged and newer payloads refused. |
| IX Bounded input | PASS — traces bounded by the allowance (≤ 64); 100 results at most. |
| XII One purchase, no advertising | PASS — free; no store code. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/AuroraLoom/Core/AuroraLoomProgress.swift                     edit  Result trace + verified; record(..., trace:) (agent A)
Packages/ExperiencesRound02/AuroraLoom/Core/AuroraLoomReconciliation.swift               new   replay-verify results (agent A)
Packages/ExperiencesRound02/AuroraLoom/CoreTests/AuroraLoomReconciliationTests.swift     new   (agent A)
Packages/ExperiencesRound02/AuroraLoom/Core/AuroraLoomExperienceCore.swift               edit  schema 3, migration 2 → 3, traces, reconcile, replay (lead)
Packages/ExperiencesRound02/AuroraLoom/Core/AuroraLoomScenarios.swift, Packages/ExperiencesRound02/AuroraLoom/scenario-manifest.json        edit (lead)
Packages/ExperiencesRound02/AuroraLoom/CoreTests/AuroraLoomExperienceCoreTests.swift     edit  schema 3, migrations, replay (lead)
Packages/ExperiencesRound02/AuroraLoom/CoreTests/AuroraLoomPersistenceTests.swift        new   500 round trips, 100 migrations, 200 edited saves (agent B)
Packages/ExperiencesRound02/AuroraLoom/Experience/AuroraLoomPresenter.swift, AuroraLoomControls.swift   edit  replay buttons, dropped announcement (lead)
Packages/ExperiencesRound02/AuroraLoom/ExperienceTests/AuroraLoomReplayTests.swift       new   replay through the port (agent C)
docs/architecture/aurora-loom.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md   edit (lead)
```

**Migration**: schema 2 → 3 (results without traces, unverified). **Rollback**: revert the commits; a schema-3 save
would then be refused as newer by the reverted build and the opening state used (the store keeps the file).

## Parallel work

Agent A (progress trace and reconciliation) first; the lead edits the adapter on A's contract; agent B writes the
persistence property tests against the adapter; agent C the simulator replay tests; the lead retests and records checks
after every agent has reported.
