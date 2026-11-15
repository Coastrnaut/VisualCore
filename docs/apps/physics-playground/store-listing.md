# Physics Playground — store text input

This is an input for the owner, who enters the App Store text of the VisualCore app; the agent never enters anything
in App Store Connect ([build-and-archive.md](../../release/build-and-archive.md) section 5). Physics Playground is an
experience of the free tier of VisualCore (`tier: free` in `Catalog/experiences.json`), not a separate app. Feature 087
(A11-P06), FR-A11-620 and FR-A11-621.

Every sentence below describes something that exists in `PhysicsPlayground/Experience/PlaygroundControls.swift`, the
gestures of `PlaygroundGestures.swift`, the canvas of `PlaygroundPresenter.swift` or the world model of
`PhysicsPlayground/Core`, and is exercised by the tests named in the traceability table. The text is checked by
`scripts/check_copy_claims.py` with `Configs/copy-claims-denylist.json` (no word is allowed for this experience:
`copyCheck.allow` in [release.json](release.json) is empty) and by the experience's own word scan of T-A11-607
(`specs/087-pp-p06-release/scan-claims-release.sh`, the refused words of the spec's Clarifications Q2). The store text
names no number with a unit and no value from a device; it describes a sandbox drawn by code whose numbers are an
educational approximation.

## Text

**Physics Playground** — a sandbox of circles, boxes and springs under gravity and drag, drawn entirely by code, inside
VisualCore.

Drop circles and boxes from the top of the stage, each made of rubber, wood, steel or ice, and watch them fall, bounce,
collide and stack. Up to 48 bodies fit on the stage, and none of them leaves it. Bodies that come to rest go to sleep
until something touches them.

Tap the empty stage to add a circle or a box, tap a body to select it, drag a body to grab it and let it go with its own
velocity, long-press a body to pin it in place, and double-tap a body to delete it. Every gesture also has a button:
previous and next body, Pin, Delete, Add at centre, Hold and four direction buttons.

Springs join bodies to each other or to a fixed point. Choose the spring stiffness (Soft, Medium, Stiff or Very stiff),
the gravity (Off, Moon or Earth) and the drag (None, Low or High).

Pause the world, advance it one step at a time while paused, or run it at quarter, half, normal or double speed; the
speed changes how fast the world runs, not where it ends up. Reset returns to the experiment as it opened.

Turn on velocity arrows and force arrows to see how each body moves and the weight and spring forces on it. A panel
headed “Educational approximation” shows the kinetic, potential, spring and total energy, the momentum and the speed of
the selected body; looking never changes the world.

Open a preset: Free play, Pendulum, Spring chain or Stacked objects. Save your own experiments with a name in four slots
on your device, open them again, and clear a slot when you no longer need it.

Two guided tutorials, Controlling time and Springs and energy, walk you through the controls step by step; each step
moves on when you have done what it asks.

The same actions always give the same world. VisualCore draws fewer details when the device needs it, and the world
stays the same at every level.

VoiceOver describes the world: the bodies, running or paused, the speed, the springs and levels, the selection and the
arrows, the opened experiment and the running tutorial step. The pickers name each level in words.

The playground resumes where you left it, and holds still while you are away. Nothing is sent anywhere.

## Traceability

| Claim | Proving test |
|---|---|
| Drawn entirely by code; every material, preset and tutorial is original content of the project | `LicenseAuditTests.swift theCommittedLicenseDocumentMatchesTheCatalog`; `LicenseAuditTests.swift theBundledCatalogHasNoProblems`; `LicenseAuditTests.swift presetsAndTutorialsFollowTheMaterialsWithTheirRoles`; `PlaygroundRenderTests.swift testTheFirstFrameIsNonBlankWithItsStageProbe` |
| Circles and boxes, each of rubber, wood, steel or ice, dropped from the top | `MaterialCatalogTests.swift theBundledMaterialsHaveTheirConstantsAndProvenance`; `WorldSimulationTests.swift dropsAreSeededAndRefusedAtTheCap`; `PlaygroundCoreTests.swift testDropsUseTheGeneratorAndStopAtTheCap` |
| Fall, bounce, collide and stack | `PhysicsFixtureTests.swift aRubberBallBouncesOnTheFloorAndNeverPassesThrough`; `PhysicsFixtureTests.swift twoEqualCirclesHeadOnKeepMomentumAndExchangeVelocities`; `StackFixtureTests.swift aFiveBoxStackStaysStandingForTenSeconds`; `ImpulseSolver2DTests.swift elasticHeadOnExchangesVelocities`; `Contacts2DTests.swift circleAgainstBoxFaceAndCorner` |
| Up to 48 bodies, and none leaves the stage | `WorldSimulationTests.swift dropsAreSeededAndRefusedAtTheCap`; `PhysicsFixtureTests.swift bodiesNeverLeaveTheStageWhenFilledToTheCap`; `WorldSimulationTests.swift theWallsLieJustOutsideTheStage` |
| Bodies at rest sleep until something touches them | `SleepTests.swift theStackFallsAsleepWithinThreeSecondsAndThenTestsNothing`; `SleepTests.swift aBodyDroppedOntoTheSleepingStackWakesItInTheTickItsBoundsReachIt`; `SleepTests.swift grabNudgePinAndDeleteWakeInTheSameEdit` |
| Tap the empty stage to add a circle or a box; tap a body to select it | `PlaygroundGestureTests.swift testATapOnTheEmptyStageAddsThePickedShapeAfterTheDoubleTapWindow`; `PlaygroundGestureTests.swift testATapOnABodySelectsItAndATapOutsideTheStageDoesNothing`; `WorldEditingTests.swift addPlacesTheSeededBodyCentredAtThePoint` |
| Drag a body to grab it and let it go with its own velocity | `PlaygroundGestureTests.swift testADragOnABodyGrabsMovesAndReleasesIt`; `WorldEditingTests.swift aGrabReachesAStillTargetWithinOneSecondAndReleaseKeepsTheVelocity`; `PlaygroundGestureTests.swift testASecondFingerOrACancelledTouchEndsTheGrab` |
| Long-press to pin a body in place; double-tap to delete it | `PlaygroundGestureTests.swift testALongPressOnABodyPinsIt`; `PinFixtureTests.swift aPinnedBodyHitForOneThousandTicksMovesByExactlyZero`; `PlaygroundGestureTests.swift testADoubleTapOnABodyDeletesItWithoutSelectingIt`; `WorldEditingTests.swift deleteRemovesTheBodyItsSpringsCacheEntriesGrabAndSelection` |
| Every gesture also has a button: previous and next body, Pin, Delete, Add at centre, Hold and four direction buttons | `PlaygroundSessionTests.swift testTheFirstFrameDrawsTheStartingSceneAndDescribesIt`; `PlaygroundGestureTests.swift testThePresenterDeclaresItsGesturesAndSendsThemThroughItsPort`; `PlaygroundRenderTests.swift testTheControlsWalkTheSelectionAndMoveAHeldBody`; `WorldEditingTests.swift nudgeAddsOneMetrePerSecondPerUnitWithinTheCaps` |
| Springs join bodies to each other or to a fixed point | `SpringWorldTests.swift theStartingSceneHasTheTwoSpringsAndTheDefaultLevels`; `PinFixtureTests.swift aSpringFromAPinnedBodySwingsTheOtherEnd`; `Springs2DTests.swift worldAnchorAndStaticEndsNeverMove`; `PlaygroundRenderTests.swift testSpringsAreDrawnAtTheirPhysicsAnchors` |
| Spring stiffness Soft, Medium, Stiff or Very stiff | `SpringWorldTests.swift aStifferLevelOscillatesFaster`; `Springs2DTests.swift stiffnessAndDampingAreClamped`; `PlaygroundCoreTests.swift testTheLevelActionsSetTheLevelsAndTheSettings` |
| Gravity Off, Moon or Earth; drag None, Low or High | `SpringWorldTests.swift gravityLevelsGiveTheStatedAcceleration`; `SpringWorldTests.swift dragLevelsGiveTheStatedDecay`; `SpringWorldTests.swift levelActionsRefuseOutOfRangeLevels` |
| Pause; advance one step at a time while paused | `WorldSimulationTests.swift pauseBlocksAdvanceAndSingleStepRunsExactlyOneTick`; `PlaygroundCoreTests.swift testASingleStepRunsExactlyOneTickOnlyWhilePaused`; `PlaygroundSessionTests.swift testFramesAdvanceTheWorldAndPauseStopsIt` |
| Quarter, half, normal or double speed; the speed changes how fast, not where it ends up | `WorldSimulationTests.swift everyTimeScaleGivesTheSameWorldAfterTheSameTicks`; `PlaygroundCoreTests.swift testEveryTimeScaleReachesTheSameWorldAfterTheSameTicks` |
| Reset returns to the experiment as it opened | `PlaygroundCoreTests.swift testResetReturnsToThePreparedWorld`; `PlaygroundCoreTests.swift testPresetsOpenAsTheStartingWorldAndResetReturnsToThem` |
| Velocity arrows and force arrows: the weight and spring forces | `PlaygroundRenderTests.swift testVelocityArrowsHaveTheStatedLengthsAndOnlyWhenOn`; `PlaygroundRenderTests.swift testForceArrowsShowWeightAndTheMeasuredSpringForce`; `ForceMeasurementTests.swift theGrabPullIsNotMeasuredAndWeightIsMassTimesG` |
| A panel headed “Educational approximation” with kinetic, potential, spring and total energy, momentum and the selected body's speed; looking never changes the world | `PlaygroundRenderTests.swift testThePanelEqualsTheDiagnosticsAndOverlaysNeverWriteTheWorld`; `WorldSimulationTests.swift diagnosticsMeasureEnergyAndMomentumWithoutChangingTheWorld`; `ForceMeasurementTests.swift measuringNeverChangesTheWorldAndARefusedTickKeepsTheMeasurement`; `PlaygroundRenderTests.swift testDrawingNeverChangesTheDigest` |
| Presets Free play, Pendulum, Spring chain and Stacked objects | `PresetTests.swift freePlayIsTheSeededStartingSceneWithTheSameDraws`; `PresetTests.swift thePendulumHasAPinnedPivotAndABobAtThirtyDegrees`; `PresetTests.swift theSpringChainHangsStraightDownAtRestLengths`; `PresetTests.swift theStackedObjectsRestOnEachOtherAndStandForFiveSeconds` |
| Save experiments with a name in four slots on your device and open them again | `ExperimentStoreTests.swift testSavingAndOpeningASlotThenResetReturnsToIt`; `ExperimentStoreTests.swift testASaveAndReadRoundTripIsIdenticalWithoutGrabAndSelection`; `ExperimentStoreTests.swift testNamesAreCutOrDefaulted`; `ExperimentStoreTests.swift testASlotOutsideZeroToThreeIsRefused` |
| Clear a slot | `ExperimentStoreTests.swift testAnEmptySlotIsRefusedAndClearingRemovesTheFile` |
| Two guided tutorials, Controlling time and Springs and energy; each step moves on when done | `TutorialTests.swift theTutorialsHaveTheirNamesAndSteps`; `TutorialTests.swift controllingTimeCompletesInOrderOnlyWhenEachConditionHolds`; `TutorialTests.swift springsAndEnergyCompletesWithTheChainArrowsAndThreeSeconds`; `PlaygroundCoreTests.swift testTutorialStartAndStop` |
| The same actions always give the same world | `PlaygroundCoreTests.swift testTheSameSeedAndActionsGiveTheSameWorld`; `ReplayTests.swift replayingTheSameInputsTwiceGivesTheSameWorld`; `WorldEditingTests.swift aRecordedEditingSessionReplaysIdentically` |
| Fewer details when the device needs it; the world stays the same at every level | `DrawingBudgetTests.swift theThreeLevelsHaveTheStatedDetail`; `PlaygroundQualityTests.swift testLowPowerModeDrawsTheLightestLevelInASession`; `PlaygroundQualityTests.swift testTheDigestIsTheSameAtEveryTier`; `PlaygroundQualityTests.swift testADrawnSessionAtChangingTiersEqualsTheUndrawnReplay` |
| VoiceOver describes the bodies, running or paused, the speed, the springs and levels, the selection and the arrows | `PlaygroundRenderTests.swift testTheDescriptionNamesBodiesStateAndTimeScale`; `PlaygroundSessionTests.swift testTheFirstFrameDrawsTheStartingSceneAndDescribesIt` |
| The opened experiment and the running tutorial step are described | `PlaygroundSessionTests.swift testAPresetAndATutorialRunThroughTheShell` |
| The pickers name each level in words | `PlaygroundRenderTests.swift testTheDescriptionNamesBodiesStateAndTimeScale` |
| The playground resumes where you left it | `PlaygroundSessionTests.swift testTheSavedStateRestoresIdenticallyInANewSession`; `ReplayTests.swift savingHalfwayAndRestoringContinuesToTheSameWorld`; `PlaygroundCoreTests.swift testTheSnapshotRestoresIdenticallyInAnotherEngine` |
| Holds still while you are away | `PlaygroundSessionTests.swift testASuspensionDoesNotAdvanceTheWorld`; `PlaygroundGestureTests.swift testSuspendingReleasesAHeldBodyAndForgetsTheGesture` |
| Nothing is sent anywhere | `ExperimentStoreTests.swift testASaveAndReadRoundTripIsIdenticalWithoutGrabAndSelection` |

The source scan of the experience (`pp-no-network`, T-A11-603) also proves that nothing is sent: no network, tracking,
sensor, recording, brightness or idle-timer use is in `Packages/ExperiencesCreative/PhysicsPlayground`. See
[privacy-and-credits.md](privacy-and-credits.md). No speed, timing or device claim is made, and the interface tests of
chunk `s2` are not cited here. Device measurements wait for the device campaign ([device-campaign.md](device-campaign.md)).
