# Tasks: R02-G20-05 — Mushroom Weather: progression and player teaching

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G20-05 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G20-05 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_495;
tests stay short (< 10 s each). No {owner} or {device} tasks (the spec names no device-only item; the round's device
campaign covers the game). Agents model their files on Microscopic Aurora's (feature 485).

## Phase 1: Setup

- [X] T-R02G2005-001 Baselines on the committed tree after R02-G20-04 is recorded: `--name baseline-host`, `--name — Verified 2026-11-27: 2026-11-27 baseline-host, baseline-timing, baseline-round02-1, -2, -3c, -3e, -3f exit 0 after R02-G20-04 (.autonomy/migration/checks/R02-G20-05.baseline-*.json)
  baseline-timing`, `--name baseline-round02-1`, `-2`, `-3c`, `-3e`, `-3f`; the rendering baseline is R02-G20-04's
  rendering runs (exit 0)

## Phase 2: Stories 2 and 3 — hints and failure explanation (P1) 🎯

- [X] T-R02G2005-002 [P] [US2] [US3] Create `Packages/ExperiencesRound02/MushroomWeather/Core/MushroomWeatherHints.swift` — Verified 2026-11-27: 2026-11-27 host-2 exit 0: 182 tests in 21 suites incl. hints (exact hints from the opening then the run win all 100 levels; 200 seeded reachable states give accepted hints; off-path search agrees with brute force; 500 seeded failures and constructed mold failures explained truly; singular and plural unstable wording) (.autonomy/migration/checks/R02-G20-05.host-2.json)
  (`MushroomWeatherHintPlan`, `MushroomWeatherHintKind` pod/vent/moonlight/run/stuck, `MushroomWeatherHint` with levels
  1 … 3 and the texts of clarification Q1 — level 1 "Change a spore pod", "Change a vent" or "Change the moonlight";
  level 2 "Use the site at row r, column c", "Take pod n away", "Use vent n" or "Make the moonlight brighter" ("dimmer");
  level 3 "Put pod n on the site at row r, column c", "Move pod n to the site at row r, column c", "Take pod n away",
  "Open vent n" ("Close"), "Set the moonlight to level l" (pods and vents numbered from 1: slot + 1, index + 1); already winning "Every colony stays in its band: run the
  weather"; stuck "No way to win was found in the actions left: undo the last action or retry the level."; failed play
  "Undo the last action or retry the level."; won play nil — while the current arrangement lies on the way to the
  certified witness's (its pods a subset of the witness's, its toggled vents a subset of the witness's, its moonlight the
  start's or the witness's) and the actions left cover the witness's remaining actions, the plan is the witness's
  remaining actions in the witness's order; otherwise a shortest completion "within min(actions left, 2) actions", one
  action before two, in the order removals by slot, moves and placements by slot and site, vents by index, moonlight
  levels ascending; an action places a pod on a free site (into the first free slot), moves a slot's pod to a free site,
  takes a slot's pod away, toggles a vent or sets another moonlight level; judged with `MushroomWeatherForest.report` on
  the arrangement; "at most 1,500 arrangements judged"; `MushroomWeatherHints.plan`/`hint` taking the certified plan;
  `MushroomWeatherFailureExplanation` with the texts of clarification Q5 for `dried`, `mold` and `unstable`, colonies
  numbered from 1 and cells as "the cell at row r, column c", followed by "Undo the last action or retry the level.")
  with `Packages/ExperiencesRound02/MushroomWeather/CoreTests/MushroomWeatherHintsTests.swift` (following exact hints
  from the opening, then the run, wins all 100 certified levels within their budget, in groups under 10 s each; 200
  seeded reachable states (seed 2_495): every exact hint is accepted by the kernel; 500 seeded failures explained with
  their true colony, cell, cycle and run lengths; a hint never changes the play; the bounded search finds a winning plan
  from states off the certified path when one exists within its bound); agent B; `--name host-2`

