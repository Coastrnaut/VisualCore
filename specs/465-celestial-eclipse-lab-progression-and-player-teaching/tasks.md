# Tasks: R02-G17-05 — Celestial Eclipse Lab: progression and player teaching

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G17-05 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G17-05 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_465;
tests stay short (< 10 s each). No {owner} or {device} tasks.

## Phase 1: Setup

- [X] T-R02G1705-001 Baselines on the committed tree after R02-G17-04 is recorded: `--name baseline-host`, `--name — Verified 2026-11-25: 2026-11-25 baseline-host, baseline-timing and round02-1, -2, -3c, -3e, -3f exit 0; rendering baseline is R02-G17-04's rendering runs (exit 0)
  baseline-timing`, `--name baseline-round02-1`, `-2`, `-3c`, `-3e`, `-3f`; the rendering baseline is R02-G17-04's
  rendering runs (exit 0)

## Phase 2: Stories 2 and 3 — hints and failure explanation (P1) 🎯

- [X] T-R02G1705-002 [P] [US2] [US3] Add `plan(_:from:maxChanges:workBound:)` to — Verified 2026-11-25: 2026-11-25 solver plan(_:from:) from given phases, hints (three levels, run, stuck, failed) and failure explanations (unwanted, window, horizon); hint tests pass incl. exact hints winning all 100 levels, 200 seeded states, 500 seeded failures (host-2 exit 0)
  `Packages/ExperiencesRound02/CelestialEclipseLab/Core/CelestialEclipseLabSolver.swift` (the search of
  `plan(_:maxChanges:workBound:)` from the given phases — subsets of movable bodies, then phases, in lexicographic
  order, each phase differing from the given one; `plan(_:)` unchanged and equal to `plan(level, from: level.phases)`; a
  plan of no changes when the given phases already win; nil for a phase vector of the wrong length or out of range) and
  create `Packages/ExperiencesRound02/CelestialEclipseLab/Core/CelestialEclipseLabHints.swift`
  (`CelestialEclipseLabHintPlan`, `CelestialEclipseLabHintKind` change/run/stuck, `CelestialEclipseLabHint` with levels
  1 … 3 and the texts of clarification Q1 — "Move planet b next", "Move planet b k steps forward" or "back" (1 step
  singular; the shorter way around its orbit, forward on a tie), "Set planet b to phase p"; already in order "The
  eclipses are in order: run the clock"; stuck "No way to win was found in the actions left: undo the last action or
  retry the level."; failed play "Undo the last action or retry the level."; won play nil — the plan is the minimal plan
  from the play's current phases within min(actions left, 5) changes and the work bound;
  `CelestialEclipseLabHints.plan`/`hint`; `CelestialEclipseLabFailureExplanation` with the texts of clarification Q5 for
  `unwanted`, `window` and `horizon`, targets numbered from 1 and planets by index, followed by "Undo the last action or
  retry the level.") with
  `Packages/ExperiencesRound02/CelestialEclipseLab/CoreTests/CelestialEclipseLabHintsTests.swift` (following exact hints
  from the opening, then the run, wins all 100 certified levels within their budget, in groups under 10 s each; 200
  seeded reachable states (seed 2_465): every exact hint is accepted by the kernel; 500 seeded failures explained with
  their true planets, target and ticks; a hint never changes the play; `plan(_:)` equals the new entry at the opening on
  all 100 levels); agent B; `--name host-2`

## Phase 3: Stories 1 and 4 — tutorial and progress (P1, P2)

- [X] T-R02G1705-003 [P] [US1] [US4] Create — Verified 2026-11-25: 2026-11-25 tutorial steps, progress with stars and frontier, daily level x 29, modes; 16 progress tests pass (host-3 exit 0)
  `Packages/ExperiencesRound02/CelestialEclipseLab/Core/CelestialEclipseLabProgress.swift`
  (`CelestialEclipseLabTutorialStep` phase → order → recover → done with the texts of clarification Q2, advanced by an
  accepted phase change (phase → order, order → recover) or the level's end (→ done), never moved back by undo — an undo
  passes `afterChange: false` and the play's real end, a redo that restores a won or failed play ends it;
  `CelestialEclipseLabProgress` "3 when at most the certified witness's change count, 2 when at most that + 2, else 1"
  by actions spent (every accepted phase-change record, undone ones included), frontier with level 1 open, best actions
  spent per level, a better result replacing a worse one; `dailyLevel(year:month:day:)` "(days from 2026-01-01 × 29) mod
  100 + 1, negative day counts wrapped", nil for an impossible date; `CelestialEclipseLabMode` campaign, practice,
  daily(level)) with `Packages/ExperiencesRound02/CelestialEclipseLab/CoreTests/CelestialEclipseLabProgressTests.swift`
  (tutorial steps on levels 1 … 3 by scripted plays following the witnesses; stars and frontier over a 100-level script;
  every date 2026-01-01 … 2036-12-31 gives a level in 1 … 100, stable; impossible dates nil; Codable round trips); agent
  C; `--name host-3`

## Phase 4: Adapter, scenarios, presenter

- [X] T-R02G1705-004 Edit `Packages/ExperiencesRound02/CelestialEclipseLab/Core/CelestialEclipseLabExperienceCore.swift` — Verified 2026-11-25: 2026-11-25 adapter controls level.select, mode.daily, mode.practice, mode.campaign, tutorial.dismiss; codes r02-g17.locked and r02-g17.date; practice budget 24; progress and mode digested; snapshot schema 2 with migration from 1; level.next to the next open level; scenarios updated and manifest regenerated; 192 CelestialEclipseLab host tests pass (host-4 exit 0)
  (controls `level.select [1 … 100]`, `mode.daily [year, month, day]`, `mode.practice`, `mode.campaign`,
  `tutorial.dismiss`; codes `r02-g17.locked`, `r02-g17.date`; practice budget 24 on a copy of the level, no stars, no
  unlocks; the daily level is playable even while still locked in the campaign, and a daily win records the level's best
  result and stars and opens nothing; progress and mode in the digest, the tutorial step snapshotted but not digested,
  the chosen body and shown tick unchanged (presentation); snapshot schema 2 `{level, mode, progress, records,
  tutorial}` with a migration from 1 "level 1 open plus the restored level, campaign mode, tutorial at its first step on
  tutorial levels"; `level.next` to the next open level, refused with `r02-g17.locked` when none; no level is ever gated
  by payment — locked means not yet unlocked (FR-R02G1705-006)) with tests in
  `Packages/ExperiencesRound02/CelestialEclipseLab/CoreTests/CelestialEclipseLabExperienceCoreTests.swift` (new
  controls, refusals, a locked daily level played without opening it, schema 2 round trip, migration from a schema-1
  payload, newer schema refused); update
  `Packages/ExperiencesRound02/CelestialEclipseLab/Core/CelestialEclipseLabScenarios.swift` where the new controls and
  the `level.next` rule change expectations and regenerate
  `Packages/ExperiencesRound02/CelestialEclipseLab/scenario-manifest.json` (`UPDATE_SCENARIO_MANIFEST=1`); update
  `CelestialEclipseLabPanelWinTests`, the gesture wiring tests and other suites whose `level.next` expectation changes;
  lead; `--name host-4 -- swift test --package-path Packages/ExperiencesRound02 --filter CelestialEclipseLab`
- [X] T-R02G1705-005 Edit — Verified 2026-11-25: 2026-11-25 presenter tutorial, three hint levels searched off the main actor with a generation guard, failure explanation, band, goal and stars; panel Hint, Dismiss tutorial, level picker, Practice, Daily, Campaign; teaching tests; identity test and registry comment updated for schema 2; sim-27 42 tests exit 0 (sim-27a failed only on the identity test's old control list)
  `Packages/ExperiencesRound02/CelestialEclipseLab/Experience/CelestialEclipseLabPresenter.swift` (the tutorial
  instruction, the hint at its current level — "Hint" raises the level 1 → 2 → 3, any play change resets it, the search
  off the main actor and a stale search never owning the hint state — and the failure explanation as panel text, with
  the level's difficulty band (of the five bands of 20), its goal and its best stars (FR-R02G1705-004); the description
  includes them) and `Packages/ExperiencesRound02/CelestialEclipseLab/Experience/CelestialEclipseLabControls.swift`
  (Hint, Dismiss tutorial, level picker for open levels, Practice, Daily (today's local date from the presenter),
  Campaign); agent D writes
  `Packages/ExperiencesRound02/CelestialEclipseLab/ExperienceTests/CelestialEclipseLabTeachingTests.swift` (the panel
  shows the tutorial, the three hint levels, the failure text, the band and the stars; mode and level controls reach the
  adapter; a refusal reads in words), given the presenter's exact texts; `--name sim-27 -- python3
  scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination
  sim-27.2 --action test --only-testing CelestialEclipseLabExperienceTests`

## Phase 5: Regression, documentation and close

- [X] T-R02G1705-006 Docs: `docs/architecture/celestial-eclipse-lab.md` (teaching and progression), — Verified 2026-11-25: 2026-11-25 architecture teaching section, round-two README, automatedtesting entry; round02-host-1, -2, -3c, -3e, -3f exit 0 (.autonomy/migration/checks/R02-G17-05.round02-host-*.json)
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host-1`, `-2`, `-3c`, `-3e`,
  `-3f`
- [X] T-R02G1705-007 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-25: 2026-11-25 rendering-27, rendering-26, experiences, host-full, app-unit exit 0 (.autonomy/migration/checks/R02-G17-05.*.json)
  `--name host-full`, `--name app-unit`
- [X] T-R02G1705-008 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-25: 2026-11-25 reference-1 exit 0 (.autonomy/migration/checks/R02-G17-05.reference-1.json)
- [X] T-R02G1705-009 Reference regression chunk 2 (`--name reference-2`) — Verified 2026-11-25: 2026-11-25 reference-2 exit 0 (.autonomy/migration/checks/R02-G17-05.reference-2.json)
- [X] T-R02G1705-010 Script tests, run alone (`--name script-tests`) — Verified 2026-11-25: 2026-11-25 script tests run alone exit 0 (.autonomy/migration/checks/R02-G17-05.script-tests.json)
- [X] T-R02G1705-011 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record; — Verified 2026-11-25: 2026-11-25 /speckit-converge: converged (nothing appended); README row, feature count 165 and gate list updated
  README row and gate list updated

## Dependencies and parallel work

001 → {002 (agent B), 003 (agent C)} → 004 (lead) → 005 (lead; agent D writes the teaching tests) → 006 … 010, 011.
Agents may draft in isolated copies before 001 (new files only). MVP: Stories 2 and 3. Requirement coverage: FR-001 →
003, 005; FR-002 → 002, 005; FR-003 → 002, 005; FR-004 → 003, 004, 005; FR-005 → 003, 004; FR-006 → 004; FR-007 →
004, 006 … 010.
