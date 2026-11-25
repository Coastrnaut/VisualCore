# Tasks: R02-G16-07 — Starlit Cartouche: persistence and replay

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G16-07 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G16-07 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_457;
tests stay short (< 10 s each). No {owner} tasks; one {device} task; no GLSL change. Model: feature 447's tasks, with
its convergence lesson (a restored replay validated against its trace) taken into the first pass.

## Phase 1: Setup

- [X] T-R02G1607-001 Baselines after R02-G16-06 is recorded: `--name baseline-host`, `--name baseline-timing`, `--name — Verified 2026-11-25: 2026-11-25 baseline-host-2 and round02-1, -2, -3c, -3e, -3f exit 0 (chunk 3 split: host runs ~3x slower, the process tree at background priority PRI 4); baseline-timing printed bounds above its asserts on all six attempts (mesh 2.3-2.7 s vs 0.70 s, VisualCore unchanged since R02-G16-06), host scheduling, not code; first attempts timed out under agent contention
  baseline-round02-1 … 3` (the three round-two filters of feature 446)

## Phase 2: Story 2 — reconcilable scores (P1) 🎯

- [X] T-R02G1607-002 [P] [US2] Edit `Packages/ExperiencesRound02/StarlitCartouche/Core/StarlitCartoucheProgress.swift` — Verified 2026-11-24: 2026-11-24 host-1 exit 0 (Reconciliation 13 and Progress tests; agent A's files retested by the lead in the merged copy, 230 tests)
  (Result gains "trace: [StarlitCartoucheAction]" (effective legs, each `.leg(star, wait)`) and "verified: Bool";
  `record(level:actionsSpent:certified:mode:trace:)` stores a verified result, replacing only when better (ties keep the
  earlier trace); `drop(level:)`; encoding keeps old payloads decodable (missing trace = empty, missing verified =
  false); mode "replay(level:)" that awards no stars and opens nothing) and create
  `Packages/ExperiencesRound02/StarlitCartouche/Core/StarlitCartoucheReconciliation.swift` ("netTrace(records): the legs
  of the leg records, each undo removing the last effective leg and each redo restoring it"; "reconcile(progress) →
  (progress, dropped): a result with a trace is kept only when a fresh play of its certified level (campaign budget)
  replays the trace to a win, the legs the trace spends are at most actionsSpent and its stars equal the stars rule for
  actionsSpent and the certified witness's leg count; a trace over 64 legs or with a leg the kernel refuses or that
  fails never verifies; untraced results kept unverified; frontier unchanged") with
  `Packages/ExperiencesRound02/StarlitCartouche/CoreTests/StarlitCartoucheReconciliationTests.swift` (agent A: every
  certified level's witness as a trace verifies; edited stars, actions spent below the trace's legs, a trace step and an
  illegal, failing or overlong trace are dropped and counted; untraced kept; frontier unchanged; netTrace over undo and
  redo sequences); `--name host-1`

## Phase 3: Stories 1 and 3 — save, migrate, replay (P1, P2)

- [X] T-R02G1607-003 [US1] [US2] [US3] Edit — Verified 2026-11-24: 2026-11-24 host-2 exit 0 (all StarlitCartoucheCoreTests: schema 3, migrations, replay rules, reconciliation on restore, sound; manifest regenerated)
  `Packages/ExperiencesRound02/StarlitCartouche/Core/StarlitCartoucheExperienceCore.swift` (schema 3, migration 2 → 3
  "results with an empty trace and verified false, sound off", digest v3; a campaign or daily win records the winning
  effective-action trace; restore reconciles and exposes `reconciliationDropped` (not digested); actions "replay.start
  [1…100]" (`r02-g16.no-replay` without a verified traced result), "replay.step" (`r02-g16.replay-end` after the last or
  once ended), "replay.stop" (campaign at that level, the frontier when it is not open); every other play action in
  replay refused with `r02-g16.replay` except `tutorial.dismiss`, `route.choose` (presentation) and `settings.sound`;
  replay never records; the tutorial is done in replay; a restored replay whose records are not exactly the first
  actions of its level's verified trace (legs only, in order, no undo or redo) is refused as `damaged`; "settings.sound
  [0 … 1]" sets `soundOn`, snapshotted in schema 3 and not digested, off after migration),
  `Packages/ExperiencesRound02/StarlitCartouche/Core/StarlitCartoucheScenarios.swift` and the regenerated
  `Packages/ExperiencesRound02/StarlitCartouche/scenario-manifest.json`,
  `Packages/ExperiencesRound02/StarlitCartouche/Core/StarlitCartoucheFeedbackPlan.swift` (refusal words "There is no
  saved solution to replay for this level.", "The replay is over.", "Stop the replay first."; a replay step announced
  like the action it applies; a replayed win claims no stars) with
  `Packages/ExperiencesRound02/StarlitCartouche/CoreTests/StarlitCartoucheExperienceCoreTests.swift` updates (schema 3,
  migrations 1 → 3 and 2 → 3, reconciliation on restore, replay rules and codes, a replay saved mid-way restores while a
  changed, reordered or undo-carrying replay is refused `damaged`, sound setting); `--name host-2`
- [X] T-R02G1607-004 [P] [US1] [US2] Create — Verified 2026-11-24: 2026-11-24 host-3 exit 0 (agent B's persistence tests, 8 tests 28 cases, retested by the lead)
  `Packages/ExperiencesRound02/StarlitCartouche/CoreTests/StarlitCartouchePersistenceTests.swift` (agent B: 500 seeded
  states round-trip with equal digests, the sound choice included and never digested; schema 1 and 2 payloads of 100
  seeded states migrate and restore with progress kept; 200 seeded saves: honest results survive, edited ones are
  dropped and counted; FR-R02G1607-005: the same save restores to an equal digest twice and the daily level depends only
  on the date given); `--name host-3`

## Phase 4: Panel and simulator proof

- [X] T-R02G1607-005 [US3] Edit — Verified 2026-11-24: 2026-11-24 sim-27 exit 0 (56 tests, the 4 replay tests by agent C included and passing unedited)
  `Packages/ExperiencesRound02/StarlitCartouche/Experience/StarlitCartouchePresenter.swift` and
  `Packages/ExperiencesRound02/StarlitCartouche/Experience/StarlitCartoucheControls.swift` (Replay for a verified solved
  level, Step and Stop with labels and values, the replay position; the Sound toggle sends `settings.sound` and the
  presenter applies the restored `soundOn` when the experience opens; the dropped results announced once: "n saved
  results could not be checked and were removed.") and create
  `Packages/ExperiencesRound02/StarlitCartouche/ExperienceTests/StarlitCartoucheReplayTests.swift` (agent C: replay
  through the port reproduces the fingerprints action by action and ends won; other actions refused during replay;
  progress unchanged; the dropped announcement once; the saved sound choice applied on open); the stored schema examples
  of the app registry come with R02-G16-09; `--name sim-27 -- python3 scripts/xcodebuild_package.py --package
  Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing
  StarlitCartoucheExperienceTests`

## Phase 5: Regression, documentation and close

- [X] T-R02G1607-006 Docs: `docs/architecture/starlit-cartouche.md` (persistence and replay), — Verified 2026-11-25: 2026-11-25 round02-host-1, -2, -3c, -3e, -3f exit 0 (chunk 3 split in three: the machine ran about 3x slower and the single chunk timed out at 600 s); docs updated
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host-1 … 3` (the three filters of
  feature 446)
- [X] T-R02G1607-007 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-25: 2026-11-25 rendering-27, rendering-26, experiences, host-full, app-unit exit 0
  `--name host-full`, `--name app-unit`
- [X] T-R02G1607-008 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-25: 2026-11-25 reference-1 exit 0
- [X] T-R02G1607-009 Reference regression chunk 2 (`--name reference-2`) — Verified 2026-11-25: 2026-11-25 reference-2 exit 0
- [ ] T-R02G1607-010 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G1607-011 {device} After ImplementationLock-100: a save survives a real app termination on D1/D2/D3.
- [ ] T-R02G1607-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → 002 (agent A) → {003 (lead), 004 (agent B, against the contract)} → 005 (lead; agent C writes the simulator tests)
→ 006 … 010, 012; 013 (the replay catalog proof) after 003. 011 stays open until device testing. Agent A may start in an
isolated copy before 001 (its files are the progress and a new reconciliation file). Shared files (adapter, scenarios,
feedback, presenter, panel, docs) stay with the lead. MVP: Stories 1 and 2. Requirement coverage: FR-001/002/005/007 →
003, 004; FR-003 → 002, 003, 004; FR-004 → 003, 005; FR-006 → 006 … 010.


## Phase 6: Replay catalog proof (taken from feature 447's convergence round)

- [X] T-R02G1607-013 Add — Verified 2026-11-24: 2026-11-24 host-6 exit 0 (all 100 levels won and replayed against the witness fingerprints; agent D's file retested by the lead)
  `Packages/ExperiencesRound02/StarlitCartouche/CoreTests/StarlitCartoucheReplayCatalogTests.swift`: for each of the 100
  certified levels (10 groups of 10, each under 10 s) win the level in campaign through the adapter with its certified
  legs, then `replay.start [level]` and `replay.step` to the end, checking each step's play fingerprint against the
  witness file's recorded fingerprints (as `StarlitCartoucheWitnessTests` reads
  `docs/games/starlit-cartouche/levels/NNN.witness.json`), the replay ending won and the progress unchanged; `--name
  host-6` (SC-R02G1607-004)
