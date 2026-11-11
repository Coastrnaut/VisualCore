---

description: "Task list for feature 024 — Fluid Art Playground Phase 06 final verification, privacy, packaging and release (ledger gate A02-P06)"
---

# Tasks: Fluid Art Playground — Phase 06 Final verification, privacy, packaging and release

**Input**: `/specs/024-fap-p06-release/` (spec with 5 clarifications and the checklist amendments, plan, research
R1–R5, data model, contract, quickstart).

**Tests** are required:
- host tests for VisualCore;
- app unit and UI tests on iOS 27.2 and 26.5 with the enumeration guard (run `xcodegen generate` after adding files);
- the unsigned Release build with the per-app release step;
- the ProjectM regression;
- an A01 build.

IDs are `T-A02-6##`, with one commit per task (`scripts/tick_task.py`). Commands run through
`run-check --stage A02-P06`. Checkpoints: `validate_docs`, `check_dependencies`, `check_public_api`,
`check_compliance`, `check_licenses` and `check_app_isolation` (allowing only `NSPhotoLibraryAddUsageDescription`).

## Phase 1: Foundational — VisualCore TemporaryFolder (blocks US3)

- [X] T-A02-601 Write `TemporaryFolderTests` first — Verified 2026-11-11: — Verified 2026-11-11: VisualCorePersistence.TemporaryFolder (strict folder names -> Temporary, makeFileURL unique sanitized names inside the folder, fileCount regular files, removeAll counts and ignores errors), documented, README and baseline (+6 lines); TemporaryFolderTests 6/6 in run-check A02-P06/t601-host-visualcore-2 (first run failed on a URL trailing-slash comparison in the test, fixed); t601-checks 4/4; ProjectM regression t601-reference-a 3/3 + t601-reference-b 4/4; A01 build-for-testing t601-a01-build succeeded
  (`Packages/VisualCore/Tests/VisualCorePersistenceTests/TemporaryFolderTests.swift`, at least 6 tests per the
  contract). Then add `Packages/VisualCore/Sources/VisualCorePersistence/TemporaryFolder.swift`:
  - `init(name:base:)`: "name is a single path component; empty, `.`, `..` or one containing `/` → `Temporary`";
  - `url`;
  - `makeFileURL(prefix:extension:)`, which creates the folder and returns a unique UUID name;
  - `fileCount`;
  - `removeAll() -> Int`, which ignores errors and touches nothing outside `url`.

  Add docs, the README module note and the baseline update. Run `swift test --package-path Packages/VisualCore`, then
  `check_public_api.py` and `check_dependencies.py`. Run the ProjectM regression 3/3 + 4/4 and the A01 build
  (FR-A02-605).

## Phase 2: User Story 3 — crash recovery and no persistence (P2, foundational for docs)

- [X] T-A02-602 [US3] Capture and launch cleanup: — Verified 2026-11-11: — Verified 2026-11-11: CaptureModel writes through TemporaryFolder(name: "Captures") (static folder), FluidArtPlaygroundApp.init empties it before any scene, FAP depends on VisualCorePersistence; CrashRecoveryTests 3 (3 stale captures + stray file -> 0 via the App init, outside file untouched; missing folder 0 and unreadable folder no crash; captures in tmp/Captures, only the latest, removed on close); run-check A02-P06/t602-app-ios27 and t602-app-ios26 TEST SUCCEEDED, enumeration 79/79 each
  - `Apps/FluidArtPlayground/App/CaptureModel.swift`: write through `TemporaryFolder(name: "Captures")`
    (`static let folder`).
  - `Apps/FluidArtPlayground/App/FluidArtPlaygroundApp.swift`: `init()` calls `CaptureModel.folder.removeAll()`
    before any scene exists.
  - `project.yml`: the FAP target depends on `VisualCorePersistence`.
  - Add `Apps/FluidArtPlayground/Tests/Unit/CrashRecoveryTests.swift`:
    - 3 stale captures and 1 file outside the folder → cleanup leaves 0 inside and the outside file untouched;
    - a non-capture file inside the app-owned folder is removed too;
    - an unreadable folder (permissions 000) → no crash, and the result is reported;
    - a missing folder → 0;
    - a capture lands in `tmp/Captures`, only the latest exists, and close removes it.

  Run on 27.2 and 26.5 (FR-A02-605, SC-A02-603).
