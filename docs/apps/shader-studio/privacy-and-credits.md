# Shader Studio — privacy and credits

Shader Studio is the experience `a22.shader-studio` of the one VisualCore app (ADR-0009). It has no app target,
Info.plist or privacy manifest of its own: the app's declarations cover it. Feature 164 (A22-P06), FR-A22-601 and
FR-A22-602. Sources: `Packages/ExperiencesCreative/ShaderStudio` (below: SS).

Shader Studio is a small editor for GLSL ES 3.00 fragment shaders. The person starts from one of four templates
written in code, edits the source with line numbers, runs it, reads each error on the line they wrote, moves the
float uniforms in an inspector, picks textures made in code, and keeps named projects in a library on the device. It
writes only the files below and nothing is sent.

## What is stored on the device

Every stored item lives in the experience's own storage: the folder `Application Support/Experiences/a22.shader-studio/`
of the experience (`ExperienceStorage`, bounded by `StorageQuota`: at most 64 files and 16 MiB together). Every file is
written atomically (a reader sees the complete old or the complete new file; a failed write keeps the previous file).
Shader Studio stores no named value under its defaults prefix.

| What | Where | Written by, and when | Content |
|---|---|---|---|
| Saved session state (the snapshot) | `state.json` in the experience's storage folder | the app (`SavedStateStore` in `Packages/VisualCore`, the session's snapshot sink in `Apps/VisualCore/App/AppModel.swift`), not the experience, at every suspension and close of the session and at a checkpoint after an accepted change; the file is replaced each time | The core's snapshot, schema 1 (`ShaderStudio/Experience/Adapter/StudioCore.swift`, digest domain `a22.shader-studio.v1`): the JSON object `{"resets", "runs", "shape", "template", "textures", "values"}` with sorted keys: the selected template (0…3), the 16 normalized uniform values (0…1), the 2 texture choices (0 checker, 1 ramp, 2 noise), the run count, the preview-reset count and the document's shape (its uniform count 0…16 and texture-input count 0…2). `textures`, `resets` and `shape` are optional on restore. The edited source is not in the snapshot; there is no name, no device data and no position |
| A named project | `project-<n>.json` in the experience's storage folder (n is a counter, never reused while the index or a higher file exists) | `ShaderStudio/Experience/ProjectLibrary.swift`, only when the person saves or renames that project in the library | One envelope of kind `a22.saved-project`, version 1, at most 131,072 bytes: the project's name in the library (1…40 characters after trimming), its modification order, the shader project (the `ShaderProject` encoding of kind `a22.shader-project`, schema 1, at most 65,536 bytes: the name, the fragment source, the float uniforms with their ranges and defaults, the limits and the texture-input names), the 16 normalized uniform values and the 2 texture choices |
| The library index | `library.json` in the experience's storage folder | `ProjectLibrary.swift`, after a save, a rename or a removal | One envelope of kind `a22.project-library`, version 1, at most 131,072 bytes: the next counter and, for each project file, its file name, name and order |

The library holds at most 24 projects (unreadable files count, as they hold storage). A name is 1…40 characters, and
names that differ only in case are the same; a save or rename to a used name is refused. The four templates, their
uniforms, the three texture recipes, the prelude and the limits are code in the app bundle and are never written.

Opening never rewrites a stored file. A project file that is damaged, of a newer version, too large or out of range,
or whose embedded project is refused (`damaged`, `newer-version`, `too-large`, `not-finite`, `out-of-range`), is listed
as unreadable with its code and is never opened, renamed or removed automatically
(`LibraryTests.unreadableFilesAreListedKeptAndOnlyRemovedOnRequest`). An index of a newer version makes the library
read only, so a newer build's index is never overwritten (`LibraryTests.aNewerIndexMakesTheLibraryReadOnly`); a damaged
index is rebuilt by the next change, never by reading. A save past a cap or a full storage quota is refused with its
message and keeps the previous file (`LibraryTests.everyCapRefusesWithItsMessageAndChangesNothing`,
`aFullQuotaRefusesAndKeepsThePreviousFile`). A damaged or out-of-range snapshot is refused
(`StudioCoreTests.theSnapshotRoundTripsAndDamageIsRefused`, `ShapeTests.outOfRangeShapesAreRefused`). A drawing failure
ends the session with a message and leaves every stored file byte-identical (A22-P06 T-A22-604,
`ExperienceTests/StudioRecoveryDrawTests.swift`); the committed samples of A22-P06 (T-A22-605,
`ExperienceTests/StoredSampleTests.swift`) prove that every sample opens or is refused as specified and stays
byte-identical.

