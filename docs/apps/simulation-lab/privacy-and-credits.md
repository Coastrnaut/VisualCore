# Simulation Lab — privacy and credits

Simulation Lab is the experience `a16.simulation-lab` of the one VisualCore app (ADR-0009). It has no app target,
Info.plist or privacy manifest of its own: the app's declarations cover it. Feature 122 (A16-P06), FR-A16-601 to
FR-A16-603 (research D1). Sources: `Packages/ExperiencesCreative/SimulationLab` (below: SL).

## What is stored on the device

The saved experiments and the session state live in the experience's own storage folder,
`Application Support/Experiences/a16.simulation-lab/`, and are written through `ExperienceStorage.write` (atomic
replace: a reader sees the complete old or the complete new file). The latest picture lives in the app's temporary
folder.

| What | Where | Written by | Content |
|---|---|---|---|
| Saved experiments | `preset-<uuid>.json`, one file per experiment, in the experience's storage folder | `SL/Experience/SimulationPresetStore.swift`, when the person taps Save experiment (`SL/Experience/SimulationControls.swift`) | One `ExperimentPreset` document (`SL/Core/ExperimentPreset.swift`; schema 1, sorted keys): the name the person typed (1 to 60 characters after trimming), the 64 × 64 simulation spec (family, preset, parameters, time step and seed), the palette id `standard`, the annotation "Saved in Simulation Lab.", the source "Saved by you" and the license `original`. At most 24 files (`SimulationPresetStore.cap`); a save beyond that is refused with "The library holds 24 experiments; delete one first." No device data, no location and no address |
| Saved session state | `state.json` in the same folder | the app (`SavedStateStore` in `Packages/VisualCore`, used by `Apps/VisualCore/App/AppModel.swift`), not the experience | The session snapshot of the core (`SL/Experience/Adapter/SimulationCore.swift`, `SimulationState` schema 1, `SL/Core/SimulationState.swift`, at most 1,048,576 bytes): the spec, the scheduler (running or paused, speed, step count) and the field itself, so that the experience reopens where it was |
| The latest picture | `a16-capture-<UUID>.png` in the temporary folder `tmp/a16-captures` | `SL/Experience/SimulationCapture.swift`, when the person taps Capture picture | One 1024 × 1024 sRGB PNG of the field, encoded by `StillImageEncoder.pngData`. The folder holds at most one picture: a new capture replaces the previous file, a failed capture removes it and shows "The picture could not be captured. Please try again." The folder is emptied whenever the experience opens (`SimulationPresenter.init` calls `SimulationCapture.clearFolder()`), so no picture of an earlier session is left. Nothing is written to Photos |

Nothing else is persisted by the experience. The six bundled presets, the palettes and the shader programs are part
of the code and are never written. Loading never writes: a preset file that is damaged, of a newer schema or refused
(`damaged`, `newer-version`, `invalid`) is reported in the library's problem lines and skipped, never deleted or
rewritten (`PresetStoreTests.testDamagedAndNewerFilesAreSkipped`,
`PresetStoreTests.testAPresetWithARefusedSpecIsReportedAndSkipped`). A saved state that is damaged, newer or out of
range is refused, the state stays and the seeded start opens (`SimulationSessionTests.testADamagedSavedStateIsRefusedAndTheStateStays`;
`SimulationStateTests.damagedPayloadsAreRefused`, `newerVersionsAreRefused`, `outOfRangeSettingsAreRefused`). A saved
experiment reopens in a new session (`PresetStoreTests.testASavedExperimentReopensInANewSession`).

## What is read

Only the experience's own files above. The experience opens no document picker and reads no photo, document, file or
folder outside its storage and its temporary folder.

## How a picture leaves the device

Only through the system share sheet that the person opens: after Capture picture, the Share picture button (a
`ShareLink` with `SimulationCaptureFile` in `SL/Experience/SimulationControls.swift`) hands the one PNG to the share
sheet, and where it goes is the person's choice there. The experience itself sends nothing.

