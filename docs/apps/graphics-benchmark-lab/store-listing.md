# Graphics Benchmark Lab — store text input

This is an input for the owner, who enters the App Store text of the VisualCore app; the agent never enters anything
in App Store Connect ([build-and-archive.md](../../release/build-and-archive.md) section 5). Graphics Benchmark Lab is
an experience of the free tier of VisualCore (`tier: free` in `Catalog/experiences.json`), not a separate app. Feature
178 (A24-P06), FR-A24-605 and FR-A24-606.

Every sentence below describes something that exists in the controls
(`GraphicsBenchmarkLab/Experience/GBLControls.swift`), the results view (`ResultsView.swift`), the repeatability view
(`RepeatabilityView.swift`), the explanation (`GBLExplanation.swift`, `ExplanationView.swift`), the presenter
(`BenchPresenter.swift`) or the adapter (`Experience/Adapter/BenchCore.swift`), and is exercised by the tests named in
the traceability table. The text is checked by `scripts/check_copy_claims.py` with `Configs/copy-claims-denylist.json`
([release.json](release.json) allows only the word "share" through `copyCheck.allow`, because the lab hands an export to
the system share sheet on the person's tap) and by the experience's own word scan of T-A24-607
(`specs/178-gbl-p06-release/scan-claims-release.sh`, the refused words of the spec's Clarifications Q2). The store text
names no measured figure, no timing and no value from a device, and makes no claim beyond what the code holds.

## Text

**Graphics Benchmark Lab** — run three repeatable GPU workloads on this device and read what was measured, with its
limits, inside VisualCore.

Three built-in cases: Textured quads, Shader ALU and Particles. Each run passes a warm-up, a measurement and a
cool-down phase, and only the frames of the measurement phase count.

For every measured frame the lab keeps the frame interval and the presenter CPU time, and the GPU time where the
device offers a GPU timer. Where it does not, the result says "GPU time not available on this device." and no other
time is shown as GPU time.

A result gives p50, p95 and p99 of these times and the frame counts, and says whether the run is Valid, Qualified or
Invalid, with its reasons: a change of the thermal state, Low Power Mode, dropped frames, too few frames, or a run
that was stopped or interrupted.

When the device becomes hot, the run ends at once as interrupted, so the lab never keeps a hot device busy. Leaving
the app during a run ends it as interrupted too.

Save up to 12 results on your device, open them later with their settings and their report (device model, OS
version, app version and build, renderer, thermal state and Low Power Mode at the start and the end), and remove them.

The repeatability view of an opened result compares its trials of the same case, device model, OS version, app build
and quality tier, and says why another trial is not comparable.

Export an opened result as a JSON run file or a CSV and share it through the system share sheet. Nothing is sent
otherwise.

"About these numbers" explains what is measured, what the classes mean, why numbers differ, that simulator numbers
say nothing about a device, and what the lab does not do: it does not rank devices, gives no overall figure and does
not compare its numbers with other tools.

The controls and results have spoken labels for VoiceOver, and the explanation's sections are read as headings.
Graphics Benchmark Lab works offline and needs no permission.

## Traceability

| Claim | Proving test |
|---|---|
| Three built-in cases: Textured quads, Shader ALU and Particles | `CaseTests.swift builtInValues`; `CaseTests.swift builtInsValidateWithDistinctStableFingerprints`; `BenchCoreTests.swift theThreeControlsAreDeclaredWithTheirRanges`; `WorkloadDrawTests.swift framesZeroAndSixtyAreDrawnDifferAndRepeatOnAnotherHost` |
| Each run passes a warm-up, a measurement and a cool-down phase; only the measured frames count | `RunTimelineTests.swift phasesFromStartZero`; `RunTimelineTests.swift endTimeIsStartPlusTotal`; `RecorderTests.swift aRunPassesItsPhasesAndFinishesWithASummaryOfTheMeasuredFrames`; `FixtureTests.swift everyFixtureMatchesItsExpectedSummaryExactly`; `GBLRunUITests` (a quads run finishes and its result opens with its explanation) |
| The frame interval and the presenter CPU time of every measured frame, and the GPU time only where a GPU timer exists; otherwise "GPU time not available on this device." | `TimerProbeTests.swift supportedWhenTheExtensionIsListed`; `TimerProbeTests.swift unsupportedOtherwise`; `GPUTimingTests.swift onTheSimulatorMeasuredFramesCarryAFiniteGPUTimeAndNoOtherFrameDoes`; `GPUTimingTests.swift withTheProbeForcedOffNoSampleHasAGPUTimeAndTheSummarySaysSo`; `RecorderTests.swift aRunThroughThePresenterMeasuresTheCPUTimeAndSaysGPUTimeIsNotAvailable`; `ReportTests.swift withTheProbeForcedOffTheGPUTimerIsNeverNamed` |
| p50, p95 and p99 of these times and the frame counts | `StatisticsTests.swift minimumCounts`; `StatisticsTests.swift distributionSortsItsValues`; `FixtureTests.swift aShuffledSetGivesTheSameSummary`; `RecorderTests.swift theSummaryTextGivesPercentilesInMillisecondsWithTwoDecimals`; `DroppedFrameRuleTests.swift strictlyAboveTheThresholdIsDropped` |
| Valid, Qualified or Invalid with its reasons (thermal change, Low Power Mode, dropped frames, too few frames, stopped or interrupted) | `RunQualificationTests.swift aCleanCompletedRunIsValid`; `RunQualificationTests.swift eachInvalidReasonAlone`; `RunQualificationTests.swift eachQualifiedReasonAlone`; `RunQualificationTests.swift everySentence`; `RunReportTests.swift thermalChangedFlag`; `QualificationDisplayTests.swift theListAndTheOpenedResultShowTheClassAndTheSentences`; `QualificationDisplayTests.swift aStoppedRunIsInvalidInTheControls` |
| A hot device ends the run at once as interrupted; leaving the app during a run ends it as interrupted | `ThermalStopTests.swift aSeriousOrCriticalThermalStateStopsTheRun`; `ThermalStopTests.swift aFairStateRunsOnAndANewRunStartsClean`; `RecorderTests.swift closingTheSessionMidRunGivesInterrupted`; `QualificationDisplayTests.swift aRunInterruptedByAGapOverASecondIsInvalidInTheControls`; `GBLRunUITests` (leaving the app mid-run ends it as "Interrupted") |
| Save up to 12 results on the device, open them with their settings and report, and remove them | `ResultLibraryTests.swift aSavedRunOpensInANewLibraryEqualToTheOriginal`; `ResultLibraryTests.swift thePresenterSavesTheEndedRunOnceAndANewPresenterOpensIt`; `ResultLibraryTests.swift theThirteenthSaveIsRefusedAndNothingChanges`; `ResultLibraryTests.swift aRemovalDeletesOnlyTheChosenFile`; `ResultLibraryTests.swift aResultOfACaseVersionTheAppDoesNotBuildInOpensWithItsSettings`; `ResultLibraryTests.swift unreadableFilesAreListedWithTheirReasonAndKept`; `ReportTests.swift aFinishedRunCarriesAValidReportWithEveryFieldFilled`; `BenchRecoveryDrawTests.swift aFailedDrawLeavesTheResultsAndANewSessionOpensThem`; `ReleaseSampleTests.swift theCurrentResultSampleOpensAndIsInTheEncodedForm`; `ReleaseSampleTests.swift theNewerAndDamagedResultSamplesAreListedAsUnreadable`; `ReleaseSampleTests.swift anOversizedResultIsListedAsTooLargeAndKept`; `ReleaseSampleTests.swift theNewerIndexSampleMakesTheLibraryReadOnly` |
| The repeatability view compares trials of the same case, device model, OS version, app build and quality tier, and says why another trial is not comparable | `RepeatabilityTests.swift threeComparableTrialsAndTheirSpread`; `RepeatabilityTests.swift eachNotComparableReason`; `RepeatabilityTests.swift theFirstDifferenceInTheFixedOrderIsGiven`; `QualificationDisplayTests.swift theRepeatabilityBlockComparesTrialsAndNamesTheOthers` |
| Export an opened result as a JSON run file or a CSV and share it through the system share sheet; nothing is sent otherwise | `ExportTests.swift theActionAloneWritesTheJSONAndCSVFiles`; `ExportTests.swift theShareItemCarriesTheContentTypeOfItsFormat`; `ExportTests.swift closingTheSessionEmptiesTheExportFolder`; `RunCSVTests.swift theJSONExportEqualsItsGoldenFile`; `RunCSVTests.swift theCSVExportEqualsItsGoldenFile` |
| "About these numbers" explains what is measured, the classes, why numbers differ, simulator numbers, and what the lab does not do | `ExplanationTests.swift theExplanationHasTheFiveSectionsInOrder`; `ExplanationTests.swift everyLimitOfUserStoryThreeIsNamed`; `ExplanationTests.swift theWordsCarryNoMeasuredClaim`; `ExplanationTests.swift theExplanationIsReachableFromAResultAndFromItsRepeatability`; `GBLRunUITests` (a quads run finishes and its result opens with its explanation) |
| Spoken labels for the controls and results; the explanation's sections are read as headings | `QualificationDisplayTests.swift theListAndTheOpenedResultShowTheClassAndTheSentences`; `ResultLibraryTests.swift aSavedRunOpensInANewLibraryEqualToTheOriginal`; `RecorderTests.swift aRunThroughThePresenterMeasuresTheCPUTimeAndSaysGPUTimeIsNotAvailable`; `ExplanationTests.swift theExplanationHasTheFiveSectionsInOrder`; `GBLRunUITests` (a quads run finishes and its result opens with its explanation) |
| Works offline, needs no permission, and opens on the case of the last session without resuming a run | `BenchCoreTests.swift theOpeningStateIsQuadsWithNoRequest`; `BenchCoreTests.swift aSnapshotRoundTrips`; `GBLManifestTests.swift theSaveRestoreStateSurvivesARestore`; `ReleaseSampleTests.swift theCurrentSnapshotSampleRestores`; `RecorderTests.swift aRestoredSnapshotNeverResumesARun`; `GBLReleaseUITests` (a fresh start is "Ready" on Textured quads with no saved result) |

The source scan of the experience (`scan-sources`, T-A24-603) proves that no network, tracking, sensor, recording,
sound input, photo-library, `UIPasteboard`, idle-timer or brightness use is in
`Packages/ExperiencesCreative/GraphicsBenchmarkLab`, and that `ShareLink` appears only in
`Experience/ResultsView.swift` (`.autonomy/checks/A24-P06.scan-sources.json`). Graphics Benchmark Lab asks for no
permission (`"permissions": []` in `Catalog/registrations.json`). See [privacy-and-credits.md](privacy-and-credits.md)
and [licenses.md](licenses.md). No speed, timing, heat, memory or device figure is stated, and no comparison with
another device or another tool is made. The interface tests of chunk `f3` (`GBLRunUITests`, `GBLReleaseUITests`;
T-A24-608) prove the journeys through the app's controls on the iOS 27 phone simulator; they are simulator results,
not device measurements. Device measurements wait for the device campaign ([device-campaign.md](device-campaign.md)).
