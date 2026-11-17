# Interactive Anatomy — store text input

This is an input for the owner, who enters the App Store text of the VisualCore app; the agent never enters anything
in App Store Connect ([build-and-archive.md](../../release/build-and-archive.md) section 5). Interactive Anatomy is an
experience of the free tier of VisualCore (`tier: free` in `Catalog/experiences.json`), not a separate app. Feature 129
(A17-P06), FR-A17-605 and FR-A17-606.

Every sentence below describes something that exists in the controls
(`InteractiveAnatomy/Experience/AnatomyControls.swift`), the canvas (`AnatomyPresenter.swift`), the label overlay
(`AnatomyOverlay.swift`), the adapter's words (`Experience/Adapter/AnatomyCore.swift`), the review words
(`Core/AnatomyReview.swift`) or the content (`Core/Content/knee-right.pack.json`), and is exercised by the tests named
in the traceability table. The text is checked by `scripts/check_copy_claims.py` with
`Configs/copy-claims-denylist.json` (one word is allowed for this experience, `camera` in `copyCheck.allow` of
[release.json](release.json): it means the orbit camera of the 3D view and nothing else) and by the
experience's own word scan of T-A17-607 (`specs/129-ia-p06-release/scan-claims-release.sh`, the refused words of the
spec's Clarifications Q2). The store text names no performance figure and no value from a device, and makes no claim
beyond what the content and the code hold.

## Text

**Interactive Anatomy** — a labelled 3D model of the right knee, made entirely in code, with layers, search and cited
plain-language descriptions, inside VisualCore. Educational, not medical.

Schematic model for learning; shapes are simplified. Fourteen parts of the right knee in three layers: the bones
(femur, tibia, fibula and patella), the cartilage and menisci, and the ligaments and tendons. Show or hide each layer.

Select a part by tapping it in the model or by choosing it in the list. The view frames the part, and the panel shows
its English name, its standard name, its layer, a short description of its form, position and connections, and its
citations.

Search by name or by a common name such as "Kneecap", "Shin bone" or "ACL"; capitals and accents are ignored.

Isolate the selected part or a whole layer, with the rest drawn faintly as ghosts or hidden; Show all ends the
isolate.

Turn, tilt and zoom the camera with a drag and a pinch, or with the Turn, Tilt and Zoom buttons; Reset view returns
the camera to its opening position.

Name labels sit beside the parts in the model. When labels would overlap, some are skipped, so the model may show
fewer names than parts; the list always names every part.

The text of every part cites Gray's Anatomy, 20th edition (1918, public domain), and Terminologia Anatomica (1998) for
the standard names; the descriptions are written for this experience. Not reviewed by a clinician.

Each layer has a sign as well as a colour (●, ◆ and ▲), so colour is never the only cue. VoiceOver reads every control
and announces each selection, every gesture has a button, and nothing in the model moves on its own.

The experience reopens with the view you left. The content is bundled with the app, and nothing is sent anywhere.

## Traceability

