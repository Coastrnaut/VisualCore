# Interactive Anatomy — privacy and credits

Interactive Anatomy is the experience `a17.interactive-anatomy` of the one VisualCore app (ADR-0009). It has no app
target, Info.plist or privacy manifest of its own: the app's declarations cover it. Feature 129 (A17-P06), FR-A17-601
and FR-A17-602. Sources: `Packages/ExperiencesCreative/InteractiveAnatomy` (below: IA).

Interactive Anatomy is educational, not medical. Its model is a schematic model for learning, its shapes are
simplified, and its text is not reviewed by a clinician ([review.md](review.md)).

## What is stored on the device

The saved view lives in the experience's own storage folder, `Application Support/Experiences/a17.interactive-anatomy/`,
and is written through `ExperienceStorage.write` (atomic replace: a reader sees the complete old or the complete new
file).

| What | Where | Written by | Content |
|---|---|---|---|
| The saved view | `view.json` in the experience's storage folder | `IA/Experience/AnatomyPresenter.swift` (`noteView`), after each change of the view; the file is replaced each time, so there is only ever one | One document envelope (`IA/Core/AnatomyViewDocument.swift`: kind `a17.view`, schema version, the time it was saved, sorted keys) whose payload is the view state (`IA/Core/AnatomyViewState.swift`, schema 2): the camera steps (turn, tilt, zoom), which of the three layers are shown, the selected part, the framed part and the isolate (a part or a layer, ghost or hide mode). Nothing else: no name, no text the person types, no device data, no location |
| Saved session state | `state.json` in the same folder | the app (`SavedStateStore` in `Packages/VisualCore`, used by `Apps/VisualCore/App/AppModel.swift`), not the experience | The session snapshot of the core (`IA/Experience/Adapter/AnatomyCore.swift`, `snapshotPayload()`): the same view state as `view.json` |

Nothing else is persisted by the experience. The content pack (`IA/Core/Content/knee-right.pack.json`), the review
record (`IA/Core/Content/knee-right.review.json`) and the geometry are part of the app bundle and are never written.

Opening never rewrites a stored file: a `view.json` that is damaged, of a newer schema, of another kind or larger than
65,536 bytes is refused, counted and left as it is, and the opening view opens
(`AnatomyViewFileTests.testDamagedNewerForeignAndOversizedFilesLeaveTheOpeningView`). A schema 1 view (A17-P02) opens
migrated (`AnatomyViewFileTests.testASchemaOneFileOpensMigrated`); an unknown part id in the file is dropped and the
rest is kept (`AnatomyViewFileTests.testAnUnknownIdInTheFileIsDroppedAndTheRestIsKept`). A write that fails is counted
and the session keeps running (`AnatomyViewFileTests.testARefusedWriteIsCountedAndTheSessionKeepsRunning`). A saved
view reopens in a new session (`AnatomyViewFileTests.testAcceptedActionsWriteTheFileAndANewSessionOpensWithIt`;
`AnatomySessionTests.testTheSavedStateRestoresInANewSession`).

## What is read

Only the experience's own files above and its bundled resources (the content pack and the review record). The
experience opens no document picker and reads no photo, document, file or folder outside its storage.

## How to delete

- **The saved view.** `view.json` always holds only the current view, so nothing older is kept. Every change of the
  view (a layer toggle, a selection, a camera step, Reset view, an isolate or Show all) replaces it.
- **Interactive Anatomy's data.** In the app's Settings, the data section lists every experience with stored data; its
  reset button for Interactive Anatomy, after a confirmation, removes the experience's folder with `view.json` and the
  saved session state (`Apps/VisualCore/App/SettingsView.swift`, `AppModel.reset(_:)` with `ResetPlan.experience`).
- **Everything.** The reset of all data in the same section, or deleting the app, removes every experience's folder,
  Interactive Anatomy's `view.json` and saved session state included.

## Permissions

Interactive Anatomy requests no permission and adds no usage-description string (FR-A17-602). Its registration
declares no permission (`"permissions": []` in `Catalog/registrations.json`). The experience uses no sensor: no
motion, location, contacts, photo library, image picker, microphone or photo and video capture. It plays no sound and
gives no haptic. Its only system call outside drawing is a VoiceOver announcement of a selection change, posted only
while VoiceOver is running (`AnatomyPresenter`, `UIAccessibility.post`).

## What is not done

- **Nothing is sent.** There is no upload, sync, sign-in, analytics or crash reporting by the experience. The saved
  view never leaves the device. The content is bundled with the app; nothing is downloaded.
- **No network, tracking, recording or sensors.** The sources of the experience contain no `URLSession`,
  `import Network`, `CLLocation`, `AVCapture`, `AVAudioRecorder`, `inputNode`, `installTap`, `CMMotion`, `CNContact`,
  `PHPhotoLibrary`, `UIImagePickerController`, `ASIdentifierManager` or `AppTrackingTransparency` (check
  `ia-no-network`, T-A17-603: `specs/129-ia-p06-release/scan-sources-release.sh`,
  `.autonomy/checks/A17-P06.ia-no-network.json`; and the package test
  `NoNetworkTests.noInteractiveAnatomySourceUsesTheNetwork`, which refuses networking types, a Network import and
  web addresses in `IA/Core` and `IA/Experience`). The app tracks nothing (`NSPrivacyTracking` false, no tracking
  domains).
