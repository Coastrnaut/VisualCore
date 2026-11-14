# Tasks: Particle Universe — Phase 06 Final verification, privacy, packaging and release

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/](contracts/), [quickstart.md](quickstart.md). Ledger gate A04-P06 (legacy). PU =
`Packages/ExperiencesCreative/ParticleUniverse`. Evidence: `python3 Tools/python/desktop_runbook.py run-check --stage
A04-P06 --name <check> -- <command>`. Commit after every task (no trailers); push through `scripts/tick_task.py`.

## Phase 1: Setup

- [X] T-A04-601 Record the baseline: ExperiencesCreative package on sim-27.2 before changes (`run-check --name baseline-experiences -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test`) — Verified 2026-11-13: 2026-11-13 .autonomy/checks/A04-P06.baseline-experiences.json (sim-27.2, TEST SUCCEEDED)

## Phase 2: Foundational

- [X] T-A04-602 Add `resources: [.copy("Fixtures")]` to the `ParticleUniverseExperienceTests` target in `Packages/ExperiencesCreative/Package.swift` and create `PU/ExperienceTests/Fixtures/Library/` (lead) — Verified 2026-11-13: 2026-11-13 .autonomy/checks/A04-P06.experiences-ios27.json and experiences-ios26.json (ExperiencesCreative on sim-27.2 and sim-26.5, TEST SUCCEEDED; the Fixtures resource bundle loads in ParticleLibraryMigrationTests)

## Phase 3: User Story 1 — Nothing about the person leaves the device (P1) 🎯

**Independent test**: release declarations, scans and the privacy note.

