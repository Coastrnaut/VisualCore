# Tasks: R02-G04-09 — Hue Compass: simulator integration and full app lock

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G04-09 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G04-09 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_339;
tests stay short (< 10 s each; interface tests < 90 s, SC-R02G0409-001). No {owner} tasks.

## Phase 1: Setup

- [X] T-R02G0409-001 Baselines: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02 -- swift test — Verified 2026-11-21: 2026-11-21 baseline-round02, baseline-host, baseline-timing exit 0; rendering baseline is R02-G04-08's rendering runs (exit 0)
  --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G04-08's rendering runs (exit 0)

## Phase 2: Foundational

- [X] T-R02G0409-002 Create `Packages/ExperiencesRound02/HueCompass/Core/HueCompassSchemaExamples.swift` — Verified 2026-11-21: 2026-11-21 host exit 0 (whole round-two host suite): HueCompassSchemaExampleTests 7/7 (both examples restore through the migrations to schema 3 with progress kept; digests match; other versions nil; deterministic); registration stores both examples, comment corrected
  (contracts/api.md; data-model: schema 1 "a seeded play of level 1 with one turn that does not win", schema 2 "campaign, frontier 2,
  level 1 solved without a trace", seed 7, the envelope of `WaveKnotKeeperSchemaExamples`) with
  `Packages/ExperiencesRound02/HueCompass/CoreTests/HueCompassSchemaExampleTests.swift` (agent A: both
  restore through `migrations` to schema 3 with progress kept; the expected digests match; versions other than 1 and 2
  give nil); edit `Apps/VisualCore/App/ExperienceRegistry.swift` (`examples:` with both; the stale schema comment
  corrected); `--name host -- swift test --package-path Packages/ExperiencesRound02`

## Phase 3: Story 1 — the game works inside the real app (P1) 🎯

- [X] T-R02G0409-003 [US1] Edit `Packages/ExperiencesRound02/HueCompass/Experience/HueCompassControls.swift`: — Verified 2026-11-21: 2026-11-21 sim-27 exit 0 on sim-27.2: HueCompassIdentifierTests (the 23 names of Q1, each once; turn names in turn order; port prefix experience.r02-g04.hue-compass) and every Hue Compass experience test
  identifiers `experience.r02-g04.hue-compass.<name>` through `port.identifier` (spec Clarifications Q1 names,
  unique; `identifierNames` lists them); with `Packages/ExperiencesRound02/HueCompass/ExperienceTests/HueCompassIdentifierTests.swift`
  (agent E: every name of Q1 is listed once by the controls' identifier list and has the prefix); `--name sim-27 --
  python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package
  --destination sim-27.2 --action test`
- [X] T-R02G0409-004 [US1] Create `Apps/VisualCore/Tests/UI/HueCompass/HCSupport.swift`, `HCPlayUITests.swift`, — Verified 2026-11-21: 2026-11-21 app-ui-3 exit 0: HCPlayUITests (level 1 won with turn buttons, Probe, band stepper and Select: 3 of 3 stars, level 2 open; progress kept over a relaunch) and HCReplayUITests (Replay steps to the matching end, Stop returns to the campaign) in serial chunk m3, 63.8 s, 72.3 s and 60.5 s; earlier runs app-ui (96.7 s) and app-ui-2 (93.2 s) passed but exceeded the 90 s bound, fixed by revealing Step once and skipping the wait for present elements; test_hue_compass_ui_chunk passes
  `HCReplayUITests.swift` (agent C: spec Clarifications Q2; level 1 start bearing, target, band, allowance and witness actions pinned in `HC`; witness turns entered as presses of 4 then 1; background
  before terminate on relaunch); edit `scripts/release_check.py` (`UI_CHUNKS["m3"]`, `"m3"` in `SERIAL_CHUNKS`) and
  `scripts/test_scripts.py` (agent D; the key `m3` checked unique among the keys); `project.yml` + `xcodegen generate` if needed; `--name app-ui -- python3
  scripts/release_check.py --only app-build-for-testing-ios27 app-ui-ios27-m3`

## Phase 4: Story 2 — the app's logic accepts the game (P1)

- [X] T-R02G0409-005 [US2] Edit `Apps/VisualCore/Tests/Unit/AppModelTests.swift` (agent B: both examples restore through — Verified 2026-11-21: 2026-11-21 app-unit exit 0: the registration restores both stored examples; Hue Compass is a candidate (not in all, not available or openable without -vcCandidates); it opens through the registry and engine and level 1 is won by its certified witness; HC's pinned level 1 constants equal the Core
  the app's migration check; the candidate opens through the registry and engine and plays level 1 to a win; without
  `-vcCandidates` it is not available and not openable; `HC`'s pinned level 1 start bearing, target, band, allowance and witness actions (the convergence lesson of feature 319)
  equal the Core's); `--name app-unit -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`

## Phase 5: Story 3 — builds and solvability (P2)

- [X] T-R02G0409-006 [US3] Release build and symbols (`HueCompassGolden`, `acceptanceScenarios` already — Verified 2026-11-21: 2026-11-21 release exit 0 (Release simulator build; HueCompassGolden and acceptanceScenarios absent from the Release binary); regression exit 0 (scripts/hue_compass_regression.py: 100 of 100 levels re-certified, golden frames, memory)
  forbidden): `--name release -- python3 scripts/release_check.py --only app-release-build app-release-symbols`;
  `--name regression -- python3 scripts/hue_compass_regression.py`

## Phase 6: Regression, documentation and close

- [ ] T-R02G0409-007 Docs: `docs/architecture/hue-compass.md` (in-app integration),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`; `--name script-tests` (alone)
- [ ] T-R02G0409-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full` (app-unit and app-ui are this gate's own runs)
- [ ] T-R02G0409-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G0409-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G0409-011 {device} After ImplementationLock-100: the same journeys on D1/D2/D3 (SC-R02G0409-006; feature 340
  prepares them)
- [ ] T-R02G0409-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  after the record push, check its CI run with `gh run list`

## Dependencies and parallel work

001 → 002 (lead; agent A tests) → 003 (lead; agent E tests) → {004 (agents C, D), 005 (agent B), 006} → 007 … 010, 012.
011 stays open until device testing. Shared files (examples source, registry, controls, project.yml, docs) stay with the
lead. MVP: Stories 1 and 2.

