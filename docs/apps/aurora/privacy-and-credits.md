# Aurora — privacy and credits

Aurora is the experience `a21.aurora` of the one VisualCore app (ADR-0009). It has no app target, Info.plist or
privacy manifest of its own: the app's declarations cover it. Feature 157 (A21-P06), FR-A21-601 and FR-A21-602.
Sources: `Packages/ExperiencesCreative/Aurora` (below: AU).

Aurora draws a full-screen sky of aurora ribbons, stars and clouds in code. The person picks one of three skies,
changes its colour, motion and intensity under a brightness limit they choose, and can turn on a quiet sound made in
code. Aurora keeps the person's choices on the device; it writes no other file and sends nothing.

## What is stored on the device

Both stored items live in the experience's own storage: the snapshot in the experience's storage folder,
`Application Support/Experiences/a21.aurora/`, written atomically (a reader sees the complete old or the complete new
file), and the saved choices as one named value under the experience's own defaults prefix `exp.a21.aurora.`.

| What | Where | Written by, and when | Content |
|---|---|---|---|
| Saved session state (the snapshot) | `state.json` in the experience's storage folder | the app (`SavedStateStore` in `Packages/VisualCore`, the session's snapshot sink in `Apps/VisualCore/App/AppModel.swift`), not the experience, at every suspension and close of the session and at a checkpoint after an accepted change; the file is replaced each time | The core's snapshot, schema 1 (`Aurora/Experience/Adapter/AuroraCore.swift`, digest `a21.aurora.v1`): the open sky only, as the JSON object `{"hue", "limit", "scene"}` (the colour shift, the brightness limit and the scene: preset, palette, ribbons, turbulence, cloudiness, stars and speed). The sound choice, the hidden controls, the still view, reduced flashing, the clock and a running change between skies are not stored; there is no name, no device data and no position |
| Saved choices | the experience value `prefs.v1` (`SkyPreferences.storageKey`) | `Aurora/Experience/AuroraPresenter.swift`, through `ExperienceStorage.setValue`, after every accepted change of the sky and of the sound choice (not for a restore itself); the value is replaced each time | One envelope (kind `a21.preferences`, schema 1, at most 4,096 bytes; `Aurora/Core/SkyPreferences.swift`): the sky preset, the colour shift, the five motion and sky values (speed, turbulence, ribbons, stars, clouds), the brightness limit, the sound on or off (off by default) and the volume |

The three skies, their palettes, the scene bounds, the shader and the sound recipe are code in the app bundle and are
never written. Both stored items are removed when the app is deleted.

Opening never rewrites a stored value. A `prefs.v1` value that is damaged, of a newer version or out of range is
refused with its code (`damaged`, `newer-version` or `out-of-range`): Aurora opens with the defaults (Polar night,
the sound off) and the line "Your saved choices could not be read, so the default sky is shown.", and the refused
value stays as it is until the next accepted change writes the person's new choices over it
(`PreferencesStoreTests.damagedNewerAndOutOfRangeValuesOpenWithTheDefaults`;
`PreferencesTests.damagedBytesAreRefusedAsDamaged`, `versionTwoIsRefusedAsNewer`,
`eachFieldOutOfRangeIsRefusedAsOutOfRange`). A failed save is reported once and the choices stay in memory
(`PreferencesStoreTests.aFailedSaveIsReportedOnceAndTheChoicesStay`). A damaged or newer snapshot is refused and the
open sky stays as it is (`AuroraCoreTests.damagedRefusedAndNewerSnapshotsAreRefused`). The committed samples of
A21-P06 (T-A21-605, `ExperienceTests/StoredSampleTests.swift`) and the drawing-failure test (T-A21-604,
`ExperienceTests/SkyRecoveryDrawTests.swift`) prove that every sample and `prefs.v1` stay byte-identical.

## No temporary file

Aurora writes no temporary file, makes no picture and exports nothing. The still view ("Still sky") and the fallback
sky keep their cached picture in GPU memory only, never on disk.

## What is read

Only the experience's own snapshot and value above. The experience opens no document picker and reads no photo,
document, file or folder outside its storage. It never reads the photo library.

## How to delete

- **Aurora's data.** In the app's Settings, the data section lists every experience with stored data; its reset
  button for Aurora, after a confirmation, removes the experience's folder with `state.json` and its values,
  `prefs.v1` included (`Apps/VisualCore/App/SettingsView.swift`, `AppModel.reset(_:)`,
  `ExperienceStorage.removeValues(of:in:)`). The next open shows the defaults.
- **Everything.** The reset of all data in the same section, or deleting the app, removes every experience's folder and
  values, Aurora's included. The snapshot and the saved choices are removed when the app is deleted.

## Permissions

Aurora requests no permission. Its registration declares `"permissions": []` (`Catalog/registrations.json`), so no
usage string is needed for it. It uses no location, microphone, camera, motion, contacts, photo library or image
picker, and no sensor of any kind.

The screen: Aurora never keeps the screen awake (it holds no idle timer) and never changes the screen brightness. Its
"Brightness limit" caps the luminance of the drawn sky in the shader only; the system brightness is untouched.

