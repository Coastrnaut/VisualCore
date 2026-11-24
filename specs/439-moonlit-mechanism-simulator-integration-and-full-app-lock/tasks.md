# Tasks: R02-G14-09 — Moonlit Mechanism: simulator integration and full app lock

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G14-09 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G14-09 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_439;
tests stay short (< 10 s each; interface tests < 90 s, SC-R02G1409-001). No {owner} tasks; no GLSL or CPU reference
change (the shaders and reference of R02-G14-03 are unchanged and re-proven by the rendering runs).

## Phase 1: Setup

- [X] T-R02G1409-001 Baselines after R02-G14-08 is recorded: `--name baseline-host`, `--name baseline-timing`, `--name — Verified 2026-11-24: 2026-11-24: baseline-host, baseline-timing exit 0; baseline-round02 exit 1 (a draft file appeared in the tree mid-run, not a code fault), rerun baseline-round02-2 exit 0 on the committed tree (.autonomy/migration/checks/R02-G14-09.baseline-*.json)
  baseline-round02 -- swift test --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G14-08's
  rendering runs (exit 0)

## Phase 2: Foundational

- [X] T-R02G1409-002 Create `Packages/ExperiencesRound02/MoonlitMechanism/Core/MoonlitMechanismSchemaExamples.swift` — Verified 2026-11-24: 2026-11-24: schema examples (lead), agent A 7 restore tests, registry examples and comment; lead retest host exit 0 (.autonomy/migration/checks/R02-G14-09.host.json); registry use proven by app-unit (T-005)
  (contracts/api.md; data-model: schema 1 "`{level: 1, records}` of a seeded play of level 1 with its first certified
  action applied (playing, not won), seed 7"; schema 2 "campaign mode, the tutorial done, progress (frontier 2, level 1
  solved with actions spent one above the certified count and its stars), records []", "the result is kept, unverified,
  without a trace"; the envelope of `AcousticConstellatorSchemaExamples`, feature 429) with
  `Packages/ExperiencesRound02/MoonlitMechanism/CoreTests/MoonlitMechanismSchemaExampleTests.swift` (agent A: both
  restore through `migrations` to schema 3 with level 1, the action and progress kept; the expected digests match;
  versions other than 1 and 2 give nil); edit `Apps/VisualCore/App/ExperienceRegistry.swift` (`examples:` with both;
  the schema comment updated); `--name host -- swift test --package-path Packages/ExperiencesRound02 --filter
  MoonlitMechanismSchemaExampleTests`

## Phase 3: Story 1 — the game works inside the real app (P1) 🎯

- [X] T-R02G1409-003 [US1] Edit `Packages/ExperiencesRound02/MoonlitMechanism/Experience/MoonlitMechanismControls.swift`: — Verified 2026-11-24: 2026-11-24: identifierNames (44 names) in the panel; agent E 4 identifier tests; lead retest sim-27 exit 0, 68 tests (.autonomy/migration/checks/R02-G14-09.sim-27.json)
  `identifierNames` lists the 44 identifiers the panel already gives through `port.identifier` (spec Clarifications
  Q1: gear, gear-minus, gear-plus, gear-detail, turn-minus, turn-plus, reseat-minus, reseat-plus, lamp, lamp-minus,
  lamp-plus, frame, frame-minus, frame-plus, run, undo, redo, next-level, reset-view, dismiss-tutorial, hint,
  failure-undo, retry, campaign, daily, practice, level-picker, play-level, replay, replay-step, replay-stop, sound,
  summary, status, actions, pending, progress, message, failure, explanation, instruction, hint-text, goal,
  replay-position; unique), with
  `Packages/ExperiencesRound02/MoonlitMechanism/ExperienceTests/MoonlitMechanismIdentifierTests.swift` (agent E: every
  name of Q1 is listed once, has the prefix `experience.r02-g14.moonlit-mechanism.`, and the panel source uses each
  exactly once); `--name sim-27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme
  ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing MoonlitMechanismExperienceTests`
- [X] T-R02G1409-004 [US1] Create `Apps/VisualCore/Tests/UI/MoonlitMechanism/MMSupport.swift`, `MMPlayUITests.swift`, — Verified 2026-11-24: 2026-11-24: agent C MM interface tests, agent D chunk w3 (serial, key unique) and script test; xcodegen generate; lead retest app-ui exit 0, 3 tests (57.7 s, 122.0 s with two launches, 57.3 s) (.autonomy/migration/checks/R02-G14-09.app-ui.json)
  `MMReplayUITests.swift` (agent C: spec Clarifications Q2; level 1's certified actions (handle turn +1, lamp step −1,
  then the run) and the budget (9) pinned in `MM`; Turn + and Lamp − tapped, each press counted only when the
  actions-left count of the `actions` text moves; then Run; read "The shadows match every required key frame." and
  "Stars: 3 of 3."; background before terminate on relaunch); edit `scripts/release_check.py` (`UI_CHUNKS["w3"]`,
  `"w3"` in `SERIAL_CHUNKS`) and `scripts/test_scripts.py` (agent D; the key `w3` checked unique among the keys; any new
  test class above the `if __name__ == "__main__":` block); `xcodegen generate --spec project.yml` and a grep of the
  project for `MMPlayUITests`; `--name app-ui -- python3 scripts/release_check.py --only app-build-for-testing-ios27
  app-ui-ios27-w3`

## Phase 4: Story 2 — the app's logic accepts the game (P1)

- [X] T-R02G1409-005 [US2] Edit `Apps/VisualCore/Tests/Unit/AppModelTests.swift` (agent B: both examples restore — Verified 2026-11-24: 2026-11-24: agent B 4 app unit tests (examples restore, candidate not available, level 1 won through the engine, MM pins equal the Core); lead retest app-unit exit 0, all 4 passed (.autonomy/migration/checks/R02-G14-09.app-unit.json)
  through the app's migration check; the candidate opens through the registry and engine and plays level 1 to a win;
  without `-vcCandidates` it is not available and not openable; `MM`'s pinned level 1 certified actions and budget
  equal the Core's); `--name app-unit -- python3 scripts/release_check.py --only app-build-for-testing-ios27
  app-unit-ios27`

## Phase 5: Story 3 — builds and solvability (P2)

- [X] T-R02G1409-006 [US3] Release build and symbols (`MoonlitMechanismGolden`, `acceptanceScenarios` already — Verified 2026-11-24: 2026-11-24: release exit 0 (app-release-build, app-release-symbols; MoonlitMechanismGolden and acceptanceScenarios absent); regression exit 0 (host and simulator PASS, 100 of 100 levels) (.autonomy/migration/checks/R02-G14-09.{release,regression}.json)
  forbidden): `--name release -- python3 scripts/release_check.py --only app-release-build app-release-symbols`;
  `--name regression -- python3 scripts/moonlit_mechanism_regression.py` (100 of 100 levels, SC-R02G1409-004)

## Phase 6: Regression, documentation and close

- [X] T-R02G1409-007 Docs: `docs/architecture/moonlit-mechanism.md` (in-app integration), — Verified 2026-11-24: 2026-11-24: architecture in-app integration section, ExperiencesRound02 README, testing doc (w3 journeys, baseline lesson); round02-host exit 0 (362 s), script-tests exit 0 alone (.autonomy/migration/checks/R02-G14-09.{round02-host,script-tests}.json)
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`; `--name script-tests`
  (alone)
