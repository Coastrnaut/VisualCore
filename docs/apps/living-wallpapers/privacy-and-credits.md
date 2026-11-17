# Living Wallpapers — privacy and credits

Living Wallpapers is the experience `a19.living-wallpapers` of the one VisualCore app (ADR-0009). It has no app
target, Info.plist or privacy manifest of its own: the app's declarations cover it. Feature 143 (A19-P06), FR-A19-601
and FR-A19-602. Sources: `Packages/ExperiencesCreative/LivingWallpapers` (below: LW).

Living Wallpapers draws procedural backgrounds in code and exports one framed still at a device template's size. The
person keeps the file through the system share sheet and makes it their wallpaper in the Settings app; the experience
never changes the wallpaper.

## What is stored on the device

Both stored files live in the experience's own storage folder, `Application Support/Experiences/a19.living-wallpapers/`,
and are written atomically (a reader sees the complete old or the complete new file).

| What | Where | Written by, and when | Content |
|---|---|---|---|
| Saved session state (the snapshot) | `state.json` in the experience's storage folder | the app (`SavedStateStore` in `Packages/VisualCore`, the session's snapshot sink in `Apps/VisualCore/App/AppModel.swift`), not the experience, at every suspension and close of the session and at a checkpoint after an accepted change; the file is replaced each time | The core's snapshot, schema 2 (`LW/Experience/Adapter/WallpaperCore.swift`, JSON with sorted keys): the scene, the colour preset, the scene's parameter values, the edited colours (`custom` and the twelve colour components), the canvas template, the orientation, the animation time, the export format and the motion setting. Nothing else: the seed and the quality tier are not stored, and there is no name, no device data and no position |
| Export history | `history.json` in the same folder | `LW/Experience/HistoryStore.swift`, through `ExperienceStorage.write`, after each written export; "Clear history" removes the file | One envelope (kind `a19.export-history`, schema version 1, JSON with sorted keys, `LW/Core/ExportHistory.swift`) of at most 20 entries, newest first; each names the scene, the template, the orientation, the format, the written width and height in pixels and the time the export was written. The file is at most 16,384 bytes |

The project fields the export plans from (`LW/Core/WallpaperProject.swift`: scene, preset, seed, parameters, template,
orientation, animation time, format and the optional edited colours) are built from the core when an export starts;
the experience writes no project file of its own. The scenes, presets, templates and shaders are code in the app
bundle and are never written.

Opening never rewrites a stored file. A snapshot of a newer schema, a damaged one, or one with a value outside its
range is refused by the host and the opening state opens (`SnapshotMigrationTests.aNewerSchemaIsRefusedAndChangesNothing`;
`WallpaperCoreTests.aPayloadOutsideItsRangesIsRefused`). A schema-1 snapshot (A19-P02) opens migrated with the preset's
own colours (`SnapshotMigrationTests.theSchemaOneExampleRestoresAsSchemaTwoWithCustomZero`). A history file that is
damaged, of a newer schema or too large gives an empty history and one problem (`damaged`, `newer-version`,
`too-large`) and is left as it is until the next written export or "Clear history"
(`HistoryStoreTests.damagedAndNewerFilesAreReportedWithAnEmptyHistory`; `ExportHistoryTests.eachRefusalHasItsCodeAndSentence`).
The committed samples of A19-P06 (T-A19-605, `ExperienceTests/StoredSampleTests.swift`) and the drawing-failure test
(T-A19-604, `ExperienceTests/WallpaperRecoveryDrawTests.swift`) prove that every sample and `history.json` stay
byte-identical.

## The temporary export file

