# Tasks: Tiny Worlds — Phase 06 Final verification, privacy, packaging and release

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/release-config.md](contracts/release-config.md), [quickstart.md](quickstart.md). Gate A12-P06 (legacy).
Evidence: `python3 Tools/python/desktop_runbook.py run-check --stage A12-P06 --timeout 600 --name <check> -- <command>`.
Commit after every task (no trailers); read every check's exit before ticking. iOS 27 only. Owner and {device} tasks
stay open, as for A11-P06.

## Phase 1: Setup

- [X] T-A12-601 Baseline: cite the A12-P05 evidence on the unchanged tree (`.autonomy/checks/A12-P05.{worlds-ios27-3,app-unit,verify-27}.json`) instead of a rerun (owner ruling of 2026-11-14) — Verified 2026-11-15: 2026-11-15: cited .autonomy/checks/A12-P05.{worlds-ios27-3,app-unit,verify-27}.json (exit 0) on the unchanged source tree (no rerun)

## Phase 2: User Story 1 — nothing leaves the device (P1) 🎯

- [ ] T-A12-602 [P] [US1] Write `docs/apps/tiny-worlds/privacy-and-credits.md` per research D1 (stored: `world-0…3.json` and `world-0…3.png` in the experience's folder and the app's session state, no personal data; nothing sent; no permission; how to delete: Clear on a slot, the app's Settings reset of the experience's data, or removing the app; credits from `content-licenses.md`: 3 presets, 3 palettes, 4 props, 4 prop palettes, 3 packs, all original, MIT) (FR-A12-601, 604)
- [ ] T-A12-603 [US1] Source scan (`--name tw-no-network -- /bin/sh -c "! grep -rnE 'URLSession|import Network|CLLocation|AVCapture|AVAudioRecorder|inputNode|installTap|CMMotion|CNContact|ASIdentifierManager|AppTrackingTransparency|UIScreen.main.brightness|isIdleTimerDisabled' Packages/ExperiencesCreative/TinyWorlds"`) (FR-A12-602; SC-A12-601)

## Phase 3: User Story 2 — damaged data never breaks a world (P1)

