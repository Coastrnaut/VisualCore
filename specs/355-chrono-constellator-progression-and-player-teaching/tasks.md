# Tasks: R02-G06-05 — Chrono Constellator: progression and player teaching

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G06-05 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G06-05 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_355;
tests stay short (< 10 s each). No {owner} or {device} tasks; no GLSL change (the CPU reference and shaders of
R02-G06-03 are unchanged).

## Phase 1: Setup

- [X] T-R02G0605-001 Baselines: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02 -- swift test — Verified 2026-11-21: 2026-11-21: baseline-host, baseline-timing, baseline-round02 exit 0; rendering baseline = R02-G06-04 rendering-27/26 exit 0
  --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G06-04's rendering runs (exit 0)

## Phase 2: Stories 2 and 3 — hints and failure explanations (P1) 🎯

- [X] T-R02G0605-002 [P] [US2] [US3] Create `Packages/ExperiencesRound02/ChronoConstellator/Core/ChronoConstellatorHints.swift` (ChronoConstellatorPlan "run(ticks), — Verified 2026-11-21: 2026-11-21: host (ChronoConstellatorHintsTests, 12 tests: exact hints win all 100 levels; opening plan = certified solution; 200 seeded states, hint stuck iff no plan, following hints wins; 500 seeded failures explained; slowest hint 66 ms) exit 0, lead retest; rewind/release gated on a plan (spec Q1 updated)
  rewind, release(star, start), phases"; `plan(_:)` "a winning current timeline: run (ticks to the win tick from the
  current tick); after tick 0 otherwise: rewind; at tick 0 with holds: release the first hold (star order, then start);
  else the solver on the level with the current phases as defaults, accepted only if the edits in use afterwards fit the
  budget and the timeline wins; else nil"; ChronoConstellatorHint "levels 1 … 3" with kinds phase, release, rewind, run,
  stuck and the texts of clarification Q1; "playing and paused: the plan's hint; failed: kind stuck; won or other
  stages: nil"; ChronoConstellatorFailureExplanation "collision: Star a (shape) and star b (shape) met at row r, column c
  on tick T. / time: Time ran out at tick T: star k (shape) is at row r, column c, its target is row r′, column c′ (joined
  by "; ").", each followed by "Undo the last change, rewind or retry the level.") with
  `Packages/ExperiencesRound02/ChronoConstellator/CoreTests/ChronoConstellatorHintsTests.swift` (agent B: exact hints from the start win all 100 certified levels;
  200 seeded reachable states: every exact hint is a legal action and from every state with a plan following hints wins;
  a state without a plan gets kind stuck; hint levels agree; 500 seeded failures explained with the true stars, cell and
  tick; measured hint time reported); `--name host`

## Phase 3: Stories 1 and 4 — tutorial, progress, daily, practice (P1, P2)

- [X] T-R02G0605-003 [P] [US1] [US4] Create `Packages/ExperiencesRound02/ChronoConstellator/Core/ChronoConstellatorProgress.swift` (ChronoConstellatorTutorialStep — Verified 2026-11-21: 2026-11-21: host-2 (ChronoConstellatorProgressTests, 9 tests: tutorial on levels 1-3 via certified solutions, 100-level progress, stars, daily for 4,018 dates, impossible dates, Codable) exit 0, lead retest
  "shift → replay (a phase change was accepted and the plan is a run — the caller passes `planIsRun`) → align (an
  accepted step) → done (the level ends); dismiss → done; undo never moves it back" with the texts of clarification Q2;
  ChronoConstellatorMode "campaign, practice, daily(level)"; ChronoConstellatorProgress "level 1 open; a campaign win
  opens the next; a better result replaces a worse one; stars 3 at most smallest edits, 2 at most smallest + 2, else 1";
  dailyLevel "(days from 2026-01-01 × 59) mod 100 + 1, negative counts wrapped; nil for an impossible date") with
  `Packages/ExperiencesRound02/ChronoConstellator/CoreTests/ChronoConstellatorProgressTests.swift` (agent C: tutorial transitions on levels 1 … 3 driven by the
  certified solutions with `planIsRun` given, every step seen in order; scripted progress through 100 levels; stars;
  every date 2026-01-01 … 2036-12-31 maps to 1 … 100 and 100 consecutive days visit every level; impossible dates
  refused); `--name host-2`

