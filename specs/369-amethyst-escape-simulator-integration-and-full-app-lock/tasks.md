# Tasks: R02-G07-09 — Amethyst Escape: simulator integration and full app lock

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G07-09 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G07-09 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_369;
tests stay short (< 10 s each; interface tests < 90 s, SC-R02G0709-001). No {owner} tasks; no GLSL or CPU reference
change (the shaders and reference of R02-G07-03 are unchanged and re-proven by the rendering runs).

## Phase 1: Setup

- [X] T-R02G0709-001 Baselines: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02 -- swift test — Verified 2026-11-22: baseline-host, baseline-timing, baseline-round02 exit=0; rendering baseline is R02-G07-08's rendering runs (exit 0)
  --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G07-08's rendering runs (exit 0)

## Phase 2: Foundational

- [ ] T-R02G0709-002 Create `Packages/ExperiencesRound02/AmethystEscape/Core/AmethystEscapeSchemaExamples.swift`
  (contracts/api.md; data-model: schema 1 "a seeded play of level 1 with one turn that does not win, seed 7";
  schema 2 "campaign mode, progress {frontier 2, solved [level 1, best moves, stars]}, tutorial", "the result is kept,
  unverified, without a trace"; the envelope of `ChronoConstellatorSchemaExamples`) with
  `Packages/ExperiencesRound02/AmethystEscape/CoreTests/AmethystEscapeSchemaExampleTests.swift` (agent A: both
  restore through `migrations` to schema 3 with level 1, the turn and progress kept; the expected digests
  match; versions other than 1 and 2 give nil); edit `Apps/VisualCore/App/ExperienceRegistry.swift` (`examples:` with
  both; the stale schema comment corrected); `--name host -- swift test --package-path Packages/ExperiencesRound02`

## Phase 3: Story 1 — the game works inside the real app (P1) 🎯

- [ ] T-R02G0709-003 [US1] Edit `Packages/ExperiencesRound02/AmethystEscape/Experience/AmethystEscapeControls.swift`:
  identifiers `experience.r02-g07.amethyst-escape.<name>` through `port.identifier` (spec Clarifications Q1 names:
  turn-down, turn-up, advance, undo, redo, next-level, show-all-layers, reset-view, hint, dismiss-tutorial,
  failure-undo, retry, campaign, daily, practice, play-level, replay, replay-step, replay-stop, shell-picker,
  level-picker, sound, summary; unique; `identifierNames` lists them) with
  `Packages/ExperiencesRound02/AmethystEscape/ExperienceTests/AmethystEscapeIdentifierTests.swift` (agent E:
  every name of Q1 is listed once by the controls' identifier list and has the prefix); `--name sim-27 -- python3
  scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package
  --destination sim-27.2 --action test --only-testing AmethystEscapeExperienceTests`
- [ ] T-R02G0709-004 [US1] Create `Apps/VisualCore/Tests/UI/AmethystEscape/AESupport.swift`, `AEPlayUITests.swift`,
  `AEReplayUITests.swift` (agent C: spec Clarifications Q2; level 1 certified actions and the shell picker's starting
  shell pinned in `AE`; each turn played by stepping the shell picker to its shell, then Turn + or Turn −; each advance
  by Advance; read "The pearl escaped through the exit gap" and "Stars: 3 of 3"; background before terminate on
  relaunch); edit `scripts/release_check.py` (`UI_CHUNKS["p3"]`, `"p3"` in `SERIAL_CHUNKS`) and
  `scripts/test_scripts.py` (agent D; the key `p3` checked unique among the keys); `project.yml` + `xcodegen generate`
  if needed; `--name app-ui -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-ui-ios27-p3`

## Phase 4: Story 2 — the app's logic accepts the game (P1)

- [ ] T-R02G0709-005 [US2] Edit `Apps/VisualCore/Tests/Unit/AppModelTests.swift` (agent B: both examples restore through
  the app's migration check; the candidate opens through the registry and engine and plays level 1 to a win; without
  `-vcCandidates` it is not available and not openable; `AE`'s pinned level 1 certified actions and the
  shell picker's starting shell (the convergence lesson of feature 319) equal the Core's); `--name app-unit -- python3
  scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`

## Phase 5: Story 3 — builds and solvability (P2)

- [ ] T-R02G0709-006 [US3] Release build and symbols (`AmethystEscapeGolden`, `acceptanceScenarios` already
  forbidden): `--name release -- python3 scripts/release_check.py --only app-release-build app-release-symbols`;
  `--name regression -- python3 scripts/amethyst_escape_regression.py` (100 of 100 levels, SC-R02G0709-004)

## Phase 6: Regression, documentation and close

- [ ] T-R02G0709-007 Docs: `docs/architecture/amethyst-escape.md` (in-app integration),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`; `--name script-tests`
  (alone)
- [ ] T-R02G0709-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full` (app-unit and app-ui are this gate's own runs)
- [ ] T-R02G0709-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G0709-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G0709-011 {device} After ImplementationLock-100: the same journeys on D1/D2/D3 (SC-R02G0709-006; feature 370
  prepares them)
- [ ] T-R02G0709-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  after the record push, check its CI run with `gh run list`

## Dependencies and parallel work

001 → 002 (lead; agent A tests) → 003 (lead; agent E tests) → {004 (agents C, D), 005 (agent B), 006} → 007 … 010, 012.
011 stays open until device testing. Shared files (examples source, registry, controls, project.yml, docs) stay with the
lead. MVP: Stories 1 and 2.
