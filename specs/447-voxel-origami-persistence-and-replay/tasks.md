# Tasks: R02-G15-07 — Voxel Origami: persistence and replay

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G15-07 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G15-07 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_447;
tests stay short (< 10 s each). No {owner} tasks; one {device} task; no GLSL change. Model: feature 437's tasks, with its
convergence lesson (a restored replay validated against its trace) taken into the first pass.

## Phase 1: Setup

- [X] T-R02G1507-001 Baselines after R02-G15-06 is recorded: `--name baseline-host`, `--name baseline-timing`, `--name — Verified 2026-11-24: 2026-11-24: baseline-host, baseline-timing and baseline-round02-1…3 exit 0 after R02-G15-06's record
  baseline-round02-1 … 3` (the three round-two filters of feature 446)

## Phase 2: Story 2 — reconcilable scores (P1) 🎯

- [X] T-R02G1507-002 [P] [US2] Edit `Packages/ExperiencesRound02/VoxelOrigami/Core/VoxelOrigamiProgress.swift` (Result gains "trace: — Verified 2026-11-24: 2026-11-24: agent A Result trace + verified (old payloads decode unverified), traced record replacing only when better, drop, replay mode; VoxelOrigamiReconciliation (netTrace, verifies, reconcile; 64-turn bound); 13 reconciliation tests; progress encodings in two test files and the manifest's final digests updated; the mode's new case added to the panel's mode name and the presenter's retry (replay.start); lead host-1 (whole VoxelOrigami suite) exit 0, experience builds
  [VoxelOrigamiAction]" (effective turns, each `.turn(hinge, step)`) and "verified: Bool";
  `record(level:actionsSpent:certified:mode:trace:)` stores a verified result, replacing only when better (ties keep the
  earlier trace); `drop(level:)`; encoding keeps old payloads decodable (missing trace = empty, missing verified =
  false); mode "replay(level:)" that awards no stars and opens nothing) and create
  `Packages/ExperiencesRound02/VoxelOrigami/Core/VoxelOrigamiReconciliation.swift` ("netTrace(records): the turns of the turn records, each undo removing the last
  effective turn and each redo restoring it"; "reconcile(progress) → (progress, dropped):
  a result with a trace is kept only when a fresh play of its certified level (campaign budget) replays the trace to a
  win, the turns the trace spends are at most actionsSpent and its stars equal the stars rule for actionsSpent and the
  certified witness's turn count; a trace over 64 turns or with a turn the kernel refuses or that fails never
  verifies; untraced
  results kept unverified; frontier unchanged") with `Packages/ExperiencesRound02/VoxelOrigami/CoreTests/VoxelOrigamiReconciliationTests.swift` (agent A:
  every certified level's witness as a trace verifies; edited stars, actions spent below the trace's turns, a trace
  step and an illegal, failing or overlong trace are dropped and counted; untraced kept; frontier unchanged; netTrace over undo
  and redo sequences); `--name host-1`

## Phase 3: Stories 1 and 3 — save, migrate, replay (P1, P2)

- [X] T-R02G1507-003 [US1] [US2] [US3] Edit `Packages/ExperiencesRound02/VoxelOrigami/Core/VoxelOrigamiExperienceCore.swift` (schema 3, migration 2 → 3 — Verified 2026-11-24: 2026-11-24 host-2 exit 0 (.autonomy/migration/checks/R02-G15-07.host-2.json)
  "results with an empty trace and verified false, sound off", digest v3; a campaign or daily win records the winning
  effective-action trace; restore reconciles and exposes `reconciliationDropped` (not digested); actions "replay.start
  [1…100]" (`r02-g15.no-replay` without a verified traced result), "replay.step" (`r02-g15.replay-end` after the last
  or once ended), "replay.stop" (campaign at that level, the frontier when it is not open); every other play action in
  replay refused with `r02-g15.replay` except `tutorial.dismiss`, `hinge.choose` (presentation) and `settings.sound`; replay never records; the
  tutorial is done in replay; a restored replay whose records are not exactly the first actions of its level's verified
  trace (turns only, in order, no undo or redo) is refused as `damaged`; "settings.sound [0 … 1]" sets `soundOn`, snapshotted in schema 3 and not digested, off
  after migration), `Packages/ExperiencesRound02/VoxelOrigami/Core/VoxelOrigamiScenarios.swift` and the regenerated `Packages/ExperiencesRound02/VoxelOrigami/scenario-manifest.json`,
  `Packages/ExperiencesRound02/VoxelOrigami/Core/VoxelOrigamiFeedbackPlan.swift` (refusal words "There is no saved solution to replay for this level.",
  "The replay is over.", "Stop the replay first."; a replay step announced like the action it applies; a replayed win
  claims no stars) with `Packages/ExperiencesRound02/VoxelOrigami/CoreTests/VoxelOrigamiExperienceCoreTests.swift` updates (schema 3, migrations 1 → 3 and
  2 → 3, reconciliation on restore, replay rules and codes, a replay saved mid-way restores while a changed, reordered
  or undo-carrying replay is refused `damaged`, sound setting); `--name host-2`
