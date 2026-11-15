# Tasks: Light Maze — Phase 02 Rendering and tap interactions

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/interaction.md](contracts/interaction.md), [quickstart.md](quickstart.md). Gate A13-P02 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A13-P02 --timeout 600 --name <check> -- <command>`. Commit
after every task (no trailers); read every check's exit before ticking. iOS 27 only. Precedent:
`specs/090-tw-p02-camera/tasks.md`.

## Phase 1: Setup

- [ ] T-A13-201 Baseline: cite the A13-P01 evidence on the unchanged tree (`.autonomy/checks/A13-P01.{maze-ios27-4,app-unit,verify-27-2}.json`) instead of a rerun (owner ruling of 2026-11-14)

## Phase 2: Foundational — loop fixtures (story 4)

- [ ] T-A13-202 [P] [US4] Write `Packages/ExperiencesCreative/LightMaze/CoreTests/LoopFixtureTests.swift` per research D3: a mirror-only board whose path returns to the emitter (ends "emitter"), a prism board whose branches meet (ends "loop"), and a mirror spiral reaching the bounce cap (ends "bounce-cap"); each branch ≤ 64 bounces, total ≤ 256 segments; boards committed as literals (FR-A13-220; SC-A13-205)

## Phase 3: Stories 1–2 — touch, drag and twist (P1) 🎯

- [ ] T-A13-203 [P] [US2] Write `Packages/ExperiencesCreative/LightMaze/Experience/MazeGestures.swift` (pure value type over `GestureArbiter` with rotate 3, drag 2, tap 1; a view→board mapping and a `send` closure passed in; tap selects or turns a turnable tile, else answers in words; drag from a turnable tile snaps at ≥ 0.35 cell to `/` within 45° of NE/SW else `\` by `tile.select` + `tile.turn` only when it differs; rotate over the selected tile turns once per ±45°; `reset()`) and `Packages/ExperiencesCreative/LightMaze/ExperienceTests/MazeGestureTests.swift` with synthetic pointer events (FR-A13-201–204; SC-A13-201–203)
- [ ] T-A13-204 [US1] Wire the gestures in `Packages/ExperiencesCreative/LightMaze/Experience/MazePresenter.swift`: inverse camera mapping of the last frame, touches routed to `MazeGestures`, reset on suspension and teardown, `gestureActions` = ["tile.select", "tile.turn"] ⊆ `nativeActions`; tests in `MazeSessionTests.swift` (taps through the presenter select then turn level 1's mirror; `GestureAlternatives.missing` is empty) (FR-A13-201, 204)

## Phase 4: Story 3 — glowing beam (P2)

- [ ] T-A13-205 [US3] In `MazePresenter.swift` draw each beam segment as a halo (width 0.30 cell, opacity 0.25) under the core (0.08 cell, opacity 1), lit targets with a ring (inset 0.05) and the selected tile with an outline (inset 0.04); speak beam changes at most once per second of frame time while VoiceOver runs through an app-local `BeamAnnouncer` (research D2b); tests in `Packages/ExperiencesCreative/LightMaze/ExperienceTests/MazeGlowTests.swift` (every core primitive lies on a tracer segment; halo half-width ≤ 0.15 cell; lit targets carry a ring; the selected tile an outline; announcements rate-limited) and a pixel check in `MazeRenderTests.swift` (beam brighter than the board along the path) (FR-A13-210–212; SC-A13-204)

## Phase 5: Records and evidence

- [ ] T-A13-206 Contract `docs/apps/light-maze/visualcore-contract.json`: G-SNAP and G-BEAMS closed by "A13-P02"; rows M04, M07, M10, M12 updated (`--name contract -- python3 scripts/check_app_contract.py --app light-maze --render`)
- [ ] T-A13-207 Light Maze tests on sim-27.2 (`--name maze-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing LightMazeCoreTests LightMazeExperienceTests`) (SC-A13-201–206)
- [ ] T-A13-208 App build and unit (`--name app-unit -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`) and runner (`--name verify-27 -- python3 scripts/verify_experiences.py --only a13.light-maze --runtime 27`) (SC-A13-206)
- [ ] T-A13-209 Packages and script tests (`--name experience-packages -- python3 scripts/check_experience_packages.py`; `--name script-tests -- python3 scripts/test_scripts.py`)
- [ ] T-A13-210 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A13-P02; update README.md in the record commit (rule 16)

## Dependencies

T-A13-201 → (202 ∥ 203) → 204 → 205 → 206 → 207 → 208 → 209 → 210.

## Parallel examples

Agent A: T-A13-202. Agent B: T-A13-203. Lead: 204, 205, records, runs, commits.

## Implementation strategy

MVP: gestures snapping to the grid (US1, US2) with the loop fixtures (US4); then the glow (US3); evidence last.
