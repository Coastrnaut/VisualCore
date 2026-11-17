# Living Wallpapers — store text input

This is an input for the owner, who enters the App Store text of the VisualCore app; the agent never enters anything
in App Store Connect ([build-and-archive.md](../../release/build-and-archive.md) section 5). Living Wallpapers is an
experience of the free tier of VisualCore (`tier: free` in `Catalog/experiences.json`), not a separate app. Feature 143
(A19-P06), FR-A19-605 and FR-A19-606.

Every sentence below describes something that exists in the controls
(`LivingWallpapers/Experience/WallpaperControls.swift`), the editor model (`EditorModel.swift`), the help
(`HelpView.swift`, `Core/WallpaperHelp.swift`) or the adapter (`Experience/Adapter/WallpaperCore.swift`), and is
exercised by the tests named in the traceability table. The text is checked by `scripts/check_copy_claims.py` with
`Configs/copy-claims-denylist.json` ([release.json](release.json) allows only the word "share" through
`copyCheck.allow`, because the experience hands its file to the system share sheet) and by the experience's own word
scan of T-A19-607 (`specs/143-lw-p06-release/scan-claims-release.sh`, the refused words of the spec's Clarifications
Q2). The store text names no performance figure and no value from a device, and makes no claim beyond what the code
holds.

## Text

**Living Wallpapers** — design your own background in code and export it as a still at the exact size of your
iPhone or iPad screen, inside VisualCore.

Four scenes drawn in code: Aurora Bands, Ink Flow, Soft Cells and Ripple Dunes, each with three colour presets. Change
the scene's own settings, edit the four colours of a preset, or reset them to the preset.

Choose a device template: iPhone 16 Pro Max, iPhone 16 Pro, iPhone 16 Plus, iPhone 16, iPhone SE (3rd generation),
iPad Pro 13-inch (M4), iPad Pro 11-inch (M4), iPad Air 11-inch (M2) or iPad mini (A17 Pro), in portrait or landscape.
A frame shows the part of the picture the screen shows, with shaded bands where the time and controls may sit; the
bands are approximate.

Pick the moment of the scene to export, and turn motion off to see that moment still.

Export a still image as PNG, JPEG or HEIC (where the device can encode HEIC), at the template's pixel size and tagged
sRGB. Each file is read back and checked for its size and colour profile before it is kept, and the result line names
the format, the size and the profile. When the device cannot draw a template at its full size, a notice says so and
offers the largest size that fits at the same shape.

Follow the export's progress, cancel it, or retry it after a failure. A cancelled or failed export leaves no file.

Hand the exported file to the system share sheet to keep it where you choose. To use it as your wallpaper, set it
yourself in the Settings app; the help explains the steps. Living Wallpapers never changes your wallpaper.

Recent exports are listed on the device, and "Clear history" removes the list.

Every control has a spoken label and value for VoiceOver, each export outcome is announced once, and the controls stay
on screen at the largest text sizes.

Living Wallpapers reopens with the scene and settings you left.

## Traceability

