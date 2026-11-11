# Implementation Plan: Fractal Explorer — Phase 03 Navigation and bookmarks

**Branch**: `028-fe-p03-navigation-bookmarks` (spec directory only; work stays on `main`) | **Date**: 2026-11-11 |
**Spec**: [spec.md](spec.md) | **Ledger gate**: A03-P03

## Summary

Bookmarks that keep mode, framing, seed, cap, radius, palette and precision mode, with an exact return on any canvas
shape; Go to coordinates; and span-keeping resizes (regression fixture). The parts are:
- **VisualCore** (owner reuse rule, Principle II):
  - `VisualCoreMath.PlaneFraming` (G-FRAMING): a Codable, size-independent center + span across the shorter side,
    converting to and from `PlaneViewport`;
  - `VisualCorePersistence.NamedLibrary<Payload>` (G-LIBRARY): the generic named-document library generalized from
    A01's `CompositionLibrary` (names, favorites, times, ordering, duplicate, rename, delete, reload with problems,
    caller validation) on `DocumentStore`.
- **App domain** (`FractalExplorerCore`): `Bookmark`, `PrecisionMode`, `BookmarkLibrary` (a thin wrapper of
  `NamedLibrary<Bookmark>`), `GoToInput` parsing and validation.
- **App UI**: Bookmarks sheet, save alert, Go to sheet, the precision note, and span-keeping `resize`.

## Technical Context

**Language/Version**: Swift 6.4.2.

**Primary Dependencies** (each checked in code):
- `VisualCorePersistence.DocumentStore(directory:kind:migrations:maxBytes:)`: `save(_:id:now:)`, `load()` →
  `LoadReport` (`items`, `problems`), `delete(id:)`, `load(id:)`; `StoreProblem` (`corrupt`, `wrongKind`,
  `newerVersion`, `tooLarge`, `notFound`, `writeFailed`, `invalidID`); `MigrationChain(currentVersion:)`.
- `VisualCoreMath.PlaneViewport` (`center`, `unitsPerPoint`, `size`, `framing(width:center:size:)`), `Vec2`
  (Codable), `PrecisionAdvisor` (`assess`, `minimumPixelStep`, `Level`).
- `VisualCoreRendering.RenderHost.renderOffscreen` (GPU aspect fixture), `RenderCapabilities.fragmentMantissaBits`.
- SwiftUI `sheet`, `alert` with `TextField`, `List`, `swipeActions`, `contextMenu`, `accessibilityAction(named:)`.

**Storage**: `Application Support/Bookmarks/<uuid>.json` (DocumentStore envelope, kind
`dev.visualcore.fe.bookmark`, schema 1, ≤ 256 KiB each).

**Testing**:
- host `swift test` for VisualCore (`PlaneFramingTests`, `NamedLibraryTests`) and FractalExplorerCore
  (`BookmarkTests`, `GoToInputTests`);
- app unit tests (`NavigationModelTests`, `AspectTests` including the GPU 64×32/32×64 agreement) and UI tests
  (`BookmarkUITests`, audit with the sheets) on iOS 27.2 and 26.5 with the enumeration guard;
- ProjectM regression and A01/A02 builds after the VisualCore additions.

**Target Platform**: iOS/iPadOS 26.0+.

**Performance Goals**: none timed; the library loads ≤ 500 small files synchronously off the render path (on sheet
open).

**Constraints**: no network, no sharing; all decoded numbers validated; ids are UUID strings (DocumentStore id rule).

**Scale/Scope**: VisualCore gains 2 types; the app core gains 3 sources; the app gains 2 views and model methods.

## Constitution Check

