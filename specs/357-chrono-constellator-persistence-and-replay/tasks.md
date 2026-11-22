# Tasks: R02-G06-07 — Chrono Constellator: persistence and replay

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G06-07 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G06-07 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_357;
tests stay short (< 10 s each). No {owner} tasks; one {device} task; no GLSL change.

## Phase 1: Setup

- [ ] T-R02G0607-001 Baselines: `--name baseline-round02`, `--name baseline-host`, `--name baseline-timing`

## Phase 2: Story 2 — reconcilable scores (P1) 🎯

- [ ] T-R02G0607-002 [P] [US2] Edit `Packages/ExperiencesRound02/ChronoConstellator/Core/ChronoConstellatorProgress.swift` (Result gains "trace:
  [ChronoConstellatorAction]" and "verified: Bool"; `record(level:edits:smallest:mode:trace:)` stores a verified result,
  replacing only when better (ties keep the earlier trace); `drop(level:)`; encoding keeps old payloads decodable
  (missing trace = empty, missing verified = false); mode "replay(level:)" that awards no stars and opens nothing) and
  create `Packages/ExperiencesRound02/ChronoConstellator/Core/ChronoConstellatorReconciliation.swift` ("netTrace(records): the actions of phase, hold, release,
  step and rewind records, each undo removing the last net action and each redo restoring it"; "reconcile(progress) →
  (progress, dropped): a result with a trace is kept only when a fresh play of its certified level (campaign budget)
  replays the trace to a win with exactly bestEdits edits in use and its stars; a trace over 64 actions or with an
  illegal action never verifies; untraced results kept unverified; frontier unchanged") with
  `Packages/ExperiencesRound02/ChronoConstellator/CoreTests/ChronoConstellatorReconciliationTests.swift` (agent A: every certified level's witness as a trace
  verifies; edited stars, edits, a trace step and an illegal or overlong trace are dropped and counted; untraced kept;
  frontier unchanged; netTrace over undo/redo sequences); `--name host`

## Phase 3: Stories 1 and 3 — save, migrate, replay (P1, P2)

- [ ] T-R02G0607-003 [US1] [US2] [US3] Edit `Packages/ExperiencesRound02/ChronoConstellator/Core/ChronoConstellatorExperienceCore.swift` (schema 3, migration 2 → 3
  "results with an empty trace and verified false, sound off", digest v3; a campaign or daily win records the winning
  net trace; restore reconciles and exposes `reconciliationDropped` (not digested); actions "replay.start [1…100]"
  (`r02-g06.no-replay` without a verified traced result), "replay.step" (`r02-g06.replay-end` after the last or once
  ended), "replay.stop" (campaign at that level, the frontier when it is not open); every other play action in replay
  refused with `r02-g06.replay` except `tutorial.dismiss` and `settings.sound`; replay never records; the tutorial is
  done in replay; "settings.sound [0 … 1]" sets `soundOn`, snapshotted in schema 3 and not digested, off after
  migration), `Packages/ExperiencesRound02/ChronoConstellator/Core/ChronoConstellatorScenarios.swift` and the regenerated `Packages/ExperiencesRound02/ChronoConstellator/scenario-manifest.json`,
  `Packages/ExperiencesRound02/ChronoConstellator/Core/ChronoConstellatorFeedbackPlan.swift` (refusal words "There is no saved solution to replay for this level.",
  "The replay is over.", "Stop the replay first."; a replay step announced like the action; a replayed win claims no
  stars) with `Packages/ExperiencesRound02/ChronoConstellator/CoreTests/ChronoConstellatorExperienceCoreTests.swift` updates (schema 3, migrations 1 → 3 and 2 → 3,
  reconciliation on restore, replay rules and codes, sound setting); `--name host-2`
- [ ] T-R02G0607-004 [P] [US1] [US2] Create `Packages/ExperiencesRound02/ChronoConstellator/CoreTests/ChronoConstellatorPersistenceTests.swift` (agent B: 500 seeded
  states round-trip with equal digests, the sound choice included and never digested; schema 1 and 2 payloads of 100
  seeded states migrate and restore with progress kept; 200 seeded saves: honest results survive, edited ones are
  dropped and counted; FR-R02G0607-005: the same save restores to an equal digest twice and the daily level depends only
  on the date given); `--name host-3`

## Phase 4: Panel and simulator proof

- [ ] T-R02G0607-005 [US3] Edit `Packages/ExperiencesRound02/ChronoConstellator/Experience/ChronoConstellatorPresenter.swift` and
  `Packages/ExperiencesRound02/ChronoConstellator/Experience/ChronoConstellatorControls.swift` (Replay for a verified solved level, Step and Stop with labels and
  values, the replay position; the Sound toggle sends `settings.sound` and the presenter applies the restored
  `soundOn` when the experience opens; the dropped results announced once: "n saved results could not be checked and
  were removed.") and create `Packages/ExperiencesRound02/ChronoConstellator/ExperienceTests/ChronoConstellatorReplayTests.swift` (agent C: replay through the port
  reproduces the fingerprints action by action and ends won; other actions refused during replay; progress unchanged;
  the dropped announcement once; the saved sound choice applied on open); the stored schema examples of the app
  registry come with R02-G06-09; `--name sim-27 -- python3 scripts/xcodebuild_package.py --package
  Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing
  ChronoConstellatorExperienceTests`

## Phase 5: Regression, documentation and close

- [ ] T-R02G0607-006 Docs: `docs/architecture/chrono-constellator.md` (persistence and replay),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`
- [ ] T-R02G0607-007 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`, `--name app-unit`
- [ ] T-R02G0607-008 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G0607-009 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G0607-010 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G0607-011 {device} After ImplementationLock-100: a save survives a real app termination on D1/D2/D3.
- [ ] T-R02G0607-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → 002 (agent A) → {003 (lead), 004 (agent B, against the contract)} → 005 (lead; agent C writes the simulator tests)
→ 006 … 010, 012. 011 stays open until device testing. Shared files (adapter, scenarios, feedback, presenter, panel,
docs) stay with the lead. MVP: Stories 1 and 2.
