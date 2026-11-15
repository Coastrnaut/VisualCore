# Neon Arcade — privacy and credits

Neon Arcade is the experience `a10.neon-arcade` of the one VisualCore app (ADR-0009). It has no app target, Info.plist
or privacy manifest of its own: the app's declarations cover it. Feature 080 (A10-P06), FR-A10-601 and FR-A10-604.
Sources: `Packages/ExperiencesCreative/NeonArcade` (below: NA).

## What is stored on the device

| What | Where | Written by | Content |
|---|---|---|---|
| High-score table | `high-scores.json` in the experience's own storage folder, `Application Support/Experiences/a10.neon-arcade/` | `NA/Experience/HighScoreStore.swift` through `ExperienceStorage.write` (atomic replace: a reader sees the complete old or the complete new table) | The table of the best runs (`HighScoreTable`, board version 1): at most ten entries of score, wave and run number, highest score first, and the number of the last run processed. No date, no name of a person, no device data and no address |
| Saved session state | `state.json` in the same folder | the app (`SavedStateStore`, `Apps/VisualCore/App/AppModel.swift`), not the experience | The session snapshot of the core (`ArcadeCore`, snapshot schema 4): the current run (score, lives, wave, player, falling objects, recent events, seeded generator state), the screen (title, playing, paused, over), the Sound and Haptics settings, the steering sensitivity step and the run number, so that the game resumes where it was. Snapshots of schemas 1 to 3 are migrated on restore |

Nothing else is persisted by the experience. The player, hazards, orbs and spawn patterns are part of the code
(`ArcadeCatalog.bundled`, `PatternTable.bundled`) and are never written. Its sources write no named defaults values
(`ExperienceStorage.setValue` is not called), no other files and no `UserDefaults` values. A high-score file that is
damaged, half-written or of a newer board version is reported once ("high scores could not be read") and left in place
until the next finished run writes a valid table; play is never stopped
(`HighScoreStoreTests.testANewerOrInvalidFileIsReportedAndThenReplaced`;
`HighScoreTableTests.damagedTruncatedAndNewerJSONAreRefusedWithAReason`). An interrupted save leaves the last complete
table (`HighScoreStoreTests.testAnInterruptedSaveLeavesTheLastCompleteTable`); a save the storage refuses is reported
once and the table stays in memory for the session
(`HighScoreStoreTests.testARefusedStorageIsReportedOnceAndTheTableStaysInMemory`). A saved state of a newer schema or
with damaged content is refused and a new run opens (`ArcadeSessionTests.testANewerSavedStateIsRefusedAndANewRunOpens`,
`testADamagedSavedStateIsRefusedAndANewRunOpens`).

## How to delete

- **Neon Arcade's data.** In the app's Settings, the data section lists every experience with stored data; its reset
  button for Neon Arcade, after a confirmation, removes the experience's folder with `high-scores.json` and the saved
  session state (`Apps/VisualCore/App/SettingsView.swift`, `AppModel.reset(_:)` with `ResetPlan.experience`). The
  next opening starts on the title screen with an empty table.
- **Everything.** The reset of all data in the same section, or removing the app, removes every experience's folder,
  the high-score table and the saved session state included.

## Permissions

Neon Arcade requests no permission and adds no usage string (FR-A10-601). Its registration declares no permission, and
it uses no sensor: no motion, location, contacts, photo library, microphone or camera. Steering uses only touches on
the field and the native controls.

- **Sound** is synthesized in code (four sound shapes, `ArcadeEffects`) and played through VisualCore's
  `SoundEffectPlayer` with the ambient audio session: it mixes with other playback, follows the silent switch, and
  never opens an input or asks for the microphone
  (`SoundEffectPlayerTests.testPlayingUsesTheAmbientSessionAndNeedsNoMicrophonePermission`). Interruptions and moving
  to the background stop playback (`testInterruptionStopsPlayback`, `testMovingToTheBackgroundStopsPlayback`). The
  Sound toggle turns it off.
- **Haptics** go through the host's `ExperienceFeedback` and the system's haptic engine, only while the Haptics toggle
  is on; the system-wide setting is honoured (`ArcadeSessionTests.testTheSoundAndHapticSinksReceiveCuesOnlyWhenEnabled`).