- **No change to the system screen.** The experience never sets the system screen brightness
  (`UIScreen.main.brightness`) and never disables the idle timer (`isIdleTimerDisabled`) (the same scan).
- **No personal data.** The person types only search queries, which are not stored.
- **No patient data.** The experience holds no patient file and no health record; it is a reference of one region.

## Required-reason APIs and the app's privacy manifest

The app manifest `Apps/VisualCore/Resources/PrivacyInfo.xcprivacy` declares no tracking, no collected data types and
three accessed-API categories. The experience's uses fall under them; it adds none:

| Category and reason | Use by Interactive Anatomy |
|---|---|
| `NSPrivacyAccessedAPICategoryFileTimestamp`, `C617.1` | `ExperienceStorage` reads file attributes (type and size) of the experience's own `view.json` when it is read or written |
| `NSPrivacyAccessedAPICategoryUserDefaults`, `CA92.1` | `ExperienceStorage` holds the app's `UserDefaults` for named values under the experience's prefix; Interactive Anatomy stores none |
| `NSPrivacyAccessedAPICategorySystemBootTime`, `35F9.1` | Frame times come from the app's render host (`ExperienceSession`); the experience's sources read no boot time. Elapsed time inside the app only |

The built product is checked against this manifest by `release_check.py --only app-release-build
app-privacy-manifest app-no-tracking app-usage-descriptions` ([build-and-archive](../../release/build-and-archive.md);
T-A17-611).

## Credits and license inventory

| Item | Kind | Source | License |
|---|---|---|---|
| Content pack `knee-right.pack.json` (schema 2, content version 2): 14 parts of the right knee with their names, synonyms, layers, descriptions and citations | Bundled resource, `IA/Core/Content/` | Sections of Gray's Anatomy, *Anatomy of the Human Body*, 20th edition (1918): Osteology (the femur, tibia, fibula and patella), Syndesmology (the knee-joint), Myology (the quadriceps femoris) | public-domain (cited by section; no text copied) |
| Standard names of the 14 parts | Facts in the content pack | Terminologia Anatomica (1998), lower limb | facts (terms, not copyrightable text) |
| The descriptions of the 14 parts | Text in the content pack | Interactive Anatomy descriptions, written for this experience | original |
| Review record `knee-right.review.json` (content version 2): one editorial entry per part, no clinical entry | Bundled resource, `IA/Core/Content/` | VisualCore (written for this experience) | original |
| Procedural geometry: every mesh (revolution, tube, extrusion and sphere kinds) built at run time from code | Code, `IA/Core/AnatomyGeometry.swift`, `AnatomyScene.swift`; VisualCore's procedural generators | VisualCore (original code); geometry license `original` in the content pack | original (repository LICENSE, MIT) |
| Layer colours: bones `#E6DBC2`, cartilage and menisci `#8CB3D9`, ligaments and tendons `#CC7373`, with the signs ●, ◆ and ▲; the selection in amber; ghosts at alpha 0.25; the dark backdrop | Colours, `IA/Core/AnatomyLayerSign.swift`, `IA/Experience/AnatomyPresenter.swift` | VisualCore (original code) | original |
| The experience's sources (content model and validation, search, picker, camera, isolate, labels, panel, review words, presenter, controls, gestures, overlay, adapter) | Code | VisualCore | original (repository LICENSE, MIT) |

- **What the content is.** Every part cites the Gray section where it is described, `ta-1998` for its standard name
  and `original-descriptions` for its description ([content-sources.md](content-sources.md)). The content validator
  `AnatomyContent.validate` refuses any source whose license is not `public-domain`, `facts` or `original`
  (`ContentValidationTests.badLicensesAreRefused`), and every part's provenance is complete
  (`ProvenanceTests.theBundledProvenanceIsComplete`). No modern atlas, textbook, website or image is used, quoted or
  traced. Descriptions state form, position and connections only; the validator refuses clinical text (reason
  `clinical-text`; `ContentValidationTests.clinicalTextIsRefused`).
- **Review.** The lead engineer checked the text of each part against its cited sources on 2026-11-16 (an editorial
  check, not a clinical review). No clinician has reviewed it, so every part shows "Not reviewed by a clinician."
  (`ReviewRecordTests.theBundledRecordHasOneEditorialEntryPerPartAndNoClinicalEntry`; [review.md](review.md)).
- **Visuals.** Drawn by code only: every structure is procedural geometry, labelled "Schematic model for learning;
  shapes are simplified.", drawn through the host's renderer (VisualCore's `DepthMeshPass` and `MeshRenderer`); the
  labels, the list and the panel are native text. No purchased, generated, scanned or hand-modelled mesh and no image,
  texture, photograph, font or data file from a third party is bundled.
- **Sound.** None.
- **Code.** The experience depends only on the local packages `Packages/VisualCore` and `Packages/VisualCoreRendering`
  (`Packages/ExperiencesCreative/Package.swift`); it adds no third-party package. The app's third-party components
  (ANGLE and the libraries inside it, listed in `docs/legal/third-party.json`) are bundled under the app's `Licenses`
  folder, shown in the app's Acknowledgements and checked by `app-licenses`.
- **Test samples.** The committed sample view files of A17-P06 (T-A17-605) are resources of the test target only;
  `scenario-manifest.json` is outside every target's path.
- **ProjectM.** Not used; no engine code, preset format or name of it is in the experience, and ProjectM types stay out
  of the app.
