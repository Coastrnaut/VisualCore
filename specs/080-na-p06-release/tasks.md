# Tasks: Neon Arcade — Phase 06 Final verification, privacy, packaging and release

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/release-config.md](contracts/release-config.md), [quickstart.md](quickstart.md). Gate A10-P06 (legacy).
Evidence: `python3 Tools/python/desktop_runbook.py run-check --stage A10-P06 --timeout 600 --name <check> -- <command>`. Commit after every task (no trailers); read every check's exit before ticking. iOS 27 only. Owner and {device} tasks stay open, as for A09-P06.

## Phase 1: Setup

- [X] T-A10-601 Baseline: cite the A10-P05 evidence on the unchanged tree (`.autonomy/checks/A10-P05.{arcade-ios27,app-ui,verify-27}.json`) instead of a rerun (owner ruling of 2026-11-14) — Verified 2026-11-15: 2026-11-15: cited .autonomy/checks/A10-P05.{arcade-ios27,app-ui,verify-27}.json on the unchanged tree (no rerun)

## Phase 2: User Story 1 — nothing leaves the device (P1) 🎯

- [X] T-A10-602 [P] [US1] Write `docs/apps/neon-arcade/privacy-and-credits.md` (stored: `high-scores.json` — at most ten scores with wave and run number, no personal data — in the experience's folder, and the app's session state; nothing sent; no permission; sound is ambient and follows the silent switch; how to delete: the app's Settings reset of the experience's data or removing the app; credits from `content-licenses.md`) (FR-A10-601, 604) — Verified 2026-11-15: 2026-11-15: docs/apps/neon-arcade/privacy-and-credits.md (high-scores.json and the session state, deletion by Settings reset or removing the app, ambient sound, no permission, nothing sent, credits from content-licenses.md); required document of release.json, checked in .autonomy/checks/A10-P06.release-docs-2.json
- [X] T-A10-603 [US1] Source scan (`--name na-no-network -- /bin/sh -c "! grep -rnE 'URLSession|import Network|CLLocation|AVCapture|AVAudioRecorder|inputNode|installTap|MicrophoneAudioSource|CMMotion|CNContact|ASIdentifierManager|AppTrackingTransparency|UIScreen.main.brightness|isIdleTimerDisabled' Packages/ExperiencesCreative/NeonArcade"`) (FR-A10-602; SC-A10-601) — Verified 2026-11-15: 2026-11-15: .autonomy/checks/A10-P06.na-no-network.json exit 0 (no network, tracking, sensor, recording, brightness or idle-timer use in Packages/ExperiencesCreative/NeonArcade)

## Phase 3: User Story 2 — damaged data never breaks the game (P1)

- [X] T-A10-604 [P] [US2] Add `resources: [.copy("Fixtures")]` to the `NeonArcadeExperienceTests` target in `Packages/ExperiencesCreative/Package.swift` and commit four samples in `Packages/ExperiencesCreative/NeonArcade/ExperienceTests/Fixtures/` ("valid (board 1, three entries), newer (board 2), damaged (not JSON), truncated") (FR-A10-610) — Verified 2026-11-15: 2026-11-15: NeonArcadeExperienceTests resources .copy("Fixtures"); four samples high-scores-{valid,newer,damaged,truncated}.json; bundled and used by HighScoreSampleFileTests (A10-P06.arcade-ios27, 214 tests pass)
- [X] T-A10-605 [P] [US2] Write `ExperienceTests/HighScoreSampleFileTests.swift` (each sample copied as `high-scores.json` into a temporary storage: the valid one shown, the others reported, all byte-identical after a reload; a finished run then writes a valid table) and `ExperienceTests/ArcadeRecoveryDrawTests.swift` (a saved table, `failNextDraw`, a frame puts the session into its failure state, `high-scores.json` byte-identical, a new session draws; schema-1…3 examples restore) (FR-A10-610–612; SC-A10-602) — Verified 2026-11-15: 2026-11-15: HighScoreSampleFileTests (valid shown; newer, damaged, truncated reported and byte-identical, then replaced by a finished run) and ArcadeRecoveryDrawTests (failNextDraw fails the session, high-scores.json byte-identical, a new session draws; schema-1…3 examples restore); .autonomy/checks/A10-P06.arcade-ios27.json exit 0 (214 tests)

## Phase 4: User Story 3 — honest copy and a complete checklist (P1)

