# Tasks: R02-G03-09 — Wave Knot Keeper: simulator integration and full app lock

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G03-09 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G03-09 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_329;
tests stay short (< 10 s each; interface tests < 90 s, SC-R02G0309-001). No {owner} tasks.

## Phase 1: Setup

- [X] T-R02G0309-001 Baselines: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02 -- swift test — Verified 2026-11-21: 2026-11-21 baseline-round02, baseline-host, baseline-timing exit 0
  --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G03-08's rendering runs (exit 0)

## Phase 2: Foundational

- [X] T-R02G0309-002 Create `Packages/ExperiencesRound02/WaveKnotKeeper/Core/WaveKnotKeeperSchemaExamples.swift` — Verified 2026-11-21: 2026-11-21 host exit 0 (all round-two host tests): WaveKnotKeeperSchemaExampleTests 6/6 (both examples restore through migrations to schema 3 with progress kept; digests match; other versions nil; deterministic); registry stores both examples, comment corrected
  (contracts/api.md; data-model: schema 1 "a seeded play of level 1 with one move", schema 2 "campaign, frontier 2,
  level 1 solved without a trace", seed 7, the envelope of `AuroraLoomSchemaExamples`) with
  `Packages/ExperiencesRound02/WaveKnotKeeper/CoreTests/WaveKnotKeeperSchemaExampleTests.swift` (agent A: both
  restore through `migrations` to schema 3 with progress kept; the expected digests match; versions other than 1 and 2
  give nil); edit `Apps/VisualCore/App/ExperienceRegistry.swift` (`examples:` with both; the stale schema comment
  corrected); `--name host -- swift test --package-path Packages/ExperiencesRound02`

## Phase 3: Story 1 — the game works inside the real app (P1) 🎯

- [X] T-R02G0309-003 [US1] Edit `Packages/ExperiencesRound02/WaveKnotKeeper/Experience/WaveKnotKeeperControls.swift`: — Verified 2026-11-21: 2026-11-21 sim-27 exit 0 on sim-27.2: WaveKnotKeeperIdentifierTests (23 names once each, the six direction names in order, the port prefix experience.r02-g03.wave-knot-keeper.) and all Wave Knot Keeper experience tests
  identifiers `experience.r02-g03.wave-knot-keeper.<name>` through `port.identifier` (spec Clarifications Q1 names,
  unique); with `Packages/ExperiencesRound02/WaveKnotKeeper/ExperienceTests/WaveKnotKeeperIdentifierTests.swift`
  (agent E: every name of Q1 is listed once by the controls' identifier list and has the prefix); `--name sim-27 --
  python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package
  --destination sim-27.2 --action test`
- [X] T-R02G0309-004 [US1] Create `Apps/VisualCore/Tests/UI/WaveKnotKeeper/WKSupport.swift`, `WKPlayUITests.swift`, — Verified 2026-11-21: 2026-11-21 app-ui exit 0 (iOS 27.2): WKPlayUITests (win level 1 with the point picker and +x, 3 of 3 stars, level 2 open: 51 s; relaunch keeps progress: 63 s) and WKReplayUITests (replay to the win, stop: 40 s); chunk l3 serial in release_check.py with its script test
  `WKReplayUITests.swift` (agent C: spec Clarifications Q2; level 1 point count, solution moves and allowance pinned in `WK`; background
  before terminate on relaunch); edit `scripts/release_check.py` (`UI_CHUNKS["l3"]`, `"l3"` in `SERIAL_CHUNKS`) and
  `scripts/test_scripts.py` (agent D); `project.yml` + `xcodegen generate` if needed; `--name app-ui -- python3
  scripts/release_check.py --only app-build-for-testing-ios27 app-ui-ios27-l3`

## Phase 4: Story 2 — the app's logic accepts the game (P1)

- [X] T-R02G0309-005 [US2] Edit `Apps/VisualCore/Tests/Unit/AppModelTests.swift` (agent B: both examples restore through — Verified 2026-11-21: 2026-11-21 app-unit exit 0: 91/91 (87 before + 4: stored examples restore through the migration check; candidate not available without -vcCandidates; opens as a candidate and level 1 is won by its certified solution; WK's pinned point count, solution moves and allowance equal the Core)
  the app's migration check; the candidate opens through the registry and engine and plays level 1 to a win; without
  `-vcCandidates` it is not available and not openable; `WK`'s pinned level 1 point count, solution moves and allowance (the convergence lesson of feature 319)
  equal the Core's); `--name app-unit -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`

## Phase 5: Story 3 — builds and solvability (P2)

- [X] T-R02G0309-006 [US3] Release build and symbols (`WaveKnotKeeperGolden`, `acceptanceScenarios` already — Verified 2026-11-21: 2026-11-21 release exit 0 (Release simulator build; symbol check with WaveKnotKeeperGolden and acceptanceScenarios forbidden); regression exit 0 (all 100 levels re-solved, golden frames, isolated memory)
  forbidden): `--name release -- python3 scripts/release_check.py --only app-release-build app-release-symbols`;
  `--name regression -- python3 scripts/wave_knot_keeper_regression.py`

## Phase 6: Regression, documentation and close

- [X] T-R02G0309-007 Docs: `docs/architecture/wave-knot-keeper.md` (in-app integration), — Verified 2026-11-21: 2026-11-21 round02-host exit 0; script-tests exit 0 (alone); architecture in-app integration, package README, testing doc
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`; `--name script-tests` (alone)
- [X] T-R02G0309-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-21: 2026-11-21 rendering-27, rendering-26, experiences, host-full exit 0 (app-unit and app-ui are this gate's own runs)
  `--name host-full` (app-unit and app-ui are this gate's own runs)
- [X] T-R02G0309-009 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-21: 2026-11-21 reference-1 exit 0
- [ ] T-R02G0309-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G0309-011 {device} After ImplementationLock-100: the same journeys on D1/D2/D3 (SC-R02G0309-006; feature 330
  prepares them)
- [ ] T-R02G0309-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  after the record push, check its CI run with `gh run list`

## Dependencies and parallel work

001 → 002 (lead; agent A tests) → 003 (lead; agent E tests) → {004 (agents C, D), 005 (agent B), 006} → 007 … 010, 012.
011 stays open until device testing. Shared files (examples source, registry, controls, project.yml, docs) stay with the
lead. MVP: Stories 1 and 2.

