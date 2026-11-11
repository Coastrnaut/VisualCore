# Fractal Explorer — store listing draft

This is a draft for the owner. The name, subtitle and keywords are placeholders until the owner chooses store
branding; the bundle ID `dev.visualcore.FractalExplorer` is the approved placeholder. Every claim below maps to a
passing test. A claim that cannot be traced is removed, not softened.

**Name:** Fractal Explorer
**Subtitle:** Mandelbrot and Julia sets up close

**Description:**

> Explore the Mandelbrot and Julia sets with a short explanation of each. Pinch and drag to zoom and move; the point
> between your fingers stays put. Choose from five palettes, let the colors flow or keep them still, and set the
> number of iterations while a cost line shows how much more work a picture takes.
>
> Save places as bookmarks and come back to them on any screen shape, go to coordinates you type in, or take one of
> three guided tours with a caption at each stop. Capture a large picture and share or save it.
>
> When a view reaches the limit of your device's number precision, the app says so and stops zooming instead of
> showing wrong detail.
>
> Works with VoiceOver and large text, and honors Reduce Motion. Everything stays on your device: no account, no
> tracking, no network.

## Claim traceability

| Claim | Test |
|---|---|
| Mandelbrot and Julia sets with an explanation of each | `ExplorerUITests.testModesExplanationsAndSpokenCanvas` |
| Pinch and drag; the point between the fingers stays put | `GestureTests.testCenteredPinchKeepsTheCoordinateStationary`; `GestureTests.testDragMovesExactlyWithTheFinger` |
| Five palettes; flowing or still colors | `PaletteTests.testEachPaletteReachesTheScene`; `PaletteTests.testAnimationOffFreezesAndOnMovesTheColors` |
| Number of iterations with a cost line | `CostAndCapTests.testCostFollowsTheCapAndReachesTheScene`; `CaptureTourUITests.testCapAndCostThenCapture` |
| Bookmarks on any screen shape | `NavigationModelTests.testSaveReloadAndOpenAtAnotherSizeReturnsTheView`; `BookmarkReproductionTests.testBookmarksReproduceTheirPictures`; `BookmarkUITests.testSaveListOpenRenameFavoriteDelete` |
| Go to coordinates | `GoToModelTests.testGoToCentersAndZooms`; `BookmarkUITests.testGoToValidAndInvalid` |
| Three guided tours with captions | `TourPlayerTests.testTicksReachEveryStopAnnounceOnceAndFinish`; `CaptureTourUITests.testTourShowsCaptionsAndStops` |
| Capture a large picture; share or save | `CaptureTests.testCaptureMatchesTheCPUReferenceAndKeepsTheAspect`; `CaptureTourUITests.testCapAndCostThenCapture` |
| Precision limit shown; zooming stops | `PrecisionClampTests.testRepeatedZoomInsStopAtTheClampWithNearAndReachedStates`; `ExplorerUITests.testZoomControlsPaletteAnimateAndPrecisionBanner` |
| VoiceOver and large text | `AccessibilityAuditUITests.testAuditDefaultTextSize`; `AccessibilityAuditUITests.testAuditLargestAccessibilityTextSize` |
| Honors Reduce Motion | `PaletteTests.testReduceMotionDefaultsAnimationOff`; `TourPlayerTests.testReduceMotionJumps` |
| On device only; no account, tracking or network | `PrivacyTests.testSessionStoresOnlyTheSavedBookmark`; `check_privacy_manifest.py` (Data Not Collected); `check_app_isolation.py` (no networking) |

**Removed:** zoom-depth, frame-rate, battery and device-compatibility wording. Precision and performance on devices
are measured in campaign II before any claim.

**Owner-only (`BLOCKED_OWNER_ACTION`):** store name and keywords, privacy policy URL, support URL, the EULA choice,
age rating answers, and screenshot upload.
