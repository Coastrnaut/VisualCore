# Tasks: R02-G12-09 — Harmonic Bridges: simulator integration and full app lock

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G12-09 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G12-09 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_419;
tests stay short (< 10 s each; interface tests < 90 s, SC-R02G1209-001). No {owner} tasks; no GLSL or CPU reference
change (the shaders and reference of R02-G12-03 are unchanged and re-proven by the rendering runs).

## Phase 1: Setup

- [X] T-R02G1209-001 Baselines after R02-G12-08 is recorded: `--name baseline-host`, `--name baseline-timing`, `--name — Verified 2026-11-23: baseline-host, baseline-timing, baseline-round02 exit 0 on the committed tree; rendering baseline is R02-G12-08's rendering runs
  baseline-round02 -- swift test --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G12-08's
  rendering runs (exit 0)

## Phase 2: Foundational

- [X] T-R02G1209-002 Create `Packages/ExperiencesRound02/HarmonicBridges/Core/HarmonicBridgesSchemaExamples.swift` — Verified 2026-11-23: host (HarmonicBridgesSchemaExampleTests 7 tests: schema-1 {level 1, records} with the certified tuning and schema-2 (campaign, frontier 2, level 1 solved, 3 actions, 2 stars, no trace) restore through migrations to schema 3, digests match, other versions nil, deterministic) exit 0, lead retest; registration stores both examples with the comment corrected (app-unit: testTheHarmonicBridgesRegistrationRestoresItsStoredExamples passes)
  (contracts/api.md; data-model: schema 1 "`{level: 1, records}` of a seeded play of level 1 with its one certified
  tuning applied (playing, not won), seed 7"; schema 2 "campaign mode, progress (level 2 open, level 1 solved with its
  actions spent and stars), records []", "the result is kept, unverified, without a trace"; the envelope of
  `EchoCartographerSchemaExamples`, feature 409) with
  `Packages/ExperiencesRound02/HarmonicBridges/CoreTests/HarmonicBridgesSchemaExampleTests.swift` (agent A: both
  restore through `migrations` to schema 3 with level 1, the tuning and progress kept; the expected digests match;
  versions other than 1 and 2 give nil); edit `Apps/VisualCore/App/ExperienceRegistry.swift` (`examples:` with both;
  the stale schema comment corrected); `--name host -- swift test --package-path Packages/ExperiencesRound02 --filter
  HarmonicBridgesSchemaExampleTests`

## Phase 3: Story 1 — the game works inside the real app (P1) 🎯

- [X] T-R02G1209-003 [US1] Edit `Packages/ExperiencesRound02/HarmonicBridges/Experience/HarmonicBridgesControls.swift`: — Verified 2026-11-23: sim-27 (67 Harmonic Bridges simulator tests incl. HarmonicBridgesIdentifierTests: the 30 names listed once, lower-case tokens, each port.identifier used exactly once in the panel source and no unlisted one, every identifier prefixed experience.r02-g12.harmonic-bridges. and unique) exit 0, lead retest
  `identifierNames` lists the 30 identifiers the panel already gives through `port.identifier` (spec Clarifications Q1:
  string, peg, tune, test, undo, redo, next-level, reset-view, dismiss-tutorial, hint, failure-undo, retry, campaign,
  daily, practice, level-picker, play-level, replay, replay-step, replay-stop, sound, summary, status, actions, message,
  failure, instruction, hint-text, goal, replay-position; unique), with
  `Packages/ExperiencesRound02/HarmonicBridges/ExperienceTests/HarmonicBridgesIdentifierTests.swift` (agent E: every
  name of Q1 is listed once, has the prefix `experience.r02-g12.harmonic-bridges.`, and the panel source uses each
  exactly once); `--name sim-27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme
  ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing HarmonicBridgesExperienceTests`
- [X] T-R02G1209-004 [US1] Create `Apps/VisualCore/Tests/UI/HarmonicBridges/HBSupport.swift`, `HBPlayUITests.swift`, — Verified 2026-11-23: app-ui (serial chunk u3: HBPlayUITests win level 1 by stepping the peg to 12, Tune and Test, 3 stars, level 2 open, 50 s; progress survives a relaunch, 98 s with two launches; HBReplayUITests replay ends won and Stop returns to the campaign, 52 s) exit 0; xcodegen regenerated, HBPlayUITests in the project; u3 unique, test_harmonic_bridges_ui_chunk passes
  `HBReplayUITests.swift` (agent C: spec Clarifications Q2; level 1's certified actions (tune string 0 to peg 12, then
  the test), the opening choice (string 0, peg 11) and the budget (9) pinned in `HB`; each tuning played by stepping the
  string and peg steppers to the tuning (reading each value, counting a press only when it moves), then Tune; finally
  Test; read "The crossing holds in every step" and "Stars: 3 of 3"; background before terminate on relaunch); edit
  `scripts/release_check.py` (`UI_CHUNKS["u3"]`, `"u3"` in `SERIAL_CHUNKS`) and `scripts/test_scripts.py` (agent D; the
  key `u3` checked unique among the keys; any new test class above the `if __name__ == "__main__":` block);
  `xcodegen generate --spec project.yml` and a grep of the project for `HBPlayUITests`; `--name app-ui -- python3
  scripts/release_check.py --only app-build-for-testing-ios27 app-ui-ios27-u3`

## Phase 4: Story 2 — the app's logic accepts the game (P1)

- [X] T-R02G1209-005 [US2] Edit `Apps/VisualCore/Tests/Unit/AppModelTests.swift` (agent B: both examples restore — Verified 2026-11-23: app-unit (app build for testing; VisualCoreTests incl. testTheHarmonicBridgesRegistrationRestoresItsStoredExamples, testHarmonicBridgesIsACandidateAndNotAvailableWithoutTheCandidatesArgument, testHarmonicBridgesOpensAsACandidateAndLevelOneIsWonByItsCertifiedActions, testHarmonicBridgesLevelOnePinsInHBEqualTheCore) exit 0, lead retest
  through the app's migration check; the candidate opens through the registry and engine and plays level 1 to a win;
  without `-vcCandidates` it is not available and not openable; `HB`'s pinned level 1 certified actions, opening choice
  and budget equal the Core's); `--name app-unit -- python3 scripts/release_check.py --only app-build-for-testing-ios27
  app-unit-ios27`

## Phase 5: Story 3 — builds and solvability (P2)

- [X] T-R02G1209-006 [US3] Release build and symbols (`HarmonicBridgesGolden`, `acceptanceScenarios` already — Verified 2026-11-23: release (app-release-build and app-release-symbols: HarmonicBridgesGolden and acceptanceScenarios absent) exit 0; regression (host 24 tests: 100 of 100 levels replayed and re-solved, golden digests; simulator 6 tests: golden frames and 12 memory cycles, growth under 0.6 MB) exit 0
  forbidden): `--name release -- python3 scripts/release_check.py --only app-release-build app-release-symbols`;
  `--name regression -- python3 scripts/harmonic_bridges_regression.py` (100 of 100 levels, SC-R02G1209-004)

## Phase 6: Regression, documentation and close

- [X] T-R02G1209-007 Docs: `docs/architecture/harmonic-bridges.md` (in-app integration), — Verified 2026-11-23: round02-host (355 s) and script-tests (alone) exit 0; architecture doc in-app integration, ExperiencesRound02 README feature 419, testing doc entry; validate_docs passes
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`; `--name script-tests`
  (alone)
