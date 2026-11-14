# Audio Odyssey — store text input

This is an input for the owner, who enters the App Store text of the VisualCore app; the agent never enters anything
in App Store Connect ([build-and-archive.md](../../release/build-and-archive.md) section 5). Audio Odyssey is an
experience of the free tier of VisualCore (`tier: free` in `Catalog/experiences.json`), not a separate app. Its
catalog entry is still marked `available: false` until the X-A07 gate integrates it.

Every sentence below describes a control that exists in `AudioOdyssey/Experience/OdysseyControls.swift` or the canvas
of `AudioOdyssey/Experience/OdysseyPresenter.swift` and is exercised by the tests named in the traceability table. The
text is checked by `scripts/check_copy_claims.py` with `Configs/copy-claims-denylist.json`; the words audio, music and
microphone are allowed for this experience only (`copyCheck.allow` in [release.json](release.json)).

## Text

**Audio Odyssey** — a music-reactive flight inside VisualCore, free to use.

Fly along a winding path through three worlds made entirely by code: a Tunnel that widens with the sound, a Landscape
whose hills swell with it and a Star corridor whose stars spread out and sparkle. Switch worlds at any time and keep
flying from the same place, pause and resume, or start a New journey with a new path and new surroundings.

Pick a source: the built-in demo signal, which needs no permission, an audio file you choose, which is read in place
and not copied, or the microphone, which listens only while you have chosen it.

In the mapping editor, decide for each world what the music moves: its shape and its light can each follow the bass,
the mids, the highs, the beats or the overall level, with low, medium or high sensitivity. Reset all mappings with one
button.

Set the speed with a slider from 0.5 to 7 units per second or with the Slow, Medium and Fast choices, and choose how
gently the flight changes speed: Gentle, Standard or Brisk. Calm motion caps the speed at 2.5 units per second and
removes the sideways sway; the system's Reduce Motion setting does the same.

Start from three built-in journeys — Deep tunnel, Rolling hills and Night stars — or save your own under a name, then
apply, rename or delete them later; they stay on your device.

Every control has a VoiceOver label, and VoiceOver announces the world, the source, an applied journey and pausing as
they change. Music you are playing in other apps keeps playing. Without microphone access, every world, the mapping
editor and the journeys still work with the demo signal or a file. VisualCore draws less detail when the device needs
it.

Nothing you hear is recorded, stored or sent.

## Traceability

