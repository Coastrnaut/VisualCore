# Digital Zen Garden — privacy and credits

Digital Zen Garden is the experience `a20.digital-zen-garden` of the one VisualCore app (ADR-0009). It has no app
target, Info.plist or privacy manifest of its own: the app's declarations cover it. Feature 150 (A20-P06), FR-A20-601
and FR-A20-602. Sources: `Packages/ExperiencesCreative/DigitalZenGarden` (below: ZG).

Digital Zen Garden draws a tray of sand, its grooves and its stones in code. The person rakes and places stones, keeps
named gardens on the device and can make one picture of the garden that they hand to the system share sheet.

## What is stored on the device

The stored files live in the experience's own storage folder, `Application Support/Experiences/a20.digital-zen-garden/`,
and are written atomically (a reader sees the complete old or the complete new file). The calm switches are one named
value under the experience's own defaults prefix `exp.a20.digital-zen-garden.`.

| What | Where | Written by, and when | Content |
|---|---|---|---|
| Saved session state (the snapshot) | `state.json` in the experience's storage folder | the app (`SavedStateStore` in `Packages/VisualCore`, the session's snapshot sink in `Apps/VisualCore/App/AppModel.swift`), not the experience, at every suspension and close of the session and at a checkpoint after an accepted change; the file is replaced each time | The core's snapshot, schema 1 (`ZG/Experience/Adapter/GardenCore.swift`): the open garden document only, as `GardenDocument.encoded()` writes it (the tray, the sand tone, each stroke's rake, capped flag and points, each stone and the next stone id). A stroke in progress, the rake style, the selection, the tool, the refusal and the undo history are not stored; there is no name, no device data and no position |
| Named gardens | `garden-<n>.json` in the same folder, one file per garden, at most 12 | `ZG/Experience/GardenLibrary.swift`, through `ExperienceStorage.write`, when the person saves, renames or deletes a garden; a save under an existing name replaces that garden after the person confirms | One envelope (kind `a20.saved-garden`, version 1) whose body is the garden's name (1 to 40 characters, typed by the person), its modification order and the garden document; at most 262,144 bytes |
| Library index | `library.json` in the same folder | `GardenLibrary`, with every change of the library | One envelope (kind `a20.garden-library`, version 1): the file counter and the file name, name and order of each garden |
| Calm switches | the experience value `calm.v1` (`CalmSettings.storageKey`) | `ZG/Experience/GardenPresenter.swift`, through `ExperienceStorage.setValue`, when the person turns a switch on or off; the value is replaced each time | Three on/off values: sound, sand drift and haptics, all off by default (`CalmSettings` in `ZG/Experience/Adapter/GardenCore.swift`) |

The tray, the sand tones, the rakes, the stone kinds, the patterns and the shaders are code in the app bundle and are
never written.