## Phase 3: Stories 1 and 4 — tutorial and progress (P1, P2)

- [X] T-R02G2005-003 [P] [US1] [US4] Create `Packages/ExperiencesRound02/MushroomWeather/Core/MushroomWeatherProgress.swift` — Verified 2026-11-27: 2026-11-27 host-3 exit 0: 202 tests in 22 suites incl. 20 progress tests (tutorial steps on levels 1 … 3 by scripted plays, stars and frontier over 100 levels, daily level for every date 2026 … 2036 in 1 … 100 and stable, impossible dates refused, Codable round trips) (.autonomy/migration/checks/R02-G20-05.host-3.json)
  (`MushroomWeatherTutorialStep` place → balance → recover → done with the texts of clarification Q2, advanced by an
  accepted placement (place → balance), a second accepted action (balance → recover) or the level's end (→ done), never
  moved back by undo — an undo passes no action and the play's real end, a redo that restores a won or failed play ends
  it; `MushroomWeatherProgress` "3 when at most the certified witness's action count, 2 when at most that + 2, else 1"
  by actions spent (every accepted pod, vent and moonlight record, undone ones included), frontier with level 1 open,
  best actions spent per level, a better result replacing a worse one; `dailyLevel(year:month:day:)` "(days from
  2026-01-01 × 17) mod 100 + 1, negative day counts wrapped", nil for an impossible date; `MushroomWeatherMode`
  campaign, practice, daily(level)) with `Packages/ExperiencesRound02/MushroomWeather/CoreTests/MushroomWeatherProgressTests.swift`
  (tutorial steps on levels 1 … 3 by scripted plays following the witnesses; stars and frontier over a 100-level script;
  every date 2026-01-01 … 2036-12-31 gives a level in 1 … 100, stable; impossible dates nil; Codable round trips);
  agent C; `--name host-3`

## Phase 4: Adapter, scenarios, presenter

- [X] T-R02G2005-004 Edit `Packages/ExperiencesRound02/MushroomWeather/Core/MushroomWeatherExperienceCore.swift` — Verified 2026-11-27: 2026-11-27 host-4 exit 0: 213 tests in 23 suites incl. 11 progression-core tests (14 controls, refusals, a locked daily level played without opening it, practice budget 24, schema-2 round trip, migration 1 → 2, newer schema refused) and the updated adapter, scenario (manifest regenerated) and panel-win suites (.autonomy/migration/checks/R02-G20-05.host-4.json)
  (controls `level.select [1 … 100]`, `mode.daily [year, month, day]`, `mode.practice`, `mode.campaign`,
  `tutorial.dismiss`; codes `r02-g20.locked`, `r02-g20.date`; practice budget 24 on a copy of the level, no stars, no
  unlocks; the daily level is playable even while still locked in the campaign, and a daily win records the level's best
  result and stars and opens nothing; progress and mode in the digest, the tutorial step snapshotted but not digested,
  the shown cycle unchanged (presentation); snapshot schema 2 `{level, mode, progress, records, tutorial}` with a
  migration from 1 "level 1 open plus the restored level, campaign mode, tutorial at its first step on tutorial levels";
  `level.next` to the next open level, refused with `r02-g20.locked` when none; the certified plan of the prepared level
  exposed for hints and stars; no level is ever gated by payment — locked means not yet unlocked (FR-R02G2005-006)) with
  tests in `Packages/ExperiencesRound02/MushroomWeather/CoreTests/MushroomWeatherProgressionCoreTests.swift` (new
  controls, refusals, a locked daily level played without opening it, schema 2 round trip, migration from a schema-1
  payload, newer schema refused); update `Packages/ExperiencesRound02/MushroomWeather/Core/MushroomWeatherScenarios.swift`
  where the new controls and the `level.next` rule change expectations and regenerate
  `Packages/ExperiencesRound02/MushroomWeather/scenario-manifest.json` (`UPDATE_SCENARIO_MANIFEST=1`); update
  `MushroomWeatherPanelWinTests`, the gesture wiring tests and other suites whose `level.next` expectation changes; lead;
  `--name host-4 -- swift test --package-path Packages/ExperiencesRound02 --filter MushroomWeather`
