# Tasks: R02-G02-09 — Lissajous Labyrinth: simulator integration and full app lock

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G02-09 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G02-09 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_319;
tests stay short (< 10 s each; interface tests < 90 s, SC-R02G0209-001). No {owner} tasks.

## Phase 1: Setup

- [X] T-R02G0209-001 Baselines: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02 -- swift test — Verified 2026-11-21: 2026-11-21 R02-G02-09.baseline-round02/host/timing exit 0
  --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G02-08's rendering runs (exit 0)

## Phase 2: Foundational

- [X] T-R02G0209-002 Create `Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthSchemaExamples.swift` — Verified 2026-11-21: 2026-11-21 host exit 0 (LissajousLabyrinthSchemaExamples: schema-1 and schema-2 examples, 6 host tests incl. the registry's migration check); registry stores both examples, comment corrected
  (contracts/api.md; data-model: schema 1 "a seeded play of level 1 with one action", schema 2 "campaign, frontier 2,
  level 1 solved without a trace", seed 7, the envelope of `AuroraLoomSchemaExamples`) with
  `Packages/ExperiencesRound02/LissajousLabyrinth/CoreTests/LissajousLabyrinthSchemaExampleTests.swift` (agent A: both
  restore through `migrations` to schema 3 with progress kept; the expected digests match; versions other than 1 and 2
  give nil); edit `Apps/VisualCore/App/ExperienceRegistry.swift` (`examples:` with both; the stale schema comment
  corrected); `--name host -- swift test --package-path Packages/ExperiencesRound02`

## Phase 3: Story 1 — the game works inside the real app (P1) 🎯

- [X] T-R02G0209-003 [US1] Edit `Packages/ExperiencesRound02/LissajousLabyrinth/Experience/LissajousLabyrinthControls.swift`: — Verified 2026-11-21: 2026-11-21 sim-27 exit 0 (panel identifiers experience.r02-g02.lissajous-labyrinth.<name>; LissajousLabyrinthIdentifierTests: 22 names, dial mapping, port prefix)
  identifiers `experience.r02-g02.lissajous-labyrinth.<name>` through `port.identifier` (spec Clarifications Q1 names,
  unique); with `Packages/ExperiencesRound02/LissajousLabyrinth/ExperienceTests/LissajousLabyrinthIdentifierTests.swift`
  (agent E: every name of Q1 is listed once by the controls' identifier list and has the prefix); `--name sim-27 --
  python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package
  --destination sim-27.2 --action test`
- [X] T-R02G0209-004 [US1] Create `Apps/VisualCore/Tests/UI/LissajousLabyrinth/LLSupport.swift`, `LLPlayUITests.swift`, — Verified 2026-11-21: 2026-11-21 app-ui exit 0 (LLPlayUITests: level 1 won through the phase-c stepper and Apply with 3 stars, progress kept over a relaunch; LLReplayUITests: replay to 1 of 1 and stop; 3 tests in 185 s, ~62 s each); chunk k3 serial (j3 is Particle Universe's; artifacts renamed)
  `LLReplayUITests.swift` (agent C: spec Clarifications Q2; level 1 start and final dials pinned in `LL`; background
  before terminate on relaunch); edit `scripts/release_check.py` (`UI_CHUNKS["k3"]`, `"k3"` in `SERIAL_CHUNKS`) and
  `scripts/test_scripts.py` (agent D); `project.yml` + `xcodegen generate` if needed; `--name app-ui -- python3
  scripts/release_check.py --only app-build-for-testing-ios27 app-ui-ios27-k3`

## Phase 4: Story 2 — the app's logic accepts the game (P1)

- [X] T-R02G0209-005 [US2] Edit `Apps/VisualCore/Tests/Unit/AppModelTests.swift` (agent B: both examples restore through — Verified 2026-11-21: 2026-11-21 app-unit exit 0 (examples restore through the app's migration check, the candidate opens and level 1 is won through the engine, unavailable without -vcCandidates, level 1 dials equal the Core)
  the app's migration check; the candidate opens through the registry and engine and plays level 1 to a win; without
  `-vcCandidates` it is not available and not openable; `LL`'s pinned level 1 dials equal the Core's start and certified
  final dials); `--name app-unit -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`

## Phase 5: Story 3 — builds and solvability (P2)

- [X] T-R02G0209-006 [US3] Release build and symbols (`LissajousLabyrinthGolden`, `acceptanceScenarios` already — Verified 2026-11-21: 2026-11-21 release exit 0 (Release simulator build of the one app with Lissajous Labyrinth linked; symbol check with LissajousLabyrinthGolden and acceptanceScenarios forbidden passes); regression exit 0 (all 100 levels re-certified; golden frames; isolated memory bound)
  forbidden): `--name release -- python3 scripts/release_check.py --only app-release-build app-release-symbols`;
  `--name regression -- python3 scripts/lissajous_labyrinth_regression.py`

## Phase 6: Regression, documentation and close

- [X] T-R02G0209-007 Docs: `docs/architecture/lissajous-labyrinth.md` (in-app integration), — Verified 2026-11-21: 2026-11-21 round02-host exit 0; script-tests exit 0 (alone); docs/architecture/lissajous-labyrinth.md in-app section, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`; `--name script-tests` (alone)
- [X] T-R02G0209-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-21: 2026-11-21 rendering-27, rendering-26, experiences, host-full exit 0; app-unit and app-ui are this gate's own app runs
  `--name host-full` (app-unit and app-ui are this gate's own runs)
- [X] T-R02G0209-009 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-21: 2026-11-21 reference-1 exit 0
- [X] T-R02G0209-010 Reference regression chunk 2 (`--name reference-2`) — Verified 2026-11-21: 2026-11-21 reference-2 exit 0: 7 of 7 with chunk 1
- [ ] T-R02G0209-011 {device} After ImplementationLock-100: the same journeys on D1/D2/D3 (SC-R02G0209-006; feature 320
  prepares them)
- [ ] T-R02G0209-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  after the record push, check its CI run with `gh run list`

## Dependencies and parallel work

001 → 002 (lead; agent A tests) → 003 (lead; agent E tests) → {004 (agents C, D), 005 (agent B), 006} → 007 … 010, 012.
011 stays open until device testing. Shared files (examples source, registry, controls, project.yml, docs) stay with the
lead. MVP: Stories 1 and 2.
