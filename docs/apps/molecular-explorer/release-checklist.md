# Molecular Explorer — release checklist and artifact inventory

Molecular Explorer (`a15.molecular-explorer`) ships inside the one VisualCore app (ADR-0009); feature 115 (A15-P06),
FR-A15-620, FR-A15-622, FR-A15-623, FR-A15-630, FR-A15-631 and FR-A15-632. App-wide commands are in
[build-and-archive.md](../../release/build-and-archive.md). The statuses are the words that
`scripts/check_experience_release.py` accepts for every experience (Clarifications Q1):

- `verified`: the evidence named in the row is a check of the legacy ledger (`.autonomy/checks/A15-P06.<name>.json`,
  recorded with `desktop_runbook.py run-check` before A15-P06 is sealed) or a sealed earlier phase
  (`.autonomy/checks/A15-P0N.*.json`; the A15-P05 package run `.autonomy/checks/A15-P05.me-ios27-4.json` passed 103
  XCTest tests and 117 Swift Testing tests in 22 suites on the unchanged sources, cited as the baseline by T-A15-601).
  A row whose check file does not exist yet is pending: the task named in the row records it, and A15-P06 is not
  sealed before every such file exists and passed;
- `pending-campaign-ii` (spec: pending device campaign): needs the device campaign D1 → D2 → D3 after
  `ImplementationLock-100`; the row names its row of [device-campaign.md](device-campaign.md) or the one app's campaign
  (Auto-Creator.md section 23.3); no device number is claimed before then;
- `owner-action` (spec: owner action): done by the owner only, steps in
  [build-and-archive.md](../../release/build-and-archive.md) section 5 (`BLOCKED_OWNER_ACTION` until done); never done
  by the agent (CLAUDE.md rule 6); task T-A15-614.

`scripts/check_experience_release.py --config docs/apps/molecular-explorer/release.json` rejects a row without a
known status or without evidence.