An export writes one file, named "<Scene> <Device> <W>x<H>.<png|jpg|heic>", into the temporary folder
`LivingWallpapers-Export` in the app's temporary directory (`LW/Experience/StillExport.swift`,
`LW/Experience/ExportJob.swift`). The folder holds at most one file: a new export first removes the previous file, and
a cancelled or failed export removes its own (`ExportJobTests.aCancelAfterEachStepLeavesNoFileAndNoGPUResource`;
`StillExportTests.cancellingFailingAndRetryingLeaveNoGPUResourceAndNoFile`). The file leaves the app only when the
person chooses Share and hands it to the system share sheet (`ShareFileTests.theItemIsTheWrittenFile`;
`ShareFileTests.thereIsNoItemWithoutAWrittenFile`). It is removed with the app's temporary data and when the app is
deleted.

## What is read

Only the experience's own files above and the folder of its temporary export. The experience opens no document picker
and reads no photo, document, file or folder outside its storage and that temporary folder. It never reads the photo
library.

## How to delete

- **The export history.** "Clear history" (`experience.a19.living-wallpapers.clear-history`) empties the list and
  removes `history.json` (`HistoryStoreTests.clearEmptiesTheHistoryAndRemovesTheFile`).
- **Living Wallpapers' data.** In the app's Settings, the data section lists every experience with stored data; its
  reset button for Living Wallpapers, after a confirmation, removes the experience's folder with `state.json` and
  `history.json` (`Apps/VisualCore/App/SettingsView.swift`, `AppModel.reset(_:)` with `ResetPlan.experience`).
- **Everything.** The reset of all data in the same section, or deleting the app, removes every experience's folder,
  Living Wallpapers' `state.json` and `history.json` included. Both files and the temporary export file are removed
  when the app is deleted.
- **A saved image.** A copy the person saved to Photos or Files through the share sheet belongs to the person and is
  deleted there; the app keeps no link to it.

## Permissions

Living Wallpapers requests no permission itself. Its registration declares `"permissions": ["photo-library-add"]`
(`Catalog/registrations.json`), covered by the app's one add-only usage string in `project.yml`:

> `NSPhotoLibraryAddUsageDescription`: "Saves exported artwork to your photo library when you choose Save Image."

The system asks for it only when the person chooses Save Image in the share sheet; the share sheet, not the
experience, adds the image. The experience calls no photo-library API and never reads the library (the scans
`specs/141-lw-p04-save-share/scan-photos.sh`, `.autonomy/checks/A19-P05.photos-scan.json`, and `lw-no-network`,
T-A19-603). When the person declines, Save to Files still works (device row LW-D7 of
[device-campaign.md](device-campaign.md), pending the device campaign). The experience uses no sensor: no motion,
position, contacts, image picker, microphone or photo and video capture. It plays no sound and gives no haptic. It
holds no idle timer and never writes the screen brightness.

## What is not done

- **Nothing is sent.** There is no upload, sync, sign-in, analytics or crash reporting by the experience. The stored
  files never leave the device; the export file leaves the app only through the share sheet when the person chooses
  it. Nothing is downloaded.
- **The wallpaper is never changed.** The experience makes no system-wallpaper call; the help explains how the person
  sets the image in the Settings app (`HelpTests.thePersonSetsTheWallpaper`).
- **No network, tracking, recording or sensors.** The sources of the experience contain none of the APIs of the spec's
  Clarifications Q3: no networking session or Network import, no position, capture, recording, audio input, motion,
  contacts, photo-library, Photos picker, image-picker, advertising-identifier or tracking-transparency API, no idle
  timer and no brightness write (check `lw-no-network`, T-A19-603: `specs/143-lw-p06-release/scan-sources-release.sh`,
  `.autonomy/checks/A19-P06.lw-no-network.json`). The app tracks nothing (`NSPrivacyTracking` false, no tracking
  domains).
- **No personal data.** The person types nothing; the history names only scenes, templates, formats, sizes and times.

## Required-reason APIs and the app's privacy manifest

The app manifest `Apps/VisualCore/Resources/PrivacyInfo.xcprivacy` declares no tracking, no collected data types and
three accessed-API categories. The experience's uses fall under them; it adds none:

