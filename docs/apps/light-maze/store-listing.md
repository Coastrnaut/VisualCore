# Light Maze — store text input

This is an input for the owner, who enters the App Store text of the VisualCore app; the agent never enters anything
in App Store Connect ([build-and-archive.md](../../release/build-and-archive.md) section 5). Light Maze is an
experience of the free tier of VisualCore (`tier: free` in `Catalog/experiences.json`), not a separate app. Feature 101
(A13-P06), FR-A13-620 and FR-A13-621.

Every sentence below describes something that exists in the controls (`LightMaze/Experience/MazeControls.swift`), the
gestures (`MazeGestures.swift`), the canvas (`MazePresenter.swift`) or the game model (`LightMaze/Core`), and is
exercised by the tests named in the traceability table. The text is checked by `scripts/check_copy_claims.py` with
`Configs/copy-claims-denylist.json` (no word is allowed for this experience: `copyCheck.allow` in
[release.json](release.json) is empty) and by the experience's own word scan of T-A13-607
(`specs/101-lm-p06-release/scan-claims-release.sh`, the refused words of the spec's Clarifications Q2). The store text
names no number with a unit and no value from a device; it describes a puzzle whose beams follow the game's grid
rules.

## Text

**Light Maze** — a puzzle of mirrors and beams on a grid, drawn entirely by code, inside VisualCore.

Guide a beam of light from its lamp into every target. Twenty handcrafted levels lead from a single mirror on a small
board to larger mazes with walls, many mirrors and, in the later levels, prisms that split the beam in two.

Tap a mirror or prism to select it and tap it again to turn it to its other diagonal. You can also drag it towards a
diagonal or twist two fingers over it. Every gesture also has a button: select the previous or next tile, turn it,
and move between levels with the Level menu or the previous and next buttons.

The beam bounces off each mirror at equal angles and always comes to an end: at a wall, at the edge of the board, in a
target or after a set number of bounces. The same board always gives the same beam.

Light every target to solve the level. Solving opens the next level and keeps your fewest moves. Every level is
checked to be solvable, and its recorded solution uses the fewest turns.

Undo takes your last turn back, and Restart returns the level to its start. Stuck? Hint selects a tile to turn and
says where it is, and following the hints solves every level.

When a level is solved, the board gains a border with a tick, a short sweep sounds and your device gives a
haptic. With Reduce Motion or Reduce Flashing on, the border stays still.

The beam glows, and the glow never hides its path. Lit targets turn green and gain a ring, and every tile state has
its own sign as well as its own colour.

VoiceOver reads the board: Describe speaks every tile, the beam's path and each target, and changes to the beam are
announced.

Your progress stays on your device. A progress file that cannot be read is reported and left as it is, and play
starts again from the first level. The maze reopens where you left it, and holds still while you are away. Nothing is
sent anywhere.

## Traceability

| Claim | Proving test |
|---|---|
| Drawn entirely by code; every level is original content of the project | `LicenseAuditTests.swift theCommittedLicenseDocumentMatchesTheCatalog`; `LicenseAuditTests.swift theBundledCatalogHasNoProblems`; `MazeRenderTests.swift testADrawnFrameOfLevelsOneSixteenAndTwentyIsNonBlank`; `MazeRenderTests.swift testTheExperienceNeverCreatesAGraphicsContextOfItsOwn` |
| Guide a beam from its lamp into every target | `BeamTracerTests.swift theFirstLevelEndsAtTheWallAndItsSolutionAtTheTarget`; `MazeRenderTests.swift testSolvingLevelOneShowsTheLitTargetColour` |
| Twenty handcrafted levels, from a single mirror on a small board to larger mazes with walls, many mirrors and prisms in the later levels | `LevelCatalogTests.swift thereAreTwentyLevelsWithProvenance`; `LevelCatalogTests.swift theLevelsFollowTheirTiers`; `LevelCatalogTests.swift everyLevelIsValidUnsolvedAtStartAndSolvedByItsSolution` |
| Prisms split the beam in two | `BeamTracerTests.swift aPrismMakesTwoBranches`; `LoopFixtureTests.swift prismBranchesThatMeetEndWithLoop`; `MazeGestureTests.swift testATapOnAPrismOfALaterLevelSelectsItsTurnableIndex` |
| Tap to select, tap again to turn to the other diagonal | `MazeGestureTests.swift testATapSelectsATurnableTileThenTurnsIt`; `MazeSessionTests.swift testTapsOnTheCanvasSelectThenTurnLevelOnesMirror`; `BoardTests.swift orientationsToggle` |
| Drag towards a diagonal or twist two fingers over it | `MazeGestureTests.swift testADragSnapsToTheNearestDiagonalAndBackWhenItCrossesOver`; `MazeGestureTests.swift testDragsInEveryDirectionLandOnTheNearestDiagonal`; `MazeGestureTests.swift testARotationOverTheSelectedTileTurnsItOncePerSnapAngle`; `MazeGestureTests.swift testTheArbiterLetsARotationWinOverADrag` |
| Every gesture also has a button: select previous or next, turn, the Level menu, previous and next level | `MazeGestureTests.swift testEveryGestureActionHasANativeControl`; `MazeRenderTests.swift testTheWordsOfTheControls`; `MazeCoreTests.swift testActionsInRangeAreAccepted`; `LMLevelUITests` |
| The beam bounces off each mirror at equal angles | `BeamTracerTests.swift mirrorsReflectWithEqualAnglesAndNeverHitThemselvesAgain`; `BeamFixtureTests.swift levelOne`; `MazeBeamFixtureTests.swift testCoreBeamLinesEqualTheTracerSegmentsOnSixtyBoards` |
| The beam always comes to an end: a wall, the edge, a target or a set number of bounces | `BeamTracerTests.swift theBounceCapHolds`; `BeamTracerTests.swift theSegmentCapHolds`; `BeamTracerTests.swift everySegmentStaysOnTheBoard`; `LoopFixtureTests.swift aMirrorSpiralReachesTheBounceCap`; `LoopFixtureTests.swift aMirrorPathBackToTheEmitterEndsThere` |
| The same board always gives the same beam | `BeamTracerTests.swift everyLevelTracesIdenticallyTwice`; `MazeCoreTests.swift testTheDigestCoversTheStateAndTheBeamAndIsStable` |
| Light every target to solve; solving opens the next level and keeps the fewest moves | `ProgressTests.swift solvingOpensTheNextLevelAndKeepsTheFewestMoves`; `MazeProgressTests.swift testSolvingLevelsOneToThreeInOrderOpensLevelFourAndLeavesFiveLocked`; `MazeProgressTests.swift testUndoToUnsolvedAndBackDoesNotCountTwice`; `BoardDescriptionTests.swift solvedBoardsLightEveryTarget`; `LMLevelUITests` |
| Every level is checked to be solvable, its recorded solution uses the fewest turns | `ContentQATests.swift everyBundledLevelPasses`; `ContentQATests.swift theCommittedQADocumentMatchesTheCatalog`; `SolverTests.swift everyBundledLevelIsSolvedWithItsRecordedTurns`; `SolutionReplayTests.swift everyRecordedSolutionReplaysFromAFreshState` |
| Undo takes the last turn back | `MovesTests.swift undoRestoresTheEarlierOrientationsAndBeam`; `MovesTests.swift undoOnASolvedLevelUnsolvesIt`; `MazeCoreTests.swift testUndoTakesTheLastTurnBackAndIsRefusedWithNoMoves`; `LMLevelUITests` |
| Restart returns the level to its start | `MazeStateTests.swift selectingTurningAndResetting`; `MovesTests.swift resetAndChoosingALevelEmptyTheMoves` |
| Hint selects a tile to turn and says where it is; following the hints solves every level | `HintTests.swift followingHintsSolvesEveryLevelWithinItsTurnableCount`; `HintTests.swift theHintIsAlwaysADifferingTurnableTile`; `MazeHintTests.swift testHintSelectsTheFirstDifferingTileAndIsRefusedWhenSolved`; `MazeHintTests.swift testFollowingHintsSolvesEveryLevel`; `MazeHintTests.swift testTheHintControlAnswersInWordsAndKeepsThemWithVoiceOverOff`; `LMHelpUITests` |
| When solved: a border with a tick, a short sweep and a haptic | `MazeFeedbackTests.swift testOneCuePerSolveWithWordsSoundAndRateLimitedHaptic`; `MazeFeedbackTests.swift testTheSolvedBoardHasABorderAndTick`; `SuccessCueTests.swift soundParametersWithinSoundEffectLimits`; `SuccessCueTests.swift solveWords` |
| With Reduce Motion or Reduce Flashing on, the border stays still | `SuccessCueTests.swift reduceMotionAndReduceFlashingKeepTheBorderStatic`; `MazeFeedbackTests.swift testTheBorderBrightensOnceAndReduceFlagsKeepItStatic` |
| The glow never hides the beam's path | `MazeGlowTests.swift testEveryCoreBeamLineLiesOnATracerSegmentWithACappedHaloUnderIt`; `MazeRenderTests.swift testTheBeamPathIsBrighterThanTheBoard`; `MazeStyleTests.swift testTheGlowStaysWithinItsReach` |
| Lit targets turn green and gain a ring | `MazeGlowTests.swift testLitTargetsCarryARingAndUnlitOnesNone`; `MazeRenderTests.swift testSolvingLevelOneShowsTheLitTargetColour` |
| Every tile state has its own sign as well as its own colour | `MazeStyleTests.swift testTheNineStatesHaveDistinctSigns`; `MazeStyleTests.swift testEveryStateColourHasThreeToOneContrastAgainstTheBoard`; `MazeGlowTests.swift testTheSelectedTileCarriesAnOutline` |
| VoiceOver reads the board: Describe speaks every tile, the beam's path and each target | `BoardDescriptionTests.swift firstLevelReadsExactly`; `BoardDescriptionTests.swift fifthLevelBranchStartsTurnsAndEnds`; `MazeHintTests.swift testDescribeSpeaksTheFullBoardAndTheSummaryCountsLitTargets`; `MazeSessionTests.swift testTheFirstFrameDrawsLevelOneAndDescribesIt`; `LMHelpUITests` |
| Changes to the beam are announced | `MazeGlowTests.swift testBeamChangesAreSpokenAtMostOncePerSecondOfFrameTime`; `MazeGlowTests.swift testNothingReachesTheSinkWhileVoiceOverIsOff` |
| Progress stays on the device | `ProgressStoreTests.swift testASaveAndLoadRoundTripIsIdentical`; `MazeProgressTests.swift testANewPresenterOverTheSameStorageLoadsEqualProgress` |
| A progress file that cannot be read is reported and left as it is; play starts again from the first level | `ProgressStoreTests.swift testRefusedFilesAreReportedAndLeftUntouched`; `ProgressStoreTests.swift testAnInterruptedOrRefusedWriteKeepsThePreviousFileByteIdentical`; `MazeProgressTests.swift testADamagedProgressFileOpensWithFreshProgressAndReportsTheRefusal`; `ProgressTests.swift damagedDocumentsAreRefused` |
| The maze reopens where you left it | `MazeSessionTests.swift testTheSavedStateRestoresIdenticallyInANewSession`; `MazeCoreTests.swift testTheSnapshotRestoresIdenticallyInAnotherEngine`; `MazeCoreTests.swift testTheSchemaOneExampleRestoresWithNoMoves` |
| Holds still while you are away | `MazeSessionTests.swift testASuspensionChangesNothing`; `MazeFeedbackTests.swift testSuspensionStopsTheSoundAndEndsTheBrightening` |
| Nothing is sent anywhere | `ProgressStoreTests.swift testASaveAndLoadRoundTripIsIdentical`; `ProgressStoreTests.swift testWithoutStorageProgressIsKeptInMemory` |

The source scan of the experience (`lm-no-network`, T-A13-603) also proves that nothing is sent: no network, tracking,
sensor, recording, brightness or idle-timer use is in `Packages/ExperiencesCreative/LightMaze`
(`.autonomy/checks/A13-P06.lm-no-network.json`). See [privacy-and-credits.md](privacy-and-credits.md). No speed,
timing or device claim is made. The interface tests of chunk `u2` cited above (`LMLevelUITests`, `LMHelpUITests`)
prove the journeys through the app's controls on the iOS 27 phone simulator; they are simulator results, not device
measurements. Device measurements wait for the device campaign ([device-campaign.md](device-campaign.md)).
