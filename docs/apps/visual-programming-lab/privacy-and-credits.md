# Visual Programming Lab — privacy and credits

Visual Programming Lab is the experience `a23.visual-programming-lab` of the one VisualCore app (ADR-0009). It has no
app target, Info.plist or privacy manifest of its own: the app's declarations cover it. Feature 171 (A23-P06),
FR-A23-601 and FR-A23-602. Sources: `Packages/ExperiencesCreative/VisualProgrammingLab` (below: VPL).

Visual Programming Lab is a small node-graph editor for pictures. The person wires seven kinds of node (Time,
Constant, Noise, Gradient, Mix, Blur and Output) on a touch canvas or in the list form, sees the checker's status and
the sentence of a refused connection, previews the accepted graph, opens three example graphs written in code, and
keeps named graphs in a library on the device. There is no code to type. It writes only the files below and nothing
is sent.

## What is stored on the device

Every stored item lives in the experience's own storage: the folder
`Application Support/Experiences/a23.visual-programming-lab/` of the experience (`ExperienceStorage`, bounded by
`StorageQuota`: at most 64 files and 16 MiB together). Every file is written atomically (a reader sees the complete old
or the complete new file; a failed write keeps the previous file). Visual Programming Lab stores no named value under
its defaults prefix.

| What | Where | Written by, and when | Content |
|---|---|---|---|
| Saved session state (the snapshot) | `state.json` in the experience's storage folder | the app (`SavedStateStore` in `Packages/VisualCore`, the session's snapshot sink in `Apps/VisualCore/App/AppModel.swift`), not the experience, at every suspension and close of the session and at a checkpoint after an accepted change; the file is replaced each time | The core's snapshot, schema 1 (`VisualProgrammingLab/Experience/Adapter/LabCore.swift`, digest domain `a23.visual-programming-lab.v1`): the JSON object `{"graph", "selection"}` with sorted keys: the open graph (the `GraphDocument` encoding: its nodes with kind, identity, position and parameter values, and its connections) and the selected node (0 for none). The digest covers the graph, not the selection. There is no name, no device data and no position other than the nodes' places on the canvas |
| A named graph | `graph-<n>.json` in the experience's storage folder (n is a counter, never reused while the index or a higher file exists) | `VisualProgrammingLab/Experience/GraphLibrary.swift`, only when the person saves or renames that graph in the library | One envelope of kind `a23.saved-graph`, version 1, at most 81,920 bytes: the graph's name in the library (1…40 characters after trimming), its modification order and the graph (the graph file of kind `a23.visual-graph`, schema 1, at most 65,536 bytes, embedded as a JSON object) |
| The library index | `library.json` in the experience's storage folder | `GraphLibrary.swift`, after a save, a rename or a removal | One envelope of kind `a23.graph-library`, version 1: the next counter and, for each graph file, its file name, name and order |

The library holds at most 24 graphs (unreadable files count, as they hold storage). A name is 1…40 characters, and
names that differ only in case are the same; a save or rename to a used name is refused. The seven node kinds, their
ports and parameter ranges, the preview operators, the canvas grid and the three example graphs (Clouds, Soft gradient
and Mixed clouds) are code in the app bundle and are never written.

Opening never rewrites a stored file. A graph file that is damaged, of a newer version, too large or whose embedded
graph is refused (`damaged`, `newer-version`, `too-large`, or the graph file's own code such as `not-finite` or
`out-of-range`) is listed as unreadable with its code and is never opened, renamed or removed automatically
(`LibraryRefusalTests.unreadableFilesAreListedRefusedAndKept`). An index of a newer version makes the library read only,
so a newer build's index is never overwritten (`LibraryRefusalTests.aNewerIndexMakesTheLibraryReadOnly`); a damaged
index is rebuilt by the next change, never by reading. A save past a cap or a full storage quota is refused with its
message and changes nothing (`LibraryRefusalTests.theCountAndNameCapsRefuseAtOnePastAndChangeNothing`,
`aFullQuotaRefusesAndWritesNothing`). An older graph file goes through the migration chain and opens; a file without a
migration step is listed as damaged and kept (`MigrationTests.anOldFileMigratesAndOpens`,
`withoutAStepTheOldFileIsListedAsDamagedAndKept`). A damaged or out-of-range snapshot is refused
(`LabCoreTests.theSnapshotRoundTripsAndDamagedSnapshotsAreRefused`). A drawing failure ends the session with a message
and leaves every stored file byte-identical (A23-P06 T-A23-604, `ExperienceTests/LabRecoveryDrawTests.swift`); the
committed samples of A23-P04 (`ExperienceTests/StoredSampleTests.swift`) and A23-P06 (T-A23-605,
`ExperienceTests/ReleaseSampleTests.swift`) prove that every sample opens or is refused as specified and stays
byte-identical.

