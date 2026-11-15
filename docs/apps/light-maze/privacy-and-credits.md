# Light Maze — privacy and credits

Light Maze is the experience `a13.light-maze` of the one VisualCore app (ADR-0009). It has no app target, Info.plist
or privacy manifest of its own: the app's declarations cover it. Feature 101 (A13-P06), FR-A13-601 and FR-A13-604.
Sources: `Packages/ExperiencesCreative/LightMaze` (below: LM).

## What is stored on the device

| What | Where | Written by | Content |
|---|---|---|---|
| Level progress | `progress.json` in the experience's own storage folder, `Application Support/Experiences/a13.light-maze/` | `LM/Experience/ProgressStore.swift` through `ExperienceStorage.write` (atomic replace: a reader sees the complete old or the complete new file), only when a solve changes the progress | One `Progress` document (file schema 1, sorted keys, at most 16 KB): for each of the 20 catalog levels, in catalog order, its id (`lm-01` … `lm-20`), whether it is open, whether it is solved and the fewest moves it took (1 … 999). No date, no name of a person, no device data and no address |
| Saved session state | `state.json` in the same folder | the app (`SavedStateStore`, `Apps/VisualCore/App/AppModel.swift`), not the experience | The session snapshot of the core (`MazeCore`, snapshot schema 2): the current level, the orientation of each mirror and prism, the selected tile and the moves made on the level (at most 64), so that the maze reopens where it was. Snapshots of schema 1 are restored with no moves (`MazeCoreTests.testTheSchemaOneExampleRestoresWithNoMoves`; `MovesTests.movesRoundTripAndSchemaOneMigrates`) |

Nothing else is persisted by the experience. The 20 levels are part of the code (`LevelCatalog.bundled`) and are never
written. Its sources write no named defaults values (`ExperienceStorage.setValue` is not called), no other files and no
`UserDefaults` values. Loading never writes: with no file (a first launch, or after a data reset) play starts from fresh
progress (level 1 open, nothing solved); a file that is damaged, half-written, too large or of a newer schema is refused
with its reason (`damaged`, `too-large`, `newer-version`), play starts from fresh progress, and the file is left byte for
byte as it was until the next solve replaces it (`ProgressStoreTests.testRefusedFilesAreReportedAndLeftUntouched`,
`ProgressStoreTests.testAnAbsentFileGivesFreshProgressAndWritesNothing`,
`MazeProgressTests.testADamagedProgressFileOpensWithFreshProgressAndReportsTheRefusal`). An interrupted or refused write
keeps the previous file (`ProgressStoreTests.testAnInterruptedOrRefusedWriteKeepsThePreviousFileByteIdentical`). A saved
state of a newer schema or with damaged content is refused and level 1 opens
(`MazeSessionTests.testANewerSavedStateIsRefusedAndTheFirstLevelOpens`,
`testADamagedSavedStateIsRefusedAndTheFirstLevelOpens`). The progress lives outside the engine state, so neither loading
nor saving changes a state digest or a replay.

## How to delete

- **One level's moves.** Restart returns the level's tiles to their starting orientations and clears its moves; it does
  not change the progress (`MazeStateTests.selectingTurningAndResetting`, `MovesTests.resetAndChoosingALevelEmptyTheMoves`).
- **Light Maze's data.** In the app's Settings, the data section lists every experience with stored data; its reset
  button for Light Maze, after a confirmation, removes the experience's folder with `progress.json` and the saved
  session state (`Apps/VisualCore/App/SettingsView.swift`, `AppModel.reset(_:)` with `ResetPlan.experience`). The next
  opening starts at level 1 with only level 1 open.
- **Everything.** The reset of all data in the same section, or removing the app, removes every experience's folder,
  the progress and the saved session state included.

## Permissions

Light Maze requests no permission and adds no usage string (FR-A13-601). Its registration declares no permission
(`"permissions": []` in `Catalog/registrations.json`), and it uses no sensor: no motion, location, contacts, photo
library, microphone or camera. Play uses only touches on the canvas (tap, drag, two-finger rotation) and the native
controls.

- **Sound.** One sound: the success sweep, made in code (`LM/Experience/MazeSound.swift` from the constants of
  `SuccessCue`; no sound file), played once per solve through VisualCore's `SoundEffectPlayer`
  (`Packages/VisualCoreRendering/Sources/VisualCoreAudio/SoundEffectPlayer.swift`), which uses the ambient session
  category: it mixes with other sound, follows the silent switch and never opens the input, so nothing is recorded.