## How to delete

- **One saved experiment.** Its Delete button in the Presets section removes its `preset-<uuid>.json` file
  (`SimulationPresetStore.delete`; `PresetStoreTests.testDeleteRemoves`).
- **The picture.** A new capture replaces it; the next opening of the experience empties `tmp/a16-captures`
  (`CaptureFileTests.testAPresenterEmptiesTheCaptureFolder`, `testClearFolderEmpties`).
- **Simulation Lab's data.** In the app's Settings, the data section lists every experience with stored data; its
  reset button for Simulation Lab, after a confirmation, removes the experience's folder with every saved experiment
  and the saved session state (`Apps/VisualCore/App/SettingsView.swift`, `AppModel.reset(_:)` with
  `ResetPlan.experience`).
- **Everything.** The reset of all data in the same section, or removing the app, removes every experience's folder,
  Simulation Lab's files and saved session state included.

## Permissions

Simulation Lab requests no permission and adds no usage string (FR-A16-602). Its registration declares no permission
(`"permissions": []` in `Catalog/registrations.json`). The share sheet needs no permission. The experience uses no
sensor: no motion, location, contacts, photo library, image picker, microphone or device camera. It plays no sound and
gives no haptic.

## What is not done

- **Nothing is sent.** There is no upload, sync, sign-in, user account, analytics or crash reporting by the
  experience. The saved experiments and the session state never leave the device; a picture leaves only through the
  share sheet the person opens.
- **No network, tracking, recording or sensors.** The sources of the experience contain no `URLSession`,
  `import Network`, `CLLocation`, `AVCapture`, `AVAudioRecorder`, `inputNode`, `installTap`, `CMMotion`, `CNContact`,
  `PHPhotoLibrary`, `UIImagePickerController`, `ASIdentifierManager` or `AppTrackingTransparency` (check
  `sl-no-network`, T-A16-603: `specs/122-sl-p06-release/scan-sources-release.sh`,
  `.autonomy/checks/A16-P06.sl-no-network.json`). The app tracks nothing (`NSPrivacyTracking` false, no tracking
  domains).
- **No change to the system screen.** The experience never sets the system screen brightness
  (`UIScreen.main.brightness`) and never disables the idle timer (`isIdleTimerDisabled`) (the same scan).
- **No personal data.** The only text the person types is the name of a saved experiment, kept in its file on the
  device.

## Required-reason APIs and the app's privacy manifest

The app manifest `Apps/VisualCore/Resources/PrivacyInfo.xcprivacy` declares no tracking, no collected data types and
three accessed-API categories. The experience's uses fall under them; it adds none:

| Category and reason | Use by Simulation Lab |
|---|---|
| `NSPrivacyAccessedAPICategoryFileTimestamp`, `C617.1` | `ExperienceStorage` reads file attributes (type and size) of the experience's own `preset-<uuid>.json` files when they are listed, read or written; `TemporaryFolder` lists its own capture folder |
| `NSPrivacyAccessedAPICategoryUserDefaults`, `CA92.1` | `ExperienceStorage` holds the app's `UserDefaults` for named values under the prefix `exp.a16.simulation-lab.`; Simulation Lab stores none |
| `NSPrivacyAccessedAPICategorySystemBootTime`, `35F9.1` | Frame times come from the app's render host (`ExperienceSession`); the experience's sources read no boot time. Elapsed time inside the app only |

The built product is checked against this manifest by `release_check.py --only app-release-build
app-privacy-manifest app-no-tracking app-usage-descriptions` ([build-and-archive](../../release/build-and-archive.md);
T-A16-611).

## Credits and license inventory

