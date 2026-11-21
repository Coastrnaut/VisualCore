# Tasks: R02-G05-05 — Colorfall Canyons: progression and player teaching

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G05-05 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G05-05 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_345;
tests stay short (< 10 s each). No {owner} or {device} tasks; no GLSL change (the CPU reference and shaders of
R02-G05-03 are unchanged).

## Phase 1: Setup

- [X] T-R02G0505-001 Baselines: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02 -- swift test — Verified 2026-11-21: 2026-11-21 baseline-host, baseline-timing, baseline-round02 exit 0 (.autonomy/migration/checks/R02-G05-05.baseline-*.json); rendering baseline: R02-G05-04 rendering-27/26 exit 0
  --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G05-04's rendering runs (exit 0)

## Phase 2: Stories 2 and 3 — hints and failure explanations (P1) 🎯

- [X] T-R02G0505-002 [P] [US2] [US3] Add `ColorfallCanyonsSolver.plan(_:from:budget:)` to — Verified 2026-11-21: 2026-11-21 host exit 0: hints 18 + catalog 7 (pinned digest and witnesses unchanged) + solver 13 XCTest; exact hints win all 100 levels; 200 seeded states (111 with a plan won by hints, 89 stuck); 500 failures explained; plan from start equals solve (.autonomy/migration/checks/R02-G05-05.host.json); lead retest
  `Packages/ExperiencesRound02/ColorfallCanyons/Core/ColorfallCanyonsSolver.swift` ("edit sets applied now, size 0 … min(budget, 3), in the
  solver's order with routing-key deduplication and reachability pruning from the current fluid; the returned set re-run
  through the kernel"; `solve(_:depth:)` results unchanged) and create
  `Packages/ExperiencesRound02/ColorfallCanyons/Core/ColorfallCanyonsHints.swift` (ColorfallCanyonsHint "levels 1 … 3: what, where (row), exact";
  kinds carve, valve, run, stuck with the texts of clarification Q1; "playing and paused: the plan's hint; failed: kind
  stuck; won or other stages: nil"; ColorfallCanyonsFailureExplanation "contamination: Basin k (row r, column c) took n
  units of <colour>; it allows at most m. / overflow: Basin k overflowed: v units, its capacity is c. / time: Time ran out
  at tick T: basin k holds <amounts>; it needs <target>.", each followed by "Undo the last change or retry the level.")
  with `Packages/ExperiencesRound02/ColorfallCanyons/CoreTests/ColorfallCanyonsHintsTests.swift` (agent B: exact hints from the start win all 100
  certified levels; 200 seeded reachable states: every exact hint is legal and from every state with a plan following
  hints wins; a state without a plan gets kind stuck; hint levels agree; 500 seeded failures explained with the true
  basin, colour and amounts; the catalog digest and every certified solution unchanged; measured hint time reported);
  `--name host`

## Phase 3: Stories 1 and 4 — tutorial, progress, daily, practice (P1, P2)

- [X] T-R02G0505-003 [P] [US1] [US4] Create `Packages/ExperiencesRound02/ColorfallCanyons/Core/ColorfallCanyonsProgress.swift` (ColorfallCanyonsTutorialStep — Verified 2026-11-21: 2026-11-21 host-2 exit 0: 17 tests in 0.07 s (tutorial steps steer/run/fill/done on levels 1-3 from certified solutions; undo/redo never move it; stars 3/2/1; scripted campaign through 100 levels; daily x 53 for every date 2026-2036 and 100-day coverage; impossible dates refused; practice/daily rules; Codable) (.autonomy/migration/checks/R02-G05-05.host-2.json); lead retest, campaign test made synthetic
  "steer → run (an edit was accepted and the plan is empty — the caller passes `planEmpty`) → fill (an accepted step) →
  done (the level ends); dismiss → done; undo never moves it back" with the texts of clarification Q2; ColorfallCanyonsMode "campaign, practice,
  daily(level)"; ColorfallCanyonsProgress "level 1 open; a campaign win opens the next; a better result replaces a worse
  one; stars 3 at most smallest actions, 2 at most smallest + 2, else 1"; dailyLevel "(days from 2026-01-01 × 53) mod 100
  + 1, negative counts wrapped; nil for an impossible date") with
  `Packages/ExperiencesRound02/ColorfallCanyons/CoreTests/ColorfallCanyonsProgressTests.swift` (agent C: tutorial transitions on levels 1 … 3 driven by the
  certified solutions with `planEmpty` given, every step seen in order; scripted progress through 100 levels; stars; every date 2026-01-01 …
  2036-12-31 maps to 1 … 100 and 100 consecutive days visit every level; impossible dates refused); `--name host-2`

## Phase 4: Adapter, scenarios and panel

- [X] T-R02G0505-004 [US1] [US2] [US3] [US4] Edit `Packages/ExperiencesRound02/ColorfallCanyons/Core/ColorfallCanyonsExperienceCore.swift` (controls — Verified 2026-11-21: 2026-11-21 host-3 exit 0: 85 tests in 7 suites (adapter schema 2 with 1 -> 2 migration, digest v2 with progress and mode, level.select/next/modes/tutorial.dismiss with r02-g05.locked/date, practice budget 30, daily without unlocking, wins record stars, scripted tutorial players win levels 1-3; scenario manifest regenerated; hint seeded tests split in 8) (.autonomy/migration/checks/R02-G05-05.host-3.json); lead retest
  "level.select [1 … 100], mode.daily [year, month, day], mode.practice, mode.campaign, tutorial.dismiss"; practice budget
  30; daily wins record results without opening levels and a locked daily level is playable; level.next to the next open
  level, refused when none; the tutorial on levels 1 … 3 in every mode; progress and mode in the digest, the tutorial step
  in the snapshot only; snapshot schema 2 `{level, records, progress, mode, tutorial}` with a 1 → 2 migration; codes
  r02-g05.locked, r02-g05.date), `Packages/ExperiencesRound02/ColorfallCanyons/Core/ColorfallCanyonsScenarios.swift` and the regenerated
  `Packages/ExperiencesRound02/ColorfallCanyons/scenario-manifest.json`, with
  `Packages/ExperiencesRound02/ColorfallCanyons/CoreTests/ColorfallCanyonsExperienceCoreTests.swift` updates (conformance; actions; migration of a
  schema-1 payload; undo restores the digest with the tutorial advanced; (schema examples are registered with the in-app integration, R02-G05-09, as for Hue Compass); on levels 1 … 3 a
  scripted player following each instruction and the exact hints wins (SC-R02G0505-001); scenarios that use level.next
  (now the next open level) regenerated and replayed); `--name host-3`
- [X] T-R02G0505-005 [US1] [US2] [US3] [US4] Edit `Packages/ExperiencesRound02/ColorfallCanyons/Experience/ColorfallCanyonsPresenter.swift` and — Verified 2026-11-21: 2026-11-21 sim-27 exit 0: ColorfallCanyonsExperienceTests 35 tests in 6 suites on sim-27.2 incl. 5 teaching tests (tutorial and dismiss, hint levels, failure text with undo and retry, locked picker, daily and practice, win records stars) (.autonomy/migration/checks/R02-G05-05.sim-27.json); lead run
  `Packages/ExperiencesRound02/ColorfallCanyons/Experience/ColorfallCanyonsControls.swift` (instruction with Dismiss; Hint revealing the next level, reset
  after any change of the play; failure explanation with Undo and Retry; level picker of open levels with bands and
  stars; Campaign / Daily (local calendar date) / Practice; all as wrapping panel text) and create
  `Packages/ExperiencesRound02/ColorfallCanyons/ExperienceTests/ColorfallCanyonsTeachingTests.swift` (agent D: hint levels through the presenter,
  failure text, picker refusals, daily and practice through the port, the tutorial on level 1); `--name sim-27`

## Phase 5: Regression, documentation and close

- [ ] T-R02G0505-006 Docs: `docs/architecture/colorfall-canyons.md` (teaching and progression),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`
- [ ] T-R02G0505-007 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`, `--name app-unit`
- [ ] T-R02G0505-008 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G0505-009 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G0505-010 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G0505-011 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → {002 (agent B), 003 (agent C)} → 004 (lead) → 005 (lead; agent D writes the simulator tests) → 006 … 011. Shared
files (adapter, scenarios, presenter, controls, docs) stay with the lead. MVP: Stories 1–3.
