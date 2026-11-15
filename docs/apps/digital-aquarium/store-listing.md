# Digital Aquarium — store text input

This is an input for the owner, who enters the App Store text of the VisualCore app; the agent never enters anything
in App Store Connect ([build-and-archive.md](../../release/build-and-archive.md) section 5). Digital Aquarium is an
experience of the free tier of VisualCore (`tier: free` in `Catalog/experiences.json`), not a separate app. Feature 073
(A09-P06), FR-A09-620 and FR-A09-621.

Every sentence below describes something that exists in `DigitalAquarium/Experience/AquariumControls.swift`, the
gestures of `AquariumGestures.swift` or the canvas of `AquariumPresenter.swift`, and is exercised by the tests named in
the traceability table. The text is checked by `scripts/check_copy_claims.py` with `Configs/copy-claims-denylist.json`
(no word is allowed for this experience: `copyCheck.allow` in [release.json](release.json) is empty) and by the
experience's own word scan of T-A09-607. The store text names no number with a unit and describes the aquarium as a
drawing made by code.

## Text

**Digital Aquarium** — a calm underwater scene drawn entirely by code, inside VisualCore.

Choose between two starter habitats, Reef and Kelp, each with its own fish, plants and water colour. The fish swim in
schools, turn back at the glass and bend as they turn; the plants sway on the gravel.

Tap the water to drop food, or press Feed: a few pellets sink, and nearby fish swim over to them.

Decorate the floor with rocks and a spiral shell. Press and hold to place a piece, drag it to move it, and remove it
again; every gesture also has a button.

Bubbles rise from the vents, small motes drift through the water, and a rippling light pattern plays over the scene.
Set the lighting to soft, dim or bright, or pause the motion at any time.

Save the aquariums you arrange under a name and open them again later; they stay on your device. The aquarium also
resumes where you left it.

Turn on ambient mode for a slower, quieter scene that dims itself after a while without a touch; a tap brings the
light back. The screen brightness of your device is never changed. With Reduce Motion on, the swimming, swaying and
bubbles move less.

VoiceOver describes the habitat, the fish, the food and the decorations and announces changes as they happen; every
control has a label. VisualCore draws less detail when the device needs it.

Nothing is sent anywhere.

## Traceability

