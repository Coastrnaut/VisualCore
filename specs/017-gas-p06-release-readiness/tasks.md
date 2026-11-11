---

description: "Task list for feature 017 — Generative Art Studio Phase 06 release readiness (ledger gate A01-P06)"
---

# Tasks: Generative Art Studio — Phase 06 Final verification, privacy, packaging and release

**Input**: `/specs/017-gas-p06-release-readiness/`. **Tests** are required:
- script unit tests with failing fixtures;
- Core host fixture tests;
- hosted app tests;
- automation rehearsal on both simulator runtimes;
- Release-build scans;
- enumeration-guarded full suites;
- the reference regression.

IDs are `T-A01-6##`, with one commit and push per task (`scripts/tick_task.py`). No physical device, signing change
or App Store Connect action. Owner steps are written down, never performed.

## Phase 1: Foundational — shared release tooling (US1, US2; blocks app work)

- [X] T-A01-601 [US1] Add `scripts/check_privacy_manifest.py`: — Verified 2026-11-11: scripts/check_privacy_manifest.py: TABLE of required-reason categories (UserDefaults, FileTimestamp, SystemBootTime, DiskSpace, ActiveKeyboards) matched on nm -u symbols and strings -a of the main executable, every embedded framework and every loose .dylib (Debug builds put app code in <App>.debug.dylib; found during the real-binary check); compare() reports undeclared/unused categories and violations (tracking, domains, collected data, empty reasons); exit 0/1/2. PrivacyManifestTests 3/3 in test_scripts.py (per-category detection incl. string-only evidence, undeclared/unused/violations, bad input exit 2). Real-binary check on the GAS Debug build: UserDefaults (_OBJC_CLASS_$_NSUserDefaults), FileTimestamp (_stat), SystemBootTime (_CACurrentMediaTime/_mach_absolute_time). run-check A01-P06/t601-script-tests 58/58 and t601-script-tests-a2 58/58 after the dylib addition
  - `scan(symbols, strings) -> categories` from a table (UserDefaults, FileTimestamp, SystemBootTime, DiskSpace,
    ActiveKeyboards) per research R1/R2;
  - `compare(detected, manifest)` → undeclared, unused and violations (tracking true, domains or collected types
    present);
  - the CLI `--app X.app [--json out]` collects `nm -u` and `strings -a` from the main executable and every
    `Frameworks/*.framework` binary, and reads `PrivacyInfo.xcprivacy`;
  - exit 0, 1 or 2 per contracts/api.md.

  Add `PrivacyManifestTests` to `scripts/test_scripts.py`: detection per category, undeclared, unused, the tracking
  violation and bad input (exit 2). Run `test_scripts.py`.
