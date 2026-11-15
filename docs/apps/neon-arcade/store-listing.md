# Neon Arcade — store text input

This is an input for the owner, who enters the App Store text of the VisualCore app; the agent never enters anything
in App Store Connect ([build-and-archive.md](../../release/build-and-archive.md) section 5). Neon Arcade is an
experience of the free tier of VisualCore (`tier: free` in `Catalog/experiences.json`), not a separate app. Feature 080
(A10-P06), FR-A10-620 and FR-A10-621.

Every sentence below describes something that exists in `NeonArcade/Experience/ArcadeControls.swift`, the gestures of
`ArcadeGestures.swift`, the canvas of `ArcadePresenter.swift` or the game logic of `NeonArcade/Core`, and is exercised
by the tests named in the traceability table. The text is checked by `scripts/check_copy_claims.py` with
`Configs/copy-claims-denylist.json` (no word is allowed for this experience: `copyCheck.allow` in
[release.json](release.json) is empty) and by the experience's own word scan of T-A10-607
(`specs/080-na-p06-release/scan-claims-release.sh`). The store text names no number with a unit, no measured value and
no benefit for the person who plays; it describes a game drawn by code.

## Text

**Neon Arcade** — Neon Dodge, a compact arcade game of glowing shapes drawn entirely by code, inside VisualCore.

Steer through falling hazards and collect glowing orbs. Drag on the field to steer, or hold Steer left and Steer
right; choose one of five steering sensitivities, from gentle to sharp.

You start with three lives. A hazard costs a life, an orb adds points, and points also come with every second you
stay in play. Even a quick hazard cannot slip past the player between two frames.

The game comes in waves, and every wave brings another pattern: steady rain, walls with one free lane, a zigzag, and a
trail of orbs guarded by hazards. Later waves fall faster and orbs are worth more.

Start from the title screen, pause and resume at any time, restart, and play again after the game is over.

Your ten best runs are kept on your device with the wave each one reached, and the best score is shown on the title
screen.

Hits, pickups and new waves light up with glow and particle bursts, drawn below the shapes so that nothing hides a
hazard. Short sound effects made by code and haptic taps accompany them; each has its own switch, and the sound
follows the silent switch.

With Reduce Motion on, the glow pulses and drifts less and screens change without a fade. With reduced flashing on,
the glow stays steady.

VoiceOver describes every screen, the score, the lives and the wave, and announces hits, new waves and the end of a
game; every control has a label, and the text grows with your text size. VisualCore draws fewer effects when the
device needs it.

The game resumes where you left it, and pauses when you leave. Nothing is sent anywhere.

## Traceability

