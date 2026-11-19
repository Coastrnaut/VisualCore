# Effects Composer — store text input

This is an input for the owner, who enters the App Store text of the VisualCore app; the agent never enters anything
in App Store Connect ([build-and-archive.md](../../release/build-and-archive.md) section 5). Effects Composer is an
experience of the free tier of VisualCore (`tier: free` in `Catalog/experiences.json`), not a separate app. Feature
185 (A25-P06), FR-A25-605 and FR-A25-606.

Every sentence below describes something that exists in the controls (`EffectsComposer/Experience/ECControls.swift`),
the presenter (`ComposerPresenter.swift`), the preview renderer (`PreviewRenderer.swift`), the picture import
(`ImageImport.swift`), the export (`StillExport.swift`), the looks library (`LookLibrary.swift`) or the adapter
(`Experience/Adapter/ComposerCore.swift`), and is exercised by the tests named in the traceability table. The text is
checked by `scripts/check_copy_claims.py` with `Configs/copy-claims-denylist.json` ([release.json](release.json)
allows only the word "share" through `copyCheck.allow`, because the experience hands an export to the system share
sheet on the person's tap) and by the experience's own word scan of T-A25-607
(`specs/185-ec-p06-release/scan-claims-release.sh`, the refused words of the spec's Clarifications Q2). The store text
names no measured figure, no speed and no memory value, and makes no claim beyond what the code holds.

## Text

**Effects Composer** — build a look from a chain of shader effects, see it on your picture as you edit, and export it
at full size, inside VisualCore.

Five built-in effects: Color grade (exposure, contrast and saturation), Blur, Distort, Vignette and Posterize. Put up
to eight of them in a chain, in the order you choose; move each one earlier or later, switch it off and on, and step
its values with buttons. Nothing needs dragging.

The preview shows every edit at the next frame, and every edit can be undone and redone. Show original compares the
look with the untouched picture.

Work on the built-in test picture, made in code, or choose one of your own photos with the system photo picker. The
app receives only the picture you pick, keeps it in memory while you work and never stores it.

Color grade, Blur and Vignette work on linear light values, decoded from sRGB and encoded again, so brightening,
softening and darkening follow the light of the picture; Distort and Posterize work on the stored values.

Save up to 24 named looks on your device, open one later as a single edit you can undo, and remove them. A look file
that cannot be read is listed with its reason and never removed by itself.

Export the shown picture at its full size, up to 2,048 pixels on the longer edge, as PNG, JPEG or HEIC where the
device can write the format, tagged sRGB, and share it through the system share sheet. If you choose Save Image there,
the system asks to add the picture to your photo library. Nothing is sent otherwise: Effects Composer works offline,
and a picture leaves your device only through an export you share.

The controls have spoken labels for VoiceOver that name the effect, its place in the chain and its value, and each
effect offers named actions to move it, switch it and change its values.

## Traceability

| Claim | Proving test |
|---|---|
| Five built-in effects: Color grade (exposure, contrast, saturation), Blur, Distort, Vignette and Posterize | `DefinitionTests.swift libraryListsFiveEffectsInOrder`; `DefinitionTests.swift parameterTableMatchesClarification`; `ReferenceTests.swift eachFormulaGivesItsSpotValues`; `ProgramRenderTests.swift theProgramMatchesItsReference` |
| Up to eight effects in a chain, in any order; move, switch off and on, and step values with buttons | `ChainTests.swift capsAndRefusals`; `ComposerCoreTests.swift addRemoveMoveAndEnableEditTheChain`; `ComposerCoreTests.swift setMapsTheFractionToTheRangeAndRoundsWholeParameters`; `OrderTests.swift theOrderChangesThePictureAndUndoingRestoresItByteForByte`; `IdentityTests.swift aChainWithOneMoreDisabledEffectDrawsTheSamePicture`; `PreviewDrawTests.swift moveAndRemoveShowAtTheNextFrameWithDistort` |
| The preview shows every edit at the next frame; every edit can be undone and redone | `PreviewDrawTests.swift addSetAndEnableShowAtTheNextFrame`; `PreviewDrawTests.swift undoRestoresThePictureByteForByteAndRedoReturnsIt`; `HistoryTests.swift everyEditUndoesToTheStartAndRedoesToTheEnd`; `ComposerCoreTests.swift undoAndRedoFollowTheHistory` |
| Show original compares the look with the untouched picture | `CompareTests.swift onShowsTheSourceAndOffTheResult`; `CompareTests.swift anEmptyChainShowsTheSourceEitherWay`; `CompareTests.swift compareIsNeitherDigestedNorStored` |
| The built-in test picture made in code, or one of your own photos from the system photo picker; the picture is kept in memory and never stored | `ReferenceTests.swift theTestImageHasTheBytesOfClarificationQ4`; `PictureSourceTests.swift anImportedPictureBecomesTheSourceAndTheChainAppliesToIt`; `PictureSourceTests.swift useTestPictureReturnsTheBuiltInPicture`; `PictureSourceTests.swift aRestoredSessionShowsTheTestPicture`; `PictureSourceTests.swift aRefusedImportLeavesTheSourceAndShowsTheMessage`; `ImageImportTests.swift orientation`; `ImageImportTests.swift downsize`; `ImageImportTests.swift damaged` |
| Color grade, Blur and Vignette on linear light values; Distort and Posterize on stored values | `ColorDomainTests.swift eachEffectHasItsDomain`; `ColorDomainTests.swift theTransferFunctionsRoundTripEveryByte`; `ColorPathTests.swift midGreyExposureMatchesTheLinearReference`; `ColorPathTests.swift blurAcrossAnEdgeAveragesLight`; `ColorPathTests.swift everyEffectMatchesTheReferenceWithThePathsStorage` |
| Up to 24 named looks on the device; open one as a single undoable edit; remove them; an unreadable file is listed with its reason and kept | `LookLibraryTests.swift saveOpenRenameAndRemoveRoundTrip`; `LookLibraryTests.swift refusedSavesAndRenamesChangeNothing`; `LookLibraryTests.swift unreadableFilesAreListedAndKeptByteIdentical`; `LookLibraryTests.swift aNewerIndexMakesTheLibraryReadOnly`; `PresetPresenterTests.swift openingAPresetIsOneUndoableEdit`; `ComposerRecoveryTests.swift aFailedDrawLeavesTheLooksAndANewSessionOpensThem` |
| Export at full size, up to 2,048 pixels on the longer edge, as PNG, JPEG or HEIC where the device can write it, tagged sRGB; shared through the system share sheet | `StillExportTests.swift eachFormatWritesADecodableSRGBFile`; `StillExportTests.swift sizeLimits`; `StillExportTests.swift unavailableFormatIsRefusedFirst`; `StillExportTests.swift fileNames`; `StillExportTests.swift regressionFixture`; `StillExportTests.swift refusalsBeforeDrawing`; `StillExportTests.swift oneFileAtATime`; `StillExportTests.swift closingRemovesTheFolder`; `RobustnessTests.swift aWrittenExportSurvivesAContextRebuild` |
| Works offline; a fresh start is ready on the test picture with an empty chain, no export to share and no saved look; the chain of the last session comes back | `ComposerCoreTests.swift theOpeningStateIsAnEmptyChainWithoutOutcome`; `ComposerCoreTests.swift theSnapshotRoundTripsTheChainAndARestoredCoreHasAnEmptyHistory`; `ECManifestTests.swift theSaveRestoreStateSurvivesARestore`; `ECReleaseUITests` |
| Spoken labels that name the effect, its place and its value; named actions to move, switch and change values | `ComposerCoreTests.swift theSpokenLabelsNameTheEffectItsPositionAndTheValue`; `AccessibilityActionTests.swift theActionsOfTheFirstAMiddleAndTheLastNode`; `AccessibilityActionTests.swift applyingEachChangesTheChainAsNamedAndRedraws`; `ECReleaseUITests` |

The source scan of the experience (`scan-sources`, T-A25-603) proves that no network, tracking, sensor, recording,
sound input, photo-library, `UIPasteboard`, idle-timer or brightness use is in
`Packages/ExperiencesCreative/EffectsComposer`, and that `PhotosUI`, `PhotosPicker` and `ShareLink` appear only in
`Experience/ECControls.swift` (`.autonomy/checks/A25-P06.scan-sources.json`). The only permission the experience can
lead to is the add-only Photos prompt, which the system shows when the person chooses Save Image in the share sheet
(`"permissions": ["photo-library-add"]` in `Catalog/registrations.json`; the usage string is checked by the app's
`BundleTests`). See [privacy-and-credits.md](privacy-and-credits.md) and [licenses.md](licenses.md). No speed, memory,
export time, heat or device figure is stated. The interface test of chunk `h3` (`ECReleaseUITests`; T-A25-608) proves
the first session through the app's controls on the iOS 27 phone simulator; it is a simulator result, not a device
measurement. Device measurements wait for the device campaign ([device-campaign.md](device-campaign.md)).
