# Tasks: R02-G07-07 — Amethyst Escape: persistence and replay

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G07-07 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G07-07 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_367;
tests stay short (< 10 s each). No {owner} tasks; one {device} task; no GLSL change.

## Phase 1: Setup

- [X] T-R02G0707-001 Baselines: `--name baseline-round02`, `--name baseline-host`, `--name baseline-timing` — Verified 2026-11-22: 2026-11-22: baseline-round02, baseline-host, baseline-timing exit 0

## Phase 2: Story 2 — reconcilable scores (P1) 🎯

- [X] T-R02G0707-002 [P] [US2] Edit `Packages/ExperiencesRound02/AmethystEscape/Core/AmethystEscapeProgress.swift` (Result gains "trace: — Verified 2026-11-22: 2026-11-22: host (swift test --filter AmethystEscape incl. ReconciliationTests 11: all 100 certified solutions verify as traces, edited results dropped and counted, untraced kept, frontier unchanged, netTrace over undo/redo; manifest regenerated for the trace fields) exit 0, lead retest
  [AmethystEscapeAction]" and "verified: Bool"; `record(level:moves:smallest:mode:trace:)` stores a verified result,
  replacing only when better (ties keep the earlier trace); `drop(level:)`; encoding keeps old payloads decodable
  (missing trace = empty, missing verified = false); mode "replay(level:)" that awards no stars and opens nothing) and
  create `Packages/ExperiencesRound02/AmethystEscape/Core/AmethystEscapeReconciliation.swift` ("netTrace(records): the actions of rotate and advance
  records, each undo removing the last net action and each redo restoring it"; "reconcile(progress) →
  (progress, dropped): a result with a trace is kept only when a fresh play of its certified level (campaign budget)
  replays the trace to a win with exactly bestMoves moves and its stars; a trace over 64 actions or with an
  illegal action never verifies; untraced results kept unverified; frontier unchanged") with
  `Packages/ExperiencesRound02/AmethystEscape/CoreTests/AmethystEscapeReconciliationTests.swift` (agent A: every certified level's witness as a trace
  verifies; edited stars, moves, a trace step and an illegal or overlong trace are dropped and counted; untraced kept;
  frontier unchanged; netTrace over undo/redo sequences); `--name host`

## Phase 3: Stories 1 and 3 — save, migrate, replay (P1, P2)

- [X] T-R02G0707-003 [US1] [US2] [US3] Edit `Packages/ExperiencesRound02/AmethystEscape/Core/AmethystEscapeExperienceCore.swift` (schema 3, migration 2 → 3 — Verified 2026-11-22: 2026-11-22: host-2 (swift test --filter AmethystEscape: schema 3 round trip, migrations 1 to 3 and 2 to 3, reconciliation on restore, replay rules and codes, sound setting not digested, replay feedback words; regenerated manifest) exit 0, lead retest
  "results with an empty trace and verified false, sound off", digest v3; a campaign or daily win records the winning
  net trace; restore reconciles and exposes `reconciliationDropped` (not digested); actions "replay.start [1…100]"
  (`r02-g07.no-replay` without a verified traced result), "replay.step" (`r02-g07.replay-end` after the last or once
  ended), "replay.stop" (campaign at that level, the frontier when it is not open); every other play action in replay
  refused with `r02-g07.replay` except `tutorial.dismiss` and `settings.sound`; replay never records; the tutorial is
  done in replay; "settings.sound [0 … 1]" sets `soundOn`, snapshotted in schema 3 and not digested, off after
  migration), `Packages/ExperiencesRound02/AmethystEscape/Core/AmethystEscapeScenarios.swift` and the regenerated `Packages/ExperiencesRound02/AmethystEscape/scenario-manifest.json`,
  `Packages/ExperiencesRound02/AmethystEscape/Core/AmethystEscapeFeedbackPlan.swift` (refusal words "There is no saved solution to replay for this level.",
  "The replay is over.", "Stop the replay first."; a replay step announced like the action; a replayed win claims no
  stars) with `Packages/ExperiencesRound02/AmethystEscape/CoreTests/AmethystEscapeExperienceCoreTests.swift` updates (schema 3, migrations 1 → 3 and 2 → 3,
  reconciliation on restore, replay rules and codes, sound setting); `--name host-2`
- [X] T-R02G0707-004 [P] [US1] [US2] Create `Packages/ExperiencesRound02/AmethystEscape/CoreTests/AmethystEscapePersistenceTests.swift` (agent B: 500 seeded — Verified 2026-11-22: 2026-11-22: host-3 (PersistenceTests 15: 500 seeded round trips with the sound choice never digested, 100 schema-1 and 100 schema-2 migrations, 200 traced saves with edited results dropped and counted exactly, restore twice and the daily level from the date only) exit 0, lead retest
  states round-trip with equal digests, the sound choice included and never digested; schema 1 and 2 payloads of 100
  seeded states migrate and restore with progress kept; 200 seeded saves: honest results survive, edited ones are
  dropped and counted; FR-R02G0707-005: the same save restores to an equal digest twice and the daily level depends only
  on the date given); `--name host-3`

## Phase 4: Panel and simulator proof

- [X] T-R02G0707-005 [US3] Edit `Packages/ExperiencesRound02/AmethystEscape/Experience/AmethystEscapePresenter.swift` and — Verified 2026-11-22: 2026-11-22: sim-27 (AmethystEscapeExperienceTests, 55 tests on iOS 27.2 incl. 3 replay tests: replay reproduces the win step by step with other actions refused and progress unchanged, the dropped-results announcement once, the saved sound choice applied on open) exit 0
  `Packages/ExperiencesRound02/AmethystEscape/Experience/AmethystEscapeControls.swift` (Replay for a verified solved level, Step and Stop with labels and
  values, the replay position; the Sound toggle sends `settings.sound` and the presenter applies the restored
  `soundOn` when the experience opens; the dropped results announced once: "n saved results could not be checked and
  were removed.") and create `Packages/ExperiencesRound02/AmethystEscape/ExperienceTests/AmethystEscapeReplayTests.swift` (agent C: replay through the port
  reproduces the fingerprints action by action and ends won; other actions refused during replay; progress unchanged;
  the dropped announcement once; the saved sound choice applied on open); the stored schema examples of the app
  registry come with R02-G07-09; `--name sim-27 -- python3 scripts/xcodebuild_package.py --package
  Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing
  AmethystEscapeExperienceTests`

## Phase 5: Regression, documentation and close

- [X] T-R02G0707-006 Docs: `docs/architecture/amethyst-escape.md` (persistence and replay), — Verified 2026-11-22: 2026-11-22: round02-host (swift test --package-path Packages/ExperiencesRound02) exit 0; architecture persistence and replay, package README, testing lesson
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`
- [X] T-R02G0707-007 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-22: rendering-27, rendering-26, experiences, host-full, app-unit exit=0
  `--name host-full`, `--name app-unit`
- [X] T-R02G0707-008 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-22: reference-1 exit=0
- [X] T-R02G0707-009 Reference regression chunk 2 (`--name reference-2`) — Verified 2026-11-22: reference-2 exit=0
- [ ] T-R02G0707-010 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G0707-011 {device} After ImplementationLock-100: a save survives a real app termination on D1/D2/D3.
- [ ] T-R02G0707-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → 002 (agent A) → {003 (lead), 004 (agent B, against the contract)} → 005 (lead; agent C writes the simulator tests)
→ 006 … 010, 012. 011 stays open until device testing. Shared files (adapter, scenarios, feedback, presenter, panel,
docs) stay with the lead. MVP: Stories 1 and 2.
