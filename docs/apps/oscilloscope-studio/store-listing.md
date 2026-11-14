# Oscilloscope Studio — store text input

This is an input for the owner, who enters the App Store text of the VisualCore app; the agent never enters anything
in App Store Connect ([build-and-archive.md](../../release/build-and-archive.md) section 5). Oscilloscope Studio is an
experience of the free tier of VisualCore (`tier: free` in `Catalog/experiences.json`), not a separate app. Its
catalog entry is still marked `available: false` until the X-A08 gate integrates it. Feature 066 (A08-P06), FR-A08-620
and FR-A08-621.

Every sentence below describes a control that exists in `OscilloscopeStudio/Experience/ScopeControls.swift` or the
canvas of `OscilloscopeStudio/Experience/ScopePresenter.swift` and is exercised by the tests named in the traceability
table. The text is checked by `scripts/check_copy_claims.py` with `Configs/copy-claims-denylist.json`; the words audio
and microphone are allowed for this experience only (`copyCheck.allow` in [release.json](release.json)). The store
text names no number with a unit, and its readouts are described as relative to full scale only.

## Text

**Oscilloscope Studio** — a two-channel scope for sound inside VisualCore, free to use.

Watch a triggered waveform that holds still on every period. Set the timebase and the gain, and choose the trigger's
level, slope and mode: Auto runs freely, Normal keeps the last triggered trace.

Pick a source: the built-in test signal with a sine, a square or a sweep, which needs no permission, an audio file you
choose, which is read in place and not copied, or the microphone, which listens only while you have chosen it. Files
and two-channel microphone routes show both channels.

Switch between three views: the waveform, an XY view that plots the left channel against the right, and a spectrum
view with a readout of its strongest peak. Every level is shown relative to full scale.

Freeze the picture to study it, then show the cursors to read the time between two points, the frequency and the
level, or a frequency and level in the spectrum. Pinch to zoom the timebase.

Start from three built-in presets — Audio overview, Bass detail and Spectrum check — or save your own under a name,
then apply, rename or delete them later; they stay on your device.

Every control has a VoiceOver label, and VoiceOver describes the view, the source, the channels and the readout and
announces changes as they happen. Without microphone access, every view, the cursors and the presets still work with
the test signal or a file. VisualCore draws less detail when the device needs it.

Nothing you hear is recorded, stored or sent.

## Traceability

