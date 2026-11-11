# Implementation Plan: Generative Art Studio — Phase 06 Final verification, privacy, packaging and release

**Branch**: `017-gas-p06-release-readiness` | **Date**: 2026-11-11 | **Spec**: [spec.md](spec.md) | **Gate**: A01-P06

## Summary

Release readiness, following the reuse rule.

**Shared by all 25 apps:**
- `scripts/check_privacy_manifest.py`: scans a built `.app` (main binary plus embedded frameworks, through `nm`)
  against a required-reason API table and compares the result with the bundle's `PrivacyInfo.xcprivacy`.
- `scripts/check_app_release.py`: checks a built app against `docs/apps/<slug>/release.json` (icon, version,
  encryption flag, allowed usage strings, privacy manifest, required documents, checklist statuses).
- `release_check.py` steps that run both checks for every app that has a `release.json`.
- `VisualCoreAutomation.AutomationView`: hosts any RenderScene and runs the requested automation mode. Showcase adopts
  it in place of its private canvas.

**Generative Art Studio adds:**
- `PrivacyInfo.xcprivacy`;
- an asset catalog with an icon rendered by its own exporter;
- version 1.0.0 (build 1);
- launch cleanup of stale exports;
- an automation entry;
- a library migration fixture and crash-recovery tests;
- release documents: privacy and credits, checklist, store listing with claim traceability, build and archive
  instructions.

## Technical Context

**Language/Version**: Swift 6.4.2; Python 3 (the system `/usr/bin/python3`, standard library only).

**Primary Dependencies**:
- the existing packages;
- Xcode `nm`, `plutil` and `assetutil` (Xcode command-line tools) for the scans;
- no new third-party code.

**Storage**: unchanged. The fixture lives in `Apps/GenerativeArtStudio/Core/Tests/GenerativeArtStudioCoreTests/Fixtures/library-v1/`.

**Testing**:
- `test_scripts.py`: privacy-scan logic on symbol lists and manifests, including undeclared, unused, tracking and
  collected-data fixtures; release-check logic on synthetic `.app` folders;
- Core host test `LibraryMigrationFixtureTests`: 4 committed v1 files load to the expected documents with 0 problems;
- app hosted tests:
  - `IconRenderTests`: renders the icon at 1024 and checks it against the committed PNG;
  - `CrashRecoveryTests`: stale export and temporary files are removed at launch cleanup; the library loads with 0
    problems after an interrupted save; fixture compositions render identically to their expected documents;
- simulator automation rehearsal: `run_automation_sim.py` smoke, launch and lifecycle on 27.2 and 26.5;
- Release build: `check_release_symbols.py`, `check_privacy_manifest.py` and `check_app_release.py` on the built app;
- full app suites (enumeration-guarded) and the reference regression, because VisualCoreAutomation changes.

**Target Platform**: iOS/iPadOS 26.0+

**Performance Goals**: none claimed. Campaign II measures them.

**Constraints**:
- no signing changes;
- no device actions;
- owner-only steps are listed, never performed;
- no new permission;
- no network.

**Scale/Scope**: 2 shared scripts, 1 VisualCore view, about 6 app files, 4 tests, 5 documents.

## Constitution Check

| Principle | Status |
|---|---|
| I Renderer | PASS: the icon is rendered by the same host and exporter; automation hosts the same RenderHost |
| II Maximize reuse | PASS: privacy scan, release check and automation view are shared; Showcase de-duplicated |
| II-a Reference | PASS: reference regression after the VisualCoreAutomation change |
| III Lifecycle | PASS: automation lifecycle mode; launch cleanup touches only the tmp export folder |
| IV Host-testable | PASS: script logic is unit-tested in Python; fixture loading in Core host tests |
| V Simulator only | PASS: device runs listed as pending campaign II; automation rehearsed on simulators only |
| VI Evidence | PASS |
| VII Accessible UI | PASS: unchanged; audit rerun in the full suite |
| VIII Privacy | PASS: manifest from a scan of the built app; no tracking or collection; summary agrees |
| IX Bounded input | PASS: fixture files go through the same validated store |
| X Licensing | PASS: credits from `docs/legal`; icon is first-party render output |
| A01 rules | PASS |

## Project Structure

```text
scripts/check_privacy_manifest.py, scripts/check_app_release.py (+ cases in scripts/test_scripts.py, fixtures/)
scripts/release_check.py                          # + app-release steps per docs/apps/*/release.json
Packages/VisualCoreRendering/Sources/VisualCoreAutomation/AutomationView.swift  (+ VisualCoreAutomationTests case)
Showcase/App/ShowcaseAutomation.swift             # adopts AutomationView
Apps/GenerativeArtStudio/Resources/PrivacyInfo.xcprivacy
Apps/GenerativeArtStudio/Resources/Assets.xcassets/AppIcon.appiconset/{Contents.json,icon-1024.png}
Apps/GenerativeArtStudio/App/{AppAutomation.swift, LaunchCleanup.swift}, GenerativeArtStudioApp.swift
Apps/GenerativeArtStudio/Core/Tests/GenerativeArtStudioCoreTests/{LibraryMigrationFixtureTests.swift, Fixtures/library-v1/*.json}
Apps/GenerativeArtStudio/Tests/Unit/{IconRenderTests,CrashRecoveryTests}.swift
project.yml                                        # resources, AppIcon, version 1.0.0, VisualCoreAutomation for GAS
docs/apps/generative-art-studio/{release.json, privacy-and-credits.md, release-checklist.md, store-listing.md, build-and-archive.md}
```

**Dependency direction**: App → VisualCoreAutomation, used only inside `#if DEBUG || VISUALCORE_AUTOMATION`. The
module is empty in Release, which the symbol check verifies. The scripts read build output only.

**Contracts**:
- **`check_privacy_manifest.py --app X.app [--json out]`**:
  - exit 0 when the declared categories equal the detected ones, tracking is false, domains are empty and the
    collected types are empty;
  - exit 1 otherwise, listing undeclared, unused and violations;
  - exit 2 on bad input.
- **`check_app_release.py --app X.app --config docs/apps/<slug>/release.json`**: exit 0 or 1 with a per-item list.

**Data migration**: the format is unchanged (schema v1). The committed fixture pins it for future versions.

**Rollback**: revert the phase commits. Scripts and the VisualCore view are additive, and Showcase keeps the same
behavior.

## Complexity Tracking

None.
