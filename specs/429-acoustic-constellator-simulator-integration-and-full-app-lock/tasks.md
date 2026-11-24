# Tasks: R02-G13-09 — Acoustic Constellator: simulator integration and full app lock

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G13-09 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G13-09 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_429;
tests stay short (< 10 s each; interface tests < 90 s, SC-R02G1309-001). No {owner} tasks; no GLSL or CPU reference
change (the shaders and reference of R02-G13-03 are unchanged and re-proven by the rendering runs).

## Phase 1: Setup

- [X] T-R02G1309-001 Baselines after R02-G13-08 is recorded: `--name baseline-host`, `--name baseline-timing`, `--name — Verified 2026-11-24: 2026-11-24: baseline-host, baseline-timing, baseline-round02 exit 0 on c5316386f (.autonomy/migration/checks/R02-G13-09.baseline-*.json); rendering baseline = R02-G13-08 rendering-27/26
  baseline-round02 -- swift test --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G13-08's
  rendering runs (exit 0)

## Phase 2: Foundational

- [X] T-R02G1309-002 Create `Packages/ExperiencesRound02/AcousticConstellator/Core/AcousticConstellatorSchemaExamples.swift` — Verified 2026-11-24: 2026-11-24: lead examples source (schema 1 one certified link, schema 2 won level 1 unverified without a trace), agent A 7 tests, registry examples: and comment; lead retest host exit 0, 7 tests (.autonomy/migration/checks/R02-G13-09.host.json)
  (contracts/api.md; data-model: schema 1 "`{level: 1, records}` of a seeded play of level 1 with its one certified
  link applied (playing, not won), seed 7"; schema 2 "campaign mode, the tutorial step, progress (level 2 open, level 1 solved with its
  actions spent and stars), records []", "the result is kept, unverified, without a trace"; the envelope of
  `HarmonicBridgesSchemaExamples`, feature 419) with
  `Packages/ExperiencesRound02/AcousticConstellator/CoreTests/AcousticConstellatorSchemaExampleTests.swift` (agent A: both
  restore through `migrations` to schema 3 with level 1, the link and progress kept; the expected digests match;
  versions other than 1 and 2 give nil); edit `Apps/VisualCore/App/ExperienceRegistry.swift` (`examples:` with both;
  the schema comment updated); `--name host -- swift test --package-path Packages/ExperiencesRound02 --filter
  AcousticConstellatorSchemaExampleTests`

## Phase 3: Story 1 — the game works inside the real app (P1) 🎯

- [X] T-R02G1309-003 [US1] Edit `Packages/ExperiencesRound02/AcousticConstellator/Experience/AcousticConstellatorControls.swift`: — Verified 2026-11-24: 2026-11-24: identifierNames pins the 35 names; agent E 4 identifier tests (listed once, lower-case tokens, panel uses each once, port prefix); sim-27 exit 0, 71 simulator tests (.autonomy/migration/checks/R02-G13-09.sim-27.json)
  `identifierNames` lists the 35 identifiers the panel already gives through `port.identifier` (spec Clarifications
  Q1: star, partner, link, unlink, nudge-minus, nudge-plus, listen, undo, redo, next-level, reset-view, dismiss-tutorial,
  hint, failure-undo, retry, campaign, daily, practice, level-picker, play-level, replay, replay-step, replay-stop, sound,
  summary, choice, status, actions, progress, message, failure, instruction, hint-text, goal, replay-position; unique), with
  `Packages/ExperiencesRound02/AcousticConstellator/ExperienceTests/AcousticConstellatorIdentifierTests.swift` (agent E: every
  name of Q1 is listed once, has the prefix `experience.r02-g13.acoustic-constellator.`, and the panel source uses each
  exactly once); `--name sim-27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme
  ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing AcousticConstellatorExperienceTests`
- [X] T-R02G1309-004 [US1] Create `Apps/VisualCore/Tests/UI/AcousticConstellator/ACNSupport.swift`, `ACNPlayUITests.swift`, — Verified 2026-11-24: 2026-11-24: agent C ACNSupport/ACNPlayUITests/ACNReplayUITests, agent D chunk v3 serial with its script test; xcodegen; app-ui exit 0, 3 of 3 (win 66 s, relaunch 100 s incl. two launches, replay 53 s) (.autonomy/migration/checks/R02-G13-09.app-ui.json)
  `ACNReplayUITests.swift` (agent C: spec Clarifications Q2; level 1's certified actions (link stars 0 and 1, then a
  listen), the opening choice (star 0, partner 1) and the budget (9) pinned in `ACN`; each link played by stepping the
  star and partner steppers to its stars only when they differ (reading each value, counting a press only when it moves),
  then Link; finally Listen; read "The symbol rings together." and "Stars: 3 of 3."; background before terminate on relaunch); edit
  `scripts/release_check.py` (`UI_CHUNKS["v3"]`, `"v3"` in `SERIAL_CHUNKS`) and `scripts/test_scripts.py` (agent D; the
  key `v3` checked unique among the keys; any new test class above the `if __name__ == "__main__":` block);
  `xcodegen generate --spec project.yml` and a grep of the project for `ACNPlayUITests`; `--name app-ui -- python3
  scripts/release_check.py --only app-build-for-testing-ios27 app-ui-ios27-v3`

## Phase 4: Story 2 — the app's logic accepts the game (P1)

- [X] T-R02G1309-005 [US2] Edit `Apps/VisualCore/Tests/Unit/AppModelTests.swift` (agent B: both examples restore — Verified 2026-11-24: 2026-11-24: agent B 4 app unit tests (stored examples restore, candidate not available without -vcCandidates, opens and level 1 won by its certified actions, ACN pins equal the Core); app-unit exit 0 (.autonomy/migration/checks/R02-G13-09.app-unit.json)
  through the app's migration check; the candidate opens through the registry and engine and plays level 1 to a win;
  without `-vcCandidates` it is not available and not openable; `ACN`'s pinned level 1 certified actions, opening choice
  and budget equal the Core's); `--name app-unit -- python3 scripts/release_check.py --only app-build-for-testing-ios27
  app-unit-ios27`

## Phase 5: Story 3 — builds and solvability (P2)

- [X] T-R02G1309-006 [US3] Release build and symbols (`AcousticConstellatorGolden`, `acceptanceScenarios` already — Verified 2026-11-24: 2026-11-24: release exit 0 (app-release-build, app-release-symbols; AcousticConstellatorGolden and acceptanceScenarios absent) (.autonomy/migration/checks/R02-G13-09.release.json); regression exit 0, 100 of 100 levels (.autonomy/migration/checks/R02-G13-09.regression.json)
  forbidden): `--name release -- python3 scripts/release_check.py --only app-release-build app-release-symbols`;
  `--name regression -- python3 scripts/acoustic_constellator_regression.py` (100 of 100 levels, SC-R02G1309-004)

## Phase 6: Regression, documentation and close

- [ ] T-R02G1309-007 Docs: `docs/architecture/acoustic-constellator.md` (in-app integration),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`; `--name script-tests`
  (alone)
- [ ] T-R02G1309-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full` (app-unit and app-ui are this gate's own runs)
- [ ] T-R02G1309-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G1309-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G1309-011 {device} After ImplementationLock-100: the same journeys on D1/D2/D3 (SC-R02G1309-006; feature 430
  prepares them)
- [ ] T-R02G1309-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated; after the record push, check its CI run with `gh run list`

## Dependencies and parallel work

001 → 002 (lead; agent A tests) → 003 (lead; agent E tests) → {004 (agents C, D), 005 (agent B), 006} → 007 … 010, 012.
011 stays open until device testing. Shared files (examples source, registry, controls, project.yml, docs) stay with the
lead. Agents may draft in isolated copies before 001 (new files only). MVP: Stories 1 and 2. Requirement coverage:
FR-001 → 003; FR-002 → 004; FR-003 → 002, 005; FR-004 → 006; FR-005 → 006; FR-006 → 005; FR-007 → 004, 005, 007 … 010.
