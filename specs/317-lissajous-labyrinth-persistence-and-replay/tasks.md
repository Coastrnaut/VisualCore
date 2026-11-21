# Tasks: R02-G02-07 — Lissajous Labyrinth: persistence and replay

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G02-07 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G02-07 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_317;
tests stay short (< 10 s each).

## Phase 1: Setup

- [X] T-R02G0207-001 Baselines: `--name baseline-round02`, `--name baseline-host`, `--name baseline-timing` — Verified 2026-11-21: 2026-11-21 baseline-round02, baseline-host, baseline-timing exit 0

## Phase 2: Story 2 — reconcilable scores (P1) 🎯

- [X] T-R02G0207-002 [P] [US2] Edit `Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthProgress.swift` (Result gains "trace: [LissajousLabyrinthAction]" — Verified 2026-11-21: 2026-11-21 host exit 0: LissajousLabyrinthReconciliationTests (every certified solution as a trace verifies, reconcile drops none; fewer actions replace, ties keep; traces encode and schema-2 entries decode unverified; overlong and out-of-range traces refused; edited stars, actions, a trace step, an illegal and a losing trace dropped and counted; untraced kept, frontier as saved; replay mode round trip) and LissajousLabyrinthProgressTests
  and "verified: Bool"; `record(level:actions:shortest:opensNext:trace:)` stores a verified result, replacing only with
  fewer actions; `drop(level:)`; encoding keeps old payloads decodable (missing trace → empty, verified false); mode
  case "replay(level:)") and create `Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthReconciliation.swift` ("a result with a trace is kept
  only when a fresh play of its certified level replays the trace to a win in exactly bestActions with its stars;
  untraced results kept unverified; frontier unchanged") with `Packages/ExperiencesRound02/LissajousLabyrinth/CoreTests/LissajousLabyrinthReconciliationTests.swift`
  (every certified level's solution as a trace verifies; edited stars, actions, a trace step and an illegal trace are
  dropped and counted; untraced kept; frontier unchanged); `--name host`

## Phase 3: Stories 1 and 3 — save, migrate, replay (P1, P2)

- [X] T-R02G0207-003 [US1] [US2] [US3] Edit `Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthExperienceCore.swift` (schema 3, migration — Verified 2026-11-21: 2026-11-21 host-2 exit 0: LissajousLabyrinthExperienceCoreTests 16/16 (schema 3, digest v3, thirteen controls; a win records its trace and replay plays it action by action without changing progress, other actions refused during replay, replay-end and stop; schema 1 and 2 migrate to 3, untraced results kept unverified, an edited result dropped and counted with the frontier as saved, an honest save restores to the same digest) and LissajousLabyrinthScenariosTests with the regenerated manifest (replay refusals)
  2 → 3 "results with an empty trace and verified false", digest v3; a campaign or daily win records the winning trace
  (the play's net changes); restore reconciles and exposes `reconciliationDropped` (not digested); actions
  "replay.start [1…100]" (`r02-g02.no-replay` without a verified traced result), "replay.step" (`r02-g02.replay-end`
  after the last or once ended), "replay.stop" (campaign at that level, the frontier when it is not open); every other
  play action in replay refused with `r02-g02.replay` except `tutorial.dismiss`; replay never records),
  `Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthScenarios.swift` and the regenerated `Packages/ExperiencesRound02/LissajousLabyrinth/scenario-manifest.json`, with
  `Packages/ExperiencesRound02/LissajousLabyrinth/CoreTests/LissajousLabyrinthExperienceCoreTests.swift` updates (schema 3, migrations 1 → 3 and 2 → 3, recording,
  replay rules and codes); `--name host-2`
- [X] T-R02G0207-004 [P] [US1] [US2] Create `Packages/ExperiencesRound02/LissajousLabyrinth/CoreTests/LissajousLabyrinthPersistenceTests.swift` (agent B: 500 seeded — Verified 2026-11-21: 2026-11-21 host-3 exit 0: LissajousLabyrinthPersistenceTests 13/13 (500 seeded reachable states incl. traced wins, daily, practice and replay round-trip with equal digests and identical payloads; 100 schema-1 and 100 schema-2 payloads migrate with progress kept, schema-2 results unverified; 200 seeded saves: 250 honest results survive and 133 edited ones (stars, bestActions, a trace step, a removed action, a false verified claim) are dropped and counted exactly, frontier as saved)
  reachable states round-trip with equal digests; schema 1 and 2 payloads of 100 seeded states migrate and restore with
  progress kept; 200 seeded saves: honest results survive, edited ones are dropped and counted); `--name host-3`

## Phase 4: Panel and simulator proof

- [X] T-R02G0207-005 [US3] Edit `Packages/ExperiencesRound02/LissajousLabyrinth/Experience/LissajousLabyrinthPresenter.swift` and — Verified 2026-11-21: 2026-11-21 sim-27 exit 0 on sim-27.2: LissajousLabyrinthReplayTests 3/3 (replay reproduces the win's fingerprints action by action, ends won, progress unchanged, other actions refused, replay-end, stop returns to campaign, retry during replay restarts it; replay of an unsolved level refused; dropped results announced once, singular and plural) and all 49 Lissajous experience tests. Fixed on the way: specific words for the three replay refusals (host test added), a replay win claims no stars, replay is not offered while one runs
  `Packages/ExperiencesRound02/LissajousLabyrinth/Experience/LissajousLabyrinthControls.swift` (Replay for a verified solved level, Step and Stop with labels and
  values, the replay position; the dropped results announced once: "n saved results could not be checked and were
  removed.") and create `Packages/ExperiencesRound02/LissajousLabyrinth/ExperienceTests/LissajousLabyrinthReplayTests.swift` (agent C: replay through the port
  reproduces the fingerprints action by action and ends won; other actions refused during replay; progress unchanged;
  the dropped announcement once); `--name sim-27 -- python3 scripts/xcodebuild_package.py --package
  Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination sim-27.2 --action test`

## Phase 5: Regression, documentation and close

- [ ] T-R02G0207-006 Docs: `docs/architecture/lissajous-labyrinth.md` (persistence and replay),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`; `--name audits -- python3
  scripts/verify_experiences.py --audits --only r02-g02.lissajous-labyrinth`
- [ ] T-R02G0207-007 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`, `--name app-unit`
- [ ] T-R02G0207-008 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G0207-009 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G0207-010 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G0207-011 {device} After ImplementationLock-100, on D1, D2 and D3: a save survives a real termination and
  restores to the same level, actions and stars. Not run before the lock.
- [ ] T-R02G0207-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → 002 (agent A) → 003 (lead) → {004 (agent B), 005 (lead; agent C writes the simulator tests)} → 006 … 010, 012.
011 is a {device} task outside this campaign. Shared files (adapter, scenarios, presenter, controls, docs) stay with
the lead. MVP: Story 2.
