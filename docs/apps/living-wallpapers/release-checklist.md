# Living Wallpapers — release checklist and artifact inventory

Living Wallpapers (`a19.living-wallpapers`) ships inside the one VisualCore app (ADR-0009); feature 143 (A19-P06),
FR-A19-601 to FR-A19-607. App-wide commands are in [build-and-archive.md](../../release/build-and-archive.md). The
statuses are the words that `scripts/check_experience_release.py` accepts for every experience (Clarifications Q1):

- `verified`: the evidence named in the row is a check of the legacy ledger (`.autonomy/checks/A19-P06.<name>.json`,
  recorded with `desktop_runbook.py run-check` before A19-P06 is sealed) or a sealed earlier phase
  (`.autonomy/checks/A19-P0N.*.json`; the A19-P05 runs `.autonomy/checks/A19-P05.{lw-ios27,app-ui,verify-27}.json`
  passed on the sources unchanged since the A19-P05 record commit 7adeb1f9, cited as the baseline by T-A19-601). A
  row whose check file does not exist yet is pending: the task named in the row records it, and A19-P06 is not sealed
  before every such file exists and passed;
- `pending-campaign-ii` (spec: pending device campaign): needs the device campaign D1 → D2 → D3 after
  `ImplementationLock-100`; the row names its row LW-D1 … LW-D8 of [device-campaign.md](device-campaign.md); no
  device number is claimed before then;
- `owner-action` (spec: owner action): done by the owner only, steps in
  [build-and-archive.md](../../release/build-and-archive.md) section 5 (`BLOCKED_OWNER_ACTION` until done); never done
  by the agent (CLAUDE.md rule 6).

`scripts/check_experience_release.py --config docs/apps/living-wallpapers/release.json` rejects a row without a known
status or without evidence.