- [X] T-R02G1409-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-24: 2026-11-24: rendering-27, rendering-26, experiences, host-full exit 0 (.autonomy/migration/checks/R02-G14-09.{rendering-27,rendering-26,experiences,host-full}.json)
  `--name host-full` (app-unit and app-ui are this gate's own runs)
- [X] T-R02G1409-009 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-24: 2026-11-24: reference-1 exit 0 (.autonomy/migration/checks/R02-G14-09.reference-1.json)
- [ ] T-R02G1409-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G1409-011 {device} After ImplementationLock-100: the same journeys on D1/D2/D3 (SC-R02G1409-006; feature 440
  prepares them)
- [ ] T-R02G1409-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated; after the record push, check its CI run with `gh run list`

## Dependencies and parallel work

001 → 002 (lead; agent A tests) → 003 (lead; agent E tests) → {004 (agents C, D), 005 (agent B), 006} → 007 … 010, 012.
011 stays open until device testing. Shared files (examples source, registry, controls, project.yml, docs) stay with the
lead. Agents may draft in isolated copies before 001 (new files only). MVP: Stories 1 and 2. Requirement coverage:
FR-001 → 003; FR-002 → 004; FR-003 → 002, 005; FR-004 → 006; FR-005 → 006; FR-006 → 005; FR-007 → 004, 005, 007 … 010.