## No temporary file

Shader Studio writes no temporary file, makes no picture file and exports nothing. The textures are made in code at
run time (`ShaderStudio/Core/TextureRecipes.swift`) and live in GPU memory only; the preview is never written to disk.

## What is read

Only the experience's own snapshot, project files and index above. The experience opens no document picker, its code
never reads the pasteboard, and it reads no photo, document, file or folder outside its storage. It never reads the photo library.

## How to delete

- **One project.** In the library, select the project and choose Remove: only this explicit action removes a project
  file, readable or not (`ProjectLibrary.remove(_:)`, `StudioLibraryView.swift`;
  `LibraryTests.saveOpenRenameAndRemoveRoundTrip`).
- **Shader Studio's data.** In the app's Settings, the data section lists every experience with stored data; its reset
  button for Shader Studio, after a confirmation, removes the experience's folder with `state.json`, every
  `project-<n>.json` and `library.json` (`Apps/VisualCore/App/SettingsView.swift`, `AppModel.reset(_:)`). The next open
  shows the Gradient template and an empty library.
- **Everything.** The reset of all data in the same section, or deleting the app, removes every experience's folder,
  Shader Studio's included. The snapshot, the projects and the index are removed when the app is deleted.

## Permissions

No permission is asked. The registration declares `"permissions": []` (`Catalog/registrations.json`), so no usage
string is needed for it. Shader Studio uses no location, microphone, camera, motion, contacts, photo library or image
picker, and no sensor of any kind.

The screen: Shader Studio never changes the screen's idle timer (it never keeps the screen awake) and never changes the
screen brightness; the system's auto-lock applies as usual.

## GPU code is not a sandbox

A person's shader runs on the device's graphics processor through the app's renderer (OpenGL ES over ANGLE on Metal).
GPU code is not a sandbox, and Shader Studio makes no claim that any shader is harmless to run. What the experience
does instead, and what its tests prove:

- before any compile, the source validator refuses a source past the limits (16,384 bytes, 400 lines, 16 float
  uniforms, 2 texture inputs), a `#version` line, a reserved or undeclared name and a source without `void main`
  (`ValidatorTests`, `OversizedProjectTests`);
- a failed compile keeps drawing the last good program (`LastGoodPreviewTests`);
- a frame watchdog stops the preview after 8 consecutive slow frame intervals and draws a flat frame until Reset
  (`FrameWatchdogTests`, `WatchdogTests`); the stop on real hardware is device row SS-D1 of
  [device-campaign.md](device-campaign.md).

A shader the person writes can still make the device's graphics processor busy until the watchdog stops it.

## What is not done

- **Nothing is sent.** There is no network use, sign-in, analytics or crash reporting by the experience. The snapshot,
  the projects and the index never leave the device. Nothing is downloaded, and the experience works offline. The
  experience offers no share sheet and its code never touches the pasteboard (the system's own text editing in the
  editor works as in any text field).
- **No network, tracking, recording or sensors.** The sources of the experience contain none of the APIs of the spec's
  Clarifications Q3: no networking session or Network import, no position, capture, recording, microphone input,
  motion, contacts, photo-library, Photos picker, advertising-identifier or tracking-transparency API, no idle timer,
  no brightness write, no pasteboard and no share link (check `scan-sources`, T-A22-603:
  `specs/164-ss-p06-release/scan-sources-release.sh`, `.autonomy/checks/A22-P06.scan-sources.json`). The app tracks
  nothing (`NSPrivacyTracking` false, no tracking domains).
- **Personal text stays local.** The person types shader source and project names; both stay in the experience's own
  storage and are read by nothing else.

## Required-reason APIs and the app's privacy manifest

