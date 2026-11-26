# Tasks: R02-G19-07 — Microscopic Aurora: persistence and replay

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G19-07 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G19-07 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_487;
tests stay short (< 10 s each). No {owner} tasks; one {device} task; no GLSL change. Model: feature 477's tasks, with
its lesson taken into the first pass (the scenario manifest digests the progress, now written with traces, so it is
regenerated in T-003 with `UPDATE_SCENARIO_MANIFEST=1`) and round02-host in five chunks (Microscopic Aurora in 3e).

## Phase 1: Setup

- [X] T-R02G1907-001 Baselines on the committed tree after R02-G19-06 is recorded: `--name baseline-host`, `--name — Verified 2026-11-26: baselines exit 0 on the committed tree after the R02-G19-06 record (host, timing, round02-1, -2, -3c, -3e, -3f); rendering baseline is R02-G19-06's rendering runs
  baseline-timing`, `--name baseline-round02-1`, `-2`, `-3c`, `-3e`, `-3f` (the five round-two filters)

## Phase 2: Story 2 — reconcilable scores (P1) 🎯

- [X] T-R02G1907-002 [P] [US2] Edit `Packages/ExperiencesRound02/MicroscopicAurora/Core/MicroscopicAuroraProgress.swift` — Verified 2026-11-26: host-1 exit 0: results carry traces (placements and removals then the play) and verified; traced record keeps the better result; drop keeps the frontier; replay mode Codable; net trace from records with undo/redo; reconciliation keeps honest results and drops edited stars, actions spent, steps and over-long traces (41 tests)
  (Result gains "trace: [MicroscopicAuroraAction]" (effective `.place(slot:well:)` and `.remove(slot:)` actions, then
  `.play`) and "verified: Bool"; `record(level:actionsSpent:certified:mode:trace:)` stores a verified result, replacing
  only when better (ties keep the earlier trace); `drop(level:)`; encoding keeps old payloads decodable (missing trace =
  empty, missing verified = false); mode "replay(level:)" that awards no stars and opens nothing) and create
  `Packages/ExperiencesRound02/MicroscopicAurora/Core/MicroscopicAuroraReconciliation.swift` ("netTrace(records): the
  actions of the place, remove and play records, each undo removing the last effective action and each redo restoring
  it"; "reconcile(progress) → (progress, dropped): a result with a trace is kept only when a fresh play of its certified
  level (campaign budget) replays the trace to a win, the placements and removals the trace spends are at most
  actionsSpent and its stars equal the stars rule for actionsSpent and the certified placement or removal count; a trace
  over 64 actions, with an action the kernel refuses, an action after the play or no final play never verifies; untraced
  results kept unverified; frontier unchanged") with
  `Packages/ExperiencesRound02/MicroscopicAurora/CoreTests/MicroscopicAuroraReconciliationTests.swift` (agent A: every
  certified level's witness placements and removals plus the play as a trace verify; edited stars, actions spent below
  the trace's placements and removals, a trace step, and an illegal, failing, play-less or overlong trace are dropped
  and counted; untraced kept; frontier unchanged; netTrace over undo and redo sequences, a failed play undone included);
  `--name host-1`

## Phase 3: Stories 1 and 3 — save, migrate, replay (P1, P2)

- [X] T-R02G1907-003 [US1] [US2] [US3] Edit — Verified 2026-11-26: host-2 exit 0 (MicroscopicAurora filter): adapter schema 3 and digest v3, sixteen controls, wins store verified traces, migrations 1 -> 2 -> 3, reconciliation on restore with reconciliationDropped, replay.start/step/stop with no-replay, replay-end and replay codes, settings.sound; scenarios with the new rejections and the regenerated manifest; ExperienceCore and ProgressionCore tests updated (replay rules and the saved-replay prefix rule are exercised in MicroscopicAuroraReplayCatalogTests, T-005)
  `Packages/ExperiencesRound02/MicroscopicAurora/Core/MicroscopicAuroraExperienceCore.swift` (schema 3, migration 2 → 3
  "results with an empty trace and verified false, sound off", digest v3; a campaign or daily win records the winning
  effective-action trace; restore reconciles and exposes `reconciliationDropped` (not digested); actions "replay.start
  [1…100]" (`r02-g19.no-replay` without a verified traced result), "replay.step" (`r02-g19.replay-end` after the last or
  once ended), "replay.stop" (campaign at that level, the frontier when it is not open); every other play action in
  replay refused with `r02-g19.replay` except `tutorial.dismiss` and `clock.show` (presentation) and `settings.sound`;
  replay never records; the tutorial is done in replay; a restored replay whose records are not exactly the first
  actions of its level's verified trace (placements and removals then the play, in order, no undo or redo) is refused as
  `damaged`; "settings.sound [0 … 1]" sets `soundOn`, snapshotted in schema 3 and not digested, off after migration),
  `Packages/ExperiencesRound02/MicroscopicAurora/Core/MicroscopicAuroraScenarios.swift` and the regenerated
  `Packages/ExperiencesRound02/MicroscopicAurora/scenario-manifest.json`,
  `Packages/ExperiencesRound02/MicroscopicAurora/Core/MicroscopicAuroraFeedbackPlan.swift` (refusal words "There is no
  saved solution to replay for this level.", "The replay is over.", "Stop the replay first."; a replay step announced
  like the action it applies; a replayed win claims no stars) with
  `Packages/ExperiencesRound02/MicroscopicAurora/CoreTests/MicroscopicAuroraExperienceCoreTests.swift` updates (schema
  3, migrations 1 → 3 and 2 → 3, reconciliation on restore, replay rules and codes, a replay saved mid-way restores
  while a changed, reordered or undo-carrying replay is refused `damaged`, sound setting); `--name host-2`
