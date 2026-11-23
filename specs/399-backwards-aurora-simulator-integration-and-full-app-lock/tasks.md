# Tasks: R02-G10-09 — Backwards Aurora: simulator integration and full app lock

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G10-09 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G10-09 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_399;
tests stay short (< 10 s each; interface tests < 90 s, SC-R02G1009-001). No {owner} tasks; no GLSL or CPU reference
change (the shaders and reference of R02-G10-03 are unchanged and re-proven by the rendering runs).

## Phase 1: Setup

- [X] T-R02G1009-001 Baselines: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02 -- swift test — Verified 2026-11-23: baseline-host, baseline-timing, baseline-round02 exit=0 on the committed tree; rendering baseline is R02-G10-08's rendering runs (exit 0)
  --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G10-08's rendering runs (exit 0)

## Phase 2: Foundational

- [X] T-R02G1009-002 Create `Packages/ExperiencesRound02/BackwardsAurora/Core/BackwardsAuroraSchemaExamples.swift` — Verified 2026-11-23: host exit=0 (round-two host suite incl. BackwardsAuroraSchemaExampleTests 7: both examples at seed 7 step 0 restore through the migrations to schema 3 with level 1 and its reversal or its unverified won result kept, digests match, the registry check reports no problems, other versions nil, deterministic; the examples join the invariant scan's presentation sources; the registration stores both examples and its comment is corrected; agent A's tests retested by the lead)
  (contracts/api.md; data-model: schema 1 "a seeded play of level 1 with one reversal that does not win, seed 7";
  schema 2 "campaign mode, progress {frontier 2, solved [level 1, reversals made, stars]}, tutorial", "the result is kept,
  unverified, without a trace"; the envelope of `BackwardsAuroraSchemaExamples`, feature 389) with
  `Packages/ExperiencesRound02/BackwardsAurora/CoreTests/BackwardsAuroraSchemaExampleTests.swift` (agent A: both
  restore through `migrations` to schema 3 with level 1, the reversal and progress kept; the expected digests
  match; versions other than 1 and 2 give nil); edit `Apps/VisualCore/App/ExperienceRegistry.swift` (`examples:` with
  both; the stale schema comment corrected); `--name host -- swift test --package-path Packages/ExperiencesRound02`

## Phase 3: Story 1 — the game works inside the real app (P1) 🎯

- [X] T-R02G1009-003 [US1] Edit `Packages/ExperiencesRound02/BackwardsAurora/Experience/BackwardsAuroraControls.swift`: — Verified 2026-11-23: sim-27 exit=0 (61 simulator tests incl. BackwardsAuroraIdentifierTests: the 21 identifier names of Q1 listed once each, well formed, built through the port with the experience prefix and unique; every panel control carries experience.r02-g10.backwards-aurora.<name>; agent E's tests retested by the lead)
  identifiers `experience.r02-g10.backwards-aurora.<name>` through `port.identifier` (spec Clarifications Q1 names:
  reverse, undo, redo, next-level, reset-view, hint, dismiss-tutorial, failure-undo, retry, campaign, daily,
  practice, play-level, replay, replay-step, replay-stop, start-picker, end-picker, level-picker, sound, summary; unique; `identifierNames` lists them) with
  `Packages/ExperiencesRound02/BackwardsAurora/ExperienceTests/BackwardsAuroraIdentifierTests.swift` (agent E:
  every name of Q1 is listed once by the controls' identifier list and has the prefix); `--name sim-27 -- python3
  scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package
  --destination sim-27.2 --action test --only-testing BackwardsAuroraExperienceTests`
- [X] T-R02G1009-004 [US1] Create `Apps/VisualCore/Tests/UI/BackwardsAurora/BASupport.swift`, `BAPlayUITests.swift`, — Verified 2026-11-23: app-ui check exit 0, 2026-11-23 (.autonomy/migration/checks/R02-G10-09.app-ui.json)
  `BAReplayUITests.swift` (agent C: spec Clarifications Q2; level 1 certified reversals and the steppers' starting section
  pinned in `BA`; each reversal played by stepping the end stepper up first, then the start stepper, then lowering the
  end if needed (reading each value), then Reverse; read "Every checkpoint matches and every bend is within the limit"
  and "Stars: 3 of 3"; background before terminate on relaunch); edit `scripts/release_check.py` (`UI_CHUNKS["s3"]`, `"s3"` in `SERIAL_CHUNKS`) and
  `scripts/test_scripts.py` (agent D; the key `s3` checked unique among the keys); `project.yml` + `xcodegen generate`
  if needed; `--name app-ui -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-ui-ios27-s3`

## Phase 4: Story 2 — the app's logic accepts the game (P1)

- [X] T-R02G1009-005 [US2] Edit `Apps/VisualCore/Tests/Unit/AppModelTests.swift` (agent B: both examples restore through — Verified 2026-11-23: app-unit check exit 0, 119 of 119 tests incl. the four Backwards Aurora AppModelTests, 2026-11-23 (.autonomy/migration/checks/R02-G10-09.app-unit.json)
  the app's migration check; the candidate opens through the registry and engine and plays level 1 to a win; without
  `-vcCandidates` it is not available and not openable; `BA`'s pinned level 1 certified reversals and the
  steppers' starting section (the convergence lesson of feature 319) equal the Core's); `--name app-unit -- python3
  scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`

## Phase 5: Story 3 — builds and solvability (P2)

- [ ] T-R02G1009-006 [US3] Release build and symbols (`BackwardsAuroraGolden`, `acceptanceScenarios` already
  forbidden): `--name release -- python3 scripts/release_check.py --only app-release-build app-release-symbols`;
  `--name regression -- python3 scripts/backwards_aurora_regression.py` (100 of 100 levels, SC-R02G1009-004)

## Phase 6: Regression, documentation and close

- [ ] T-R02G1009-007 Docs: `docs/architecture/backwards-aurora.md` (in-app integration),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`; `--name script-tests`
  (alone)
- [ ] T-R02G1009-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full` (app-unit and app-ui are this gate's own runs)
- [ ] T-R02G1009-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G1009-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G1009-011 {device} After ImplementationLock-100: the same journeys on D1/D2/D3 (SC-R02G1009-006; feature 400
  prepares them)
- [ ] T-R02G1009-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  after the record push, check its CI run with `gh run list`

## Dependencies and parallel work

001 → 002 (lead; agent A tests) → 003 (lead; agent E tests) → {004 (agents C, D), 005 (agent B), 006} → 007 … 010, 012.
011 stays open until device testing. Shared files (examples source, registry, controls, project.yml, docs) stay with the
lead. MVP: Stories 1 and 2. Requirement coverage: FR-001 → 003; FR-002 → 004; FR-003 → 002, 005; FR-004 → 006;
FR-005 → 006; FR-006 → 005; FR-007 → 004, 005, 007 … 010.
