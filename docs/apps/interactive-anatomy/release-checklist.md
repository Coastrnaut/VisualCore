# Interactive Anatomy — release checklist and artifact inventory

Interactive Anatomy (`a17.interactive-anatomy`) ships inside the one VisualCore app (ADR-0009); feature 129
(A17-P06), FR-A17-601 to FR-A17-607. App-wide commands are in [build-and-archive.md](../../release/build-and-archive.md).
The statuses are the words that `scripts/check_experience_release.py` accepts for every experience (Clarifications
Q1):

- `verified`: the evidence named in the row is a check of the legacy ledger (`.autonomy/checks/A17-P06.<name>.json`,
  recorded with `desktop_runbook.py run-check` before A17-P06 is sealed) or a sealed earlier phase
  (`.autonomy/checks/A17-P0N.*.json`; the A17-P05 package run `.autonomy/checks/A17-P05.ia-ios27.json` passed 75
  XCTest tests and 101 Swift Testing tests in 20 suites on the unchanged sources, cited as the baseline by T-A17-601).
  A row whose check file does not exist yet is pending: the task named in the row records it, and A17-P06 is not
  sealed before every such file exists and passed;
- `pending-campaign-ii` (spec: pending device campaign): needs the device campaign D1 → D2 → D3 after
  `ImplementationLock-100`; the row names its row IA-D1 … IA-D7 of [device-campaign.md](device-campaign.md); no device
  number is claimed before then;
- `owner-action` (spec: owner action): done by the owner only, steps in
  [build-and-archive.md](../../release/build-and-archive.md) section 5 or in [review.md](review.md)
  (`BLOCKED_OWNER_ACTION` until done); never done by the agent (CLAUDE.md rule 6).

`scripts/check_experience_release.py --config docs/apps/interactive-anatomy/release.json` rejects a row without a
known status or without evidence.

