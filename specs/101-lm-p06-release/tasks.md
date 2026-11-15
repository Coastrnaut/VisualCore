# Tasks: Light Maze — Phase 06 Final verification, privacy, packaging and release

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/release-config.md](contracts/release-config.md), [quickstart.md](quickstart.md). Gate A13-P06 (legacy).
Evidence: `python3 Tools/python/desktop_runbook.py run-check --stage A13-P06 --timeout 600 --name <check> -- <command>`.
Commit after every task (no trailers); read every check's exit before ticking. iOS 27 only. Precedent:
`specs/094-tw-p06-release/tasks.md`.

## Phase 1: Setup

- [X] T-A13-601 Baseline: cite the A13-P05 evidence on the unchanged tree (`.autonomy/checks/A13-P05.{maze-ios27,app-unit,verify-27}.json`) instead of a rerun (owner ruling of 2026-11-14) — Verified 2026-11-15: 2026-11-15: cited .autonomy/checks/A13-P05.{maze-ios27,app-unit,verify-27}.json (exit 0) on the unchanged tree (no rerun)

## Phase 2: Story 1 — nothing leaves the device (P1)

- [X] T-A13-602 [P] [US1] Write `docs/apps/light-maze/privacy-and-credits.md` per research D1 (stored: `progress.json` in the experience's folder and the app's session state — level, orientations, selection, moves; no personal data; nothing sent; no permission; deletion by the app's data reset or removing the app; credits: 20 levels by "VisualCore project" under MIT, see `content-licenses.md`; the success sweep made in code; no third-party content) and link it from `docs/apps/light-maze/README.md` (FR-A13-601, 604) — Verified 2026-11-15: 2026-11-15: docs/apps/light-maze/privacy-and-credits.md (progress.json and the session state, no personal data, nothing sent, no permission, deletion, credits: 20 levels by VisualCore project under MIT, sweep made in code) linked from the app README; release-document check passes (python3 scripts/check_experience_release.py --config docs/apps/light-maze/release.json: 5 documents, 32 rows)
- [X] T-A13-603 [US1] Source scan (`--name lm-no-network -- /bin/sh -c "! grep -rnE 'URLSession|import Network|CLLocation|AVCapture|AVAudioRecorder|inputNode|installTap|CMMotion|CNContact|ASIdentifierManager|AppTrackingTransparency|UIScreen.main.brightness|isIdleTimerDisabled' Packages/ExperiencesCreative/LightMaze"`) (FR-A13-602; SC-A13-601) — Verified 2026-11-15: 2026-11-15: .autonomy/checks/A13-P06.lm-no-network.json exit 0 (no network, tracking, sensor, recording, brightness or idle-timer use in Packages/ExperiencesCreative/LightMaze)

## Phase 3: Story 2 — damaged progress never stops play (P1)

- [X] T-A13-604 [US2] Add the test-only seam `var failNextDraw = false` to `Packages/ExperiencesCreative/LightMaze/Experience/MazePresenter.swift` (the next `draw` throws an `ExperienceError` once and clears the flag; documented as test-only, modelled on `TinyWorlds/Experience/WorldsPresenter.swift`) and write `Packages/ExperiencesCreative/LightMaze/ExperienceTests/MazeRecoveryDrawTests.swift` (level 1 solved with a temporary storage so `progress.json` is written; `failNextDraw`; one frame puts the session into its failure state; `progress.json` byte-identical; a new session over the same storage loads the progress and draws) (FR-A13-611; SC-A13-602) — Verified 2026-11-15: 2026-11-15: test-only failNextDraw seam (MazeDrawError.injected once, clears itself) and MazeRecoveryDrawTests (a failed draw fails the session, progress.json byte-identical before and after close, a new session loads the same progress and draws) pass in .autonomy/checks/A13-P06.maze-ios27-2.json exit 0 on sim-27.2 (LightMazeCoreTests 93, LightMazeExperienceTests 80, manifest 6; first attempt A13-P06.maze-ios27.json exit 65 kept: a missing VisualCoreUI import in MazeRecoveryDrawTests)
- [X] T-A13-605 [P] [US2] Commit `Packages/ExperiencesCreative/LightMaze/ExperienceTests/Fixtures/progress-{valid,newer,damaged,truncated}.json` (valid: the exact bytes `Progress.encoded()` gives after level 1 is solved in 1 move; newer: the same with `"schema":2`; damaged: not JSON; truncated: the valid bytes cut in half), add `resources: [.copy("Fixtures")]` to `LightMazeExperienceTests` in `Packages/ExperiencesCreative/Package.swift`, and write `ExperienceTests/ProgressSampleFileTests.swift` (each copied into a temporary storage and loaded with `ProgressStore.load()`: valid loads with level 1 solved and level 2 open; newer → `newer-version`, damaged and truncated → `damaged`, each with fresh progress and the file byte-identical; the schema-1 state example `MazeCore.schemaOneExample()` restores) (FR-A13-610, 612; SC-A13-602) — Verified 2026-11-15: 2026-11-15: four committed progress samples (valid loads with level 1 solved, level 2 open; newer → newer-version; damaged and truncated → damaged; each with fresh progress and byte-identical, no write), Fixtures bundled in LightMazeExperienceTests, schema-1 state example restores; ProgressSampleFileTests (4) pass in .autonomy/checks/A13-P06.maze-ios27-2.json exit 0 on sim-27.2 (LightMazeCoreTests 93, LightMazeExperienceTests 80, manifest 6; first attempt A13-P06.maze-ios27.json exit 65 kept: a missing VisualCoreUI import in MazeRecoveryDrawTests)

## Phase 4: Story 3 — honest store copy and a complete checklist (P1)

- [X] T-A13-606 [P] [US3] Write `docs/apps/light-maze/{store-listing.md (text + Claim | Proving test table; no measured or refused claim), release-checklist.md (Item | Area | Status | Evidence; statuses verified, pending-campaign-ii, owner-action; artifact inventory; accessibility facts proved and audits pending), device-campaign.md (rows for frame pacing, thermals, memory high-water mark, touch latency, haptic and sound feel, VoiceOver and accessibility audits on D1–D3), release.json (contracts/release-config.md)}` and the A13 section of `docs/release/known-limitations.md` (device-only items; beams follow the game's grid rules, not physical optics) (FR-A13-620, 622, 623; SC-A13-603, 604) — Verified 2026-11-15: 2026-11-15: store-listing.md (27 claims, each with existing proving tests), release-checklist.md (32 rows: verified, pending-campaign-ii LM-D1…D6, owner-action), device-campaign.md (LM-D1…D6 on D1–D3), release.json (contract), A13 section of docs/release/known-limitations.md; check_experience_release PASS and check_copy_claims PASS (3 files)
- [X] T-A13-607 [US3] Write `specs/101-lm-p06-release/scan-claims-release.sh` (refuses physics, physical, optics, optical, accurate, accuracy, precise, precision, scientific, realistic, fps, frames per second, battery and a millisecond figure — whole words, case-insensitive — in `docs/apps/light-maze/store-listing.md` and `Packages/ExperiencesCreative/LightMaze/Experience/{MazeControls,MazePresenter}.swift`; every test named in the store claim table is found under `Packages/ExperiencesCreative/LightMaze` or `Apps/VisualCore/Tests/UI/LightMaze`) and run it (`--name claims -- /bin/sh specs/101-lm-p06-release/scan-claims-release.sh`) (FR-A13-621; SC-A13-603) — Verified 2026-11-15: 2026-11-15: specs/101-lm-p06-release/scan-claims-release.sh (refused words in the store text and MazeControls/MazePresenter; every named proving test and interface class exists); .autonomy/checks/A13-P06.claims.json exit 0 (83 proving tests found)

## Phase 5: Story 4 — the maze works in the real app (P2)

- [X] T-A13-608 [P] [US4] Write `Apps/VisualCore/Tests/UI/LightMaze/{LMSupport,LMLevelUITests,LMHelpUITests}.swift` per research D4 (native controls, identifiers `experience.a13.light-maze.<name>`; modelled on `Apps/VisualCore/Tests/UI/TinyWorlds/TWSupport.swift`) and add chunk `"u2": ["LMLevelUITests", "LMHelpUITests"]` (serial) to `scripts/release_check.py` (FR-A13-630) — Verified 2026-11-15: 2026-11-15: LMSupport, LMLevelUITests (solve level 1 by select next and turn, undo, turn, choose the opened level 2 from the Level menu) and LMHelpUITests (Hint names a mirror, Describe shows the board) by native controls with a fresh-data launch; serial chunk u2 in scripts/release_check.py; both pass in .autonomy/checks/A13-P06.app-ui.json (32.1 s and 21.1 s)
- [X] T-A13-609 [US4] Light Maze suites on sim-27.2 (`--name maze-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing LightMazeCoreTests LightMazeExperienceTests`) (FR-A13-632; SC-A13-605) — Verified 2026-11-15: 2026-11-15: .autonomy/checks/A13-P06.maze-ios27-2.json exit 0 on sim-27.2 (LightMazeCoreTests 93, LightMazeExperienceTests 80, manifest 6)
- [X] T-A13-610 [US4] App build, unit and interface chunk (`xcodegen generate --spec project.yml` first, then `--name app-ui -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27 app-ui-ios27-u2`; each interface test < 60 s) (FR-A13-630; SC-A13-605) — Verified 2026-11-15: 2026-11-15: .autonomy/checks/A13-P06.app-ui.json exit 0 (xcodegen generate; app-build-for-testing-ios27, app-unit-ios27, app-ui-ios27-u2 — 2 interface tests, each under 60 s)
- [ ] T-A13-611 [US4] Runner iOS 27 (`--name verify-27 -- python3 scripts/verify_experiences.py --only a13.light-maze --runtime 27`) (SC-A13-605)
- [ ] T-A13-612 [US4] Release build checks (`--name release-checks -- python3 scripts/release_check.py --only app-release-build app-release-symbols app-privacy-manifest app-no-tracking app-licenses app-usage-descriptions experience-release-a13 copy-claims-a13`) (FR-A13-601, 603, 620, 621, 631; SC-A13-601)

## Phase 6: Records and evidence

- [ ] T-A13-613 Script tests (`--name script-tests -- python3 scripts/test_scripts.py`)
- [ ] T-A13-614 BLOCKED_OWNER_ACTION: signing, archive upload and App Store Connect entry of Light Maze's store text, per `docs/release/build-and-archive.md` owner steps (FR-A13-620)
- [ ] T-A13-615 {device} In the device campaign (after ImplementationLock-100): the measurements and audits of `docs/apps/light-maze/device-campaign.md` on D1–D3 (FR-A13-622)
- [ ] T-A13-616 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A13-P06 (owner and device items stay open, as for A12-P06); update README.md (status, gate count) in the record commit (rule 16)

## Dependencies

T-A13-601 → (602 ∥ 604 ∥ 605 ∥ 606 ∥ 608) → 603, 607 → 609 → 610 → 611 → 612 → 613 → 616 (607 needs 606's store text
and 608's test names; 612 needs 606's release.json; 614 and 615 stay open).

## Parallel examples

Agent A: T-A13-602 and 606 (documents). Agent B: T-A13-605 (fixtures and sample tests). Agent C: T-A13-608 (interface
tests). Lead: 604 (presenter seam and recovery test), Package.swift, release_check.py chunk (agent C hands its line
over), 607, runs, commits.

## Implementation strategy

Privacy and recovery first (602–605), then copy (606–607), then interface and release checks (608–612). Review
checkpoints after 605, after 607 and at 612.