- [X] T-R02G1507-004 [P] [US1] [US2] Create `Packages/ExperiencesRound02/VoxelOrigami/CoreTests/VoxelOrigamiPersistenceTests.swift` (agent B: 500 seeded — Verified 2026-11-24: 2026-11-24 host-3 exit 0, 8 tests (.autonomy/migration/checks/R02-G15-07.host-3.json)
  states round-trip with equal digests, the sound choice included and never digested; schema 1 and 2 payloads of 100
  seeded states migrate and restore with progress kept; 200 seeded saves: honest results survive, edited ones are
  dropped and counted; FR-R02G1507-005: the same save restores to an equal digest twice and the daily level depends only
  on the date given); `--name host-3`

## Phase 4: Panel and simulator proof

- [X] T-R02G1507-005 [US3] Edit `Packages/ExperiencesRound02/VoxelOrigami/Experience/VoxelOrigamiPresenter.swift` and — Verified 2026-11-24: 2026-11-24 sim-27 exit 0 (.autonomy/migration/checks/R02-G15-07.sim-27.json); VoxelOrigamiReplayTests 7 passed
  `Packages/ExperiencesRound02/VoxelOrigami/Experience/VoxelOrigamiControls.swift` (Replay for a verified solved level, Step and Stop with labels and
  values, the replay position; the Sound toggle sends `settings.sound` and the presenter applies the restored `soundOn`
  when the experience opens; the dropped results announced once: "n saved results could not be checked and were
  removed.") and create `Packages/ExperiencesRound02/VoxelOrigami/ExperienceTests/VoxelOrigamiReplayTests.swift` (agent C: replay through the port
  reproduces the fingerprints action by action and ends won; other actions refused during replay; progress unchanged;
  the dropped announcement once; the saved sound choice applied on open); the stored schema examples of the app registry
  come with R02-G15-09; `--name sim-27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02
  --scheme ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing VoxelOrigamiExperienceTests`

## Phase 5: Regression, documentation and close

- [X] T-R02G1507-006 Docs: `docs/architecture/voxel-origami.md` (persistence and replay), — Verified 2026-11-24: 2026-11-24 round02-host-1/2/3 exit 0 (55 s, 44 s, 337 s; .autonomy/migration/checks/R02-G15-07.round02-host-*.json)
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host-1 … 3` (the three filters of feature 446)
- [X] T-R02G1507-007 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-24: 2026-11-24 rendering-27, rendering-26, experiences, host-full, app-unit exit 0 (.autonomy/migration/checks/R02-G15-07.*.json)
  `--name host-full`, `--name app-unit`
- [ ] T-R02G1507-008 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G1507-009 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G1507-010 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G1507-011 {device} After ImplementationLock-100: a save survives a real app termination on D1/D2/D3.
- [ ] T-R02G1507-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → 002 (agent A) → {003 (lead), 004 (agent B, against the contract)} → 005 (lead; agent C writes the simulator tests)
→ 006 … 010, 012. 011 stays open until device testing. Agent A may start in an isolated copy before 001 (its files are
the progress and a new reconciliation file). Shared files (adapter, scenarios, feedback, presenter, panel, docs) stay
with the lead. MVP: Stories 1 and 2. Requirement coverage: FR-001/002/005/007 → 003, 004; FR-003 → 002, 003, 004; FR-004 →
003, 005; FR-006 → 006 … 010.


## Phase 6: Convergence

- [ ] T-R02G1507-013 Add `Packages/ExperiencesRound02/VoxelOrigami/CoreTests/VoxelOrigamiReplayCatalogTests.swift`: for each of the 100 certified levels (10 groups of 10, each under 10 s) win the level in campaign through the adapter with its certified turns, then `replay.start [level]` and `replay.step` to the end, checking each step's play fingerprint against the witness file's recorded fingerprints (as `VoxelOrigamiWitnessTests` reads `docs/games/voxel-origami/levels/NNN.witness.json`), the replay ending won and the progress unchanged; `--name host-4` per SC-R02G1507-004 (partial)