| Claim | Proving test |
|---|---|
| Four scenes drawn in code (Aurora Bands, Ink Flow, Soft Cells, Ripple Dunes), each with three colour presets | `SceneCatalogTests.swift theCatalogHoldsFourScenesInOrder`; `SceneCatalogTests.swift everySceneHasThreePresetsOfFourOpaqueColours`; `SceneRenderTests.swift everySceneAtBothLevelsIsNotBlankAndRepeatsExactly`; `SceneRenderTests.swift scenesAndPresetsGiveDifferentPictures` |
| Change the scene's own settings | `SceneCatalogTests.swift everySceneHasTwoOrThreeParametersWithValidRanges`; `SceneRenderTests.swift aPresetOrParameterChangeSetsUniformsAndASceneChangeRebuilds`; `WallpaperCoreTests.swift everyControlIsAcceptedInsideItsRange` |
| Edit the four colours of a preset, or reset them to the preset | `ColourEditTests.swift everySlotEditChangesThePictureAndResetReturnsThePresetExactly`; `ColourEditTests.swift anotherPresetOrSceneClearsTheEdit`; `ProjectTests.swift customColoursRoundTripExactly` |
| Nine iPhone and iPad device templates, in portrait or landscape | `TemplateTests.swift nineTemplatesHaveTheExactSizes`; `TemplateTests.swift landscapeSwapsTheEdges`; `TemplateTests.swift everyTemplateRecordsItsProvenance` |
| A frame shows the part of the picture the screen shows, with approximate bands where the time and controls may sit | `CropOverlayTests.swift theFrameIsCropFrameFitForEveryTemplateAndOrientation`; `CropOverlayTests.swift theDrawnOverlayDimsOutsideTheFrameAndLeavesItsCentreClear`; `CropFrameTests.swift theBandsSitInsideTheFrameAtTheGuideFractions`; `TemplateTests.swift theSafeAreaGuidesAreTheApproximateFractions` |
| Pick the moment of the scene to export; motion off shows that moment still | `StillExportTests.swift twoAnimationTimesGiveDifferentFilesAndTheSameTimeIdenticalPixels`; `SceneRenderTests.swift withMotionOffTwoFrameTimesGiveTheSamePicture`; `SceneRenderTests.swift withMotionOnTwoFrameTimesDiffer` |
| PNG, JPEG or HEIC (where the device can encode HEIC), at the template's pixel size, tagged sRGB | `StillExportTests.swift everyAvailableFormatExportsAtAFittingTemplateAndVerifies`; `PlannerTests.swift aFittingTemplateIsPlannedAtItsExactSize`; `ShareFileTests.swift theContentTypeFollowsTheFormat`; `LWExportUITests` (the iPhone SE template exports with its result line) |
| Each file is read back and checked for its size and colour profile; the result line names format, size and profile | `ExportFixtureTests.swift everyFittingTemplateReadsBackAsPlanned`; `ExportFixtureTests.swift aWrongSizeIsReported`; `ExportFixtureTests.swift theProfileNameIsTheSystemSRGBName`; `ExportNoticeTests.swift theResultLineNamesFormatSizeAndProfile`; `NoticeAndResultTests.swift aWrittenExportGivesTheResultLineAndTheHelpOpensFromIt` |
| When the device cannot draw a template at its full size, a notice says so and offers the largest size that fits | `PlannerTests.swift templatesAboveTheLimitAreRefusedWithAFittingOffer`; `ExportNoticeTests.swift everyRefusedTemplateGetsANoticeWithItsNumbers`; `NoticeAndResultTests.swift theNoticeAndTheOfferedPlanFollowTheLimit`; `LWExportUITests` (a limit too small shows the notice and exports at the offered size) |
| Follow the progress, cancel, or retry after a failure; a cancelled or failed export leaves no file | `ExportJobTests.swift aSuccessfulJobPublishesEveryProgressValue`; `ExportJobTests.swift aCancelAfterEachStepLeavesNoFileAndNoGPUResource`; `ExportJobTests.swift aFailureNamesItsReasonAndRetryUsesTheOfferedPlan`; `StillExportTests.swift cancellingFailingAndRetryingLeaveNoGPUResourceAndNoFile` |
| Hand the exported file to the system share sheet | `ShareFileTests.swift theItemIsTheWrittenFile`; `ShareFileTests.swift thereIsNoItemWithoutAWrittenFile`; `ShareFileTests.swift theFileNameNamesSceneDeviceSizeAndFormat`; `LWExportUITests` (the Share button follows a written export) |
| You set it as your background yourself in the Settings app; the help explains the steps; the app never changes it | `HelpTests.swift thePersonSetsTheWallpaper`; `HelpTests.swift noRefusedPhraseOrPhaseAppears`; `NoticeAndResultTests.swift theHelpViewLaysOutTheThreeSections`; `LWClaimsUITests` (the editor, the result and their help claim nothing more) |
| Recent exports are listed on the device; "Clear history" removes the list | `HistoryStoreTests.swift aWrittenExportRecordsAnEntryAtTheFixedTime`; `HistoryStoreTests.swift entriesAreNewestFirstAndBounded`; `HistoryStoreTests.swift clearEmptiesTheHistoryAndRemovesTheFile`; `HistoryStoreTests.swift theControlsListTheNewestEntriesWithLabels`; `LWHistoryUITests` (an export listed in the history is removed by Clear history) |
| Spoken labels and values; each outcome announced once; controls on screen at the largest text sizes | `EditorAccessibilityTests.swift everyLabelIsNonEmptyAndNamesItsValue`; `EditorAccessibilityTests.swift eachExportOutcomeIsAnnouncedExactlyOnce`; `EditorAccessibilityTests.swift atAccessibilityFiveTheControlsStackWithinTheCanvas` |
| Reopens with the scene and settings you left | `WallpaperCoreTests.swift theSnapshotRoundTripKeepsTheDigest`; `SnapshotMigrationTests.swift theSchemaTwoExampleRoundTripsThroughTwoEngines`; `SnapshotMigrationTests.swift theSchemaOneExampleRestoresAsSchemaTwoWithCustomZero` |

The source scan of the experience (`lw-no-network`, T-A19-603) proves that no network, tracking, sensor, recording,
photo-library, image-picker, idle-timer or brightness use is in `Packages/ExperiencesCreative/LivingWallpapers`
(`.autonomy/checks/A19-P06.lw-no-network.json`). The only permission is the app's add-only Photos string, asked by the
system when the person chooses Save Image in the share sheet. See [privacy-and-credits.md](privacy-and-credits.md) and
[licenses.md](licenses.md). No speed, timing, heat, memory or device claim is made, and the size limit of a device is
not stated: it is measured in the device campaign. The interface tests of chunk `a3` (`LWExportUITests`,
`LWClaimsUITests`, `LWHistoryUITests`; T-A19-608) prove the journeys through the app's controls on the iOS 27 phone
simulator; they are simulator results, not device measurements. Device measurements wait for the device campaign
([device-campaign.md](device-campaign.md)).
