# Digital Aquarium — privacy and credits

Digital Aquarium is the experience `a09.digital-aquarium` of the one VisualCore app (ADR-0009). It has no app target,
Info.plist or privacy manifest of its own: the app's declarations cover it. Feature 073 (A09-P06), FR-A09-601 and
FR-A09-604. Sources: `Packages/ExperiencesCreative/DigitalAquarium` (below: DA).

## What is stored on the device

| What | Where | Written by | Content |
|---|---|---|---|
| Saved aquariums | `aquarium-<uuid>.json` in the experience's own storage folder, `Application Support/Experiences/a09.digital-aquarium/` | `DA/Experience/AquariumLibrary.swift` through `ExperienceStorage.write` (atomic replace; at most 12 saved aquariums, `AquariumLibrary.maxEntries`; the storage quota of `StorageQuota`: at most 64 files and 16 MiB) | The arrangement the person saved under a name (`AquariumConfiguration`, format 1): the id, the name, the saved time, the habitat, the lighting, the decoration pieces with their places, turns and sizes, the chosen decoration kind and whether ambient mode is on. No picture, no touch history, no name of a person and no address |
| Saved session state | `state.json` in the same folder | the app (`SavedStateStore`, `Apps/VisualCore/App/AppModel.swift`), not the experience | The session snapshot of the core (`AquariumCore`, snapshot schema 4): the habitat document with fish, plants, food pellets and decorations, the lighting, the step count, pause, the chosen decoration kind, ambient mode and the seeded generator state, so that the aquarium resumes where it was. Snapshots of schemas 1 to 3 are migrated on restore |

Nothing else is persisted by the experience. The two starter habitats (Reef, Kelp), the species, plants and decoration
kinds are part of the code (`SpeciesCatalog.bundled`) and are never written. Its sources write no named defaults values
(`ExperienceStorage.setValue` is not called), no other files and no `UserDefaults` values. Damaged files, files of a
newer format, files whose name does not match their id and invalid configurations are counted and kept, never deleted
or rewritten (`AquariumLibrary.reload()`; `AquariumLibraryTests.testDamagedForeignInvalidAndNewerFilesAreCountedAndKept`).
A thirteenth save, or a save the storage refuses, is refused with a plain message and writes no file
(`AquariumLibraryTests.testTheThirteenthSaveIsRefusedWithNoNewFile`, `testASaveTheStorageRefusesChangesNoFile`). A
saved state with unknown content or of a newer schema is refused and the Reef starter habitat opens
(`AquariumSessionTests.testASavedStateWithUnknownContentIsRefusedAndTheReefOpens`,
`testANewerSavedStateIsRefusedAndTheStarterHabitatOpens`).

## How to delete

- **One saved aquarium.** Select it in the "Saved aquariums" section and press "Delete saved aquarium"
  (`library.delete`); its file is removed and the current aquarium stays
  (`AquariumLibraryTests.testSaveListOpenInANewSessionAndDelete`).
- **Everything.** Removing the app removes the experience's folder with every saved aquarium and the saved session
  state.

## Permissions

Digital Aquarium requests no permission and adds no usage string (FR-A09-601). Its registration declares no
permission, and it uses no sensor: no motion, location, contacts, photo library, microphone or camera. Feeding,
placing and moving decorations use only touches on the canvas and the native controls.

## What is not done

- **Nothing is sent.** There is no upload, sync, sign-in, user account, analytics or crash reporting by the
  experience.
- **No network, tracking or sensors.** The sources of the experience contain no `URLSession`, `import Network`,
  `CLLocation`, `AVCapture`, `AVAudio`, `CMMotion`, `CNContact`, `ASIdentifierManager` or `AppTrackingTransparency`
  (check `da-no-network`, T-A09-603: `.autonomy/checks/A09-P06.da-no-network.json`). The app tracks nothing
  (`NSPrivacyTracking` false, no tracking domains).
- **No change to the system screen.** Ambient mode dims the drawn scene only; the experience never sets the system
  screen brightness (`UIScreen.main.brightness`) and never disables the idle timer (`isIdleTimerDisabled`)
  (`AquariumRenderTests.testNoSourceSetsTheSystemBrightnessOrTheIdleTimer`; the same scan).
- **Low Power Mode is read, not changed.** The host's public `ProcessInfo` state selects the ambient drawing; the
  aquarium's state does not change with it (`AquariumRenderTests.testLowPowerModeDrawsAmbientWithoutChangingTheState`).

## Required-reason APIs and the app's privacy manifest

The app manifest `Apps/VisualCore/Resources/PrivacyInfo.xcprivacy` declares no tracking, no collected data types and
three accessed-API categories. The experience's uses fall under them; it adds none:

| Category and reason | Use by Digital Aquarium |
|---|---|
| `NSPrivacyAccessedAPICategoryFileTimestamp`, `C617.1` | `ExperienceStorage` reads file attributes (type and size) of the experience's own files when the library lists, reads or writes saved aquariums |
| `NSPrivacyAccessedAPICategoryUserDefaults`, `CA92.1` | `ExperienceStorage` holds the app's `UserDefaults` for named values under the prefix `exp.a09.digital-aquarium.`; Digital Aquarium stores none |
| `NSPrivacyAccessedAPICategorySystemBootTime`, `35F9.1` | Frame times, the ambient dimmer's clock and quality decisions come from the app's render host (`ExperienceSession`); the experience's sources read no boot time. Elapsed time inside the app only |

The built product is checked against this manifest by `release_check.py --only app-release-build
app-privacy-manifest app-no-tracking app-usage-descriptions` ([build-and-archive](../../release/build-and-archive.md);
T-A09-612).

## Credits

- **Content.** Every bundled species (Orange striped fish, Blue fish with yellow tail, Silver slender fish, Gold round
  fish), plant (Green ribbon weed, Red fan plant, Tall brown ribbon, Purple fan plant), decoration (Round rock, Flat
  rock, Spiral shell) and habitat (Reef, Kelp) is original procedural content by the VisualCore project under the MIT
  license. The full table with author and license per item is [content-licenses.md](content-licenses.md), generated
  from `SpeciesCatalog.bundled` by `LicenseAudit.markdown(_:)` and checked against the catalog by
  `LicenseAuditTests.theCommittedLicenseDocumentMatchesTheCatalog` (13 items, 0 problems).
- **Visuals.** Drawn by code only: fish outlines, plants, decoration polygons, food pellets, bubbles, drifting motes,
  depth layers and the rippling light pattern (`CausticsScene`, a shader with a fallback) are generated at run time
  through the host's renderers. No image, model, font, sound or data file from a third party is bundled.
- **Code.** The experience's sources (simulation, schooling, feeding, decoration editing, water effects, ambient
  dimmer, library, presenter and controls) are this repository's own code. The experience depends only on the local
  packages `Packages/VisualCore` and `Packages/VisualCoreRendering` (`Packages/ExperiencesCreative/Package.swift`); it
  adds no third-party package. The app's third-party components (ANGLE and the libraries inside it, listed in
  `docs/legal/third-party.json`) are bundled under the app's `Licenses` folder, shown in the app's Acknowledgements and
  checked by `app-licenses`.
- **Test samples.** The committed sample saved files are resources of the test target only (T-A09-604);
  `scenario-manifest.json` is outside every target's path.
- **ProjectM.** Not used; no engine code, preset format or name of it is in the experience, and ProjectM types stay out
  of the app.
