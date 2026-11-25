# Tasks: R02-G17-07 — Celestial Eclipse Lab: persistence and replay

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G17-07 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G17-07 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_467;
tests stay short (< 10 s each). No {owner} tasks; one {device} task; no GLSL change. Model: feature 457's tasks, with
its replay catalog proof (its convergence round) taken into the first pass and round02-host in five chunks.

## Phase 1: Setup

- [X] T-R02G1707-001 Baselines on the committed tree after R02-G17-06 is recorded: `--name baseline-host`, `--name — Verified 2026-11-25: 2026-11-25 baseline-host, baseline-timing, baseline-round02-1, -2, -3c, -3e, -3f exit 0 on the committed tree (.autonomy/migration/checks/R02-G17-07.baseline-*.json)
  baseline-timing`, `--name baseline-round02-1`, `-2`, `-3c`, `-3e`, `-3f` (the five round-two filters)

## Phase 2: Story 2 — reconcilable scores (P1) 🎯

- [X] T-R02G1707-002 [P] [US2] Edit — Verified 2026-11-25: 2026-11-25 host-1b exit 0, 232 core tests (.autonomy/migration/checks/R02-G17-07.host-1b.json; host-1 failed only on the scenario manifest, which digests the progress now written with traces; regenerated); results carry trace and verified, replay mode, reconciliation with every certified witness trace verifying
  `Packages/ExperiencesRound02/CelestialEclipseLab/Core/CelestialEclipseLabProgress.swift` (Result gains "trace:
  [CelestialEclipseLabAction]" (effective `.phase(body, offset)` changes, then `.run`) and "verified: Bool";
  `record(level:actionsSpent:certified:mode:trace:)` stores a verified result, replacing only when better (ties keep the
  earlier trace); `drop(level:)`; encoding keeps old payloads decodable (missing trace = empty, missing verified =
  false); mode "replay(level:)" that awards no stars and opens nothing) and create
  `Packages/ExperiencesRound02/CelestialEclipseLab/Core/CelestialEclipseLabReconciliation.swift` ("netTrace(records):
  the actions of the phase and run records, each undo removing the last effective action and each redo restoring it";
  "reconcile(progress) → (progress, dropped): a result with a trace is kept only when a fresh play of its certified
  level (campaign budget) replays the trace to a win, the phase changes the trace spends are at most actionsSpent and
  its stars equal the stars rule for actionsSpent and the certified change count; a trace over 64 actions, with an
  action the kernel refuses, an action after the run or no final run never verifies; untraced results kept unverified;
  frontier unchanged") with
  `Packages/ExperiencesRound02/CelestialEclipseLab/CoreTests/CelestialEclipseLabReconciliationTests.swift` (agent A:
  every certified level's witness changes plus the run as a trace verify; edited stars, actions spent below the trace's
  changes, a trace step, and an illegal, failing, run-less or overlong trace are dropped and counted; untraced kept;
  frontier unchanged; netTrace over undo and redo sequences, a failed run undone included); `--name host-1`

## Phase 3: Stories 1 and 3 — save, migrate, replay (P1, P2)

- [X] T-R02G1707-003 [US1] [US2] [US3] Edit — Verified 2026-11-25: 2026-11-25 host-2 exit 0, 250 core tests incl. 7 replay core tests (.autonomy/migration/checks/R02-G17-07.host-2.json); schema 3 and digest v3, migration 2 → 3, traces stored on wins, reconciliation on restore, replay.start/step/stop, settings.sound, replay refusal words, scenarios and manifest regenerated
  `Packages/ExperiencesRound02/CelestialEclipseLab/Core/CelestialEclipseLabExperienceCore.swift` (schema 3, migration
  2 → 3 "results with an empty trace and verified false, sound off", digest v3; a campaign or daily win records the
  winning effective-action trace; restore reconciles and exposes `reconciliationDropped` (not digested); actions
  "replay.start [1…100]" (`r02-g17.no-replay` without a verified traced result), "replay.step" (`r02-g17.replay-end`
  after the last or once ended), "replay.stop" (campaign at that level, the frontier when it is not open); every other
  play action in replay refused with `r02-g17.replay` except `tutorial.dismiss`, `orbit.choose` and `clock.show`
  (presentation) and `settings.sound`; replay never records; the tutorial is done in replay; a restored replay whose
  records are not exactly the first actions of its level's verified trace (phase changes then the run, in order, no undo
  or redo) is refused as `damaged`; "settings.sound [0 … 1]" sets `soundOn`, snapshotted in schema 3 and not digested,
  off after migration), `Packages/ExperiencesRound02/CelestialEclipseLab/Core/CelestialEclipseLabScenarios.swift` and
  the regenerated `Packages/ExperiencesRound02/CelestialEclipseLab/scenario-manifest.json`,
  `Packages/ExperiencesRound02/CelestialEclipseLab/Core/CelestialEclipseLabFeedbackPlan.swift` (refusal words "There is
  no saved solution to replay for this level.", "The replay is over.", "Stop the replay first."; a replay step announced
  like the action it applies; a replayed win claims no stars) with
  `Packages/ExperiencesRound02/CelestialEclipseLab/CoreTests/CelestialEclipseLabExperienceCoreTests.swift` updates
  (schema 3, migrations 1 → 3 and 2 → 3, reconciliation on restore, replay rules and codes, a replay saved mid-way
  restores while a changed, reordered or undo-carrying replay is refused `damaged`, sound setting); `--name host-2`
