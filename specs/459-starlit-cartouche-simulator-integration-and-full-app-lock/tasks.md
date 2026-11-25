# Tasks: R02-G16-09 — Starlit Cartouche: simulator integration and full app lock

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G16-09 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G16-09 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_459;
tests stay short (< 10 s each; interface tests < 90 s, SC-R02G1609-001). No {owner} tasks; no GLSL or CPU reference
change (the shaders and reference of R02-G16-03 are unchanged and re-proven by the rendering runs).

## Phase 1: Setup

- [X] T-R02G1609-001 Baselines after R02-G16-08 is recorded: `--name baseline-host`, `--name baseline-timing`, `--name — Verified 2026-11-25: 2026-11-25 baseline-host and round02-1, -2, -3c, -3e, -3f exit 0; baseline-timing printed bounds above its asserts (process tree at background priority PRI 4, VisualCore unchanged), host scheduling, not code; rendering baseline is R02-G16-08's rendering runs (exit 0)
  baseline-round02-1`, `-2`, `-3c`, `-3e`, `-3f` (the round-two chunks of feature 457); the rendering baseline is
  R02-G16-08's rendering runs (exit 0)

## Phase 2: Foundational

- [X] T-R02G1609-002 Create `Packages/ExperiencesRound02/StarlitCartouche/Core/StarlitCartoucheSchemaExamples.swift` — Verified 2026-11-25: 2026-11-25 host exit 0 (7 schema-example tests by agent A, retested by the lead); registry stores both examples
  (contracts/api.md; data-model: schema 1 "`{level: 1, records}` of a seeded play of level 1 with its first certified
  leg applied (playing, not won), seed 7"; schema 2 "campaign mode, the tutorial done, progress (frontier 2, level 1
  solved with actions spent one above the certified count and its stars), records []", "the result is kept, unverified,
  without a trace"; the envelope of `VoxelOrigamiSchemaExamples`, feature 449) with
  `Packages/ExperiencesRound02/StarlitCartouche/CoreTests/StarlitCartoucheSchemaExampleTests.swift` (agent A: both
  restore through `migrations` to schema 3 with level 1, the leg and progress kept; the expected digests match;
  versions other than 1 and 2 give nil); edit `Apps/VisualCore/App/ExperienceRegistry.swift` (`examples:` with both;
  the schema comment updated); `--name host -- swift test --package-path Packages/ExperiencesRound02 --filter
  StarlitCartoucheSchemaExampleTests`

## Phase 3: Story 1 — the game works inside the real app (P1) 🎯

- [X] T-R02G1609-003 [US1] Edit — Verified 2026-11-25: 2026-11-25 sim-27 exit 0 (66 tests incl. agent E's 4 identifier tests; 37 names pinned)
  `Packages/ExperiencesRound02/StarlitCartouche/Experience/StarlitCartoucheControls.swift`: `identifierNames` lists the
  37 identifiers the panel already gives through `port.identifier` (spec Clarifications Q1: star, star-minus, star-plus,
  wait, wait-minus, wait-plus, fly, leg-detail, undo, redo, next-level, reset-view, dismiss-tutorial, hint,
  failure-undo, retry, campaign, daily, practice, level-picker, play-level, replay, replay-step, replay-stop, sound,
  summary, status, actions, pending, progress, message, failure, explanation, instruction, hint-text, goal,
  replay-position; unique), with
  `Packages/ExperiencesRound02/StarlitCartouche/ExperienceTests/StarlitCartoucheIdentifierTests.swift` (agent E: every
  name of Q1 is listed once, has the prefix `experience.r02-g16.starlit-cartouche.`, and the panel source uses each
  exactly once); `--name sim-27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme
  ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing StarlitCartoucheExperienceTests`
- [X] T-R02G1609-004 [US1] Create `Apps/VisualCore/Tests/UI/StarlitCartouche/SCSupport.swift`, `SCPlayUITests.swift`, — Verified 2026-11-25: 2026-11-25 app-ui exit 0: chunk y3 ran SCPlayUITests (94.5 s, relaunch 131.1 s) and SCReplayUITests (80.7 s) by agent C, passing unedited (launch setup about 30 s per launch); y3 serial, key unique (script test); xcodegen regenerated
  `SCReplayUITests.swift` (agent C: spec Clarifications Q2; level 1's certified legs (to star 4 after 1 beat, then to
  star 5 after 0 beats) and the budget (9) pinned in `SC`; each leg's destination and wait chosen with Star + or Star −
  and Wait + or Wait − by their controls' values, Fly tapped, each press counted only when the actions-left count of the
  `actions` text moves; read "The trail draws the symbol and the ship rests at the beacon." and "Stars: 3 of 3.";
  background before terminate on relaunch); edit `scripts/release_check.py` (`UI_CHUNKS["y3"]`, `"y3"` in
  `SERIAL_CHUNKS`) and `scripts/test_scripts.py` (agent D; the key `y3` checked unique among the keys; any new test
  class above the `if __name__ == "__main__":` block); `xcodegen generate --spec project.yml` and a grep of the project
  for `SCPlayUITests`; `--name app-ui -- python3 scripts/release_check.py --only app-build-for-testing-ios27
  app-ui-ios27-y3`

## Phase 4: Story 2 — the app's logic accepts the game (P1)

- [X] T-R02G1609-005 [US2] Edit `Apps/VisualCore/Tests/Unit/AppModelTests.swift` (agent B: both examples restore — Verified 2026-11-25: 2026-11-25 app-unit exit 0 (143 tests; the 4 Starlit tests by agent B pass: examples restore, candidate not available, level 1 won through the engine, SC pins equal the Core)
  through the app's migration check; the candidate opens through the registry and engine and plays level 1 to a win;
  without `-vcCandidates` it is not available and not openable; `SC`'s pinned level 1 certified legs and budget
  equal the Core's); `--name app-unit -- python3 scripts/release_check.py --only app-build-for-testing-ios27
  app-unit-ios27`

## Phase 5: Story 3 — builds and solvability (P2)

- [ ] T-R02G1609-006 [US3] Release build and symbols (`StarlitCartoucheGolden`, `acceptanceScenarios` already
  forbidden): `--name release -- python3 scripts/release_check.py --only app-release-build app-release-symbols`;
  `--name regression -- python3 scripts/starlit_cartouche_regression.py` (100 of 100 levels, SC-R02G1609-004)

## Phase 6: Regression, documentation and close

- [ ] T-R02G1609-007 Docs: `docs/architecture/starlit-cartouche.md` (in-app integration),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host-1`, `-2`, `-3c`, `-3e`,
  `-3f`; `--name script-tests` (alone)
- [ ] T-R02G1609-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full` (app-unit and app-ui are this gate's own runs)
- [ ] T-R02G1609-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G1609-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G1609-011 {device} After ImplementationLock-100: the same journeys on D1/D2/D3 (SC-R02G1609-006; feature 460
  prepares them)
- [ ] T-R02G1609-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated; after the record push, check its CI run with `gh run list`

## Dependencies and parallel work

001 → 002 (lead; agent A tests) → 003 (lead; agent E tests) → {004 (agents C, D), 005 (agent B), 006} → 007 … 010, 012.
011 stays open until device testing. Shared files (examples source, registry, controls, project.yml, docs) stay with the
lead. Agents may draft in isolated copies before 001 (new files only). MVP: Stories 1 and 2. Requirement coverage:
FR-001 → 003; FR-002 → 004; FR-003 → 002, 005; FR-004 → 006; FR-005 → 006; FR-006 → 005; FR-007 → 004, 005, 007 … 010.
