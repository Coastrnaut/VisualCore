# Aurora — store text input

This is an input for the owner, who enters the App Store text of the VisualCore app; the agent never enters anything
in App Store Connect ([build-and-archive.md](../../release/build-and-archive.md) section 5). Aurora is an experience
of the free tier of VisualCore (`tier: free` in `Catalog/experiences.json`), not a separate app. Feature 157
(A21-P06), FR-A21-605 and FR-A21-606.

Every sentence below describes something that exists in the controls (`Aurora/Experience/AuroraControls.swift`), the
presenter (`AuroraPresenter.swift`), the adapter (`Experience/Adapter/AuroraCore.swift`) or the sound
(`SkySound.swift`), and is exercised by the tests named in the traceability table. The text is checked by
`scripts/check_copy_claims.py` with `Configs/copy-claims-denylist.json` ([release.json](release.json) allows no word
through `copyCheck.allow`, because Aurora hands nothing to another app) and by the experience's own word scan of
T-A21-607 (`specs/157-au-p06-release/scan-claims-release.sh`, the refused words of the spec's Clarifications Q2). The
store text names no performance figure and no value from a device, and makes no claim beyond what the code holds.

## Text

**Aurora** — a calm, full-screen sky of glowing ribbons, stars and drifting clouds, drawn in code, inside VisualCore.

Choose one of three skies: Polar night, Violet veil or Dawn haze. Each is stylized art made in code.

Shape the sky with your own colour shift, speed, turbulence, ribbons, stars and clouds. A brightness limit you choose
keeps every part of the sky at or below it.

When you pick another sky, the old one fades gently into the new one while both keep moving.

Your choices are kept on your device, so Aurora opens with the sky you chose.

For a quieter screen, turn on Still sky to hold one unmoving picture, or Reduced flashing to stop the stars twinkling
and slow every change between skies. With Reduce Motion on, the sky stays still.

If the device cannot draw the full sky, Aurora shows a simpler sky and says so.

An optional sound, made in code, plays only while Aurora is open. It is off until you turn it on, and its volume is
yours to set.

Hide the controls to see only the sky, and tap the sky to bring them back.

Every control has a spoken label and value for VoiceOver. Aurora works offline and needs no permission.

## Traceability

| Claim | Proving test |
|---|---|
| Three skies: Polar night, Violet veil or Dawn haze, made in code | `PresetTests.swift theIdsAreUniqueAndInOrder`; `PresetTests.swift thePresetsHaveTheirDescribedCharacter`; `SkyRenderTests.swift testEachPresetMatchesItsReferenceAtBothLevelsWithinTheBrightnessRange`; `AUSkyUITests` (picking Violet veil names it on the canvas) |
| Colour shift, speed, turbulence, ribbons, stars and clouds | `AuroraCoreTests.swift theEightControlsAreDeclaredWithTheirRanges`; `AuroraCoreTests.swift everyActionIsAcceptedInRange`; `AuroraCoreTests.swift outOfRangeAndFractionalValuesAreRefusedAndChangeNothing`; `BlendTests.swift theHueShiftTurnsThePaletteAndZeroChangesNothing` |
| A brightness limit you choose keeps every part of the sky at or below it | `LimitTests.swift testEveryPresetStaysUnderEveryLimit`; `LimitTests.swift testALowLimitDimsTheBrightestPixelsAndKeepsTheirHue`; `LimitRenderTests.swift everyPresetStaysUnderEveryLimit`; `LimitRenderTests.swift everyChangeStaysUnderTheLowLimit` |
| The old sky fades into the new one while both keep moving | `TransitionTests.swift aChangeTakesTwoSecondsEasedWithBothSkiesMoving`; `TransitionTests.swift everyStepIsUnderTheLimitAndMovesTowardsTheNewSky`; `TransitionTests.swift aNewChoiceDuringAChangeRestartsFromTheCurrentMix` |
| Your choices are kept on your device; Aurora opens with the sky you chose | `PreferencesStoreTests.swift closingAndReopeningKeepsEveryChoice`; `PreferencesTests.swift aChangedValueSetRoundTripsExactlyAndDeterministically`; `PreferencesStoreTests.swift damagedNewerAndOutOfRangeValuesOpenWithTheDefaults`; `SkyRecoveryDrawTests` (a failed draw keeps the saved choices); `StoredSampleTests` (the committed samples open or are refused, byte-identical) |
| Still sky holds one unmoving picture | `StillViewTests.swift theStillSkyIsDrawnOnceAndOnceMoreAfterAChange`; `StillViewTests.swift aChangeBetweenSkiesCompletesThenHolds`; `StillViewTests.swift withReduceMotionTooTheStillViewWinsAndHolds`; `AUSkyUITests` (Still sky and Reduced flashing turn on) |
| Reduced flashing stops the stars twinkling and slows every change between skies | `ReducedFlashTests.swift theControlTurnsTheTwinkleOffAndSlowsAChange`; `ReducedFlashTests.swift theSystemsReduceFlashingTurnsTheModeOn`; `AUSkyUITests` (Still sky and Reduced flashing turn on) |
| With Reduce Motion on, the sky stays still | `ClockTests.swift testHeldUnderReducedMotionAndAtSpeedZero`; `ReducedMotionFrameTests.swift testReducedMotionFramesAreByteIdentical`; `BlendTests.swift underReduceMotionAChangeIsImmediateAndTheSkyStill`; `TransitionTests.swift underReduceMotionAChangeIsImmediate` |
| A simpler sky when the device cannot draw the full sky, and Aurora says so | `FallbackTests.swift aCompileFailureShowsTheFallbackSky`; `FallbackTests.swift aMissingHighpShowsTheFallbackSky`; `FallbackTests.swift whenTheFallbackFailsTooTheSkyColourRemains` |
| An optional sound made in code, only while Aurora is open, off until turned on, with its volume | `SoundLoopTests.swift aFreshStartHasTheSoundOffAndMakesNoPlayer`; `SoundLoopTests.swift theLoopPlaysOnlyWhileOnOnScreenAndActive`; `SoundLoopTests.swift theVolumeIsPassedAtOnce`; `SoundChoiceTests.swift theSoundChoiceOutlivesEveryLifecycleEvent`; `AUSoundUITests` (the sound choice comes back after a relaunch); `AUReleaseUITests` (a fresh start reads the sound, Still sky and Reduced flashing off) |
| Hide the controls and tap the sky to bring them back | `ChromeTests.swift hiddenControlsReturnByATapAndByTheAction`; `ChromeTests.swift aDragACancelledTouchOrASuspensionDoNotShowTheControls`; `AUSkyUITests` (hidden controls come back with a tap on the sky) |
| Spoken labels and values for VoiceOver | `ChromeTests.swift everyControlHasASpokenLabelAndANativeAction`; `SoundChoiceTests.swift theSoundControlsHaveSpokenLabelsAndSendNothing` |
| Works offline and opens on the sky of the last session | `AuroraCoreTests.swift theSnapshotRoundTrips`; `AuroraManifestTests.swift theSaveRestoreStateSurvivesARestore`; `PreferencesStoreTests.swift aRestoredSnapshotWinsForTheSkyNeverForTheSound`; `AUReleaseUITests` (a fresh start opens on Polar night) |

The source scan of the experience (`au-no-network`, T-A21-603) proves that no network, tracking, sensor, recording,
sound input, photo-library, idle-timer or brightness use is in `Packages/ExperiencesCreative/Aurora`
(`.autonomy/checks/A21-P06.au-no-network.json`). Aurora asks for no permission (`"permissions": []` in
`Catalog/registrations.json`). See [privacy-and-credits.md](privacy-and-credits.md) and [licenses.md](licenses.md).
No speed, timing, heat, memory, brightness or device claim is made. The interface tests of chunk `c3`
(`AUSkyUITests`, `AUSoundUITests`, `AUReleaseUITests`; T-A21-608) prove the journeys through the app's controls on
the iOS 27 phone simulator; they are simulator results, not device measurements. Device measurements wait for the
device campaign ([device-campaign.md](device-campaign.md)).