- [X] T-A02-603 [US1] [US3] Add `Apps/FluidArtPlayground/Tests/Unit/PrivacyTests.swift`: — Verified 2026-11-11: — Verified 2026-11-11: PrivacyTests 2: exactly NSPhotoLibraryAddUsageDescription with the documented text; a session (paint, tune, pause, detail, capture, close) leaves 0 defaults keys (0 system), Documents only the Debug-only rehearsal report on 27.2 (listed, excluded) and empty on 26.5, Library only Caches/Preferences/Saved Application State/SplashBoard, capture folder 0; run-check A02-P06/t603-app-ios27 and t603-app-ios26 (PrivacyTests) TEST SUCCEEDED; full-suite runs follow in T-A02-610
  - the built app's Info.plist has exactly one `NS*UsageDescription`, `NSPhotoLibraryAddUsageDescription`, with the
    documented text;
  - after a session that opens the playground, paints, captures and closes, the app's defaults domain has 0 keys
    written by the app (`UserDefaults.standard.persistentDomain(forName: bundleID)` minus Apple/system-prefixed keys,
    which are listed);
  - Documents and Library hold no app files (system caches excluded and listed).

  Run on 27.2 and 26.5 (FR-A02-602, FR-A02-606, SC-A02-601, SC-A02-603).

## Phase 3: User Story 2 — release package (P1)

- [X] T-A02-604 [US2] App icon and version: — Verified 2026-11-11: — Verified 2026-11-11: icon-1024.png = the app's own render (TestMode gentle setting: default force/cap, 3 pointers at 500 pt/s, seed 3, Glowing dye, 90 frames, offscreen 1024^2, opaque; the first write with the stress settings was washed out white and was replaced — t604-icon-write then t604-icon-write-2; viewed); IconRenderTests provenance mean 0.0 max 0 on iOS 27.2 and 26.5 (run-check A02-P06/t604-icon-ios27, t604-icon-ios26, with DeterminismTests still green); project.yml: Resources, ASSETCATALOG_COMPILER_APPICON_NAME AppIcon, 1.0.0 (1); the built app has CFBundleIconName AppIcon and Assets.car
  - Add `Apps/FluidArtPlayground/Tests/Unit/IconRenderTests.swift`: test mode, seed 3, palette `glow`, 90 frames,
    hosted at 390×844, then paused, `renderOffscreen(1024, 1024)` and `StillImageEncoder.pngData`. With
    `FAP_WRITE_ICON=1` (`TEST_RUNNER_FAP_WRITE_ICON`) it writes the PNG; otherwise it compares with the committed
    icon (mean ≤ 1/255).
  - Commit `Apps/FluidArtPlayground/Resources/Assets.xcassets/{Contents.json, AppIcon.appiconset/{Contents.json,
    icon-1024.png}}` and view the PNG (1024×1024, opaque).
  - `project.yml`: the Resources folder, `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon`,
    `CFBundleShortVersionString` 1.0.0 and `CFBundleVersion` 1.

  Run on 27.2 and 26.5 (FR-A02-603, SC-A02-602).
- [ ] T-A02-605 [US1] Build Release for generic iOS (unsigned) and run `check_privacy_manifest.py --app` to read
  the required-reason categories. Write `Apps/FluidArtPlayground/Resources/PrivacyInfo.xcprivacy` with:
  - tracking false, no domains, no collected data;
  - exactly the found categories, with reasons (ANGLE FileTimestamp C617.1 and SystemBootTime 35F9.1 as in A01's
    source check; app frame timing 35F9.1).

  Rebuild, then: scan 0 undeclared and 0 unused; `check_release_symbols.py` 0 (FR-A02-601, SC-A02-601).
- [ ] T-A02-606 [US2] Acknowledgements:
  - `project.yml`: the FAP `bundle_licenses.py` post-build phase, as in A01.
  - The home link `fap.home.acknowledgements` opens `AcknowledgementsView(identifierPrefix: "fap.acknowledgements")`.
  - Add `Apps/FluidArtPlayground/Tests/UI/AcknowledgementsUITests.swift`: the screen opens and lists ANGLE,
    VisualCore and the app.
  - `AccessibilityAuditUITests` gains the screen (default size and XXXL).
  - The missing-bundle fallback text is covered by VisualCoreUI's existing `AcknowledgementsViewTests` (analyze G2).

  Run on 27.2 and 26.5, plus `check_licenses.py` (FR-A02-604, SC-A02-604).