| Item | Area | Status | Evidence |
|---|---|---|---|
| Privacy and credits note: what is stored and where (the app's `state.json` with the schema 2 snapshot of the scene, preset, parameters, edited colours, template, orientation, animation time, format and motion setting; `history.json` with at most 20 exports, written after each written export and removed by "Clear history"), the temporary export folder `LivingWallpapers-Export` with at most one file, nothing sent, how to delete (Clear history; the Settings reset of the experience's data; the reset of all data; deleting the app); the add-only Photos string and when the system asks it; the license inventory (scenes and shaders written for this repository; presets and template sizes as numbers; the system font) | Privacy | verified | [privacy-and-credits.md](privacy-and-credits.md) (T-A19-602); [licenses.md](licenses.md); `.autonomy/checks/A19-P06.release-checks.json` (`experience-release-a19`, T-A19-611) |
| No network, tracking, sensor, recording, microphone input, photo-library, Photos picker, image-picker, idle-timer or system-brightness use in the experience's sources | Privacy | verified | `.autonomy/checks/A19-P06.lw-no-network.json` (`specs/143-lw-p06-release/scan-sources-release.sh`, T-A19-603); `.autonomy/checks/A19-P04.photos-scan.json` and `.autonomy/checks/A19-P05.photos-scan.json` (`specs/141-lw-p04-save-share/scan-photos.sh`) |
| One permission: the app's add-only usage string `NSPhotoLibraryAddUsageDescription` "Saves exported artwork to your photo library when you choose Save Image.", asked by the system only when the person chooses Save Image in the share sheet; the registration declares `"permissions": ["photo-library-add"]`; no sound and no haptic | Privacy | verified | `.autonomy/checks/A19-P04.usage.json` (`app-usage-descriptions`); `.autonomy/checks/A19-P06.release-checks.json` (`app-usage-descriptions`, T-A19-611); `Catalog/registrations.json`; `project.yml`; [privacy-and-credits.md](privacy-and-credits.md) |
| The export file leaves the app only through the share sheet; the temporary folder holds at most one file; a cancelled or failed export leaves no file | Privacy | verified | `.autonomy/checks/A19-P05.lw-ios27.json` (`ShareFileTests.theItemIsTheWrittenFile`, `thereIsNoItemWithoutAWrittenFile`; `ExportJobTests.aCancelAfterEachStepLeavesNoFileAndNoGPUResource`; `StillExportTests.cancellingFailingAndRetryingLeaveNoGPUResourceAndNoFile`; baseline, T-A19-601); `.autonomy/checks/A19-P06.lw-ios27.json` (T-A19-609) |
| App privacy manifest matches the Release build and covers the experience's required-reason uses | Privacy | verified | `.autonomy/checks/A19-P06.release-checks.json` (`app-privacy-manifest`, T-A19-611); [privacy-and-credits.md](privacy-and-credits.md) |
| No tracking or advertising in the built app | Privacy | verified | `.autonomy/checks/A19-P06.release-checks.json` (`app-no-tracking`, T-A19-611) |
| Licenses and acknowledgements: visuals made in code (the four scene shaders, original code; the presets, template sizes and guide fractions as numbers; text in the system font); no third-party code, image, texture, font file, model or sound in the experience; app Licenses folder equals the inventory | Credits | verified | `.autonomy/checks/A19-P06.release-checks.json` (`app-licenses`, T-A19-611); [licenses.md](licenses.md); `SceneRenderTests.everySceneAtBothLevelsIsNotBlankAndRepeatsExactly`, `SceneCatalogTests.theCatalogHoldsFourScenesInOrder`, `TemplateTests.everyTemplateRecordsItsProvenance` in `.autonomy/checks/A19-P05.lw-ios27.json` (baseline, T-A19-601) and `.autonomy/checks/A19-P06.lw-ios27.json` (T-A19-609) |
| Store text input describing only implemented and tested features, with a claim → proving-test table; stills only (PNG, JPEG, HEIC); sizes per device template, capped by the device; the person sets the wallpaper in Settings; no performance figure, no device value and none of the refused words of Clarifications Q2 | Store | verified | [store-listing.md](store-listing.md) (T-A19-606); `.autonomy/checks/A19-P06.lw-claims.json` (`specs/143-lw-p06-release/scan-claims-release.sh`, T-A19-607) |
| Copy check: no measured claim, unmeasured quality word or missing feature in the store text and interface strings (controls, editor model, help view, adapter); only "share" allowed | Store | verified | `.autonomy/checks/A19-P06.release-checks.json` (`copy-claims-a19`, T-A19-611; `Configs/copy-claims-denylist.json`); `.autonomy/checks/A19-P06.experience-release.json` (T-A19-606) |
| Help and interface words: the help says the person sets the wallpaper in the Settings app; no refused phrase in the editor, the result or the help | Store | verified | `.autonomy/checks/A19-P05.help-claims.json` (`specs/140-lw-p03-editor/scan-help-claims.sh`); `.autonomy/checks/A19-P05.lw-ios27.json` (`HelpTests.thePersonSetsTheWallpaper`, `noRefusedPhraseOrPhaseAppears`); `.autonomy/checks/A19-P05.app-ui.json` (`LWClaimsUITests`) |
| Short video: no-go for version 0.1; no video control, encoder or copy | Store | verified | [video-decision.md](video-decision.md) (A19-P01); `.autonomy/checks/A19-P06.lw-claims.json` (T-A19-607) |
| Experience release check: required documents present (privacy and credits, store text, checklist, device campaign, licenses, video decision, VisualCore contract, build and archive), every checklist row has status and evidence | Store | verified | `.autonomy/checks/A19-P06.release-checks.json` (`experience-release-a19`, T-A19-611); `.autonomy/checks/A19-P06.experience-release.json` (T-A19-606) |
| Sample stored files: `snapshot-{v1,v2,newer,damaged}.json` (v1 and v2 restore, v1 migrated; newer and damaged refused) and `history-{current,newer,damaged}.json` (current loads two entries; newer reports `newer-version`; damaged reports `damaged`); each stays byte-identical | Data | verified | `.autonomy/checks/A19-P06.lw-ios27.json` (`StoredSampleTests`; T-A19-605, T-A19-609) |
| Snapshot: schema 2 round trip; schema 1 opens migrated with the preset's colours; a newer schema or a value outside its range is refused | Data | verified | `.autonomy/checks/A19-P05.lw-ios27.json` (`SnapshotMigrationTests.theSchemaIsTwoAndTheSchemaOneExampleIsAcceptedByTheRegistryCheck`, `theSchemaOneExampleRestoresAsSchemaTwoWithCustomZero`, `theSchemaTwoExampleRoundTripsThroughTwoEngines`, `aNewerSchemaIsRefusedAndChangesNothing`; `WallpaperCoreTests.theSnapshotRoundTripKeepsTheDigest`, `aPayloadOutsideItsRangesIsRefused`; baseline, T-A19-601); `.autonomy/checks/A19-P06.lw-ios27.json` (T-A19-609) |
| Export history: each written export recorded with its time, newest first and at most 20; the file round-trips exactly; damaged and newer files give an empty history with their code; Clear history empties it and removes the file | Data | verified | `.autonomy/checks/A19-P05.lw-ios27.json` (`HistoryStoreTests.aWrittenExportRecordsAnEntryAtTheFixedTime`, `entriesAreNewestFirstAndBounded`, `clearEmptiesTheHistoryAndRemovesTheFile`, `damagedAndNewerFilesAreReportedWithAnEmptyHistory`, `aRoundTripAcrossTwoStoresOnTheSameStorage`; `ExportHistoryTests.addingKeepsTheNewestTwentyNewestFirst`, `theFileRoundTripsExactly`, `eachRefusalHasItsCodeAndSentence`; baseline, T-A19-601); `.autonomy/checks/A19-P06.lw-ios27.json` (T-A19-609) |
| Drawing-failure recovery: with two exports in the history, a failed draw fails the session with the injected error's message, `history.json` is byte-identical after the failure and after close, and a new session over the same storage opens and lists both | Recovery | verified | `.autonomy/checks/A19-P06.lw-ios27.json` (`WallpaperRecoveryDrawTests`, test-only `failNextDraw` seam; T-A19-604, T-A19-609) |
| Export recovery: a failure names its reason and a retry uses the offered plan; cancelling after each step leaves no file and no GPU resource | Recovery | verified | `.autonomy/checks/A19-P05.lw-ios27.json` (`ExportJobTests.aFailureNamesItsReasonAndRetryUsesTheOfferedPlan`, `aCancelAfterEachStepLeavesNoFileAndNoGPUResource`; `StillExportTests.aRenderWithNoExperienceOpenFailsAndLeavesNothing`; baseline, T-A19-601); `.autonomy/checks/A19-P06.lw-ios27.json` (T-A19-609) |
| Export: every available format at a fitting template is written at the planned size and read back as sRGB; a template above the limit is refused with a fitting offer and its notice | Export | verified | `.autonomy/checks/A19-P05.lw-ios27.json` (`StillExportTests.everyAvailableFormatExportsAtAFittingTemplateAndVerifies`; `ExportFixtureTests.everyFittingTemplateReadsBackAsPlanned`; `PlannerTests.templatesAboveTheLimitAreRefusedWithAFittingOffer`; `ExportNoticeTests.everyRefusedTemplateGetsANoticeWithItsNumbers`; `NoticeAndResultTests.theNoticeAndTheOfferedPlanFollowTheLimit`; baseline, T-A19-601); `.autonomy/checks/A19-P06.lw-ios27.json` (T-A19-609) |
| Accessibility (automated): every label non-empty and naming its value; each export outcome announced once; at the largest accessibility text size the controls stack within the canvas | Accessibility | verified | `.autonomy/checks/A19-P05.lw-ios27.json` (`EditorAccessibilityTests.everyLabelIsNonEmptyAndNamesItsValue`, `eachExportOutcomeIsAnnouncedExactlyOnce`, `atAccessibilityFiveTheControlsStackWithinTheCanvas`; `CropOverlayTests.theLabelNamesTheDeviceTheOrientationAndThePixelSize`; baseline, T-A19-601); `.autonomy/checks/A19-P06.lw-ios27.json` (T-A19-609); `.autonomy/checks/A19-P06.app-ui.json` (chunk `a3`, T-A19-610) |
| Accessibility (automated): motion — with motion off or Reduce Motion two frame times give the same picture | Accessibility | verified | `.autonomy/checks/A19-P05.lw-ios27.json` (`SceneRenderTests.withMotionOffTwoFrameTimesGiveTheSamePicture`, `withReduceMotionTwoFrameTimesGiveTheSamePicture`; baseline, T-A19-601); `.autonomy/checks/A19-P06.lw-ios27.json` (T-A19-609) |
| ExperiencesCreative package suites of Living Wallpapers on the iOS 27 simulator (sim-27.2; iOS 26 at X-A19 by owner ruling of 2026-11-14), the slowest test under 10 s; the documented API | Tests | verified | `.autonomy/checks/A19-P05.lw-ios27.json` and `.autonomy/checks/A19-P05.documented-api.json` (baseline, T-A19-601); `.autonomy/checks/A19-P06.lw-ios27.json` (`LivingWallpapersCoreTests`, `LivingWallpapersExperienceTests`) and `.autonomy/checks/A19-P06.documented-api.json` (T-A19-609) |
| App build, unit tests and interface chunk a3 (serial): the iPhone SE template exports with its result line, share link and history; a limit too small shows the notice and exports at the offered size; the editor, the result and their help claim nothing more; an export listed in the history is removed by Clear history | Tests | verified | `.autonomy/checks/A19-P05.app-ui.json` (baseline, T-A19-601); `.autonomy/checks/A19-P06.app-ui.json` (`app-build-for-testing-ios27`, `app-unit-ios27`, `app-ui-ios27-a3`: `LWExportUITests`, `LWClaimsUITests`, `LWHistoryUITests`; T-A19-608, T-A19-610) |
| Experience runner on iOS 27 (standard scenarios) | Tests | verified | `.autonomy/checks/A19-P05.verify-27.json` (baseline, T-A19-601); `.autonomy/checks/A19-P06.verify-27.json` (T-A19-610) |
| Packages, catalog and script tests (the release and copy-claim tools with the new release configuration) | Tests | verified | T-A19-612: `.autonomy/checks/A19-P06.experience-packages.json`, `.autonomy/checks/A19-P06.catalog.json`, `.autonomy/checks/A19-P06.script-tests.json` |
| VisualCore contract: G-RELEASE closed by A19-P06 | Tests | verified | `.autonomy/checks/A19-P06.contract.json` (`scripts/check_app_contract.py --app living-wallpapers --render`, T-A19-612); [visualcore-contract.md](visualcore-contract.md) |
| Release build checks: unsigned Release build, no debug or scenario symbols, manifest, tracking, licenses, usage strings, experience release documents, copy claims | Build | verified | `.autonomy/checks/A19-P06.release-checks.json` (T-A19-611) |
| Build-and-archive instructions for the one app, owner steps marked | Build | verified | [build-and-archive.md](../../release/build-and-archive.md); its agent-run release steps in `.autonomy/checks/A19-P06.release-checks.json` (T-A19-611) |
| The device's size limit (maximum texture size and render size) per device, and the notice for exactly the templates above it | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row LW-D1 "Size limit"; no limit is claimed before device evidence |
| The largest templates (iPad Pro 13-inch (M4) landscape, iPhone 16 Pro Max portrait) export at their size or at the offered size, with no crash | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row LW-D2 "Largest template" |
| The written file's pixel size and sRGB profile in the result line, in Files and in Photos | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row LW-D3 "Written file's size and colour profile" |
| Heat during ten largest exports back to back | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row LW-D4 "Heat during ten largest exports"; no thermal figure is claimed |
| Memory during the largest export: high-water mark and release after the last export | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row LW-D5 "Memory during the largest export"; no memory figure is claimed |
| The add-only Photos prompt shows the app's usage string word for word and never asks for full library access | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row LW-D6 "Add-only Photos prompt"; answering the prompt is an owner action |
| With adding to Photos declined, no app error; Save to Files still writes the file; the history still lists the export | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row LW-D7 "Declined path"; declining is an owner action |
| System accessibility audits of the Living Wallpapers screen, its notice and result rows and its help sheet at the default and the largest text size | Accessibility | pending-campaign-ii | [device-campaign.md](device-campaign.md) row LW-D8 "Accessibility audit", run with `VC_RUN_AUDITS=1`; deferred to the device campaign by owner ruling of 2026-11-13 |
| Signing set-up: team, certificates and provisioning profiles | Distribution | owner-action | `BLOCKED_OWNER_ACTION`: [build-and-archive.md](../../release/build-and-archive.md) section 5 step 1 (create the gitignored `Configs/Signing.local.xcconfig` with `DEVELOPMENT_TEAM`; certificates and profiles in Xcode Settings › Accounts with the owner's Apple ID) and step 2 (final bundle and product identifiers) |
| Archive of the one app | Distribution | owner-action | `BLOCKED_OWNER_ACTION`: [build-and-archive.md](../../release/build-and-archive.md) section 5 step 3 (open `VisualCore.xcodeproj`, scheme `VisualCore`, destination "Any iOS Device (arm64)", Product › Archive) |
| Validation and upload of the archive | Distribution | owner-action | `BLOCKED_OWNER_ACTION`: [build-and-archive.md](../../release/build-and-archive.md) section 5 step 4 (Organizer, Validate App, then Distribute App › App Store Connect › Upload) |

The App Store Connect record, the App Privacy answers (no data collected, no tracking), the store text from
[store-listing.md](store-listing.md), the screenshots and the review submission are further owner steps of the one app
([build-and-archive.md](../../release/build-and-archive.md) section 5 steps 5, 6, 8 and 9), recorded once for the app as
`BLOCKED_OWNER_ACTION`; the agent never does them.

## Accessibility: proved so far and pending for devices

Proved by the experience's tests on the iOS 27 simulator (rows above): every control's label names its value; the
crop frame's label names the device, the orientation and the pixel size; each export outcome is announced once; the
controls stack within the canvas at the largest accessibility text size; still pictures with motion off and under
Reduce Motion. Pending for devices (owner ruling of 2026-11-13: all system accessibility audits wait for device
testing): the system accessibility audits (LW-D8), and the Photos prompt and the declined path on hardware (LW-D6,
LW-D7).

## Artifact inventory

Documents of this phase (all under `docs/apps/living-wallpapers/` unless a path is given):

- `privacy-and-credits.md` — stored data, the temporary export file, what is read, how to delete, permissions, what is
  not done, required-reason APIs, the license inventory (T-A19-602).
- `store-listing.md` — store text input with the claim → proving-test table (T-A19-606).
- `release-checklist.md` — this checklist (T-A19-606).
- `release.json` — release configuration read by `check_experience_release.py` and `release_check.py` (T-A19-606;
  `specs/143-lw-p06-release/data-model.md`).
- `docs/release/known-limitations.md`, section "Living Wallpapers" — no wallpaper setting, no short video in 0.1, the
  export size limits, the approximate safe areas, the stored files and the device-only items (T-A19-606).
- `device-campaign.md` — device measurements LW-D1 … LW-D8 (A19-P05).
- `licenses.md` — licenses of the visual content and the template data (A19-P01).
- `video-decision.md` — the short-video no-go for version 0.1 (A19-P01).
- `docs/release/build-and-archive.md` — app-wide build and owner steps (existing).
- `README.md`, `visualcore-contract.json`, `visualcore-contract.md`, `regression-baseline.md` — existing documents.

Configuration:

- `Configs/copy-claims-denylist.json` — shared copy-claim denylist (unchanged; `copyCheck.allow` `["share"]`).
- `specs/143-lw-p06-release/scan-sources-release.sh` — source scan of Clarifications Q3 (T-A19-603).
- `specs/143-lw-p06-release/scan-claims-release.sh` — refused-word scan of the store text and the interface Swift and
  test-name check of the claim table (T-A19-607).
- `scripts/release_check.py` — serial interface chunk `a3` with `LWExportUITests`, `LWClaimsUITests` and
  `LWHistoryUITests` (T-A19-608).

Code and test artifacts of this phase:

- `Packages/ExperiencesCreative/LivingWallpapers/Experience/WallpaperPresenter.swift` — the test-only `failNextDraw`
  seam (T-A19-604).
- `Packages/ExperiencesCreative/LivingWallpapers/ExperienceTests/WallpaperRecoveryDrawTests.swift` (T-A19-604).
- `Packages/ExperiencesCreative/LivingWallpapers/ExperienceTests/Fixtures/` with `snapshot-{v1,v2,newer,damaged}.json`
  and `history-{current,newer,damaged}.json`, the test target's resources in
  `Packages/ExperiencesCreative/Package.swift`, and `ExperienceTests/StoredSampleTests.swift` (T-A19-605).
- `Apps/VisualCore/Tests/UI/LivingWallpapers/LWHistoryUITests.swift` (T-A19-608).

Evidence files (legacy ledger, stage A19-P06): `lw-no-network`, `experience-release`, `lw-claims`, `lw-ios27`,
`documented-api`, `app-ui`, `verify-27`, `release-checks`, `contract` under `.autonomy/checks/A19-P06.<name>.json`;
sealed evidence of the earlier phases `.autonomy/evidence/A19-P00.json` … `A19-P05.json`; baseline cited from
`.autonomy/checks/A19-P05.{lw-ios27,app-ui,verify-27}.json` (T-A19-601).
