# Infinite Geometry — store text input

This is an input for the owner, who enters the App Store text of the VisualCore app; the agent never enters anything
in App Store Connect ([build-and-archive.md](../../release/build-and-archive.md) section 5). Infinite Geometry is an
experience of the free tier of VisualCore (`tier: free` in `Catalog/experiences.json`), not a separate app. Its
catalog entry is still marked `available: false` until the X-A05 gate integrates it.

Every sentence below describes a control that exists in `InfiniteGeometry/Experience/GeometryControls.swift` or the
canvas of `InfiniteGeometry/Experience/GeometryPresenter.swift` and is exercised by the tests named in the
traceability table. The text is checked by `scripts/check_copy_claims.py` with `Configs/copy-claims-denylist.json`.

## Text

**Infinite Geometry** — a geometry laboratory inside VisualCore, free to use.

Explore symmetric patterns made entirely by code. Choose one of four presets: a kaleidoscope, a square tiling, a
hexagonal tiling or a 3D composition. Set the symmetry order of the kaleidoscope and the 3D composition, the number
of repetitions and the scale, pick one of six palettes, or draw a new motif.

Move the view with the buttons or with your fingers on the canvas: pan, zoom in and out, orbit around the 3D
composition, make its field of view wider or narrower, and reset the view to the preset's own.

Save the compositions you like under a name, then open, rename or delete them later; they stay on your device.
Export a picture of the composition as a PNG image, up to 2048 pixels on its long edge, and pass it on through the
system sheet.

VisualCore draws the 3D composition with less detail when the device needs it; the composition itself stays the same.
VoiceOver describes the composition on the canvas.

## Traceability

| Claim | Proof |
|---|---|
| Four presets: kaleidoscope, square tiling, hexagonal tiling, 3D composition | `GeometryCoreTests.curatedPresetsComeInKindOrder`, `GeometrySessionTests.testEachCuratedPresetDrawsANonBlankFrameWhoseProbeMatches` (package); `IGControlsUITests` (chunk k2) |
| Symmetry order of the kaleidoscope and the 3D composition | `KaleidoscopeRenderTests` (orders 1, 3, 6, 12), `GeometryCoreTests.eachValidActionChangesTheStateAndTheDigest` (package); `IGControlsUITests` (chunk k2) |
| Repetitions, scale, six palettes, new motif | `GeometryCoreTests.eachValidActionChangesTheStateAndTheDigest`, `eachInvalidActionIsRefusedWithTheDigestUnchanged` (package) |
| Pan, zoom, orbit, field of view wider or narrower, reset, by buttons | `GeometryCameraTests`, `GeometryOrbitViewTests` (package); `IGControlsUITests` (chunk k2) |
| The same view changes with fingers on the canvas | `GeometryOrbitViewTests.twoFingerMovementPansTheTargetAndTheButtonsClampTheFieldOfView`, `theCanvasDescriptionStatesTheFieldOfViewOnTheSolid` (every gesture action has a button) (package); `.autonomy/evidence/A05-P02.json`, `.autonomy/evidence/A05-P03.json` |
| Saved compositions: save, open, rename, delete; stored on the device | `GeometryLibraryTests`, `GeometryDocumentTests.everyKindReopensWithTheOriginalDigest` (package); `IGLibraryExportUITests` (chunk k2); [privacy-and-credits.md](privacy-and-credits.md) |
| Export a PNG picture, up to 2048 pixels on its long edge, passed on through the system sheet | `GeometryExportTests.testExportsAreIdenticalExactlySizedMatchTheScreenAndKeepTheDigest` (package); `IGLibraryExportUITests` (chunk k2) |
| Less detail on the 3D composition when the device needs it; the composition stays the same | `GeometryQualityTests.testTheTierChangesNoDigestSnapshotOrSavedComposition`, `testAPinnedLevelDrawsItsTessellation` (package) |
| VoiceOver describes the composition | `GeometryOrbitViewTests.theCanvasDescriptionStatesTheFieldOfViewOnTheSolid` (package); `IGControlsUITests` (chunk k2) |
| Free tier | `Catalog/experiences.json` (`a05.infinite-geometry`, `tier: free`) |

No speed, timing or device claim is made; those wait for the device campaign ([device-campaign.md](device-campaign.md)).
