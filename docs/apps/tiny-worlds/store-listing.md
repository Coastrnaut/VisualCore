# Tiny Worlds — store text input

This is an input for the owner, who enters the App Store text of the VisualCore app; the agent never enters anything
in App Store Connect ([build-and-archive.md](../../release/build-and-archive.md) section 5). Tiny Worlds is an
experience of the free tier of VisualCore (`tier: free` in `Catalog/experiences.json`), not a separate app. Feature 094
(A12-P06), FR-A12-620 and FR-A12-621.

Every sentence below describes something that exists in the controls (`TinyWorlds/Experience/WorldsControls.swift`),
the gestures (`WorldsGestures.swift`), the canvas (`WorldsPresenter.swift`) or the world model (`TinyWorlds/Core`), and
is exercised by the tests named in the traceability table. The text is checked by `scripts/check_copy_claims.py` with
`Configs/copy-claims-denylist.json` (no word is allowed for this experience: `copyCheck.allow` in
[release.json](release.json) is empty) and by the experience's own word scan of T-A12-608
(`specs/094-tw-p06-release/scan-claims-release.sh`, the refused words of the spec's Clarifications Q2). The store text
names no number with a unit and no value from a device; it describes stylised miniature dioramas drawn by code, not
maps of any place.

## Text

**Tiny Worlds** — a gallery of miniature worlds, each grown from a seed and drawn entirely by code, inside VisualCore.

Choose an island, an asteroid garden or a miniature city. Each world is generated from its seed, and the same seed
always gives the same world. Ask for a new seed and a new world of the same kind appears. The land is coloured by its
height: shallows under the sea of the island and the city, and an asteroid that fades into the dark around it.

Open one of three ready-made packs — Island, Asteroid garden or Miniature city — each a composed scene with its own
props, light and view. Reset to pack brings the scene back after any change.

Drag to orbit around the world and pinch to zoom in or out. Every gesture also has a button: turn left and right, tilt
up and down, zoom in and out, and reset the view. The view always stays above the land and the props, and it eases to
each new position; with Reduce Motion on, it moves there directly.

Place up to 24 props of four kinds — tree, rock, house and lantern — and each one rests on the land. Tap a prop or use
the select buttons to choose it, then move it, turn it or delete it.

Set the direction of the sun and the ambient light, and watch the land and the props take the new light.

Save your worlds in four slots on your device, each with a small picture of the world, open them again exactly as they
were, and clear a slot when you no longer need it. A saved file that cannot be read is reported and left as it is.

VisualCore draws fewer details when the device needs it, and the world stays the same at every level; drawing never
changes the world.

VoiceOver describes the world: its name, its seed and the view, every edit and light change in words, and the place on
the land you tap.

The world reopens where you left it, and holds still while you are away. Nothing is sent anywhere.

## Traceability

| Claim | Proving test |
|---|---|
| Drawn entirely by code; every preset, palette, prop and pack is original content of the project | `LicenseAuditTests.swift theCommittedLicenseDocumentMatchesTheCatalog`; `LicenseAuditTests.swift theBundledCatalogHasNoProblems`; `WorldsRenderTests.swift testADrawnFrameOfEachPresetIsNonBlank`; `WorldsRenderTests.swift testTheExperienceNeverCreatesAGraphicsContextOfItsOwn` |
| An island, an asteroid garden or a miniature city | `TerrainGeneratorTests.swift thePresetsHaveTheirRecipes`; `TerrainGeneratorTests.swift theAsteroidGardenPlacesItsCratersAndMoundsFromTheSeed`; `TerrainGeneratorTests.swift theCityIsTerraced`; `WorldsRenderTests.swift testADrawnFrameOfEachPresetIsNonBlank` |
| Each world is generated from its seed; the same seed always gives the same world | `TerrainGeneratorTests.swift eachTerrainIsDeterministicWithinRangeAndBudget`; `TerrainFixtureTests.swift theDigestsOfSeedsOneTwoAndThreeEqualTheFixtures`; `GradientNoise2DTests.swift sameSeedAndPointGiveTheSameValue`; `HeightFieldTests.swift fieldsSharingAnEdgeAgreeBitForBit` |
| Ask for a new seed and a new world of the same kind appears | `WorldStateTests.swift aNewSeedComesFromTheGeneratorAndContinuesIt`; `WorldsCoreTests.swift testNewSeedsComeFromTheGenerator` |
| The land is coloured by its height: shallows under the sea, an asteroid that fades into the dark | `TerrainColoringTests.swift seaWorldsShadeTheLowLandUnderwaterAndBlendUpwards`; `TerrainColoringTests.swift theAsteroidEdgeFadesIntoTheVoid`; `WorldsRenderTests.swift testColouredLowAndHighLandDifferInTheFrame` |
| Three ready-made packs, each with its own props, light and view | `WorldPackTests.swift theBundledPackDataIsAsSpecified`; `WorldPackTests.swift eachPackAppliesWithItsComposition`; `WorldsPackTests.swift testPackDigestsEqualTheCommittedValues`; `WorldsPackTests.swift testADrawnFrameOfEachPackIsNonBlank`; `TWWorldUITests.swift testOpenPack` |
| Reset to pack brings the scene back after any change | `WorldsPackTests.swift testResetAfterEditsRestoresTheDigestExactly` |
| Drag to orbit, pinch to zoom | `WorldsGestureTests.swift testADragOrbitsByPointsMoved`; `WorldsGestureTests.swift testAPinchZoomsByTheScaleSinceTheLastEvent`; `WorldsGestureTests.swift testGesturesThroughTheShellMoveTheViewWithinTheLimits` |
| Every gesture also has a button: turn, tilt, zoom and reset the view | `WorldsGestureTests.swift testEveryGestureHasANativeControl`; `WorldsEditingTests.swift testEveryActionHasANativeControl`; `WorldViewTests.swift orbitWrapsYawAndClampsPitch`; `WorldViewTests.swift zoomDividesTheDistanceWithinItsRange`; `TWWorldUITests.swift testTurnAndZoom` |
| The view always stays above the land and the props | `CameraPolicyTests.swift theSweepStaysWithinLimitsAndKeepsTheClearance`; `WorldsCoreTests.swift testRestoredAndActedViewsKeepTheCameraPolicy`; `WorldPackTests.swift aPropNearTheEyeRaisesThePitch` |
| The view eases to each new position; with Reduce Motion on, it moves there directly | `WorldsRenderTests.swift testTheViewEasesToTheTargetIn035Seconds`; `WorldsRenderTests.swift testReduceMotionMovesTheViewDirectlyEvenMidEase`; `WorldsPackTests.swift testUnderReduceMotionThePackViewIsDrawnDirectly` |
| Up to 24 props of four kinds, each resting on the land | `WorldEditingTests.swift placedPropsRestOnTheDrawnTerrainAndKeepTheRules`; `WorldEditingTests.swift eachPlacementRefusalIsNamedAndChangesNothing`; `WorldsEditingTests.swift testTheTwentyFifthPropIsRefused`; `PropCatalogTests.swift everyPropMeshValidatesWithinItsBudget`; `WorldsRenderTests.swift testPlacedPropsAreDrawnWithTheirModelMatrices`; `TWEditUITests.swift testPlaceProp` |
| Tap a prop or use the select buttons to choose it, then move, turn or delete it | `WorldEditingTests.swift selectMoveRotateAndDeleteChangeOnlyTheSelectedProp`; `WorldEditingTests.swift aMoveSnapsToTheTerrainAndKeepsTheRules`; `WorldEditingTests.swift aRayPicksTheNearestPropByItsPickingBox`; `WorldsEditingTests.swift testATapSelectsAPropNearerThanTheGround`; `WorldsEditingTests.swift testPropActionsThroughTheEngineFollowTheRules` |
| The direction of the sun and the ambient light; the land and the props take the new light | `WorldLightTests.swift theDirectionFollowsAzimuthAndElevation`; `WorldsEditingTests.swift testTheLightActionsSetTheLight`; `WorldsRenderTests.swift testALitFaceIsBrighterThanAfterTheLightMovesAway` |
| Four slots on your device, each with a small picture, opened again exactly as they were | `WorldStoreTests.swift testSavingDrawsAThumbnailAndOpeningRestoresTheWorldExactly`; `WorldStoreTests.swift testASaveAndReadRoundTripIsBitIdentical`; `WorldStoreTests.swift testSavedWorldsRoundTripAcrossTiersAndPacks`; `TWEditUITests.swift testSaveWorld` |
| Clear a slot | `WorldStoreTests.swift testEmptyAndInvalidSlotsAndClearing` |
| A saved file that cannot be read is reported and left as it is | `WorldStoreTests.swift testRefusedFilesAreReportedAndLeftUntouched`; `WorldStoreTests.swift testAnInterruptedWriteKeepsThePreviousFileByteIdentical`; `WorldSampleFileTests.swift testTheCommittedSamplesOpenOrAreRefused`; `WorldsRecoveryDrawTests.swift testAFailedDrawLeavesSavedWorldsUntouched` |
| Fewer details when the device needs it; the world stays the same at every level | `WorldsQualityTests.swift testAMemoryWarningDrawsTheLowestTierUntilTheHoldEnds`; `WorldsQualityTests.swift testLowPowerModeDrawsTheLightestTierFromTheFirstFrame`; `TierPolicyTests.swift memoryWarningHoldsTheLowestTierForThirtySeconds`; `DetailTierTests.swift everyWorldPartAndPropIsDrawnAtEveryTier`; `WorldsRenderTests.swift testALevelChangeRebuildsOnlyTheTerrainRendererAndKeepsTheDigest` |
| Drawing never changes the world | `WorldsRenderTests.swift testDrawingNeverChangesTheState`; `WorldsRenderTests.swift testTurningTheViewChangesTheFrameAndNotTheTerrain` |
| VoiceOver describes the world's name, its seed and the view | `WorldsRenderTests.swift testTheDescriptionNamesTheWorldSeedAndView`; `WorldsRenderTests.swift testViewAnnouncementsAreSpokenAtMostOncePerSecond`; `WorldsSessionTests.swift testTheFirstFrameDrawsTheIslandAndDescribesIt` |
| Every edit and light change in words | `WorldsEditingTests.swift testEditingActionsAreAnsweredInWords`; `WorldsPackTests.swift testEveryActionHasAControlAndPacksAreAnsweredInWords` |
| The place on the land you tap is described | `WorldsGestureTests.swift testATapOnTheTerrainSpeaksAGroundPointAndChangesNothing`; `WorldsGestureTests.swift testATapOnTheSkySpeaksAMissAndChangesNothing` |
| The world reopens where you left it | `WorldsSessionTests.swift testTheSavedStateRestoresIdenticallyInANewSession`; `WorldsCoreTests.swift testTheSnapshotRestoresIdenticallyInAnotherEngine`; `WorldsEditingTests.swift testTheSchemaOneExampleMigrates` |
| Holds still while you are away | `WorldsSessionTests.swift testASuspensionChangesNothing` |
| Nothing is sent anywhere | `WorldStoreTests.swift testASaveAndReadRoundTripIsBitIdentical` |

The source scan of the experience (`tw-no-network`, T-A12-603) also proves that nothing is sent: no network, tracking,
sensor, recording, brightness or idle-timer use is in `Packages/ExperiencesCreative/TinyWorlds`. See
[privacy-and-credits.md](privacy-and-credits.md). No speed, timing or device claim is made. The interface tests of
chunk `t2` cited above (`TWWorldUITests`, `TWEditUITests`) prove the journeys through the app's controls on the iOS 27
phone simulator; they are simulator results, not device measurements. Device measurements wait for the device campaign
([device-campaign.md](device-campaign.md)).