- [X] T-R02G1907-004 [P] [US1] [US2] Create — Verified 2026-11-26: host-3 exit 0: 500 seeded round trips with equal digests (sound choice in the payload, never the digest), schema 1 and 2 migrations for 100 states each, 200 saves with honest results kept and edited ones dropped and counted, deterministic seeds and dates
  `Packages/ExperiencesRound02/MicroscopicAurora/CoreTests/MicroscopicAuroraPersistenceTests.swift` (agent B: 500 seeded
  states round-trip with equal digests, the sound choice included and never digested; schema 1 and 2 payloads of 100
  seeded states migrate and restore with progress kept; 200 seeded saves: honest results survive, edited ones are
  dropped and counted; FR-R02G1907-005: the same save restores to an equal digest twice and the daily level depends only
  on the date given); `--name host-3`
- [X] T-R02G1907-005 [P] [US3] Create — Verified 2026-11-26: host-4 exit 0: all 100 certified levels won through the adapter, their traces replayed step by step to the stored fingerprints and a win, progress unchanged; no-replay, replay-end and replay refusals; a replay saved mid-way restores while changed, reordered, undo-carrying or overlong records are refused damaged
  `Packages/ExperiencesRound02/MicroscopicAurora/CoreTests/MicroscopicAuroraReplayCatalogTests.swift`: for each of the
  100 certified levels (10 groups of 10, each under 10 s) win the level in campaign through the adapter with its
  certified placements and removals and the play, then `replay.start [level]` and `replay.step` to the end, checking
  each step's play fingerprint against the witness file's recorded fingerprints (as `MicroscopicAuroraWitnessTests`
  reads `docs/games/microscopic-aurora/levels/NNN.witness.json`), the replay ending won and the progress unchanged;
  `--name host-4` (SC-R02G1907-004)

## Phase 4: Panel and simulator proof

- [X] T-R02G1907-006 [US3] Edit — Verified 2026-11-26: presenter: replay availability and position, startReplay/stepReplay/stopReplay, saveSound through settings.sound, restored sound applied on open, dropped results announced once; panel: Replay best solution, position, Step, Stop with labels and values, Sound saved; MicroscopicAuroraReplayTests (4), identity (16 controls, schema 3) and accessibility control names updated; sim-27 exit 0 (62 tests)
  `Packages/ExperiencesRound02/MicroscopicAurora/Experience/MicroscopicAuroraPresenter.swift` and
  `Packages/ExperiencesRound02/MicroscopicAurora/Experience/MicroscopicAuroraControls.swift` (Replay for a verified
  solved level, Step and Stop with labels and values, the replay position; the Sound toggle sends `settings.sound` and
  the presenter applies the restored `soundOn` when the experience opens; the dropped results announced once: "n saved
  results could not be checked and were removed.") and create
  `Packages/ExperiencesRound02/MicroscopicAurora/ExperienceTests/MicroscopicAuroraReplayTests.swift` (agent C: replay
  through the port reproduces the fingerprints action by action and ends won; other actions refused during replay;
  progress unchanged; the dropped announcement once; the saved sound choice applied on open); the stored schema examples
  of the app registry come with R02-G19-09; `--name sim-27 -- python3 scripts/xcodebuild_package.py --package
  Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing
  MicroscopicAuroraExperienceTests`

## Phase 5: Regression, documentation and close

- [X] T-R02G1907-007 Docs: `docs/architecture/microscopic-aurora.md` (persistence and replay), — Verified 2026-11-26: docs updated (architecture persistence and replay, round-two README, automatedtesting); round02-host-1, -2, -3c, -3e, -3f exit 0
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host-1`, `-2`, `-3c`, `-3e`,
  `-3f` (the five round-two filters)
- [X] T-R02G1907-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, `--name — Verified 2026-11-26: rendering-27, rendering-26, experiences, host-full, app-unit exit 0
  host-full`, `--name app-unit`
- [X] T-R02G1907-009 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-26: reference-1 exit 0
- [X] T-R02G1907-010 Reference regression chunk 2 (`--name reference-2`) — Verified 2026-11-26: reference-2 exit 0 (7 of 7 with chunk 1)
- [X] T-R02G1907-011 Script tests, run alone (`--name script-tests`) — Verified 2026-11-26: script-tests exit 0, run alone
- [ ] T-R02G1907-012 {device} After ImplementationLock-100: a save survives a real app termination on D1/D2/D3.
- [X] T-R02G1907-013 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record; — Verified 2026-11-26: /speckit-converge converged (nothing appended); README row R02-G19-07 pass, 187 round-two features, gate list updated
  README row and gate list updated

## Dependencies and parallel work

001 → 002 (agent A) → {003 (lead), 004 (agent B, against the contract)} → 005 (after 003) → 006 (lead; agent C writes
the simulator tests) → 007 … 011, 013. 012 stays open until device testing. Agent A may start in an isolated copy before
001 (its files are the progress and a new reconciliation file). Shared files (adapter, scenarios, feedback, presenter,
panel, docs) stay with the lead. MVP: Stories 1 and 2. Requirement coverage: FR-001/002/005/007 → 003, 004; FR-003 →
002, 003, 004; FR-004 → 003, 005, 006; FR-006 → 007 … 011.
