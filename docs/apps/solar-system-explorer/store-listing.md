# Solar System Explorer — store text input

This is an input for the owner, who enters the App Store text of the VisualCore app; the agent never enters anything
in App Store Connect ([build-and-archive.md](../../release/build-and-archive.md) section 5). Solar System Explorer is an
experience of the free tier of VisualCore (`tier: free` in `Catalog/experiences.json`), not a separate app. Feature 108
(A14-P06), FR-A14-620 and FR-A14-621 (research D2).

Every sentence below describes something that exists in the controls (`SolarSystemExplorer/Experience/SolarControls.swift`),
the canvas (`SolarPresenter.swift`) or the model (`SolarSystemExplorer/Core`), and is exercised by the tests named in
the traceability table. The text is checked by `scripts/check_copy_claims.py` with `Configs/copy-claims-denylist.json`
(one word is allowed for this experience, `camera` in `copyCheck.allow` of [release.json](release.json): the
experience's view has a virtual camera that the controls orbit, tilt and zoom; the device camera is never used) and by
the experience's own word scan of T-A14-608 (`specs/108-sse-p06-release/scan-claims-release.sh`, the refused words of
the spec's Clarifications Q2). The store text names no performance figure and no value from a device; it describes an
approximate model of the solar system.

## Text

**Solar System Explorer** — the Sun and the eight planets on approximate orbits, drawn entirely by code, inside
VisualCore.

Choose any of the nine bodies from the Body menu, or step through them in order from the Sun to Neptune, and the view
flies to the body you choose. Orbit around it, tilt and zoom, and Reset view returns to the overview.

Step the date by 1, 30 or 365 days in either direction, or press Play and let time run at one of four rates,
from a day to a year each second. Now jumps to today's date. Dates run from 1950 to 2050.

Positions come from an approximate model: Kepler orbits from the planets' mean elements at J2000.0. It is not an
ephemeris. The model is checked against published Mars oppositions and Earth perihelia, and each falls within three
days of its published date. About this model says so in the app.

Two scales: Enhanced enlarges sizes and distances so that every planet can be seen, and says on screen that it is not
to scale. True relative draws distances and sizes to one scale and marks the bodies too small to see.

Every body has a fact card: its radius and axial tilt and, for a planet, the size and period of its orbit and its
distance from the Sun on the date shown, each number with its unit and its source. Every number shown comes from
public-domain NASA, IAU and JPL sources.

Saturn wears its rings, each planet has its own procedural surface, and labels name the bodies and never overlap.

Take a guided tour of the inner planets or the giant planets. Each stop has a caption with the body's numbers; skip to
the next stop, pause or stop the tour whenever you like.

Save view keeps the body, the date, the rate, the view and the scale on your device, and Restore view brings them back.
A saved view that cannot be read is reported and left as it is.

With Reduce Motion on, the view cuts straight to each body and each tour stop instead of flying.

VoiceOver reads every control with its value and describes the canvas with the date, the distance and the scale.
While time plays, the date is announced at most once every ten seconds.

The experience reopens where you left it and holds still while you are away. Nothing is sent anywhere.

## Traceability

| Claim | Proving test |
|---|---|
| The Sun and the eight planets, drawn entirely by code | `SolarRenderTests.swift testADrawnFrameWithTheSunEarthAndNeptuneSelectedIsNonBlank`; `SolarRenderTests.swift testTheExperienceNeverCreatesAGraphicsContextOfItsOwn`; `SolarRenderTests.swift testTheRecipeColoursAreProceduralAndDeterministic`; `BodyCatalogTests.swift thereAreNineBodiesInOrder` |
| Choose any body from the Body menu or step through them from the Sun to Neptune | `SolarStateTests.swift selectingAcceptsOnlyTheNineBodies`; `SolarStateTests.swift nextAndPreviousStepAndStopAtTheEnds`; `SolarSessionTests.swift testTheSessionOpensWithNineBodiesInCatalogOrderAndTheSunSelected`; `SolarRenderTests.swift testChangingTheSelectionChangesTheDrawnPixelsAndTheCard` |
| The view flies to the chosen body | `SolarOrbitRenderTests.swift testFocusingABodyMovesTheCameraOntoIt`; `FocusFlightTests.swift testEveryOrderedPairKeepsTheEyeOutsideAndTheFocusInsideTheDepthRange`; `FocusFlightTests.swift testFramesAreClampedAndEndpointsExact` |
| Orbit, tilt and zoom; Reset view returns to the overview | `SolarOrbitRenderTests.swift testTheCameraActionsChangeTheViewAndResetRestoresIt`; `SolarStateSchema2Tests.swift cameraStepsStayInTheirRanges`; `SolarStateSchema2Tests.swift resetKeepsSelectionAndDate` |
| Step the date by 1, 30 or 365 days in either direction | `SimulatedDateTests.swift hundredStepsForwardAndBackReturnExactly`; `SolarStateSchema2Tests.swift dateStepsAreAcceptedOrRefusedWithTheirCodes`; `SolarOrbitRenderTests.swift testADateStepOf365DaysChangesTheDrawnPixels` |
| Play at one of four rates, from a day to a year each second | `SimClockTests.swift ratesLabelsAndConstants`; `SolarStateSchema4Tests.swift playingAdvancesExactlyAndPausedDoesNot`; `SolarTimeTourSessionTests.swift testPlayingAtOneYearPerSecondMovesEarthAndAdvancesTheDateByAYear` |
| Now jumps to today's date | `SolarTimeTourSessionTests.swift testNowSetsTheDateFromTheInjectedClock` |
| Dates run from 1950 to 2050 | `SimulatedDateTests.swift rangeEndsAcceptedAndOneStepBeyondRefused`; `SolarStateSchema4Tests.swift playingStopsAtTheRangeEndWithTheReason`; `SimClockTests.swift aStepPastTheUpperEndClampsAndStops` |
| An approximate model: Kepler orbits from mean elements at J2000.0; not an ephemeris; About this model says so | `OrbitFixtureTests.swift earthLongitudeAtJ2000`; `OrbitFixtureTests.swift everyPlanetReturnsAfterOnePeriod`; `OrbitElementsTests.swift storedValuesAreTheClarifiedOnes`; `ScientificReviewTests.swift theModelStatementIsClarificationQ3`; `SolarQualityTests.swift testTheControlsShowTheModelStatement` |
| Checked against published Mars oppositions and Earth perihelia, each within three days | `EventChecksTests.swift theSevenFixturesAreBundled`; `EventChecksTests.swift eachEventIsWithinItsTolerance`; `EventChecksTests.swift aBrokenFixtureDoesNotPass`; `ScientificReviewTests.swift theCommittedReviewMatchesTheModel` |
| Enhanced enlarges and says it is not to scale; True relative is to one scale and marks bodies too small to see | `ScaleModeTests.swift theEnhancedModeKeepsTheOrbitViewMapping`; `ScaleModeTests.swift theTrueRelativeModeKeepsTheCatalogRatios`; `TruthfulLabelTests.swift everyEnhancedDescriptionSaysNotToScaleAndNoTrueRelativeOneDoes`; `OrbitLayoutTests.swift testMarkersAreChosenBelowTwoPixelsInTheTrueRelativeModeOnly`; `SolarBodiesRenderTests.swift testSwitchingTheScaleModeChangesThePixelsTheControlAndTheWords` |
| Fact cards: radius, axial tilt, orbit size and period and distance from the Sun, each number with its unit and source | `BodyCatalogTests.swift factCardsCarryUnitsAndSources`; `SolarCoreTests.swift testDistanceWordsAgreeInAUAndKm`; `UnitsTests.swift everyCatalogValueAgreesInBothUnits` |
| Every number comes from public-domain NASA, IAU and JPL sources | `CitationAuditTests.swift everyStoredValueHasOneRecord`; `CitationAuditTests.swift theBundledCatalogHasNoProblems`; `CitationAuditTests.swift theCommittedDataSourcesDocumentMatchesTheCatalog`; `CitationAuditTests.swift theOrbitalElementsAreAudited`; `RingRecordTests.swift theRingSourcesAreAudited` |
| Saturn wears its rings | `SceneMeshesTests.swift testSaturnsRingIsTwoSidedWithTheRecordsRatios`; `SolarBodiesRenderTests.swift testSaturnsRingIsVisibleAroundSaturn`; `RingRecordTests.swift saturnsRingsHaveTheFactSheetValuesInOrder` |
| Each planet has its own procedural surface | `SurfaceRecipeTests.swift digestsAreStableAndPairwiseDistinct`; `SurfaceRecipeTests.swift earthHasOceanLandAndPolarWhite`; `SceneMeshesTests.swift testTheBodySpheresCarryTheirRecipeColours`; `SolarBodiesRenderTests.swift testEarthAndJupiterAreDrawnInTheirColours` |
| Labels name the bodies and never overlap | `LabelLayoutTests.swift testAtTheOverviewSeveralLabelsArePlacedAndNoneOverlap`; `LabelLayoutTests.swift testTheFocusedBodyIsPlacedFirstThenByDistanceAndOverlapsAreSkipped` |
| Guided tours of the inner and the giant planets with captions; next stop, pause, stop | `ToursTests.swift twoToursWithTheStatedStopsInOrder`; `ToursTests.swift captionsReadAsSpecified`; `ToursTests.swift captionNumbersAreStoredCatalogValuesOfTheBody`; `SolarStateSchema4Tests.swift pauseNextAndStop`; `SolarTimeTourSessionTests.swift testATourVisitsItsStopsInOrderWithTheCaptionAndHoldsSkipsAndStops` |
| Save view keeps body, date, rate, view and scale on the device; Restore view brings them back | `SavedViewTests.swift roundTripAndSortedKeyText`; `ViewStoreTests.swift testASavedViewLoadsBackIdentical`; `SolarStateSchema4Tests.swift aSavedViewAppliesAndStopsTheTour`; `SolarTimeTourSessionTests.swift testSaveChangeAndRestoreReturnTheViewAndRefusedFilesChangeNothing` |
| A saved view that cannot be read is reported and left as it is | `ViewStoreTests.swift testDamagedNewerAndOversizedFilesAreRefusedAndLeftUntouched`; `SavedViewSampleTests.swift testTheRefusedSamplesAreRefusedAndUntouched`; `SavedViewTests.swift damagedDocumentsAreRefused`; `SavedViewTests.swift oversizedIsRefusedFirst` |
| With Reduce Motion, the view cuts straight to each body and each tour stop | `FocusFlightTests.swift testReduceMotionCutsToTheNewViewAtOnce`; `SolarBodiesRenderTests.swift testReduceMotionCutsTheFlightAndAFlightRestartsFromTheCurrentView`; `SolarTimeTourSessionTests.swift testWithReduceMotionTheCameraCutsToEachTourStop` |
| VoiceOver reads every control with its value | `SolarRenderTests.swift testTheWordsOfTheControls`; `SolarQualityTests.swift testTheControlsShowTheModelStatement` |
| The canvas is described with the date, the distance and the scale | `SolarCoreTests.swift testTheCanvasDescriptionFollowsClarificationsQ4AndQ5`; `SolarCoreTests.swift testTheCanvasDescriptionIsTruthfulInAllSampledStates`; `TruthfulLabelTests.swift noTourCaptionOrClockWordClaimsAScale` |
| While time plays, the date is announced at most once every ten seconds | `AnnouncementLimiterTests.swift testThePeriodicDatePassesAtMostOnceEveryTenSeconds`; `AnnouncementLimiterTests.swift testEventAnnouncementsAlwaysPass`; `AnnouncementLimiterTests.swift testAnEventRestartsTheInterval` |
| Reopens where you left it | `SolarSessionTests.swift testTheSavedStateRestoresIdenticallyInANewSession`; `SolarCoreTests.swift testTheSnapshotRestoresIdenticallyInAnotherEngine`; `SolarCoreTests.swift testASchema1EnvelopeMigrates` |
| Holds still while you are away | `SolarSessionTests.swift testASuspensionChangesNothing`; `SolarTimeTourSessionTests.swift testWhileSuspendedAndDrawingTheDateDoesNotMove` |
| Nothing is sent anywhere | `ViewStoreTests.swift testASavedViewLoadsBackIdentical`; `ViewStoreTests.swift testWithoutStorageTheViewIsKeptInMemory` |

The source scan of the experience (`sse-no-network`, T-A14-603) also proves that nothing is sent: no network,
tracking, sensor, recording, brightness or idle-timer use is in `Packages/ExperiencesCreative/SolarSystemExplorer`
(`.autonomy/checks/A14-P06.sse-no-network.json`). See [privacy-and-credits.md](privacy-and-credits.md) and
[scientific-review.md](scientific-review.md). No speed, timing or device claim is made. The interface tests of chunk
`v2` (`SSEViewUITests`, `SSETourUITests`; T-A14-609) prove the journeys through the app's controls on the iOS 27 phone
simulator; they are simulator results, not device measurements. Device measurements wait for the device campaign
([device-campaign.md](device-campaign.md)).