## No temporary file

Visual Programming Lab writes no temporary file, makes no picture file and exports nothing. The preview's textures
(at most six render targets of 256 × 256 pixels, `GraphCompiler.swift`) are made at run time and live in GPU memory
only; the preview and the canvas are never written to disk.

## What is read

Only the experience's own snapshot, graph files and index above. The experience opens no document picker, its code
never reads the pasteboard, and it reads no photo, document, file or folder outside its storage. It never reads the
photo library.

## How to delete

- **One graph.** In the library, choose Remove on the graph's row and confirm: only this explicit action removes a
  graph file, readable or not (`GraphLibrary.remove`, `LabLibraryView.swift`;
  `LibraryTests.saveOpenRenameAndRemoveRoundTrip`).
- **Visual Programming Lab's data.** In the app's Settings, the data section lists every experience with stored data;
  its reset button for Visual Programming Lab, after a confirmation, removes the experience's folder with `state.json`,
  every `graph-<n>.json` and `library.json` (`Apps/VisualCore/App/SettingsView.swift`, `AppModel.reset(_:)`). The next
  open shows the starter graph (Noise into Output) and an empty library.
- **Everything.** The reset of all data in the same section, or deleting the app, removes every experience's folder,
  Visual Programming Lab's included. The snapshot, the graphs and the index are removed when the app is deleted.

## Permissions

No permission is asked. The registration declares `"permissions": []` (`Catalog/registrations.json`), so no usage
string is needed for it. Visual Programming Lab uses no location, microphone, camera, motion, contacts, photo library
or image picker, and no sensor of any kind.

The screen: Visual Programming Lab never changes the screen's idle timer (it never keeps the screen awake) and never
changes the screen brightness; the system's auto-lock applies as usual.

## No code is run

The person never types code. A graph is made only of the seven known node kinds; it is type-checked, sorted and
refused with its sentence when it has a loop, a wrong connection or more than the limits (32 nodes, 64 connections, six
preview textures), before any pass is compiled or any texture is allocated. Only the operators written in this
repository are compiled.

## What is not done

