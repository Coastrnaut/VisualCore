# Ambient Clock — privacy and credits

Ambient Clock is the experience `a18.ambient-clock` of the one VisualCore app (ADR-0009). It has no app target,
Info.plist or privacy manifest of its own: the app's declarations cover it. Feature 136 (A18-P06), FR-A18-601 and
FR-A18-602. Sources: `Packages/ExperiencesCreative/AmbientClock` (below: AC).

The clock shows the time of the device's own system clock, formatted with the system's calendar, time zone and
locale. It reads nothing else to tell the time.

## What is stored on the device

Both files live in the experience's own storage folder, `Application Support/Experiences/a18.ambient-clock/`, and are
written atomically (a reader sees the complete old or the complete new file).

| What | Where | Written by, and when | Content |
|---|---|---|---|
| Saved session state (the snapshot) | `state.json` in the experience's storage folder | the app (`SavedStateStore` in `Packages/VisualCore`, the session's snapshot sink in `Apps/VisualCore/App/AppModel.swift`), not the experience, at every suspension and close of the session; the file is replaced each time | The core's snapshot, schema 3 (`AC/Experience/Adapter/AmbientCore.swift`, JSON with sorted keys): the format (`hourCycle` system, 12-hour or 24-hour; `showSeconds`; `showDate`), the theme (`theme`, `palette`, `motion`, `speed`), night mode (`nightMode` off, on or scheduled; `nightStart` and `nightEnd` in minutes of the local day; `nightDim`), the in-app reduced motion (`reduceMotion`) and keep-awake (`keepAwake`). Nothing else: the shown instant and the time-change count are not stored, and there is no name, no device data and no position |
| Favourites | `favourites.json` in the same folder | `AC/Experience/AmbientFavourites.swift`, through `ExperienceStorage.write`, only when the person saves a favourite (Save favourite) or removes one; removing the last one removes the file | One envelope (kind `a18.favourites`, schema version 1, JSON with sorted keys) of at most 12 entries, each with an id, the name the person typed (trimmed, at most 60 characters; an empty name becomes "Favourite N"), the time it was saved and the preset (theme, palette, speed, motion). The file is at most 65,536 bytes |

Nothing else is persisted by the experience. The themes, palettes and shaders are code in the app bundle and are
never written.

Opening never rewrites a stored file. A snapshot of a newer schema, a damaged one, or one with a value outside its range
is refused by the host and the opening state opens (`AmbientCoreTests.aStoredValueOutsideItsRangeIsRefused`;
`SnapshotMigrationTests.aStoredThemeOrPaletteOutsideItsRangeIsRefused`). Schema 1 (A18-P02) and schema 2 (A18-P03)
snapshots open migrated (`SnapshotMigrationTests.theSchemaOneExampleMigratesToThemeZeroPaletteZeroKeepingTheOtherFields`;
`PowerCoreTests.theEarlierExamplesMigrateToSchemaThreeWithTheDefaults`). A favourites file that is damaged, of a newer
schema, too large or holding an invalid entry gives an empty list and one sentence, and is left as it is until the
person saves (`FavouritesTests.aDamagedFileGivesAnEmptyListAndIsKeptUntilASave`, `aNewerSchemaIsNewerVersion`,
`aFileAboveTheLimitIsTooLarge`, `anInvalidEntryIsInvalidEntry`). A 13th favourite is refused and nothing is written
(`FavouritesTests.aThirteenthFavouriteIsRefusedAsOverCap`). The committed samples of A18-P06 (T-A18-605,
`ExperienceTests/StoredSampleTests.swift`) and the drawing-failure test (T-A18-604,
`ExperienceTests/AmbientRecoveryDrawTests.swift`) prove that every sample and `favourites.json` stay byte-identical.

## What is read

Only the experience's own files above, the system clock, and the system's calendar, time zone and locale (through
Foundation's formatters and the system's time-change notifications). The experience opens no document picker and reads
no photo, document, file or folder outside its storage.

## How to delete

- **A favourite.** Removing a favourite rewrites `favourites.json` without it; removing the last one removes the file.
- **Ambient Clock's data.** In the app's Settings, the data section lists every experience with stored data; its reset
  button for Ambient Clock, after a confirmation, removes the experience's folder with `state.json` and
  `favourites.json` (`Apps/VisualCore/App/SettingsView.swift`, `AppModel.reset(_:)` with `ResetPlan.experience`).
- **Everything.** The reset of all data in the same section, or deleting the app, removes every experience's folder,
  Ambient Clock's `state.json` and `favourites.json` included. Both files are removed when the app is deleted.

## Permissions

Ambient Clock requests no permission and adds no usage-description string (FR-A18-601). Its registration declares no
permission (`"permissions": []` in `Catalog/registrations.json`). The experience uses no sensor: no motion, position,
contacts, photo library, image picker, microphone or photo and video capture. It plays no sound and gives no haptic.
Nothing is announced; the canvas label is the spoken time (`AmbientPresenter.describe`).

## Keep-awake

- **Off by default.** The snapshot's `keepAwake` is false in a new state and in every migrated older snapshot
  (`PowerCoreTests.theEarlierExamplesMigrateToSchemaThreeWithTheDefaults`).
- **Turned on only by the person**, with the toggle "Keep the screen on while the clock is open"
  (`AC/Experience/AmbientControls.swift`, identifier `experience.a18.ambient-clock.keep-awake`, action
  `screen.keepAwake`).
