# Simulation Lab — store text input

This is an input for the owner, who enters the App Store text of the VisualCore app; the agent never enters anything
in App Store Connect ([build-and-archive.md](../../release/build-and-archive.md) section 5). Simulation Lab is an
experience of the free tier of VisualCore (`tier: free` in `Catalog/experiences.json`), not a separate app. Feature 122
(A16-P06), FR-A16-620 and FR-A16-621 (research D2).

Every sentence below describes something that exists in the controls
(`SimulationLab/Experience/SimulationControls.swift`), the canvas (`SimulationPresenter.swift`), the legend
(`SimulationLegend.swift`), the adapter's words (`Experience/Adapter/SimulationCore.swift`) or the model
(`SimulationLab/Core`), and is exercised by the tests named in the traceability table. The text is checked by
`scripts/check_copy_claims.py` with `Configs/copy-claims-denylist.json` (one word is allowed for this experience,
`share` in `copyCheck.allow` of [release.json](release.json): a captured picture is handed to the system share sheet)
and by the experience's own word scan of T-A16-607 (`specs/122-sl-p06-release/scan-claims-release.sh`, the refused
words of the spec's Clarifications Q2). The store text names no performance figure and no value from a device, and
makes no claim beyond what is computed and labelled; every simulation is an educational approximation.

## Text

**Simulation Lab** — three families of simulations on a grid of cells, each started from a seed and drawn entirely by
code, inside VisualCore.

Choose a family: Life-like cellular automata (Life, HighLife and Seeds), Gray-Scott reaction-diffusion (Spots and
Mazes) or a 2D wave field (Pulse). Each preset starts from the same seeded field every time.

Run and pause the simulation, step it one iteration at a time, or reset it to its seeded start. Choose a speed from
×0.25 to ×4, and change the time step of reaction-diffusion and the wave; a step beyond the stability limit is refused
with the reason.

Paint cells with a tap or a drag: the automaton toggles a cell or sets it alive, reaction-diffusion drops a small disc
of inhibitor and the wave starts a pulse. A Seed button does the same at a chosen column and row.

The inspector lists every parameter with its range and the time step with its limit. The legend shows the colour scale
with the field's lowest and highest values, or the counts of alive and dead cells.

Every simulation carries an approximation label that names its grid, its values, its boundary and its step method, so
you always see what is computed and what is simplified. A CPU reference of each algorithm on a small grid is the
check the drawn field is compared with.

Save an experiment under your own name and open it again later from the Presets list; the six bundled presets carry
their sources and licenses. Saved experiments are kept on your device, and a stored file that cannot be read is
reported and left as it is.

Capture a picture of the field and share it through the share sheet.

VoiceOver reads every control with its value and describes the canvas with the family, the preset, the grid, the state
and the step. With Reduce Motion on, the simulation opens paused and the faster speeds are off.

The experience reopens where you left it. Nothing is sent anywhere.

## Traceability

