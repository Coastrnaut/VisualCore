# Tasks: R02-G08-09 — Faceted Forge: simulator integration and full app lock

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G08-09 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G08-09 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_379;
tests stay short (< 10 s each; interface tests < 90 s, SC-R02G0809-001). No {owner} tasks; no GLSL or CPU reference
change (the shaders and reference of R02-G08-03 are unchanged and re-proven by the rendering runs).

## Phase 1: Setup

- [X] T-R02G0809-001 Baselines: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02 -- swift test — Verified 2026-11-22: baseline-host, baseline-timing, baseline-round02 exit 0; rendering baseline is R02-G08-08's rendering runs (exit 0)
  --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G08-08's rendering runs (exit 0)

## Phase 2: Foundational

- [X] T-R02G0809-002 Create `Packages/ExperiencesRound02/FacetedForge/Core/FacetedForgeSchemaExamples.swift` — Verified 2026-11-22: host (swift test --package-path Packages/ExperiencesRound02 incl. FacetedForgeSchemaExampleTests 7: both examples restore through migrations to schema 3 with level 1, the cut and progress kept, the schema-2 result unverified with its stars, expected digests match, other versions nil, SnapshotMigrationCheck reports no problems) exit 0; registration stores both examples, comment corrected; lead retest (the app-side restore is proven by app-unit in T-005)
  (contracts/api.md; data-model: schema 1 "a seeded play of level 1 with one cut that does not win, seed 7";
  schema 2 "campaign mode, progress {frontier 2, solved [level 1, cuts made, stars]}, tutorial", "the result is kept,
  unverified, without a trace"; the envelope of `AmethystEscapeSchemaExamples`) with
  `Packages/ExperiencesRound02/FacetedForge/CoreTests/FacetedForgeSchemaExampleTests.swift` (agent A: both
  restore through `migrations` to schema 3 with level 1, the cut and progress kept; the expected digests
  match; versions other than 1 and 2 give nil); edit `Apps/VisualCore/App/ExperienceRegistry.swift` (`examples:` with
  both; the stale schema comment corrected); `--name host -- swift test --package-path Packages/ExperiencesRound02`

## Phase 3: Story 1 — the game works inside the real app (P1) 🎯

- [X] T-R02G0809-003 [US1] Edit `Packages/ExperiencesRound02/FacetedForge/Experience/FacetedForgeControls.swift`: — Verified 2026-11-22: sim-27 (FacetedForgeExperienceTests, 66 tests on iOS 27.2 incl. FacetedForgeIdentifierTests: the 24 clarified names each once, lower-case tokens, every identifier experience.r02-g08.faceted-forge.<name> and unique) exit 0; 24 .accessibilityIdentifier modifiers added; an unrecorded run passed first
  identifiers `experience.r02-g08.faceted-forge.<name>` through `port.identifier` (spec Clarifications Q1 names:
  cut, undo, redo, next-level, depth-down, depth-up, reset-view, hint, dismiss-tutorial, failure-undo, retry,
  campaign, daily, practice, play-level, replay, replay-step, replay-stop, piece-picker, direction-picker, depth-picker,
  level-picker, sound, summary; unique; `identifierNames` lists them) with
  `Packages/ExperiencesRound02/FacetedForge/ExperienceTests/FacetedForgeIdentifierTests.swift` (agent E:
  every name of Q1 is listed once by the controls' identifier list and has the prefix); `--name sim-27 -- python3
  scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package
  --destination sim-27.2 --action test --only-testing FacetedForgeExperienceTests`
- [X] T-R02G0809-004 [US1] Create `Apps/VisualCore/Tests/UI/FacetedForge/FFSupport.swift`, `FFPlayUITests.swift`, — Verified 2026-11-22: app-ui-2 (release_check app-build-for-testing-ios27 + app-ui-ios27-q3: FFPlayUITests win level 1 through the panel with 3 stars and level 2 open, progress kept over a relaunch; FFReplayUITests replay to a win and Stop back to the campaign) exit 0 after app-ui exit 1 (the relaunch test could not tap the restored level picker; the helpers now wait up to 5 s and tap a visible control by coordinate; a corrupt PosterBoard store on the UI-test simulator was crashing on every Home press and was moved aside); chunk q3 serial and unique
  `FFReplayUITests.swift` (agent C: spec Clarifications Q2; level 1 certified cuts and the pickers' starting choice
  pinned in `FF`; each cut played by stepping the piece, direction and depth pickers from the current choice to the
  cut's values (reading each value), then Cut; read "The pieces match the target" and "Stars: 3 of 3"; background before terminate on
  relaunch); edit `scripts/release_check.py` (`UI_CHUNKS["q3"]`, `"q3"` in `SERIAL_CHUNKS`) and
  `scripts/test_scripts.py` (agent D; the key `q3` checked unique among the keys); `project.yml` + `xcodegen generate`
  if needed; `--name app-ui -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-ui-ios27-q3`

## Phase 4: Story 2 — the app's logic accepts the game (P1)

- [X] T-R02G0809-005 [US2] Edit `Apps/VisualCore/Tests/Unit/AppModelTests.swift` (agent B: both examples restore through — Verified 2026-11-22: app-unit (release_check app-build-for-testing-ios27 + app-unit-ios27: both schema examples restore through the app's migration check, the candidate opens through registry and engine and wins level 1, without -vcCandidates it is not available or openable, FF's pinned level 1 cuts and start choice equal the Core's) exit 0
  the app's migration check; the candidate opens through the registry and engine and plays level 1 to a win; without
  `-vcCandidates` it is not available and not openable; `FF`'s pinned level 1 certified cuts and the
  pickers' starting choice (the convergence lesson of feature 319) equal the Core's); `--name app-unit -- python3
  scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`

## Phase 5: Story 3 — builds and solvability (P2)

- [X] T-R02G0809-006 [US3] Release build and symbols (`FacetedForgeGolden`, `acceptanceScenarios` already — Verified 2026-11-22: release (app-release-build, app-release-symbols: FacetedForgeGolden and acceptanceScenarios absent) exit 0; regression (faceted_forge_regression.py: host and simulator PASS, 100 of 100 levels) exit 0
  forbidden): `--name release -- python3 scripts/release_check.py --only app-release-build app-release-symbols`;
  `--name regression -- python3 scripts/faceted_forge_regression.py` (100 of 100 levels, SC-R02G0809-004)

## Phase 6: Regression, documentation and close

- [X] T-R02G0809-007 Docs: `docs/architecture/faceted-forge.md` (in-app integration), — Verified 2026-11-22: round02-host exit 0; script-tests exit 0 (run alone); architecture in-app integration, package README, testing lessons (PosterBoard crashes on the UI-test phone; Faceted Forge in the app); validate_docs passes
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`; `--name script-tests`
  (alone)
- [X] T-R02G0809-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-22: rendering-27, rendering-26, experiences, host-full exit=0 (app-unit and app-ui are this gate's own runs)
  `--name host-full` (app-unit and app-ui are this gate's own runs)
- [X] T-R02G0809-009 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-22: reference-1 exit=0
- [X] T-R02G0809-010 Reference regression chunk 2 (`--name reference-2`) — Verified 2026-11-22: reference-2-2 exit=0 after reference-2 exit 1 (projectm-reference-ios26 square preset within8 0.9703 vs required 0.9706: the documented run-to-run variance; rerun passed; failed attempt kept)
- [ ] T-R02G0809-011 {device} After ImplementationLock-100: the same journeys on D1/D2/D3 (SC-R02G0809-006; feature 380
  prepares them)
- [X] T-R02G0809-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record; — Verified 2026-11-22: converge clean (no tasks appended); sealed and recorded pass; failed attempts app-ui and reference-2 kept
  after the record push, check its CI run with `gh run list`

## Dependencies and parallel work

001 → 002 (lead; agent A tests) → 003 (lead; agent E tests) → {004 (agents C, D), 005 (agent B), 006} → 007 … 010, 012.
011 stays open until device testing. Shared files (examples source, registry, controls, project.yml, docs) stay with the
lead. MVP: Stories 1 and 2.