- [X] T-A04-603 [P] [US1] Write `docs/apps/particle-universe/privacy-and-credits.md`: stored data (saved scenes `scene-<uuid>.json` in the experience's own folder, nothing else persisted), no collection or sharing, no permission, no network, no third-party code, no non-code assets, the app manifest's required reasons that cover the experience (UserDefaults CA92.1 via ExperienceStorage, FileTimestamp C617.1), per FR-A04-603–604 — Verified 2026-11-13: 2026-11-13 docs/apps/particle-universe/privacy-and-credits.md, a required document checked by .autonomy/checks/A04-P06.experience-release.json; release-checks.json (manifest, tracking, licenses, usage) pass
- [X] T-A04-604 [US1] Prove FR-A04-602 for the sources: `run-check --name pu-no-network -- /bin/sh -c "! grep -rnE 'URLSession|import Network|CoreMotion|AVFoundation|CoreLocation|AdSupport|AppTrackingTransparency|NSUserTrackingUsage' Packages/ExperiencesCreative/ParticleUniverse/Core Packages/ExperiencesCreative/ParticleUniverse/Experience"` (exit 0 only when nothing is found); the built-app tracking, privacy and usage checks are T-A04-620 — Verified 2026-11-13: 2026-11-13 .autonomy/checks/A04-P06.pu-no-network.json (grep finds no network, sensor, tracking or advertising API in PU Core and Experience; exit 0)

## Phase 4: User Story 2 — A broken file or a failed draw never loses work (P1)

**Independent test**: fixtures load as specified; failure → failed → retry → running.

- [X] T-A04-605 [P] [US2] Commit library fixtures in `PU/ExperienceTests/Fixtures/Library/`: `scene-no-format.json` (wrapper without `format`), `scene-format-1.json`, `scene-format-2.json` (`format: 2`), `scene-damaged.json` (truncated), each with a fixed `id`; the test writes each as `scene-<its id lowercased>.json` — Verified 2026-11-13: 2026-11-13 four fixtures in PU/ExperienceTests/Fixtures/Library loaded by ParticleLibraryMigrationTests; .autonomy/checks/A04-P06.experiences-ios27.json and experiences-ios26.json (ExperiencesCreative on sim-27.2 and sim-26.5, TEST SUCCEEDED)
- [X] T-A04-606 [P] [US2] Write `PU/ExperienceTests/ParticleLibraryMigrationTests.swift` first (failing): the four fixtures copied into a temporary `ExperienceStorage` as `scene-<uuid>.json`; no-format and format-1 open with 100% of fields equal; format 2 counted in `newer`, kept, refused by `document(for:)`; damaged counted in `unreadable`, kept; save and rename write `"format":1`; a format-1 file decodes with the wrapper as it was before this phase (extra key ignored) — Verified 2026-11-13: 2026-11-13 .autonomy/checks/A04-P06.experiences-ios27.json and experiences-ios26.json (ExperiencesCreative on sim-27.2 and sim-26.5, TEST SUCCEEDED: 6 ParticleLibraryMigrationTests pass)
- [X] T-A04-607 [US2] Add `format` to the private `File` of `PU/Experience/ParticleLibrary.swift` ("absent = 1; written as 1"; `format > 1` counted in `newer`, never rewritten) with `///` documentation, until T-A04-606 passes — Verified 2026-11-13: 2026-11-13 .autonomy/checks/A04-P06.experiences-ios27.json and experiences-ios26.json (ExperiencesCreative on sim-27.2 and sim-26.5, TEST SUCCEEDED: ParticleLibrary format field; migration and existing ParticleLibraryTests pass)
- [X] T-A04-608 [P] [US2] Add the internal seam `failNextDraw` (throws `ParticleDrawError.injected` from `draw`, then clears) and an internal `brightnessCap` read to `PU/Experience/ParticlePresenter.swift` — Verified 2026-11-13: 2026-11-13 .autonomy/checks/A04-P06.experiences-ios27.json and experiences-ios26.json (ExperiencesCreative on sim-27.2 and sim-26.5, TEST SUCCEEDED: failNextDraw seam and brightnessCap used by ParticleRecoveryTests)
- [X] T-A04-609 [P] [US2] Write `PU/ExperienceTests/ParticleRecoveryTests.swift`: a hosted session with a saved scene, `failNextDraw` set, one frame → session `.failed` with a failure, library file bytes unchanged; `retry()` → running and frames draw; a session opened with `reduceFlashing: true` has `brightnessCap == 0.6` after a frame and `1` without it (FR-A04-612–613) — Verified 2026-11-13: 2026-11-13 .autonomy/checks/A04-P06.experiences-ios27.json and experiences-ios26.json (ExperiencesCreative on sim-27.2 and sim-26.5, TEST SUCCEEDED: testADrawingFailureFailsTheSessionAndKeepsSavedScenes and testReduceFlashingCapsBrightnessInTheSession pass)
- [X] T-A04-610 [US2] Run the package on sim-27.2 (`run-check --name experiences-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test`) — Verified 2026-11-13: 2026-11-13 .autonomy/checks/A04-P06.experiences-ios27.json (sim-27.2, TEST SUCCEEDED)
- [X] T-A04-611 [US2] Run the package on sim-26.5 (`run-check --name experiences-ios26 -- … --destination sim-26.5 --action test`) — Verified 2026-11-13: 2026-11-13 .autonomy/checks/A04-P06.experiences-ios26.json (sim-26.5, TEST SUCCEEDED, migration and recovery tests included)

## Phase 5: User Story 3 — The owner can build, check and archive the app (P2)

- [X] T-A04-612 [P] [US3] Write `docs/release/build-and-archive.md` for the one app: prerequisites (`verify_environment.py`, `xcodegen generate --spec project.yml`), unsigned tests and release checks (`release_check.py --only app-build-for-testing-ios27 …`, `--only app-release-build app-release-symbols app-privacy-manifest app-no-tracking app-licenses app-usage-descriptions`), and the owner steps marked `BLOCKED_OWNER_ACTION` (team and signing in `Configs/Signing.local.xcconfig`, Product › Archive, Organizer upload, App Store Connect record, privacy answers, pricing USD 1.99 non-consumable, review submission), per FR-A04-620 — Verified 2026-11-13: 2026-11-13 docs/release/build-and-archive.md; its agent-run steps pass in .autonomy/checks/A04-P06.release-checks.json; owner steps marked BLOCKED_OWNER_ACTION
- [ ] T-A04-613 [US3] BLOCKED_OWNER_ACTION: signing, archive upload and App Store Connect submission for the one app, per `docs/release/build-and-archive.md` §owner steps (never done by the agent)

## Phase 6: User Story 4 — The release record is complete and claims nothing unmeasured (P2)

- [X] T-A04-614 [P] [US4] Write `scripts/check_copy_claims.py` and `Configs/copy-claims-denylist.json` (schema 1: `patterns` [{id, regex, reason}], `words` [{word, reason}]) per contracts/scripts.md; handed to the lead as separate files — Verified 2026-11-13: 2026-11-13 .autonomy/checks/A04-P06.copy-claims.json (PASS on store text and interface strings) and A04-P06.script-tests.json (ExperienceReleaseAndCopyTests: denylisted word, measured number, allow marker, Swift identifiers)
- [X] T-A04-615 [P] [US4] Write `scripts/check_experience_release.py` (imports `checklist_problems` from `scripts/check_app_release.py`; config schema 1: `experience`, `requiredDocs`, `checklist`) per contracts/scripts.md — Verified 2026-11-13: 2026-11-13 .autonomy/checks/A04-P06.experience-release.json (PASS) and A04-P06.script-tests.json (pass, missing document, unknown status, empty evidence)
- [X] T-A04-616 [P] [US4] Write `docs/apps/particle-universe/release.json`, `release-checklist.md` (table Item | Area | Status | Evidence, statuses `verified` / `pending-campaign-ii` / `owner-action`), `store-listing.md` (store text input describing only tested features), `device-campaign.md` (pacing, detail steps under load, thermal behaviour, memory, accessibility audits — all pending), and links in `docs/apps/particle-universe/README.md` — Verified 2026-11-13: 2026-11-13 release.json, release-checklist.md (25 rows), store-listing.md, device-campaign.md, README links; .autonomy/checks/A04-P06.experience-release.json and copy-claims.json pass; cited UI test names verified by grep
- [X] T-A04-617 [US4] Add Particle Universe's device-only items to `docs/release/known-limitations.md`; add tests of both scripts (pass, missing document, unknown status, empty evidence, denylisted word, measured number, allow marker) to `scripts/test_scripts.py`; add steps `experience-release-a04` and `copy-claims-a04` to `scripts/release_check.py` (lead) — Verified 2026-11-13: 2026-11-13 known-limitations.md Particle Universe section; release_check steps experience-release-a04 and copy-claims-a04 (A04-P06.experience-release.json, copy-claims.json); ExperienceReleaseAndCopyTests in A04-P06.script-tests.json
- [X] T-A04-618 [US4] Run the experience checks (`run-check --name experience-release -- python3 scripts/check_experience_release.py --config docs/apps/particle-universe/release.json`; `run-check --name copy-claims -- python3 scripts/check_copy_claims.py --config Configs/copy-claims-denylist.json --text docs/apps/particle-universe/store-listing.md --swift PU/Experience/ParticleControls.swift PU/Experience/ParticlePresenter.swift`) — Verified 2026-11-13: 2026-11-13 .autonomy/checks/A04-P06.experience-release.json and .autonomy/checks/A04-P06.copy-claims.json (both PASS)

## Phase 7: Polish & verification

- [X] T-A04-619 Run the PU interface chunks on the iOS 27.2 phone simulator, one command each (`run-check --name ui-pu-j2 -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-ui-ios27-j2`; `ui-pu-j3` `--only app-ui-ios27-j3`; `ui-pu-j4` `--only app-ui-ios27-j4`), including `testReduceMotionStartsPaused` — Verified 2026-11-13: 2026-11-13 .autonomy/checks/A04-P06.ui-pu-j2-r2.json, ui-pu-j3.json, ui-pu-j4.json (iOS 27.2 phone simulator, all pass incl. testReduceMotionStartsPaused); the first j2 run failed on testPauseStepAndNewSeed (12 steps cancelled out at steady state), test now steps until the count moves, at most 60 steps
- [X] T-A04-620 Run the release build checks (`run-check --name release-checks -- python3 scripts/release_check.py --only app-release-build app-release-symbols app-privacy-manifest app-no-tracking app-licenses app-usage-descriptions`) — Verified 2026-11-13: 2026-11-13 .autonomy/checks/A04-P06.release-checks.json (6/6 steps pass: Release build, symbols, privacy manifest, no tracking, licenses, usage strings)
- [X] T-A04-621 Run the script tests (`run-check --name script-tests -- python3 scripts/test_scripts.py`) and the dependency audit (`run-check --name dependency-audit -- python3 scripts/audit_showcase_dependencies.py --target VisualCore --sources Apps/VisualCore`) — Verified 2026-11-13: 2026-11-13 .autonomy/checks/A04-P06.script-tests.json (528 tests OK) and A04-P06.dependency-audit.json (exit 0)
- [ ] T-A04-622 {device} In the device campaign (after ImplementationLock-100): the measurements and audits of `docs/apps/particle-universe/device-campaign.md` on D1 → D2 → D3
- [ ] T-A04-623 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A04-P06

## Dependencies

Setup → Foundational → US1 ∥ US2 ∥ US3 ∥ US4 → Polish. Within US2: T-A04-605/606 before 607; 608/609 together; 610/611
last. Within US4: 614/615/616 before 617 before 618.

## Parallel examples

Agents (separate files): A — T-A04-605/606/607; B — T-A04-608/609; C — T-A04-614/615; D — T-A04-603/612/616.
Lead: T-A04-602, T-A04-617, every run, tick and commit.

## Implementation strategy

MVP is US2 (migration and recovery, P1) with US1's note; then US4's checks and documents; US3's instructions last.

## Phase 8: Convergence

Appended by `/speckit-converge` (T-A04-623, round 1, 2026-11-13).

- [X] T-A04-624 Document the optional `copyCheck` ({text, swift}) of the experience release config and the release-check steps `experience-release-a04` and `copy-claims-a04` in `specs/038-pu-p06-release/data-model.md` and `contracts/scripts.md` per plan: data model and contracts (partial) — Verified 2026-11-13: 2026-11-13 data-model.md and contracts/scripts.md describe copyCheck and the steps; release_check.py --list shows experience-release-a04 and copy-claims-a04, both passing in .autonomy/checks/A04-P06.experience-release-r2.json and copy-claims.json
