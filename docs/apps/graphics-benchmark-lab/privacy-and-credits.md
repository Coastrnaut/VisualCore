# Graphics Benchmark Lab — privacy and credits

Graphics Benchmark Lab is the experience `a24.graphics-benchmark-lab` of the one VisualCore app (ADR-0009). It has no
app target, Info.plist or privacy manifest of its own: the app's declarations cover it. Feature 178 (A24-P06),
FR-A24-601 and FR-A24-602. Sources: `Packages/ExperiencesCreative/GraphicsBenchmarkLab` (below: GBL).

Graphics Benchmark Lab runs three built-in GPU workloads (Textured quads, Shader ALU and Particles) through a warm-up,
a measurement and a cool-down phase, shows the frame interval, the presenter CPU time and, where the device offers a
GPU timer, the GPU time of the measured frames, qualifies each run as valid, qualified or invalid, keeps saved results
on the device, compares comparable trials, and explains its limits in "About these numbers". It writes only the files
below. Nothing is sent automatically: a result leaves the device only through the system share sheet that the person
opens after tapping Export.

## What is stored on the device

Every stored item except the export files lives in the experience's own storage: the folder
`Application Support/Experiences/a24.graphics-benchmark-lab/` of the experience (`ExperienceStorage`, bounded by
`StorageQuota`: at most 64 files and 16 MiB together). Every file is written atomically (a reader sees the complete old
or the complete new file; a failed write keeps the previous file). Graphics Benchmark Lab stores no named value under
its defaults prefix.