## Phase 4: Adapter, scenarios and panel

- [X] T-R02G0605-004 [US1] [US2] [US3] [US4] Edit `Packages/ExperiencesRound02/ChronoConstellator/Core/ChronoConstellatorExperienceCore.swift` (controls "level.select — Verified 2026-11-21: 2026-11-21: host-3 (swift test --filter ChronoConstellator, 180 tests in 19 suites: adapter schema 2 with migration, modes, locked/date refusals, tutorial+hints player wins levels 1-3, regenerated manifest) exit 0
  [1 … 100], mode.daily [year, month, day], mode.practice, mode.campaign, tutorial.dismiss"; practice budget 20; daily
  wins record results without opening levels and a locked daily level is playable; level.next to the next open level,
  refused when none; the tutorial on levels 1 … 3 in every mode; progress and mode in the digest, the tutorial step in
  the snapshot only; snapshot schema 2 `{level, records, progress, mode, tutorial}` with a 1 → 2 migration; codes
  r02-g06.locked, r02-g06.date), `Packages/ExperiencesRound02/ChronoConstellator/Core/ChronoConstellatorScenarios.swift` and the regenerated
  `Packages/ExperiencesRound02/ChronoConstellator/scenario-manifest.json`, with `Packages/ExperiencesRound02/ChronoConstellator/CoreTests/ChronoConstellatorExperienceCoreTests.swift` updates (conformance;
  actions; migration of a schema-1 payload; undo restores the digest with the tutorial advanced; on levels 1 … 3 a
  scripted player following each instruction and the exact hints wins (SC-R02G0605-001); scenarios that use level.next
  regenerated and replayed; the schema-1 example is registered at R02-G06-09); `--name host-3`
- [X] T-R02G0605-005 [US1] [US2] [US3] [US4] Edit `Packages/ExperiencesRound02/ChronoConstellator/Experience/ChronoConstellatorPresenter.swift` and — Verified 2026-11-21: 2026-11-21: sim-27 (ChronoConstellatorExperienceTests, 37 tests in 6 suites on iOS 27.2 incl. 4 teaching tests: tutorial, hint levels, failure undo/rewind/retry, picker refusal, daily and practice) exit 0
  `Packages/ExperiencesRound02/ChronoConstellator/Experience/ChronoConstellatorControls.swift` (instruction with Dismiss; Hint revealing the next level, reset after
  any change of the play; failure explanation with Undo, Rewind and Retry; level picker of open levels with bands and
  stars; Campaign / Daily (local calendar date) / Practice; all as wrapping panel text) and create
  `Packages/ExperiencesRound02/ChronoConstellator/ExperienceTests/ChronoConstellatorTeachingTests.swift` (agent D: hint levels through the presenter, failure text,
  picker refusals, daily and practice through the port, the tutorial on level 1); `--name sim-27 -- python3
  scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination
  sim-27.2 --action test --only-testing ChronoConstellatorExperienceTests`

## Phase 5: Regression, documentation and close

- [ ] T-R02G0605-006 Docs: `docs/architecture/chrono-constellator.md` (teaching and progression),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`
- [ ] T-R02G0605-007 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`, `--name app-unit`, plus `--name catalog-search` if `Catalog/registrations.json` changes
- [ ] T-R02G0605-008 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G0605-009 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G0605-010 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G0605-011 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → {002 (agent B), 003 (agent C)} → 004 (lead) → 005 (lead; agent D writes the simulator tests) → 006 … 011. Shared
files (adapter, scenarios, presenter, controls, docs) stay with the lead. MVP: Stories 1–3.
