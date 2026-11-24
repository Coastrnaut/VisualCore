# Tasks: R02-G15-05 — Voxel Origami: progression and player teaching

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G15-05 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G15-05 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_445;
tests stay short (< 10 s each). No {owner} or {device} tasks. Model: feature 435's tasks, with its lessons taken into
the first pass (the tutorial's undo and redo behaviour documented exactly; a simulator check recorded only on an agent's
final copy; round02-host split by test bundle, since it reached 401 s at R02-G15-04).

## Phase 1: Setup

- [X] T-R02G1505-001 Baselines on the committed tree after R02-G15-04 is recorded: `--name baseline-host`, `--name — Verified 2026-11-24: 2026-11-24: baseline-host, baseline-timing, baseline-round02 exit 0 on the committed tree after R02-G15-04's record
  baseline-timing`, `--name baseline-round02 -- swift test --package-path Packages/ExperiencesRound02`; the rendering
  baseline is R02-G15-04's rendering runs (exit 0)

## Phase 2: Stories 2 and 3 — hints and failure explanation (P1) 🎯

- [X] T-R02G1505-002 [P] [US2] [US3] Add `plan(_:turns:maxTurns:workBound:)` to — Verified 2026-11-24: 2026-11-24: agent B solver entry plan(_:turns:) (plan(_:) delegates; witness files still byte-identical), VoxelOrigamiHints (three levels, stuck and failed texts), VoxelOrigamiFailureExplanation (collision, sweep, budget, action from 1); hints win all 100 levels (one case per level, max ~2.8 s), 200 seeded states, 500 seeded failures; lead retest host-2 exit 0
  `Packages/ExperiencesRound02/VoxelOrigami/Core/VoxelOrigamiSolver.swift` (the breadth-first search of
  `plan(_:maxTurns:workBound:)` from the given quarter turns — hinges in index order, −1 before +1, idle hinges,
  collisions and sweeps skipped; `plan(_:)` unchanged and equal to `plan(level, turns: level.startTurns)`; nil for turns
  of the wrong count, a pose that collides or a pose that already matches) and create
  `Packages/ExperiencesRound02/VoxelOrigami/Core/VoxelOrigamiHints.swift` (`VoxelOrigamiHintPlan`, `VoxelOrigamiHintKind`
  turn/stuck, `VoxelOrigamiHint` with levels 1 … 3 and the texts of clarification Q1 — "The next turn swings cube k"
  (k the hinge's tracked cube, `VoxelOrigamiPicker.trackedCube`), "Turn hinge h", "Turn hinge h forward (+1)" or "Turn
  hinge h back (−1)"; stuck "No way to win was found in the actions left: undo the last action or retry the level.";
  failed play "Undo the last action or retry the level."; won play nil — the plan is the minimal plan from the play's
  current turns, and nil unless its turns fit the actions left (and within the work bound); `VoxelOrigamiHints.plan`/
  `hint`; `VoxelOrigamiFailureExplanation` with the texts of clarification Q5 for `collision`, `sweep` and `budget`,
  actions numbered from 1, cubes and hinges by index and cells as (x, y, z), followed by "Undo the last action or retry
  the level.") with `Packages/ExperiencesRound02/VoxelOrigami/CoreTests/VoxelOrigamiHintsTests.swift` (following exact
  hints from the opening wins all 100 certified levels within their budget, in groups under 10 s each; 200 seeded
  reachable states (seed 2_445): every exact hint is accepted by the kernel; 500 seeded failures explained with their
  true action, cubes and cell; a hint never changes the play; `plan(_:)` equals the new entry at the start on all 100
  levels); agent B; `--name host-2`

## Phase 3: Stories 1 and 4 — tutorial and progress (P1, P2)

- [X] T-R02G1505-003 [P] [US1] [US4] Create `Packages/ExperiencesRound02/VoxelOrigami/Core/VoxelOrigamiProgress.swift` — Verified 2026-11-24: 2026-11-24: agent C tutorial steps (turn, compare, recover, done; undo never moves back, a redo to a finished play ends it), progress with stars and frontier, daily level (× 31, Hinnant day count, no clock), modes with practice budget 40; 15 tests (level 2's witness is one turn, so its tutorial goes to done on the winning turn); lead retest host-3 exit 0
  (`VoxelOrigamiTutorialStep` turn → compare → recover → done with the texts of clarification Q2, advanced by an
  accepted turn (turn → compare, compare → recover) or the level's end (→ done), never moved back by undo — documented
  exactly: an undo passes `afterTurn: false` and the play's real end (an undo always lands before the end, so it never
  ends the tutorial), a redo that restores a won or failed play ends it; `VoxelOrigamiProgress` "3 when at most the
  certified witness's turn count, 2 when at most that + 2, else 1" by actions spent (every accepted turn record, undone
  ones included), frontier with level 1 open, best actions spent per level, a better result replacing a worse one;
  `dailyLevel(year:month:day:)` "(days from 2026-01-01 × 31) mod 100 + 1, negative day counts wrapped", nil for an
  impossible date; `VoxelOrigamiMode` campaign, practice, daily(level)) with
  `Packages/ExperiencesRound02/VoxelOrigami/CoreTests/VoxelOrigamiProgressTests.swift` (tutorial steps on levels 1 … 3
  by scripted plays following the witnesses; stars and frontier over a 100-level script; every date 2026-01-01 …
  2036-12-31 gives a level in 1 … 100, stable; impossible dates nil; Codable round trips); agent C; `--name host-3`

## Phase 4: Adapter, scenarios, presenter

