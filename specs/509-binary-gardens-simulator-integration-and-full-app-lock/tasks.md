# Tasks: R02-G21-09 — Binary Gardens: simulator integration and full app lock

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G21-09 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G21-09 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_509;
tests stay short (< 10 s each; interface tests < 90 s plus setup, SC-R02G2109-001). No {owner} tasks; no GLSL or CPU
reference change. Prerequisites: R02-G21-05 … R02-G21-08 recorded (R02-G21-04 is recorded).

## Phase 1: Setup

- [X] T-R02G2109-001 Baselines on the committed tree after R02-G21-08 is recorded: `--name baseline-host`, `--name — Verified 2026-11-27: baseline-host, baseline-timing, baseline-round02-1, -2, -3c, -3e, -3f exit 0 (after R02-G21-08 was recorded)
  baseline-timing`, `--name baseline-round02-1`, `-2`, `-3c`, `-3e`, `-3f` (the five round-two chunks, 2 with
  `BinaryGardens`); the rendering baseline is R02-G21-08's rendering runs (exit 0)

## Phase 2: Foundational

- [X] T-R02G2109-002 Create `Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensSchemaExamples.swift` — Verified 2026-11-27: host exit 0 (swift test --filter BinaryGardensSchemaExampleTests: 8 tests, schema 1 and 2 examples restore to schema 3, digests pinned); registry examples registered
  (contracts/api.md; schema 1 "`{level: 1, records}` of a play of level 1 with star 2's ring change `star.ring [1, 1]`
  accepted (playing, not won)"; schema 2 "campaign mode, the tutorial done, progress (frontier 2, level 1 solved with 2
  actions spent and 2 stars, one above the certified count of 1), the records of a fresh play", "the result is kept,
  unverified, without a trace"; the envelope of `MushroomWeatherSchemaExamples`) with
  `Packages/ExperiencesRound02/BinaryGardens/CoreTests/BinaryGardensSchemaExampleTests.swift` (both restore through the
  migrations to schema 3 with level 1, the action and progress kept; the expected digests match; versions other than 1
  and 2 give nil); edit `Apps/VisualCore/App/ExperienceRegistry.swift` (`examples:` with both; the schema comment
  corrected); lead; `--name host -- swift test --package-path Packages/ExperiencesRound02 --filter
  BinaryGardensSchemaExampleTests`

## Phase 3: Story 1 — the game works inside the real app (P1) 🎯

- [X] T-R02G2109-003 [US1] Edit `Packages/ExperiencesRound02/BinaryGardens/Experience/BinaryGardensControls.swift`: — Verified 2026-11-27: sim-27 exit 0 (sim-27.2, BinaryGardensExperienceTests: 87 tests in 11 suites; identifierNames of 56 unique names, the failure explanation renamed explanation)
  `identifierNames` lists every identifier the panel carries (spec Clarifications Q1, aligned with the names features
  505 … 507 built; the level line carries none), pinned as built and unique, with
  `Packages/ExperiencesRound02/BinaryGardens/ExperienceTests/BinaryGardensIdentifierTests.swift` (every name listed
  once, with the prefix `experience.r02-g21.binary-gardens.`, and the panel source uses each exactly once); lead;
  `--name sim-27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme
  ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing BinaryGardensExperienceTests`
- [X] T-R02G2109-004 [US1] Create `Apps/VisualCore/Tests/UI/BinaryGardens/BGSupport.swift`, `BGPlayUITests.swift`, — Verified 2026-11-27: app-ui-8 exit 0 (app-ui-ios27-d4: BGPlayUITests 2 and BGReplayUITests 1 pass, 88 s, 146 s with a relaunch, 80 s); attempts app-ui … app-ui-7 failed because a segment tap never reached the overridden segmented star picker (and one build broke on XCUIElement.increment), so the star row became two buttons; sim-27-3 exit 0 after that panel change (87 tests); xcodegen generated
  `BGReplayUITests.swift` (agent C: spec Clarifications Q2; level 1's certified plan (star 2's luminosity down one
  level, then the run) and the budget pinned in `BG`; star 2 chosen, its luminosity value read, Luminosity − tapped and
  counted only when the actions-left count of the `actions` text moves; then Run; read the canvas win text and "Best: 3
  of 3 stars"; level 2 open; background before terminate on relaunch; the replay steps to a won end and Stop returns to
  campaign); edit `scripts/release_check.py` (`UI_CHUNKS["d4"]`, `"d4"` in `SERIAL_CHUNKS`) and
  `scripts/test_scripts.py` (the key `d4` checked unique among the keys; any new test class above the
  `if __name__ == "__main__":` block); `xcodegen generate --spec project.yml` and a grep of the project for
  `BGPlayUITests`; `--name app-ui -- python3 scripts/release_check.py --only app-build-for-testing-ios27
  app-ui-ios27-d4`

