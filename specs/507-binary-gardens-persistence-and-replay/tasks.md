# Tasks: R02-G21-07 — Binary Gardens: persistence and replay

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G21-07 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G21-07 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_507;
tests stay short (< 10 s each). No {owner} tasks; one {device} task; no GLSL change. Model: feature 497's tasks, with
its lesson taken into the first pass (the scenario manifest digests the progress, now written with traces, so it is
regenerated in T-003 with `UPDATE_SCENARIO_MANIFEST=1`) and round02-host in five chunks (Binary Gardens in chunk 2).
Prerequisites: R02-G21-04, R02-G21-05 and R02-G21-06 recorded.

## Phase 1: Setup

- [ ] T-R02G2107-001 Baselines on the committed tree after R02-G21-06 is recorded: `--name baseline-host`, `--name
  baseline-timing`, `--name baseline-round02-1`, `-2`, `-3c`, `-3e`, `-3f` (the five round-two filters)

## Phase 2: Story 2 — reconcilable scores (P1) 🎯

- [ ] T-R02G2107-002 [P] [US2] Edit `Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensProgress.swift`
  (Result gains "trace: [BinaryGardensAction]" (effective `.ring(star:index:)`, `.phase(star:step:)`,
  `.luminosity(star:index:)` and `.tilt(step:)` actions, then `.run`) and "verified: Bool";
  `record(level:actionsSpent:certified:mode:trace:)` stores a verified result, replacing only when it spends fewer
  actions (ties keep the earlier trace); `drop(level:)`; encoding keeps schema 2 payloads decodable (missing trace =
  empty, missing verified = false); mode "replay(level:)" that awards no stars and opens nothing) and create
  `Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensReconciliation.swift` ("netTrace(records): the actions
  of the ring, phase, luminosity, tilt and run records, each undo removing the last effective action and each redo
  restoring it"; "reconcile(progress) → (progress, dropped): a result with a trace is kept only when a fresh play of its
  certified level (campaign budget) replays the trace to a win, the actions the trace spends are at most actionsSpent
  and its stars equal the stars rule for actionsSpent and the certified action count; a trace over 64 actions, with an
  action the kernel refuses, an action after the run or no final run never verifies; a result marked verified with an
  empty trace is dropped; untraced unverified results kept unverified; frontier unchanged") with
  `Packages/ExperiencesRound02/BinaryGardens/CoreTests/BinaryGardensReconciliationTests.swift` (agent B: every certified
  level's witness actions plus the run as a trace verify; edited stars, actions spent below the trace's actions, a
  changed trace step, and an illegal, failing, run-less or overlong trace are dropped and counted; untraced kept;
  frontier unchanged; netTrace over undo and redo sequences, a failed run undone included) and the
  `Packages/ExperiencesRound02/BinaryGardens/CoreTests/BinaryGardensProgressTests.swift` updates for traces;
  `--name host-1 -- swift test --package-path Packages/ExperiencesRound02 --filter BinaryGardens`

## Phase 3: Stories 1 and 3 — save, migrate, replay (P1, P2)

- [ ] T-R02G2107-003 [US1] [US2] [US3] Edit
  `Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensExperienceCore.swift` (schema 3, migration 2 → 3
  "results with an empty trace and verified false, sound off" (1 → 2 is R02-G21-05's step), digest domain
  `"r02-g21.binary-gardens.v3"` over the level, the play fingerprint, the progress with its traces and the mode (never
  the tutorial step, the shown tick, the sound choice or the dropped count); a campaign or daily win records the winning
  effective-action trace; restore reconciles and exposes `reconciliationDropped` (not digested); actions "replay.start
  [1…100]" (`r02-g21.no-replay` without a verified traced result), "replay.step" (`r02-g21.replay-end` after the last or
  once ended), "replay.stop" (campaign at that level, the frontier when it is not open); every other play action in
  replay refused with `r02-g21.replay` except `tutorial.dismiss`, `clock.show` (presentation) and `settings.sound`;
  replay starts with tick 48 shown, a step keeps the shown tick, replay never records, and the tutorial is done in
  replay; a restored replay whose records are not exactly the first actions of its level's verified trace (ring,
  phase, luminosity and tilt actions then the run, in order, no undo or redo) is refused as `damaged`; a replay whose
  result was dropped on restore returns to campaign; "settings.sound [0 … 1]" sets `soundOn` (non-whole values
  `r02-g21.not-whole`), snapshotted in schema 3 under `"sound"`, part of `==` and not digested, off after migration),
  `Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensScenarios.swift` and the regenerated
  `Packages/ExperiencesRound02/BinaryGardens/scenario-manifest.json`,
  `Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensFeedbackPlan.swift` (refusal words "There is no saved
  solution to replay for this level.", "The replay is over.", "Stop the replay first."; a replay step announced like
  the action it applies; a replayed win claims no stars) with the updates named in clarification Q6 in place —
  `Packages/ExperiencesRound02/BinaryGardens/CoreTests/BinaryGardensExperienceCoreTests.swift` (control list, schema 3,
  the newer-schema refusal test's literal versions, digest v3, migrations 1 → 3 and 2 → 3, reconciliation on restore,
  replay rules and codes, a replay saved mid-way restores while a changed, reordered or undo-carrying replay is refused
  `damaged`, the sound setting), `BinaryGardensProgressionCoreTests.swift`, `BinaryGardensSceneSnapshotTests.swift`
  (`schemaVersion`) and `BinaryGardensFeedbackPlanTests.swift`; `--name host-2 -- swift test --package-path
  Packages/ExperiencesRound02 --filter BinaryGardens`