- **Haptics.** One `success` haptic per solve through the app's feedback route, which follows the person's haptics
  switch and its rate limit (`MazeFeedbackTests.testOneCuePerSolveWithWordsSoundAndRateLimitedHaptic`).

## What is not done

- **Nothing is sent.** There is no upload, sync, sign-in, user account, online level sharing, analytics or crash
  reporting by the experience. The progress never leaves the device; there is no export.
- **No network, tracking, recording or sensors.** The sources of the experience contain no `URLSession`,
  `import Network`, `CLLocation`, `AVCapture`, `AVAudioRecorder`, `inputNode`, `installTap`, `CMMotion`, `CNContact`,
  `ASIdentifierManager` or `AppTrackingTransparency` (check `lm-no-network`, T-A13-603:
  `.autonomy/checks/A13-P06.lm-no-network.json`). The app tracks nothing (`NSPrivacyTracking` false, no tracking
  domains).
- **No change to the system screen.** The experience never sets the system screen brightness
  (`UIScreen.main.brightness`) and never disables the idle timer (`isIdleTimerDisabled`) (the same scan).
- **No personal data.** The person types nothing; the progress holds level ids, flags and move counts only.

## Required-reason APIs and the app's privacy manifest

The app manifest `Apps/VisualCore/Resources/PrivacyInfo.xcprivacy` declares no tracking, no collected data types and
three accessed-API categories. The experience's uses fall under them; it adds none:

| Category and reason | Use by Light Maze |
|---|---|
| `NSPrivacyAccessedAPICategoryFileTimestamp`, `C617.1` | `ExperienceStorage` reads file attributes (type and size) of the experience's own `progress.json` when it is read or written |
| `NSPrivacyAccessedAPICategoryUserDefaults`, `CA92.1` | `ExperienceStorage` holds the app's `UserDefaults` for named values under the prefix `exp.a13.light-maze.`; Light Maze stores none |
| `NSPrivacyAccessedAPICategorySystemBootTime`, `35F9.1` | Frame times, which pace the spoken beam changes and the solved border, come from the app's render host (`ExperienceSession`); the experience's sources read no boot time. Elapsed time inside the app only |

The built product is checked against this manifest by `release_check.py --only app-release-build
app-privacy-manifest app-no-tracking app-usage-descriptions` ([build-and-archive](../../release/build-and-archive.md);
T-A13-612).

## Credits

- **Content.** The 20 levels (`lm-01` First light … `lm-20` Prism maze) are original content by the VisualCore project
  under the MIT license. The full table with author and license per level is [content-licenses.md](content-licenses.md),
  generated from `LevelCatalog.bundled` by `LicenseAudit.markdown(_:)` and checked against it by
  `LicenseAuditTests.theCommittedLicenseDocumentMatchesTheCatalog` (20 levels; 0 problems). Each level's solvability
  and fewest turns are in [content-qa.md](content-qa.md) (`ContentQATests.theCommittedQADocumentMatchesTheCatalog`).
- **Sound.** The success sweep is made in code from `SuccessCue`'s constants (a sine sweep with an attack and a
  release, no noise); no sound file is bundled. It is this repository's own code under the same license.
- **Visuals.** Drawn by code only: the board, the grid, the tiles, the beam and its glow, the rings, the outlines and the
  solved border are procedural shapes drawn at run time through the host's `PrimitiveRenderer`. No image, sprite,
  texture, font or data file from a third party is bundled.
- **Code.** The experience's sources (board, beam tracer, solver, levels, content QA, hints, board description,
  progress, presenter, gestures, controls and sound) are this repository's own code. The experience depends only on the
  local packages `Packages/VisualCore` and `Packages/VisualCoreRendering` (`Packages/ExperiencesCreative/Package.swift`);
  it adds no third-party package. The app's third-party components (ANGLE and the libraries inside it, listed in
  `docs/legal/third-party.json`) are bundled under the app's `Licenses` folder, shown in the app's Acknowledgements and
  checked by `app-licenses`.
- **No third-party content.** No level, sound, picture or code from outside the project is in the experience.
- **Test samples.** The committed sample progress files (`progress-valid.json`, `progress-newer.json`,
  `progress-damaged.json`, `progress-truncated.json`; A13-P06, T-A13-605) are resources of the test target only;
  `scenario-manifest.json` is outside every target's path.
- **ProjectM.** Not used; no engine code, preset format or name of it is in the experience, and ProjectM types stay out
  of the app.