| What | Where | Written by, and when | Content |
|---|---|---|---|
| Saved session state (the snapshot) | `state.json` in the experience's storage folder | the app (`SavedStateStore` in `Packages/VisualCore`, the session's snapshot sink in `Apps/VisualCore/App/AppModel.swift`), not the experience, at every suspension and close of the session; the file is replaced each time | The core's snapshot, schema 1 (`GraphicsBenchmarkLab/Experience/Adapter/BenchCore.swift`, digest domain `a24.graphics-benchmark-lab.v1`): the JSON object `{"selectedCase", "startRequests", "stopRequests"}` with sorted keys: the index of the selected case (0…2) and the start and stop request counters. The digest covers the selected case only. A restored snapshot never resumes a run. There is no name, no device data and no measurement in it |
| A saved result | `result-<n>.json` in the experience's storage folder (n is a counter, never reused while the index or a higher file exists) | `GraphicsBenchmarkLab/Experience/ResultLibrary.swift`, only when the person taps Save result after a run ended | One envelope of kind `a24.saved-result`, version 1, at most 2,162,688 bytes: the save order and the run (the run file of kind `a24.benchmark-run`, schema 3, at most 2,097,152 bytes, embedded as a JSON object): the case with its settings and plan, how the run ended, the frame samples of the run, the summary and the run's report (the device facts below) |
| The results index | `results.json` in the experience's storage folder | `ResultLibrary.swift`, after a save or a removal | One envelope of kind `a24.result-library`, version 1: the next counter and, for each result file, its file name and order |
| An export of a saved result | `Benchmark <case title> <order>.json` or `.csv` in the temporary folder `GraphicsBenchmarkLab-Export` (`TemporaryFolder` in the app's temporary directory), not in the experience's storage | `GraphicsBenchmarkLab/Experience/ResultExportFile.swift` (`ResultExporter`), only when the person taps Export JSON or Export CSV on an opened result | The run file itself (`RunDocument.encode`, version 3, sorted keys) or the CSV of the run (`RunCSV.text(of:)`, UTF-8). It is handed to the share sheet only when the person taps it (`ShareLink` in `Experience/ResultsView.swift`) |

The library holds at most 12 results (unreadable files count, as they hold storage). The three cases, their settings
and plans (`Core/BenchmarkCase.swift`), the workload shaders and the explanation's text are code in the app bundle and
are never written. The qualification of a run is computed when it is shown, never stored.

Opening never rewrites a stored file. A result file that is damaged, of a newer version, too large or whose embedded
run is refused (`damaged`, `newer-version`, `too-large`, or the run file's own code such as `not-finite`,
`out-of-range`, `out-of-order` or `too-many-samples`) is listed as unreadable with its code and is never opened or
removed automatically (`ResultLibraryTests.unreadableFilesAreListedWithTheirReasonAndKept`). An index of a newer
version makes the library read only, so a newer build's index is never overwritten; a damaged index is rebuilt by the
next change, never by reading (`ResultLibraryTests.aNewerIndexIsReadOnlyAndADamagedIndexIsRebuiltOnlyByAChange`). A
13th save or a full storage quota is refused with its message and changes nothing
(`ResultLibraryTests.theThirteenthSaveIsRefusedAndNothingChanges`, `aFullStorageRefusesWithTheMessageAndWritesNothing`).
An older run file goes through the migration chain and opens (`RunDocumentTests.migrationChainEndsAtVersionThree`,
`versionOneOpensWithoutReport`). A damaged or out-of-range snapshot is refused
(`BenchCoreTests.damagedAndOutOfRangeSnapshotsAreRefused`). A drawing failure ends the session with a message and
leaves every stored file byte-identical, and a new session lists and opens the results (A24-P06 T-A24-604,
`ExperienceTests/BenchRecoveryDrawTests.swift`); the committed samples of A24-P06 (T-A24-605,
`ExperienceTests/ReleaseSampleTests.swift`) prove that every sample opens or is refused as specified and stays
byte-identical.

## The export files

An export is written only on the person's tap of Export JSON or Export CSV, into the temporary folder
`GraphicsBenchmarkLab-Export`; the experience never writes one by itself. The folder is emptied when the session closes
(the presenter's `teardown`) and when the experience opens again (the presenter's start, which clears what a killed
session left behind) (`ExportTests.theActionAloneWritesTheJSONAndCSVFiles`,
`closingTheSessionEmptiesTheExportFolder`). The share item carries the content type of its format (JSON or
comma-separated text) and sends the written file itself (`ExportTests.theShareItemCarriesTheContentTypeOfItsFormat`).
Where the file goes after that is the person's choice in the system share sheet.

## What is read

Only the experience's own snapshot, result files and index above. The experience opens no document picker, its code
never reads the pasteboard, and it reads no photo, document, file or folder outside its storage and its export
folder. It never reads the photo library.

The report of a run reads device facts from public APIs only (`Experience/ReportSource.swift`):

- the model identifier: the `utsname` machine identifier, a model name such as "iPhone17,1" that is not unique to a
  device (on the simulator, the simulator's `SIMULATOR_MODEL_IDENTIFIER` environment value);
- the OS version: `ProcessInfo.operatingSystemVersion`;
- the app version and build: the main bundle's `CFBundleShortVersionString` and `CFBundleVersion`;
- the renderer and GL version strings of the drawing context, and the quality tier;
- the thermal state ("nominal", "fair", "serious" or "critical") and Low Power Mode at the start and the end of the
  run.

No vendor or advertising identifier and not the device's name is read; no private framework and no dynamic loading is
used (`ReportTests.aFinishedRunCarriesAValidReportWithEveryFieldFilled`,
`theSourceFillsEmptyStringsAndCutsLongOnes`). The report is kept only inside a saved result or an export the person
makes.

## How to delete

- **One result.** In the saved results, choose Remove on the result's row: only this explicit action removes a result
  file, readable or not (`ResultLibrary.remove`, `ResultsView.swift`;
  `ResultLibraryTests.aRemovalDeletesOnlyTheChosenFile`).
- **The exports.** They are removed when the session closes and when the experience opens again (above).
- **Graphics Benchmark Lab's data.** In the app's Settings, the data section lists every experience with stored data;
  its reset button for Graphics Benchmark Lab, after a confirmation, removes the experience's folder with
  `state.json`, every `result-<n>.json` and `results.json` (`Apps/VisualCore/App/SettingsView.swift`,
  `AppModel.reset(_:)`). The next open selects Textured quads and shows no saved result.
- **Everything.** The reset of all data in the same section, or deleting the app, removes every experience's folder,
  Graphics Benchmark Lab's included. The snapshot, the results, the index and the temporary folder are removed when the
  app is deleted.

## Permissions

No permission is asked. The registration declares `"permissions": []` (`Catalog/registrations.json`), so no usage
string is needed for it; the system share sheet needs none. Graphics Benchmark Lab uses no location, microphone,
camera, motion, contacts, photo library or image picker, and no sensor of any kind.

The screen: Graphics Benchmark Lab never changes the screen's idle timer (it never keeps the screen awake) and never
changes the screen brightness; the system's auto-lock applies as usual. A serious or critical thermal state ends a run
as interrupted before the next frame is drawn, so the lab never keeps a hot device busy
(`ThermalStopTests.aSeriousOrCriticalThermalStateStopsTheRun`).

## What is not done

- **Nothing is sent automatically.** There is no network use, sign-in, analytics or crash reporting by the experience.
  The snapshot, the results and the index never leave the device by themselves. A result leaves the device only as an
  export file through the system share sheet that the person opens on an opened result. Nothing is downloaded, and the
  experience works offline. The experience's code never touches the pasteboard.
- **No network, tracking, recording or sensors.** The sources of the experience contain none of the APIs of the spec's
  Clarifications Q3: no networking session or Network import, no position, capture, recording, microphone input,
  motion, contacts, photo-library, Photos picker, advertising-identifier, vendor-identifier, device-name or
  tracking-transparency API, no idle timer, no brightness write, no pasteboard, and the share link appears only in
  `Experience/ResultsView.swift` (check `scan-sources`, T-A24-603: `specs/178-gbl-p06-release/scan-sources-release.sh`,
  `.autonomy/checks/A24-P06.scan-sources.json`). The app tracks nothing (`NSPrivacyTracking` false, no tracking
  domains).
- **No ranking and no comparison.** The lab does not rank devices, gives no overall figure and compares a result only
  with trials of the same case fingerprint, device model, OS version, app build and quality tier on the same device's
  saved results.

## Required-reason APIs and the app's privacy manifest

The app manifest `Apps/VisualCore/Resources/PrivacyInfo.xcprivacy` declares no tracking, no collected data types and
three accessed-API categories. The experience's uses fall under them; it adds none:

| Category and reason | Use by Graphics Benchmark Lab |
|---|---|
| `NSPrivacyAccessedAPICategoryFileTimestamp`, `C617.1` | `SavedStateStore` reads file attributes (type and size) of the experience's own `state.json`, and `ExperienceStorage` reads the size of the experience's own files when the library lists, reads or writes them; the experience itself reads no file attribute |
| `NSPrivacyAccessedAPICategoryUserDefaults`, `CA92.1` | `ExperienceStorage` holds the app's `UserDefaults` for named values; Graphics Benchmark Lab stores none |
| `NSPrivacyAccessedAPICategorySystemBootTime`, `35F9.1` | Frame times come from the app's render host (`ExperienceSession`); the presenter times its own draw with Swift's `ContinuousClock` (elapsed time between two events on the device) and the experience's sources read no boot time |

The built product is checked against this manifest by `release_check.py --only app-release-build
app-privacy-manifest app-no-tracking app-usage-descriptions` ([build-and-archive](../../release/build-and-archive.md);
T-A24-611).

## Credits and license inventory

Consistent with [licenses.md](licenses.md): everything Graphics Benchmark Lab ships is made in code written for this
repository. A person's own results are their own and stay on the device unless the person exports them.

| Item | Kind | Source | License |
|---|---|---|---|
| Benchmark cases Textured quads, Shader ALU and Particles (settings, versions and plans) | Names and numbers, `GraphicsBenchmarkLab/Core/BenchmarkCase.swift` | written for this experience (A24-P01) | original (repository LICENSE, MIT) |
| Workload pictures: the code-made texture (a checker of 16 cells mixed with VisualCore's value noise) and its layered field passes, the shader ALU field pass, the instanced particles | Code, `GraphicsBenchmarkLab/Experience/Workloads.swift`, `Core/ParticleField.swift`, over VisualCore's GLSL library `vc/` and `ParticleRenderer` | written for this experience (A24-P02) | original (repository LICENSE, MIT) |
| Run file `a24.benchmark-run`, saved-result file `a24.saved-result`, results index `a24.result-library` and CSV formats; the committed test samples | Formats and test resources, `Core/BenchmarkRun.swift`, `Core/RunCSV.swift`, `Experience/ResultLibrary.swift`, `CoreTests/Fixtures/`, `ExperienceTests/Fixtures/` | written for this experience (A24-P01, A24-P03, A24-P04, A24-P06) | original (repository LICENSE, MIT) |
| Statistics, qualification and repeatability rules | Code, `Core/Statistics.swift`, `Core/RunQualification.swift`, `Core/Repeatability.swift` | written for this experience (A24-P01, A24-P05) | original (repository LICENSE, MIT) |
| Status lines, sentences, spoken labels and "About these numbers" | Text, `Experience/BenchPresenter.swift`, `Experience/GBLExplanation.swift`, `Experience/ResultsView.swift`, `Experience/RepeatabilityView.swift` | written for this experience | original (repository LICENSE, MIT) |
| GLSL library `vc/` (hashes, value noise, colour) | Code, `Packages/VisualCoreRendering/Sources/VisualCoreRendering/GLSL/vc/` | VisualCore | original (repository LICENSE, MIT) |
| GPU timer over `GL_EXT_disjoint_timer_query` | Code, `GPUFrameTimer` in `Packages/VisualCoreRendering` | VisualCore | original (repository LICENSE, MIT) |
| Text and labels | The system fonts, drawn by SwiftUI; the words in `GraphicsBenchmarkLab/Experience/GBLControls.swift`, `ResultsView.swift`, `RepeatabilityView.swift`, `ExplanationView.swift` | part of iOS; text written for this experience | nothing bundled; original (repository LICENSE, MIT) |
| The experience's sources (core, adapter, presenter, recorder, workloads, library, export, views) | Code | VisualCore | original (repository LICENSE, MIT) |

- **Visuals.** Made in code only: every workload picture (the textured quads with a texture made in code, the shader
  ALU pass and the instanced particles) is drawn through the host's renderer; the controls, results and explanation
  are native views. No image, stored texture, font file, model, sound file or generated asset is bundled, and nothing
  is downloaded.
- **Code.** The experience depends only on the local packages of VisualCore
  (`Packages/ExperiencesCreative/Package.swift`); it adds no third-party package. The app's third-party components
  (ANGLE and the libraries inside it, listed in `docs/legal/third-party.json`) are bundled under the app's `Licenses`
  folder, shown in the app's Acknowledgements and checked by `app-licenses`.
- **Test samples.** The committed sample files (`CoreTests/Fixtures/` and those of A24-P06 in
  `ExperienceTests/Fixtures/`, T-A24-605) are resources of the test targets only; `scenario-manifest.json` is outside
  every target's path.
- **Other tools.** No code, number or name of another benchmark tool is used or compared with.
- **ProjectM.** Not used; no engine code, preset format or name of it is in the experience, and ProjectM types stay out
  of the app.