- **Nothing is sent.** There is no network use, sign-in, analytics or crash reporting by the experience. The snapshot,
  the graphs and the index never leave the device. Nothing is downloaded, and the experience works offline. The
  experience offers no share sheet and its code never touches the pasteboard (the system's own text editing in the
  library's name field works as in any text field).
- **No network, tracking, recording or sensors.** The sources of the experience contain none of the APIs of the spec's
  Clarifications Q3: no networking session or Network import, no position, capture, recording, microphone input,
  motion, contacts, photo-library, Photos picker, advertising-identifier or tracking-transparency API, no idle timer,
  no brightness write, no pasteboard and no share link (check `scan-sources`, T-A23-603:
  `specs/171-vpl-p06-release/scan-sources-release.sh`, `.autonomy/checks/A23-P06.scan-sources.json`). The app tracks
  nothing (`NSPrivacyTracking` false, no tracking domains).
- **Personal text stays local.** The person types only graph names; they stay in the experience's own storage and are
  read by nothing else.

## Required-reason APIs and the app's privacy manifest

The app manifest `Apps/VisualCore/Resources/PrivacyInfo.xcprivacy` declares no tracking, no collected data types and
three accessed-API categories. The experience's uses fall under them; it adds none:

| Category and reason | Use by Visual Programming Lab |
|---|---|
| `NSPrivacyAccessedAPICategoryFileTimestamp`, `C617.1` | `SavedStateStore` reads file attributes (type and size) of the experience's own `state.json`, and `ExperienceStorage` reads the size of the experience's own files when the library lists, reads or writes them; the experience itself reads no file attribute |
| `NSPrivacyAccessedAPICategoryUserDefaults`, `CA92.1` | `ExperienceStorage` holds the app's `UserDefaults` for named values; Visual Programming Lab stores none |
| `NSPrivacyAccessedAPICategorySystemBootTime`, `35F9.1` | Frame times come from the app's render host (`ExperienceSession`); the experience's sources read no boot time |

The built product is checked against this manifest by `release_check.py --only app-release-build
app-privacy-manifest app-no-tracking app-usage-descriptions` ([build-and-archive](../../release/build-and-archive.md);
T-A23-611).

## Credits and license inventory

Consistent with [licenses.md](licenses.md): everything Visual Programming Lab ships is made in code written for this
repository. A person's own graphs are their own work and stay on the device.

| Item | Kind | Source | License |
|---|---|---|---|
| Example graphs Clouds, Soft gradient and Mixed clouds (nodes, parameters, positions and connections) | Code, `VisualProgrammingLab/Experience/LabExamples.swift` | written for this experience (A23-P04) | original (repository LICENSE, MIT) |
| Node kinds Time, Constant, Noise, Gradient, Mix, Blur and Output with their ports and parameter ranges | Names and numbers, `VisualProgrammingLab/Core/NodeLibrary.swift` | written for this experience (A23-P01) | original (repository LICENSE, MIT) |
| Preview operators `noise`, `gradient`, `mix`, `blur` and `output` (GLSL ES 3.00 fragment sources) | Code, `VisualProgrammingLab/Experience/Operators.swift`, over VisualCore's GLSL library `vc/` | written for this experience (A23-P03) | original (repository LICENSE, MIT) |
| Canvas grid (a VisualCore full-screen field pass) | Code, `VisualProgrammingLab/Experience/GridScene.swift` | written for this experience (A23-P02) | original (repository LICENSE, MIT) |
| Graph file `a23.visual-graph`, saved-graph file `a23.saved-graph` and library index `a23.graph-library` formats; the committed test samples | Formats and test resources, `Core/GraphDocument.swift`, `Experience/GraphLibrary.swift`, `ExperienceTests/Fixtures/` | written for this experience (A23-P01, A23-P04, A23-P06) | original (repository LICENSE, MIT) |
| Refusal sentences, status lines and spoken labels | Text, `VisualProgrammingLab/Core/EditMessages.swift`, `Core/GraphCompiler.swift`, `Experience/GraphLibrary.swift` | written for this experience | original (repository LICENSE, MIT) |
| GLSL library `vc/` (hashes, gradient noise, fbm, colour) | Code, `Packages/VisualCoreRendering/Sources/VisualCoreRendering/GLSL/vc/` | VisualCore | original (repository LICENSE, MIT) |
| Text and labels | The system fonts, drawn by SwiftUI; the words in `VisualProgrammingLab/Experience/LabControls.swift`, `CanvasOverlay.swift`, `LabLibraryView.swift` | part of iOS; text written for this experience | nothing bundled; original (repository LICENSE, MIT) |
| The experience's sources (core, adapter, presenter, pipeline, canvas, controls, library) | Code | VisualCore | original (repository LICENSE, MIT) |

- **Visuals.** Made in code only: the preview is the graph's operators drawn through the host's renderer; the canvas
  grid is a field pass; node boxes, ports, wires and controls are native views. No image, stored texture, font file,
  model, sound file or generated asset is bundled, and nothing is downloaded.
- **Code.** The experience depends only on the local packages of VisualCore (`Packages/ExperiencesCreative/Package.swift`);
  it adds no third-party package. The app's third-party components (ANGLE and the libraries inside it, listed in
  `docs/legal/third-party.json`) are bundled under the app's `Licenses` folder, shown in the app's Acknowledgements and
  checked by `app-licenses`.
- **Test samples.** The committed sample files (A23-P04 `graph-sample.json` and those of A23-P06, T-A23-605) are
  resources of the test target only; `scenario-manifest.json` is outside every target's path.
- **ProjectM.** Not used; no engine code, preset format or name of it is in the experience, and ProjectM types stay out
  of the app.
