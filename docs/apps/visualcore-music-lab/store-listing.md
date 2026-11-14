# VisualCore Music Lab — store text input

This is an input for the owner, who enters the App Store text of the VisualCore app; the agent never enters anything
in App Store Connect ([build-and-archive.md](../../release/build-and-archive.md) section 5). VisualCore Music Lab is an
experience of the free tier of VisualCore (`tier: free` in `Catalog/experiences.json`), not a separate app. Its
catalog entry is still marked `available: false` until the X-A06 gate integrates it.

Every sentence below describes a control that exists in `VisualCoreMusicLab/Experience/MusicLabControls.swift` or the
canvas of `VisualCoreMusicLab/Experience/MusicLabPresenter.swift` and is exercised by the tests named in the
traceability table. The text is checked by `scripts/check_copy_claims.py` with `Configs/copy-claims-denylist.json`;
the words audio, music and microphone are allowed for this experience only (`copyCheck.allow` in
[release.json](release.json)).

## Text

**VisualCore Music Lab** — a music visualizer inside VisualCore, free to use.

Watch sound turn into moving pictures made entirely by code. Pick a source: the built-in demo signal, which needs no
permission, an audio file you choose, which is read in place and not copied, or the microphone, which listens only
while you have chosen it.

Choose one of three scenes: Bars, Rings or Geometry. In the mapping editor, decide which part of the sound drives
each parameter of the scene — the level, the peak, the beat or one of four frequency regions — and how strongly, or
reset the scene's mapping. Colour every scene with one of three palettes: Aurora, Ember or Mono.

Start from three built-in presets, one per scene, or save your own under a name, then apply, rename or delete them
later; they stay on your device.

A short sound metrics text names the level, the strongest frequency region and the beat as an approximate visual aid,
and VoiceOver reads it and describes the canvas. With Reduce Motion on, the Geometry scene stops spinning with the
sound.

When a call or another app takes the microphone, Music Lab pauses and offers Resume or the demo signal; music you are
playing in other apps keeps playing. Without microphone access, every scene, the mapping editor and the presets still
work with the demo signal or a file. VisualCore analyses the sound in less detail when the device needs it.

Nothing you hear is recorded, stored or sent.

## Traceability

| Claim | Proof |
|---|---|
| Three sources: demo signal without permission, a chosen audio file read in place, the microphone only while chosen | `MusicLabSessionTests.testTheDemoToneIsDrawnAsTheRingBuffersNewestSamples`, `testAccessOffRefusesTheMicrophoneWithoutARequestAndKeepsTheDemo`, `testANotDeterminedPermissionIsAskedOnceAndARefusalFallsBackToTheDemo`, `testClosingStopsTheSource`, `testAnUndecodableFileKeepsThePreviousSourceAndShowsAMessage` (package); `MusicLabCoreTests.eachSourceModeAndReseedActionChangesTheDigest` (package) |
| Three scenes: Bars, Rings, Geometry | `MusicLabSceneTests.thereAreThreeScenesWithTwoTwoAndThreeParameters` (package); `MusicLabSceneRenderTests.testTheThreeScenesDrawDifferentPicturesOfTheTone`, `testEachSceneChangesBetweenSilenceAndTheTone` (package); `MLScenesUITests` (chunk m2, T-A06-609) |
| Mapping editor: level, peak, beat or one of four regions per parameter, strength, reset | `MusicLabSceneTests.mappingChoiceRefusesOutOfRangeValues`, `MusicLabCoreTests.sceneAndMappingActionsChangeTheDigest` (package); `MusicLabSceneRenderTests.testAGainOfTwoDoublesTheSettledValueInsideTheRange`, `testTheSceneAndMappingSurviveASnapshot` (package); `MetricTextTests.bandsAreSummedIntoFourRegions` (package); `MLPresetsUITests` (chunk m2, T-A06-609) |
| Three palettes: Aurora, Ember, Mono, on every scene | `MusicLabPaletteTests.thereAreThreePalettesWithIndicesAndNames`, `palettesDifferPairwiseInBarAndWave` (package); `MusicLabMetricsTests.testEachPaletteChangesTheBarsPicture` (package); `MusicLabCoreTests.thePaletteActionAndPresetPaletteChangeTheDigest` (package); `MLScenesUITests` (chunk m2, T-A06-609) |
| Three built-in presets, one per scene | `MusicPresetTests.builtInsAreValidReadOnlyAndDistinct` (package); `MusicLabPresetStoreTests.testBuiltInsAreListedFirst`, `testBuiltInsCannotBeRenamedOrDeleted` (package); `MLPresetsUITests` (chunk m2, T-A06-609) |
| Own presets: save under a name, apply, rename, delete; stored on the device | `MusicLabPresetStoreTests.testSaveThenReloadInANewLibraryKeepsTheChoices`, `testRenameToAUsedNameIsMadeUniqueAndKeepsTheSavedDate`, `testDeleteRemovesTheFile` (package); `MusicLabCoreTests.applyingAPresetSetsTheSceneAndItsChoices` (package); `MLPresetsUITests` (chunk m2, T-A06-609); [privacy-and-credits.md](privacy-and-credits.md) |
| Sound metrics text: level, strongest region, beat, approximate; read by VoiceOver; canvas description | `MetricTextTests` (package); `MusicLabMetricsTests.testTheMetricTextOfTheToneAndOfSilence`, `testAnnouncementsAreRateLimitedAndOnlyWithVoiceOver` (package); `MLScenesUITests` (chunk m2, T-A06-609) |
| Reduce Motion: the Geometry scene stops spinning with the sound | `MusicLabSceneRenderTests.testReduceMotionKeepsTheSpinAtItsMinimum` (package) |
| Pause on a call or another app, Resume or the demo signal | `AudioSessionEventTests`, `MicrophoneRecoveryTests.testBeganInterruptsAndStopsCapture`, `testEndedWithoutResumeWaitsForResume`, `testRouteLostAndMediaResetWhileRunningRebuild` (VisualCoreRendering package); `MusicLabRecoveryTests.testPausedThenResumeThenStoppedWithUseDemo` (package); `MusicLabTransitionTests` (package) |
| Music in other apps keeps playing | `MicrophoneSourceTests.testSessionMixesWithOtherAudio` (`MicrophoneAudioSource.sessionOptions` contains `.mixWithOthers`, not `.duckOthers`; FR-A06-107; VisualCoreRendering package); real-device confirmation in [device-campaign.md](device-campaign.md) |
| Without microphone access, scenes, mapping editor and presets still work | `MusicLabDeniedUsabilityTests.testEverythingButTheMicrophoneWorksWithAccessDenied` (package); `MusicLabCoreTests.theMicrophoneIsRefusedByRuleWhileAccessIsOff` (package) |
| Less analysis detail when the device needs it | `MusicLabMetricsTests.testTheTierSelectsTheAnalysisLevel` (package) |
| Nothing recorded, stored or sent | `.autonomy/checks/A06-P06.ml-no-network.json` (T-A06-603); `MusicLabPresetStoreTests` (presets hold no audio); [privacy-and-credits.md](privacy-and-credits.md) |
| Free tier | `Catalog/experiences.json` (`a06.visualcore-music-lab`, `tier: free`) |

No speed, timing, device, hearing or health claim is made; device measurements wait for the device campaign
([device-campaign.md](device-campaign.md)).