- [X] T-A01-602 [US2] Add `scripts/check_app_release.py --app X.app --config docs/apps/<slug>/release.json`, checking — Verified 2026-11-11: scripts/check_app_release.py: bundle id, version/build, ITSAppUsesNonExemptEncryption key, NS*UsageDescription keys exactly the allowed set and non-empty, PrivacyInfo.xcprivacy in bundle, compiled icon (CFBundleIconName/CFBundleIcons + Assets.car), required docs, checklist rows with status in {verified, pending-campaign-ii, owner-action} and non-empty evidence; exit 0/1/2. release_check.py app_release_steps(): one app-release-<slug> step per docs/apps/*/release.json (unsigned generic-iOS Release build → check_release_symbols → check_privacy_manifest → check_app_release); release.json gains a scheme field (data-model updated). AppReleaseTests 3/3 (pass + usage/version/encryption/icon/manifest failures; checklist status/evidence rules; bad input exit 2). run-check A01-P06/t602-script-tests 61/61 OK
  bundle ID, version and build, the `ITSAppUsesNonExemptEncryption` key, "NS*UsageDescription keys ⊆ allowed (and
  every allowed key present)", `PrivacyInfo.xcprivacy` in the bundle, a compiled icon (`CFBundleIcons` or
  `CFBundleIconName` plus `Assets.car`), required docs, and that every checklist row has status ∈ {verified,
  pending-campaign-ii, owner-action} with non-empty evidence or steps. Add `AppReleaseTests` to `test_scripts.py`
  with a synthetic `.app` folder (pass and each failure). Add `release_check.py` steps `app-release-<slug>` for every
  `docs/apps/*/release.json` (build Release generic iOS unsigned, then check_release_symbols, check_privacy_manifest
  and check_app_release).
- [X] T-A01-603 [US4] Add `Packages/VisualCoreRendering/Sources/VisualCoreAutomation/AutomationView.swift` (`#if DEBUG — Verified 2026-11-11: VisualCoreAutomation/AutomationView.swift (#if DEBUG || VISUALCORE_AUTOMATION; AutomationView(mode:bundleID:makeScene:configure:outputDirectory:terminate:) hosts any RenderScene full screen, configures with the display scale, runs the mode after the first layout, writes renderer-unavailable when no renderer) + AutomationViewTests (smoke in a window → one report, mode smoke, terminate [0], configure got the scale); Showcase AutomationRootView now uses it (its private canvas removed); API baseline 881 (0 undocumented); VisualCoreRendering README automation paragraph. run-check A01-P06/t603-rendering-ios27/ios26 TEST SUCCEEDED; t603-showcase-a showcase-ios27 + ios26 pass; t603-showcase-release: Release build, 0 automation symbols, ProjectM independence pass; t603-fast 5/5; reference regression t603-reference-a 3/3 + b 4/4 = 7/7
  || VISUALCORE_AUTOMATION`; `AutomationView(mode:bundleID:makeScene:configure:)`; renderer-unavailable fallback
  report) with a VisualCoreAutomationTests case. Make `Showcase/App/ShowcaseAutomation.swift` use it. Update the API
  baseline and the VisualCoreRendering README. Run the rendering package tests and the Showcase suite on 27.2 and
  26.5, R1–R5 and the reference regression (7 steps).

## Phase 2: US1 + US2 — Privacy, icon, metadata, documents (P1) 🎯

- [X] T-A01-604 [US2] Add the app icon: — Verified 2026-11-11: App icon: Resources/Assets.xcassets/AppIcon.appiconset (single 1024 universal) with icon-1024.png = the app's own render of Gradient Noise 'Dusk' at t = 12 s through ExportRunner.render + StillImageEncoder (written once with TEST_RUNNER_GAS_WRITE_ICON=1 after a black bootstrap PNG; viewed: 1024×1024 RGB, no alpha); Tests/Unit/IconRenderTests.swift checks the committed icon against a fresh render. project.yml: Resources folder, ASSETCATALOG_COMPILER_APPICON_NAME AppIcon, CFBundleShortVersionString 1.0.0, CFBundleVersion 1. Built app has CFBundleIcons/CFBundleIconName AppIcon + Assets.car and version 1.0.0. run-check A01-P06/t604-icon-ios27 + ios26: provenance mean 0.0 max 0, passed (FR-A01-604)
  - `Apps/GenerativeArtStudio/Tests/Unit/IconRenderTests.swift` renders "Dusk" at t = 12 s at 1024² through
    `ExportRunner.render`; with `GAS_WRITE_ICON=1` it writes the PNG, otherwise it compares (mean ≤ 1/255);
  - commit `Apps/GenerativeArtStudio/Resources/Assets.xcassets/AppIcon.appiconset/{Contents.json,icon-1024.png}`;
  - `project.yml`: add the asset catalog and `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon`; set
    `CFBundleShortVersionString` 1.0.0 and `CFBundleVersion` 1.
- [X] T-A01-605 [US1] Add `Apps/GenerativeArtStudio/Resources/PrivacyInfo.xcprivacy` (tracking false, no domains, no — Verified 2026-11-11: Resources/PrivacyInfo.xcprivacy: NSPrivacyTracking false, no tracking domains, no collected data types; UserDefaults CA92.1 (the app's own settings via @AppStorage, gas.a11y.*), FileTimestamp C617.1 (stat in ANGLE's libEGL; read-only source check of system_utils_posix.cpp: Linux-only path, failed-dlopen diagnostic and IsDirectory on bundle/container paths, no timestamp reads), SystemBootTime 35F9.1 (CACurrentMediaTime/systemUptime frame timing in the app, mach_absolute_time in libGLESv2). The scanner now also treats SwiftUI AppStorage symbols as UserDefaults use (the Release binary has no direct NSUserDefaults reference) + test. run-check A01-P06/t605-release-build-a2 (unsigned generic iOS Release) BUILD SUCCEEDED with the manifest in the bundle; t605-privacy-scan PASS 3 detected = 3 declared in 3 binaries, 0 undeclared, 0 unused, 0 violations (SC-A01-601); t605-release-symbols 0 automation symbols, 0 trigger strings; t605-script-tests 61/61
  collected data; the accessed API categories and reasons that the T-A01-601 scan of the Release build actually
  reports, per the Clarifications reasons; no guessing) and add it to the app resources in `project.yml`. Build
  Release generic iOS unsigned and run `check_privacy_manifest.py` (0 undeclared, 0 unused) and
  `check_release_symbols.py`.
- [ ] T-A01-606 [US2] Write `docs/apps/generative-art-studio/`:
  - `privacy-and-credits.md`: data stored, permissions with UI paths, the manifest categories with code sites,
    third-party components with licenses from `docs/legal`, icon provenance;
  - `store-listing.md`: draft name, subtitle and description, with a claim → test table;
  - `release-checklist.md`: a table of every release item with status and evidence or owner steps, including
    signing, archive upload, App Store Connect record, privacy-policy URL hosting, screenshots and the campaign II
    device rows;
  - `build-and-archive.md`: exact commands; owner-only signing and upload steps;
  - `release.json`.

  Run `check_app_release.py` on the Release build.

## Phase 3: US3 — Saved work survives updates and crashes (P1)

- [ ] T-A01-607 [US3] Add `Apps/GenerativeArtStudio/Core/Tests/GenerativeArtStudioCoreTests/Fixtures/library-v1/`
  (4 envelope files, one per family, kind `dev.visualcore.gas.composition`, schemaVersion 1, written by the current
  `CompositionLibrary` through a generator test that runs only with `GAS_WRITE_FIXTURE=1`, with fixed ids, names and
  times; analyze U1) and `LibraryMigrationFixtureTests.swift`: 4 entries, 0 problems, documents equal to the
  expected compositions, files byte-identical after load. Add `App/LaunchCleanup.swift` (removes only `tmp/Exports`),
  called from `GenerativeArtStudioApp.init`, and `Tests/Unit/CrashRecoveryTests.swift`:
  - stale export and store temporary files are removed by cleanup and load, and saved files are untouched;
  - the fixture compositions render identically to their expected documents (max 0);
  - a library with an interrupted save (a temporary file left beside the old file) loads the old version with 0
    problems.

## Phase 4: US4 — Device tests ready; build reproducible (P2)

- [ ] T-A01-608 [US4] Add `Apps/GenerativeArtStudio/App/AppAutomation.swift` (`#if DEBUG || VISUALCORE_AUTOMATION`;
  hosts the default Gradient Noise composition through `AutomationView`) and route `GenerativeArtStudioApp` to it
  when `AutomationRunner.requestedMode()` is set. Add the VisualCoreAutomation product to the app in `project.yml`.
  Rehearse smoke, launch and lifecycle with `run_automation_sim.py` on 27.2 and 26.5 (6 reports). Build Release and
  check 0 automation symbols and trigger strings with `check_release_symbols.py`.

## Phase 5: Polish

- [ ] T-A01-609 Run `release_check.py --only app-release-generative-art-studio` and the fast steps, the full app
  suites on both runtimes (enumeration-guarded, including `AccessibilityAuditUITests` as the manual's Phase 06
  accessibility re-verification; analyze C1), the contract check and the documented API. Update the
  `release-checklist.md` evidence column and `docs/release/support-matrix.md` (Generative Art Studio: release
  candidate on simulators, devices pending campaign II) (FR-A01-611, SC-A01-606).

## Dependencies

T-A01-601 → T-A01-605; T-A01-602 → T-A01-606; T-A01-603 → T-A01-608; T-A01-604 → T-A01-606; T-A01-607 needs
nothing new; T-A01-609 runs last.

## Implementation strategy

Shared tooling and the automation view first (Principle II), then the app artifacts each check needs, then data
safety, automation, and the final release run.

## Analyze remediation (2026-11-11)

Applied autonomously (CLAUDE.md §2): U1 → T-A01-607 fixture generator; C1 → T-A01-609 names the accessibility audit. 0
critical issues.
