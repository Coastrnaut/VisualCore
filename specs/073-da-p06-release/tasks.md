# Tasks: Digital Aquarium — Phase 06 Final verification, privacy, packaging and release

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/release-config.md](contracts/release-config.md), [quickstart.md](quickstart.md). Gate A09-P06 (legacy).
Evidence: `python3 Tools/python/desktop_runbook.py run-check --stage A09-P06 --timeout 600 --name <check> -- <command>`. Commit after every task (no trailers). iOS 27 only. Owner and {device} tasks
stay open, as for A07-P06 and A08-P06.

## Phase 1: Setup

- [X] T-A09-601 Baseline: cite the A09-P05 evidence on the unchanged tree (`.autonomy/checks/A09-P05.aquarium-ios27.json`, `.autonomy/checks/A09-P05.app-unit.json`, `.autonomy/checks/A09-P05.verify-27.json`) instead of a rerun (owner ruling of 2026-11-14) — Verified 2026-11-14: 2026-11-14: no aquarium or app source change since the A09-P05 evidence (only specs, docs and the record's regenerated catalog fixture); cites .autonomy/checks/A09-P05.{aquarium-ios27,app-unit,verify-27}.json

## Phase 2: User Story 1 — nothing leaves the device (P1) 🎯

- [X] T-A09-602 [P] [US1] Write `docs/apps/digital-aquarium/privacy-and-credits.md` (stored: `aquarium-<uuid>.json` saved configurations in the experience's folder and the app's session state; nothing sent; no permission; credits from `content-licenses.md`) (FR-A09-601, 604) — Verified 2026-11-14: 2026-11-14: docs/apps/digital-aquarium/privacy-and-credits.md (stored files, nothing sent, no permission, credits of all 13 bundled items)
- [X] T-A09-603 [US1] Source scan (`python3 Tools/python/desktop_runbook.py run-check --stage A09-P06 --timeout 600 --name da-no-network -- /bin/sh -c "! grep -rnE 'URLSession|import Network|CLLocation|AVCapture|AVAudio|CMMotion|CNContact|ASIdentifierManager|AppTrackingTransparency|UIScreen.main.brightness|isIdleTimerDisabled' Packages/ExperiencesCreative/DigitalAquarium"`) (FR-A09-602; SC-A09-601) — Verified 2026-11-14: 2026-11-14: .autonomy/checks/A09-P06.da-no-network.json exit 0 (no network, tracking, sensor, brightness or idle-timer use in Packages/ExperiencesCreative/DigitalAquarium)

## Phase 3: User Story 2 — damaged data never breaks the aquarium (P1)

- [X] T-A09-604 [P] [US2] Add `resources: [.copy("Fixtures")]` to the `DigitalAquariumExperienceTests` target in `Packages/ExperiencesCreative/Package.swift` and commit four samples in `Packages/ExperiencesCreative/DigitalAquarium/ExperienceTests/Fixtures/` ("valid (format 1), newer (format 2), damaged (not JSON), mismatched id"; synthetic ids `00000000-0000-4000-8000-…`) (FR-A09-610) — Verified 2026-11-14: 2026-11-14: Fixtures resource on DigitalAquariumExperienceTests; four samples (valid, newer, damaged, mismatched id) with synthetic ids
- [X] T-A09-605 [P] [US2] Write `ExperienceTests/AquariumSampleFileTests.swift` (samples copied into a temporary storage; the valid one listed, two unreadable and one newer counted; all byte-identical after a reload and a save) and `ExperienceTests/AquariumRecoveryDrawTests.swift` (a saved configuration, `failNextDraw`, a frame puts the session into its failure state, files byte-identical, a new session draws; schema-1…3 examples restore) (FR-A09-610–612; SC-A09-602) — Verified 2026-11-14: 2026-11-14: AquariumSampleFileTests (1 listed, 2 unreadable, 1 newer, byte-identical; schema-1…3 examples restore) and AquariumRecoveryDrawTests (failure state, files byte-identical, reopen draws) pass on sim-27.2 (.autonomy/checks/A09-P06.aquarium-ios27.json)

## Phase 4: User Story 3 — honest copy and a complete checklist (P1)

- [X] T-A09-606 [P] [US3] Write `docs/apps/digital-aquarium/{store-listing.md (text + claim → proving-test table; no measured, realism or care claim), release-checklist.md (Item | Area | Status | Evidence; statuses verified, pending-campaign-ii, owner-action; artifact inventory; accessibility rows per FR-A09-623), release.json (contracts/release-config.md)}`, link them from `docs/apps/digital-aquarium/README.md`, and add the A09 section to `docs/release/known-limitations.md` (device-only items) (FR-A09-620, 622, 623) — Verified 2026-11-14: 2026-11-14: store-listing (29 claims traced to tests), release-checklist (35 rows: 22 verified, 11 pending-campaign-ii, 2 owner-action; artifact inventory), release.json, README links, known-limitations A09 section; check_experience_release PASS 5 documents
- [X] T-A09-607 [US3] Write `specs/073-da-p06-release/scan-realism.sh` (the realism and care words of Clarifications Q2 refused in the store text and the interface Swift; and every test name in the store-listing claim table found in `Packages/ExperiencesCreative/DigitalAquarium` or `Apps/VisualCore/Tests`, exit 1 otherwise) and run the release-document, copy and realism checks (`python3 Tools/python/desktop_runbook.py run-check --stage A09-P06 --timeout 600 --name release-docs -- /bin/sh -c "python3 scripts/release_check.py --only experience-release-a09 copy-claims-a09 && sh specs/073-da-p06-release/scan-realism.sh"`) (FR-A09-620, 621; SC-A09-603) — Verified 2026-11-14: 2026-11-14: .autonomy/checks/A09-P06.release-docs.json exit 0 (experience-release-a09, copy-claims-a09, realism scan: 70 proving tests found, no realism or care word)

## Phase 5: User Story 4 — the aquarium works in the real app (P2)

- [X] T-A09-608 [P] [US4] Write `Apps/VisualCore/Tests/UI/DigitalAquarium/{DASupport.swift, DAAquariumUITests.swift, DALibraryUITests.swift}` (candidate launch with `-vcCandidates` and `-openExperience a09.digital-aquarium`; feed, add/move right/remove decor, Kelp, ambient on — checked through the canvas description and control values; save under a name, change habitat, open the saved one) and add the serial chunk `"q2": ["DAAquariumUITests", "DALibraryUITests"]` to `UI_CHUNKS` and `SERIAL_CHUNKS` in `scripts/release_check.py` (FR-A09-630) — Verified 2026-11-14: 2026-11-14: DASupport, DAAquariumUITests (feeding, decorations, habitat and ambient), DALibraryUITests (save and open); serial chunk q2 in release_check.py
- [X] T-A09-609 [US4] Digital Aquarium suites on sim-27.2 (`python3 Tools/python/desktop_runbook.py run-check --stage A09-P06 --timeout 600 --name aquarium-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing DigitalAquariumCoreTests DigitalAquariumExperienceTests`) (FR-A09-632; SC-A09-605) — Verified 2026-11-14: 2026-11-14: .autonomy/checks/A09-P06.aquarium-ios27.json exit 0 (core 142 + experience 88 XCTest + 4 manifest tests; each < 10 s)
- [X] T-A09-610 [US4] App build, unit and interface chunk (`xcodegen generate --spec project.yml` first, then `python3 Tools/python/desktop_runbook.py run-check --stage A09-P06 --timeout 600 --name app-ui -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27 app-ui-ios27-q2`; each interface test < 60 s) (FR-A09-630; SC-A09-604) — Verified 2026-11-14: 2026-11-14: .autonomy/checks/A09-P06.app-ui.json exit 0 (build-for-testing, unit 78 tests, chunk q2: 4 tests in 97.4 s, longest 41.4 s)
- [ ] T-A09-611 [US4] Runner iOS 27 (`python3 Tools/python/desktop_runbook.py run-check --stage A09-P06 --timeout 600 --name verify-27 -- python3 scripts/verify_experiences.py --only a09.digital-aquarium --runtime 27`)
- [ ] T-A09-612 [US4] Release build checks (`python3 Tools/python/desktop_runbook.py run-check --stage A09-P06 --timeout 600 --name release-checks -- python3 scripts/release_check.py --only app-release-build app-release-symbols app-privacy-manifest app-no-tracking app-licenses app-usage-descriptions`) (FR-A09-603, 631)

## Phase 6: Polish, owner and device items

- [ ] T-A09-613 Script tests (`python3 Tools/python/desktop_runbook.py run-check --stage A09-P06 --timeout 600 --name script-tests -- python3 scripts/test_scripts.py`)
- [ ] T-A09-614 BLOCKED_OWNER_ACTION: signing, archive upload and App Store Connect entry of Digital Aquarium's store text, per `docs/release/build-and-archive.md` owner steps (FR-A09-640)
- [ ] T-A09-615 {device} In the device campaign (after ImplementationLock-100): the measurements and audits of `docs/apps/digital-aquarium/device-campaign.md` on D1–D3 (FR-A09-641)
- [ ] T-A09-616 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A09-P06 (owner and device items stay open, as for A08-P06); update README.md (status, gate count) in the record commit (rule 16)

## Dependencies

T-A09-601 → (602 ∥ 604 ∥ 606 ∥ 608) → 603, 605, 607 → 609 → 610 → 611 → 612 → 613 → 616.

## Parallel examples

Agent A: T-A09-602, 606. Agent B: T-A09-604, 605. Agent C: T-A09-608. Lead: scans, runs, commits.

## Implementation strategy

Documents and scans first, then the data and recovery tests, then the interface chunk and the builds.