The app manifest `Apps/VisualCore/Resources/PrivacyInfo.xcprivacy` declares no tracking, no collected data types and
three accessed-API categories. The experience's uses fall under them; it adds none:

| Category and reason | Use by Shader Studio |
|---|---|
| `NSPrivacyAccessedAPICategoryFileTimestamp`, `C617.1` | `SavedStateStore` reads file attributes (type and size) of the experience's own `state.json`, and `ExperienceStorage` reads the size of the experience's own files when the library lists, reads or writes them; the experience itself reads no file attribute |
| `NSPrivacyAccessedAPICategoryUserDefaults`, `CA92.1` | `ExperienceStorage` holds the app's `UserDefaults` for named values; Shader Studio stores none |
| `NSPrivacyAccessedAPICategorySystemBootTime`, `35F9.1` | Frame times come from the app's render host (`ExperienceSession`); the watchdog is fed each drawn frame's delta, and the experience's sources read no boot time |

The built product is checked against this manifest by `release_check.py --only app-release-build
app-privacy-manifest app-no-tracking app-usage-descriptions` ([build-and-archive](../../release/build-and-archive.md);
T-A22-611).

## Credits and license inventory

Consistent with [licenses.md](licenses.md): everything Shader Studio ships is code written for this repository. A
person's own shaders are their own work and stay on the device.

| Item | Kind | Source | License |
|---|---|---|---|
| Starter templates Gradient, Noise flow, Rings and Texture mix (GLSL ES 3.00 fragment sources and their uniforms) | Code, `ShaderStudio/Core/ShaderTemplates.swift`, over VisualCore's GLSL library `vc/` | written for this experience (A22-P01, A22-P03) | original (repository LICENSE, MIT) |
| Textures Checker, Ramp and Noise (64 × 64 values made at run time, never stored as images) | Code, `ShaderStudio/Core/TextureRecipes.swift` | written for this experience (A22-P03) | original (repository LICENSE, MIT) |
| Template prelude `ss/prelude.glsl` and the assembly | Code, `ShaderStudio/Core/ShaderAssembly.swift` | VisualCore | original (repository LICENSE, MIT) |
| GLSL ES 3.00 keyword, type and built-in word lists of the editor's tokenizer | Names, `ShaderStudio/Core/GLSLTokenizer.swift` | facts of the OpenGL ES Shading Language 3.00 specification | facts; the list is the repository LICENSE, MIT |
| Limits, guidance sentences and the watchdog | Numbers and text, `ShaderStudio/Core/ShaderProject.swift`, `Guidance.swift`, `FrameWatchdog.swift` | written for this experience | original (repository LICENSE, MIT) |
| GLSL library `vc/` (hashes, gradient noise, fbm, colour) | Code, `Packages/VisualCoreRendering/Sources/VisualCoreRendering/GLSL/vc/` | VisualCore | original (repository LICENSE, MIT) |
| Text and labels; the editor's font | The system fonts (the editor uses the system's monospaced font), drawn by SwiftUI; the words in `ShaderStudio/Experience/StudioControls.swift`, `StudioEditor.swift`, `StudioInspector.swift`, `StudioLibraryView.swift` | part of iOS; text written for this experience | nothing bundled; original (repository LICENSE, MIT) |
| The experience's sources (core, adapter, presenter, pipeline, editor, inspector, library) | Code | VisualCore | original (repository LICENSE, MIT) |

- **Visuals.** Drawn by code only: the preview is the person's fragment shader (or a template) drawn through the host's
  renderer; the editor and controls are native text. No image, stored texture, font file, model, sound file or
  generated asset is bundled, and nothing is downloaded.
- **Code.** The experience depends only on the local packages of VisualCore (`Packages/ExperiencesCreative/Package.swift`);
  it adds no third-party package. The app's third-party components (ANGLE and the libraries inside it, listed in
  `docs/legal/third-party.json`) are bundled under the app's `Licenses` folder, shown in the app's Acknowledgements and
  checked by `app-licenses`.
- **Test samples.** The committed sample files of A22-P06 (T-A22-605) are resources of the test target only;
  `scenario-manifest.json` is outside every target's path.
- **ProjectM.** Not used; no engine code, preset format or name of it is in the experience, and ProjectM types stay out
  of the app.
