# Tasks: Light Maze — Phase 04 Hints, accessibility and visual polish

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/feedback.md](contracts/feedback.md), [quickstart.md](quickstart.md). Gate A13-P04 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A13-P04 --timeout 600 --name <check> -- <command>`. Commit
after every task (no trailers); read every check's exit before ticking. iOS 27 only. Precedent:
`specs/098-lm-p03-progress/tasks.md`.

## Phase 1: Setup

- [X] T-A13-401 Baseline: cite the A13-P03 evidence on the unchanged tree (`.autonomy/checks/A13-P03.{maze-ios27,app-unit,verify-27}.json`) instead of a rerun (owner ruling of 2026-11-14) — Verified 2026-11-15: 2026-11-15: cited .autonomy/checks/A13-P03.{maze-ios27,app-unit,verify-27}.json (exit 0) on the unchanged tree (no rerun)

## Phase 2: Foundational — core rules (stories 1–3)

- [ ] T-A13-402 [P] [US1] Core: new `Packages/ExperiencesCreative/LightMaze/Core/Hint.swift` — `Hint.tile(level:orientations:) -> Int?` "first index i (board order) with orientations[i] != level.solution[i]; nil when the tracer reads the board solved"; test `Packages/ExperiencesCreative/LightMaze/CoreTests/HintTests.swift` (for all 20 levels from the start, repeating hint then turn solves the level within its turnable-tile count; nil on a solved board; a board solved otherwise than the recorded solution gives nil) (FR-A13-401, 402; SC-A13-401)
- [ ] T-A13-403 [P] [US2] Core: new `Packages/ExperiencesCreative/LightMaze/Core/BoardDescription.swift` — `summary` "Light Maze: level N, K of T targets lit." plus " Solved." and `full` (level name and size; per tile kind the places, rows and columns from 1, row 1 at the top, with direction or "slash"/"backslash"; per beam branch start, turns and end; per target lit or unlit) "≤ 4,000 characters"; test `CoreTests/BoardDescriptionTests.swift` (fixture boards lm-01 and lm-05 name every tile, each branch's start, turn and end cells and every target; text follows a turn; a 12 × 12 board with 144 tiles stays ≤ 4,000 characters) (FR-A13-410, 411; SC-A13-402)
- [ ] T-A13-404 [P] [US3] Core: new `Packages/ExperiencesCreative/LightMaze/Core/SuccessCue.swift` — `duration = 0.6`; `brightness(elapsed:reduceMotion:reduceFlashing:)` "1 + 0.5·sin(π·t/0.6) for 0 ≤ t < 0.6 s, otherwise 1; exactly 1 under Reduce Motion or Reduce Flashing"; `words(levelNumber:moves:nextOpened:isLast:)` per contract §Words; test `CoreTests/SuccessCueTests.swift` (single rise and fall, peak ≤ 1.5, 1 after 0.6 s and under each flag; words for 1 move, opened next, last level, already open) (FR-A13-420, 421; SC-A13-403)

## Phase 3: Stories 1–4 — the experience

- [ ] T-A13-405 [P] [US4] New `Packages/ExperiencesCreative/LightMaze/Experience/MazeStyle.swift` — the nine `StateSign`s of clarification Q4 with colour hex from the presenter's colours, the unlit target colour raised to ≥ 3 : 1 against `boardColor` (and `MazePresenter.targetColor` changed to it); test `ExperienceTests/MazeStyleTests.swift` (`stateSignProblems(MazeStyle.signs)` empty; every state colour composited over the board against the board ≥ 3 : 1 by `AccessibilitySettingsSection.contrastRatio`; glow reach ≤ 0.15 cell kept) (FR-A13-430, 431; SC-A13-404)
- [ ] T-A13-406 [US1] Adapter `Experience/Adapter/MazeCore.swift`: action `hint.show` (selects `Hint.tile`; refused `a13.already-solved` whenever `Hint.tile` is nil; changes only the selection) in the action list and descriptions; `MazeControls.swift` Hint (`hint`) and Describe (`describe`) buttons; `MazePresenter.swift` hint words ("Hint: turn the mirror at row R, column C." / "Level N is already solved."), `describe` summary from `BoardDescription.summary` and a `describeBoard()` that shows and speaks the full text; tests `ExperienceTests/MazeHintTests.swift` (hint selects the expected tile on lm-01; refused when solved; words; Describe text equals `BoardDescription.full`; canvas description equals the summary; with VoiceOver off the hint words are kept and shown, not posted) and updated `MazeCoreTests.swift` (FR-A13-401, 402, 410, 411)
- [ ] T-A13-407 [US3] Success cue: `Packages/ExperiencesCreative/Package.swift` (LightMazeExperience and LightMazeExperienceTests add `VisualCoreAudio` from the rendering package and `VisualCoreAudioDSP` from VisualCore); new `Experience/MazeSound.swift` (`MazeSoundSink` protocol, default `MazeSoundPlayer` over `SoundEffectPlayer` with the contract's sweep); `LightMazeExperience.swift` passes `reduceMotion`, `reduceFlashing` into the presenter, plus test hooks for a sound sink and an `ExperienceFeedback` route; `MazePresenter.swift` plays the cue once per solve transition (words to spoken list and message, sound, `success` haptic, border clock from frame time), draws the border and tick polyline while solved with `SuccessCue.brightness`, and `suspended()` stops the sink and ends the brightening; test `ExperienceTests/MazeFeedbackTests.swift` (one cue per transition, none on repeated frames; again after undo and re-solve; Reduce Motion and Reduce Flashing keep brightness 1; suspension stops the sound; recorded haptic is `success`; two solves within the 0.05 s haptic interval of an injected route clock give one haptic; with VoiceOver off the words are in the spoken list and message and nothing is posted) (FR-A13-420, 421; SC-A13-403)
- [ ] T-A13-408 [US1] Manifest: fixture `fixture-hint` (lm-01: `hint.show`, `tile.turn`, solved) in `Experience/Adapter/MazeManifest.swift`; `scenario-manifest.json` regenerated (`UPDATE_SCENARIO_MANIFEST=1 TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`); `ExperienceTests/MazeManifestTests.swift` updated (FR-A13-402)

## Phase 4: Records and evidence

- [ ] T-A13-409 Contract `docs/apps/light-maze/visualcore-contract.json`: G-FEEDBACK closed by "A13-P04"; rows M09, M10, M17 updated (`--name contract -- python3 scripts/check_app_contract.py --app light-maze --render`)
- [ ] T-A13-410 Light Maze tests on sim-27.2 (`--name maze-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing LightMazeCoreTests LightMazeExperienceTests`) (SC-A13-401–405)
- [ ] T-A13-411 App build and unit (`--name app-unit -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`) and runner (`--name verify-27 -- python3 scripts/verify_experiences.py --only a13.light-maze --runtime 27`) (SC-A13-405)
- [ ] T-A13-412 Packages and script tests (`--name experience-packages -- python3 scripts/check_experience_packages.py`; `--name script-tests -- python3 scripts/test_scripts.py`)
- [ ] T-A13-413 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A13-P04; update README.md in the record commit (rule 16)

## Dependencies

T-A13-401 → (402 ∥ 403 ∥ 404 ∥ 405) → 406 → 407 → 408 → 409 → 410 → 411 → 412 → 413 (406 uses 402 and 403; 407 uses
404 and 405's colours; 406 and 407 share the presenter and controls, so they run in order).

## Parallel examples

Agents A–D: T-A13-402, 403, 404, 405 (separate new files). Lead: 406–408 (shared presenter, adapter, controls),
regeneration, records, runs, commits.

## Implementation strategy

MVP: story 1 (hint, 402 + 406 + 408). Then story 2 (403 in 406), story 3 (404 + 407), story 4 (405). Review
checkpoint after 405 (core and style tests), after 407 (experience tests) and at 410.