| Item | Kind | Source | License |
|---|---|---|---|
| Life (B3/S23) | Bundled preset (cellular automaton) | Conway 1970 (Game of Life) | public-domain |
| HighLife (B36/S23) | Bundled preset (cellular automaton) | Thompson 1994 (HighLife) | public-domain |
| Seeds (B2/S) | Bundled preset (cellular automaton) | Silverman (Seeds) | public-domain |
| Spots (feed 0.035, kill 0.065) | Bundled preset (reaction-diffusion) | Pearson 1993 (Gray-Scott classification) | public-domain |
| Mazes (feed 0.029, kill 0.057) | Bundled preset (reaction-diffusion) | Pearson 1993 (Gray-Scott classification) | public-domain |
| Pulse | Bundled preset (wave field) | VisualCore (original) | original |
| Automaton palette (dead dark navy, alive mint) | Palette, `SimulationPalette` (`SL/Experience/SimulationPalette.swift`) | VisualCore (original code) | original |
| Reaction-diffusion palette (deep blue, teal, yellow from the inhibitor v) | Palette, `SimulationPalette` | VisualCore (original code) | original |
| Wave palette (blue below zero, dark neutral at zero, orange above) | Palette, `SimulationPalette` | VisualCore (original code) | original |
| `display`, `automatonDisplay`, `automatonStep`, `reactionDisplay`, `waveDisplay` | GLSL ES 3.00 shader programs, `SL/Experience/SimulationShaders.swift` | VisualCore (original code) | original (repository LICENSE, MIT) |
| Gray-Scott step (`GrayScottGPU.stepFragment`) | GLSL ES 3.00 shader program, `SL/Experience/GrayScottGPU.swift` | VisualCore (original code) | original (repository LICENSE, MIT) |
| Wave step (`WaveGPU.stepFragment`) | GLSL ES 3.00 shader program, `SL/Experience/WaveGPU.swift` | VisualCore (original code) | original (repository LICENSE, MIT) |

- **What the presets are.** The names, rules and parameter values of the five public-domain presets are published
  scientific facts (the rules of Life, HighLife and Seeds; the Gray-Scott feed and kill values of Pearson's
  classification); only the values are used, and the code that runs them is this repository's own. Every bundled
  preset is valid and carries its source and license (`ExperimentPresetTests.theSixFamilyPresetsAreBundled`,
  `everyBundledPresetIsValidAndAttributed`). Presets the person saves carry the source "Saved by you" and the license
  `original`.
- **What the values are.** Every simulation is an educational approximation and says so in its approximation label:
  64 × 64 cells, exact states (0 or 1) and a wrap boundary for the automaton; half-float values, a wrap boundary and an
  explicit Euler step for reaction-diffusion; half-float values, a fixed zero boundary and a leapfrog step for the wave
  (`SimulationCore.approximationWords`; `InspectorWordsTests.theApproximationLabels`).
- **Visuals.** Drawn by code only: the field is coloured by the palettes above and drawn through the shader programs
  above at run time through the host's renderer; the legend and the inspector are native overlay text and shapes. No
  image, texture, photograph, model, font or data file from a third party is bundled.
- **Sound.** None.
- **Code.** The experience's sources (rules, Gray-Scott, wave field, seeding, brush, histogram, scheduler, model,
  specs, state, presets, palettes, shaders, GPU steps, presenter, controls, legend, capture and preset store) are this
  repository's own code. The experience depends only on the local packages `Packages/VisualCore` and
  `Packages/VisualCoreRendering` (`Packages/ExperiencesCreative/Package.swift`); it adds no third-party package. The
  app's third-party components (ANGLE and the libraries inside it, listed in `docs/legal/third-party.json`) are bundled
  under the app's `Licenses` folder, shown in the app's Acknowledgements and checked by `app-licenses`.
- **No third-party content.** Apart from the public-domain preset values above, no picture, sound, text or code from
  outside the project is in the experience.
- **Test samples.** The committed sample preset and state files of A16-P06 (T-A16-605) are resources of the test
  target only; `scenario-manifest.json` is outside every target's path.
- **ProjectM.** Not used; no engine code, preset format or name of it is in the experience, and ProjectM types stay out
  of the app.