- [X] T-R02G1505-004 Edit `Packages/ExperiencesRound02/VoxelOrigami/Core/VoxelOrigamiExperienceCore.swift` (controls — Verified 2026-11-24: 2026-11-24: adapter controls level.select, mode.daily, mode.practice, mode.campaign, tutorial.dismiss; codes r02-g15.locked/date; progress, mode and tutorial; digest v2; snapshot schema 2 with migration from 1; scenarios (integration rows win first, level-100 rule, new refusals) and manifest regenerated; adapter tests updated; agent F 9 progression tests; identity test and registry comment; lead host-4 (VoxelOrigamiCoreTests) exit 0
  `level.select [1 … 100]`, `mode.daily [year, month, day]`, `mode.practice`, `mode.campaign`, `tutorial.dismiss`; codes
  `r02-g15.locked`, `r02-g15.date`; practice budget 40 on a copy of the level, no stars, no unlocks; a daily win records
  the level's best result and stars and opens nothing; progress and mode in the digest, the tutorial step snapshotted
  but not digested, the chosen hinge unchanged (presentation); snapshot schema 2 `{level, mode, progress, records,
  tutorial}` with a migration from 1 "level 1 open plus the restored level, campaign mode, tutorial at its first step on
  tutorial levels"; `level.next` to the next open level, refused with `r02-g15.locked` when none; no level is ever gated
  by payment — locked means not yet unlocked (FR-R02G1505-006)) with tests in
  `Packages/ExperiencesRound02/VoxelOrigami/CoreTests/VoxelOrigamiExperienceCoreTests.swift` (new controls, refusals,
  schema 2 round trip, migration from a schema-1 payload, newer schema refused); update
  `Packages/ExperiencesRound02/VoxelOrigami/Core/VoxelOrigamiScenarios.swift` where the new controls and the
  `level.next` rule change expectations and regenerate `Packages/ExperiencesRound02/VoxelOrigami/scenario-manifest.json`
  (`UPDATE_SCENARIO_MANIFEST=1`); update `VoxelOrigamiPanelWinTests`, the gesture wiring tests and other suites whose
  `level.next` expectation changes; lead; `--name host-4 -- swift test --package-path Packages/ExperiencesRound02
  --filter VoxelOrigamiCoreTests`
- [X] T-R02G1505-005 Edit `Packages/ExperiencesRound02/VoxelOrigami/Experience/VoxelOrigamiPresenter.swift` (the — Verified 2026-11-24: 2026-11-24: presenter tutorial instruction, hints (three levels from one off-main search, stale searches own nothing, hidden on any play change), failure explanation, goal with band and stars, retry/undo/daily; panel Hint, Dismiss, Undo, Retry, Campaign/Daily/Practice, level picker; agent D 6 teaching tests; 36 simulator tests, no warnings; sim-27 exit 0
  tutorial instruction, the hint at its current level — "Hint" raises the level 1 → 2 → 3, any play change resets it,
  the search off the main actor and a stale search never owning the hint state — and the failure explanation as panel
  text, with the level's difficulty band (of the five bands of 20), its goal and its best stars (FR-R02G1505-004); the
  description includes them) and `Packages/ExperiencesRound02/VoxelOrigami/Experience/VoxelOrigamiControls.swift`
  (Hint, Dismiss tutorial, level picker for open levels, Practice, Daily (today's local date from the presenter),
  Campaign); agent D writes `Packages/ExperiencesRound02/VoxelOrigami/ExperienceTests/VoxelOrigamiTeachingTests.swift`
  (the panel shows the tutorial, the three hint levels, the failure text, the band and the stars; mode and level
  controls reach the adapter; a refusal reads in words), given the presenter's exact texts; `--name sim-27 -- python3
  scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination
  sim-27.2 --action test --only-testing VoxelOrigamiExperienceTests`

## Phase 5: Regression, documentation and close

- [X] T-R02G1505-006 Docs: `docs/architecture/voxel-origami.md` (teaching and progression), — Verified 2026-11-24: 2026-11-24: architecture teaching section, ExperiencesRound02 README, testing doc; round02-host in two chunks: round02-host-1 (VoxelOrigami) exit 0 in 57 s, round02-host-2 (the rest) exit 0 in 450 s (split again from R02-G15-06)
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host` (split by test bundle:
  Voxel Origami's suites and the rest, each under 450 s)
- [X] T-R02G1505-007 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-24: 2026-11-24: rendering-27, rendering-26, experiences, host-full, app-unit exit 0
  `--name host-full`, `--name app-unit`
- [ ] T-R02G1505-008 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G1505-009 Reference regression chunk 2 (`--name reference-2`)
- [X] T-R02G1505-010 Script tests, run alone (`--name script-tests`) — Verified 2026-11-24: 2026-11-24: script-tests exit 0, run alone before the chain
- [ ] T-R02G1505-011 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → {002 (agent B), 003 (agent C)} → 004 (lead) → 005 (lead; agent D writes the teaching tests) → 006 … 011. Shared
files (adapter, scenarios, presenter, controls, docs) stay with the lead. Agents B and C may start in isolated copies
before 001, since their files are new or untouched by R02-G15-04 (the solver is untouched there). MVP: Stories 1–3
(tutorial, hints, failure text); Story 4 (progress, daily, practice) follows in the same gate. Requirement coverage:
FR-001 → 003, 005; FR-002, 003 → 002, 005; FR-004, 005 → 003, 004, 005; FR-006 → 004; FR-007 → 004, 006 … 011.
