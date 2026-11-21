# Tasks: R02-G03-07 — Wave Knot Keeper: persistence and replay

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G03-07 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G03-07 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_327;
tests stay short (< 10 s each).

## Phase 1: Setup

- [X] T-R02G0307-001 Baselines: `--name baseline-round02`, `--name baseline-host`, `--name baseline-timing` — Verified 2026-11-21: 2026-11-21 baseline-round02, baseline-host, baseline-timing exit 0

## Phase 2: Story 2 — reconcilable scores (P1) 🎯

- [X] T-R02G0307-002 [P] [US2] Edit `Packages/ExperiencesRound02/WaveKnotKeeper/Core/WaveKnotKeeperProgress.swift` (Result gains "trace: [WaveKnotKeeperMove]" — Verified 2026-11-21: 2026-11-21 host exit 0: WaveKnotKeeperReconciliationTests 11/11 (every certified solution verifies; edited stars, moves, trace step, illegal and short traces dropped and counted; untraced kept; frontier unchanged; replace only with fewer moves) and WaveKnotKeeperProgressTests
  and "verified: Bool"; `record(level:moves:shortest:opensNext:trace:)` stores a verified result, replacing only with
  fewer moves; `drop(level:)`; encoding keeps old payloads decodable (missing trace → empty, verified false); mode
  case "replay(level:)") and create `Packages/ExperiencesRound02/WaveKnotKeeper/Core/WaveKnotKeeperReconciliation.swift` ("a result with a trace is kept
  only when a fresh play of its certified level replays the trace to a win in exactly bestMoves with its stars;
  untraced results kept unverified; frontier unchanged") with `Packages/ExperiencesRound02/WaveKnotKeeper/CoreTests/WaveKnotKeeperReconciliationTests.swift`
  (every certified level's solution as a trace verifies; edited stars, moves, a trace step and an illegal trace are
  dropped and counted; untraced kept; frontier unchanged); `--name host`

## Phase 3: Stories 1 and 3 — save, migrate, replay (P1, P2)

- [X] T-R02G0307-003 [US1] [US2] [US3] Edit `Packages/ExperiencesRound02/WaveKnotKeeper/Core/WaveKnotKeeperExperienceCore.swift` (schema 3, migration — Verified 2026-11-21: 2026-11-21 host-2 exit 0: adapter schema 3, migration 2 -> 3, traces recorded, restore reconciles, replay start/step/stop and codes; scenarios and manifest regenerated; feedback plan replay words
  2 → 3 "results with an empty trace and verified false", digest v3; a campaign or daily win records the winning trace
  (the play's net moves); restore reconciles and exposes `reconciliationDropped` (not digested); actions
  "replay.start [1…100]" (`r02-g03.no-replay` without a verified traced result), "replay.step" (`r02-g03.replay-end`
  after the last or once ended), "replay.stop" (campaign at that level, the frontier when it is not open); every other
  play action in replay refused with `r02-g03.replay` except `tutorial.dismiss` and `point.select`; replay never records),
  `Packages/ExperiencesRound02/WaveKnotKeeper/Core/WaveKnotKeeperScenarios.swift` and the regenerated `Packages/ExperiencesRound02/WaveKnotKeeper/scenario-manifest.json`, with
  `Packages/ExperiencesRound02/WaveKnotKeeper/CoreTests/WaveKnotKeeperExperienceCoreTests.swift` updates (schema 3, migrations 1 → 3 and 2 → 3, recording,
  replay rules and codes); `--name host-2`
- [X] T-R02G0307-004 [P] [US1] [US2] Create `Packages/ExperiencesRound02/WaveKnotKeeper/CoreTests/WaveKnotKeeperPersistenceTests.swift` (agent B: 500 seeded — Verified 2026-11-21: 2026-11-21 host-3 exit 0: WaveKnotKeeperPersistenceTests 13/13 (500 round trips, 100 schema-1 and schema-2 migrations, 200 saves with edited results dropped and counted)
  reachable states round-trip with equal digests; schema 1 and 2 payloads of 100 seeded states migrate and restore with
  progress kept; 200 seeded saves: honest results survive, edited ones are dropped and counted); `--name host-3`

## Phase 4: Panel and simulator proof

- [X] T-R02G0307-005 [US3] Edit `Packages/ExperiencesRound02/WaveKnotKeeper/Experience/WaveKnotKeeperPresenter.swift` and — Verified 2026-11-21: 2026-11-21 sim-27 exit 0 on sim-27.2: WaveKnotKeeperReplayTests 5/5 (replay reproduces the win move by move with announcements and progress unchanged; other actions refused in words; retry restarts the replay; no replay without a verified result; dropped results announced once) and all Wave Knot Keeper experience tests
  `Packages/ExperiencesRound02/WaveKnotKeeper/Experience/WaveKnotKeeperControls.swift` (Replay for a verified solved level, Step and Stop with labels and
  values, the replay position; the dropped results announced once: "n saved results could not be checked and were
  removed.") and create `Packages/ExperiencesRound02/WaveKnotKeeper/ExperienceTests/WaveKnotKeeperReplayTests.swift` (agent C: replay through the port
  reproduces the fingerprints move by move and ends won; other actions refused during replay; progress unchanged;
  the dropped announcement once); `--name sim-27 -- python3 scripts/xcodebuild_package.py --package
  Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination sim-27.2 --action test`

## Phase 5: Regression, documentation and close

- [ ] T-R02G0307-006 Docs: `docs/architecture/wave-knot-keeper.md` (persistence and replay),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`; `--name audits -- python3
  scripts/verify_experiences.py --audits --only r02-g03.wave-knot-keeper`
- [ ] T-R02G0307-007 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`, `--name app-unit`
- [ ] T-R02G0307-008 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G0307-009 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G0307-010 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G0307-011 {device} After ImplementationLock-100, on D1, D2 and D3: a save survives a real termination and
  restores to the same level, rope, moves and stars. Not run before the lock.
- [ ] T-R02G0307-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → 002 (agent A) → 003 (lead) → {004 (agent B), 005 (lead; agent C writes the simulator tests)} → 006 … 010, 012.
011 is a {device} task outside this campaign. Shared files (adapter, scenarios, presenter, controls, docs) stay with
the lead. MVP: Story 2.
