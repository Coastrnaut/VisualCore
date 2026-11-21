# Implementation Plan: R02-G02-07 — Lissajous Labyrinth: persistence and replay

**Branch**: `317-lissajous-labyrinth-persistence-and-replay` (spec directory only; work on `main`) | **Date**: 2026-11-21 |
**Spec**: [spec.md](spec.md)

## Summary

Make Lissajous Labyrinth's progress durable and checkable, following feature 307. In the host-tested
`LissajousLabyrinthCore`: results gain their winning trace and a `verified` flag (`LissajousLabyrinthProgress`),
`LissajousLabyrinthReconciliation` replays each trace on its certified level on restore and drops what does not
verify, the mode gains `replay(level:)`, and the adapter writes snapshot schema 3 with a 2 → 3 migration, records the
winning trace of each campaign or daily win, reconciles on restore and adds `replay.start/step/stop`. In the iOS
`LissajousLabyrinthExperience`: the panel offers Replay for a verified solved level with Step and Stop, and the
presenter announces dropped results once. Research: [research.md](research.md). Data: [data-model.md](data-model.md).
API: [contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6. **Primary dependencies**: LissajousLabyrinthCore's kernel and generator;
VisualCoreExperience (`MigrationChain`, snapshots); the app's shared `SavedStateStore` (unchanged). No new package.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02` (500 seeded round trips, 100 schema-1 and
schema-2 migrations, 200 seeded saves with honest and edited results, every certified trace replayed); simulator: replay
through the port and the dropped announcement; app unit tests (candidate); regression as R02-G02-06; script tests
(alone). The scenario manifest is regenerated (schema 3 digests, new controls).
**Performance**: reconciliation replays at most 100 traces of at most 64 actions on restore (100 level generations are
cached per process; each lap verdict is exact integer work).
**Constraints**: no clock or random source in the state; the saved frontier is restored as saved; replay never changes
progress.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| II App-neutral API | PASS — game code in the experience package; the shared store is reused unchanged. |
| III Deterministic, testable core | PASS — seeds, dates and actions only; replay and reconciliation are host-tested. |
| IV Host-testable | PASS — progress, reconciliation, migration and replay in the Core. |
| V Implementation before devices | PASS — a save surviving termination on hardware waits for D1–D3. |
| VI Evidence Over Assertion | PASS — round trips, migrations and edited saves are property-tested. |
| IX Bounded input | PASS — traces bounded by the allowance; level numbers and actions validated; stable refusal codes. |
| XI One app and stable identity | PASS — snapshot versioned with migrations; newer schemas refused by the shared store. |
| XII One purchase, no advertising | PASS — free; no network or accounts. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthProgress.swift                   edit  Result trace + verified; record(..., trace:); replay mode (agent A)
Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthReconciliation.swift             new   replay-verify results (agent A)
Packages/ExperiencesRound02/LissajousLabyrinth/CoreTests/LissajousLabyrinthReconciliationTests.swift   new   (agent A)
Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthExperienceCore.swift             edit  schema 3, migration 2 → 3, traces, reconcile, replay (lead)
Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthScenarios.swift, Packages/ExperiencesRound02/LissajousLabyrinth/scenario-manifest.json   edit (lead)
Packages/ExperiencesRound02/LissajousLabyrinth/CoreTests/LissajousLabyrinthExperienceCoreTests.swift   edit  schema 3, migrations, replay (lead)
Packages/ExperiencesRound02/LissajousLabyrinth/CoreTests/LissajousLabyrinthPersistenceTests.swift      new   500 round trips, 100 migrations, 200 edited saves (agent B)
Packages/ExperiencesRound02/LissajousLabyrinth/Experience/LissajousLabyrinthPresenter.swift, LissajousLabyrinthControls.swift   edit  replay buttons, dropped announcement (lead)
Packages/ExperiencesRound02/LissajousLabyrinth/ExperienceTests/LissajousLabyrinthReplayTests.swift     new   replay through the port (agent C)
docs/architecture/lissajous-labyrinth.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md   edit (lead)
```

**Migration**: schema 2 → 3 (results with empty traces, unverified). **Rollback**: revert the commits; a schema-3 save
would then be refused as newer by the reverted build and the opening state used (the store keeps the file).

## Parallel work

Agent A (progress trace, replay mode and reconciliation) first; the lead edits the adapter on A's contract; agent B
writes the persistence property tests against the adapter; agent C the simulator replay tests; the lead retests and
records checks after every agent has reported.