- [X] T-A10-606 [P] [US3] Write `docs/apps/neon-arcade/{store-listing.md (text + claim → proving-test table; no measured, skill or ranking claim), release-checklist.md (Item | Area | Status | Evidence; statuses verified, pending-campaign-ii, owner-action; artifact inventory; accessibility rows per FR-A10-623), release.json (contracts/release-config.md)}`, link them from `docs/apps/neon-arcade/README.md`, and add the A10 section to `docs/release/known-limitations.md` (device-only items) (FR-A10-620, 622, 623) — Verified 2026-11-15: 2026-11-15: store-listing.md (29 claims, each with a proving test), release-checklist.md (37 rows: 29 verified, 6 pending-campaign-ii, 2 owner-action; artifact inventory; accessibility rows), release.json, README links, known-limitations A10 section, device-campaign audit row; experience-release-a10 and copy-claims-a10 pass (.autonomy/checks/A10-P06.release-docs-2.json)
- [X] T-A10-607 [US3] Write `specs/080-na-p06-release/scan-claims-release.sh` (the skill and ranking words of Clarifications Q2 refused in the store text and the interface Swift; every test name in the store-listing claim table found in `Packages/ExperiencesCreative/NeonArcade`, `Packages/VisualCore`, `Packages/VisualCoreRendering` or `Apps/VisualCore/Tests`; exit 1 otherwise) and run the release-document, copy and claim checks (`--name release-docs -- /bin/sh -c "python3 scripts/release_check.py --only experience-release-a10 copy-claims-a10 && sh specs/080-na-p06-release/scan-claims-release.sh"`) (FR-A10-620, 621; SC-A10-603) — Verified 2026-11-15: 2026-11-15: specs/080-na-p06-release/scan-claims-release.sh (skill and ranking words refused; 87 proving tests found); .autonomy/checks/A10-P06.release-docs.json and release-docs-2.json exit 0 (experience-release-a10, copy-claims-a10, claims scan)

## Phase 5: User Story 4 — the game works in the real app (P2)

- [X] T-A10-608 [P] [US4] Write `Apps/VisualCore/Tests/UI/NeonArcade/NASettingsUITests.swift` (sound and haptics toggles change their values; the sensitivity stepper's value changes; using `NASupport`) and add it to chunk `"r2"` in `scripts/release_check.py` (FR-A10-630) — Verified 2026-11-15: 2026-11-15: NASettingsUITests (sound toggle, haptics toggle, sensitivity stepper) added to chunk r2 (serial); pass in .autonomy/checks/A10-P06.app-ui.json
- [X] T-A10-609 [US4] Neon Arcade suites on sim-27.2 (`--name arcade-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing NeonArcadeCoreTests NeonArcadeExperienceTests`) (FR-A10-632; SC-A10-605) — Verified 2026-11-15: 2026-11-15: .autonomy/checks/A10-P06.arcade-ios27.json exit 0 (214 tests on sim-27.2)
- [X] T-A10-610 [US4] App build, unit and interface chunk (`xcodegen generate --spec project.yml` first, then `--name app-ui -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27 app-ui-ios27-r2`; each interface test < 60 s) (FR-A10-630; SC-A10-604) — Verified 2026-11-15: 2026-11-15: .autonomy/checks/A10-P06.app-ui.json exit 0 (app build, unit, chunk r2: 7 interface tests in 165 s — NASettingsUITests 3 in 60.7 s, NAArcadeUITests 4 in about 105 s)
- [X] T-A10-611 [US4] Runner iOS 27 (`--name verify-27 -- python3 scripts/verify_experiences.py --only a10.neon-arcade --runtime 27`) — Verified 2026-11-15: 2026-11-15: .autonomy/checks/A10-P06.verify-27.json exit 0 (runner, a10.neon-arcade, nine standard scenarios)
- [X] T-A10-612 [US4] Release build checks (`--name release-checks -- python3 scripts/release_check.py --only app-release-build app-release-symbols app-privacy-manifest app-no-tracking app-licenses app-usage-descriptions`) (FR-A10-603, 631) — Verified 2026-11-15: 2026-11-15: .autonomy/checks/A10-P06.release-checks.json exit 0 (release build, symbols, privacy manifest, no tracking, licenses, usage descriptions)

## Phase 6: Polish, owner and device items

- [X] T-A10-613 Script tests (`--name script-tests -- python3 scripts/test_scripts.py`) — Verified 2026-11-15: 2026-11-15: .autonomy/checks/A10-P06.script-tests.json exit 0
- [ ] T-A10-614 BLOCKED_OWNER_ACTION: signing, archive upload and App Store Connect entry of Neon Arcade's store text, per `docs/release/build-and-archive.md` owner steps (FR-A10-640)
- [ ] T-A10-615 {device} In the device campaign (after ImplementationLock-100): the measurements and audits of `docs/apps/neon-arcade/device-campaign.md` on D1–D3 (FR-A10-641)
- [X] T-A10-616 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A10-P06 (owner and device items stay open, as for A09-P06); update README.md (status, gate count) in the record commit (rule 16) — Verified 2026-11-15: 2026-11-15: /speckit-converge appended nothing (18 FR/SC, 4 stories, 13 tasks with evidence; all 15 checks cited by the release checklist exist with exit 0; T-A10-614 owner and T-A10-615 device open by design)

## Dependencies

T-A10-601 → (602 ∥ 604 ∥ 606 ∥ 608) → 603, 605, 607 → 609 → 610 → 611 → 612 → 613 → 616.

## Parallel examples

Agent A: T-A10-602, 606. Agent B: T-A10-604 samples (Package.swift by the lead), 605. Agent C: T-A10-608. Lead: scans,
release.json review, runs, commits.

## Implementation strategy

Documents and scans first, then the data and recovery tests, then the interface chunk and the builds.
