# Fractal Explorer — release checklist and artifact inventory

Release candidate 1.0.0 (1), bundle `dev.visualcore.FractalExplorer` (approved placeholder). Statuses:
- `verified`: the evidence is in the ledger;
- `pending-campaign-ii`: needs D1–D3 after the implementation lock;
- `owner-action`: the owner does it; exact steps are in [build-and-archive.md](build-and-archive.md) (recorded as
  `BLOCKED_OWNER_ACTION` until done).

`scripts/check_app_release.py` rejects any row without a known status and evidence or steps.

| Area | Item | Status | Evidence or steps |
|---|---|---|---|
| Privacy | Privacy manifest equals the Release-build scan (2 categories, no tracking, no collection) | verified | `A03-P06/t601-privacy-scan` PASS; [privacy-and-credits.md](privacy-and-credits.md) |
| Privacy | Only the Photos add-only usage string, with its UI path; export-compliance key false | verified | `PrivacyTests.testOnlyPhotosAddUsageStringIsDeclared` (`A03-P06/t601-app-ios27-2`, `t601-app-ios26-2`); `check_app_release.py` |
| Privacy | A session stores only the saved bookmark: 0 defaults keys, no documents, no capture left | verified | `PrivacyTests.testSessionStoresOnlyTheSavedBookmark` (`A03-P06/t601-app-ios27-2`, `t601-app-ios26-2`) |
| Privacy | No networking in app code or the built app | verified | `A03-P06/t602-isolation` |
| Privacy | Privacy policy hosted at a public URL | owner-action | Host the text in privacy-and-credits.md and enter the URL in App Store Connect |
| Privacy | App Privacy questionnaire: Data Not Collected | owner-action | App Store Connect → App Privacy |
| Assets | App icon 1024, the app's own render, opaque | verified | `IconRenderTests` (`A03-P06/t603-app-ios27`, `t603-app-ios26`; provenance mean 0.0) |
| Assets | Version 1.0.0 (1) | verified | `project.yml`; `check_app_release.py` |
| Credits | License texts bundled and shown (Acknowledgements) | verified | `AcknowledgementsUITests` (`A03-P06/t604-app-ios27`, `t604-app-ios26`); `bundle_licenses.py` |
| Credits | No ProjectM or LGPL code linked | verified | Dependency audit build phase (FR-A03-006); `check_dependencies.py` R1–R5 |
| Accessibility | Audits at default and largest text sizes (home, Acknowledgements, explorer in both modes, Go to and bookmark sheets, cost and capture, tours, precision banner); documented exclusions for canvas artwork, navigation-bar chrome and text cut by the screen edges | verified | `AccessibilityAuditUITests` (`A03-P06/t604-app-ios27`, `t604-app-ios26`) |
| Tests | Full app suites, enumeration-guarded, both runtimes | verified | `A03-P06/t607-app-all-ios27`, `t607-app-all-ios26` |
| Tests | GPU vs CPU agreement, gestures, precision clamp, bookmark reproduction, capture and tours | verified | Features 027–030 seals (A03-P02…P05) |
| Data | Bookmark schema 1 frozen by a committed fixture; newer files reported and left | verified | `MigrationTests` (`A03-P06/t605-app-ios27`, `t605-app-ios26`) |
| Data | Crash recovery: stale captures removed at launch; interrupted bookmark writes cleaned; other files untouched | verified | `CrashRecoveryTests` (`A03-P06/t605-app-ios27`, `t605-app-ios26`) |
| Store | Listing text with claim → test traceability; no unsupported claims | verified | [store-listing.md](store-listing.md); `CopyTests` |
| Store | Store name, keywords, support URL, EULA, age rating and the final bundle ID | owner-action | Decide before the first upload; the bundle ID is permanent |
| Store | Screenshots at the required sizes | owner-action | Capture from simulators at App Store sizes when preparing the submission |
| Build | Unsigned Release build for generic iOS | verified | `A03-P06/t601-release-build-2`; `app-release-fractal-explorer` |
| Build | 0 automation symbols and trigger strings in Release | verified | `A03-P05/t507-release-symbols`; `app-release-fractal-explorer` |
| Build | Signing team, archive and upload | owner-action | build-and-archive.md §5 steps 1–3 |
| Store | App Store Connect record and submission | owner-action | build-and-archive.md §5 step 4 |
| Device | Automation runner (smoke, launch, lifecycle, precision, tour) | verified | `A03-P05/t507-rehearse-*` (simulator rehearsal only, not device evidence); [device-campaign.md](device-campaign.md) |
| Device | D1 iPhone 15 iOS 27.0.1: install, smoke, launch, lifecycle, precision ladder, tours and capture, VoiceOver pass, container and defaults privacy | pending-campaign-ii | `scripts/run_device_campaign.py` after IMPLEMENTATION-LOCK |
| Device | D2 iPad Pro M5 iPadOS 27.2: same rows | pending-campaign-ii | Same, after D1 |
| Device | D3 iPad A16 iPadOS 26.5 (never updated): same rows | pending-campaign-ii | Same, after D2 |
| Performance | Frame pacing, launch time, thermal behavior, GPU memory and the precision limit on devices | pending-campaign-ii | No number is claimed before device evidence |
