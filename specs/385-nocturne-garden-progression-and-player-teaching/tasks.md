# Tasks: R02-G09-05 — Nocturne Garden: progression and player teaching

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G09-05 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G09-05 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_385;
tests stay short (< 10 s each). No {owner} or {device} tasks.

## Phase 1: Setup

- [X] T-R02G0905-001 Baselines on the committed tree: `--name baseline-host`, `--name baseline-timing`, `--name — Verified 2026-11-22: baseline-host, baseline-timing, baseline-round02 exit=0 on the committed tree (the feature's work held aside); rendering baseline is R02-G09-04's rendering runs (exit 0)
  baseline-round02 -- swift test --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G09-04's
  rendering runs (exit 0)

## Phase 2: Stories 2 and 3 — hints and failure explanation (P1) 🎯

- [X] T-R02G0905-002 [P] [US2] [US3] Add `solve(_:from:sun:movesLeft:supplyLeft:workBound:)` to — Verified 2026-11-22: host-2 exit=0 (25 tests: NocturneGardenHintsTests 7 — following exact hints from the opening wins all 100 levels at their certified move counts (max work 12,404), 200 seeded states get legal hints that win where a plan exists, a spoiling bloom is hinted away, hint texts per level, hints follow the stage, 500 seeded failures explained; solver and invariant suites unchanged; the search orders elevations as certification does (spec Q1 corrected); agent B's files retested by the lead)
  `Packages/ExperiencesRound02/NocturneGarden/Core/NocturneGardenSolver.swift` (the solver's bounded depth-first search started at the given blooms and sun,
  looking for the fewest further moves within the moves and supply left: plants at the current sun, then a sun move
  first, then the removal of one planted bloom (canonical order) first; `solve(_:workBound:)` unchanged) and create
  `Packages/ExperiencesRound02/NocturneGarden/Core/NocturneGardenHints.swift` (`NocturneGardenPlan`, `NocturneGardenHint` with levels 1 … 3 and the texts of
  clarification Q1, `NocturneGardenHints.plan`/`hint`, `NocturneGardenFailureExplanation` with the texts of
  clarification Q5) with `Packages/ExperiencesRound02/NocturneGarden/CoreTests/NocturneGardenHintsTests.swift` (following exact hints from the opening wins all
  100 certified levels, in parallel groups under 10 s each; 200 seeded reachable states (seed 2_385): every exact hint is
  a legal move, from every state with a plan following hints wins; 500 seeded failures explained with their true reason,
  move and counts; a hint never changes the play); agent B; `--name host-2`

## Phase 3: Stories 1 and 4 — tutorial and progress (P1, P2)

- [X] T-R02G0905-003 [P] [US1] [US4] Create `Packages/ExperiencesRound02/NocturneGarden/Core/NocturneGardenProgress.swift` (`NocturneGardenTutorialStep` plant → — Verified 2026-11-22: host-3 exit=0 (NocturneGardenProgressTests 11: tutorial steps on levels 1-3, undo and redo never move the step back, stars by moves made, a 100-level progress script, every day of 2026-2036 maps into 1-100 and is stable, negative day counts wrap, impossible dates refused, Codable round trips; agent C's files retested by the lead)
  shape → finish → done with the texts of clarification Q2; `NocturneGardenProgress` "3 when at most the certified
  smallest move count, 2 when at most that + 2, else 1" by moves made (action records, undone ones included), frontier,
  best moves made; `dailyLevel(year:month:day:)` "(days from 2026-01-01 × 71) mod 100 + 1, negative day counts
  wrapped", nil for an impossible date; `NocturneGardenMode` campaign, practice, daily(level)) with
  `Packages/ExperiencesRound02/NocturneGarden/CoreTests/NocturneGardenProgressTests.swift` (tutorial steps on levels 1 … 3 by scripted plays; stars and frontier
  over a 100-level script; every date 2026-01-01 … 2036-12-31 gives a level in 1 … 100, stable; impossible dates nil);
  agent C; `--name host-3`

## Phase 4: Adapter, scenarios, presenter

- [X] T-R02G0905-004 Edit `Packages/ExperiencesRound02/NocturneGarden/Core/NocturneGardenExperienceCore.swift` (controls `level.select [1 … 100]`, `mode.daily — Verified 2026-11-22: host-4 exit=0 (179 Nocturne Garden host tests: adapter controls level.select, mode.daily, mode.practice, mode.campaign, tutorial.dismiss with r02-g09.locked and r02-g09.date, practice budget 40, campaign win opens the next level with stars, daily records without unlocking, schema 2 round trip and migration from schema 1, newer schema refused, digest carries progress and mode but not the tutorial; scenario manifest regenerated; agent F's files retested by the lead)
  [year, month, day]`, `mode.practice`, `mode.campaign`, `tutorial.dismiss`; codes `r02-g09.locked`,
  `r02-g09.date`; practice budget 40 on a copy of the level, no stars, no unlocks; a daily win records the level's best
  result and stars and opens nothing; progress and mode in the digest, the tutorial step snapshotted but not digested;
  snapshot schema 2 `{level, records, progress, mode, tutorial}` with a migration from 1 "level 1 open plus the restored
  level, campaign mode, tutorial at its first step on tutorial levels"; `level.next` to the next open level) with tests
  in `Packages/ExperiencesRound02/NocturneGarden/CoreTests/NocturneGardenExperienceCoreTests.swift` (new controls, refusals, schema 2 round trip, migration from a
  schema-1 payload, newer schema refused); regenerate `Packages/ExperiencesRound02/NocturneGarden/Core/NocturneGardenScenarios.swift` entries where needed and
  `Packages/ExperiencesRound02/NocturneGarden/scenario-manifest.json` (`UPDATE_SCENARIO_MANIFEST=1`); lead; `--name host-4 -- swift test --package-path
  Packages/ExperiencesRound02 --filter NocturneGarden`
- [X] T-R02G0905-005 Edit `Packages/ExperiencesRound02/NocturneGarden/Experience/NocturneGardenPresenter.swift` (the tutorial instruction, the hint at its current — Verified 2026-11-22: sim-27 exit=65 (an identity test still expected the kernel's raw leak reason; the description now gives the failure explanation by design, test updated), sim-27-2 exit=0 (45 simulator tests incl. NocturneGardenTeachingTests 5: tutorial shown and dismissed, three hint levels equal the Core's and following them wins level 1, a budget failure explained with Undo and Retry, a campaign win records stars and opens the next level with a locked level refused, practice, daily and campaign modes); the hint search runs off the main actor and a stale search no longer owns the hint state (found by agent D); agent D's tests retested by the lead
  level — "Hint" raises the level 1 → 2 → 3, any play change resets it, the search off the main actor — and the failure
  explanation as panel text; the description includes them) and `Packages/ExperiencesRound02/NocturneGarden/Experience/NocturneGardenControls.swift` (Hint,
  Dismiss tutorial, level picker for open levels, Practice, Daily (today's local date from the presenter), Campaign);
  agent D writes `Packages/ExperiencesRound02/NocturneGarden/ExperienceTests/NocturneGardenTeachingTests.swift` (the panel shows the tutorial, the three hint
  levels and the failure text; mode and level controls reach the adapter); `--name sim-27 -- python3
  scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination
  sim-27.2 --action test --only-testing NocturneGardenExperienceTests`

## Phase 5: Regression, documentation and close

- [X] T-R02G0905-006 Docs: `docs/architecture/nocturne-garden.md` (teaching and progression), — Verified 2026-11-22: round02-host (swift test --package-path Packages/ExperiencesRound02) exit 0; docs/architecture/nocturne-garden.md teaching and progression, ExperiencesRound02 README feature 385, docs/automatedtesting.md entry; validate_docs passes
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`
- [X] T-R02G0905-007 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-22: rendering-27, rendering-26, experiences, host-full, app-unit exit=0
  `--name host-full`, `--name app-unit`
- [X] T-R02G0905-008 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-22: reference-1 exit=0
- [X] T-R02G0905-009 Reference regression chunk 2 (`--name reference-2`) — Verified 2026-11-22: reference-2 exit=0
- [X] T-R02G0905-010 Script tests, run alone (`--name script-tests`) — Verified 2026-11-22: script-tests exit=0 (run alone)
- [ ] T-R02G0905-011 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → {002 (agent B), 003 (agent C)} → 004 (lead) → 005 (lead; agent D writes the teaching tests) → 006 … 011. Shared
files (adapter, scenarios, presenter, controls, docs) stay with the lead. MVP: Stories 1–3.