Opening never rewrites a stored file. A garden file that is damaged, of a newer version, too large or whose document is
refused is listed as unreadable with its code (`damaged`, `newer-version`, `too-large` or the document's refusal code)
and is never opened or deleted automatically (`LibraryTests.refusedFilesAreListedWithTheirCodesNeverOpenedAndKept`).
A damaged index is rebuilt by the next change; an index of a newer version makes the library read only, so it is never
overwritten (`LibraryTests.aDamagedIndexIsRebuiltAndANewerIndexIsReadOnly`). A failed write keeps the previous file
(`LibraryTests.aFailedWriteKeepsThePreviousFile`). A damaged calm value is ignored and the switches stay off
(`CalmTests.aDamagedValueIsIgnored`). The committed samples of A20-P06 (T-A20-605,
`ExperienceTests/StoredSampleTests.swift`) and the drawing-failure test (T-A20-604,
`ExperienceTests/GardenRecoveryDrawTests.swift`) prove that every sample, `library.json` and the garden files stay
byte-identical.

## The temporary picture file

Make picture draws the garden at 1600 by 1200 pixels and writes one PNG, "Zen Garden 1600x1200.png", into the temporary
folder `DigitalZenGarden-Still` in the app's temporary directory (`ZG/Experience/GardenStill.swift`). The folder holds
at most one file: each new picture first removes the previous one, and a failed picture leaves no file
(`StillTests.aStillIsA1600By1200PNGAndASecondExportReplacesIt`; `StillTests.aFailedExportLeavesNoFile`). The file leaves
the app only when the person chooses Share picture and hands it to the system share sheet. It is removed with the app's
temporary data and when the app is deleted.

## What is read

Only the experience's own files and value above and the folder of its temporary picture. The experience opens no
document picker and reads no photo, document, file or folder outside its storage and that temporary folder. It never
reads the photo library.

## How to delete

- **A named garden.** Delete in the saved gardens list removes its `garden-<n>.json` and its entry in `library.json`;
  the open garden stays (`LibraryTests.listRenameAndDelete`). An unreadable file can be deleted the same way.
- **Digital Zen Garden's data.** In the app's Settings, the data section lists every experience with stored data; its
  reset button for Digital Zen Garden, after a confirmation, removes the experience's folder with `state.json`,
  `library.json` and every `garden-<n>.json`, and its values, `calm.v1` included (`Apps/VisualCore/App/SettingsView.swift`,
  `AppModel.reset(_:)`, `ExperienceStorage.removeValues(of:in:)`).
- **Everything.** The reset of all data in the same section, or deleting the app, removes every experience's folder and
  values, Digital Zen Garden's included. The stored files, the calm value and the temporary picture are removed when
  the app is deleted.
- **A saved picture.** A copy the person saved to Photos or Files through the share sheet belongs to the person and is
  deleted there; the app keeps no link to it.

## Permissions

Digital Zen Garden requests no permission itself. Its registration declares `"permissions": ["photo-library-add"]`
(`Catalog/registrations.json`), covered by the app's one add-only usage string in `project.yml`:

> `NSPhotoLibraryAddUsageDescription`: "Saves exported artwork to your photo library when you choose Save Image."

The system asks for it only when the person chooses Save Image in the share sheet; the share sheet, not the
experience, adds the picture. The experience calls no photo-library API and never reads the library (the scans
`.autonomy/checks/A20-P04.photos-scan.json`, `.autonomy/checks/A20-P05.photos-scan.json` and `zg-no-network`,
T-A20-603). When the person declines, Save to Files still works (device campaign row ZG-D7, pending). The experience uses no
sensor: no motion, position, contacts, image picker, microphone or photo and video capture. With the sound switch on
it plays soft tones made in code (an ambient session, so the silent switch mutes them and other playback continues);
with the haptics switch on it gives a light selection and placement haptic. Both are off by default. It holds no idle
timer and never writes the screen brightness.

## What is not done

- **Nothing is sent.** There is no upload, sync, sign-in, analytics or crash reporting by the experience. The stored
  files and the calm value never leave the device; the picture leaves the app only through the share sheet when the
  person chooses it. Nothing is downloaded, and the experience works offline.
- **No network, tracking, recording or sensors.** The sources of the experience contain none of the APIs of the spec's
  Clarifications Q3: no networking session or Network import, no position, capture, recording, microphone input,
  motion, contacts, photo-library, Photos picker, image-picker, advertising-identifier or tracking-transparency API, no
  idle timer and no brightness write (check `zg-no-network`, T-A20-603: `specs/150-zg-p06-release/scan-sources-release.sh`,
  `.autonomy/checks/A20-P06.zg-no-network.json`). The app tracks nothing (`NSPrivacyTracking` false, no tracking
  domains).
- **No personal data.** The only text the person types is a garden's name, which stays in the experience's storage.

## Required-reason APIs and the app's privacy manifest

The app manifest `Apps/VisualCore/Resources/PrivacyInfo.xcprivacy` declares no tracking, no collected data types and
three accessed-API categories. The experience's uses fall under them; it adds none:

| Category and reason | Use by Digital Zen Garden |
|---|---|
| `NSPrivacyAccessedAPICategoryFileTimestamp`, `C617.1` | `ExperienceStorage` reads file attributes (type and size) of the experience's own `library.json` and `garden-<n>.json` files when they are read or written, `SavedStateStore` of `state.json`, and `TemporaryFolder` of the file in `DigitalZenGarden-Still` |
| `NSPrivacyAccessedAPICategoryUserDefaults`, `CA92.1` | `ExperienceStorage` holds the app's `UserDefaults` for named values under the experience's prefix; Digital Zen Garden stores the one value `calm.v1` |
| `NSPrivacyAccessedAPICategorySystemBootTime`, `35F9.1` | Frame times come from the app's render host (`ExperienceSession`); the experience's sources read no boot time. The library orders gardens by a counter, not by a clock |

The built product is checked against this manifest by `release_check.py --only app-release-build
app-privacy-manifest app-no-tracking app-usage-descriptions` ([build-and-archive](../../release/build-and-archive.md);
T-A20-611).

## Credits and license inventory

Consistent with [licenses.md](licenses.md): everything Digital Zen Garden draws or plays is code written for this
repository.

| Item | Kind | Source | License |
|---|---|---|---|
| Tray, sand tones (pale, warm, grey), rake styles (fine, wide) and stone kinds (river pebble, flat slate, round granite, tall basalt, moss boulder) | Numbers, `ZG/Core/GardenPalette.swift` | chosen for this experience | original (repository LICENSE, MIT); colour values are facts |
| Sand relief, grooves, grain and drift | Code, `ZG/Experience/SandScene.swift`, `ZG/Core/RakeBrush.swift`, over VisualCore's GLSL library | VisualCore (written for this experience) | original (repository LICENSE, MIT) |
| Stone shapes and their soft shadows | Code, `ZG/Core/StoneShape.swift`, `ZG/Experience/SandScene.swift` | VisualCore | original (repository LICENSE, MIT) |
| Patterns (rows, circle, wave, spiral) | Code, `ZG/Experience/StrokePatterns.swift` | VisualCore | original (repository LICENSE, MIT) |
| Three soft tones (stroke, place, remove) | Code, `ZG/Experience/GardenSounds.swift`, made with VisualCoreAudioDSP; no sound file | VisualCore | original (repository LICENSE, MIT) |
| Text and labels | The system font, drawn by SwiftUI; the words in `ZG/Experience/GardenControls.swift` | part of iOS; text written for this experience | nothing bundled; original (repository LICENSE, MIT) |
| The experience's sources (core, adapter, presenter, controls, library, still, preview, scene) | Code | VisualCore | original (repository LICENSE, MIT) |

- **Visuals.** Drawn by code only: the sand and the stones are shaders drawn through the host's renderer; the controls
  are native text. No image, texture, font file, model, sound file or generated asset is bundled, and nothing is
  downloaded.
- **Code.** The experience depends only on the local packages of VisualCore (`Packages/ExperiencesCreative/Package.swift`);
  it adds no third-party package. The PNG encoding uses the system's own frameworks. The app's third-party components
  (ANGLE and the libraries inside it, listed in `docs/legal/third-party.json`) are bundled under the app's `Licenses`
  folder, shown in the app's Acknowledgements and checked by `app-licenses`.
- **Test samples.** The committed sample files of A20-P06 (T-A20-605) are resources of the test target only;
  `scenario-manifest.json` is outside every target's path.
- **ProjectM.** Not used; no engine code, preset format or name of it is in the experience, and ProjectM types stay out
  of the app.