| Claim | Proving test |
|---|---|
| Three families on a grid of cells, drawn entirely by code | `SimulationCoreTests.swift familyPresetAndSpeedActions`; `SimulationRenderTests.swift testEveryFamilyDrawsANonBlankFrame`; `SimulationRenderTests.swift testChangingTheFamilyChangesThePixelsAndTheDescription`; `SimulationRenderTests.swift testThePaletteMapsEachFamily` |
| Life-like cellular automata: Life, HighLife and Seeds | `AutomatonRuleTests.swift notationParsesThePresets`; `AutomatonRuleTests.swift theBlinkerHasPeriodTwo`; `AutomatonRuleTests.swift aGliderWrapsBackToItsShapeAfterFourNSteps`; `AutomatonParityTests.swift testASeededAutomatonEqualsTheReferenceAfter1_2_10And100Steps` |
| Gray-Scott reaction-diffusion: Spots and Mazes | `GrayScottTests.swift oneStepMatchesHandComputedValues`; `GrayScottTests.swift valuesStayFiniteAndWithinTheUnitRange`; `GrayScottToleranceTests.swift testTenGPUStepsMatchTheCPUReferenceWithinTolerance` |
| A 2D wave field: Pulse | `WaveFieldTests.swift aCentredPulseStaysSymmetricAndZeroOnTheBorder`; `WaveFieldTests.swift theDampedEnergyNeverIncreases`; `WaveBorderTests.swift testEveryEdgeCellIsZeroAfterAHundredSteps` |
| Each preset starts from the same seeded field every time | `SimulationSpecTests.swift theSameSeedGivesTheSameStart`; `SimulationSpecTests.swift theSeededStartsHaveTheirStatedShape`; `SchedulerTests.swift theDigestIsDeterministic` |
| Run, pause, step one iteration, reset to the seeded start | `SchedulerTests.swift pauseStopsAndRunResumes`; `SchedulerTests.swift oneStepWhilePausedAddsExactlyOneRuleStep`; `SchedulerTests.swift resetGivesTheSeededStartAndStepZero`; `StepExactTests.swift testOneStepIsExactlyOneIterationInEveryFamily`; `SimulationCoreTests.swift resetActionAndCoreReset` |
| A speed from ×0.25 to ×4 | `SchedulerTests.swift everySpeedRunsItsRateAtTheHostStep`; `SchedulerTests.swift speedChangesAreBounded` |
| The time step of reaction-diffusion and the wave; a step beyond the stability limit is refused with the reason | `TimeStepTests.swift reactionDiffusionAcceptsItsLimitAndRefusesAbove`; `TimeStepTests.swift theWaveAcceptsTheCourantLimitAndRefusesAbove`; `TimeStepMessageTests.swift testRefusedTimeStepsShowTheirSentenceAndAnAcceptedOneClearsIt`; `SimulationSpecTests.swift theStabilityLimitsAcceptTheLimitAndRefuseOnePercentAbove` |
| Paint cells with a tap or a drag, per family; the Seed button does the same | `SimulationBrushTests.swift anAutomatonTapTogglesExactlyOneCellAndTwiceRestores`; `SimulationBrushTests.swift anAutomatonDragSetsTheCellAlive`; `SimulationBrushTests.swift aReactionTapWritesExactlyTheWrappedDisc`; `SimulationBrushTests.swift aWaveTapWritesTheCellAndItsNeighboursInBothFields`; `PaintTests.swift testTouchesPaintCellsLikeTheSeedRow`; `PaintTests.swift testPaintChangesOnlyTheBrushCellsAndKeepsTheStep` |
| The inspector lists every parameter with its range and the time step with its limit | `InspectorWordsTests.swift theInspectorRows` |
| The legend shows the colour scale with the lowest and highest values, or the alive and dead counts | `LegendTests.swift theValuesAreTheFieldsExtremes`; `LegendTests.swift thePresenterCarriesTheLegendAndOffersTheOverlay` |
| An approximation label names the grid, the values, the boundary and the step method | `InspectorWordsTests.swift theApproximationLabels` |
| A CPU reference of each algorithm is the check the drawn field is compared with | `FloatMirrorTests.swift testRunningMirrorsStayWithinToleranceAndReloadAfter64Steps`; `FloatFieldToleranceTests.swift testReactionDiffusionMatchesWithinTolerance`; `FloatFieldToleranceTests.swift testTheWaveMatchesWithinTolerance`; `AutomatonParityTests.swift testASeededAutomatonEqualsTheReferenceAfter1_2_10And100Steps` |
| Save an experiment under your own name and open it again from the Presets list | `PresetStoreTests.swift testRoundTripAcrossStores`; `PresetStoreTests.swift testASavedExperimentReopensInANewSession`; `PresetStoreTests.swift testSortedByNameThenId`; `PresetStoreTests.swift testCapOfTwentyFour` |
| The six bundled presets carry their sources and licenses | `ExperimentPresetTests.swift theSixFamilyPresetsAreBundled`; `ExperimentPresetTests.swift everyBundledPresetIsValidAndAttributed`; `PaintTests.swift testSpecGivesEachBundledPresetAndRefusesBadOnes` |
| Saved experiments are kept on the device; a stored file that cannot be read is reported and left as it is | `PresetStoreTests.swift testDamagedAndNewerFilesAreSkipped`; `PresetStoreTests.swift testAPresetWithARefusedSpecIsReportedAndSkipped`; `ExperimentPresetTests.swift damagedBytesAreRefusedAsDamaged`; `ExperimentPresetTests.swift aNewerSchemaIsRefusedAsNewer` |
| Capture a picture of the field and share it through the share sheet | `CaptureTests.swift testCapturesLeaveOnePNGAndChangeNothing`; `CaptureFileTests.swift testTwoCapturesLeaveOneFile`; `CaptureFileTests.swift testThrowingRenderLeavesNoFile`; `CaptureFileTests.swift testAPresenterEmptiesTheCaptureFolder` |
| VoiceOver reads every control with its value and describes the canvas with the family, preset, grid, state and step | `SimulationCoreTests.swift theWordsNameTheFamilyPresetGridStateAndStep`; `InspectorWordsTests.swift theDescriptionSpeaksTheState` |
| With Reduce Motion on, the simulation opens paused and the faster speeds are off | `SimulationSessionTests.swift testReduceMotionOpensPaused`; `MotionCapTests.swift testTheCapsPerSettingAndFamily`; `MotionCapTests.swift testAFasterSpeedIsRefusedAndAFamilyChangeLowersIt` |
| Reopens where you left it | `SimulationSessionTests.swift testTheSavedStateRestoresToTheSameDigestInANewSession`; `SimulationCoreTests.swift snapshotAndRestoreGiveTheSameDigest`; `SimulationStateTests.swift theRoundTripIsByteForByte` |
| Nothing is sent anywhere | `CaptureTests.swift testCapturesLeaveOnePNGAndChangeNothing`; `CaptureFileTests.swift testAPresenterEmptiesTheCaptureFolder`; `PresetStoreTests.swift testRoundTripAcrossStores` |

The source scan of the experience (`sl-no-network`, T-A16-603) also proves that nothing is sent: no network,
tracking, sensor, recording, photo-library, image-picker, brightness or idle-timer use is in
`Packages/ExperiencesCreative/SimulationLab` (`.autonomy/checks/A16-P06.sl-no-network.json`). See
[privacy-and-credits.md](privacy-and-credits.md) and [validation-report.md](validation-report.md). No speed, timing or
device claim is made. The interface tests of chunk `x2` (`SLExploreUITests`, `SLLibraryUITests`; T-A16-608) prove the
journeys through the app's controls on the iOS 27 phone simulator without presenting the share sheet; they are
simulator results, not device measurements. Device measurements wait for the device campaign
([device-campaign.md](device-campaign.md)).