| Category and reason | Use by Living Wallpapers |
|---|---|
| `NSPrivacyAccessedAPICategoryFileTimestamp`, `C617.1` | `ExperienceStorage` reads file attributes (type and size) of the experience's own `history.json` when it is read or written, `SavedStateStore` of `state.json`, and `TemporaryFolder` of the files in `LivingWallpapers-Export` |
| `NSPrivacyAccessedAPICategoryUserDefaults`, `CA92.1` | `ExperienceStorage` holds the app's `UserDefaults` for named values under the experience's prefix; Living Wallpapers stores none |
| `NSPrivacyAccessedAPICategorySystemBootTime`, `35F9.1` | Frame times come from the app's render host (`ExperienceSession`); the experience's sources read no boot time. The history's time comes from the injected `ClockSource` (`SystemClock`, the wall clock) |

The built product is checked against this manifest by `release_check.py --only app-release-build
app-privacy-manifest app-no-tracking app-usage-descriptions` ([build-and-archive](../../release/build-and-archive.md);
T-A19-611).

## Credits and license inventory

Consistent with [licenses.md](licenses.md): everything Living Wallpapers draws is code written for this repository.

| Item | Kind | Source | License |
|---|---|---|---|
| Scene "Aurora Bands" (soft vertical light bands) | Code, `LW/Experience/SceneShaders.swift`, over VisualCore's GLSL library | VisualCore (written for this experience) | original (repository LICENSE, MIT) |
| Scene "Ink Flow" (domain-warped noise) | Code, `LW/Experience/SceneShaders.swift` | VisualCore | original (repository LICENSE, MIT) |
| Scene "Soft Cells" (Voronoi cells) | Code, `LW/Experience/SceneShaders.swift` | VisualCore | original (repository LICENSE, MIT) |
| Scene "Ripple Dunes" (layered sine dunes) | Code, `LW/Experience/SceneShaders.swift` | VisualCore | original (repository LICENSE, MIT) |
| Colour presets: three per scene, four opaque sRGB colours each | Numbers, `LW/Core/SceneCatalog.swift` | chosen for this experience | facts (colour values), no license needed |
| Device template pixel sizes (nine templates) | Numbers, `LW/Core/CanvasTemplates.swift` | Apple technical specifications, retrieved 2026-11-17 | facts, no license needed |
| Safe-area guides (approximate fractions of the canvas) | Numbers, `LW/Core/CanvasTemplates.swift`, drawn by `LW/Experience/CropOverlay.swift` | the app's own design fractions, not system measurements | original (repository LICENSE, MIT) |
| Text, help and labels | The system font, drawn by SwiftUI; the help text in `LW/Core/WallpaperHelp.swift` | part of iOS; text written for this experience | nothing bundled; original (repository LICENSE, MIT) |
| The experience's sources (catalog, templates, crop frame, planner, colour pipeline, history, notice, presenter, export, job, controls, editor model, help view, adapter) | Code | VisualCore | original (repository LICENSE, MIT) |

- **Visuals.** Drawn by code only: every scene is a full-screen shader drawn through the host's renderer; the crop
  frame and the guides are drawn over it; the controls are native text. No image, texture, font file, model, sound or
  generated asset is bundled, and nothing is downloaded.
- **Sound.** None.
- **Code.** The experience depends only on the local packages `Packages/VisualCore` and `Packages/VisualCoreRendering`
  (`Packages/ExperiencesCreative/Package.swift`); it adds no third-party package. The image encoding uses the system's
  own frameworks. The app's third-party components (ANGLE and the libraries inside it, listed in
  `docs/legal/third-party.json`) are bundled under the app's `Licenses` folder, shown in the app's Acknowledgements and
  checked by `app-licenses`.
- **Test samples.** The committed sample files of A19-P06 (T-A19-605) are resources of the test target only;
  `scenario-manifest.json` is outside every target's path.
- **ProjectM.** Not used; no engine code, preset format or name of it is in the experience, and ProjectM types stay out
  of the app.