- **Only while the clock is open.** `KeepAwakeController` holds the system idle timer off exactly while the setting is
  on and the clock is visible: from the presenter's setup or `didBecomeActive` until `willResignActive`,
  `didEnterBackground` or teardown, and writes only on a change. With the setting off the idle timer is never held
  (`KeepAwakeTests.withTheSettingOffThePortIsNeverSetToTrue`, `withTheSettingOnThePortFollowsEveryTransition`,
  `theControllerWritesOnlyOnChange`).
- **In one file.** `isIdleTimerDisabled` is named only in `AC/Experience/KeepAwake.swift`
  (`SourceScanTests.theIdleTimerIsNamedOnlyInKeepAwake`; the source scan `ac-no-network`, T-A18-603).

## Screen brightness

The system screen brightness is never written. Night mode dims and warms the drawing itself (the scene's dim factor
and tint, and warm text) and the idle dim lowers the drawing's and the text's opacity; neither touches the system
setting. No source of the experience writes a brightness (`SourceScanTests.noSourceWritesABrightness`; the source scan
`ac-no-network` refuses any `brightness =` write, T-A18-603).

## What is not done

- **Nothing is sent.** There is no upload, sync, sign-in, analytics or crash reporting by the experience. The stored
  files never leave the device. Nothing is downloaded.
- **No network, tracking, recording or sensors.** The sources of the experience contain none of the APIs of the spec's
  Clarifications Q3: no networking session or Network import, no position, capture, recording, audio input, motion,
  contacts, photo-library, image-picker, advertising-identifier or tracking-transparency API (check `ac-no-network`,
  T-A18-603: `specs/136-ac-p06-release/scan-sources-release.sh`, `.autonomy/checks/A18-P06.ac-no-network.json`). The
  app tracks nothing (`NSPrivacyTracking` false, no tracking domains).
- **No personal data.** The person types only favourite names, which stay in `favourites.json` on the device.

## Required-reason APIs and the app's privacy manifest

The app manifest `Apps/VisualCore/Resources/PrivacyInfo.xcprivacy` declares no tracking, no collected data types and
three accessed-API categories. The experience's uses fall under them; it adds none:

| Category and reason | Use by Ambient Clock |
|---|---|
| `NSPrivacyAccessedAPICategoryFileTimestamp`, `C617.1` | `ExperienceStorage` reads file attributes (type and size) of the experience's own `favourites.json` when it is read or written, and `SavedStateStore` of `state.json` |
| `NSPrivacyAccessedAPICategoryUserDefaults`, `CA92.1` | `ExperienceStorage` holds the app's `UserDefaults` for named values under the experience's prefix; Ambient Clock stores none |
| `NSPrivacyAccessedAPICategorySystemBootTime`, `35F9.1` | Frame times come from the app's render host (`ExperienceSession`); the experience's sources read no boot time. The clock's time is the wall clock (`ClockSource`), not elapsed time |

The built product is checked against this manifest by `release_check.py --only app-release-build
app-privacy-manifest app-no-tracking app-usage-descriptions` ([build-and-archive](../../release/build-and-archive.md);
T-A18-611).

## Credits and license inventory

Consistent with [licenses.md](licenses.md): everything the clock draws is code written for this repository.

| Item | Kind | Source | License |
|---|---|---|---|
| Theme "Noise Gradient" | Code, `AC/Experience/NoiseGradientTheme.swift`, over the `vc/noise.glsl` and `vc/color.glsl` library | VisualCore (written for this experience) | original (repository LICENSE, MIT) |
| Theme "Particle Drift": procedural discs in hashed cells | Code, `AC/Experience/ParticleDriftTheme.swift`, over `vc/hash.glsl` | VisualCore | original (repository LICENSE, MIT) |
| Theme "Wave Field": a sum of sine waves | Code, `AC/Experience/WaveFieldTheme.swift` | VisualCore | original (repository LICENSE, MIT) |
| Theme "SDF Shapes" | Code, `AC/Experience/SDFShapesTheme.swift`, over `vc/sdf.glsl` | VisualCore | original (repository LICENSE, MIT) |
| Palettes: three per theme, four colours each | Numbers, `AC/Core/ThemeCatalog.swift` | chosen for this experience | facts (colour values), no license needed |
| Night text colour (warm amber) and tint | Numbers, `AC/Core/NightPolicy.swift` | chosen for this experience | facts (colour values) |
| Time and date text | The system font, drawn by SwiftUI in `AC/Experience/ClockOverlay.swift`; the strings from the system's own locale data through Foundation's formatters | part of iOS | nothing bundled |
| The experience's sources (clock model, formatter, schedule, night policy, screen care, catalog, presets, presenter, controls, overlay, favourites, keep-awake, adapter) | Code | VisualCore | original (repository LICENSE, MIT) |

- **Visuals.** Drawn by code only: every theme is a full-screen shader drawn through the host's renderer (VisualCore's
  `FullScreenShaderScene`, `CrossfadeScene` and `CachedScene`); the time, the date and the controls are native text.
  No image, texture, font file, model, sound or generated asset is bundled, and nothing is downloaded.
- **Sound.** None.
- **Code.** The experience depends only on the local packages `Packages/VisualCore` and `Packages/VisualCoreRendering`
  (`Packages/ExperiencesCreative/Package.swift`); it adds no third-party package. The app's third-party components
  (ANGLE and the libraries inside it, listed in `docs/legal/third-party.json`) are bundled under the app's `Licenses`
  folder, shown in the app's Acknowledgements and checked by `app-licenses`.
- **Test samples.** The committed sample files of A18-P06 (T-A18-605) are resources of the test target only;
  `scenario-manifest.json` is outside every target's path.
- **ProjectM.** Not used; no engine code, preset format or name of it is in the experience, and ProjectM types stay out
  of the app.
