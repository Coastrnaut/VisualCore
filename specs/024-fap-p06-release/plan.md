# Implementation Plan: Fluid Art Playground — Phase 06 Final verification, privacy, packaging and release

**Branch**: `024-fap-p06-release` (spec directory only; work stays on `main`) | **Date**: 2026-11-11 |
**Spec**: [spec.md](spec.md) | **Ledger gate**: A02-P06

## Summary

This phase makes Fluid Art Playground release-ready, reusing A01's release tooling unchanged:
- a privacy manifest that matches the scan of the Release build;
- the single Photos add-only usage string, with a test;
- an app icon rendered by the app's own deterministic test mode, with a provenance test;
- version 1.0.0 (1);
- bundled licenses shown through VisualCoreUI's `AcknowledgementsView`;
- launch cleanup of temporary captures through a new VisualCorePersistence `TemporaryFolder`;
- a no-persistence test;
- release docs and a checklist in which every row has a status;
- `release.json`, which enables `release_check.py`'s per-app release step.

## Technical Context

**Language/Version**: Swift 6.4.2; Python 3 (existing scripts only).

**Primary Dependencies** (all checked in code):
- **VisualCoreUI**: `AcknowledgementsView(identifierPrefix:)` and `LicenseInventory(bundle:)`.
- **VisualCoreRendering**: `RenderHost.renderOffscreen(width:height:time:)` and `StillImageEncoder.pngData(_:)`.
- **App**: `TestMode.makeModel` (feature 023).
- **Scripts**:
  - `scripts/bundle_licenses.py` (post-build phase, `docs/legal/third-party.json`);
  - `check_privacy_manifest.py --app`;
  - `check_app_release.py --app --config` (statuses `verified`, `pending-campaign-ii`, `owner-action`);
  - `check_release_symbols.py` and `check_app_isolation.py`;
  - `release_check.py`'s `app_release_steps`, which run for every `docs/apps/<slug>/release.json`.

**Storage**: none, except `tmp/Captures` (emptied at launch and on close).

**Testing**:
- host `swift test` for VisualCore (`TemporaryFolderTests`);
- app unit tests: icon provenance, launch cleanup, no persistence and the usage-string set;
- UI tests: Acknowledgements, with the audit extended;
- on iOS 27.2 and 26.5 with the enumeration guard;
- the unsigned Release build, then `release_check.py --only app-release-fluid-art-playground`;
- the ProjectM regression after the VisualCore addition.

**Target Platform**: iOS/iPadOS 26.0+.

**Performance Goals**: none claimed; device rows are pending campaign II.

**Constraints**:
- no signing or App Store Connect action;
- no networking, tracking or new permission;
- no migration code.

**Scale/Scope**:
- VisualCore: 1 new type.
- App: an Assets catalog and a privacy manifest under `Apps/FluidArtPlayground/Resources/`, edits to
  `CaptureModel`, the App shell and `project.yml`.
- Tests: about 5 new test classes.
- Docs: 5.

## Constitution Check

| Principle / rule | Compliance | Status |
|---|---|---|
| I. Proven renderer only | The icon renders through `RenderHost.renderOffscreen`; no new GL. | PASS |
| II. Reuse first | A01 tooling and `AcknowledgementsView` are reused. `TemporaryFolder` is generic, in VisualCorePersistence (Foundation only, R2), documented, with a baseline update. A01's adoption is recorded as reuse debt. | PASS |
| II-a. Preserve reference | ProjectM regression after the VisualCore addition. | PASS (planned) |
| III. GPU lifecycle | Unchanged. | PASS |
| IV. Host-testable | `TemporaryFolder` has host tests. | PASS |
| V. Implementation before devices | Device rows are `pending-campaign-ii`. | PASS |
| VI. Evidence | Every `verified` row cites a ledger check. | PASS |
| VII. Accessible UI | Acknowledgements are added to the audit at default size and XXXL. | PASS |
| VIII. Public APIs, privacy | The manifest comes from the scan; one usage key; no tracking. | PASS |
| X. Licensing | `bundle_licenses.py` and `check_licenses.py`; icon provenance. | PASS |

## Project Structure

```text
Packages/VisualCore/Sources/VisualCorePersistence/TemporaryFolder.swift            # NEW
Packages/VisualCore/Tests/VisualCorePersistenceTests/TemporaryFolderTests.swift    # NEW
docs/api/visualcore-public-api.txt                                                 # EDIT (--update)
Apps/FluidArtPlayground/Resources/Assets.xcassets/{Contents.json,AppIcon.appiconset/{Contents.json,icon-1024.png}}  # NEW
Apps/FluidArtPlayground/Resources/PrivacyInfo.xcprivacy                            # NEW (from the scan)
Apps/FluidArtPlayground/App/CaptureModel.swift          # EDIT write through TemporaryFolder("Captures")
Apps/FluidArtPlayground/App/FluidArtPlaygroundApp.swift # EDIT init: launch cleanup; home link to Acknowledgements
Apps/FluidArtPlayground/Tests/Unit/IconRenderTests.swift, CrashRecoveryTests.swift, PrivacyTests.swift   # NEW
Apps/FluidArtPlayground/Tests/UI/AcknowledgementsUITests.swift   # NEW; AccessibilityAuditUITests gains the screen
project.yml   # EDIT FAP: Resources (assets + manifest), ASSETCATALOG_COMPILER_APPICON_NAME, version 1.0.0 (1),
              #      VisualCorePersistence dependency, bundle_licenses post-build phase
docs/apps/fluid-art-playground/{release.json, privacy-and-credits.md, store-listing.md, build-and-archive.md,
                                release-checklist.md}                                    # NEW
docs/apps/fluid-art-playground/visualcore-contract.{json,md}, regression-baseline.md     # EDIT
```

Dependency direction: app → VisualCorePersistence (pure). App → VisualCoreUI and VisualCoreRendering.

## Lifecycle contracts

- **Launch**: `FluidArtPlaygroundApp.init` calls `CaptureModel.folder.removeAll()` before any scene exists. It runs
  in automation launches too, which is harmless.
- **Capture**: `CaptureModel` writes `folder.makeFileURL(prefix: "FluidArt", extension: "png")` and removes the
  previous file. `close()` removes the file. Only the latest file exists.
- **Icon**: in tests only. Build a test-mode model (seed 3, glow), host it at 390×844, step 90 frames, pause, then
  `renderOffscreen(1024, 1024)`, `pngData`, and compare or write.

## Migration and rollback

- **Migration**: the app stores nothing, so there is nothing to migrate (FR-A02-606).
  - `FluidConfiguration.version` 1 is documented as the starting point for any future persisted format.
  - The capture location moves from `tmp/FluidArt-*.png` to `tmp/Captures/`. Files at the old location belong to
    the system's temporary cleanup; the new launch cleanup covers only the new folder.
- **Rollback**: revert the feature-024 commits. `TemporaryFolder` is additive.

## Complexity Tracking

None.