- [ ] T-R02G2107-004 [P] [US1] [US2] Create
  `Packages/ExperiencesRound02/BinaryGardens/CoreTests/BinaryGardensPersistenceTests.swift` (agent C: 500 seeded
  states round-trip with equal digests, the sound choice included and never digested; schema 1 and 2 payloads of 100
  seeded states migrate and restore with progress kept; 200 seeded saves: honest results survive, edited ones are
  dropped and counted; FR-R02G2107-005: the same save restores to an equal digest twice and the daily level depends
  only on the date given); `--name host-3 -- swift test --package-path Packages/ExperiencesRound02 --filter
  BinaryGardens`
- [ ] T-R02G2107-005 [P] [US3] Create
  `Packages/ExperiencesRound02/BinaryGardens/CoreTests/BinaryGardensReplayCatalogTests.swift`: for each of the 100
  certified levels (10 groups of 10, each under 10 s) win the level in campaign through the adapter with its certified
  actions and the run, then `replay.start [level]` and `replay.step` to the end, checking each step's play fingerprint
  against the witness file's recorded fingerprints (as `BinaryGardensWitnessTests` reads
  `docs/games/binary-gardens/levels/NNN.witness.json`), the replay ending won, the shown tick kept and the progress
  unchanged; agent C; `--name host-4 -- swift test --package-path Packages/ExperiencesRound02 --filter BinaryGardens`
  (SC-R02G2107-004)

## Phase 4: Panel and simulator proof

- [ ] T-R02G2107-006 [US3] Edit `Packages/ExperiencesRound02/BinaryGardens/Experience/BinaryGardensPresenter.swift`
  and `Packages/ExperiencesRound02/BinaryGardens/Experience/BinaryGardensControls.swift` (Replay for a verified solved
  level, Step and Stop with labels and values, the replay position; the Sound toggle sends `settings.sound` and the
  presenter applies the restored `soundOn` when the experience opens, replacing R02-G21-06's presenter-held choice; the
  dropped results announced once: "n saved results could not be checked and were removed.") and create
  `Packages/ExperiencesRound02/BinaryGardens/ExperienceTests/BinaryGardensReplayTests.swift` (agent C: replay through
  the port reproduces the fingerprints action by action and ends won; tick scrubbing allowed and other actions refused
  during replay; progress unchanged; the dropped announcement once; the saved sound choice applied on open); update in
  place `Packages/ExperiencesRound02/BinaryGardens/ExperienceTests/BinaryGardensExperienceIdentityTests.swift` and
  `BinaryGardensAccessibilityTests.swift` only where they assert the presenter-held sound choice; the stored schema
  examples of the app registry come with R02-G21-09; `--name sim-27 -- python3 scripts/xcodebuild_package.py --package
  Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing
  BinaryGardensExperienceTests`

## Phase 5: Regression, documentation and close

- [ ] T-R02G2107-007 Docs: `docs/architecture/binary-gardens.md` (persistence and replay),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host-1`, `-2`, `-3c`, `-3e`,
  `-3f` (the five round-two filters)
- [ ] T-R02G2107-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, `--name
  host-full`, `--name app-unit`
- [ ] T-R02G2107-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G2107-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G2107-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G2107-012 {device} After ImplementationLock-100: a save survives a real app termination on D1/D2/D3
  (SC-R02G2107-007)
- [ ] T-R02G2107-013 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → 002 (agent B) → {003 (lead), 004 (agent C, against the contract)} → 005 (after 003) → 006 (lead; agent C writes
the simulator tests) → 007 … 011, 013. 012 stays open until device testing. Agent B may start in an isolated copy
before 001 (its files are the progress and a new reconciliation file). Shared files (adapter, scenarios, feedback,
presenter, panel, docs) stay with the lead. MVP: Stories 1 and 2. Requirement coverage: FR-001/002/005/007 → 003, 004;
FR-003 → 002, 003, 004; FR-004 → 003, 005, 006; FR-006 → 007 … 011; FR-008 → 003, 006; FR-009 → 003, 006.