- [ ] T-A12-604 [US2] Add the test-only seam `var failNextDraw = false` to `Packages/ExperiencesCreative/TinyWorlds/Experience/WorldsPresenter.swift` (the next `draw` throws an `ExperienceError` once and clears the flag; documented as test-only) (FR-A12-611)
- [ ] T-A12-605 [P] [US2] Write `Packages/ExperiencesCreative/TinyWorlds/ExperienceTests/WorldsRecoveryDrawTests.swift` (a world saved to slot 0 in a temporary storage, `failNextDraw`, one frame puts the session into its failure state, `world-0.json` and `world-0.png` byte-identical, a new session draws; `WorldsCore.schemaOneExample()` restores) (FR-A12-611, 612)
- [ ] T-A12-606 [P] [US2] Commit `Packages/ExperiencesCreative/TinyWorlds/ExperienceTests/Fixtures/world-{valid,newer,damaged,truncated}.json` (valid: the exact bytes `WorldStore` writes for the island pack saved to slot 0; newer: schema 3; damaged: not JSON; truncated: the valid file cut in half), add `resources: [.copy("Fixtures")]` to `TinyWorldsExperienceTests` in `Packages/ExperiencesCreative/Package.swift`, and write `Packages/ExperiencesCreative/TinyWorlds/ExperienceTests/WorldSampleFileTests.swift` ("valid opens; newer → `newer-version`; damaged and truncated → `damaged`; all byte-identical after reading"; a lone `world-0.png` leaves slot 0's status "Empty."; the valid sample without a picture reads "Holds “<name>”, no picture.") (FR-A12-610; SC-A12-602)

## Phase 4: User Story 3 — honest copy and a complete checklist (P1)

- [ ] T-A12-607 [P] [US3] Write `docs/apps/tiny-worlds/{store-listing.md (text + claim → proving-test table; no measured or refused claim), release-checklist.md (Item | Area | Status | Evidence; statuses verified, pending-campaign-ii, owner-action; artifact inventory; accessibility rows per FR-A12-623), release.json (contracts/release-config.md)}`, link them from `docs/apps/tiny-worlds/README.md`, and add the A12 section to `docs/release/known-limitations.md` (frame pacing, thermals, memory high-water mark, touch latency, accessibility audits; stylised dioramas, not maps) (FR-A12-620, 622, 623)
- [ ] T-A12-608 [US3] Write `specs/094-tw-p06-release/scan-claims-release.sh` (the A12-P05 refused words in the store text and the interface Swift; every test named in the store-listing claim table found in `Packages/ExperiencesCreative/TinyWorlds`, `Packages/VisualCore`, `Packages/VisualCoreRendering` or `Apps/VisualCore/Tests`; exit 1 otherwise) and run (`--name release-docs -- /bin/sh -c "python3 scripts/release_check.py --only experience-release-a12 copy-claims-a12 && sh specs/094-tw-p06-release/scan-claims-release.sh"`) (FR-A12-620, 621; SC-A12-603)

## Phase 5: User Story 4 — the worlds work in the real app (P2)

- [ ] T-A12-609 [P] [US4] Write `Apps/VisualCore/Tests/UI/TinyWorlds/{TWSupport,TWWorldUITests,TWEditUITests}.swift` per research D4 (native controls; modelled on `Apps/VisualCore/Tests/UI/PhysicsPlayground/PPSupport.swift`) and add chunk `"t2"` (serial) to `scripts/release_check.py` (FR-A12-630)
- [ ] T-A12-610 [US4] Tiny Worlds suites on sim-27.2 (`--name worlds-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing TinyWorldsCoreTests TinyWorldsExperienceTests`) (FR-A12-610–612, 632; SC-A12-602, 605)
- [ ] T-A12-611 [US4] App build, unit and interface chunk (`xcodegen generate --spec project.yml` first, then `--name app-ui -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27 app-ui-ios27-t2`; each interface test < 60 s) (FR-A12-630; SC-A12-604)
- [ ] T-A12-612 [US4] Runner iOS 27 (`--name verify-27 -- python3 scripts/verify_experiences.py --only a12.tiny-worlds --runtime 27`) (SC-A12-605)
- [ ] T-A12-613 [US4] Release build checks (`--name release-checks -- python3 scripts/release_check.py --only app-release-build app-release-symbols app-privacy-manifest app-no-tracking app-licenses app-usage-descriptions`) (FR-A12-601, 603, 631; SC-A12-601)

## Phase 6: Polish, owner and device items

- [ ] T-A12-614 Script tests (`--name script-tests -- python3 scripts/test_scripts.py`)
- [ ] T-A12-615 BLOCKED_OWNER_ACTION: signing, archive upload and App Store Connect entry of Tiny Worlds' store text, per `docs/release/build-and-archive.md` owner steps (FR-A12-640)
- [ ] T-A12-616 {device} In the device campaign (after ImplementationLock-100): the measurements and audits of `docs/apps/tiny-worlds/device-campaign.md` on D1–D3 (FR-A12-641)
- [ ] T-A12-617 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A12-P06 (owner and device items stay open, as for A11-P06); update README.md (status, gate count) in the record commit (rule 16)

## Dependencies

T-A12-601 → (602 ∥ 604 → 605 ∥ 606 ∥ 607 ∥ 609) → 603, 608 → 610 → 611 → 612 → 613 → 614 → 617.

## Parallel examples

Agent A: T-A12-602, 607. Agent B: T-A12-609 test files (release_check.py chunk by the lead). Agent C: T-A12-605, 606
tests and fixtures (Package.swift and the seam by the lead). Lead: scans, release.json review, runs, ticks, commits.

## Implementation strategy

Documents and scans first, then the seam, recovery and sample tests, then the interface chunk and the builds.
