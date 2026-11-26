# Tasks: R02-G19-09 — Microscopic Aurora: simulator integration and full app lock

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G19-09 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G19-09 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_489;
tests stay short (< 10 s each; interface tests < 90 s, SC-R02G1909-001). No {owner} tasks; no GLSL or CPU reference
change (the shaders and reference of R02-G19-03 are unchanged and re-proven by the rendering runs).

## Phase 1: Setup

- [ ] T-R02G1909-001 Baselines on the committed tree after R02-G19-08 is recorded: `--name baseline-host`, `--name
  baseline-timing`, `--name baseline-round02-1`, `-2`, `-3c`, `-3e`, `-3f` (the five round-two chunks, 3f with
  `MicroscopicAurora`); the rendering baseline is R02-G19-08's rendering runs (exit 0)

## Phase 2: Foundational

- [ ] T-R02G1909-002 Create `Packages/ExperiencesRound02/MicroscopicAurora/Core/MicroscopicAuroraSchemaExamples.swift`
  (contracts/api.md; data-model: schema 1 "`{level: 1, records}` of a seeded play of level 1 with one non-winning well
  placed (playing, not won), seed 7"; schema 2 "campaign mode, the tutorial done, progress (frontier 2, level 1 solved
  with actions spent one above the certified count and its stars), the records of a fresh play", "the result is kept,
  unverified, without a trace"; the envelope of `ApsidesWorkshopSchemaExamples`, feature 479) with
  `Packages/ExperiencesRound02/MicroscopicAurora/CoreTests/MicroscopicAuroraSchemaExampleTests.swift` (agent A: both restore
  through `migrations` to schema 3 with level 1, the well and progress kept; the expected digests match; versions
  other than 1 and 2 give nil); edit `Apps/VisualCore/App/ExperienceRegistry.swift` (`examples:` with both; the schema
  comment updated); `--name host -- swift test --package-path Packages/ExperiencesRound02 --filter
  MicroscopicAuroraSchemaExampleTests`

## Phase 3: Story 1 — the game works inside the real app (P1) 🎯

- [ ] T-R02G1909-003 [US1] Edit `Packages/ExperiencesRound02/MicroscopicAurora/Experience/MicroscopicAuroraControls.swift`:
  the failure explanation's identifier becomes `explanation` (it shared `failure`), and `identifierNames` lists the 48
  identifiers (spec Clarifications Q1: slot, slot-minus, slot-plus, selection, wells-detail, site, site-minus, site-plus,
  strength, strength-minus, strength-plus, sense, place, remove, freeze, reset-view, tick, tick-minus, tick-plus, tick-detail, play, undo, redo, next-level, dismiss-tutorial, hint, campaign, daily, practice,
  level-picker, play-level, replay, replay-step, replay-stop, sound, actions, status, failure, explanation, progress,
  summary, message, tutorial, hint-text, band, stars, goal, replay-position; unique), with
  `Packages/ExperiencesRound02/MicroscopicAurora/ExperienceTests/MicroscopicAuroraIdentifierTests.swift` (agent E: every
  name of Q1 is listed once, has the prefix `experience.r02-g19.microscopic-aurora.`, and the panel source uses each
  exactly once); `--name sim-27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme
  ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing MicroscopicAuroraExperienceTests`
- [ ] T-R02G1909-004 [US1] Create `Apps/VisualCore/Tests/UI/MicroscopicAurora/MASupport.swift`, `MAPlayUITests.swift`,
  `MAReplayUITests.swift` (agent C: spec Clarifications Q2; level 1's certified plan (its wells from
  `MicroscopicAuroraExperienceCore.certifiedActions(1)`: slot, site, strength, sense) and the budget pinned in `MA`; for
  each well the slot, site and strength moved with Well, Site and Strength − or + by their controls' values and the sense
  toggled to match, Place tapped, counted only when the actions-left count of the `actions` text moves, then Play; read
  "The trails covered the stencil as one pattern." and "Best: 3 of 3 stars"; background before terminate on relaunch); edit
  `scripts/release_check.py` (`UI_CHUNKS["b4"]`, `"b4"` in `SERIAL_CHUNKS`) and `scripts/test_scripts.py` (agent D; the
  key `b4` checked unique among the keys; any new test class above the `if __name__ == "__main__":` block); `xcodegen
  generate --spec project.yml` and a grep of the project for `MAPlayUITests`; `--name app-ui -- python3
  scripts/release_check.py --only app-build-for-testing-ios27 app-ui-ios27-b4`

## Phase 4: Story 2 — the app's logic accepts the game (P1)

- [ ] T-R02G1909-005 [US2] Edit `Apps/VisualCore/Tests/Unit/AppModelTests.swift` (agent B: both examples restore through
  the app's migration check; the candidate opens through the registry and engine and plays level 1 to a win; without
  `-vcCandidates` it is not available and not openable; `MA`'s pinned level 1 certified plan and budget equal the
  Core's); `--name app-unit -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`

## Phase 5: Story 3 — builds and solvability (P2)

- [ ] T-R02G1909-006 [US3] Release build and symbols (`MicroscopicAuroraGolden`, `acceptanceScenarios` already forbidden):
  `--name release -- python3 scripts/release_check.py --only app-release-build app-release-symbols`; `--name regression
  -- python3 scripts/microscopic_aurora_regression.py` (100 of 100 levels, SC-R02G1909-004)

## Phase 6: Regression, documentation and close

- [ ] T-R02G1909-007 Docs: `docs/architecture/microscopic-aurora.md` (in-app integration),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host-1`, `-2`, `-3c`, `-3e`,
  `-3f`; `--name script-tests` (alone)
- [ ] T-R02G1909-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, `--name
  host-full` (app-unit and app-ui are this gate's own runs)
- [ ] T-R02G1909-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G1909-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G1909-011 {device} After ImplementationLock-100: the same journeys on D1/D2/D3 (SC-R02G1909-006; feature 490
  prepares them)
- [ ] T-R02G1909-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated; after the record push, check its CI run with `gh run list`

## Dependencies and parallel work

001 → 002 (lead; agent A tests) → 003 (lead; agent E tests) → {004 (agents C, D), 005 (agent B), 006} → 007 … 010, 012.
011 stays open until device testing. Shared files (examples source, registry, controls, project.yml, docs) stay with the
lead. Agents may draft in isolated copies before 001 (new files only). MVP: Stories 1 and 2. Requirement coverage:
FR-001 → 003; FR-002 → 004; FR-003 → 002, 005; FR-004 → 006; FR-005 → 006; FR-006 → 005; FR-007 → 004, 005, 007 … 010.
