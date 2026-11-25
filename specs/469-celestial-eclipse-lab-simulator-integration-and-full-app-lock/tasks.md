# Tasks: R02-G17-09 — Celestial Eclipse Lab: simulator integration and full app lock

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G17-09 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G17-09 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_469;
tests stay short (< 10 s each; interface tests < 90 s, SC-R02G1709-001). No {owner} tasks; no GLSL or CPU reference
change (the shaders and reference of R02-G17-03 are unchanged and re-proven by the rendering runs).

## Phase 1: Setup

- [X] T-R02G1709-001 Baselines on the committed tree after R02-G17-08 is recorded: `--name baseline-host`, `--name — Verified 2026-11-25: 2026-11-25 baseline-host, baseline-timing, baseline-round02-1, -2, -3c, -3e, -3f exit 0 on the committed tree (.autonomy/migration/checks/R02-G17-09.baseline-*.json)
  baseline-timing`, `--name baseline-round02-1`, `-2`, `-3c`, `-3e`, `-3f` (the five round-two chunks, 3c with
  `CelestialEclipseLab`); the rendering baseline is R02-G17-08's rendering runs (exit 0)

## Phase 2: Foundational

- [X] T-R02G1709-002 Create — Verified 2026-11-25: 2026-11-25 host exit 0, 7 schema example tests (.autonomy/migration/checks/R02-G17-09.host.json): schema-1 and schema-2 examples migrate to schema 3 and restore with the phase change and progress kept; registered in ExperienceRegistry with examples:
  `Packages/ExperiencesRound02/CelestialEclipseLab/Core/CelestialEclipseLabSchemaExamples.swift` (contracts/api.md;
  data-model: schema 1 "`{level: 1, records}` of a seeded play of level 1 with its first certified phase change applied
  (playing, not won), seed 7"; schema 2 "campaign mode, the tutorial done, progress (frontier 2, level 1 solved with
  actions spent one above the certified count and its stars), the records of a fresh play", "the result is kept,
  unverified, without a trace"; the envelope of `StarlitCartoucheSchemaExamples`, feature 459) with
  `Packages/ExperiencesRound02/CelestialEclipseLab/CoreTests/CelestialEclipseLabSchemaExampleTests.swift` (agent A: both
  restore through `migrations` to schema 3 with level 1, the phase change and progress kept; the expected digests match;
  versions other than 1 and 2 give nil); edit `Apps/VisualCore/App/ExperienceRegistry.swift` (`examples:` with both; the
  schema comment updated); `--name host -- swift test --package-path Packages/ExperiencesRound02 --filter
  CelestialEclipseLabSchemaExampleTests`

## Phase 3: Story 1 — the game works inside the real app (P1) 🎯

- [X] T-R02G1709-003 [US1] Edit — Verified 2026-11-25: 2026-11-25 sim-27 exit 0, 68 simulator tests incl. 4 identifier tests (.autonomy/migration/checks/R02-G17-09.sim-27.json); identifierNames pins 41 names, each used once; the failure explanation has its own identifier explanation
  `Packages/ExperiencesRound02/CelestialEclipseLab/Experience/CelestialEclipseLabControls.swift`: the failure
  explanation's identifier becomes `explanation` (it shared `failure`), and `identifierNames` lists the 41 identifiers
  (spec Clarifications Q1: planet, planet-minus, planet-plus, planet-detail, phase, phase-minus, phase-plus, set-phase,
  reset-view, tick, tick-minus, tick-plus, tick-detail, run, undo, redo, next-level, dismiss-tutorial, hint, campaign,
  daily, practice, level-picker, play-level, replay, replay-step, replay-stop, sound, actions, status, failure,
  explanation, progress, summary, message, tutorial, hint-text, band, stars, goal, replay-position; unique), with
  `Packages/ExperiencesRound02/CelestialEclipseLab/ExperienceTests/CelestialEclipseLabIdentifierTests.swift` (agent E:
  every name of Q1 is listed once, has the prefix `experience.r02-g17.celestial-eclipse-lab.`, and the panel source
  uses each exactly once); `--name sim-27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02
  --scheme ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing
  CelestialEclipseLabExperienceTests`
- [X] T-R02G1709-004 [US1] Create `Apps/VisualCore/Tests/UI/CelestialEclipseLab/CELSupport.swift`, — Verified 2026-11-25: 2026-11-25 app-ui exit 0 (.autonomy/migration/checks/R02-G17-09.app-ui.json): CELPlayUITests (level 1 won through the panel with 3 of 3 stars, progress kept over a relaunch) and CELReplayUITests (replay to a win, Stop back to campaign), 3 tests in 321 s including four app launches (replay class 86 s); chunk z3 serial and unique; xcodegen regenerated
  `CELPlayUITests.swift`, `CELReplayUITests.swift` (agent C: spec Clarifications Q2; level 1's certified plan (body 1
  to phase 2, then body 2 to phase 0) and the budget (9) pinned in `CEL`; each body chosen with Planet + or Planet −
  by the planet control's value, its pending phase moved with Phase + or Phase − by the phase control's value, Set
  phase tapped, each press counted only when the actions-left count of the `actions` text moves, then Run; read "Every
  target eclipse came in order inside its window." and "Best: 3 of 3 stars"; background before terminate on relaunch);
  edit `scripts/release_check.py` (`UI_CHUNKS["z3"]`, `"z3"` in `SERIAL_CHUNKS`) and `scripts/test_scripts.py` (agent
  D; the key `z3` checked unique among the keys; any new test class above the `if __name__ == "__main__":` block);
  `xcodegen generate --spec project.yml` and a grep of the project for `CELPlayUITests`; `--name app-ui -- python3
  scripts/release_check.py --only app-build-for-testing-ios27 app-ui-ios27-z3`

## Phase 4: Story 2 — the app's logic accepts the game (P1)

- [X] T-R02G1709-005 [US2] Edit `Apps/VisualCore/Tests/Unit/AppModelTests.swift` (agent B: both examples restore — Verified 2026-11-25: 2026-11-25 app-unit exit 0, 147 app unit tests (143 before; the four new Celestial Eclipse Lab tests: stored examples restore, candidate not available without -vcCandidates, level 1 won through registry and engine with its trace, CEL pins equal the Core) (.autonomy/migration/checks/R02-G17-09.app-unit.json)
  through the app's migration check; the candidate opens through the registry and engine and plays level 1 to a win;
  without `-vcCandidates` it is not available and not openable; `CEL`'s pinned level 1 certified plan and budget
  equal the Core's); `--name app-unit -- python3 scripts/release_check.py --only app-build-for-testing-ios27
  app-unit-ios27`

## Phase 5: Story 3 — builds and solvability (P2)

- [X] T-R02G1709-006 [US3] Release build and symbols (`CelestialEclipseLabGolden`, `acceptanceScenarios` — Verified 2026-11-25: 2026-11-25 release exit 0: app-release-build and app-release-symbols pass (.autonomy/migration/checks/R02-G17-09.release.json); regression exit 0: host and simulator parts pass, 100 of 100 levels (.autonomy/migration/checks/R02-G17-09.regression.json)
  already forbidden): `--name release -- python3 scripts/release_check.py --only app-release-build app-release-symbols`;
  `--name regression -- python3 scripts/celestial_eclipse_lab_regression.py` (100 of 100 levels, SC-R02G1709-004)

## Phase 6: Regression, documentation and close

- [ ] T-R02G1709-007 Docs: `docs/architecture/celestial-eclipse-lab.md` (in-app integration),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host-1`, `-2`, `-3c`, `-3e`,
  `-3f`; `--name script-tests` (alone)
- [ ] T-R02G1709-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full` (app-unit and app-ui are this gate's own runs)
- [ ] T-R02G1709-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G1709-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G1709-011 {device} After ImplementationLock-100: the same journeys on D1/D2/D3 (SC-R02G1709-006; feature 470
  prepares them)
- [ ] T-R02G1709-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated; after the record push, check its CI run with `gh run list`

## Dependencies and parallel work

001 → 002 (lead; agent A tests) → 003 (lead; agent E tests) → {004 (agents C, D), 005 (agent B), 006} → 007 … 010, 012.
011 stays open until device testing. Shared files (examples source, registry, controls, project.yml, docs) stay with the
lead. Agents may draft in isolated copies before 001 (new files only). MVP: Stories 1 and 2. Requirement coverage:
FR-001 → 003; FR-002 → 004; FR-003 → 002, 005; FR-004 → 006; FR-005 → 006; FR-006 → 005; FR-007 → 004, 005, 007 … 010.
