# Molecular Explorer — privacy and credits

Molecular Explorer is the experience `a15.molecular-explorer` of the one VisualCore app (ADR-0009). It has no app
target, Info.plist or privacy manifest of its own: the app's declarations cover it. Feature 115 (A15-P06), FR-A15-601
and FR-A15-604 (research D1). Sources: `Packages/ExperiencesCreative/MolecularExplorer` (below: ME).

## What is stored on the device

All four files live in the experience's own storage folder,
`Application Support/Experiences/a15.molecular-explorer/`, and are written through `ExperienceStorage.write` (atomic
replace: a reader sees the complete old or the complete new file).

| What | Where | Written by | Content |
|---|---|---|---|
| Recent molecules | `recent.json` | `ME/Experience/RecentStore.swift`, whenever the person opens a different molecule | One `RecentMolecules` document (`ME/Core/RecentMolecules.swift`; file schema 1, sorted keys, at most 2,048 bytes): the ids of at most eight recently opened molecules, newest first (`water` … `caffeine`, and `imported` for the imported molecule). No name of a person, no device data, no location and no address |
| Visual settings | `settings.json` | `ME/Experience/SettingsStore.swift`, when the person changes the Labels picker | One `MoleculeSettings` document (`ME/Core/MoleculeSettings.swift`; file schema 1, sorted keys, at most 1,024 bytes): the label mode (all, selected or none) |
| The imported copy | `import.xyz` | `ME/Experience/MoleculeImporter.swift`, only once the engine accepted every atom of a file the person picked | The bytes of that one XYZ file (at most 65,536 bytes, at most 500 atoms of the ten catalog elements); a later import replaces it, so there is only ever one |
| The imported copy's title | `import-title.txt` | `MoleculeImporter`, together with `import.xyz` | The title made from the picked file's name: its extension dropped, only letters, digits, spaces and `-_.()` kept, at most 40 characters, or "Imported molecule" (`MoleculeImport.title(fileName:)`). The comment line inside the file is never used as a title |
| Saved session state | `state.json` in the same folder | the app (`SavedStateStore`, `Apps/VisualCore/App/AppModel.swift`), not the experience | The session snapshot of the core (`MoleculeCore`, `MoleculeState` schema 4): the selected molecule, the display mode, the camera's turn, tilt, zoom and pan, the selected atom and, when there is one, the imported molecule's atoms (element and x, y, z in ångström), so that the experience reopens where it was. Snapshots of schemas 1 to 3 migrate to schema 4 (`MoleculeCoreTests.testTheMigrationStepsTurnSchemaOneAndTwoIntoSchemaFour`, `MoleculeStateSchema4Tests.olderSchemasMigrateWithNoImport`) |

Nothing else is persisted by the experience. The five library molecules, the ten elements and their source records are
part of the code (`MoleculeLibrary`, `MoleculeLibraryData`, `Elements`, `SourceRecord`) and are never written. Its
sources write no named defaults values (`ExperienceStorage.setValue` is not called), no other files and no
`UserDefaults` values. Loading never writes: with no `recent.json` the Recent menu says "No recent molecules", with no
`settings.json` labels are shown for all atoms (`SettingsStoreTests.testNoFileGivesLabelsForAllAtomsAndWritesNothing`);
a file that is damaged, too large, of a newer schema or holds a value outside its range is refused with its reason
(`damaged`, `oversized`, `newer-version`, `out-of-range`), the defaults are used and the file is left byte for byte as
it was until the next change replaces it (`RecentStoreTests.testRefusedFilesStayByteIdenticalWithTheirMessages`,
`SettingsStoreTests.testRefusedFilesStayByteIdenticalWithTheirMessages`). Ids outside the library are dropped when the
list is read (`RecentStoreTests.testIdsOutsideTheLibraryAreDroppedOnRead`). A refused write keeps the previous file
(`RecentStoreTests.testAFailedWriteKeepsThePreviousFile`, `SettingsStoreTests.testAFailedWriteKeepsThePreviousFile`); a
refused write of the imported copy still opens the molecule and says it could not be kept
(`MoleculeImportSessionTests.testARefusedCopyWriteStillImportsWithItsMessage`). A missing or damaged stored copy keeps
the saved molecule and drops the unavailable Recent entry
(`MoleculeImportSessionTests.testAMissingOrDamagedCopyKeepsTheSavedMoleculeAndAnUnavailableEntryIsDropped`). A saved
state of a newer schema or with damaged content is refused and water opens
(`MoleculeSessionTests.testANewerSavedStateIsRefusedAndWaterOpens`, `testADamagedSavedStateIsRefusedAndWaterOpens`).
The recent list and the settings live outside the engine state, so they never change a state digest or a replay
(`RecentStoreTests.testTheEngineDigestIsTheSameWithAndWithoutStorage`).