| Claim | Proof |
|---|---|
| Three worlds: Tunnel, Landscape, Star corridor, each responding to the sound | `WorldPiecesTests.piecesAreDeterministicAndDifferByWorld`, `WorldResponseTests.primaryScalesFollowTheClarification` (package, Core); `OdysseyRenderTests.testTheThreeWorldsDrawDifferentNonBlankPictures` (package); `OdysseyMappingTests.testTheMappedLowToneRaisesThePrimaryAndEachWorldAppliesItsScale` (package); `AOJourneyUITests` (chunk o2, T-A07-609) |
| Switch worlds and keep flying from the same place | `OdysseyCoreTests.aWorldSwitchKeepsDistanceAndSpeed` (package); `OdysseySessionTests.testWorldSwitchesAndANewJourneyRebuildTheWindowAndTheLastSwitchWins` (package); `AOJourneyUITests` (chunk o2, T-A07-609) |
| Pause and resume; New journey with a new path | `OdysseyCoreTests.pauseEasesToRestAndKeepsTheJourneyAndResumeContinues`, `eachActionChangesTheDigestAndTheMirrorDoesNot` (package); `JourneyRailTests.theRailIsDeterministicAndSeedDependent` (package, Core); `AOJourneyUITests` (chunk o2, T-A07-609) |
| Three sources: demo signal without permission, a chosen audio file read in place, the microphone only while chosen | `OdysseySourcePickerTests.testTheDemoFirstThenAFileIsNamedAndTheDemoAgain`, `testTheMicrophoneGrantedPlaysAsMicrophone`, `testNotDeterminedAsksOnceThenPlaysOrFallsBackToTheDemo`, `testAnUndecodableFileKeepsTheSourceAndSaysWhy` (package); `OdysseyCoreTests.theFlightStartsWithoutAPromptAndEasesTowardMedium`, `sourceSwitchesKeepTheFlight` (package) |
| Mapping editor: shape and light per world follow bass, mids, highs, beats or overall level, low/medium/high sensitivity; reset all | `WorldMappingTests` (package, Core); `AudioEnvelopeTests.aBandPulseRaisesOnlyItsChannel` (package, Core); `OdysseyMappingTests.mappingsAreKeptPerWorldAndResetRestoresTheDefaults`, `aPulseOnOneChannelRaisesOnlyTheResponsesMappedToIt` (package); `AOPresetsUITests` (chunk o2, T-A07-609) |
| Speed slider 0.5 to 7 units per second; Slow, Medium, Fast | `JourneyStateTests.theSpeedTargetIsSnappedAndClamped`, `speedChoicesAndWorldNamesMatchTheClarification` (package, Core); `OdysseyCoreTests.speedEasesWithinTheStandardLimits` (package); `AOJourneyUITests` (chunk o2, T-A07-609) |
| Easing: Gentle, Standard, Brisk | `WorldMappingTests.gainsAndEasingFactorsMatchTheClarification` (package, Core); `OdysseyComfortTests.gentleTakesAtLeastTwiceAsLongAsBriskFromSlowToFast`, `seededSpeedAndEasingSequencesStayWithinTheLimitsAndSettle` (package) |
| Calm motion caps the speed at 2.5 units per second and removes the sideways sway; Reduce Motion does the same | `OdysseyComfortTests.calmMotionCapsTheSpeedAndRemovesTheSway` (package); `OdysseyCoreTests.reduceMotionCapsTheSpeedAndRemovesTheSway` (package); `OdysseySessionTests.testTheCameraSwaysAlongTheLevelRightAxisAndNotAtAllUnderReduceMotion` (package); `AOJourneyUITests` (chunk o2, T-A07-609) |
| Three built-in journeys: Deep tunnel, Rolling hills, Night stars | `JourneyPresetTests.builtInsAreValidReadOnlyDistinctAndAsSpecified` (package, Core); `JourneyPresetStoreTests.testBuiltInsAreListedFirst`, `testBuiltInsCannotBeRenamedOrDeleted` (package); `OdysseyPresetApplyTests.testABuiltInAppliedThroughThePresenterKeepsTheFlight` (package); `AOPresetsUITests` (chunk o2, T-A07-609) |
| Own journeys: save under a name, apply, rename, delete; stored on the device | `JourneyPresetStoreTests.testSaveReloadApplyRoundTripsEveryFieldOverSeededStates`, `testSavingOrRenamingToATakenNameGetsTheNextFreeSuffix`, `testDeleteRemovesTheFile` (package); `OdysseyPresetApplyTests.testWithStorageThePresenterSavesRenamesAndDeletesTheSelectedJourney` (package); `OdysseyPersistenceTests` (package); `JourneyPresetMigrationTests` (package, T-A07-605); `AOPresetsUITests` (chunk o2, T-A07-609); [privacy-and-credits.md](privacy-and-credits.md) |
| VoiceOver labels; announcements of world, source, applied journey and pause, only with VoiceOver | `OdysseyAnnouncementTests` (package); `JourneyAnnouncerTests` (package, Core); `OdysseySessionTests.testTheFirstFrameDrawsTheTunnelWindowThroughTheHostAndDescribesIt` (package); `AOJourneyUITests`, `AOPresetsUITests` (controls found by identifier and label, chunk o2, T-A07-609) |
| Music in other apps keeps playing | `MicrophoneSourceTests.testSessionMixesWithOtherAudio` (`MicrophoneAudioSource.sessionOptions` contains `.mixWithOthers`; VisualCoreRendering package); real-device confirmation in [device-campaign.md](device-campaign.md) |
| Without microphone access, worlds, mapping editor and journeys still work | `OdysseySourcePickerTests.testDeniedOrRestrictedShowsTheWayToSettingsAndKeepsTheDemo`, `OdysseyAudioTests.testDeniedAccessRefusesTheMicrophoneKeepsTheDemoAndShowsTheWayToSettings` (package); `OdysseyCoreTests.theMicrophoneIsRefusedByTheRuleOnlyWhileAccessIsOff` (package) |
| Less detail when the device needs it | `OdysseyQualityTests.testEachLevelShrinksTheTunnelWindowAndTheFog`, `testTheStarCorridorCarriesTheLevelsStarCount`, `testLevelChangesMidFlightLeaveTheJourneyAndItsDigestUnchanged` (package); `LongDistanceTests.levelsAndStarCountsDoNotIncrease` (package, Core) |
| Nothing recorded, stored or sent | `.autonomy/checks/A07-P06.ao-no-network.json` (T-A07-603); `JourneyPresetTests.fileRoundTripIsEqualAndNotBuiltIn` (journeys hold no audio); [privacy-and-credits.md](privacy-and-credits.md) |
| Free tier | `Catalog/experiences.json` (`a07.audio-odyssey`, `tier: free`) |

No speed, timing, device, hearing, health or comfort claim is made; "units per second" is the flight's own speed
setting in the generated world, not a measurement. Device measurements wait for the device campaign
([device-campaign.md](device-campaign.md)).
