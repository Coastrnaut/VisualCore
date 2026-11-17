# Digital Zen Garden — store text input

This is an input for the owner, who enters the App Store text of the VisualCore app; the agent never enters anything
in App Store Connect ([build-and-archive.md](../../release/build-and-archive.md) section 5). Digital Zen Garden is an
experience of the free tier of VisualCore (`tier: free` in `Catalog/experiences.json`), not a separate app. Feature 150
(A20-P06), FR-A20-605 and FR-A20-606.

Every sentence below describes something that exists in the controls
(`DigitalZenGarden/Experience/GardenControls.swift`), the presenter (`GardenPresenter.swift`), the adapter
(`Experience/Adapter/GardenCore.swift`) or the picture (`GardenStill.swift`), and is exercised by the tests named in
the traceability table. The text is checked by `scripts/check_copy_claims.py` with `Configs/copy-claims-denylist.json`
([release.json](release.json) allows only the word "share" through `copyCheck.allow`, because the experience hands its
picture to the system share sheet) and by the experience's own word scan of T-A20-607
(`specs/150-zg-p06-release/scan-claims-release.sh`, the refused words of the spec's Clarifications Q2). The store text
names no performance figure and no value from a device, and makes no claim beyond what the code holds.

## Text

**Digital Zen Garden** — a quiet tray of sand to rake and arrange with stones, drawn in code, inside VisualCore.

Rake the sand with one finger using a fine rake or a wide rake, in pale, warm or grey sand. A preview under your finger
shows where the rake will go. Or let a pattern rake rows, a circle, a wave or a spiral for you.

Place stones from five kinds, move them, turn them and remove them. Undo and redo every stroke, tone change and stone.

Save up to 12 named gardens on your device, then open, rename or delete them.

The garden is calm from the start: sound, sand drift and haptics are each off until you turn them on, and your choice
is kept. With Reduce Motion on, the picture stays still.

Make a picture of your garden at 1600 by 1200 pixels and hand it to the system share sheet to keep it where you choose.

Every control has a spoken label and value for VoiceOver. Digital Zen Garden works offline and reopens with the garden
you left.

## Traceability

| Claim | Proving test |
|---|---|
| Rake with one finger using a fine rake or a wide rake | `PaletteTests.swift theTwoRakesDiffer`; `RakeTests.swift theStylesDifferInTinesWidthAndDepth`; `PointerPathTests.swift threeFarApartEventsGiveAStrokeWithoutGaps`; `PointerPathTests.swift aSecondFingerIsIgnored` |
| Pale, warm or grey sand | `PaletteTests.swift theTonesAreOpaqueAndInRange`; `GardenCoreTests.swift choosingTheCurrentToneChangesNothing` |
| A preview under the finger shows where the rake will go | `BrushPreviewTests.swift theDragShowsTheRakesWidthAndTines`; `BrushPreviewTests.swift thePreviewFollowsTheRakeStyle`; `BrushPreviewTests.swift thePreviewNeverChangesTheDigest` |
| Patterns rake rows, a circle, a wave or a spiral | `PatternTests.swift everyPatternLiesInsideTheTrayBelowThePointCap`; `PatternTests.swift eachPatternCommitsOneStrokeThroughTheStrokeActions`; `ZGGardenUITests` (raking rows adds a stroke and Undo takes it back) |
| Place stones from five kinds, move them, turn them and remove them | `PaletteTests.swift theStoneKindsAreFiveWithRadiiInRange`; `StoneActionTests.swift movesStayInsideTheTray`; `StoneGestureTests.swift aDragFromTheSelectedStoneShowsTheMoveAndSendsOneMoveOnLift`; `StoneGestureTests.swift aTwoFingerTurnSendsOneRotateAtItsEnd`; `StoneGestureTests.swift theNativeControlsSelectTurnNudgeAndRemove`; `ZGGardenUITests` (a placed pebble is removed and Undo restores it) |
| Undo and redo every stroke, tone change and stone | `HistoryTests.swift eachCommandKindAppliesAndUndoesExactly`; `StoneActionTests.swift eachStoneCommandUndoneAndRedoneGivesEqualDocuments`; `ReplayFixtureTests.swift sixtyCommandsUndoneAndRedoneAreIdentical`; `ReplayFixtureTests.swift beyondOneHundredCommandsTheOldestFoldIntoTheCheckpoint` |
| Save up to 12 named gardens on your device; open, rename or delete them | `LibraryTests.swift aSaveAndOpenRoundTripIsExact`; `LibraryTests.swift listRenameAndDelete`; `LibraryTests.swift theLibraryHoldsTwelveGardens`; `LibraryTests.swift namesAreTrimmedAndOneToFortyCharacters`; `ZGLibraryUITests` (a garden saved as Evening opens with its stroke) |
| Sound, sand drift and haptics are each off until you turn them on, and the choice is kept | `CalmTests.swift theSwitchesAreOffByDefault`; `CalmTests.swift tonesAndHapticsOnlyWhenOn`; `CalmTests.swift theSwitchesAreKeptAcrossAReopen`; `ZGReleaseUITests` (a fresh start shows the three calm switches off) |
| With Reduce Motion on, the picture stays still | `ReducedMotionTests.swift withTheDriftOnUnderReduceMotionTwoFramesAreIdentical`; `ReducedMotionTests.swift withTheDriftOffTwoFramesAreIdenticalAndTheStillFrameIsReused` |
| A picture of the garden at 1600 by 1200 pixels, handed to the system share sheet | `StillTests.swift aStillIsA1600By1200PNGAndASecondExportReplacesIt`; `StillTests.swift theSessionsStillRendererDrawsTheGardenForTheShareControl`; `StillTests.swift aFailedExportLeavesNoFile`; `ZGReleaseUITests` (Make picture reports 1600 by 1200 pixels and the share control appears) |
| Spoken labels and values for VoiceOver | `AccessibilityTests.swift everyControlHasASpokenLabelAndValue`; `AccessibilityTests.swift undoRedoLibraryPictureAndRefusalsAreAnnounced`; `AccessibilityTests.swift atAccessibilityFiveTheControlsStackWithinTheCanvas` |
| Works offline and reopens with the garden you left | `GardenCoreTests.swift theSnapshotIsTheGardenDocumentOnly`; `GardenManifestTests.swift theSaveRestoreStateSurvivesARestore`; `DocumentTests.swift theRoundTripIsExact` |

The source scan of the experience (`zg-no-network`, T-A20-603) proves that no network, tracking, sensor, recording,
photo-library, image-picker, idle-timer or brightness use is in `Packages/ExperiencesCreative/DigitalZenGarden`
(`.autonomy/checks/A20-P06.zg-no-network.json`). The only permission is the app's add-only Photos string, asked by the
system when the person chooses Save Image in the share sheet. See [privacy-and-credits.md](privacy-and-credits.md) and
[licenses.md](licenses.md). No speed, timing, heat, memory or device claim is made. The interface tests of chunk `b3`
(`ZGGardenUITests`, `ZGLibraryUITests`, `ZGReleaseUITests`; T-A20-608) prove the journeys through the app's controls on
the iOS 27 phone simulator; they are simulator results, not device measurements. Device measurements wait for the
device campaign ([device-campaign.md](device-campaign.md)).
