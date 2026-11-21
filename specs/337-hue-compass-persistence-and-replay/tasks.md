# Tasks: R02-G04-07 — Hue Compass: persistence and replay

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G04-07 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G04-07 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_337;
tests stay short (< 10 s each). {device} items are D1–D3 observations after ImplementationLock-100.

## Phase 1: Setup

- [X] T-R02G0407-001 Baselines: `--name baseline-round02`, `--name baseline-host`, `--name baseline-timing` — Verified 2026-11-21: 2026-11-21 baseline-round02, baseline-host, baseline-timing exit 0

## Phase 2: Story 2 — reconcilable scores (P1) 🎯

- [X] T-R02G0407-002 [P] [US2] Edit `Packages/ExperiencesRound02/HueCompass/Core/HueCompassProgress.swift` (Result gains "trace: [HueCompassAction]" and — Verified 2026-11-21: 2026-11-21 host exit 0: HueCompassReconciliationTests 10/10 (every certified witness trace verifies; edited stars, units, a changed selection band, illegal and over-long traces dropped and counted; untraced kept; frontier unchanged) and HueCompassProgressTests
  "verified: Bool"; `record(level:units:smallest:mode:trace:)` stores a verified result, replacing only with fewer
  units; `drop(level:)`; encoding keeps old payloads decodable (missing trace → empty, verified false); mode case
  "replay(level:)" that awards no stars and opens nothing) and create `Packages/ExperiencesRound02/HueCompass/Core/HueCompassReconciliation.swift` ("a
  result with a trace is kept only when a fresh play of its certified level (campaign allowance) replays the trace to a
  win having spent exactly bestUnits with its stars; a trace over the bound of research R6 or with an illegal action
  never verifies; untraced results kept unverified; frontier unchanged") with
  `Packages/ExperiencesRound02/HueCompass/CoreTests/HueCompassReconciliationTests.swift` (every certified level's solution as a trace verifies; edited
  stars, units, a trace step and an illegal trace are dropped and counted; untraced kept; frontier unchanged);
  `--name host`

## Phase 3: Stories 1 and 3 — save, migrate, replay (P1, P2)

- [X] T-R02G0407-003 [US1] [US2] [US3] Edit `Packages/ExperiencesRound02/HueCompass/Core/HueCompassExperienceCore.swift` (schema 3, migration 2 → 3 — Verified 2026-11-21: 2026-11-21 host-2 exit 0: HueCompassExperienceCoreTests (schema 3, migrations 1 -> 3 and 2 -> 3, net-action traces with an undone turn left out, replay rules and codes, reconcile on restore), HueCompassScenariosTests (manifest regenerated, 25 rejection entries) and HueCompassFeedbackPlanTests (replay refusal words)
  "results with an empty trace and verified false", digest v3; a campaign or daily win records the winning trace (the
  play's net actions: turns, probes and the selection, an undone turn left out); restore reconciles and exposes
  `reconciliationDropped` (not digested); actions "replay.start [1…100]" (`r02-g04.no-replay` without a verified
  traced result), "replay.step" (`r02-g04.replay-end` after the last or once ended), "replay.stop" (campaign at that
  level, the frontier when it is not open); every other play action in replay refused with `r02-g04.replay` except
  `tutorial.dismiss`; replay never records; the tutorial is done in replay), `Packages/ExperiencesRound02/HueCompass/Core/HueCompassScenarios.swift` and the
  regenerated `Packages/ExperiencesRound02/HueCompass/scenario-manifest.json`, `Packages/ExperiencesRound02/HueCompass/Core/HueCompassFeedbackPlan.swift` (refusal words "There is no saved
  solution to replay for this level.", "The replay is over.", "Stop the replay first."; a replayed win claims no stars),
  with `Packages/ExperiencesRound02/HueCompass/CoreTests/HueCompassExperienceCoreTests.swift` updates (schema 3, migrations 1 → 3 and 2 → 3, recording,
  replay rules and codes); `--name host-2`
- [X] T-R02G0407-004 [P] [US1] [US2] Create `Packages/ExperiencesRound02/HueCompass/CoreTests/HueCompassPersistenceTests.swift` (agent B: 500 seeded reachable — Verified 2026-11-21: 2026-11-21 host-3 exit 0: HueCompassPersistenceTests 15/15 (500 round trips, 100 schema-1 and 100 schema-2 migrations, 200 saves reconciled exactly, determinism)
  states round-trip with equal digests; schema 1 and 2 payloads of 100 seeded states migrate and restore with progress
  kept; 200 seeded saves: honest results survive, edited ones are dropped and counted; FR-R02G0407-005: the same save
  restores to an equal digest twice and the daily level depends only on the date given); `--name host-3`

## Phase 4: Panel and simulator proof

- [X] T-R02G0407-005 [US3] Edit `Packages/ExperiencesRound02/HueCompass/Experience/HueCompassPresenter.swift` and `Packages/ExperiencesRound02/HueCompass/Experience/HueCompassControls.swift` — Verified 2026-11-21: 2026-11-21 sim-27 exit 0 on sim-27.2: HueCompassReplayTests (replay reproduces the win action by action; other actions refused with words; past the end refused; stop returns to campaign; no saved solution refused; dropped result announced once) and every Hue Compass experience test
  (Replay for a verified solved level, Step and Stop with labels and values, the replay position; the dropped results
  announced once: "n saved results could not be checked and were removed.") and create
  `Packages/ExperiencesRound02/HueCompass/ExperienceTests/HueCompassReplayTests.swift` (agent C: replay through the port reproduces the fingerprints action
  by action and ends won; other actions refused during replay; progress unchanged; the dropped announcement once); the
  stored schema examples of the app registry come with the in-app integration feature R02-G04-09, as in feature 329;
  `--name sim-27 -- python3 scripts/xcodebuild_package.py --package
  Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination sim-27.2 --action test`

## Phase 5: Regression, documentation and close

- [X] T-R02G0407-006 Docs: `docs/architecture/hue-compass.md` (persistence and replay), — Verified 2026-11-21: 2026-11-21 round02-host exit 0; architecture (persistence and replay), package README and testing doc (net-action traces, independent edits) updated
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`
- [X] T-R02G0407-007 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-21: 2026-11-21 rendering-27, rendering-26, experiences, host-full, app-unit exit 0
  `--name host-full`, `--name app-unit`
- [X] T-R02G0407-008 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-21: 2026-11-21 reference-1 exit 0
- [X] T-R02G0407-009 Reference regression chunk 2 (`--name reference-2`) — Verified 2026-11-21: 2026-11-21 reference-2 exit 0: 7 of 7 with chunk 1
- [X] T-R02G0407-010 Script tests, run alone (`--name script-tests`) — Verified 2026-11-21: 2026-11-21 script-tests exit 0, run alone
- [ ] T-R02G0407-011 {device} After ImplementationLock-100, on D1, D2 and D3: a save survives a real termination and
  restores to the same level, bearing, clues, units and stars. Not run before the lock.
- [X] T-R02G0407-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record — Verified 2026-11-21: 2026-11-21 converge round 1 converged (nothing appended); sealed 16 passing; recorded R02-G04-07 pass

## Dependencies and parallel work

001 → 002 (agent A) → 003 (lead) → {004 (agent B), 005 (lead; agent C writes the simulator tests)} → 006 … 010, 012.
011 is a {device} task outside this campaign. Shared files (adapter, scenarios, feedback plan, presenter, controls,
docs) stay with the lead. MVP: Story 2.
