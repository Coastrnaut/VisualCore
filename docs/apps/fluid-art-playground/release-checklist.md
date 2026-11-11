# Fluid Art Playground — release checklist and artifact inventory

Release candidate 1.0.0 (1), bundle `dev.visualcore.FluidArtPlayground` (approved placeholder). Statuses:
- `verified`: the evidence is in the ledger;
- `pending-campaign-ii`: needs D1–D3 after the implementation lock;
- `owner-action`: the owner does it; exact steps are in [build-and-archive.md](build-and-archive.md).

`scripts/check_app_release.py` rejects any row without a known status and evidence or steps.

| Area | Item | Status | Evidence or steps |
|---|---|---|---|
| Privacy | Privacy manifest equals the Release-build scan (2 categories, no tracking, no collection) | verified | `A02-P06/t605-privacy-scan` PASS; [privacy-and-credits.md](privacy-and-credits.md) |
| Privacy | Only the Photos add-only usage string, with its UI path | verified | `PrivacyTests.testOnlyPhotosAddUsageStringIsDeclared` (`A02-P06/t603-app-ios27`, `t603-app-ios26`); `check_app_release.py` usage item |
| Privacy | Nothing persisted: 0 defaults keys, no documents or Library files of the app | verified | `PrivacyTests.testSessionStoresNothing` (`A02-P06/t603-app-ios27`, `t603-app-ios26`) |
| Privacy | Privacy policy hosted at a public URL | owner-action | Host the text in privacy-and-credits.md and enter the URL in App Store Connect |
| Privacy | App Privacy questionnaire: Data Not Collected | owner-action | App Store Connect → App Privacy |
| Assets | App icon 1024, the app's own render, opaque | verified | `A02-P06/t604-icon-ios27`, `t604-icon-ios26` (provenance mean 0.0) |
| Assets | Version 1.0.0 (1) and the export-compliance key | verified | `project.yml`; `check_app_release.py` |
| Credits | License texts bundled and shown (Acknowledgements) | verified | `A02-P06/t606-ui-ios27`, `t606-ui-ios26`; `bundle_licenses.py`; `A02-P06/t606-licenses` |
| Credits | No ProjectM or LGPL code linked | verified | Dependency audit build phase (FR-A02-006); `check_dependencies.py` R1–R5 |
| Accessibility | Audit at default and largest text sizes (home, playground, paused playground, Adjust, capture, Acknowledgements); documented exclusions only for canvas artwork and navigation-bar chrome | verified | `A02-P06/t606-ui-ios27`, `t606-ui-ios26` |
| Tests | Full app suites, enumeration-guarded, both runtimes | verified | `A02-P06/t602-app-ios27`, `t602-app-ios26` (79/79 each); final runs in T-A02-610 |
| Tests | Numerical fixtures 1–5, stress (600 frames per storage) and determinism | verified | `A02-P05` seal (`conv1-app-ios27`, `conv1-app-ios26`, 76/76 each) |
| Data | No stored data, so no migration; schema version 1 documented as the future starting point | verified | `PrivacyTests.testSessionStoresNothing`; [privacy-and-credits.md](privacy-and-credits.md) |
| Data | Crash recovery: stale captures removed at launch; files outside untouched | verified | `CrashRecoveryTests` (`A02-P06/t602-app-ios27`, `t602-app-ios26`) |
| Store | Listing text with claim → test traceability | verified | [store-listing.md](store-listing.md) |
| Store | Store name and final bundle ID | owner-action | Decide before the first upload; the bundle ID is permanent |
| Store | Screenshots at the required sizes | owner-action | Capture from simulators at App Store sizes when preparing the submission |
| Build | Unsigned Release build for generic iOS | verified | `A02-P06/t605-release-build-3` |
| Build | 0 automation symbols and trigger strings in Release | verified | `A02-P06/t605-release-symbols` |
| Build | Signing team, archive and upload | owner-action | build-and-archive.md §5 steps 1–3 |
| Store | App Store Connect record and submission | owner-action | build-and-archive.md §5 step 4 |
| Device | Automation runner (smoke, launch, lifecycle) with seed, post-run field check and digest | verified | `A02-P05/t511-rehearse-smoke`, `-launch`, `-lifecycle` (simulator rehearsal only, not device evidence); [device-campaign.md](device-campaign.md) |
| Device | D1 iPhone 15 iOS 27.0.1: install, smoke, launch, lifecycle, rendering, capture, accessibility | pending-campaign-ii | `scripts/run_device_campaign.py` after IMPLEMENTATION-LOCK |
| Device | D2 iPad Pro M5 iPadOS 27.2: same rows | pending-campaign-ii | Same, after D1 |
| Device | D3 iPad A16 iPadOS 26.5 (never updated): same rows | pending-campaign-ii | Same, after D2 |
| Performance | Frame pacing, launch time, thermal behavior and GPU memory on devices | pending-campaign-ii | No number is claimed before device evidence |
