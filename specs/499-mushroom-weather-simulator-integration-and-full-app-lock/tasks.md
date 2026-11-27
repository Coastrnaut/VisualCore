# Tasks: R02-G20-09 — Mushroom Weather: simulator integration and full app lock

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G20-09 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G20-09 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_499;
tests stay short (< 10 s each; interface tests < 90 s, SC-R02G2009-001). No {owner} tasks; no GLSL or CPU reference
change (the shaders and reference of R02-G20-03 are unchanged and re-proven by the rendering runs).

## Phase 1: Setup

- [X] T-R02G2009-001 Baselines on the committed tree after R02-G20-08 is recorded: `--name baseline-host`, `--name — Verified 2026-11-27: baseline-host, baseline-timing, baseline-round02-1, -2, -3c, -3e, -3f exit=0 (.autonomy/migration/checks/R02-G20-09.baseline-*.json)
  baseline-timing`, `--name baseline-round02-1`, `-2`, `-3c`, `-3e`, `-3f` (the five round-two chunks, 3f with
  `MushroomWeather`); the rendering baseline is R02-G20-08's rendering runs (exit 0)

## Phase 2: Foundational

- [ ] T-R02G2009-002 Create `Packages/ExperiencesRound02/MushroomWeather/Core/MushroomWeatherSchemaExamples.swift`
  (contracts/api.md; data-model: schema 1 "`{level: 1, records}` of a seeded play of level 1 with one non-winning pod
  placed (playing, not won), seed 7"; schema 2 "campaign mode, the tutorial done, progress (frontier 2, level 1 solved
  with actions spent one above the certified count and its stars), the records of a fresh play", "the result is kept,
  unverified, without a trace"; the envelope of `MushroomWeatherSchemaExamples`, feature 489) with
  `Packages/ExperiencesRound02/MushroomWeather/CoreTests/MushroomWeatherSchemaExampleTests.swift` (agent A: both restore
  through `migrations` to schema 3 with level 1, the pod and progress kept; the expected digests match; versions
  other than 1 and 2 give nil); edit `Apps/VisualCore/App/ExperienceRegistry.swift` (`examples:` with both; the schema
  comment updated); `--name host -- swift test --package-path Packages/ExperiencesRound02 --filter
  MushroomWeatherSchemaExampleTests`

## Phase 3: Story 1 — the game works inside the real app (P1) 🎯

- [ ] T-R02G2009-003 [US1] Edit `Packages/ExperiencesRound02/MushroomWeather/Experience/MushroomWeatherControls.swift`:
  the failure explanation keeps its own identifier `explanation`, and `identifierNames` lists every identifier the
  panel carries (spec Clarifications Q1; contracts/api.md lists the expected names: slot, slot-minus, slot-plus,
  selection, pods-detail, site, site-minus, site-plus, place, remove, vent-0 … vent-5 (labelled Vent 1 … 6), moon,
  moon-minus, moon-plus, moon-set, reset-view, cycle, cycle-minus, cycle-plus, cycle-detail, run, undo, redo, next-level,
  dismiss-tutorial, hint, campaign, daily, practice, level-picker, play-level, replay, replay-step, replay-stop, sound,
  actions, status, failure, explanation, progress, summary, message, tutorial, hint-text, band, stars, goal,
  replay-position; pinned as built; unique), with
  `Packages/ExperiencesRound02/MushroomWeather/ExperienceTests/MushroomWeatherIdentifierTests.swift` (agent E: every
  name of Q1 is listed once, has the prefix `experience.r02-g20.mushroom-weather.`, and the panel source uses each
  exactly once); `--name sim-27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme
  ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing MushroomWeatherExperienceTests`
- [ ] T-R02G2009-004 [US1] Create `Apps/VisualCore/Tests/UI/MushroomWeather/MWSupport.swift`, `MWPlayUITests.swift`,
  `MWReplayUITests.swift` (agent C: spec Clarifications Q2; level 1's certified plan (a pod at row 2, column 5 in slot 0, then vent 0 closed)
  and the budget pinned in `MW`; the slot and site moved with Pod and Site − or + by their controls' values, Place
  tapped, counted only when the actions-left count of the `actions` text moves; vent 1's toggle tapped until its value
  reads closed, counted the same way; then Run; read "Every colony ended the run in its band." and "Best: 3 of 3 stars";
  background before terminate on relaunch); edit
  `scripts/release_check.py` (`UI_CHUNKS["c4"]`, `"c4"` in `SERIAL_CHUNKS`) and `scripts/test_scripts.py` (agent D; the
  key `c4` checked unique among the keys; any new test class above the `if __name__ == "__main__":` block); `xcodegen
  generate --spec project.yml` and a grep of the project for `MWPlayUITests`; `--name app-ui -- python3
  scripts/release_check.py --only app-build-for-testing-ios27 app-ui-ios27-c4`

## Phase 4: Story 2 — the app's logic accepts the game (P1)

- [ ] T-R02G2009-005 [US2] Edit `Apps/VisualCore/Tests/Unit/AppModelTests.swift` (agent B: both examples restore through
  the app's migration check; the candidate opens through the registry and engine and plays level 1 to a win; without
  `-vcCandidates` it is not available and not openable; `MW`'s pinned level 1 certified plan and budget equal the
  Core's); `--name app-unit -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`

## Phase 5: Story 3 — builds and solvability (P2)

- [ ] T-R02G2009-006 [US3] Release build and symbols (`MushroomWeatherGolden`, `acceptanceScenarios` already forbidden):
  `--name release -- python3 scripts/release_check.py --only app-release-build app-release-symbols`; `--name regression
  -- python3 scripts/mushroom_weather_regression.py` (100 of 100 levels, SC-R02G2009-004)

## Phase 6: Regression, documentation and close

- [ ] T-R02G2009-007 Docs: `docs/architecture/mushroom-weather.md` (in-app integration),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host-1`, `-2`, `-3c`, `-3e`,
  `-3f`; `--name script-tests` (alone)
- [ ] T-R02G2009-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, `--name
  host-full` (app-unit and app-ui are this gate's own runs)
- [ ] T-R02G2009-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G2009-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G2009-011 {device} After ImplementationLock-100: the same journeys on D1/D2/D3 (SC-R02G2009-006; feature 500
  prepares them)
- [ ] T-R02G2009-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated; after the record push, check its CI run with `gh run list`

## Dependencies and parallel work

001 → 002 (lead; agent A tests) → 003 (lead; agent E tests) → {004 (agents C, D), 005 (agent B), 006} → 007 … 010, 012.
011 stays open until device testing. Shared files (examples source, registry, controls, project.yml, docs) stay with the
lead. Agents may draft in isolated copies before 001 (new files only). MVP: Stories 1 and 2. Requirement coverage:
FR-001 → 003; FR-002 → 004; FR-003 → 002, 005; FR-004 → 006; FR-005 → 006; FR-006 → 005; FR-007 → 004, 005, 007 … 010.