- [X] T-R02G1707-004 [P] [US1] [US2] Create — Verified 2026-11-25: 2026-11-25 host-3 exit 0, 9 persistence tests (.autonomy/migration/checks/R02-G17-07.host-3.json): 500 round trips, 100 schema-1 and schema-2 migrations, 200 reconciled saves, determinism
  `Packages/ExperiencesRound02/CelestialEclipseLab/CoreTests/CelestialEclipseLabPersistenceTests.swift` (agent B: 500
  seeded states round-trip with equal digests, the sound choice included and never digested; schema 1 and 2 payloads of
  100 seeded states migrate and restore with progress kept; 200 seeded saves: honest results survive, edited ones are
  dropped and counted; FR-R02G1707-005: the same save restores to an equal digest twice and the daily level depends only
  on the date given); `--name host-3`
- [X] T-R02G1707-005 [P] [US3] Create — Verified 2026-11-25: 2026-11-25 host-4 exit 0 (.autonomy/migration/checks/R02-G17-07.host-4.json): every certified level won then replayed against its witness fingerprints, progress unchanged
  `Packages/ExperiencesRound02/CelestialEclipseLab/CoreTests/CelestialEclipseLabReplayCatalogTests.swift`: for each of
  the 100 certified levels (10 groups of 10, each under 10 s) win the level in campaign through the adapter with its
  certified changes and the run, then `replay.start [level]` and `replay.step` to the end, checking each step's play
  fingerprint against the witness file's recorded fingerprints (as `CelestialEclipseLabWitnessTests` reads
  `docs/games/celestial-eclipse-lab/levels/NNN.witness.json`), the replay ending won and the progress unchanged; `--name
  host-4` (SC-R02G1707-004)

## Phase 4: Panel and simulator proof

- [X] T-R02G1707-006 [US3] Edit — Verified 2026-11-25: 2026-11-25 sim-27 exit 0, 58 simulator tests incl. 4 replay tests (.autonomy/migration/checks/R02-G17-07.sim-27.json); Replay, Step and Stop with labels and values, replay position, the Sound toggle saved through settings.sound and applied on open, dropped results announced once; identity tests take schema 3 and sixteen controls
  `Packages/ExperiencesRound02/CelestialEclipseLab/Experience/CelestialEclipseLabPresenter.swift` and
  `Packages/ExperiencesRound02/CelestialEclipseLab/Experience/CelestialEclipseLabControls.swift` (Replay for a verified
  solved level, Step and Stop with labels and values, the replay position; the Sound toggle sends `settings.sound` and
  the presenter applies the restored `soundOn` when the experience opens; the dropped results announced once: "n saved
  results could not be checked and were removed.") and create
  `Packages/ExperiencesRound02/CelestialEclipseLab/ExperienceTests/CelestialEclipseLabReplayTests.swift` (agent C:
  replay through the port reproduces the fingerprints action by action and ends won; other actions refused during
  replay; progress unchanged; the dropped announcement once; the saved sound choice applied on open); the stored schema
  examples of the app registry come with R02-G17-09; `--name sim-27 -- python3 scripts/xcodebuild_package.py --package
  Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing
  CelestialEclipseLabExperienceTests`

## Phase 5: Regression, documentation and close

- [X] T-R02G1707-007 Docs: `docs/architecture/celestial-eclipse-lab.md` (persistence and replay), — Verified 2026-11-25: 2026-11-25 round02-host-1, -2, -3c, -3e, -3f exit 0 (.autonomy/migration/checks/R02-G17-07.round02-host-*.json); architecture, package README and testing doc updated
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host-1`, `-2`, `-3c`, `-3e`,
  `-3f` (the five round-two filters)
- [ ] T-R02G1707-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`, `--name app-unit`
- [ ] T-R02G1707-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G1707-010 Reference regression chunk 2 (`--name reference-2`)
- [X] T-R02G1707-011 Script tests, run alone (`--name script-tests`) — Verified 2026-11-25: 2026-11-25 script-tests exit 0, run alone (.autonomy/migration/checks/R02-G17-07.script-tests.json)
- [ ] T-R02G1707-012 {device} After ImplementationLock-100: a save survives a real app termination on D1/D2/D3.
- [ ] T-R02G1707-013 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → 002 (agent A) → {003 (lead), 004 (agent B, against the contract)} → 005 (after 003) → 006 (lead; agent C writes
the simulator tests) → 007 … 011, 013. 012 stays open until device testing. Agent A may start in an isolated copy before
001 (its files are the progress and a new reconciliation file). Shared files (adapter, scenarios, feedback, presenter,
panel, docs) stay with the lead. MVP: Stories 1 and 2. Requirement coverage: FR-001/002/005/007 → 003, 004; FR-003 →
002, 003, 004; FR-004 → 003, 005, 006; FR-006 → 007 … 011.