## What is not done

- **Nothing is sent.** There is no upload, sync, sign-in, user account, online score table, analytics or crash
  reporting by the experience. The high-score table never leaves the device.
- **No network, tracking, recording or sensors.** The sources of the experience contain no `URLSession`,
  `import Network`, `CLLocation`, `AVCapture`, `AVAudioRecorder`, `inputNode`, `installTap`, `MicrophoneAudioSource`,
  `CMMotion`, `CNContact`, `ASIdentifierManager` or `AppTrackingTransparency` (check `na-no-network`, T-A10-603:
  `.autonomy/checks/A10-P06.na-no-network.json`). The app tracks nothing (`NSPrivacyTracking` false, no tracking
  domains).
- **No change to the system screen.** The experience never sets the system screen brightness
  (`UIScreen.main.brightness`) and never disables the idle timer (`isIdleTimerDisabled`) (the same scan).
- **Low Power Mode is read, not changed.** The host's public `ProcessInfo` state selects the lowest drawing level; the
  run does not change with it (`ArcadeSessionTests.testLowPowerModeDrawsLevelZeroAndNeverChangesTheState`).

## Required-reason APIs and the app's privacy manifest

The app manifest `Apps/VisualCore/Resources/PrivacyInfo.xcprivacy` declares no tracking, no collected data types and
three accessed-API categories. The experience's uses fall under them; it adds none:

| Category and reason | Use by Neon Arcade |
|---|---|
| `NSPrivacyAccessedAPICategoryFileTimestamp`, `C617.1` | `ExperienceStorage` reads file attributes (type and size) of the experience's own files when the high-score table is read or written |
| `NSPrivacyAccessedAPICategoryUserDefaults`, `CA92.1` | `ExperienceStorage` holds the app's `UserDefaults` for named values under the prefix `exp.a10.neon-arcade.`; Neon Arcade stores none |
| `NSPrivacyAccessedAPICategorySystemBootTime`, `35F9.1` | Frame times and quality decisions come from the app's render host (`ExperienceSession`); the game advances by its own fixed step, and the experience's sources read no boot time. Elapsed time inside the app only |

The built product is checked against this manifest by `release_check.py --only app-release-build
app-privacy-manifest app-no-tracking app-usage-descriptions` ([build-and-archive](../../release/build-and-archive.md);
T-A10-612).

## Credits

- **Content.** The player (Chevron), both hazards (Spike ball, Bar), the orb (Glow orb) and the four spawn patterns of
  the wave director (Rain, Wall, Zigzag, Orb trail) are original content by the VisualCore project under the MIT
  license. The full table with author and license per item is [content-licenses.md](content-licenses.md), generated
  from `ArcadeCatalog.bundled` and `PatternTable.bundled` by `LicenseAudit.markdown(_:)` and checked against them by
  `LicenseAuditTests.theCommittedLicenseDocumentMatchesTheCatalog` (8 entries, 0 problems).
- **Visuals.** Drawn by code only: the player, hazards, orbs, lane guides, score and wave text, glow, particle bursts
  and screen transitions are generated at run time through the host's renderers. No image, model, font or data file
  from a third party is bundled.
- **Sound.** Every sound effect is synthesized at run time from a waveform, a pitch sweep and an envelope
  (`SoundEffect` in `Packages/VisualCore`); no recording or sound file is bundled.
- **Code.** The experience's sources (simulation, collision use, wave director, flow, effects, high-score table,
  presenter and controls) are this repository's own code. The experience depends only on the local packages
  `Packages/VisualCore` and `Packages/VisualCoreRendering` (`Packages/ExperiencesCreative/Package.swift`); it adds no
  third-party package. The app's third-party components (ANGLE and the libraries inside it, listed in
  `docs/legal/third-party.json`) are bundled under the app's `Licenses` folder, shown in the app's Acknowledgements and
  checked by `app-licenses`.
- **Test samples.** The committed sample high-score files are resources of the test target only (T-A10-604);
  `scenario-manifest.json` is outside every target's path.
- **ProjectM.** Not used; no engine code, preset format or name of it is in the experience, and ProjectM types stay out
  of the app.
