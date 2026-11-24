# Tasks: R02-G14-09 — Moonlit Mechanism: simulator integration and full app lock

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G14-09 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G14-09 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_439;
tests stay short (< 10 s each; interface tests < 90 s, SC-R02G1409-001). No {owner} tasks; no GLSL or CPU reference
change (the shaders and reference of R02-G14-03 are unchanged and re-proven by the rendering runs).

## Phase 1: Setup

- [ ] T-R02G1409-001 Baselines after R02-G14-08 is recorded: `--name baseline-host`, `--name baseline-timing`, `--name
  baseline-round02 -- swift test --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G14-08's
  rendering runs (exit 0)

## Phase 2: Foundational

- [ ] T-R02G1409-002 Create `Packages/ExperiencesRound02/MoonlitMechanism/Core/MoonlitMechanismSchemaExamples.swift`
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

- [ ] T-R02G1409-003 [US1] Edit `Packages/ExperiencesRound02/MoonlitMechanism/Experience/MoonlitMechanismControls.swift`:
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
- [ ] T-R02G1409-004 [US1] Create `Apps/VisualCore/Tests/UI/MoonlitMechanism/MMSupport.swift`, `MMPlayUITests.swift`,
  `MMReplayUITests.swift` (agent C: spec Clarifications Q2; level 1's certified actions (handle turn +1, lamp step −1,
  then the run) and the budget (9) pinned in `MM`; Turn + and Lamp − tapped, each press counted only when the
  actions-left count of the `actions` text moves; then Run; read "The shadows match every required key frame." and
  "Stars: 3 of 3."; background before terminate on relaunch); edit `scripts/release_check.py` (`UI_CHUNKS["w3"]`,
  `"w3"` in `SERIAL_CHUNKS`) and `scripts/test_scripts.py` (agent D; the key `w3` checked unique among the keys; any new
  test class above the `if __name__ == "__main__":` block); `xcodegen generate --spec project.yml` and a grep of the
  project for `MMPlayUITests`; `--name app-ui -- python3 scripts/release_check.py --only app-build-for-testing-ios27
  app-ui-ios27-w3`

## Phase 4: Story 2 — the app's logic accepts the game (P1)

- [ ] T-R02G1409-005 [US2] Edit `Apps/VisualCore/Tests/Unit/AppModelTests.swift` (agent B: both examples restore
  through the app's migration check; the candidate opens through the registry and engine and plays level 1 to a win;
  without `-vcCandidates` it is not available and not openable; `MM`'s pinned level 1 certified actions and budget
  equal the Core's); `--name app-unit -- python3 scripts/release_check.py --only app-build-for-testing-ios27
  app-unit-ios27`

## Phase 5: Story 3 — builds and solvability (P2)

- [ ] T-R02G1409-006 [US3] Release build and symbols (`MoonlitMechanismGolden`, `acceptanceScenarios` already
  forbidden): `--name release -- python3 scripts/release_check.py --only app-release-build app-release-symbols`;
  `--name regression -- python3 scripts/moonlit_mechanism_regression.py` (100 of 100 levels, SC-R02G1409-004)

## Phase 6: Regression, documentation and close

- [ ] T-R02G1409-007 Docs: `docs/architecture/moonlit-mechanism.md` (in-app integration),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`; `--name script-tests`
  (alone)
- [ ] T-R02G1409-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full` (app-unit and app-ui are this gate's own runs)
- [ ] T-R02G1409-009 Reference regression chunk 1 (`--name reference-1`)
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