- [X] T-R02G2005-005 Edit `Packages/ExperiencesRound02/MushroomWeather/Experience/MushroomWeatherPresenter.swift` (the — Verified 2026-11-27: 2026-11-27 sim-27-2 exit 0 on sim-27.2: 47 tests in 6 suites incl. 10 teaching tests (tutorial steps and dismissal, three hint levels equal to the Core's, a stale search never owns the hint, hints win level 1 with 3 stars, failure explanation, band, goal and stars, practice, daily and campaign, locked and impossible-date refusals in words); the first attempt failed on the test's own daily-level constant (30 for 13), fixed (.autonomy/migration/checks/R02-G20-05.{sim-27,sim-27-2}.json)
  tutorial instruction, the hint at its current level — "Hint" raises the level 1 → 2 → 3, any play change resets it,
  the search off the main actor and a stale search never owning the hint state — and the failure explanation as panel
  text, replacing the mirror's own failure words, with the level's difficulty band (of the five bands of 20), its goal
  (every colony in its band for the last K cycles, and the action count that earns 3 stars, the certified witness's) and
  its best stars (FR-R02G2005-004); the description includes them) and
  `Packages/ExperiencesRound02/MushroomWeather/Experience/MushroomWeatherControls.swift` (Hint, Dismiss tutorial, level
  picker for open levels, Practice, Daily (today's local date from the presenter), Campaign); agent D writes
  `Packages/ExperiencesRound02/MushroomWeather/ExperienceTests/MushroomWeatherTeachingTests.swift` (the panel shows the
  tutorial, the three hint levels, the failure text, the band and the stars; mode and level controls reach the adapter;
  a refusal reads in words), given the presenter's exact texts; `--name sim-27 -- python3 scripts/xcodebuild_package.py
  --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination sim-27.2 --action test
  --only-testing MushroomWeatherExperienceTests`

## Phase 5: Regression, documentation and close

- [X] T-R02G2005-006 Docs: `docs/architecture/mushroom-weather.md` (teaching and progression), — Verified 2026-11-27: 2026-11-27 docs (architecture teaching and progression, package README, automatedtesting) and round02-host-1, -2, -3c, -3e, -3f exit 0 (.autonomy/migration/checks/R02-G20-05.round02-host-*.json)
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host-1`, `-2`, `-3c`, `-3e`,
  `-3f`
- [X] T-R02G2005-007 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-27: rendering-27, rendering-26, experiences, host-full and app-unit exit=0 (.autonomy/migration/checks/R02-G20-05.{rendering-27,rendering-26,experiences,host-full,app-unit}.json)
  `--name host-full`, `--name app-unit`
- [X] T-R02G2005-008 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-27: reference-1 exit=0 (.autonomy/migration/checks/R02-G20-05.reference-1.json)
- [X] T-R02G2005-009 Reference regression chunk 2 (`--name reference-2`) — Verified 2026-11-27: reference-2 exit=0 (.autonomy/migration/checks/R02-G20-05.reference-2.json)
- [X] T-R02G2005-010 Script tests, run alone (`--name script-tests`) — Verified 2026-11-27: script-tests exit=0 (.autonomy/migration/checks/R02-G20-05.script-tests.json)
- [ ] T-R02G2005-011 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → {002 (agent B), 003 (agent C)} → 004 (lead) → 005 (lead; agent D writes the teaching tests) → 006 … 010, 011.
Agents may draft in isolated copies before 001 (new files only). MVP: Stories 2 and 3. Requirement coverage: FR-001 →
003, 005; FR-002 → 002, 005; FR-003 → 002, 005; FR-004 → 003, 004, 005; FR-005 → 003, 004; FR-006 → 004; FR-007 →
004, 006 … 010.
