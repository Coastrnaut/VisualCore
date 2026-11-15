# Tasks: Physics Playground — Phase 06 Final verification, privacy, packaging and release

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/release-config.md](contracts/release-config.md), [quickstart.md](quickstart.md). Gate A11-P06 (legacy).
Evidence: `python3 Tools/python/desktop_runbook.py run-check --stage A11-P06 --timeout 600 --name <check> -- <command>`.
Commit after every task (no trailers); read every check's exit before ticking. iOS 27 only. Owner and {device} tasks
stay open, as for A10-P06.

## Phase 1: Setup

- [X] T-A11-601 Baseline: cite the A11-P05 evidence on the unchanged tree (`.autonomy/checks/A11-P05.{playground-ios27,app-unit,verify-27}.json`) instead of a rerun (owner ruling of 2026-11-14) — Verified 2026-11-15: 2026-11-15: cited .autonomy/checks/A11-P05.{playground-ios27,app-unit,verify-27}.json (exit 0) on the unchanged source tree (no rerun)

## Phase 2: User Story 1 — nothing leaves the device (P1) 🎯

- [ ] T-A11-602 [P] [US1] Write `docs/apps/physics-playground/privacy-and-credits.md` (stored: `experiment-<slot>.json` saved experiments and the app's session state in the experience's folder, no personal data; nothing sent; no permission; how to delete: delete an experiment in the experience, the app's Settings reset of the experience's data, or removing the app; credits from `content-licenses.md`: 4 materials, 4 presets, 2 tutorials, all original) (FR-A11-601, 604)
- [X] T-A11-603 [US1] Source scan (`--name pp-no-network -- /bin/sh -c "! grep -rnE 'URLSession|import Network|CLLocation|AVCapture|AVAudioRecorder|inputNode|installTap|CMMotion|CNContact|ASIdentifierManager|AppTrackingTransparency|UIScreen.main.brightness|isIdleTimerDisabled' Packages/ExperiencesCreative/PhysicsPlayground"`) (FR-A11-602; SC-A11-601) — Verified 2026-11-15: 2026-11-15: .autonomy/checks/A11-P06.pp-no-network.json exit 0 (no network, tracking, sensor, recording, brightness or idle-timer use in Packages/ExperiencesCreative/PhysicsPlayground)

## Phase 3: User Story 2 — damaged data never breaks the playground (P1)

- [ ] T-A11-604 [P] [US2] Write `Packages/ExperiencesCreative/PhysicsPlayground/ExperienceTests/PlaygroundRecoveryDrawTests.swift` (a saved experiment, `failNextDraw`, a frame puts the session into its failure state, `experiment-<slot>.json` byte-identical, a new session draws; the schema-1…4 examples restore) (FR-A11-611, 612)
- [ ] T-A11-605 [US2] Re-run the committed sample files (`ExperimentSampleFileTests`: valid opened; newer, damaged, truncated refused and byte-identical) in the package run of T-A11-610 (FR-A11-610; SC-A11-602)

## Phase 4: User Story 3 — honest copy and a complete checklist (P1)

- [ ] T-A11-606 [P] [US3] Write `docs/apps/physics-playground/{store-listing.md (text + claim → proving-test table; no measured or accuracy claim), release-checklist.md (Item | Area | Status | Evidence; statuses verified, pending-campaign-ii, owner-action; artifact inventory; accessibility rows per FR-A11-623), release.json (contracts/release-config.md)}`, link them from `docs/apps/physics-playground/README.md`, and add the A11 section to `docs/release/known-limitations.md` (frame pacing, thermals, touch latency, VoiceOver; the numbers are an educational approximation) (FR-A11-620, 622, 623)
- [ ] T-A11-607 [US3] Write `specs/087-pp-p06-release/scan-claims-release.sh` (the accuracy, safety, prediction and learning-outcome words of Clarifications Q2 refused in the store text and the interface Swift after removing the two allowed denial phrases; every test name in the store-listing claim table found in `Packages/ExperiencesCreative/PhysicsPlayground`, `Packages/VisualCore`, `Packages/VisualCoreRendering` or `Apps/VisualCore/Tests`; exit 1 otherwise) and run (`--name release-docs -- /bin/sh -c "python3 scripts/release_check.py --only experience-release-a11 copy-claims-a11 && sh specs/087-pp-p06-release/scan-claims-release.sh"`) (FR-A11-620, 621; SC-A11-603)

## Phase 5: User Story 4 — the playground works in the real app (P2)

- [ ] T-A11-608 [P] [US4] Write `Apps/VisualCore/Tests/UI/PhysicsPlayground/{PPSupport,PPWorldUITests,PPExperimentUITests}.swift` (`PPWorldUITests`: drop a body, pause, single step, time scale; `PPExperimentUITests`: open a preset, force arrows, start a tutorial; native controls; modelled on `NASupport`) and add chunk `"s2"` (serial) to `scripts/release_check.py` (FR-A11-630)
- [ ] T-A11-609 [US4] Physics Playground suites on sim-27.2 (`--name playground-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing PhysicsPlaygroundCoreTests PhysicsPlaygroundExperienceTests`) (FR-A11-610–612, 632; SC-A11-602, 605)
- [ ] T-A11-610 [US4] App build, unit and interface chunk (`xcodegen generate --spec project.yml` first, then `--name app-ui -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27 app-ui-ios27-s2`; each interface test < 60 s) (FR-A11-630; SC-A11-604)
- [ ] T-A11-611 [US4] Runner iOS 27 (`--name verify-27 -- python3 scripts/verify_experiences.py --only a11.physics-playground --runtime 27`) (SC-A11-605)
- [ ] T-A11-612 [US4] Release build checks (`--name release-checks -- python3 scripts/release_check.py --only app-release-build app-release-symbols app-privacy-manifest app-no-tracking app-licenses app-usage-descriptions`) (FR-A11-601, 603, 631; SC-A11-601)

## Phase 6: Polish, owner and device items

- [ ] T-A11-613 Script tests (`--name script-tests -- python3 scripts/test_scripts.py`)
- [ ] T-A11-614 BLOCKED_OWNER_ACTION: signing, archive upload and App Store Connect entry of Physics Playground's store text, per `docs/release/build-and-archive.md` owner steps (FR-A11-640)
- [ ] T-A11-615 {device} In the device campaign (after ImplementationLock-100): the measurements and audits of `docs/apps/physics-playground/device-campaign.md` on D1–D3 (FR-A11-641)
- [ ] T-A11-616 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A11-P06 (owner and device items stay open, as for A10-P06); update README.md (status, gate count) in the record commit (rule 16)

## Dependencies

T-A11-601 → (602 ∥ 604 ∥ 606 ∥ 608) → 603, 607 → 609 (covers 605) → 610 → 611 → 612 → 613 → 616.

## Parallel examples

Agent A: T-A11-602, 606. Agent B: T-A11-604. Agent C: T-A11-608 test files (release_check.py chunk by the lead).
Lead: scans, release.json review, runs, ticks, commits.

## Implementation strategy

Documents and scans first, then the recovery test, then the interface chunk and the builds.