The optional sound: with "Sound" on, Aurora plays one loop synthesised in code (`AmbientLoopRecipe.gentle`, through
`AmbientLoopPlayer` of VisualCoreAudio) on the ambient audio session category, so the silent switch silences it and
other playback continues. The sound is off by default, plays only while Aurora is open in the active app with the
sound on, and stops on an interruption, in the background and on leaving Aurora without restarting by itself
(`SoundLoopTests.aFreshStartHasTheSoundOffAndMakesNoPlayer`, `theLoopPlaysOnlyWhileOnOnScreenAndActive`). Nothing is
recorded.

## What is not done

- **Nothing is sent.** There is no upload, sync, sign-in, analytics or crash reporting by the experience. The snapshot
  and the saved choices never leave the device. Nothing is downloaded, and the experience works offline.
- **No network, tracking, recording or sensors.** The sources of the experience contain none of the APIs of the spec's
  Clarifications Q3: no networking session or Network import, no position, capture, recording, microphone input,
  motion, contacts, photo-library, Photos picker, advertising-identifier or tracking-transparency API, no idle timer
  and no brightness write (check `au-no-network`, T-A21-603: `specs/157-au-p06-release/scan-sources-release.sh`,
  `.autonomy/checks/A21-P06.au-no-network.json`). The app tracks nothing (`NSPrivacyTracking` false, no tracking
  domains).
- **No personal data.** The person types no text in Aurora; every choice is a control value.

## Required-reason APIs and the app's privacy manifest

The app manifest `Apps/VisualCore/Resources/PrivacyInfo.xcprivacy` declares no tracking, no collected data types and
three accessed-API categories. The experience's uses fall under them; it adds none:

| Category and reason | Use by Aurora |
|---|---|
| `NSPrivacyAccessedAPICategoryFileTimestamp`, `C617.1` | `SavedStateStore` reads file attributes (type and size) of the experience's own `state.json` when it is read or written; the experience itself reads no file |
| `NSPrivacyAccessedAPICategoryUserDefaults`, `CA92.1` | `ExperienceStorage` holds the app's `UserDefaults` for named values under the experience's prefix; Aurora stores the one value `prefs.v1` |
| `NSPrivacyAccessedAPICategorySystemBootTime`, `35F9.1` | Frame times come from the app's render host (`ExperienceSession`); the sky clock (`SkyClock`) advances by each frame's clamped delta, and the experience's sources read no boot time |

The built product is checked against this manifest by `release_check.py --only app-release-build
app-privacy-manifest app-no-tracking app-usage-descriptions` ([build-and-archive](../../release/build-and-archive.md);
T-A21-611).

## Credits and license inventory

Consistent with [licenses.md](licenses.md): everything Aurora draws or plays is code written for this repository.

| Item | Kind | Source | License |
|---|---|---|---|
| Presets Polar night, Violet veil and Dawn haze (palettes and scene values) and the scene bounds | Numbers, `Aurora/Core/SkyPresets.swift`, `Aurora/Core/SkyScene.swift` | chosen for this experience | original (repository LICENSE, MIT); colour values are facts |
| Sky shader `aurora-sky.frag` (stars, clouds and ribbons over noise) and the fallback sky | Code, `Aurora/Core/SkyShader.swift`, over VisualCore's GLSL library `vc/` | VisualCore (written for this experience) | original (repository LICENSE, MIT) |
| Noise port and reference (`SkyNoise`, `SkyReference`) | Code, `Aurora/Core/SkyNoise.swift`, `Aurora/Core/SkyReference.swift` | VisualCore | original (repository LICENSE, MIT) |
| Changes between skies, the input blend and the still view | Code, `Aurora/Experience/SkyTransition.swift`, `Aurora/Experience/SkyBlend.swift`, `Aurora/Experience/AuroraPresenter.swift` | VisualCore | original (repository LICENSE, MIT) |
| The optional sound (`AmbientLoopRecipe.gentle`) | Code, synthesised at run time by VisualCoreAudioDSP and played by `Aurora/Experience/SkySound.swift`; no sound file and no recording | VisualCore | original (repository LICENSE, MIT) |
| Text and labels | The system font, drawn by SwiftUI; the words in `Aurora/Experience/AuroraControls.swift` | part of iOS; text written for this experience | nothing bundled; original (repository LICENSE, MIT) |
| The experience's sources (core, adapter, presenter, controls, sound, transition, blend) | Code | VisualCore | original (repository LICENSE, MIT) |

- **Visuals.** Drawn by code only: the sky is one fragment shader drawn through the host's renderer; the controls are
  native text. No image, texture, font file, model, sound file or generated asset is bundled, and nothing is
  downloaded. The skies are stylized art, not a depiction of measured aurora activity.
- **Code.** The experience depends only on the local packages of VisualCore (`Packages/ExperiencesCreative/Package.swift`);
  it adds no third-party package. The app's third-party components (ANGLE and the libraries inside it, listed in
  `docs/legal/third-party.json`) are bundled under the app's `Licenses` folder, shown in the app's Acknowledgements and
  checked by `app-licenses`.
- **Test samples.** The committed sample files of A21-P06 (T-A21-605) are resources of the test target only;
  `scenario-manifest.json` is outside every target's path.
- **ProjectM.** Not used; no engine code, preset format or name of it is in the experience, and ProjectM types stay out
  of the app.
