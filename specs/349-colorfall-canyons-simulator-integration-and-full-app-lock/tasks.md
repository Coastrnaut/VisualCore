# Tasks: R02-G05-09 — Colorfall Canyons: simulator integration and full app lock

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G05-09 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G05-09 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_349;
tests stay short (< 10 s each; interface tests < 90 s, SC-R02G0509-001). No {owner} tasks; no GLSL or CPU reference
change (the shaders and reference of R02-G05-03 are unchanged and re-proven by the rendering runs).

## Phase 1: Setup

- [X] T-R02G0509-001 Baselines: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02 -- swift test — Verified 2026-11-21: 2026-11-21 baseline-host, baseline-timing, baseline-round02 exit 0 (.autonomy/migration/checks/R02-G05-09.baseline-*.json); rendering baseline: R02-G05-08 rendering-27/26 exit 0
  --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G05-08's rendering runs (exit 0)

## Phase 2: Foundational

- [X] T-R02G0509-002 Create `Packages/ExperiencesRound02/ColorfallCanyons/Core/ColorfallCanyonsSchemaExamples.swift` — Verified 2026-11-21: 2026-11-21 host exit 0: schema examples 7 tests (both restore to schema 3 with level 1, the carve and progress kept; digests match; versions 0/3/4 nil; deterministic) + experience core and persistence suites (.autonomy/migration/checks/R02-G05-09.host.json); registry stores both examples, comment corrected; lead retest
  (contracts/api.md; data-model: schema 1 "a seeded play of level 1 with one carve that does not win, seed 7"; schema 2
  "campaign mode, progress {frontier 2, solved [level 1, best units, stars]}, tutorial", "the result is kept, unverified,
  without a trace"; the envelope of `HueCompassSchemaExamples`) with
  `Packages/ExperiencesRound02/ColorfallCanyons/CoreTests/ColorfallCanyonsSchemaExampleTests.swift` (agent A: both
  restore through `migrations` to schema 3 with level 1, the carve and progress kept; the expected digests match;
  versions other than 1 and 2 give nil); edit `Apps/VisualCore/App/ExperienceRegistry.swift` (`examples:` with both;
  the stale schema comment corrected); `--name host -- swift test --package-path Packages/ExperiencesRound02`

## Phase 3: Story 1 — the game works inside the real app (P1) 🎯

- [X] T-R02G0509-003 [US1] Edit `Packages/ExperiencesRound02/ColorfallCanyons/Experience/ColorfallCanyonsControls.swift`: — Verified 2026-11-21: 2026-11-21 sim-27 exit 0: ColorfallCanyonsExperienceTests 56 tests in 11 suites on sim-27.2 incl. ColorfallCanyonsIdentifierTests (26 clarified names once, valve names for up to 3 springs, port prefix for every name) (.autonomy/migration/checks/R02-G05-09.sim-27.json); lead run
  identifiers `experience.r02-g05.colorfall-canyons.<name>` through `port.identifier` (spec Clarifications Q1 names:
  carve, valve-0 … valve-2, step-1, step-10, run, undo, redo, next-level, reset-view, hint, dismiss-tutorial,
  failure-undo, retry, campaign, daily, practice, play-level, replay, replay-step, replay-stop, cell-picker,
  level-picker, sound, summary; unique; `identifierNames` lists them) with
  `Packages/ExperiencesRound02/ColorfallCanyons/ExperienceTests/ColorfallCanyonsIdentifierTests.swift` (agent E: every
  name of Q1 is listed once by the controls' identifier list and has the prefix); `--name sim-27 -- python3
  scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package
  --destination sim-27.2 --action test --only-testing ColorfallCanyonsExperienceTests`
- [ ] T-R02G0509-004 [US1] Create `Apps/VisualCore/Tests/UI/ColorfallCanyons/CCSupport.swift`, `CCPlayUITests.swift`,
  `CCReplayUITests.swift` (agent C: spec Clarifications Q2; level 1 certified actions and carvable-cell order pinned in
  `CC`; each carve cell reached by stepping the cell picker by its index in the carvable order, recomputed after each
  carve; read "Every basin is filled" and "Stars: 3 of 3"; background before terminate on relaunch); edit
  `scripts/release_check.py` (`UI_CHUNKS["n3"]`, `"n3"` in `SERIAL_CHUNKS`) and `scripts/test_scripts.py` (agent D; the
  key `n3` checked unique among the keys); `project.yml` + `xcodegen generate` if needed; `--name app-ui -- python3
  scripts/release_check.py --only app-build-for-testing-ios27 app-ui-ios27-n3`

## Phase 4: Story 2 — the app's logic accepts the game (P1)

- [ ] T-R02G0509-005 [US2] Edit `Apps/VisualCore/Tests/Unit/AppModelTests.swift` (agent B: both examples restore through
  the app's migration check; the candidate opens through the registry and engine and plays level 1 to a win; without
  `-vcCandidates` it is not available and not openable; `CC`'s pinned level 1 certified actions and carvable-cell order
  (the convergence lesson of feature 319) equal the Core's); `--name app-unit -- python3 scripts/release_check.py
  --only app-build-for-testing-ios27 app-unit-ios27`

## Phase 5: Story 3 — builds and solvability (P2)

- [X] T-R02G0509-006 [US3] Release build and symbols (`ColorfallCanyonsGolden`, `acceptanceScenarios` already — Verified 2026-11-21: 2026-11-21 release exit 0 (app-release-build, app-release-symbols: no ColorfallCanyonsGolden or acceptanceScenarios in Release) (.autonomy/migration/checks/R02-G05-09.release.json); regression exit 0: solver regression 100 of 100 levels, golden descriptions, simulator golden frames and memory (.autonomy/migration/checks/R02-G05-09.regression.json); lead runs
  forbidden): `--name release -- python3 scripts/release_check.py --only app-release-build app-release-symbols`;
  `--name regression -- python3 scripts/colorfall_canyons_regression.py` (100 of 100 levels, SC-R02G0509-004)

## Phase 6: Regression, documentation and close

- [ ] T-R02G0509-007 Docs: `docs/architecture/colorfall-canyons.md` (in-app integration),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`; `--name script-tests` (alone)
- [ ] T-R02G0509-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full` (app-unit and app-ui are this gate's own runs)
- [ ] T-R02G0509-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G0509-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G0509-011 {device} After ImplementationLock-100: the same journeys on D1/D2/D3 (SC-R02G0509-006; feature 350
  prepares them)
- [ ] T-R02G0509-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  after the record push, check its CI run with `gh run list`

## Dependencies and parallel work

001 → 002 (lead; agent A tests) → 003 (lead; agent E tests) → {004 (agents C, D), 005 (agent B), 006} → 007 … 010, 012.
011 stays open until device testing. Shared files (examples source, registry, controls, project.yml, docs) stay with the
lead. MVP: Stories 1 and 2.
