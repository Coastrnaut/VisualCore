# Tasks: R02-G11-09 — Echo Cartographer: simulator integration and full app lock

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G11-09 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G11-09 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_409;
tests stay short (< 10 s each; interface tests < 90 s, SC-R02G1109-001). No {owner} tasks; no GLSL or CPU reference
change (the shaders and reference of R02-G11-03 are unchanged and re-proven by the rendering runs).

## Phase 1: Setup

- [X] T-R02G1109-001 Baselines: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02 -- swift test — Verified 2026-11-23: baseline-host, baseline-timing, baseline-round02 exit 0 on the committed tree; rendering baseline is R02-G11-08's rendering runs (exit 0)
  --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G11-08's rendering runs (exit 0)

## Phase 2: Foundational

- [X] T-R02G1109-002 Create `Packages/ExperiencesRound02/EchoCartographer/Core/EchoCartographerSchemaExamples.swift` — Verified 2026-11-23: host exit 0 (round-two host suite incl. EchoCartographerSchemaExampleTests 7: both examples at seed 7 step 0 restore through the migrations to schema 3 with level 1 and its pulse or its unverified won result kept, digests match, the registry check reports no problems, other versions nil, deterministic; the examples join the invariant scan's presentation sources; the registration stores both examples and its comment is corrected; agent A's tests retested by the lead)
  (contracts/api.md; data-model: schema 1 "a seeded play of level 1 with one pulse that does not win, seed 7";
  schema 2 "campaign mode, progress {frontier 2, solved [level 1, energy spent, stars]}, tutorial", "the result is kept,
  unverified, without a trace"; the envelope of `BackwardsAuroraSchemaExamples`, feature 399) with
  `Packages/ExperiencesRound02/EchoCartographer/CoreTests/EchoCartographerSchemaExampleTests.swift` (agent A: both
  restore through `migrations` to schema 3 with level 1, the pulse and progress kept; the expected digests
  match; versions other than 1 and 2 give nil); edit `Apps/VisualCore/App/ExperienceRegistry.swift` (`examples:` with
  both; the stale schema comment corrected); `--name host -- swift test --package-path Packages/ExperiencesRound02`

## Phase 3: Story 1 — the game works inside the real app (P1) 🎯

- [X] T-R02G1109-003 [US1] Edit `Packages/ExperiencesRound02/EchoCartographer/Experience/EchoCartographerControls.swift`: — Verified 2026-11-23: sim-27 exit 0 (61 simulator tests incl. EchoCartographerIdentifierTests: the 23 identifier names of Q1 listed once each, well formed, built through the port with the experience prefix and unique; every panel control carries experience.r02-g11.echo-cartographer.<name>; agent E's tests retested by the lead)
  identifiers `experience.r02-g11.echo-cartographer.<name>` through `port.identifier` (spec Clarifications Q1 names:
  pulse, claim, mark, undo, redo, next-level, reset-view, hint, dismiss-tutorial, failure-undo, retry, campaign,
  daily, practice, play-level, replay, replay-step, replay-stop, column-picker, row-picker, level-picker, sound, summary; unique; `identifierNames` lists them) with
  `Packages/ExperiencesRound02/EchoCartographer/ExperienceTests/EchoCartographerIdentifierTests.swift` (agent E:
  every name of Q1 is listed once by the controls' identifier list and has the prefix); `--name sim-27 -- python3
  scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package
  --destination sim-27.2 --action test --only-testing EchoCartographerExperienceTests`
- [X] T-R02G1109-004 [US1] Create `Apps/VisualCore/Tests/UI/EchoCartographer/ECGSupport.swift`, `ECGPlayUITests.swift`, — Verified 2026-11-23: app-ui-4 exit 0 (ECGPlayUITests: level 1 won through the panel with three stars and level 2 open, 51 s; progress kept over a relaunch, 98 s with two launches; ECGReplayUITests: the stored solution replayed by exactly its 3 actions to a win, Stop back to the campaign, 59 s; chunk t3 serial, its key unique, 5 script tests); earlier attempts: app-ui 0 tests (project not regenerated), app-ui-2 and app-ui-3 a replay press counted without its value moving (the loop now counts confirmed presses)
  `ECGReplayUITests.swift` (agent C: spec Clarifications Q2; level 1 certified actions and the cursor's starting cell (the
  entry, column 0, row 3) and the chamber size (6 × 6) pinned in `ECG`; each action played by stepping the column and row steppers from the cursor's
  cell to the action's cell (reading each value), then Pulse or Claim; read "Every beacon is located" and "Stars: 3 of
  3"; background before terminate on relaunch); edit `scripts/release_check.py` (`UI_CHUNKS["t3"]`, `"t3"` in `SERIAL_CHUNKS`) and
  `scripts/test_scripts.py` (agent D; the key `t3` checked unique among the keys); `project.yml` + `xcodegen generate`
  if needed; `--name app-ui -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-ui-ios27-t3`

## Phase 4: Story 2 — the app's logic accepts the game (P1)

- [X] T-R02G1109-005 [US2] Edit `Apps/VisualCore/Tests/Unit/AppModelTests.swift` (agent B: both examples restore through — Verified 2026-11-23: app-unit exit 0, 123 of 123 tests incl. the four Echo Cartographer AppModelTests (stored examples restore with no migration problems; a candidate not available or openable without -vcCandidates; opens with the argument and level 1 is won by its certified actions with three stars, verified, level 2 open; ECG's pinned level 1 actions, starting cell and 6 x 6 chamber equal the Core); agent B's tests retested by the lead
  the app's migration check; the candidate opens through the registry and engine and plays level 1 to a win; without
  `-vcCandidates` it is not available and not openable; `ECG`'s pinned level 1 certified actions, the
  cursor's starting cell and the chamber size (the convergence lesson of feature 319) equal the Core's); `--name app-unit -- python3
  scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`

## Phase 5: Story 3 — builds and solvability (P2)

- [X] T-R02G1109-006 [US3] Release build and symbols (`EchoCartographerGolden`, `acceptanceScenarios` already — Verified 2026-11-23: release and regression checks exit 0 (Release simulator build and symbol check without EchoCartographerGolden and acceptanceScenarios; echo_cartographer_regression host and simulator PASS, 100 of 100 levels)
  forbidden): `--name release -- python3 scripts/release_check.py --only app-release-build app-release-symbols`;
  `--name regression -- python3 scripts/echo_cartographer_regression.py` (100 of 100 levels, SC-R02G1109-004)

## Phase 6: Regression, documentation and close

- [X] T-R02G1109-007 Docs: `docs/architecture/echo-cartographer.md` (in-app integration), — Verified 2026-11-23: docs written (architecture in-app integration, ExperiencesRound02 README feature 409, testing doc: regenerate the project for a new UI test folder, Echo Cartographer interface journeys); round02-host (326 s) and script-tests exit 0
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`; `--name script-tests`
  (alone)
- [X] T-R02G1109-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-23: rendering-27, rendering-26, experiences, host-full exit 0 (app-unit and app-ui are this gate's own runs)
  `--name host-full` (app-unit and app-ui are this gate's own runs)
- [X] T-R02G1109-009 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-23: reference-1 exit 0
- [X] T-R02G1109-010 Reference regression chunk 2 (`--name reference-2`) — Verified 2026-11-23: reference-2 exit 0
- [ ] T-R02G1109-011 {device} After ImplementationLock-100: the same journeys on D1/D2/D3 (SC-R02G1109-006; feature 410
  prepares them)
- [ ] T-R02G1109-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  after the record push, check its CI run with `gh run list`

## Dependencies and parallel work

001 → 002 (lead; agent A tests) → 003 (lead; agent E tests) → {004 (agents C, D), 005 (agent B), 006} → 007 … 010, 012.
011 stays open until device testing. Shared files (examples source, registry, controls, project.yml, docs) stay with the
lead. MVP: Stories 1 and 2. Requirement coverage: FR-001 → 003; FR-002 → 004; FR-003 → 002, 005; FR-004 → 006;
FR-005 → 006; FR-006 → 005; FR-007 → 004, 005, 007 … 010.
