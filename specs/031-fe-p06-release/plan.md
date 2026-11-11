# Implementation Plan: Fractal Explorer — Phase 06 Final verification, privacy, packaging and release

**Branch**: `031-fe-p06-release` (spec directory only; work stays on `main`) | **Date**: 2026-11-11 |
**Spec**: [spec.md](spec.md) | **Ledger gate**: A03-P06

## Summary

Release readiness with the existing tooling and no VisualCore change: privacy manifest from the Release scan, privacy
and session tests, own-render icon with provenance test, Acknowledgements from bundled licenses, version 1.0.0 (1),
the committed v1 bookmark fixture and crash-recovery tests, copy tests, release documents and checklist, full suites
on both runtimes.

## Technical Context

**Language/Version**: Swift 6.4.2; Python 3 tooling.

**Primary Dependencies** (each checked in code):
- `scripts/bundle_licenses.py --out <bundle>/Licenses` (post-build phase), `VisualCoreUI.AcknowledgementsView(identifierPrefix:)`;
- `scripts/check_privacy_manifest.py --app`, `scripts/check_app_release.py --app --config`, `scripts/check_app_isolation.py
  --app --built-app --allow-usage`, `scripts/check_release_symbols.py --app`; `release_check.py` discovers
  `docs/apps/<slug>/release.json` and adds `app-release-<slug>`;
- `StillCapture.folder(named:)`/`TemporaryFolder.removeAll()` (launch cleanup, feature 029), `BookmarkLibrary`
  (`NamedLibrary<Bookmark>`, `DocumentStore` leftover cleanup), `StillImageEncoder.pngData`, `RenderHost.renderOffscreen`.

**Storage**: unchanged (bookmarks schema 1; temporary captures).

**Testing**: app unit/UI on 27.2 and 26.5 with the guard (new `PrivacyTests`, `IconRenderTests`, `MigrationTests`,
`CrashRecoveryTests`, `CopyTests`, `AcknowledgementsUITests`); host tests; Release build and checks; isolation.

**Target Platform**: iOS/iPadOS 26.0+.

**Performance Goals**: none claimed.

**Constraints**: no device runs; owner-only steps marked `BLOCKED_OWNER_ACTION`; no signing changes.

## Constitution Check

| Principle / rule | Compliance | Status |
|---|---|---|
| I–III | No rendering change; icon via the existing offscreen path. | PASS |
| II. Reuse first | Release tooling, AcknowledgementsView and persistence reused; no new app-local copies. | PASS |
| II-a. Preserve reference | No VisualCore change, so no new regression run required; final checks include the release suite. | PASS |
| IV. Host-testable | Fixture and recovery tests on the library. | PASS |
| V/VI. Evidence | Simulator/host only; device rows pending. | PASS |
| VII. Accessible UI | Acknowledgements audited; full audits pass. | PASS |
| VIII. Privacy | Manifest from scan; session leaves no app keys; no network. | PASS |
| IX. Bounded input | Unchanged. | PASS |
| A03 truthful precision / claims | Copy tests forbid performance and device claims. | PASS |

## Project Structure

```text
Apps/FractalExplorer/Resources/PrivacyInfo.xcprivacy                 # NEW (from the Release scan)
Apps/FractalExplorer/Resources/Assets.xcassets/AppIcon.appiconset/{Contents.json,icon-1024.png}  # NEW
Apps/FractalExplorer/App/FractalExplorerApp.swift                    # EDIT home description, acknowledgements link
Apps/FractalExplorer/Tests/Fixtures/bookmark-v1.json                 # NEW golden fixture (committed once)
Apps/FractalExplorer/Tests/Unit/{PrivacyTests,IconRenderTests,MigrationTests,CrashRecoveryTests,CopyTests}.swift  # NEW
Apps/FractalExplorer/Tests/UI/AcknowledgementsUITests.swift          # NEW
project.yml   # EDIT resources, version 1.0.0 (1), bundle-licenses post-build phase, test resources
docs/apps/fractal-explorer/{release.json,privacy-and-credits.md,store-listing.md,build-and-archive.md,release-checklist.md}  # NEW
docs/apps/fractal-explorer/visualcore-contract.{json,md}, docs/testing/simulator-test-lessons.md  # EDIT
```

## Lifecycle contracts

- App launch: captures folder emptied (existing); bookmark store cleanup happens on the first load.
- Acknowledgements: home link → `AcknowledgementsView(identifierPrefix: "fe.acknowledgements")`.

## Migration and rollback

- **Migration**: bookmark schema 1 is frozen by the fixture; a future schema adds a `MigrationChain` step and a new
  fixture.
- **Rollback**: revert the feature-031 commits.

## Complexity Tracking

None.