| Item | Area | Status | Evidence |
|---|---|---|---|
| Privacy and credits note: what is stored and where (`view.json` in the experience's storage with the camera steps, the shown layers, the selection, the framed part and the isolate, replaced on every view change; the app's `state.json` session state), nothing sent, how to delete (the Settings reset of the experience's data; the reset of all data; deleting the app); the license inventory of the content pack (Gray's Anatomy 1918 sections: public-domain; Terminologia Anatomica names: facts; descriptions: original), the review record, the procedural geometry and the colours (original) | Privacy | verified | [privacy-and-credits.md](privacy-and-credits.md) (T-A17-602); `.autonomy/checks/A17-P06.release-checks.json` (`experience-release-a17`, T-A17-611) |
| No network, tracking, sensor, recording, microphone input, photo-library, image-picker, system-brightness or idle-timer use in the experience's sources | Privacy | verified | `.autonomy/checks/A17-P06.ia-no-network.json` (`specs/129-ia-p06-release/scan-sources-release.sh`, T-A17-603); `NoNetworkTests.noInteractiveAnatomySourceUsesTheNetwork` in `.autonomy/checks/A17-P05.ia-ios27.json` (baseline, T-A17-601) |
| No permission requested and no usage-description string added (the registration declares `"permissions": []`); no sound and no haptic; the app's usage strings unchanged | Privacy | verified | `.autonomy/checks/A17-P06.release-checks.json` (`app-usage-descriptions`, T-A17-611); `Catalog/registrations.json`; `project.yml`; [privacy-and-credits.md](privacy-and-credits.md) |
| App privacy manifest matches the Release build and covers the experience's required-reason uses | Privacy | verified | `.autonomy/checks/A17-P06.release-checks.json` (`app-privacy-manifest`, T-A17-611); [privacy-and-credits.md](privacy-and-credits.md) |
| No tracking or advertising in the built app | Privacy | verified | `.autonomy/checks/A17-P06.release-checks.json` (`app-no-tracking`, T-A17-611) |
| Credits and licenses of the content: every part cites its Gray's Anatomy (20th edition, 1918) section, Terminologia Anatomica (1998) for its standard name and the original descriptions; only `public-domain`, `facts` and `original` are allowed; the provenance is complete; the generated sources table matches the content | Credits | verified | `.autonomy/checks/A17-P05.ia-ios27.json` (`ContentPackTests.theBundledPackLoadsAndValidates`; `ContentValidationTests.badLicensesAreRefused`; `ProvenanceTests.theBundledProvenanceIsComplete`; `SourcesDocumentTests.theCommittedSourcesDocumentMatchesTheContent`; baseline, T-A17-601); `.autonomy/checks/A17-P06.ia-ios27.json` (T-A17-609); [content-sources.md](content-sources.md) |
| Licenses and acknowledgements: visuals made in code (procedural geometry of `AnatomyGeometry.swift` and `AnatomyScene.swift`, original code; the layer colours and signs of `AnatomyLayerSign.swift`; native labels, list and panel); no third-party code, mesh, image, font or sound in the experience; app Licenses folder equals the inventory | Credits | verified | `.autonomy/checks/A17-P06.release-checks.json` (`app-licenses`, T-A17-611); `SceneBuildTests.everyMeshValidatesAndIsClosedAtBothLevels`, `LayerSignTests.everyLayerHasItsSignWordsAndColour` in `.autonomy/checks/A17-P05.ia-ios27.json` (baseline, T-A17-601) and `.autonomy/checks/A17-P06.ia-ios27.json` (T-A17-609) |
| Educational, not medical: the descriptions state form, position and connections only, and the validator refuses clinical text (reason `clinical-text`); the model statement "Schematic model for learning; shapes are simplified." shown with the model; "Not reviewed by a clinician." on every part; a refused review record leaves only that line | Content | verified | `.autonomy/checks/A17-P05.ia-ios27.json` (`ContentValidationTests.clinicalTextIsRefused`; `ReviewRecordTests.theBundledRecordHasOneEditorialEntryPerPartAndNoClinicalEntry`, `theModelStatementAndTheLinesWithoutARecord`; `AnatomyListOnlyTests.testARefusedReviewRecordLeavesOnlyTheNotReviewedLineAndIsCounted`; baseline, T-A17-601); `.autonomy/checks/A17-P06.ia-ios27.json` (T-A17-609); `.autonomy/checks/A17-P06.app-ui.json` (`IAExploreUITests`, T-A17-610); [review.md](review.md) |
| Store text input describing only implemented and tested features, with a claim → proving-test table; the educational, schematic and not-reviewed statements; labels may be skipped and the list names every part; no performance figure, no device value and none of the refused words of Clarifications Q2 | Store | verified | [store-listing.md](store-listing.md) (T-A17-606); `.autonomy/checks/A17-P06.ia-claims.json` (`specs/129-ia-p06-release/scan-claims-release.sh`, T-A17-607) |
| Copy check: no measured claim, unmeasured quality word or missing feature in the store text and interface strings (only `camera` allowed: the orbit camera of the 3D view) | Store | verified | `.autonomy/checks/A17-P06.release-checks.json` (`copy-claims-a17`, T-A17-611; `Configs/copy-claims-denylist.json`); `.autonomy/checks/A17-P06.experience-release.json` (T-A17-606) |
| Experience release check: required documents present (privacy and credits, store text, checklist, device campaign, review, content sources, VisualCore contract, build and archive), every checklist row has status and evidence | Store | verified | `.autonomy/checks/A17-P06.release-checks.json` (`experience-release-a17`, T-A17-611); `.autonomy/checks/A17-P06.experience-release.json` (T-A17-606) |
| Sample stored files: `view-{v2,v1,newer,damaged}.json` (v2 opens; v1 opens migrated; newer and damaged leave the opening view and count a read refusal); each stays byte-identical | Data | verified | `.autonomy/checks/A17-P06.ia-ios27.json` (`StoredViewSampleTests`; T-A17-605, T-A17-609) |
| Saved view: accepted actions write `view.json` and a new session opens with it; a schema 1 file opens migrated; an unknown id is dropped and the rest kept; damaged, newer, foreign and oversized files leave the opening view; a refused write is counted and the session keeps running; a restored snapshot wins over the file | Data | verified | `.autonomy/checks/A17-P05.ia-ios27.json` (`AnatomyViewFileTests.testAcceptedActionsWriteTheFileAndANewSessionOpensWithIt`, `testASchemaOneFileOpensMigrated`, `testAnUnknownIdInTheFileIsDroppedAndTheRestIsKept`, `testDamagedNewerForeignAndOversizedFilesLeaveTheOpeningView`, `testARefusedWriteIsCountedAndTheSessionKeepsRunning`, `testARestoredSnapshotWinsOverTheFile`; `ViewDocumentTests.aViewRoundTripsExactly`, `badFilesAreRefusedWithTheirReasons`; baseline, T-A17-601); `.autonomy/checks/A17-P06.ia-ios27.json` (T-A17-609) |
| Session state: the saved state restores in a new session; damaged and edited states are refused and the opening view opens; a schema 1 state opens migrated | Data | verified | `.autonomy/checks/A17-P05.ia-ios27.json` (`AnatomySessionTests.testTheSavedStateRestoresInANewSession`, `testADamagedSavedStateIsRefusedAndTheOpeningViewOpens`, `testAnEditedSnapshotIsRefusedByTheHostAndOpensTheOpeningView`, `testASchemaOneSavedStateOpensMigrated`; `AnatomyCoreTests.testTheSnapshotPayloadRoundTrips`, `testDamagedNewerAndUnknownIdSavedStatesAreRefused`; baseline, T-A17-601); `.autonomy/checks/A17-P06.ia-ios27.json` (T-A17-609) |
| Old views: view schema 1 (A17-P02) is the only older form, covered by the v1 sample and the migration tests | Data | verified | `Packages/ExperiencesCreative/InteractiveAnatomy/Core/AnatomyViewState.swift` (`AnatomyViewState.schemaVersion = 2`, migration 1 → 2); `ViewStateTests.schemaOneMigratesWithNoIsolate`, `ViewDocumentTests.aSchemaOneFileMigratesWithNoIsolate` in `.autonomy/checks/A17-P05.ia-ios27.json` (baseline, T-A17-601); `StoredViewSampleTests` in `.autonomy/checks/A17-P06.ia-ios27.json` (T-A17-605, T-A17-609) |
| Drawing-failure recovery: a failed draw after a save fails the session, `view.json` is byte-identical after the failure and after close, and a new session over the same storage opens with the view | Recovery | verified | `.autonomy/checks/A17-P06.ia-ios27.json` (`AnatomyRecoveryDrawTests`, test-only `failNextDraw` seam; T-A17-604, T-A17-609) |
| Ghost failure: a throwing translucent draw turns the ghosts off, the panel says "Ghosts are off." and the session goes on | Recovery | verified | `.autonomy/checks/A17-P05.ia-ios27.json` (`AnatomyIsolateRenderTests.testAThrowingTranslucentDrawTurnsTheGhostsOffAndTheSessionGoesOn`; baseline, T-A17-601); `.autonomy/checks/A17-P06.ia-ios27.json` (T-A17-609) |
| Accessibility (automated): every part selectable from the list alone, with the panel and the announcement a tap gives; labels, values, hints and identifiers `experience.a17.interactive-anatomy.<name>` on every control (`AnatomyControls.swift`); refused actions answered in words ("The camera is at its limit.") | Accessibility | verified | `.autonomy/checks/A17-P05.ia-ios27.json` (`AnatomyListOnlyTests.testEveryPartIsSelectedFromTheListAloneWithThePanelAndTheAnnouncementOfATap`; `AnatomyGestureTests.testStepsPastTheLimitsAreRefusedWithTheSentence`; baseline, T-A17-601); `.autonomy/checks/A17-P06.ia-ios27.json` (T-A17-609); `.autonomy/checks/A17-P06.app-ui.json` (`IAExploreUITests`, `IASearchUITests`, T-A17-610) |
| Accessibility (automated): a native control for every gesture (Turn, Tilt, Zoom and Reset view buttons; the list for a tap) | Accessibility | verified | `.autonomy/checks/A17-P05.ia-ios27.json` (`AnatomyGestureTests.testEveryGestureActionHasANativeControl`, `testADragThroughTheSessionEqualsTheButtons`; `AnatomyTapTests.testChoosingFromTheListEqualsTheTapThatPickedThePart`; baseline, T-A17-601); `.autonomy/checks/A17-P06.ia-ios27.json` (T-A17-609) |
| Accessibility (automated): colour is never the only cue (the layer signs ●, ◆ and ▲; rows spoken "<name>, <layer words>"; the canvas description names the shown layers, the selection and the isolate); selections announced at most every 0.5 s with the last always announced | Accessibility | verified | `.autonomy/checks/A17-P05.ia-ios27.json` (`LayerSignTests.everyLayerHasItsSignWordsAndColour`, `theSignsPassTheStateSignCheck`; `AnatomyCoreTests.testTheCanvasDescription`; `AnatomyAnnouncementTests.testFiveQuickSelectionsAreRateLimitedAndTheLastIsAlwaysAnnounced`; baseline, T-A17-601); `.autonomy/checks/A17-P06.ia-ios27.json` (T-A17-609) |
| Accessibility (automated): labels never overlap, ghosted and hidden parts get none, at most 16 are placed and the rest are skipped; the list names every part | Accessibility | verified | `.autonomy/checks/A17-P05.ia-ios27.json` (`AnatomyLabelTests.testOverAGridOfCamerasNoLabelsOverlapAndTheSelectionIsPlaced`, `testGhostedAndHiddenPartsGetNoLabel`, `testACanvasSmallerThanOneBoxPlacesNoLabel`; baseline, T-A17-601); `.autonomy/checks/A17-P06.ia-ios27.json` (T-A17-609) |
| Accessibility (automated): motion — nothing animates in any mode; framing and every camera step cut in one frame, with Reduce Motion and without | Accessibility | verified | `.autonomy/checks/A17-P05.ia-ios27.json` (`AnatomyAnnouncementTests.testWithReduceMotionSelectingFramesThePartInTheSameFrame`, `testWithoutReduceMotionNothingAnimatesEither`; baseline, T-A17-601); `.autonomy/checks/A17-P06.ia-ios27.json` (T-A17-609) |
| ExperiencesCreative package suites of Interactive Anatomy on the iOS 27 simulator (sim-27.2; iOS 26 at X-A17 by owner ruling of 2026-11-14), the slowest test under 10 s | Tests | verified | `.autonomy/checks/A17-P05.ia-ios27.json` (baseline, T-A17-601); `.autonomy/checks/A17-P06.ia-ios27.json` (`InteractiveAnatomyCoreTests`, `InteractiveAnatomyExperienceTests`, T-A17-609) |
| App build, unit tests and interface chunk y2 (serial): choose "Femur" in the list, the panel shows "Femur", a citation and "Not reviewed by a clinician."; the About row shows the model statement; switch off the bones layer, the femur row is marked hidden; type "ACL" and choose the first result, the anterior cruciate ligament is selected; Isolate selected, then Show all | Tests | verified | `.autonomy/checks/A17-P05.app-unit.json` (baseline, T-A17-601); `.autonomy/checks/A17-P06.app-ui.json` (`app-build-for-testing-ios27`, `app-unit-ios27`, `app-ui-ios27-y2`: `IAExploreUITests`, `IASearchUITests`; T-A17-608, T-A17-610) |
| Experience runner on iOS 27 (standard scenarios) | Tests | verified | `.autonomy/checks/A17-P05.verify-27.json` (baseline, T-A17-601); `.autonomy/checks/A17-P06.verify-27.json` (T-A17-610) |
| Packages, catalog and script tests (the release and copy-claim tools with the new release configuration) | Tests | verified | T-A17-612: `.autonomy/checks/A17-P06.experience-packages.json`, `.autonomy/checks/A17-P06.catalog.json`, `.autonomy/checks/A17-P06.script-tests.json` |
| VisualCore contract: G-RELEASE closed by A17-P06 | Tests | verified | `.autonomy/checks/A17-P06.contract.json` (`scripts/check_app_contract.py --app interactive-anatomy --render`, T-A17-612); [visualcore-contract.md](visualcore-contract.md) |
| Release build checks: unsigned Release build, no debug or scenario symbols, manifest, tracking, licenses, usage strings, experience release documents, copy claims | Build | verified | `.autonomy/checks/A17-P06.release-checks.json` (T-A17-611) |
| Build-and-archive instructions for the one app, owner steps marked | Build | verified | [build-and-archive.md](../../release/build-and-archive.md); its agent-run release steps in `.autonomy/checks/A17-P06.release-checks.json` (T-A17-611) |
| Frame pacing at both drawing levels | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row IA-D1 "Frame pacing at both levels"; no number is claimed before device evidence |
| Thermal state over a loop of orbit, selection, search, isolate and Show all | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row IA-D2 "Thermal state over 10 minutes" |
| Memory high-water mark and five reopens restoring the view from `view.json` | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row IA-D3 "Memory" |
| VoiceOver on hardware with the list alone (every part, the panel, search, isolate, Show all) | Accessibility | pending-campaign-ii | [device-campaign.md](device-campaign.md) row IA-D4 "VoiceOver with the list alone" and the one app's campaign, Auto-Creator.md section 23.3 |
| Dynamic Type at the largest accessibility size (labels may be skipped; the list names every part) | Accessibility | pending-campaign-ii | [device-campaign.md](device-campaign.md) row IA-D5 "Dynamic Type at the largest size" |
| Reduce Motion on hardware | Accessibility | pending-campaign-ii | [device-campaign.md](device-campaign.md) row IA-D6 "Reduce Motion" |
| System accessibility audits at the default and the largest text size | Accessibility | pending-campaign-ii | [device-campaign.md](device-campaign.md) row IA-D7 "Accessibility audit", run with `VC_RUN_AUDITS=1`; deferred to the device campaign by owner ruling of 2026-11-13 |
| Clinical review of the content by a qualified clinician | Content | owner-action | `BLOCKED_OWNER_ACTION`: [review.md](review.md) section "Clinical review (not done)" (a qualified clinician reads every description and name in the content pack; a `clinical` entry per reviewed part with the reviewer's name, the ISO date and the method in `knee-right.review.json`; core tests run and the review table regenerated with `UPDATE_DATA_SOURCES=1`); the engineer never adds a clinical entry |
| Signing set-up: team, certificates and provisioning profiles | Distribution | owner-action | `BLOCKED_OWNER_ACTION`: [build-and-archive.md](../../release/build-and-archive.md) section 5 step 1 (create the gitignored `Configs/Signing.local.xcconfig` with `DEVELOPMENT_TEAM`; certificates and profiles in Xcode Settings › Accounts with the owner's Apple ID) and step 2 (final bundle and product identifiers) |
| Archive of the one app | Distribution | owner-action | `BLOCKED_OWNER_ACTION`: [build-and-archive.md](../../release/build-and-archive.md) section 5 step 3 (open `VisualCore.xcodeproj`, scheme `VisualCore`, destination "Any iOS Device (arm64)", Product › Archive) |
| Validation and upload of the archive | Distribution | owner-action | `BLOCKED_OWNER_ACTION`: [build-and-archive.md](../../release/build-and-archive.md) section 5 step 4 (Organizer, Validate App, then Distribute App › App Store Connect › Upload) |

The App Store Connect record, the App Privacy answers (no data collected, no tracking), the store text from
[store-listing.md](store-listing.md), the screenshots and the review submission are further owner steps of the one app
([build-and-archive.md](../../release/build-and-archive.md) section 5 steps 5, 6, 8 and 9), recorded once for the app as
`BLOCKED_OWNER_ACTION`; the agent never does them.

## Accessibility: proved so far and pending for devices

Proved by the experience's tests on the iOS 27 simulator (rows above): every part selectable from the list alone with
the panel and the announcement a tap gives; labels, values, hints and identifiers on every control; a native control
for every gesture; the layer signs, so colour is never the only cue; the canvas description; rate-limited selection
announcements; labels that never overlap, with the list naming every part; nothing animating in any mode. Pending for
devices (owner ruling of 2026-11-13: all system accessibility audits wait for device testing): VoiceOver on hardware
(IA-D4), Dynamic Type at the largest size (IA-D5), Reduce Motion on hardware (IA-D6) and the system accessibility
audits (IA-D7).

## Artifact inventory

Documents of this phase (all under `docs/apps/interactive-anatomy/` unless a path is given):

- `privacy-and-credits.md` — stored data, what is read, how to delete, permissions, what is not done, required-reason
  APIs, the license inventory (T-A17-602).
- `store-listing.md` — store text input with the claim → proving-test table (T-A17-606).
- `release-checklist.md` — this checklist (T-A17-606).
- `release.json` — release configuration read by `check_experience_release.py` and `release_check.py` (T-A17-606;
  `specs/129-ia-p06-release/contracts/release.md`).
- `docs/release/known-limitations.md`, section "Interactive Anatomy" — one region, the schematic model, the review
  status, the labels, the stored view and the device-only items (T-A17-606).
- `device-campaign.md` — device measurements IA-D1 … IA-D7 (A17-P05).
- `review.md`, `content-sources.md` — review status and content sources (A17-P05, A17-P01).
- `docs/release/build-and-archive.md` — app-wide build and owner steps (existing).
- `README.md`, `visualcore-contract.json`, `visualcore-contract.md`, `regression-baseline.md` — existing documents.

Configuration:

- `Configs/copy-claims-denylist.json` — shared copy-claim denylist (unchanged).
- `specs/129-ia-p06-release/scan-sources-release.sh` — source scan of Clarifications Q3 (T-A17-603).
- `specs/129-ia-p06-release/scan-claims-release.sh` — refused-word scan of the store text and the interface Swift and
  test-name check of the claim table (T-A17-607).
- `scripts/release_check.py` — serial interface chunk `y2` with `IAExploreUITests` and `IASearchUITests`
  (T-A17-608).

Code and test artifacts of this phase:

- `Packages/ExperiencesCreative/InteractiveAnatomy/Experience/AnatomyPresenter.swift` — the test-only `failNextDraw`
  seam (T-A17-604).
- `Packages/ExperiencesCreative/InteractiveAnatomy/ExperienceTests/AnatomyRecoveryDrawTests.swift` (T-A17-604).
- `Packages/ExperiencesCreative/InteractiveAnatomy/ExperienceTests/Fixtures/` with `view-{v2,v1,newer,damaged}.json`,
  the test target's resources in `Packages/ExperiencesCreative/Package.swift`, and
  `ExperienceTests/StoredViewSampleTests.swift` (T-A17-605).
- `Apps/VisualCore/Tests/UI/InteractiveAnatomy/IASupport.swift`, `IAExploreUITests.swift`, `IASearchUITests.swift`
  (T-A17-608).

Evidence files (legacy ledger, stage A17-P06): `ia-no-network`, `experience-release`, `ia-claims`, `ia-ios27`,
`app-ui`, `verify-27`, `release-checks`, `contract` under `.autonomy/checks/A17-P06.<name>.json`; sealed evidence of
the earlier phases `.autonomy/evidence/A17-P00.json` … `A17-P05.json`; baseline cited from
`.autonomy/checks/A17-P05.{ia-ios27,app-unit,verify-27}.json` (T-A17-601).