| Claim | Proving test |
|---|---|
| A 3D model of the right knee made entirely in code | `SceneBuildTests.swift everyDeclaredMeshHasAPlacementOfItsKind`; `SceneBuildTests.swift everyMeshValidatesAndIsClosedAtBothLevels`; `BundledRegionTests.swift theManifestIsLicensedAndNotReviewed`; `AnatomySessionTests.swift testTheSessionOpensRunningAndDrawsANonBlankFrame` |
| Educational, not medical: the descriptions state form, position and connections only, and clinical text is refused | `ContentValidationTests.swift clinicalTextIsRefused`; `BundledRegionTests.swift theBundledKneeLoadsAndValidates` |
| "Schematic model for learning; shapes are simplified." is shown with the model | `ReviewRecordTests.swift theModelStatementAndTheLinesWithoutARecord`; `IAExploreUITests` (the About row shows the model statement) |
| Fourteen parts in three layers; show or hide each layer | `BundledRegionTests.swift everyPartHasASourceADescriptionMeshesAndItsLayer`; `SceneBuildTests.swift visibleItemsFollowTheLayers`; `AnatomyRenderTests.swift testHidingEachLayerChangesTheFrameAndStopsDrawingItsMeshes`; `IAExploreUITests` (switching off the bones layer marks the femur row hidden) |
| Select a part by tapping it in the model or choosing it in the list | `PickerTests.swift probeRaysReachEveryPartAndNeverAHiddenOne`; `AnatomyTapTests.swift testATapAtEachPartsCentreSelectsWhatThePickerReturns`; `AnatomyTapTests.swift testChoosingFromTheListEqualsTheTapThatPickedThePart`; `AnatomyListOnlyTests.swift testEveryPartIsSelectedFromTheListAloneWithThePanelAndTheAnnouncementOfATap` |
| The view frames the selected part | `CameraFramingTests.swift framingEveryPartKeepsItsSphereInView`; `AnatomyTapTests.swift testAfterSelectingEachPartItsCentreIsInsideTheView` |
| The panel shows the English name, the standard name, the layer, the description and the citations | `PanelTests.swift everyPartShowsItsNamesLayerDescriptionAndCitations`; `PanelTests.swift citationsReadTitleEditionSectionAndLicense`; `IAExploreUITests` (choosing "Femur" shows "Femur", a citation and "Not reviewed by a clinician.") |
| Search by name or common name ("Kneecap", "Shin bone", "ACL"); capitals and accents ignored | `SearchTests.swift everyNameAndSynonymFindsItsPartFirst`; `SearchTests.swift caseAccentsSpacesAndWordPrefixesAreIgnored`; `SearchTests.swift contentVersionTwoCarriesTheCommonNames`; `AnatomySearchSessionTests.swift testSynonymsSelectTheirParts`; `IASearchUITests` (typing "ACL" and choosing the first result selects the anterior cruciate ligament) |
| Isolate the selected part or a layer, the rest ghosted or hidden; Show all ends the isolate | `IsolateTests.swift everyTargetAndModeGivesTheRuleSets`; `AnatomyIsolateRenderTests.swift testEachIsolateInBothModesDrawsTheCoresSolidAndGhostSets`; `AnatomyIsolateRenderTests.swift testIsolateClearRestoresThePhaseTwoFrameExactly`; `IASearchUITests` (Isolate selected, then Show all) |
| Turn, tilt and zoom with a drag, a pinch or the buttons; Reset view returns the camera to its opening position | `CameraFramingTests.swift resetRestoresTheOpeningView`; `AnatomyGestureTests.swift testDragLengthsGiveTheStatedTurnAndTiltSteps`; `AnatomyGestureTests.swift testPinchScalesGiveTheStatedZoomSteps`; `AnatomyGestureTests.swift testADragThroughTheSessionEqualsTheButtons`; `AnatomyRenderTests.swift testEachCameraStepChangesTheFrameAndResetRestoresTheOpeningFrame` |
| Name labels beside the parts; overlapping labels are skipped; the list names every part | `AnatomyLabelTests.swift testOverAGridOfCamerasNoLabelsOverlapAndTheSelectionIsPlaced`; `AnatomyLabelTests.swift testGhostedAndHiddenPartsGetNoLabel`; `AnatomyLabelTests.swift testADrawnFrameLaysTheLabelsOutAndTheMirrorNamesThem`; `AnatomyListOnlyTests.swift testEveryPartIsSelectedFromTheListAloneWithThePanelAndTheAnnouncementOfATap` |
| Every part cites Gray's Anatomy (1918, public domain) and Terminologia Anatomica (1998); the descriptions are original | `ContentPackTests.swift theBundledPackLoadsAndValidates`; `ProvenanceTests.swift theBundledProvenanceIsComplete`; `ContentValidationTests.swift badLicensesAreRefused`; `SourcesDocumentTests.swift theCommittedSourcesDocumentMatchesTheContent` |
| Not reviewed by a clinician | `ReviewRecordTests.swift theBundledRecordHasOneEditorialEntryPerPartAndNoClinicalEntry`; `AnatomyListOnlyTests.swift testARefusedReviewRecordLeavesOnlyTheNotReviewedLineAndIsCounted`; `AnatomySearchSessionTests.swift testThePanelOfTheSelectionHasACitationAndTheReviewSentence`; `IAExploreUITests` |
| Each layer has a sign as well as a colour | `LayerSignTests.swift everyLayerHasItsSignWordsAndColour`; `LayerSignTests.swift theSignsPassTheStateSignCheck` |
| VoiceOver reads every control and announces each selection | `AnatomyAnnouncementTests.swift testFiveQuickSelectionsAreRateLimitedAndTheLastIsAlwaysAnnounced`; `AnatomyAnnouncementTests.swift testAClearIsAnnounced`; `AnatomyCoreTests.swift testTheCanvasDescription` |
| Every gesture has a button | `AnatomyGestureTests.swift testEveryGestureActionHasANativeControl` |
| Nothing in the model moves on its own | `AnatomyAnnouncementTests.swift testWithReduceMotionSelectingFramesThePartInTheSameFrame`; `AnatomyAnnouncementTests.swift testWithoutReduceMotionNothingAnimatesEither`; `AnatomyCoreTests.swift testHostStepsAndResetChangeNothingUnexpected` |
| Reopens with the view you left | `AnatomyViewFileTests.swift testAcceptedActionsWriteTheFileAndANewSessionOpensWithIt`; `AnatomySessionTests.swift testTheSavedStateRestoresInANewSession`; `ViewDocumentTests.swift aViewRoundTripsExactly`; `AnatomyViewFileTests.swift testDamagedNewerForeignAndOversizedFilesLeaveTheOpeningView` |
| The content is bundled and nothing is sent anywhere | `NoNetworkTests.swift noInteractiveAnatomySourceUsesTheNetwork`; `ContentPackTests.swift theBundledPackLoadsAndValidates` |

The source scan of the experience (`ia-no-network`, T-A17-603) also proves that nothing is sent: no network,
tracking, sensor, recording, photo-library, image-picker, brightness or idle-timer use is in
`Packages/ExperiencesCreative/InteractiveAnatomy` (`.autonomy/checks/A17-P06.ia-no-network.json`). See
[privacy-and-credits.md](privacy-and-credits.md), [content-sources.md](content-sources.md) and
[review.md](review.md). No speed, timing or device claim is made. The interface tests of chunk `y2`
(`IAExploreUITests`, `IASearchUITests`; T-A17-608) prove the journeys through the app's controls on the iOS 27 phone
simulator; they are simulator results, not device measurements. Device measurements wait for the device campaign
([device-campaign.md](device-campaign.md)).
