# Tasks: Neon Arcade — Phase 04 Scores and accessibility

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate A10-P04 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A10-P04 --timeout 600 --name <check> -- <command>`. Commit
after every task (no trailers). iOS 27 only; reference regression and iOS 26 at X-A10; accessibility audits at the
device campaign (owner, 2026-11-13/14). Precedent: `specs/077-na-p03-effects/tasks.md`.

## Phase 1: Setup

- [X] T-A10-401 Baseline: cite the A10-P03 evidence on the unchanged tree (`.autonomy/checks/A10-P03.{arcade-ios27,app-unit,verify-27}.json`) instead of a rerun (owner ruling of 2026-11-14) — Verified 2026-11-14: 2026-11-14: cited .autonomy/checks/A10-P03.{arcade-ios27,app-unit,verify-27}.json on the unchanged tree (no rerun)

## Phase 2: Foundational — core sensitivity, table and announcements

- [X] T-A10-402 [P] [US1] Core: new `Packages/ExperiencesCreative/NeonArcade/Core/{Sensitivity,HighScoreTable,ArcadeAnnouncements}.swift` per contracts/api.md, data-model.md and research D1, D2, D4 ("reaches 2.5, 2.0, 1.5, 1.0, 0.6 units; default 2"; `HighScoreEntry` "score 1…9,999,999, wave ≥ 1, run ≥ 1"; `HighScoreTable` "boardVersion 1, entries (≤ 10, sorted), lastRun ≥ 0", ties by earlier run, a run entered once, JSON with sorted keys and a validating decoder; announcement texts of clarification 4); tests new `Packages/ExperiencesCreative/NeonArcade/CoreTests/{SensitivityTests,HighScoreTableTests,ArcadeAnnouncementsTests}.swift` (each step's steering for fixed offsets, ordered gentle → sharp and within −1…1; insertion ranks, ties, the tenth-entry cut, score 0 and duplicate runs refused, round trip, damaged / truncated / newer JSON refused with a reason; texts for hit, wave, game over and new high score, none for pickups, game over replaced by new high score) (FR-A10-401, 410, 412, 420; SC-A10-401, 403) — Verified 2026-11-14: 2026-11-14: Sensitivity (5 reaches), HighScoreTable/HighScoreEntry (ranked, ties by run, run entered once, versioned JSON with damaged/newer/invalid), ArcadeAnnouncements and ArcadeAnnouncer (≤ 1 per second); 102 core tests pass on the host (core targets only; the license-document test is path-bound and runs on the simulator)

## Phase 3: Stories 1–3 — the experience and the interface

- [X] T-A10-403 [US2] Experience: `NeonArcade/Experience/Adapter/ArcadeCore.swift` (snapshot schema 4 with `sensitivity` and `runNumber`, migration 3 → 4, `schemaThreeExample()`, action `settings.sensitivity [0…4]` with `a10.invalid-choice` for fractions, `runNumber` + 1 on every new run); new `NeonArcade/Experience/HighScoreStore.swift` (`high-scores.json` in the launch `ExperienceStorage` with the atomic write, load with damage reporting, `record(run:)` entering a finished run once); `NeonArcade/Experience/{ArcadePresenter,ArcadeControls,ArcadeGestures}.swift` (gesture reach from the chosen step; best scores on the title and game-over screens with the new entry marked; announcements through `AnnouncementPlanner(minimumInterval: 1.0)` and `ExperienceFeedback.announce`; sensitivity control with label and value; description adds the best score); `Apps/VisualCore/App/ExperienceRegistry.swift` adds `schemaThreeExample()`; tests new `NeonArcade/ExperienceTests/HighScoreStoreTests.swift` (round trip through a temporary `ExperienceStorage`; an interrupted save — a partial hidden temporary file beside the table — and a truncated copy: the table reads as the last complete one, the truncated copy is reported; newer or damaged file reported, play continues, the next run writes a valid table; storage refusal reported once) and updates to `ArcadeCoreTests`, `ArcadeSessionTests`, `ArcadeRenderTests` (sensitivity round trip and migration; same finger offset gives different steering per step; a finished run is entered once even after restoring the game-over screen; announcements ≤ 1 per second over a 600-step run; `GestureAlternatives.missing` empty; every control labelled; the title and game-over screens draw the best scores and mark the new entry; control texts use text styles that scale with Dynamic Type) (FR-A10-402, 411–413, 420, 421; SC-A10-401–404) — Verified 2026-11-14: 2026-11-14: snapshot schema 4 (sensitivity, runNumber; migration 3→4, schemaThreeExample registered), settings.sensitivity, HighScoreStore (atomic high-scores.json, damage and refusal reported, run entered once), best scores drawn with the new entry marked, announcements ≤ 1 per second incl. game over detected by the presenter, sensitivity Stepper, Dynamic Type text styles; 182 arcade tests pass on sim-27.2 (.autonomy/checks/A10-P04.arcade-ios27.json; the first run had 5 test-expectation failures, fixed)
- [X] T-A10-404 [P] [US3] UI tests: new `Apps/VisualCore/Tests/UI/NeonArcade/{NASupport,NAArcadeUITests}.swift` per research D5 (open Neon Arcade with `-vcCandidates`, Start, steer left/right with the buttons, pause and resume, change the sensitivity, find the best-score text on the title); chunk `"r2": ["NAArcadeUITests"]` in `scripts/release_check.py` `UI_CHUNKS` and `SERIAL_CHUNKS`; each test < 60 s (FR-A10-422; SC-A10-405) — Verified 2026-11-14: 2026-11-14: NASupport + NAArcadeUITests (start and steer, pause and resume, sensitivity, best score on the title); chunk r2 (serial); .autonomy/checks/A10-P04.app-ui.json exit 0 — 4 UI tests in 95 s on the iOS 27.2 phone
- [X] T-A10-405 [US2] Manifest and contract: `NeonArcade/Experience/Adapter/ArcadeManifest.swift` fixture 15 (a run to game over; the table write is proved by `HighScoreStoreTests`) and fixture 16 (sensitivity change), regenerate `NeonArcade/scenario-manifest.json`; `docs/apps/neon-arcade/visualcore-contract.json` G-STEERINPUT and G-HIGHSCORES closed by "A10-P04" (rows M10, M13 updated); `--name contract -- python3 scripts/check_app_contract.py --app neon-arcade --render` — Verified 2026-11-14: 2026-11-14: fixtures 15 (a run to game over at step 679) and 16 (sensitivity 4 then 0); scenario-manifest.json regenerated; ArcadeManifestTests pass (A10-P04.arcade-ios27); runner 9/9 on iOS 27 (A10-P04.verify-27); contract G-STEERINPUT and G-HIGHSCORES closed by A10-P04 (.autonomy/checks/A10-P04.contract.json)

## Phase 4: Polish & evidence

- [X] T-A10-406 Arcade tests on sim-27.2 (`--name arcade-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing NeonArcadeCoreTests NeonArcadeExperienceTests`; each test < 10 s) (SC-A10-401–404, 406) — Verified 2026-11-14: 2026-11-14: .autonomy/checks/A10-P04.arcade-ios27.json exit 0 (182 tests on sim-27.2)
- [ ] T-A10-407 App build, unit and the UI chunk (`--name app-ui -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27 app-ui-ios27-r2`) and runner iOS 27 (`--name verify-27 -- python3 scripts/verify_experiences.py --only a10.neon-arcade --runtime 27`) (SC-A10-405, 406)
- [ ] T-A10-408 Experience package check and script tests (`--name experience-packages -- python3 scripts/check_experience_packages.py`; `--name script-tests -- python3 scripts/test_scripts.py`)
- [ ] T-A10-409 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A10-P04

## Dependencies

T-A10-401 → 402 → 403 → 405 → Polish; 404 runs in parallel with 403 (different files) and needs 403's identifiers to
pass.

## Parallel examples

Agent A: T-A10-402. Agent B: T-A10-403 after A. Agent C: T-A10-404 (UI test files only). Lead: registry,
release_check chunk, regeneration, contract, runs, commits.

## Implementation strategy

MVP: sensitivity (US1) and the crash-safe table (US2); then the accessibility interface and UI tests (US3); evidence
last.
