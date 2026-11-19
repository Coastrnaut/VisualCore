# Effects Composer — privacy and credits

Effects Composer is the experience `a25.effects-composer` of the one VisualCore app (ADR-0009). It has no app target,
Info.plist or privacy manifest of its own: the app's declarations cover it. Feature 185 (A25-P06), FR-A25-601 and
FR-A25-602. Sources: `Packages/ExperiencesCreative/EffectsComposer` (below: EC).

Effects Composer applies a chain of up to eight effects, chosen from five built-in ones (Color grade, Blur, Distort,
Vignette and Posterize), in order to a picture, with a preview drawn at the next frame after every edit and an undo and
redo of every edit. The picture is the built-in test picture made in code or a picture the person picks with the
system photo picker. Chains can be kept as named looks (presets) and opened later, and the shown picture can be
exported at its full size as PNG, JPEG or HEIC and handed to the system share sheet. It writes only the files below.
Nothing is sent automatically: a picture leaves the device only as an export file through the system share sheet that
the person opens after an export.

## What is stored on the device

Every stored item except the export files lives in the experience's own storage: the folder
`Application Support/Experiences/a25.effects-composer/` of the experience (`ExperienceStorage`, bounded by
`StorageQuota`: at most 64 files and 16 MiB together). Every file is written atomically (a reader sees the complete old
or the complete new file; a failed write keeps the previous file). Effects Composer stores no named value under its
defaults prefix.