- [X] T-R02G1209-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-23: rendering-27, rendering-26, experiences, host-full exit 0 (app-unit and app-ui are this gate's own runs)
  `--name host-full` (app-unit and app-ui are this gate's own runs)
- [X] T-R02G1209-009 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-23: reference-1 exit 0
- [X] T-R02G1209-010 Reference regression chunk 2 (`--name reference-2`) — Verified 2026-11-23: reference-2 exit 0
- [ ] T-R02G1209-011 {device} After ImplementationLock-100: the same journeys on D1/D2/D3 (SC-R02G1209-006; feature 420
  prepares them)
- [X] T-R02G1209-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record; — Verified 2026-11-23: converge round 1 appended nothing; README row, gate list and feature count updated
  README row and gate list updated; after the record push, check its CI run with `gh run list`

## Dependencies and parallel work

001 → 002 (lead; agent A tests) → 003 (lead; agent E tests) → {004 (agents C, D), 005 (agent B), 006} → 007 … 010, 012.
011 stays open until device testing. Shared files (examples source, registry, controls, project.yml, docs) stay with the
lead. Agents may draft in isolated copies before 001 (new files only). MVP: Stories 1 and 2. Requirement coverage:
FR-001 → 003; FR-002 → 004; FR-003 → 002, 005; FR-004 → 006; FR-005 → 006; FR-006 → 005; FR-007 → 004, 005, 007 … 010.
