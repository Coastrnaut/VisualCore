# Physics Playground — privacy and credits

Physics Playground is the experience `a11.physics-playground` of the one VisualCore app (ADR-0009). It has no app
target, Info.plist or privacy manifest of its own: the app's declarations cover it. Feature 087 (A11-P06), FR-A11-601
and FR-A11-604. Sources: `Packages/ExperiencesCreative/PhysicsPlayground` (below: PP).

## What is stored on the device

| What | Where | Written by | Content |
|---|---|---|---|
| Saved experiments | `experiment-0.json` … `experiment-3.json` (`experiment-<slot>.json`, one file per slot) in the experience's own storage folder, `Application Support/Experiences/a11.physics-playground/` | `PP/Experience/ExperimentStore.swift` through `ExperienceStorage.write` (atomic replace: a reader sees the complete old or the complete new file), only when the person taps Save on a slot | One `ExperimentDocument` (file schema 1): the name the person typed for the slot (1 to 24 characters, or "Experiment N" when left empty), the origin (a preset or a slot) and the world (bodies, springs, gravity, drag and stiffness levels, pins and overlay flags); a grab and a selection are never written. No date, no name of a person other than what was typed as the experiment's name, no device data and no address |
| Saved session state | `state.json` in the same folder | the app (`SavedStateStore`, `Apps/VisualCore/App/AppModel.swift`), not the experience | The session snapshot of the core (`PlaygroundCore`, snapshot schema 5): the world, the seeded generator state, the origin of the opened experiment, its starting world (for Reset) and the running tutorial's progress, so that the playground resumes where it was. Snapshots of schemas 1 to 4 are migrated on restore |

Nothing else is persisted by the experience. The materials, presets and tutorial texts are part of the code
(`MaterialCatalog.bundled`, `Presets.swift`, `Tutorials.swift`) and are never written. Its sources write no named
defaults values (`ExperienceStorage.setValue` is not called), no other files and no `UserDefaults` values. Reading a
slot never writes: a file that is damaged, half-written, of a newer file schema or with a world that does not validate
is refused with its reason in the slot's status line and left byte for byte as it was until the person saves over it
(`ExperimentStoreTests.testRefusedFilesAreReportedAndLeftUntouched`,
`ExperimentSampleFileTests.testTheRefusedSamplesAreRefusedAndLeftByteIdentical`). A save the storage refuses is
reported and changes nothing (`ExperimentStoreTests.testStorageRefusalsAreReportedAndChangeNothing`). A saved state of
a newer schema or with damaged content is refused and the starting scene opens
(`PlaygroundSessionTests.testANewerSavedStateIsRefusedAndTheStartingSceneOpens`,
`testADamagedSavedStateIsRefusedAndTheStartingSceneOpens`).

## How to delete

- **One saved experiment.** In the experience's Experiment group, the Clear button of a slot removes that slot's
  `experiment-<slot>.json` (`PlaygroundPresenter.clearExperiment(slot:)`, `ExperimentStore.clear(slot:)`;
  `ExperimentStoreTests.testAnEmptySlotIsRefusedAndClearingRemovesTheFile`). Saving to a slot replaces what it held.
- **Physics Playground's data.** In the app's Settings, the data section lists every experience with stored data; its
  reset button for Physics Playground, after a confirmation, removes the experience's folder with every saved
  experiment and the saved session state (`Apps/VisualCore/App/SettingsView.swift`, `AppModel.reset(_:)` with
  `ResetPlan.experience`). The next opening starts with the starting scene and four empty slots.
- **Everything.** The reset of all data in the same section, or removing the app, removes every experience's folder,
  the saved experiments and the saved session state included.

## Permissions

Physics Playground requests no permission and adds no usage string (FR-A11-601). Its registration declares no
permission (`"permissions": []` in `Catalog/registrations.json`), and it uses no sensor: no motion, location,
contacts, photo library, microphone or camera. Editing uses only touches on the stage and the native controls. The
experience plays no sound and sends no haptic feedback.

## What is not done

- **Nothing is sent.** There is no upload, sync, sign-in, user account, online gallery, analytics or crash reporting
  by the experience. Saved experiments never leave the device; there is no export.
