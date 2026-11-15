# Tasks: Light Maze — Phase 03 Core levels and progress

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/progress.md](contracts/progress.md), [quickstart.md](quickstart.md). Gate A13-P03 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A13-P03 --timeout 600 --name <check> -- <command>`. Commit
after every task (no trailers); read every check's exit before ticking. iOS 27 only. Precedent:
`specs/091-tw-p03-customize/tasks.md`.

## Phase 1: Setup

- [X] T-A13-301 Baseline: cite the A13-P02 evidence on the unchanged tree (`.autonomy/checks/A13-P02.{maze-ios27,app-unit,verify-27}.json`) instead of a rerun (owner ruling of 2026-11-14) — Verified 2026-11-15: 2026-11-15: cited .autonomy/checks/A13-P02.{maze-ios27,app-unit,verify-27}.json (exit 0) on the unchanged tree (no rerun)

## Phase 2: Foundational — progress document and moves in the core (stories 1–2, 4)

- [X] T-A13-302 [US1] Core: new `Packages/ExperiencesCreative/LightMaze/Core/Progress.swift` per data-model.md and contracts/progress.md (`LevelProgress` "solved ⇒ open, best 1…999; unsolved ⇒ best nil"; `Progress` "level 1 open; ≤ 16 KB", exactly the 20 catalog ids in order; `fresh`, `recordSolved(levelIndex:moves:)` opening the next level and keeping the minimum best (at least 1), `isOpen(_:)`; sorted-key codec and decoder refusing `damaged`, `too-large`, `newer-version`) and `MazeState.swift` schema 2 (`moves` [{tile, before, after}] "≤ 64 (oldest dropped)"; `turnSelected` appends; `undo()` restores `before` and removes the last move, false when empty; `reset` and `selectLevel` empty the moves; decode migrates schema 1 with no moves; newer refused); tests `Packages/ExperiencesCreative/LightMaze/CoreTests/{ProgressTests,MovesTests,SolutionReplayTests}.swift` and updated `MazeStateTests.swift` (progression and refusals; undo exactness of orientations and beam; cap; replay of all 20 recorded solutions as select and turn from a fresh state) (FR-A13-301, 310, 321, 330; SC-A13-301, 302, 304) — Verified 2026-11-15: 2026-11-15: Progress.swift (schema 1, validating codec: damaged, too-large, newer-version; recordSolved opens the next level, keeps the minimum best) and MazeState schema 2 (moves ≤ 64, undo, migration from 1); ProgressTests, MovesTests, SolutionReplayTests (all 20 levels replayed to solved) and MazeStateTests pass in .autonomy/checks/A13-P03.maze-ios27.json exit 0 (60 core tests on sim-27.2)

## Phase 3: Stories 1–3 — the experience

- [X] T-A13-303 [US3] New `Packages/ExperiencesCreative/LightMaze/Experience/ProgressStore.swift` modelled on `Packages/ExperiencesCreative/PhysicsPlayground/Experience/ExperimentStore.swift` (`progress.json` through `ExperienceStorage.write` atomically; read never writes; refusals reported by code; memory variant without storage) and `Packages/ExperiencesCreative/LightMaze/ExperienceTests/ProgressStoreTests.swift` (round trip identical; damaged, truncated, too large and newer files reported and byte-identical; an interrupted write keeps the previous file; an absent file, as after the app's data reset, gives fresh progress with level 1 open and nothing solved) (FR-A13-320; SC-A13-303) — Verified 2026-11-15: 2026-11-15: ProgressStore (progress.json, atomic write, read never writes, memory variant) and ProgressStoreTests (5: round trip, absent file fresh, damaged/truncated/too-large/newer reported and byte-identical, interrupted and refused writes keep the file, memory variant) pass in .autonomy/checks/A13-P03.maze-ios27.json exit 0
- [X] T-A13-304 [US1] Experience: `Adapter/MazeCore.swift` (action `move.undo` with `a13.no-moves`; snapshot schema 2 with migration 1 → 2; `schemaOneExample()`), `MazePresenter.swift` (owns a `ProgressStore` from the factory's storage, loads progress once, records a solve on the frame the current level turns solved, opens the next level and saves once), `MazeControls.swift` (Undo `undo` with value "N moves"; Restart label for `reset-level`; Level menu disables locked levels with "locked"; Next level disabled when the next is locked; a refused choice answered "Level N is locked; solve level N−1 first."), `LightMazeExperience.swift` (storage passed to the store); `Apps/VisualCore/App/ExperienceRegistry.swift` examples `[MazeCore.schemaOneExample()]`; tests `Packages/ExperiencesCreative/LightMaze/ExperienceTests/MazeProgressTests.swift` (solving levels 1–3 in order opens 2–4 and leaves 5 locked; best counts; undo to unsolved and back; locked choices refused; progress reloaded by a new presenter equals the saved one) and updated `MazeCoreTests.swift` (FR-A13-301, 302, 310, 311, 321; SC-A13-301, 302) — Verified 2026-11-15: 2026-11-15: MazeCore move.undo (a13.no-moves), schema 2 with migration and schemaOneExample; presenter owns the ProgressStore, records solves once per transition and saves; controls Undo, Restart, Level menu with locked and solved words, Next level locked; registry example; MazeProgressTests (5) and updated MazeCoreTests pass in .autonomy/checks/A13-P03.maze-ios27.json exit 0 (62 experience tests)
- [X] T-A13-305 [US2] Manifest: digests of the five fixtures regenerated (state schema 2) and a fixture `fixture-undo` solving level 1 then undoing (unsolved) in `Packages/ExperiencesCreative/LightMaze/Experience/Adapter/MazeManifest.swift`; `Packages/ExperiencesCreative/LightMaze/scenario-manifest.json` regenerated (`UPDATE_SCENARIO_MANIFEST=1 TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`); `MazeManifestTests.swift` updated (FR-A13-310) — Verified 2026-11-15: 2026-11-15: five fixture digests re-pinned for state schema 2 and fixture-undo added (six fixtures); scenario-manifest.json regenerated (UPDATE_SCENARIO_MANIFEST=1 on sim-27.2); MazeManifestTests pass in .autonomy/checks/A13-P03.maze-ios27.json exit 0

## Phase 4: Records and evidence

- [X] T-A13-306 Contract `docs/apps/light-maze/visualcore-contract.json`: G-LEVELS closed by "A13-P03"; rows M06, M09, M20 updated (`--name contract -- python3 scripts/check_app_contract.py --app light-maze --render`) — Verified 2026-11-15: 2026-11-15: G-LEVELS closed by A13-P03; M06 and M20 now available, M09 notes updated (stays requires adaptation for G-FEEDBACK); .autonomy/checks/A13-P03.contract-2.json exit 0 (first attempt A13-P03.contract.json exit 1 kept: M06/M20 still marked requires adaptation)
- [ ] T-A13-307 Light Maze tests on sim-27.2 (`--name maze-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing LightMazeCoreTests LightMazeExperienceTests`) (SC-A13-301–305)
- [ ] T-A13-308 App build and unit (`--name app-unit -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`) and runner (`--name verify-27 -- python3 scripts/verify_experiences.py --only a13.light-maze --runtime 27`) (SC-A13-305)
- [ ] T-A13-309 Packages and script tests (`--name experience-packages -- python3 scripts/check_experience_packages.py`; `--name script-tests -- python3 scripts/test_scripts.py`)
- [ ] T-A13-310 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A13-P03; update README.md in the record commit (rule 16)

## Dependencies

T-A13-301 → 302 → (303 ∥ 304) → 305 → 306 → 307 → 308 → 309 → 310 (304 uses 303's store; the store file is
independent).

## Parallel examples

Agent A: T-A13-302. Agent B: T-A13-303. Agent C: T-A13-304 after A and B. Lead: registry, 305 regeneration, records,
runs, commits.

## Implementation strategy

MVP: unlock progression with undo and restart (US1, US2), then saved progress (US3); the replay proof (US4) rides on the
core tests; evidence last.