| Claim | Proving test |
|---|---|
| Drawn entirely by code; every bundled item and pattern is original content of the project | `LicenseAuditTests.swift theCommittedLicenseDocumentMatchesTheCatalog`; `LicenseAuditTests.swift theBundledCatalogHasNoProblems`; `ArcadeCatalogTests.swift theBundledCatalogHasThePlayerTwoHazardsAndTheOrb` |
| Falling hazards and orbs | `GameSimulationTests.swift theFirstObjectAppearsWithinTwoSeconds`; `ArcadeRenderTests.swift testFramesDifferOnceObjectsFallAndAPausedRunHolds`; `ArcadeRenderTests.swift testObjectsAndThePlayerAreDrawnAtTheRuleSizes` |
| Drag on the field to steer | `ArcadeRenderTests.swift testADragSteersByTheFingerOffsetAndReleaseStops`; `ArcadeRenderTests.swift testAHeldDragFollowsTheFingerAsThePlayerMoves`; `NAArcadeUITests.swift testStartAndSteer` |
| Or hold Steer left and Steer right | `NAArcadeUITests.swift testStartAndSteer`; `GameSimulationTests.swift steeringEasesTheVelocityAndMovesThePlayer`; `ArcadeSessionTests.swift testEveryControlIsLabelledAndTheControlsGrowWithDynamicType` |
| Five steering sensitivities, from gentle to sharp | `SensitivityTests.swift theFiveReachesAndTheDefault`; `SensitivityTests.swift oneOffsetIsOrderedGentleToSharpAndBounded`; `ArcadeSessionTests.swift testTheDragReachFollowsTheSensitivityStep`; `NAArcadeUITests.swift testSensitivity`; `NASettingsUITests.swift testSensitivityStepper` |
| Three lives; a hazard costs a life | `GameRunTests.swift aNewRunHasTheStartValuesAndIsValid`; `GameSimulationTests.swift aHazardHitCostsOneLifeAndStartsInvulnerability`; `GameSimulationTests.swift gameOverStopsTheRun` |
| An orb adds points; points for every second in play | `GameSimulationTests.swift anOrbPickupAddsTen`; `GameSimulationTests.swift survivalAddsOnePointPerSecondOfPlayOnly` |
| Even a quick hazard cannot slip past the player between two frames | `Collision2DTests.swift earliestFractionForAHeadOnCrossing`; `GameSimulationTests.swift aFastCircleCrossingThePlayerInOneStepIsCaught`; `GameSimulationTests.swift capsulesHitByEndOfStepOverlap`; `GameSimulationTests.swift theCapsuleSpeedBoundHoldsForTheCatalogAtTheDifficultyCeiling` |
| Waves, each with another pattern: rain, walls with one free lane, zigzag, a trail of orbs guarded by hazards | `WaveDirectorTests.swift wavesAdvanceEvery600StepsWithAnotherPattern`; `WaveDirectorTests.swift everyWallLeavesExactlyOneFreeLaneNeverThePrevious`; `WaveDirectorTests.swift zigzagWalksTheLanesAndBack`; `WaveDirectorTests.swift anOrbTrailGuardsEverySecondOrb` |
| Later waves fall faster and orbs are worth more | `DifficultyTests.swift theValuesFollowTheRamp`; `DifficultyTests.swift difficultyNeverFallsAndStopsAtTheCeiling`; `GameSimulationTests.swift anOrbInALaterWaveIsWorthItsValueTimesTheMultiplier` |
| Start from the title screen | `ArcadeFlowTests.swift aNewExperienceOpensOnTitle`; `ArcadeRenderTests.swift testTheTitleScreenIsDrawn`; `NAArcadeUITests.swift testStartAndSteer` |
| Pause and resume at any time | `GameSimulationTests.swift pauseStopsTheRun`; `ArcadeSessionTests.swift testFramesAdvanceTheRunAndPauseStopsIt`; `NAArcadeUITests.swift testPauseAndResume` |
| Restart, and play again after the game is over | `ArcadeFlowTests.swift aWholeGameFollowsTheFlow`; `GameRunTests.swift restartGivesTheNewRunValues`; `ArcadeRenderTests.swift testTheGameOverScreenShowsTheScoreAndTheWave` |
| Ten best runs kept on your device with the wave each one reached | `HighScoreTableTests.swift entriesAreRankedHighestFirst`; `HighScoreTableTests.swift theTenthEntryCut`; `HighScoreStoreTests.swift testATableRoundTripsThroughStorageAndARunIsEnteredOnce`; `HighScoreStoreTests.swift testAnInterruptedSaveLeavesTheLastCompleteTable` |
| The best score is shown on the title screen | `ArcadeRenderTests.swift testTheBestScoresAreDrawnOnTheTitleAndGameOverScreensWithTheNewEntryMarked`; `NAArcadeUITests.swift testTitleShowsBestScore` |
| Hits, pickups and new waves light up with glow and particle bursts | `ArcadeRenderTests.swift testHitsPickupsAndWavesStartTheirEffects`; `ArcadeRenderTests.swift testParticlesAreDrawnInASessionAndARestartClearsThem`; `ArcadeEffectsTests.swift aPickupCueAtTheOrbsPlace` |
| Drawn below the shapes so that nothing hides a hazard | `ArcadeRenderTests.swift testTheEffectsAreDrawnBelowTheCollisionShapes`; `ContrastTests.swift everyHazardIsReadableAgainstItsGlowAtEveryLevel`; `ContrastTests.swift everyCoreIsReadableAgainstTheField` |
| Short sound effects made by code | `ArcadeEffectsTests.swift theFourSoundShapes`; `ArcadeEffectsTests.swift theSoundShapesStayInsideTheLimits`; `SoundEffectSynthTests.swift noiseChangesTheBufferDeterministically`; `SoundEffectPlayerTests.swift testBuffersAreRenderedOncePerID` |
| Haptic taps; each has its own switch | `ArcadeSessionTests.swift testTheSoundAndHapticSinksReceiveCuesOnlyWhenEnabled`; `ArcadeSessionTests.swift testDigestsAreIdenticalWithEffectsSoundAndHapticsOnOrOff`; `NASettingsUITests.swift testSoundToggle`; `NASettingsUITests.swift testHapticsToggle` |
| The sound follows the silent switch | `SoundEffectPlayerTests.swift testPlayingUsesTheAmbientSessionAndNeedsNoMicrophonePermission`; `SoundEffectPlayerTests.swift testDisabledPlayerPlaysNothing` |
| With Reduce Motion on, the glow pulses and drifts less and screens change without a fade | `ArcadeRenderTests.swift testReduceMotionHalvesPulseAndDriftAndLeavesTheCoreAlone`; `ArcadeSessionTests.swift testReduceMotionHalvesPulseAndDriftButNeverChangesTheState`; `ArcadeRenderTests.swift testScreensCrossFadeAndChangeAtOnceUnderReduceMotion` |
| With reduced flashing on, the glow stays steady | `ArcadeRenderTests.swift testReducedFlashingHoldsTheGlowSteadyAtEveryLevel` |
| VoiceOver describes every screen, the score, the lives and the wave | `ArcadeRenderTests.swift testTheDescriptionNamesScoreLivesAndState`; `ArcadeSessionTests.swift testEveryScreenIsSpoken`; `ArcadeSessionTests.swift testTheFirstFrameDrawsANewRunAndDescribesIt` |
| Announces hits, new waves and the end of a game | `ArcadeAnnouncementsTests.swift textsForHitWaveAndGameOver`; `ArcadeAnnouncementsTests.swift atMostOnePerSecondOverASixHundredStepBurst`; `ArcadeAnnouncementsTests.swift nothingIsPostedWithVoiceOverOff`; `ArcadeSessionTests.swift testAnnouncementsAreAtMostOnePerSecondOverARun` |
| Every control has a label; the text grows with your text size | `ArcadeSessionTests.swift testEveryControlIsLabelledAndTheControlsGrowWithDynamicType` |
| Fewer effects when the device needs it | `ArcadeBudgetTests.swift everyLevelHasItsDocumentedCaps`; `ArcadeRenderTests.swift testEachLevelKeepsTheLiveParticlesWithinItsCap`; `ArcadeSessionTests.swift testLowPowerModeDrawsLevelZeroAndNeverChangesTheState`; `ArcadeSessionTests.swift testALevelChangeMidRunKeepsTheShapesTheStateAndTheDigest` |
| The game resumes where you left it | `ArcadeSessionTests.swift testTheSavedStateRestoresIdenticallyInANewSession`; `ArcadeSessionTests.swift testASavedTitleOrGameOverScreenRestoresToTheSameScreen`; `ReplayTests.swift savingAndRestoringHalfwayContinuesTheSameRun` |
| Pauses when you leave | `ArcadeSessionTests.swift testASuspensionWhilePlayingRecordsAPauseAndAdvancesNothing`; `ArcadeSessionTests.swift testASuspensionOfAnyLengthInWaveThreeChangesNothing` |
| Nothing is sent anywhere | `HighScoreStoreTests.swift testATableRoundTripsThroughStorageAndARunIsEnteredOnce`; `SoundEffectPlayerTests.swift testPlayingUsesTheAmbientSessionAndNeedsNoMicrophonePermission` |

The source scan of the experience (`na-no-network`, T-A10-603) also proves that nothing is sent: no network, tracking,
sensor, recording, brightness or idle-timer use is in `Packages/ExperiencesCreative/NeonArcade`. See
[privacy-and-credits.md](privacy-and-credits.md). No speed, timing, device or benefit claim is made, and no table of
other people's results exists. Device measurements wait for the device campaign ([device-campaign.md](device-campaign.md)).