| Claim | Proving test |
|---|---|
| Two starter habitats, Reef and Kelp, each with its own fish, plants and water colour | `SpeciesCatalogTests.swift theBundledCatalogHasTwoStarterHabitatsOfTwoSpeciesEach`; `AquariumCoreTests.swift testTheOtherHabitatChangesFishPlantsAndWater`; `AquariumRenderTests.swift testTheTwoHabitatsDrawNonBlankFramesThatDiffer` |
| Drawn entirely by code; every bundled item is original content of the project | `LicenseAuditTests.swift theCommittedLicenseDocumentMatchesTheCatalog`; `LicenseAuditTests.swift theBundledCatalogHasNoProblems`; `SpeciesCatalogTests.swift everyBundledItemIsValidWithAuthorAndLicense` |
| Fish swim in schools | `SchoolingTests.swift reefFishSchoolWithinThirtySecondsForAtLeast18Of20Seeds`; `SchoolingTests.swift kelpFishSchoolWithinThirtySecondsForAtLeast18Of20Seeds` |
| Fish turn back at the glass | `AquariumSimulationTests.swift aFishAtACornerHeadingOutwardTurnsBackAndStaysInside`; `SchoolingTests.swift aLoneFishWandersAtHalfCruiseOrMoreAndStaysInside` |
| Fish bend as they turn | `AquariumRenderTests.swift testATurnBendsTheOutlineTowardTheTurn`; `AquariumRenderTests.swift testTwoMomentsOfASwimDrawDifferentOutlines` |
| Plants sway | `AquariumSessionTests.swift testReduceMotionHalvesTheSwayButNeverChangesTheState` |
| Tap the water to drop food | `AquariumGestureTests.swift testAQuickTapFeedsAtItsPointAndNothingElse`; `AquariumRenderTests.swift testAQuickTapOnTheCanvasDropsFoodOnce`; `FeedingTests.swift aFeedAddsThreePelletsAroundThePointClampedIntoTheBounds` |
| Or press Feed | `AquariumCoreTests.swift testFeedingAddsThreePelletsAndRefusesBeyondTwelve`; `AquariumRenderTests.swift testEveryGestureActionHasANativeControl` |
| Pellets sink; nearby fish swim over to them | `FeedingTests.swift pelletsSinkHalfAUnitPerSecond`; `FeedingTests.swift theSeekForcePointsAtTheNearestPelletWithinFourUnits`; `FeedingTests.swift aFishEatsExactlyItsNearestPelletWithinReach`; `FeedingTests.swift aFeedBesideTheReefSchoolIsEatenForAtLeast18Of20Seeds` |
| Rocks and a spiral shell | `SpeciesCatalogTests.swift theBundledDecorIsThreeKindsWithStarterPiecesOnTheGravel` |
| Press and hold to place a piece | `AquariumGestureTests.swift testAHoldOfSixTenthsPlacesAtThePressPointAndNeverFeeds` |
| Drag a piece to move it | `AquariumGestureTests.swift testADragFromAPieceMovesItWithTheFinger`; `AquariumGestureTests.swift testTheTopmostPieceIsMoved` |
| Place, move and remove | `DecorEditingTests.swift placeMoveAndRemoveGiveExactlyTheRequestedList`; `AquariumCoreTests.swift testDecorKindPlaceMoveAndRemove` |
| Every gesture also has a button | `AquariumRenderTests.swift testEveryGestureActionHasANativeControl` |
| Bubbles rise from the vents | `WaterEffectsTests.swift twoVentsGiveTwentyBubblesEachOnceSteady`; `WaterEffectsTests.swift aBubbleReachesTheSurfaceAndIsGoneByTheNextReleaseCycle`; `AquariumRenderTests.swift testBubblesAndMotesAreDrawnAtLeastOnePixelWide` |
| Small motes drift through the water | `WaterEffectsTests.swift motesDriftAndWrapAfterCrossingTheEdge`; `WaterEffectsTests.swift twentyFourMotesStayInsideTheWaterForOneMinute` |
| A rippling light pattern plays over the scene | `AquariumRenderTests.swift testTheCausticsChangeOverTimeAndHoldUnderReduceMotion`; `AquariumRenderTests.swift testABrokenCausticsShaderFallsBackAndTheFrameStillDraws` |
| Lighting soft, dim or bright | `AquariumRenderTests.swift testTheLightingChangesTheFrame`; `AquariumRenderTests.swift testDimCausticsAreFainterThanBright` |
| Pause the motion | `AquariumSessionTests.swift testFramesAdvanceTheFishAndPauseStopsThem`; `AquariumCoreTests.swift testHostStepsMoveTheFishUnlessPaused` |
| Save aquariums under a name and open them again later; they stay on your device | `AquariumLibraryTests.swift testSaveListOpenInANewSessionAndDelete`; `AquariumLibraryTests.swift testNamesAreCleanedAndDuplicatesAreKeptInOrder`; `AquariumLibraryTests.swift testTheThirteenthSaveIsRefusedWithNoNewFile` |
| The aquarium resumes where you left it | `AquariumSessionTests.swift testTheSavedStateRestoresIdenticallyInANewSession`; `AquariumSessionTests.swift testFoodDecorEditsAndTheChosenKindRestore`; `AquariumSessionTests.swift testASuspensionDoesNotFastForwardFishOrFood` |
| Ambient mode: a slower, quieter scene | `AquariumCoreTests.swift testAmbientModeIsSavedAndSlowsTheFish`; `AquariumSimulationTests.swift anAmbientRestingFishIsBroughtUpToTheScaledFloor`; `AquariumRenderTests.swift testAmbientHalvesTheDrawnParticles` |
| Dims itself after a while without a touch; a tap brings the light back | `AquariumRenderTests.swift testAmbientDimsAfterAMinuteAndATouchRestoresAlsoWhilePaused`; `AquariumRenderTests.swift testATapDuringDimmingRestoresTheBrightnessAndStillFeeds`; `AmbientDimmerTests.swift theBrightnessFadesAfterSixtySecondsOverTwoSeconds`; `AmbientDimmerTests.swift aTouchRestoresFullBrightnessAtOnce` |
| The screen brightness of your device is never changed | `AquariumRenderTests.swift testNoSourceSetsTheSystemBrightnessOrTheIdleTimer` |
| With Reduce Motion on, swimming, swaying and bubbles move less | `AquariumRenderTests.swift testReduceMotionHalvesEveryPointsDisplacement`; `AquariumSessionTests.swift testReduceMotionHalvesTheSwayButNeverChangesTheState`; `WaterEffectsTests.swift reduceMotionHalvesTheRiseAndRemovesTheWobble` |
| VoiceOver describes the habitat, the fish, the food and the decorations | `AquariumWordingTests.swift theReefStarterIsDescribedWithSpeciesCounts`; `AquariumWordingTests.swift emptyDecorFoodPausedAndLightingAreDescribed`; `AquariumRenderTests.swift testTheDescriptionNamesPelletAndDecorCounts`; `AquariumSessionTests.swift testTheFirstFrameDrawsTheReefAndDescribesIt` |
| Announces changes as they happen; every control has a label | `AquariumAnnouncementTests.swift testFeedingAnnouncesFoodDroppedOnceWithVoiceOver`; `AquariumAnnouncementTests.swift testTogglingAmbientAnnouncesIt`; `AquariumAnnouncerTests.swift theFirstAnnouncementSpeaksAndTheNextWithinTheIntervalWaits`; `AquariumRenderTests.swift testEveryGestureActionHasANativeControl` |
| Less detail when the device needs it | `AquariumBudgetTests.swift everyLevelAndAmbientGiveTheDocumentedBudget`; `AquariumRenderTests.swift testEachLevelDrawsNoMoreParticlesThanTheLevelAboveWithTheSameDigest`; `AquariumRenderTests.swift testLowPowerModeDrawsAmbientWithoutChangingTheState` |
| Nothing is sent anywhere | `AquariumRenderTests.swift testThePresenterOwnsALibraryOnlyWithStorage`; `AquariumLibraryTests.swift testSaveListOpenInANewSessionAndDelete` |

The source scan of the experience (`da-no-network`, T-A09-603) also proves that nothing is sent: no network, tracking,
sensor, brightness or idle-timer use is in `Packages/ExperiencesCreative/DigitalAquarium`. See
[privacy-and-credits.md](privacy-and-credits.md). No speed, timing, device or wellbeing claim is made. Device
measurements wait for the device campaign ([device-campaign.md](device-campaign.md)).
