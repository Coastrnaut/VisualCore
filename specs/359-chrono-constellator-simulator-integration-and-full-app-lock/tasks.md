# Tasks: R02-G06-09 — Chrono Constellator: simulator integration and full app lock

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G06-09 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G06-09 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_359;
tests stay short (< 10 s each; interface tests < 90 s, SC-R02G0609-001). No {owner} tasks; no GLSL or CPU reference
change (the shaders and reference of R02-G06-03 are unchanged and re-proven by the rendering runs).

## Phase 1: Setup

- [X] T-R02G0609-001 Baselines: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02 -- swift test — Verified 2026-11-22: baseline-host, baseline-timing, baseline-round02 exit=0 (on 4aaa54d90, before this gate's edits); rendering baseline is R02-G06-08's runs (exit 0)
  --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G06-08's rendering runs (exit 0)

## Phase 2: Foundational

- [X] T-R02G0609-002 Create `Packages/ExperiencesRound02/ChronoConstellator/Core/ChronoConstellatorSchemaExamples.swift` — Verified 2026-11-22: host exit=0 (round-two host suite incl. ChronoConstellatorSchemaExampleTests 7/7: both examples restore to schema 3, digests match, other versions nil); registry stores both examples, comment corrected
  (contracts/api.md; data-model: schema 1 "a seeded play of level 1 with one phase change that does not win, seed 7";
  schema 2 "campaign mode, progress {frontier 2, solved [level 1, best edits, stars]}, tutorial", "the result is kept,
  unverified, without a trace"; the envelope of `ColorfallCanyonsSchemaExamples`) with
  `Packages/ExperiencesRound02/ChronoConstellator/CoreTests/ChronoConstellatorSchemaExampleTests.swift` (agent A: both
  restore through `migrations` to schema 3 with level 1, the phase change and progress kept; the expected digests
  match; versions other than 1 and 2 give nil); edit `Apps/VisualCore/App/ExperienceRegistry.swift` (`examples:` with
  both; the stale schema comment corrected); `--name host -- swift test --package-path Packages/ExperiencesRound02`

## Phase 3: Story 1 — the game works inside the real app (P1) 🎯

- [X] T-R02G0609-003 [US1] Edit `Packages/ExperiencesRound02/ChronoConstellator/Experience/ChronoConstellatorControls.swift`: — Verified 2026-11-22: sim-27 exit=0 (ChronoConstellatorExperienceTests on sim-27.2 incl. ChronoConstellatorIdentifierTests: 28 names, each once, prefixed and unique)
  identifiers `experience.r02-g06.chrono-constellator.<name>` through `port.identifier` (spec Clarifications Q1 names:
  phase-down, phase-up, add-hold, remove-hold, step-1, step-10, run, rewind, undo, redo, next-level, reset-view, hint,
  dismiss-tutorial, failure-undo, failure-rewind, retry, campaign, daily, practice, play-level, replay, replay-step,
  replay-stop, star-picker, level-picker, sound, summary; unique; `identifierNames` lists them) with
  `Packages/ExperiencesRound02/ChronoConstellator/ExperienceTests/ChronoConstellatorIdentifierTests.swift` (agent E:
  every name of Q1 is listed once by the controls' identifier list and has the prefix); `--name sim-27 -- python3
  scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package
  --destination sim-27.2 --action test --only-testing ChronoConstellatorExperienceTests`
- [ ] T-R02G0609-004 [US1] Create `Apps/VisualCore/Tests/UI/ChronoConstellator/CRSupport.swift`, `CRPlayUITests.swift`,
  `CRReplayUITests.swift` (agent C: spec Clarifications Q2; level 1 certified phase changes, default phases and loop
  lengths pinned in `CR`; each changed star reached by stepping the star picker, then Phase + or Phase − the shorter way
  round its loop; Run; read "Every star stands on its target" and "Stars: 3 of 3"; background before terminate on
  relaunch); edit `scripts/release_check.py` (`UI_CHUNKS["o3"]`, `"o3"` in `SERIAL_CHUNKS`) and
  `scripts/test_scripts.py` (agent D; the key `o3` checked unique among the keys); `project.yml` + `xcodegen generate`
  if needed; `--name app-ui -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-ui-ios27-o3`

## Phase 4: Story 2 — the app's logic accepts the game (P1)

- [ ] T-R02G0609-005 [US2] Edit `Apps/VisualCore/Tests/Unit/AppModelTests.swift` (agent B: both examples restore through
  the app's migration check; the candidate opens through the registry and engine and plays level 1 to a win; without
  `-vcCandidates` it is not available and not openable; `CR`'s pinned level 1 certified phase changes, default phases
  and loop lengths (the convergence lesson of feature 319) equal the Core's); `--name app-unit -- python3
  scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`

## Phase 5: Story 3 — builds and solvability (P2)

- [ ] T-R02G0609-006 [US3] Release build and symbols (`ChronoConstellatorGolden`, `acceptanceScenarios` already
  forbidden): `--name release -- python3 scripts/release_check.py --only app-release-build app-release-symbols`;
  `--name regression -- python3 scripts/chrono_constellator_regression.py` (100 of 100 levels, SC-R02G0609-004)

## Phase 6: Regression, documentation and close

- [ ] T-R02G0609-007 Docs: `docs/architecture/chrono-constellator.md` (in-app integration),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`; `--name script-tests` (alone)
- [ ] T-R02G0609-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full` (app-unit and app-ui are this gate's own runs)
- [ ] T-R02G0609-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G0609-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G0609-011 {device} After ImplementationLock-100: the same journeys on D1/D2/D3 (SC-R02G0609-006; feature 360
  prepares them)
- [ ] T-R02G0609-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  after the record push, check its CI run with `gh run list`

## Dependencies and parallel work

001 → 002 (lead; agent A tests) → 003 (lead; agent E tests) → {004 (agents C, D), 005 (agent B), 006} → 007 … 010, 012.
011 stays open until device testing. Shared files (examples source, registry, controls, project.yml, docs) stay with the
lead. MVP: Stories 1 and 2.
