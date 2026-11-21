# Tasks: R02-G05-07 — Colorfall Canyons: persistence and replay

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G05-07 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G05-07 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_347;
tests stay short (< 10 s each). {device} items are D1–D3 observations after ImplementationLock-100.

## Phase 1: Setup

- [X] T-R02G0507-001 Baselines: `--name baseline-round02`, `--name baseline-host`, `--name baseline-timing` — Verified 2026-11-21: 2026-11-21 baseline-host, baseline-timing, baseline-round02 exit 0 (.autonomy/migration/checks/R02-G05-07.baseline-*.json)

## Phase 2: Story 2 — reconcilable scores (P1) 🎯

- [X] T-R02G0507-002 [P] [US2] Edit `Packages/ExperiencesRound02/ColorfallCanyons/Core/ColorfallCanyonsProgress.swift` (Result gains "trace: [ColorfallCanyonsAction]" and — Verified 2026-11-21: 2026-11-21 host exit 0: 57 tests in 4 suites incl. 11 reconciliation tests (every certified trace verifies with 3 stars; 9 tampered results dropped and counted; untraced kept; frontier as saved; trace bound edges; net actions with undo/redo) (.autonomy/migration/checks/R02-G05-07.host.json); lead retest
  "verified: Bool"; `record(level:actions:smallest:mode:trace:)` stores a verified result, replacing only when better; `drop(level:)`; encoding keeps old payloads decodable (missing trace → empty, verified false); mode case
  "replay(level:)" that awards no stars and opens nothing) and create `Packages/ExperiencesRound02/ColorfallCanyons/Core/ColorfallCanyonsReconciliation.swift` ("a
  result with a trace is kept only when a fresh play of its certified level (campaign budget) replays the trace to a
  win having spent exactly bestActions with its stars; a trace over the bound of research R6 or with an illegal action
  never verifies; untraced results kept unverified; frontier unchanged") with
  `Packages/ExperiencesRound02/ColorfallCanyons/CoreTests/ColorfallCanyonsReconciliationTests.swift` (every certified level's solution as a trace verifies; edited
  stars, actions, a trace step and an illegal trace are dropped and counted; untraced kept; frontier unchanged);
  `--name host`

## Phase 3: Stories 1 and 3 — save, migrate, replay (P1, P2)

- [X] T-R02G0507-003 [US1] [US2] [US3] Edit `Packages/ExperiencesRound02/ColorfallCanyons/Core/ColorfallCanyonsExperienceCore.swift` (schema 3, migration 2 → 3 — Verified 2026-11-21: 2026-11-21 host-2 exit 0: 102 tests in 8 suites (schema 3 and digest v3; migrations 1 -> 3 and 2 -> 3 with progress kept unverified and sound off; wins record net-action traces; restore reconciles, honest kept, edited dropped and counted; replay start/step/stop with refusal codes and words; settings.sound snapshotted, never digested; manifest regenerated) (.autonomy/migration/checks/R02-G05-07.host-2.json); lead retest
  "results with an empty trace and verified false", digest v3; a campaign or daily win records the winning trace (the
  play's net actions: carves, valve toggles and steps, an undone action left out unless redone); restore reconciles and exposes
  `reconciliationDropped` (not digested); actions "replay.start [1…100]" (`r02-g05.no-replay` without a verified
  traced result), "replay.step" (`r02-g05.replay-end` after the last or once ended), "replay.stop" (campaign at that
  level, the frontier when it is not open); every other play action in replay refused with `r02-g05.replay` except
  `tutorial.dismiss`; replay never records; the tutorial is done in replay; FR-R02G0507-007: "settings.sound [0 … 1]" sets `soundOn`,
  snapshotted in schema 3 and not digested, off after migration), `Packages/ExperiencesRound02/ColorfallCanyons/Core/ColorfallCanyonsScenarios.swift` and the
  regenerated `Packages/ExperiencesRound02/ColorfallCanyons/scenario-manifest.json`, `Packages/ExperiencesRound02/ColorfallCanyons/Core/ColorfallCanyonsFeedbackPlan.swift` (refusal words "There is no saved
  solution to replay for this level.", "The replay is over.", "Stop the replay first."; a replayed win claims no stars),
  with `Packages/ExperiencesRound02/ColorfallCanyons/CoreTests/ColorfallCanyonsExperienceCoreTests.swift` updates (schema 3, migrations 1 → 3 and 2 → 3, recording,
  replay rules and codes); `--name host-2`
- [ ] T-R02G0507-004 [P] [US1] [US2] Create `Packages/ExperiencesRound02/ColorfallCanyons/CoreTests/ColorfallCanyonsPersistenceTests.swift` (agent B: 500 seeded reachable
  states round-trip with equal digests, the sound choice included and never digested; schema 1 and 2 payloads of 100 seeded states migrate and restore with progress
  kept; 200 seeded saves: honest results survive, edited ones are dropped and counted; FR-R02G0507-005: the same save
  restores to an equal digest twice and the daily level depends only on the date given); `--name host-3`

## Phase 4: Panel and simulator proof

- [ ] T-R02G0507-005 [US3] Edit `Packages/ExperiencesRound02/ColorfallCanyons/Experience/ColorfallCanyonsPresenter.swift` and `Packages/ExperiencesRound02/ColorfallCanyons/Experience/ColorfallCanyonsControls.swift`
  (Replay for a verified solved level, Step and Stop with labels and values, the replay position; the Sound toggle sends
  `settings.sound` and the presenter applies the restored `soundOn` when the experience opens; the dropped results
  announced once: "n saved results could not be checked and were removed.") and create
  `Packages/ExperiencesRound02/ColorfallCanyons/ExperienceTests/ColorfallCanyonsReplayTests.swift` (agent C: replay through the port reproduces the fingerprints action
  by action and ends won; other actions refused during replay; progress unchanged; the dropped announcement once); the
  stored schema examples of the app registry come with the in-app integration feature R02-G05-09, as in feature 337;
  `--name sim-27 -- python3 scripts/xcodebuild_package.py --package
  Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination sim-27.2 --action test`

## Phase 5: Regression, documentation and close

- [ ] T-R02G0507-006 Docs: `docs/architecture/colorfall-canyons.md` (persistence and replay),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`
- [ ] T-R02G0507-007 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`, `--name app-unit`
- [ ] T-R02G0507-008 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G0507-009 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G0507-010 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G0507-011 {device} After ImplementationLock-100, on D1, D2 and D3: a save survives a real termination and
  restores to the same level, carved cells, valves, fluid, actions and stars. Not run before the lock.
- [ ] T-R02G0507-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → 002 (agent A) → 003 (lead) → {004 (agent B), 005 (lead; agent C writes the simulator tests)} → 006 … 010, 012.
011 is a {device} task outside this campaign. Shared files (adapter, scenarios, feedback plan, presenter, controls,
docs) stay with the lead. MVP: Story 2.