## What is read

Only the file the person picks in the system document picker (the Import XYZ file button, `.fileImporter` in
`ME/Experience/MoleculeControls.swift`, one `.xyz` or plain-text file) is read, once, under the security-scoped access
the picker grants, which is stopped again as soon as the bytes are read. Its size is checked first and a file above
65,536 bytes is refused without being read (`MoleculeImportSessionTests.testAnOversizedFileIsRefusedWithoutBeingRead`).
The bytes are parsed by the strict, bounded `XYZParser`; a refused file changes nothing and nothing is written
(`MoleculeImportSessionTests.testEachRefusalShowsItsSentenceAndChangesNothing`). An accepted file is copied as
`import.xyz`; the original is never written, moved or read again. No other file, folder, photo or document is read,
and a cancelled picker does nothing. Importing works only while the experience is active
(`MoleculeImportSessionTests.testAnImportWhileNotActiveChangesNothing`).

## How to delete

- **The imported copy.** Importing another file replaces `import.xyz` and `import-title.txt`; there is only ever one
  imported molecule.
- **Molecular Explorer's data.** In the app's Settings, the data section lists every experience with stored data; its
  reset button for Molecular Explorer, after a confirmation, removes the experience's folder with `recent.json`,
  `settings.json`, `import.xyz`, `import-title.txt` and the saved session state
  (`Apps/VisualCore/App/SettingsView.swift`, `AppModel.reset(_:)` with `ResetPlan.experience`). The next opening
  shows water with labels for all atoms, an empty Recent menu and no imported molecule
  (`RecentStoreTests.testRemovingTheFolderGivesAnEmptyList`, `SettingsStoreTests.testRemovingTheFolderGivesTheDefault`).
- **Everything.** The reset of all data in the same section, or removing the app, removes every experience's folder,
  Molecular Explorer's files and saved session state included.

## Permissions

Molecular Explorer requests no permission and adds no usage string (FR-A15-601). Its registration declares no
permission (`"permissions": []` in `Catalog/registrations.json`). The system document picker needs no permission: the
person chooses the file, and the app receives access to that file only. The experience uses no sensor: no motion,
location, contacts, photo library, image picker, microphone or device camera. The "camera" of the 3D view is a
virtual viewpoint that the controls and gestures turn, tilt, zoom and pan. It plays no sound and gives no haptic.

## What is not done

- **Nothing is sent.** There is no upload, sync, sign-in, user account, analytics or crash reporting by the
  experience. The recent list, the settings and the imported copy never leave the device; there is no export.
- **No network, tracking, recording or sensors.** The sources of the experience contain no `URLSession`,
  `import Network`, `CLLocation`, `AVCapture`, `AVAudioRecorder`, `inputNode`, `installTap`, `CMMotion`, `CNContact`,
  `PHPhotoLibrary`, `UIImagePickerController`, `ASIdentifierManager` or `AppTrackingTransparency` (check
  `me-no-network`, T-A15-603: `specs/115-me-p06-release/scan-sources-release.sh`,
  `.autonomy/checks/A15-P06.me-no-network.json`). The app tracks nothing (`NSPrivacyTracking` false, no tracking
  domains).
- **No change to the system screen.** The experience never sets the system screen brightness
  (`UIScreen.main.brightness`) and never disables the idle timer (`isIdleTimerDisabled`) (the same scan).
- **No personal data.** The person types nothing. The imported file is the person's own data; the experience keeps
  only its copy and a title made from its file name, and the file's comment line is never shown as a title.

## Required-reason APIs and the app's privacy manifest

The app manifest `Apps/VisualCore/Resources/PrivacyInfo.xcprivacy` declares no tracking, no collected data types and
three accessed-API categories. The experience's uses fall under them; it adds none:

| Category and reason | Use by Molecular Explorer |
|---|---|
| `NSPrivacyAccessedAPICategoryFileTimestamp`, `C617.1` | `ExperienceStorage` reads file attributes (type and size) of the experience's own `recent.json`, `settings.json`, `import.xyz` and `import-title.txt` when they are read or written. The size of the picked file is read from its `fileSizeKey` resource value, not a timestamp |
| `NSPrivacyAccessedAPICategoryUserDefaults`, `CA92.1` | `ExperienceStorage` holds the app's `UserDefaults` for named values under the prefix `exp.a15.molecular-explorer.`; Molecular Explorer stores none |
| `NSPrivacyAccessedAPICategorySystemBootTime`, `35F9.1` | Frame times come from the app's render host (`ExperienceSession`); the experience's sources read no boot time. Elapsed time inside the app only |