## Phase 4: Story 2 — the app's logic accepts the game (P1)

- [X] T-R02G2109-005 [US2] Edit `Apps/VisualCore/Tests/Unit/AppModelTests.swift` (agent B: both examples restore through — Verified 2026-11-27: app-unit exit 0 (build-for-testing pass, app-unit-ios27 pass; four Binary Gardens app tests: stored examples restore, not available without -vcCandidates, opens and wins level 1, BG pins equal the Core)
  the app's migration check; the candidate opens through the registry and engine and plays level 1 to a win; without
  `-vcCandidates` it is not available and not openable; `BG`'s pinned level 1 certified plan and budget equal the
  Core's); `--name app-unit -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`

## Phase 5: Story 3 — builds and solvability (P2)

- [X] T-R02G2109-006 [US3] Release build and symbols (`BinaryGardensGolden`, `acceptanceScenarios` forbidden): `--name — Verified 2026-11-27: release exit 0 (app-release-build and app-release-symbols pass; BinaryGardensGolden forbidden); regression exit 0 (binary_gardens_regression.py host and simulator PASS, 100 of 100 levels)
  release -- python3 scripts/release_check.py --only app-release-build app-release-symbols`; `--name regression --
  python3 scripts/binary_gardens_regression.py` (100 of 100 levels, SC-R02G2109-004)

## Phase 6: Regression, documentation and close

- [X] T-R02G2109-007 Docs: `docs/architecture/binary-gardens.md` (in-app integration), — Verified 2026-11-27: docs (architecture in-app integration, package README, automatedtesting); validate_docs PASS; round02-host-1/2/3c/3e/3f exit=0; script-tests exit=0
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host-1`, `-2`, `-3c`, `-3e`,
  `-3f`; `--name script-tests` (alone)
- [X] T-R02G2109-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, `--name — Verified 2026-11-27: rendering-27, rendering-26, experiences, host-full exit=0; app-unit recorded at T-005
  host-full` (app-unit and app-ui are this gate's own runs)
- [X] T-R02G2109-009 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-27: reference-1 exit=0
- [ ] T-R02G2109-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G2109-011 {device} After ImplementationLock-100: the same journeys on D1/D2/D3 (SC-R02G2109-006; feature 510
  prepares them)
- [ ] T-R02G2109-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated; after the record push, check its CI run with `gh run list`

## Dependencies and parallel work

001 → 002 (lead) → 003 (lead) → {004 (agent C), 005 (agent B), 006} → 007 … 010, 012. 011 stays open until device
testing. Shared files (examples source, registry, controls, project.yml, release check, script tests, docs) stay with
the lead. Agents may draft in isolated copies before 001 (new files only). MVP: Stories 1 and 2. Requirement coverage:
FR-001 → 003; FR-002 → 004; FR-003 → 002, 005; FR-004 → 006; FR-005 → 006; FR-006 → 005; FR-007 → 004, 005, 007 … 010.