| Item | Area | Status | Evidence |
|---|---|---|---|
| Privacy and credits note: what is stored and where (`recent.json` with at most eight recent ids, at most 2,048 bytes; `settings.json` with the label mode, at most 1,024 bytes; `import.xyz`, the one imported copy, at most 65,536 bytes; `import-title.txt`, its title; the app's `state.json` session state), only the picked file read and nothing sent, no personal data, how to delete (a new import replaces the copy; the Settings reset of the experience's data; the reset of all data; removing the app); every data source credited with its license | Privacy | verified | [privacy-and-credits.md](privacy-and-credits.md) (T-A15-602); [data-sources.md](data-sources.md); `.autonomy/checks/A15-P06.release-checks.json` (`experience-release-a15`, T-A15-612) |
| No network, tracking, sensor, recording, microphone input, photo-library, image-picker, system-brightness or idle-timer use in the experience's sources | Privacy | verified | `.autonomy/checks/A15-P06.me-no-network.json` (`specs/115-me-p06-release/scan-sources-release.sh`, T-A15-603) |
| No permission requested and no usage string added (the registration declares `"permissions": []`; the system document picker needs none); no sound and no haptic; the app's usage strings unchanged | Privacy | verified | `.autonomy/checks/A15-P06.release-checks.json` (`app-usage-descriptions`, T-A15-612); `Catalog/registrations.json`; `project.yml`; [privacy-and-credits.md](privacy-and-credits.md) |
| App privacy manifest matches the Release build and covers the experience's required-reason uses | Privacy | verified | `.autonomy/checks/A15-P06.release-checks.json` (`app-privacy-manifest`, T-A15-612); [privacy-and-credits.md](privacy-and-credits.md) |
| No tracking or advertising in the built app | Privacy | verified | `.autonomy/checks/A15-P06.release-checks.json` (`app-no-tracking`, T-A15-612) |
| Only the picked file is read: its size is checked first and a file above 64 KB is never read; a refused file writes nothing and sends no action; an import while the experience is not active changes nothing | Privacy | verified | `.autonomy/checks/A15-P05.me-ios27-4.json` (`MoleculeImportSessionTests.testAnOversizedFileIsRefusedWithoutBeingRead`, `testEachRefusalShowsItsSentenceAndChangesNothing`, `testAnImportWhileNotActiveChangesNothing`; baseline, T-A15-601); `.autonomy/checks/A15-P06.me-ios27.json` (T-A15-610) |
| Data credits and licenses: ten elements with 50 source records (PubChem Periodic Table of Elements, public-domain; covalent radii from B. Cordero et al., Dalton Transactions 2008, factual-data) and five molecules (PubChem Compound CIDs 962, 297, 702, 241 and 2519, 3D conformers, public-domain); 0 problems; the committed data-sources and data-review documents match the data | Credits | verified | `.autonomy/checks/A15-P05.me-ios27-4.json` (`ElementAuditTests.theBundledDataHasNoProblems`, `theCommittedDataSourcesDocumentMatchesTheData`; `ElementsTests.everyStoredValueHasOneSourceRecord`; `MoleculeLibraryTests.everyStructureRecordIsPubChemPublicDomain`; `MoleculeReviewTests.theCommittedDataReviewMatchesTheData`; baseline, T-A15-601); `.autonomy/checks/A15-P06.me-ios27.json` (T-A15-610); [data-sources.md](data-sources.md); [data-review.md](data-review.md) |
| Licenses and acknowledgements: visuals made in code (one procedural unit sphere and one unit stick, scaled and coloured per atom and bond; native overlay labels and ring); no third-party code, image, font or sound in the experience; app Licenses folder equals the inventory | Credits | verified | `.autonomy/checks/A15-P06.release-checks.json` (`app-licenses`, T-A15-612); `MoleculeRenderTests.testTheUnitMeshesTheModelMatricesAndTheColours`, `testTheExperienceNeverCreatesAGraphicsContextOfItsOwn` in `.autonomy/checks/A15-P05.me-ios27-4.json` (baseline, T-A15-601) and `.autonomy/checks/A15-P06.me-ios27.json` (T-A15-610) |
| Data review and truthful words: the two statements ("Display radii, not measured sizes."; "Bonds marked inferred are estimated from atom distances.") shown; no shown sentence and no string literal of the sources holds a claim word; inferred bonds always marked inferred | Content | verified | `.autonomy/checks/A15-P05.me-ios27-4.json` (`MoleculeReviewTests.theStatementsAndClaimWordsAreFixed`, `theDocumentHoldsNoClaimWord`; `MoleculeWordsTests.testNoShownSentenceHoldsAClaimWord`, `testThePanelShowsBothStatements`, `testNoStringLiteralInTheSourcesHoldsAClaimWord`; `BondInferenceTests.theResultIsSortedSingleInferredAndDeterministic`; baseline, T-A15-601); `.autonomy/checks/A15-P05.copy-claims.json`; [data-review.md](data-review.md) |
| Store text input describing only implemented and tested features, with a claim → proving-test table; no performance figure, no device value and none of the refused words of Clarifications Q2 (no accuracy, simulation, safety, toxicity, medical or measured-performance word); unsupported promised features absent from the interface and the store text | Store | verified | [store-listing.md](store-listing.md) (T-A15-607); `.autonomy/checks/A15-P06.me-claims.json` (`specs/115-me-p06-release/scan-claims-release.sh`, T-A15-608) |
| Copy check: no measured claim, unmeasured quality word or missing feature in the store text and interface strings (only `camera` allowed: the 3D view's virtual camera) | Store | verified | `.autonomy/checks/A15-P06.release-checks.json` (`copy-claims-a15`, T-A15-612; `Configs/copy-claims-denylist.json`) |
| Experience release check: required documents present (privacy and credits, store text, checklist, device campaign, data review, data sources, build and archive), every checklist row has status and evidence | Store | verified | `.autonomy/checks/A15-P06.release-checks.json` (`experience-release-a15`, T-A15-612) |
| Sample stored files: `recent-{valid,newer,damaged,oversized}.json`, `settings-{valid,newer,damaged,oversized}.json` and `import-{valid,damaged,oversized}.xyz` committed; the valid ones load or open; the others are refused with their reason (`newer-version`, `damaged`, `oversized`; a parser refusal with its sentence; a size refusal before reading) and each stays byte-identical | Data | verified | `.autonomy/checks/A15-P06.me-ios27.json` (`StoredFileSampleTests`; T-A15-605, T-A15-610) |
| Recent list and settings stores: a recorded list and a changed label mode load back in a new store; ids outside the library dropped on read; damaged, newer, oversized and out-of-range files refused and left byte-identical with their messages; a failed write keeps the previous file; removing the folder gives the defaults; the engine digest is the same with and without storage | Data | verified | `.autonomy/checks/A15-P05.me-ios27-4.json` (`RecentStoreTests`, `SettingsStoreTests`, `RecentMoleculesTests`, `MoleculeSettingsTests`; baseline, T-A15-601); `.autonomy/checks/A15-P06.me-ios27.json` (T-A15-610) |
| Imported copy: a valid file is kept as `import.xyz` and `import-title.txt` and reopens with the Recent list holding it; a missing or damaged copy keeps the saved molecule and drops the unavailable entry; a refused copy write still imports with its message | Data | verified | `.autonomy/checks/A15-P05.me-ios27-4.json` (`MoleculeImportSessionTests.testReopeningShowsTheImportAndTheRecentListHoldsIt`, `testAMissingOrDamagedCopyKeepsTheSavedMoleculeAndAnUnavailableEntryIsDropped`, `testARefusedCopyWriteStillImportsWithItsMessage`; baseline, T-A15-601); `.autonomy/checks/A15-P06.me-ios27.json` (T-A15-610) |
| Session state: snapshots of schemas 1 to 3 migrate to schema 4 (stored examples `MoleculeCore.schemaOneExample()`, `schemaTwoExample()`, `schemaThreeExample()` with their digests, passed to the registry); newer and damaged snapshots refused and water opens; the saved state restores identically in a new session | Data | verified | `.autonomy/checks/A15-P05.me-ios27-4.json` (`MoleculeCoreTests.testTheMigrationStepsTurnSchemaOneAndTwoIntoSchemaFour`; `MoleculeStateSchema4Tests.olderSchemasMigrateWithNoImport`; `MoleculeSessionTests.testANewerSavedStateIsRefusedAndWaterOpens`, `testADamagedSavedStateIsRefusedAndWaterOpens`, `testTheSavedStateRestoresIdenticallyInANewSession`; baseline, T-A15-601); `.autonomy/checks/A15-P06.me-ios27.json` (`MoleculeSchemaExampleTests`; T-A15-606, T-A15-610) |
| Drawing-failure recovery: a failed draw after an import fails the session, `import.xyz`, `recent.json` and `settings.json` byte-identical, a new session over the same storage draws the import | Recovery | verified | `.autonomy/checks/A15-P06.me-ios27.json` (`MoleculeRecoveryDrawTests`, test-only `failNextDraw` seam; T-A15-604, T-A15-610) |
| Accessibility (automated): labels and values on every control — every control is built with a label, a value and a hint and an identifier `experience.a15.molecular-explorer.<name>` (`MoleculeControls.swift`); hit areas at least 44 points high and text wraps; the status line names the selected molecule; refused actions are answered in words; the controls are found by identifier in the interface chunk | Accessibility | verified | `.autonomy/checks/A15-P05.me-ios27-4.json` (`MoleculeRenderTests.testTheWordsOfTheControls`; `MoleculeLibraryUITests.testEveryLibraryEntrysWords`; `MoleculeImportSessionTests.testTheImportButtonsWordsAndTheControlsHoldOnlyReferences`; `MoleculeCoreTests.testRefusalsKeepTheStateWithTheirReasons`; baseline, T-A15-601); `.autonomy/checks/A15-P06.me-ios27.json` (T-A15-610); `.autonomy/checks/A15-P06.app-ui.json` (`MEExploreUITests`, `MELibraryUITests`, chunk w2, T-A15-611) |
| Accessibility (automated): a native control for every gesture — turn, tilt, zoom and pan buttons, Reset view, Previous and Next atom and Clear selection do what drags, pinches, two-finger moves and taps do; the experience has no gesture-only action | Accessibility | verified | `.autonomy/checks/A15-P05.me-ios27-4.json` (`MoleculeGestureTests.testEveryGestureActionHasANativeControl`, `testADragThroughTheSessionEqualsPressingTurnLeftThreeTimes`; baseline, T-A15-601); `.autonomy/checks/A15-P06.me-ios27.json` (T-A15-610); `.autonomy/checks/A15-P06.app-ui.json` (chunk w2 uses the native controls only, T-A15-611) |
| Accessibility (automated): canvas description with the molecule, the display mode and the selected atom ("; selected nitrogen, atom 3"); the atom panel names the element, its place, position and radii and each bond with its order and origin | Accessibility | verified | `.autonomy/checks/A15-P05.me-ios27-4.json` (`MoleculeCoreTests.testTheLinesAndTheCanvasDescriptionFollowClarificationQ5`, `testTheDigestAndTheDescriptionCoverThePanAndTheAtom`; `MoleculePanelTests.testTheMirrorAndTheDescriptionNameTheSelectedAtom`, `testThePanelLinesNameTheAtomAndItsBonds`; baseline, T-A15-601); `.autonomy/checks/A15-P06.me-ios27.json` (T-A15-610) |
| Accessibility (automated): element identity never depends on colour — element symbols are shown as labels that never overlap and the selected atom's element is named in words | Accessibility | verified | `.autonomy/checks/A15-P05.me-ios27-4.json` (`LabelLayoutTests.placedLabelsNeverOverlap`, `theSelectedAtomComesFirstThenNearerAtoms`; `MoleculePanelTests.testTheLabelsNeverOverlapAndTheSelectedAtomComesFirstWithItsRing`; baseline, T-A15-601); `.autonomy/checks/A15-P06.me-ios27.json` (T-A15-610) |
| Accessibility (automated): announcements — each action announces at most once and a selection change announces the atom; an import announces its success or its refusal | Accessibility | verified | `.autonomy/checks/A15-P05.me-ios27-4.json` (`MoleculePanelTests.testEachActionAnnouncesAtMostOnceAndASelectionChangeIsAnnounced`; `MoleculeImportSessionTests.testTheSuccessAndRefusalAnnouncements`; baseline, T-A15-601); `.autonomy/checks/A15-P06.me-ios27.json` (T-A15-610); the announcements themselves are heard on hardware in the device row ME-D3 |
| Accessibility (automated): motion — camera steps, resets and molecule changes cut to the new view in one frame (no animated move), so Reduce Motion changes nothing; nothing flashes; drawing never changes the state | Accessibility | verified | `.autonomy/checks/A15-P05.me-ios27-4.json` (`MoleculeCameraTests.testEveryCameraStepChangesTheFrameAndKeepsTheCentre`, `testResetViewFramesTheMoleculeAgain`; `MoleculeRenderTests.testDrawingNeverChangesTheState`; baseline, T-A15-601); `.autonomy/checks/A15-P06.me-ios27.json` (T-A15-610); `.autonomy/checks/A15-P06.me-ios27-3.json` (`MoleculeReduceMotionTests.testReduceMotionAndReduceFlashingChangeNothing`: the same digests, drawn counts and pixels with both settings on and off, T-A15-615) |
| ExperiencesCreative package suites of Molecular Explorer on the iOS 27 simulator (sim-27.2; iOS 26 at X-A15 by owner ruling of 2026-11-14) | Tests | verified | `.autonomy/checks/A15-P05.me-ios27-4.json` (baseline, T-A15-601); `.autonomy/checks/A15-P06.me-ios27.json` (`MolecularExplorerCoreTests`, `MolecularExplorerExperienceTests`, T-A15-610) |
| App build, unit tests and interface chunk w2 (serial): choose Benzene from the Library, the status names Benzene; Space filling, the legend starts "Space filling"; Next atom, the panel names atom 1; choose Caffeine then Water, the Recent menu lists Water then Caffeine; Labels None, the picker's value is None; reopen the experience, Labels still None; the document picker is never presented | Tests | verified | `.autonomy/checks/A15-P05.app-unit.json` (baseline, T-A15-601); `.autonomy/checks/A15-P06.app-ui.json` (`app-build-for-testing-ios27`, `app-unit-ios27`, `app-ui-ios27-w2`: `MEExploreUITests`, `MELibraryUITests`, iOS 27.2 phone simulator, each test under 60 s, T-A15-609, T-A15-611) |
| Experience runner on iOS 27 (standard scenarios) | Tests | verified | `.autonomy/checks/A15-P05.verify-27.json` (baseline, T-A15-601); `.autonomy/checks/A15-P06.verify-27.json` (T-A15-611) |
| Script tests (the release and copy-claim tools with the new release configuration) | Tests | verified | `.autonomy/checks/A15-P06.script-tests.json` (T-A15-613) |
| Release build checks: unsigned Release build, no debug or scenario symbols, manifest, tracking, licenses, usage strings, experience release documents, copy claims | Build | verified | `.autonomy/checks/A15-P06.release-checks.json` (T-A15-612) |
| Build-and-archive instructions for the one app, owner steps marked | Build | verified | [build-and-archive.md](../../release/build-and-archive.md); its agent-run release steps in `.autonomy/checks/A15-P06.release-checks.json` (T-A15-612) |
| Frame pacing with caffeine in both display modes on D1 to D3 | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row ME-D1 "Frame pacing with caffeine in both modes"; no number is claimed before device evidence |
| Touch orbit, pan, zoom and atom picking on hardware | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row ME-D2 "Touch orbit, pan, zoom and atom picking" |
| VoiceOver journey on hardware over every control, the panel, the statements and the announcements | Accessibility | pending-campaign-ii | [device-campaign.md](device-campaign.md) row ME-D3 "VoiceOver journey" and the one app's campaign, Auto-Creator.md section 23.3 |
| Dynamic Type at the largest accessibility size and the system accessibility audits at the default and the largest text size | Accessibility | pending-campaign-ii | [device-campaign.md](device-campaign.md) row ME-D4 "Dynamic Type and the system accessibility audits", run with `VC_RUN_AUDITS=1`; deferred to the device campaign by owner ruling of 2026-11-13 |
| Import from Files through the system document picker on hardware (valid, too large, too many atoms, unknown element, cancel, reopen) | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row ME-D5 "Import from Files"; never automated, since the picker waits for a person |
| Thermal state and peak memory over a short session with five reopenings and a memory warning | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row ME-D6 "Thermal state and peak memory over a short session" |
| Signing set-up: team, certificates and provisioning profiles | Distribution | owner-action | `BLOCKED_OWNER_ACTION`: [build-and-archive.md](../../release/build-and-archive.md) section 5 step 1 (create the gitignored `Configs/Signing.local.xcconfig` with `DEVELOPMENT_TEAM`; certificates and profiles in Xcode Settings › Accounts with the owner's Apple account) and step 2 (final bundle and product identifiers) (T-A15-614) |
| Archive of the one app | Distribution | owner-action | `BLOCKED_OWNER_ACTION`: [build-and-archive.md](../../release/build-and-archive.md) section 5 step 3 (open `VisualCore.xcodeproj`, scheme `VisualCore`, destination "Any iOS Device (arm64)", Product › Archive) (T-A15-614) |
| Validation and upload of the archive | Distribution | owner-action | `BLOCKED_OWNER_ACTION`: [build-and-archive.md](../../release/build-and-archive.md) section 5 step 4 (Organizer, Validate App, then Distribute App › App Store Connect › Upload) (T-A15-614) |

The App Store Connect record, the App Privacy answers (no data collected, no tracking), the store text from
[store-listing.md](store-listing.md), the screenshots and the review submission are further owner steps of the one app
([build-and-archive.md](../../release/build-and-archive.md) section 5 steps 5, 6, 8 and 9), recorded once for the app as
`BLOCKED_OWNER_ACTION`; the agent never does them.

## Accessibility: proved so far and pending for devices

Proved by the experience's tests on the iOS 27 simulator (rows above): labels, values, hints and identifiers on every
control, hit areas at least 44 points high and wrapping text; a native control for every gesture (there is no
gesture-only action); the canvas description with the molecule, the display mode and the selected atom; the atom panel
in words with each bond's order and origin; element symbols as non-overlapping labels, so element identity never
depends on colour; one announcement per action and one per selection change, and the import's success or refusal
announced; camera and molecule changes that cut in one frame, so Reduce Motion changes nothing and nothing flashes;
refused actions answered in words. Pending for devices (owner ruling of 2026-11-13: all system accessibility audits
wait for device testing): the VoiceOver journey on hardware (ME-D3), Dynamic Type at the largest sizes and the system
accessibility audits (ME-D4) and the import through the system document picker (ME-D5).

## Artifact inventory

Documents of this phase (all under `docs/apps/molecular-explorer/` unless a path is given):

- `privacy-and-credits.md` — stored data, what is read, how to delete, permissions, what is not done, required-reason
  APIs, credits (T-A15-602).
- `store-listing.md` — store text input with the claim → proving-test table (T-A15-607).
- `release-checklist.md` — this checklist (T-A15-607).
- `release.json` — release configuration read by `check_experience_release.py` and `release_check.py` (T-A15-607;
  `specs/115-me-p06-release/contracts/release.md`).
- `device-campaign.md` — device measurements ME-D1 … ME-D6 with procedure, threshold and pending status (T-A15-607).
- `docs/release/known-limitations.md`, section "Molecular Explorer" — device-only items, the five-molecule library, the
  bond-inference rule and the import limits (T-A15-607).
- `data-review.md` — every displayed value with units, source and license and the two statements, generated by
  `MoleculeReview` (A15-P05).
- `data-sources.md` — element values and molecule structures with source, units and license, generated by
  `ElementAudit` (A15-P01 onwards).
- `docs/release/build-and-archive.md` — app-wide build and owner steps (existing).
- `README.md`, `visualcore-contract.json`, `visualcore-contract.md`, `regression-baseline.md` — existing documents.

Configuration:

- `Configs/copy-claims-denylist.json` — shared copy-claim denylist (unchanged; Clarifications Q2).
- `specs/115-me-p06-release/scan-sources-release.sh` — source scan of Clarifications Q3 (T-A15-603).
- `specs/115-me-p06-release/scan-claims-release.sh` — refused-word scan of the store text and the interface Swift and
  test-name check of the claim table (T-A15-608).
- `scripts/release_check.py` — serial interface chunk `w2` with `MEExploreUITests` and `MELibraryUITests`
  (T-A15-609).

Code and test artifacts of this phase:

- `Packages/ExperiencesCreative/MolecularExplorer/Experience/MoleculePresenter.swift` — the test-only `failNextDraw`
  seam (T-A15-604).
- `Packages/ExperiencesCreative/MolecularExplorer/ExperienceTests/MoleculeRecoveryDrawTests.swift` (T-A15-604).
- `Packages/ExperiencesCreative/MolecularExplorer/ExperienceTests/Fixtures/` with
  `recent-{valid,newer,damaged,oversized}.json`, `settings-{valid,newer,damaged,oversized}.json` and
  `import-{valid,damaged,oversized}.xyz`, the test target's resources in `Packages/ExperiencesCreative/Package.swift`,
  and `ExperienceTests/StoredFileSampleTests.swift` (T-A15-605).
- `Experience/Adapter/MoleculeCore.swift` — `schemaOneExample()`, `schemaTwoExample()`, `schemaThreeExample()`, passed
  to the registry in `Apps/VisualCore/App/ExperienceRegistry.swift`, with
  `ExperienceTests/MoleculeSchemaExampleTests.swift` (T-A15-606).
- `Apps/VisualCore/Tests/UI/MolecularExplorer/MESupport.swift`, `MEExploreUITests.swift`, `MELibraryUITests.swift`
  (T-A15-609).

Test files cited by this checklist and the store text (existing): `Packages/ExperiencesCreative/MolecularExplorer/`
`CoreTests/{AtomPickerTests, BondInferenceTests, BondStyleTests, CameraSettingsTests, ElementAuditTests, ElementsTests,
ImportFuzzTests, LabelLayoutTests, MoleculeImportTests, MoleculeLibraryTests, MoleculeReviewTests, MoleculeSceneTests,
MoleculeSettingsTests, MoleculeStateSchema3Tests, MoleculeStateSchema4Tests, MoleculeStateTests, MoleculeTests,
RecentMoleculesTests, XYZParserTests}.swift` and `ExperienceTests/{MoleculeCameraTests, MoleculeCoreTests,
MoleculeGestureTests, MoleculeImportSessionTests, MoleculeLibraryUITests, MoleculePanelTests, MoleculePickingTests,
MoleculeRenderTests, MoleculeSceneRenderTests, MoleculeSessionTests, MoleculeWordsTests, RecentStoreTests,
SettingsStoreTests}.swift`.

Evidence files (legacy ledger, stage A15-P06): `me-no-network`, `me-ios27`, `me-claims`, `app-ui`, `verify-27`,
`release-checks`, `script-tests` under `.autonomy/checks/A15-P06.<name>.json`; sealed evidence of the earlier phases
`.autonomy/evidence/A15-P00.json` … `A15-P05.json`; baseline cited from
`.autonomy/checks/A15-P05.{me-ios27-4,app-unit,verify-27}.json` (T-A15-601).