The built product is checked against this manifest by `release_check.py --only app-release-build
app-privacy-manifest app-no-tracking app-usage-descriptions` ([build-and-archive](../../release/build-and-archive.md);
T-A15-612).

## Credits

Every value Molecular Explorer shows comes from the sources below. The full tables with value, units, source and
license per value are [data-sources.md](data-sources.md), generated from `Elements` and `MoleculeLibrary` by
`ElementAudit.markdown()` and checked against them by `ElementAuditTests.theCommittedDataSourcesDocumentMatchesTheData`
(10 elements, 50 element source records, 5 molecules; 0 problems; allowed licenses `public-domain`, `CC0-1.0` and
`factual-data`), and [data-review.md](data-review.md), generated by `MoleculeReview.document()` and checked by
`MoleculeReviewTests.theCommittedDataReviewMatchesTheData`.

| Source | Publisher | Used for | License |
|---|---|---|---|
| PubChem Compound CID 962, 3D conformer, pubchem.ncbi.nlm.nih.gov/compound/962 | National Library of Medicine (NCBI) | The structure of water (H2O; 3 atoms, 2 bonds; coordinates in Å) | public-domain |
| PubChem Compound CID 297, 3D conformer, pubchem.ncbi.nlm.nih.gov/compound/297 | National Library of Medicine (NCBI) | The structure of methane (CH4; 5 atoms, 4 bonds) | public-domain |
| PubChem Compound CID 702, 3D conformer, pubchem.ncbi.nlm.nih.gov/compound/702 | National Library of Medicine (NCBI) | The structure of ethanol (C2H6O; 9 atoms, 8 bonds) | public-domain |
| PubChem Compound CID 241, 3D conformer, pubchem.ncbi.nlm.nih.gov/compound/241 | National Library of Medicine (NCBI) | The structure of benzene (C6H6; 12 atoms, 12 bonds) | public-domain |
| PubChem Compound CID 2519, 3D conformer, pubchem.ncbi.nlm.nih.gov/compound/2519 | National Library of Medicine (NCBI) | The structure of caffeine (C8H10N4O2; 24 atoms, 25 bonds) | public-domain |
| PubChem Periodic Table of Elements, pubchem.ncbi.nlm.nih.gov/periodic-table | National Library of Medicine (NCBI) | The name, atomic number, van der Waals radius (Å) and display colour of H, C, N, O, F, P, S, Cl, Br and I | public-domain |
| Covalent radii revisited (B. Cordero et al., Dalton Transactions, 2008), doi.org/10.1039/b801115j | Royal Society of Chemistry | The covalent radius (Å) of H, C, N, O, F, P, S, Cl, Br and I, which sizes the atoms in ball and stick and infers the bonds of an imported file | factual-data |

- **What the values are.** The structures are illustrative models from the recorded PubChem 3D conformers; the radii
  and colours are display conventions with their source ("Display radii, not measured sizes."). Bonds of an imported
  file are estimated from atom distances and marked inferred ("Bonds marked inferred are estimated from atom
  distances."). The experience makes no chemical safety, toxicity or medical statement.
- **Imported molecules.** An imported molecule is the person's own data: its source reads "imported file", publisher
  "your own file", license `own-data` ("your own data"). Nothing of it is bundled.
- **Visuals.** Drawn by code only: the atoms are one procedural unit sphere and the bonds one procedural unit stick,
  scaled and placed per atom and bond and coloured per element, drawn at run time through the host's renderer; the
  labels and the selection ring are native overlay text and shapes. No image, texture, photograph, model, font or data
  file from a third party is bundled.
- **Sound.** None.
- **Code.** The experience's sources (element catalog, source records, element audit, strict XYZ parser, bond
  inference, molecule domain and library, display modes, scene, picking, label layout, camera settings, recent list,
  settings, import, review, presenter, controls, gestures and overlay) are this repository's own code. The experience
  depends only on the local packages `Packages/VisualCore` and `Packages/VisualCoreRendering`
  (`Packages/ExperiencesCreative/Package.swift`); it adds no third-party package. The app's third-party components
  (ANGLE and the libraries inside it, listed in `docs/legal/third-party.json`) are bundled under the app's `Licenses`
  folder, shown in the app's Acknowledgements and checked by `app-licenses`.
- **No third-party content.** Apart from the public-domain and factual values above, no picture, sound, text or code
  from outside the project is in the experience.
- **Test samples.** The committed sample recent, settings and import files of A15-P06 (T-A15-605) are resources of the
  test target only; `scenario-manifest.json` is outside every target's path.
- **ProjectM.** Not used; no engine code, preset format or name of it is in the experience, and ProjectM types stay out
  of the app.
