# Tasks: R02-G14-07 — Moonlit Mechanism: persistence and replay

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G14-07 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G14-07 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_437;
tests stay short (< 10 s each). No {owner} tasks; one {device} task; no GLSL change. Model: feature 427's tasks, with its
convergence lesson (a restored replay validated against its trace) taken into the first pass.

## Phase 1: Setup

- [ ] T-R02G1407-001 Baselines after R02-G14-06 is recorded: `--name baseline-host`, `--name baseline-timing`, `--name
  baseline-round02 -- swift test --package-path Packages/ExperiencesRound02`

## Phase 2: Story 2 — reconcilable scores (P1) 🎯

- [ ] T-R02G1407-002 [P] [US2] Edit `Packages/ExperiencesRound02/MoonlitMechanism/Core/MoonlitMechanismProgress.swift` (Result gains "trace:
  [MoonlitMechanismAction]" (effective turns, re-seats and lamp steps and the run) and "verified: Bool";
  `record(level:actionsSpent:certified:mode:trace:)` stores a verified result, replacing only when better (ties keep the
  earlier trace); `drop(level:)`; encoding keeps old payloads decodable (missing trace = empty, missing verified =
  false); mode "replay(level:)" that awards no stars and opens nothing) and create
  `Packages/ExperiencesRound02/MoonlitMechanism/Core/MoonlitMechanismReconciliation.swift` ("netTrace(records): the actions of the turn, re-seat, lamp step and run records,
  each undo removing the last effective action and each redo restoring it"; "reconcile(progress) → (progress, dropped):
  a result with a trace is kept only when a fresh play of its certified level (campaign budget) replays the trace to a
  win, the actions the trace spends are at most actionsSpent and its stars equal the stars rule for actionsSpent and the
  certified witness's action count; a trace over 64 actions or with an action the kernel refuses never verifies; untraced
  results kept unverified; frontier unchanged") with `Packages/ExperiencesRound02/MoonlitMechanism/CoreTests/MoonlitMechanismReconciliationTests.swift` (agent A:
  every certified level's witness as a trace verifies; edited stars, actions spent below the trace's actions, a trace
  step and an illegal or overlong trace are dropped and counted; untraced kept; frontier unchanged; netTrace over undo
  and redo sequences); `--name host`

## Phase 3: Stories 1 and 3 — save, migrate, replay (P1, P2)

- [ ] T-R02G1407-003 [US1] [US2] [US3] Edit `Packages/ExperiencesRound02/MoonlitMechanism/Core/MoonlitMechanismExperienceCore.swift` (schema 3, migration 2 → 3
  "results with an empty trace and verified false, sound off", digest v3; a campaign or daily win records the winning
  effective-action trace; restore reconciles and exposes `reconciliationDropped` (not digested); actions "replay.start
  [1…100]" (`r02-g14.no-replay` without a verified traced result), "replay.step" (`r02-g14.replay-end` after the last
  or once ended), "replay.stop" (campaign at that level, the frontier when it is not open); every other play action in
  replay refused with `r02-g14.replay` except `tutorial.dismiss` and `settings.sound`; replay never records; the
  tutorial is done in replay; a restored replay whose records are not exactly the first actions of its level's verified
  trace (turns, re-seats, lamp steps and the run only, in order, no undo or redo) is refused as `damaged`; "settings.sound [0 … 1]" sets `soundOn`, snapshotted in schema 3 and not digested, off
  after migration), `Packages/ExperiencesRound02/MoonlitMechanism/Core/MoonlitMechanismScenarios.swift` and the regenerated `Packages/ExperiencesRound02/MoonlitMechanism/scenario-manifest.json`,
  `Packages/ExperiencesRound02/MoonlitMechanism/Core/MoonlitMechanismFeedbackPlan.swift` (refusal words "There is no saved solution to replay for this level.",
  "The replay is over.", "Stop the replay first."; a replay step announced like the action it applies; a replayed win
  claims no stars) with `Packages/ExperiencesRound02/MoonlitMechanism/CoreTests/MoonlitMechanismExperienceCoreTests.swift` updates (schema 3, migrations 1 → 3 and
  2 → 3, reconciliation on restore, replay rules and codes, a replay saved mid-way restores while a changed, reordered
  or undo-carrying replay is refused `damaged`, sound setting); `--name host-2`
- [ ] T-R02G1407-004 [P] [US1] [US2] Create `Packages/ExperiencesRound02/MoonlitMechanism/CoreTests/MoonlitMechanismPersistenceTests.swift` (agent B: 500 seeded
  states round-trip with equal digests, the sound choice included and never digested; schema 1 and 2 payloads of 100
  seeded states migrate and restore with progress kept; 200 seeded saves: honest results survive, edited ones are
  dropped and counted; FR-R02G1407-005: the same save restores to an equal digest twice and the daily level depends only
  on the date given); `--name host-3`

## Phase 4: Panel and simulator proof

- [ ] T-R02G1407-005 [US3] Edit `Packages/ExperiencesRound02/MoonlitMechanism/Experience/MoonlitMechanismPresenter.swift` and
  `Packages/ExperiencesRound02/MoonlitMechanism/Experience/MoonlitMechanismControls.swift` (Replay for a verified solved level, Step and Stop with labels and
  values, the replay position; the Sound toggle sends `settings.sound` and the presenter applies the restored `soundOn`
  when the experience opens; the dropped results announced once: "n saved results could not be checked and were
  removed.") and create `Packages/ExperiencesRound02/MoonlitMechanism/ExperienceTests/MoonlitMechanismReplayTests.swift` (agent C: replay through the port
  reproduces the fingerprints action by action and ends won; other actions refused during replay; progress unchanged;
  the dropped announcement once; the saved sound choice applied on open); the stored schema examples of the app registry
  come with R02-G14-09; `--name sim-27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02
  --scheme ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing MoonlitMechanismExperienceTests`

## Phase 5: Regression, documentation and close

- [ ] T-R02G1407-006 Docs: `docs/architecture/moonlit-mechanism.md` (persistence and replay),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`
- [ ] T-R02G1407-007 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`, `--name app-unit`
- [ ] T-R02G1407-008 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G1407-009 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G1407-010 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G1407-011 {device} After ImplementationLock-100: a save survives a real app termination on D1/D2/D3.
- [ ] T-R02G1407-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → 002 (agent A) → {003 (lead), 004 (agent B, against the contract)} → 005 (lead; agent C writes the simulator tests)
→ 006 … 010, 012. 011 stays open until device testing. Agent A may start in an isolated copy before 001 (its files are
the progress and a new reconciliation file). Shared files (adapter, scenarios, feedback, presenter, panel, docs) stay
with the lead. MVP: Stories 1 and 2. Requirement coverage: FR-001/002/005/007 → 003, 004; FR-003 → 002, 003, 004; FR-004 →
003, 005; FR-006 → 006 … 010.