| What | Where | Written by, and when | Content |
|---|---|---|---|
| Saved session state (the snapshot) | `state.json` in the experience's storage folder | the app (`SavedStateStore` in `Packages/VisualCore`, the session's snapshot sink in `Apps/VisualCore/App/AppModel.swift`), not the experience, at every suspension and close of the session; the file is replaced each time | The core's snapshot, schema 1 (`EffectsComposer/Experience/Adapter/ComposerCore.swift`, digest domain `a25.effects-composer.v1`): the chain file's body `{"nodes": [...]}`, exactly the bytes `ChainDocument.encode` writes for it: each node's identifier, effect, enabled flag and parameter values. The undo and redo history, the compare setting and the picture are not in it, so a restored session starts with an empty history on the test picture. There is no name, no device data and no picture data in it |
| A saved look | `preset-<n>.json` in the experience's storage folder (n is a counter, never reused while the index or a higher file exists) | `EffectsComposer/Experience/LookLibrary.swift`, only when the person taps Save in the presets section with a name typed | One envelope of kind `a25.preset`, version 1, at most 69,632 bytes: the look's name (1 to 40 characters), its order and the chain (the chain file of kind `a25.effect-chain`, version 1, at most 65,536 bytes, embedded as a JSON object). No picture is stored with a look |
| The looks index | `presets.json` in the experience's storage folder | `LookLibrary.swift`, after a save or a removal | One envelope of kind `a25.preset-library`, version 1: the next counter and, for each look file, its file name, name and order |
| An export of the shown picture | `Look <W>x<H>.png`, `.jpeg` or `.heic` in the temporary folder `EffectsComposer` (in the app's temporary directory), not in the experience's storage | `EffectsComposer/Experience/StillExport.swift`, only when the person taps Export as PNG, Export as JPEG or Export as HEIC | The chain drawn again over the shown picture at its full size, encoded as PNG, JPEG or HEIC (quality 0.9 for JPEG and HEIC), opaque and tagged sRGB. It is handed to the share sheet only when the person taps Share (`ShareLink` in `Experience/ECControls.swift`) |

The library holds at most 24 looks (unreadable files count, as they hold storage). The five effects, their parameters
and ranges (`Core/EffectDefinition.swift`), their fragment programs (`Core/EffectPrograms.swift`) and the test picture
(`Core/TestImage.swift`) are code in the app bundle and are never written.

Opening never rewrites a stored file. A look file that is damaged, of a newer version, too large or whose embedded
chain is refused (`damaged`, `newer-version`, `too-large`, or the chain file's own code) is listed as unreadable with
its code and is never opened or removed automatically
(`LookLibraryTests.unreadableFilesAreListedAndKeptByteIdentical`). An index of a newer version makes the library read
only, so a newer build's index is never overwritten (`LookLibraryTests.aNewerIndexMakesTheLibraryReadOnly`); a damaged
index is rebuilt by the next change, never by reading (`LookLibraryTests.aDamagedIndexIsRebuiltOnlyByTheNextChange`).
A 25th save or a full storage quota is refused with its message and changes nothing
(`LookLibraryTests.refusedSavesAndRenamesChangeNothing`, `aFullQuotaRefusesWithTheMessageAndWritesNothing`). A damaged
snapshot is refused (`ComposerCoreTests.aDamagedPayloadIsRefused`). A drawing failure ends the session with the message
"The picture could not be drawn." and leaves every stored file byte-identical, and a new session lists and opens the
looks (A25-P06 T-A25-604, `ExperienceTests/ComposerRecoveryTests.swift`); the committed samples of A25-P06
(T-A25-605, `ExperienceTests/Fixtures/`, `ExperienceTests/ReleaseSampleTests.swift`) prove that every sample opens or
is refused as specified and stays byte-identical.

## A picked picture

The `import` control ("Choose a picture") opens the system photo picker (SwiftUI `PhotosPicker`, images only). The
picker runs outside the app's process and gives the app only the one picture the person picks; the app has no read
access to the photo library and asks no permission for it, and nothing is read before the person picks. The picked
picture's data is decoded off the main thread with ImageIO into sRGB bytes, the longer edge at most 2,048 pixels
(`Experience/ImageImport.swift`), and held in memory only, as the source of the preview. It is never written to a file:
it is in neither the snapshot nor a look, so a restored session shows the test picture
(`PictureSourceTests.aRestoredSessionShowsTheTestPicture`), and `test-picture` ("Use the test picture") returns to it at
any time. Damaged, too small and too large data is refused with a message and changes nothing
(`ImageImportTests.damaged`, `tooSmall`, `tooLarge`).

## The export files

An export is written only on the person's tap of an export button, into the temporary folder `EffectsComposer`; the
experience never writes one by itself. The earlier file is removed before the next export, so one export file exists
at a time (`PresenterExportTests.oneFileAtATime` in `StillExportTests.swift`), and the folder is removed when the
experience closes (`PresenterExportTests.closingRemovesTheFolder`). An export interrupted by a context loss leaves no
file (`RobustnessTests.anExportInterruptedByAContextLossLeavesNoFileAndTheNextSucceeds`). The share item carries the
content type of its format and sends the written file itself. The share sheet reports no completion, so a shared file
stays in the temporary folder until the next export or the close of the experience. Where the file goes after that is
the person's choice in the system share sheet.

## What is read

Only the experience's own snapshot, look files and index above, and the one picture the person picks in the system
photo picker. The experience opens no document picker, its code never reads the pasteboard, and it reads no photo,
document, file or folder outside its storage, its export folder and the picked picture. It never reads the photo
library itself.

## How to delete

- **One look.** In the presets section, choose Remove on the look's row: only this explicit action removes a look
  file, readable or not (`LookLibrary.remove`, `ECControls.swift`;
  `LookLibraryTests.saveOpenRenameAndRemoveRoundTrip`).
- **The exports.** They are removed before the next export and when the experience closes (above).
- **The picked picture.** It is never stored; it is gone when the session ends or the test picture is chosen.
- **Effects Composer's data.** In the app's Settings, the data section lists every experience with stored data; its
  reset button for Effects Composer, after a confirmation, removes the experience's folder with `state.json`, every
  `preset-<n>.json` and `presets.json` (`Apps/VisualCore/App/SettingsView.swift`, `AppModel.reset(_:)`). The next open
  shows the test picture with an empty chain and no saved look.
- **Everything.** The reset of all data in the same section, or deleting the app, removes every experience's folder,
  Effects Composer's included. The snapshot, the looks, the index and the temporary folder are removed when the app is
  deleted.

## Permissions

The registration declares `"permissions": ["photo-library-add"]` (`Catalog/registrations.json`). The app's
`NSPhotoLibraryAddUsageDescription` reads, word for word: "Saves exported artwork to your photo library when you choose
Save Image." (`Apps/VisualCore/Generated/Info.plist`, from `project.yml`, checked by `BundleTests`). This add-only
Photos prompt is shown by the system only when the person chooses Save Image in the share sheet for an exported
picture; it lets the system add that picture to the photo library and never gives the app read access. Effects
Composer's own code calls no photo-library API (no `PHPhotoLibrary`, no `import Photos`). The photo picker runs out of
process and needs no usage string; the share sheet needs none. Effects Composer uses no location, microphone, camera,
motion or contacts, and no sensor of any kind.

The screen: Effects Composer never changes the screen's idle timer (it never keeps the screen awake) and never changes
the screen brightness; the system's auto-lock applies as usual.

## What is not done

- **Nothing is sent automatically.** There is no network use, sign-in, analytics or crash reporting by the experience.
  The snapshot, the looks, the index and the picked picture never leave the device by themselves. A picture leaves the
  device only as an export file through the system share sheet that the person opens after an export. Nothing is
  downloaded, and the experience works offline. The experience's code never touches the pasteboard.
- **No network, tracking, recording or sensors.** The sources of the experience contain none of the APIs of the spec's
  Clarifications Q3: no networking session or Network import, no position, capture, recording, microphone input,
  motion, contacts, photo-library, advertising-identifier, vendor-identifier, device-name or tracking-transparency API,
  no idle timer, no brightness write, no pasteboard, and `PhotosUI`, `PhotosPicker` and `ShareLink` appear only in
  `Experience/ECControls.swift` (check `scan-sources`, T-A25-603: `specs/185-ec-p06-release/scan-sources-release.sh`,
  `.autonomy/checks/A25-P06.scan-sources.json`). The app tracks nothing (`NSPrivacyTracking` false, no tracking
  domains).

## Required-reason APIs and the app's privacy manifest

The app manifest `Apps/VisualCore/Resources/PrivacyInfo.xcprivacy` declares no tracking, no collected data types and
three accessed-API categories. The experience's uses fall under them; it adds none:

| Category and reason | Use by Effects Composer |
|---|---|
| `NSPrivacyAccessedAPICategoryFileTimestamp`, `C617.1` | `SavedStateStore` reads file attributes (type and size) of the experience's own `state.json`, and `ExperienceStorage` reads the size of the experience's own files when the library lists, reads or writes them; the experience itself reads no file attribute |
| `NSPrivacyAccessedAPICategoryUserDefaults`, `CA92.1` | `ExperienceStorage` holds the app's `UserDefaults` for named values; Effects Composer stores none |
| `NSPrivacyAccessedAPICategorySystemBootTime`, `35F9.1` | Frame times come from the app's render host (`ExperienceSession`); the experience's sources read no boot time |

The built product is checked against this manifest by `release_check.py --only app-release-build
app-privacy-manifest app-no-tracking app-usage-descriptions` ([build-and-archive](../../release/build-and-archive.md);
T-A25-611).

## Credits and license inventory

Consistent with [licenses.md](licenses.md): everything Effects Composer ships is made in code written for this
repository. A person's own pictures and looks are their own and stay on the device unless the person exports a
picture.

| Item | Kind | Source | License |
|---|---|---|---|
| The five effects Color grade, Blur, Distort, Vignette and Posterize (parameters, ranges, defaults, versions) | Names and numbers, `EffectsComposer/Core/EffectDefinition.swift` | written for this experience (A25-P01) | original (repository LICENSE, MIT) |
| The effects' fragment programs and their CPU references; the colour domain (sRGB decode and encode) | Code, `Core/EffectPrograms.swift`, `Core/EffectReference.swift`, `Core/ColorDomain.swift`, over VisualCore's GLSL library `vc/` | written for this experience (A25-P01, A25-P05) | original (repository LICENSE, MIT) |
| The built-in test picture (colour ramps with a checker) | Code, `Core/TestImage.swift` | written for this experience (A25-P01, A25-P02) | original (repository LICENSE, MIT) |
| The pass plan, the preview renderer and its pooled targets, the export | Code, `Core/PassPlan.swift`, `Experience/PreviewRenderer.swift`, `Experience/StillExport.swift` | written for this experience (A25-P02, A25-P05) | original (repository LICENSE, MIT) |
| Chain file `a25.effect-chain`, look file `a25.preset`, looks index `a25.preset-library`; the committed test samples | Formats and test resources, `Core/ChainDocument.swift`, `Experience/LookLibrary.swift`, `ExperienceTests/Fixtures/` | written for this experience (A25-P01, A25-P03, A25-P06) | original (repository LICENSE, MIT) |
| Status lines, sentences and spoken labels | Text, `Experience/ECControls.swift`, `Experience/ComposerPresenter.swift`, `Experience/Adapter/ComposerCore.swift` | written for this experience | original (repository LICENSE, MIT) |
| GLSL library `vc/` (colour) | Code, `Packages/VisualCoreRendering/Sources/VisualCoreRendering/GLSL/vc/` | VisualCore | original (repository LICENSE, MIT) |
| Text and labels | The system fonts, drawn by SwiftUI | part of iOS | nothing bundled |
| The experience's sources (core, adapter, presenter, renderer, import, export, library, controls) | Code | VisualCore | original (repository LICENSE, MIT) |

- **Visuals.** Made in code only: every effect is a fragment program written for this experience, and the built-in
  test picture is computed in code; the controls are native views. No image, stored texture, font file, model, sound
  file or generated asset is bundled, and nothing is downloaded. A picture the person picks is their own input, never
  bundled and never stored.
- **Code.** The experience depends only on the local packages of VisualCore and the system frameworks
  (`Packages/ExperiencesCreative/Package.swift`); it adds no third-party package. The app's third-party components
  (ANGLE and the libraries inside it, listed in `docs/legal/third-party.json`) are bundled under the app's `Licenses`
  folder, shown in the app's Acknowledgements and checked by `app-licenses`.
- **Test samples.** The committed sample files (`ExperienceTests/Fixtures/`, T-A25-605) and the test pictures that the
  import tests write with ImageIO are resources or outputs of the test targets only; `scenario-manifest.json` is outside
  every target's path.
- **ProjectM.** Not used; no engine code, preset format or name of it is in the experience, and ProjectM types stay out
  of the app.