- [ ] T-A02-607 [US2] [US4] Write `docs/apps/fluid-art-playground/`:
  - `release.json`: scheme, bundle, 1.0.0 (1), the allowed usage string, required docs, checklist, and the
    privacyManifest, icon and licenses flags.
  - `privacy-and-credits.md`: stored data (none, plus the temporary capture folder); the permission with its exact
    UI path; the manifest categories with their code sites; credits and licenses; icon provenance; the Debug-only
    automation-report note; privacy-policy text for the owner.
  - `store-listing.md`: draft text with a claim → test table, per clarification 5.
  - `build-and-archive.md`: exact unsigned commands, the automation rehearsal, and owner-only signing, archive,
    upload and App Store Connect steps.
  - `release-checklist.md`: every row `verified` with ledger evidence, `pending-campaign-ii` (D1/D2/D3,
    performance) or `owner-action` with steps.

  Then run `release_check.py --only app-release-fluid-art-playground` (Release build, symbols, privacy, release
  check) and isolation with the built app (FR-A02-607, FR-A02-608, SC-A02-602, SC-A02-605).

## Phase 4: User Story 5 — no unsupported promises (P3)

- [ ] T-A02-608 [US5] Review every user-visible string in `Apps/FluidArtPlayground/App/*.swift`, the store listing
  and the README's A02 section against the implemented features. Remove any promise, "later phases" or performance
  wording. Expose the home copy as `HomeView.summary` (a static constant). Add `Apps/FluidArtPlayground/Tests/Unit/CopyTests.swift`,
  which scans `HomeView.summary` and `docs/apps/fluid-art-playground/store-listing.md` (read through `#filePath`;
  the simulator shares the host file system) for banned words ("coming soon", "later phase", "fps", "frames per
  second", "physically accurate", "battery"), and checks that each store claim row names an existing test. Run on
  27.2 and 26.5 (FR-A02-609; analyze U1).

## Phase 5: Polish and cross-cutting

- [ ] T-A02-609 Contract and notes:
  - `visualcore-contract.json`: gate A02-P06, `TemporaryFolder` in the inventory, a reuse-debt note "A01
    LaunchCleanup → TemporaryFolder (owner: next A01 change)", and a decision reason; render it.
  - Regression baseline (ProjectM rerun after T-A02-601).
  - Simulator lessons.

  Run the fast checks with `check_app_contract.py --render` (FR-A02-610).
- [ ] T-A02-610 Final verification:
  - the full app suites on iOS 27.2 and 26.5 with the guard;
  - `release_check.py --only app-release-fluid-art-playground`;
  - the fast checks;
  - update the release checklist's test rows with these run names (FR-A02-610, SC-A02-604, SC-A02-606).

## Analyze remediation (2026-11-11, applied under CLAUDE.md §2)

- U1: the CopyTests file and how it reads its inputs.
- G1: crash-recovery edge cases.
- G2: cites the existing VisualCoreUI tests.
- D1: the order of T-A02-604 and T-A02-605.

## Dependencies

- T-A02-601 blocks T-A02-602.
- T-A02-602 blocks T-A02-603.
- T-A02-604 runs before T-A02-605, so the scanned Release build includes the asset catalog (analyze D1).
- T-A02-604, T-A02-605 and T-A02-606 block T-A02-607.
- T-A02-607 blocks T-A02-608 and T-A02-610.
- T-A02-609 runs before T-A02-610.

## Parallel opportunities

- T-A02-603 and T-A02-604 touch different test files.
- T-A02-605's Release build can follow T-A02-604 directly.

## Implementation strategy

1. VisualCore helper and regression.
2. Recovery and privacy facts.
3. Icon, manifest and Acknowledgements.
4. Docs and the release step.
5. Copy review.
6. Final verification.

Review checkpoints: after T-A02-601 (API and regression), T-A02-605 (manifest equals scan) and T-A02-607 (release
step green).
