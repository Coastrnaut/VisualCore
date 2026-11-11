# Generative Art Studio — release checklist and artifact inventory

Release candidate 1.0.0 (1), bundle `dev.visualcore.GenerativeArtStudio` (approved placeholder). Statuses:
- `verified`: the evidence is in the ledger;
- `pending-campaign-ii`: needs D1–D3 after the implementation lock;
- `owner-action`: the owner does it; exact steps are in [build-and-archive.md](build-and-archive.md).

`scripts/check_app_release.py` rejects any row without a known status and evidence or steps.

| Area | Item | Status | Evidence or steps |
|---|---|---|---|
| Privacy | Privacy manifest equals the Release-build scan (3 categories, no tracking, no collection) | verified | `A01-P06/t605-privacy-scan` PASS; [privacy-and-credits.md](privacy-and-credits.md) |
| Privacy | Only the Photos add-only usage string, with its UI path | verified | `ExportRenderTests.testOnlyPhotosAddUsageStringIsDeclared`; `check_app_release.py` usage item |
| Privacy | Privacy policy hosted at a public URL | owner-action | Host the text in privacy-and-credits.md and enter the URL in App Store Connect |
| Privacy | App Privacy questionnaire: Data Not Collected | owner-action | App Store Connect → App Privacy |
| Assets | App icon 1024, the app's own render, opaque | verified | `A01-P06/t604-icon-ios27`, `t604-icon-ios26` (provenance mean 0.0) |
| Assets | Version 1.0.0 (1) and the export-compliance key | verified | `project.yml`; `check_app_release.py` |
| Credits | License texts bundled and shown (Acknowledgements) | verified | `A01-P06/t610-ui-ios27`, `t610-ui-ios26`; `bundle_licenses.py`; `check_licenses.py` |
| Credits | No ProjectM or LGPL code linked | verified | Dependency audit build phase (FR-A01-006); `check_dependencies.py` R1–R5 |
| Accessibility | Audit at default and largest text sizes; documented exclusions only for navigation-bar chrome | verified | `A01-P05` seal; `A01-P06/t610-ui-*` |
| Data | Release-format library (schema v1) opens unchanged: 4 compositions, 0 problems, identical renders | verified | `A01-P06/t607-core-tests` (LibraryMigrationFixtureTests); `t607-crash-ios27`, `t607-crash-ios26` |
| Data | Crash recovery: interrupted save keeps the previous file; stale exports removed at launch | verified | `A01-P06/t607-crash-ios27`, `t607-crash-ios26` (CrashRecoveryTests) |
| Store | Listing text with claim → test traceability | verified | [store-listing.md](store-listing.md) |
| Store | Store name and final bundle ID | owner-action | Decide before the first upload; the bundle ID is permanent |
| Store | Screenshots at the required sizes | owner-action | Capture from simulators at App Store sizes when preparing the submission |
| Build | Unsigned Release build for generic iOS | verified | `A01-P06/t605-release-build-a2` |
| Build | 0 automation symbols and trigger strings in Release | verified | `A01-P06/t605-release-symbols` |
| Build | Signing team, archive and upload | owner-action | build-and-archive.md §5 steps 1–3 |
| Store | App Store Connect record and submission | owner-action | build-and-archive.md §5 step 4 |
| Device | D1 iPhone 15 iOS 27.0.1: install, smoke, launch, lifecycle, rendering, export, accessibility | pending-campaign-ii | `scripts/run_device_campaign.py` after IMPLEMENTATION-LOCK |
| Device | D2 iPad Pro M5 iPadOS 27.2: same rows | pending-campaign-ii | Same, after D1 |
| Device | D3 iPad A16 iPadOS 26.5 (never updated): same rows | pending-campaign-ii | Same, after D2 |
| Performance | Frame pacing, launch time, GPU memory on devices | pending-campaign-ii | No number is claimed before device evidence |