| Principle / rule | Compliance | Status |
|---|---|---|
| I. Proven renderer only | GPU work stays in `FractalScene` behind `RenderHost`; the aspect fixture uses `renderOffscreen`. | PASS |
| II. Reuse first | `PlaneFraming` and `NamedLibrary` are generic, documented, baselined; app keeps only the bookmark schema. | PASS |
| II-a. Preserve reference | ProjectM regression and A01/A02 builds after the VisualCore additions. | PASS (planned) |
| III. GPU lifecycle | No new GL resources; host ownership unchanged. | PASS |
| IV. Host-testable, test first | Framing, library, bookmark and Go to parsing are host-tested first. | PASS |
| V/VI. Evidence | Simulator and host only, with run-check; precision values are context. | PASS |
| VII. Accessible UI | Sheets, labelled fields, accessibility actions for row operations, audit at default and XXXL. | PASS |
| VIII. Privacy | Local files in the container only; no permissions or networking. The store's file-attribute read is a FileTimestamp required-reason API; the Phase 06 privacy manifest (from the built-app scan) must declare C617.1. | PASS |
| IX. Bounded input | Name ≤ 60, |x|,|y| ≤ 4, zoom (0, 1e15], cap 1…10,000, R ≥ 2, finite checks, 256 KiB files. | PASS |
| A03 truthful precision | Precision mode stored; clamp and note on open. | PASS |

## Project Structure

```text
Packages/VisualCore/Sources/VisualCoreMath/PlaneFraming.swift                      # NEW G-FRAMING
Packages/VisualCore/Tests/VisualCoreMathTests/PlaneFramingTests.swift              # NEW
Packages/VisualCore/Sources/VisualCorePersistence/NamedLibrary.swift               # NEW G-LIBRARY
Packages/VisualCore/Tests/VisualCorePersistenceTests/NamedLibraryTests.swift       # NEW
Packages/VisualCore/README.md, docs/api/visualcore-public-api.txt                   # EDIT
Apps/FractalExplorer/FractalExplorerCore/Package.swift                             # EDIT + VisualCorePersistence
Apps/FractalExplorer/FractalExplorerCore/Sources/FractalExplorerCore/Bookmark.swift      # NEW Bookmark, PrecisionMode, BookmarkLibrary
Apps/FractalExplorer/FractalExplorerCore/Sources/FractalExplorerCore/GoToInput.swift     # NEW parsing/validation
Apps/FractalExplorer/FractalExplorerCore/Tests/FractalExplorerCoreTests/{BookmarkTests,GoToInputTests}.swift  # NEW
Apps/FractalExplorer/App/ExplorerView.swift          # EDIT resize via PlaneFraming; bookmark/open/goTo in the model; buttons
Apps/FractalExplorer/App/BookmarksView.swift         # NEW sheet list, save alert, row actions
Apps/FractalExplorer/App/GoToView.swift              # NEW sheet with three fields
Apps/FractalExplorer/Tests/Unit/{NavigationModelTests,AspectTests}.swift   # NEW
Apps/FractalExplorer/Tests/UI/BookmarkUITests.swift, AccessibilityAuditUITests.swift   # NEW / EDIT
project.yml                                           # EDIT app links VisualCorePersistence
docs/apps/fractal-explorer/visualcore-contract.{json,md}, regression-baseline.md, docs/testing/simulator-test-lessons.md  # EDIT
```

Dependency direction:
- VisualCorePersistence → Foundation only (unchanged rule R1); VisualCoreMath unchanged;
- FractalExplorerCore → VisualCoreMath, VisualCorePersistence;
- app → FractalExplorerCore, VisualCore modules.

## Lifecycle contracts

- `ExplorerModel` owns a `BookmarkLibrary` created lazily on first use with `defaultDirectory()` (tests inject a
  `TemporaryFolder`). `reload()` runs when the sheet opens.
- `open(_ bookmark:)` sets mode, seed, cap, radius and palette, then `apply(framing.viewport(size:))`; the precision
  clamp of Phase 02 runs inside `apply`. If the clamp changed the span, `bookmarkNote` is set; any later `apply`
  from a gesture, zoom or reset clears it.
- `resize(to:)` = `apply(PlaneFraming(viewport).viewport(size:))`.
- Library writes are synchronous and small; errors surface as an alert text, never a crash.

## Migration and rollback

- **Migration**: none (new storage, schema 1). A01 is unchanged; adopting `NamedLibrary` there is a follow-up
  recorded in the contract (ADR not required: additive).
- **Rollback**: revert the feature-028 commits; the VisualCore types are additive, and stored bookmarks are ignored by
  an older build (no reader).

## Complexity Tracking

None.