| Claim | Proof |
|---|---|
| Triggered waveform that holds still on every period | `ScopeAcquisitionTests.consecutiveWindowsStartOnTheSamePhase`, `periodsPerWindowMatchTheTestSignalAtEveryTimebase` (package, Core); `ScopeSessionTests.testTheFirstFrameShowsATriggeredTenPeriodWindowOfTheTestSignal` (package); `ScopeRenderTests.testFramesAreNonBlankAndTheSineAndTheSquareDiffer` (package); `OSScopeUITests` (chunk p2, T-A08-609) |
| Timebase and gain | `ScopeAcquisitionTests.gainScalesTheDisplayAndMarksClipping` (package, Core); `ScopeStateTests.theChoiceTablesMatchTheClarification` (package, Core); `ScopeSessionTests.testGainClipsAndTheTimebaseWidensTheWindow` (package); `OSScopeUITests` (chunk p2, T-A08-609) |
| Trigger level, slope and mode; Auto runs freely, Normal keeps the last triggered trace | `ScopeAcquisitionTests.aFlatLineIsUntriggeredInAutoAndWaitingInNormal`, `normalModeKeepsTheLastTriggeredWindow` (package, Core); `ScopeSessionTests.testAFlatLineNeverTriggersAndNormalModeWaits`, `testAMissingCrossingNeverTriggersAndNormalModeKeepsTheLastTrace` (package); `ScopeCoreTests.testEveryActionIsAcceptedInRangeAndChangesTheDigest` (package) |
| Test signal: sine, square, sweep, without permission | `ScopeStateTests.theFirstStateIsAOneKilohertzSineAtOneMillisecondPerDivision` (package, Core); `ScopeSessionTests.testWaveformAndFrequencyRestartTheSource`, `testTheSpectrumReadoutFollowsTheSweep` (package); `ScopeAccuracyAuditTests.testSquareExtremesAndFundamentalPeak`, `testSweepPeaksLieInTheFrameRangeAndRise` (package); `OSScopeUITests` (chunk p2, T-A08-609) |
| An audio file read in place and not copied; an undecodable file keeps the source | `StereoFileAudioSourceTests.testStereoFileKeepsBothChannels`, `testMonoFileIsWrittenToBothChannels`, `testDamagedFileThrowsUndecodable` (VisualCoreRendering package); `ScopeSessionTests.testAnUndecodableFileKeepsThePreviousSource` (package); [privacy-and-credits.md](privacy-and-credits.md) |
| The microphone only while chosen; two-channel routes show both channels | `ScopeSessionTests.testAGrantedMicrophoneOnAOneChannelRouteIsReadAsOneChannel`, `testATwoChannelMicrophoneRouteDrawsXYAndARouteChangeFallsBackWithTheMark`, `testSuspendingStopsTheSourceAndActivatingStartsItOnAFreshBuffer` (package); `StereoMicrophoneAudioSourceTests.testTwoChannelRouteReportsTwoAndKeepsChannelsApart`, `testOneChannelRouteReportsOne`, `testRouteChangeRebuildsWithNewChannelCount` (VisualCoreRendering package, capture double); real routes in [device-campaign.md](device-campaign.md) |
| XY view plots left against right | `ScopeTraceTests.xyPointsEqualTheScaledPairsMappedIntoTheSquare` (package, Core); `ScopeSessionTests.testXYPlotsTheScaledSamplePairsOfTheStereoTestSignal`, `testAMonoSourceInXYFallsBackWithTheMarkAndAStereoSourceShowsXYAgain` (package); `ScopeRenderTests.testTheXYFrameIsNonBlankAndDiffersFromTheWaveformFrame` (package); `OSScopeUITests` (chunk p2, T-A08-609) |
| Spectrum view with a readout of its strongest peak | `SpectrumViewTests.theHighestPointIsTheStrongestLevel`, `eachColumnKeepsItsStrongestBin` (package, Core); `SpectrumReadoutTests.knownSinesReadWithinOneBinAndOnePointFiveDecibels`, `silenceHasNoSignalAndNoValue` (package, Core); `ScopeSessionTests.testTheSpectrumReadsTheOneKilohertzTestSineAndIgnoresTheGain` (package); `ScopeRenderTests.testTheSpectrumFrameIsNonBlankAndDiffersFromTheWaveformAndXYFrames` (package); `OSScopeUITests` (chunk p2, T-A08-609) |
| Every level relative to full scale | `SpectrumReadoutTests.theValidTextNamesFrequencyAndLevelRelativeToFullScale`, `noCalibratedWordingInAnyText` (package, Core); `ScopeAccuracyAuditTests.testEveryCasePasses`, `testReadoutWordsStayRelativeToFullScale`, `testWordingEntryRefusesAForbiddenWord` (package) |
| Freeze | `ScopeSessionTests.testAFrozenWindowStaysIdenticalWhileFramesArriveAndUnfreezingResumesTheNewest`, `testFreezingAnEmptyWindowIsRefusedWithAMessage`, `testAFrozenWindowKeepsItsMetadataOverGainLevelAndRouteChanges` (package); `ScopeRenderTests.testAFrozenFrameWithCursorsIsNonBlankAndDiffersFromTheLiveFrame` (package); `OSPresetsUITests` (chunk p2, T-A08-609) |
| Cursors: time, frequency and level; frequency and level in the spectrum | `ScopeReadoutTests.cursorsOnePeriodApartReadThePeriodAndFrequency`, `levelsReadTwoDecimalsAndATenthOfADecibel`, `theSpectrumCursorReadsItsColumnRoundedToTheBinWidth` (package, Core); `ScopeSessionTests.testCursorsOnePeriodApartReadThePeriodAndTheFrequency`, `testTheSpectrumFrequencyCursorReadsItsColumnWithTheBinWidthAndLevel`, `testOneFingerDragsTheNearestCursor` (package); `OSPresetsUITests` (chunk p2, T-A08-609) |
| Pinch to zoom the timebase | `ScopeZoomTests.oneStepPerDoublingOfTheScale`, `pinchFactorsFromEveryTimebaseGiveTheExpectedClampedSteps` (package, Core); `ScopeSessionTests.testThePinchStepsTheTimebaseOncePerDoublingClampedAtTheEnds` (package) |
| Three built-in presets: Audio overview, Bass detail, Spectrum check | `ScopePresetTests.theBuiltInsComeInOrderWithFixedIds` (package, Core); `ScopePresetStoreTests.testBuiltInsComeFirstAndAreReadOnly` (package); `ScopeCoreTests.testPresetApplyAppliesTheBuiltInsAndKeepsSourceFreezeAndCursors` (package); `OSPresetsUITests` (chunk p2, T-A08-609) |
| Own presets: save under a name, apply, rename, delete; stored on the device | `ScopePresetStoreTests.testSaveRenameApplyDeleteAndReloadInFiveOfFiveCases`, `testNamesAreTrimmedToOneToFortyCharactersAndDuplicatesAreAllowed`, `testANewSessionListsASavedPresetAndAppliesIt` (package); `ScopePresetMigrationTests` (package, T-A08-605); `OSPresetsUITests` (chunk p2, T-A08-609); [privacy-and-credits.md](privacy-and-credits.md) |
| VoiceOver labels; a description of view, source, channels and readout; announcements of changes, only with VoiceOver | `ScopeDescriptionTests.testTheDescriptionNamesEveryViewAndState`, `testChangesAreAnnouncedAtMostOncePerIntervalAndOnlyWithVoiceOver`, `testNothingIsAnnouncedWithoutVoiceOver`, `testARouteChangeAnnouncesTheChannelCount` (package); `ScopeAnnouncerTests` (package, Core); `OSScopeUITests`, `OSPresetsUITests` (controls found by identifier and label, chunk p2, T-A08-609) |
| Without microphone access, views, cursors and presets still work | `ScopeSessionTests.testADeniedMicrophoneKeepsThePreviousSourceAndOffersTheTestSignal` (package); `StereoMicrophoneAudioSourceTests.testDeniedIsRefusedWithoutCapture`, `testRestrictedIsRefusedWithoutCapture` (VisualCoreRendering package) |
| Less detail when the device needs it | `ScopeQualityTests.theThreeLevels`, `analysisEveryOneTwoAndFourFrames` (package, Core); `ScopeDescriptionTests.testTheCoreDeclaresThreeLevels`, `testLevelsHalveAndQuarterTheColumnsAndAnalysesWithTheSameDigest` (package) |
| Nothing recorded, stored or sent | `.autonomy/checks/A08-P06.os-no-network.json` (T-A08-603); `ScopePresetTests.theFileRoundTripsWithSortedKeysAndSettingsOnly` (presets hold settings only); [privacy-and-credits.md](privacy-and-credits.md) |
| Free tier | `Catalog/experiences.json` (`a08.oscilloscope-studio`, `tier: free`) |

No speed, timing, latency, device, hearing or health claim is made, and no accuracy beyond readouts relative to full
scale. Device measurements wait for the device campaign ([device-campaign.md](device-campaign.md)).
