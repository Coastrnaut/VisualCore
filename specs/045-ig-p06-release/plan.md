# Implementation Plan: Infinite Geometry — Phase 06 Final verification, privacy, packaging and release

**Branch**: `045-ig-p06-release` (spec directory only; work on `main`) | **Date**: 2026-11-14 | **Spec**: [spec.md](spec.md)

## Summary

Release readiness for Infinite Geometry on the A04-P06 pattern: privacy and credits note and a no-network scan; library
fixtures for every file form; a drawing-failure seam proving recovery; release documents with the release-document and
copy-claim checks; known limitations and a device-campaign plan; an interface chunk `k2` in the one app; the release
build checks. No VisualCore change. Research: [research.md](research.md).

## Technical Context

**Language**: Swift 6, SwiftUI, Python 3 (existing checks only). **Testing**: ExperiencesCreative on sim-27.2 (fixtures,
recovery); app build-for-testing, unit and UI chunk k2 on the iOS 27 phone; runner on iOS 27; release build checks; the
experience release and copy checks; script tests. **Constraints**: iOS 27 only at this phase gate (owner, 2026-11-14);
tests < 10 s each; no device runs.

## Constitution Check

I–XIII PASS: no renderer change; no VisualCore change; host keeps the context; no network, data collection or ads;
interface tests use buttons only; audits deferred to the device campaign by owner ruling; owner-only steps recorded.

## Project Structure

```text
docs/apps/infinite-geometry/{privacy-and-credits.md, store-listing.md, release-checklist.md, device-campaign.md, release.json}   new
docs/release/known-limitations.md                                              modify  Infinite Geometry device-only items
Packages/ExperiencesCreative/InfiniteGeometry/Experience/GeometryPresenter.swift                                          modify  internal failNextDraw seam, GeometryDrawError
Packages/ExperiencesCreative/Package.swift                                     modify  InfiniteGeometryExperienceTests resources (Fixtures)
Packages/ExperiencesCreative/InfiniteGeometry/ExperienceTests/Fixtures/Library/composition-*.json                         new     five fixtures (UUIDs 00000000-0000-4000-8000-…)
Packages/ExperiencesCreative/InfiniteGeometry/ExperienceTests/{GeometryLibraryMigrationTests,GeometryRecoveryTests}.swift new
Apps/VisualCore/Tests/UI/InfiniteGeometry/{IGSupport,IGControlsUITests,IGLibraryExportUITests}.swift   new
scripts/release_check.py                                                       modify  UI_CHUNKS k2
```

**Lifecycle**: the seam is internal and false in every non-test path. **Migration**: none (library format 1 stays).
**Rollback**: revert the commits.

## Parallel work

Agent A: docs (privacy, store listing, checklist, device campaign, release.json, known limitations). Agent B: fixtures,
Package.swift resources, migration and recovery tests, presenter seam. Agent C: UI tests (IGSupport, two classes).
Lead: release_check chunk, runs, commits.