- **No network, tracking, recording or sensors.** The sources of the experience contain no `URLSession`,
  `import Network`, `CLLocation`, `AVCapture`, `AVAudioRecorder`, `inputNode`, `installTap`, `CMMotion`, `CNContact`,
  `ASIdentifierManager` or `AppTrackingTransparency` (check `pp-no-network`, T-A11-603:
  `.autonomy/checks/A11-P06.pp-no-network.json`). The app tracks nothing (`NSPrivacyTracking` false, no tracking
  domains).
- **No change to the system screen.** The experience never sets the system screen brightness
  (`UIScreen.main.brightness`) and never disables the idle timer (`isIdleTimerDisabled`) (the same scan).
- **Low Power Mode is read, not changed.** The public `ProcessInfo` state selects the lightest drawing level; the
  world does not change with it (`PlaygroundQualityTests.testLowPowerModeDrawsTheLightestLevelInASession`,
  `testTheDigestIsTheSameAtEveryTier`).

## Required-reason APIs and the app's privacy manifest

The app manifest `Apps/VisualCore/Resources/PrivacyInfo.xcprivacy` declares no tracking, no collected data types and
three accessed-API categories. The experience's uses fall under them; it adds none:

| Category and reason | Use by Physics Playground |
|---|---|
| `NSPrivacyAccessedAPICategoryFileTimestamp`, `C617.1` | `ExperienceStorage` reads file attributes (type and size) of the experience's own files when a saved experiment is read or written |
| `NSPrivacyAccessedAPICategoryUserDefaults`, `CA92.1` | `ExperienceStorage` holds the app's `UserDefaults` for named values under the prefix `exp.a11.physics-playground.`; Physics Playground stores none |
| `NSPrivacyAccessedAPICategorySystemBootTime`, `35F9.1` | Frame times and quality decisions come from the app's render host (`ExperienceSession`); the world advances by its own fixed step, and the experience's sources read no boot time. Elapsed time inside the app only |

The built product is checked against this manifest by `release_check.py --only app-release-build
app-privacy-manifest app-no-tracking app-usage-descriptions` ([build-and-archive](../../release/build-and-archive.md);
T-A11-612).

## Credits

- **Content.** The four materials (Rubber, Wood, Steel, Ice), the four presets (Free play, Pendulum, Spring chain,
  Stacked objects) and the two tutorials (Controlling time, Springs and energy, each with all of its step texts) are
  original content by the VisualCore project under the MIT license. The full table with author and license per item is
  [content-licenses.md](content-licenses.md), generated from `MaterialCatalog.bundled` by `LicenseAudit.markdown(_:)`
  and checked against it by `LicenseAuditTests.theCommittedLicenseDocumentMatchesTheCatalog` (4 materials, 4 presets,
  2 tutorials; 0 problems). The material constants are educational approximations, not engineering data.
- **Visuals.** Drawn by code only: the bodies, their edges, marks and hatching, the springs, pins, arrows, the grab
  line, the selection ring and the stage are generated at run time through the host's renderers. No image, model, font
  or data file from a third party is bundled.
- **Code.** The experience's sources (world model, simulation, editing, presets, tutorials, experiment documents and
  store, presenter, gestures and controls) are this repository's own code; the box contacts, impulse solver, springs
  and broad phase it uses are VisualCore's own code (`Packages/VisualCore/Sources/VisualCoreSimulation`). The
  experience depends only on the local packages `Packages/VisualCore` and `Packages/VisualCoreRendering`
  (`Packages/ExperiencesCreative/Package.swift`); it adds no third-party package. The app's third-party components
  (ANGLE and the libraries inside it, listed in `docs/legal/third-party.json`) are bundled under the app's `Licenses`
  folder, shown in the app's Acknowledgements and checked by `app-licenses`.
- **Test samples.** The four committed sample experiment files (`experiment-valid.json`, `experiment-newer.json`,
  `experiment-damaged.json`, `experiment-truncated.json`) are resources of the test target only (A11-P04);
  `scenario-manifest.json` is outside every target's path.
- **ProjectM.** Not used; no engine code, preset format or name of it is in the experience, and ProjectM types stay out
  of the app.
