# Effects Composer — release checklist and artifact inventory

Effects Composer (`a25.effects-composer`) ships inside the one VisualCore app (ADR-0009); feature 185 (A25-P06),
FR-A25-601 to FR-A25-608. App-wide commands are in [build-and-archive.md](../../release/build-and-archive.md). The
statuses are the words that `scripts/check_experience_release.py` accepts for every experience (Clarifications Q1):

- `verified`: the evidence named in the row is a check of the legacy ledger (`.autonomy/checks/A25-P06.<name>.json`,
  recorded with `desktop_runbook.py run-check` before A25-P06 is sealed) or of a sealed earlier phase
  (`.autonomy/checks/A25-P0N.*.json`; the A25-P05 runs `.autonomy/checks/A25-P05.{ec-ios27-3,app-unit-2,verify-27-2}.json`
  passed on the sources cited as the baseline by T-A25-601). A row whose A25-P06 check file does not exist yet is
  pending: the task named in the row records it, and A25-P06 is not sealed before every such file exists and passed;
- `pending-campaign-ii` (spec: pending device campaign): needs the device campaign D1 → D2 → D3 after
  `ImplementationLock-100`; the row names its rows EC-D1 … EC-D7 of [device-campaign.md](device-campaign.md); no
  device number is claimed before then;
- `owner-action` (spec: owner action): done by the owner only, steps in
  [build-and-archive.md](../../release/build-and-archive.md) section 5 (`BLOCKED_OWNER_ACTION` until done); never done
  by the agent (CLAUDE.md rule 6).

`scripts/check_experience_release.py --config docs/apps/effects-composer/release.json` rejects a row without a known
status or without evidence.

| Item | Status | Evidence |
|---|---|---|
| Privacy and credits note: what is stored and where (the app's `state.json` with the `ComposerCore` schema 1 snapshot, the chain file's body; `preset-<n>.json`, kind `a25.preset` version 1, at most 69,632 bytes, embedding the chain file `a25.effect-chain` version 1, at most 24 looks; `presets.json`, kind `a25.preset-library` version 1; all in the experience's own storage); the export files in the temporary folder `EffectsComposer`, written only on an export tap, removed before the next export and when the experience closes; a picked picture held in memory only; nothing is sent automatically; how to delete; the add-only Photos prompt and its usage string; the license inventory (made in code only) | verified | [privacy-and-credits.md](privacy-and-credits.md) (T-A25-602); [licenses.md](licenses.md); `.autonomy/checks/A25-P06.experience-release.json` (`experience-release-a25`, T-A25-606) |
| No network, tracking, location, sensor, recording, microphone input, camera, photo-library, contacts, pasteboard, idle-timer or system-brightness use, no vendor or advertising identifier and not the device's name in the experience's sources; `PhotosUI`, `PhotosPicker` and `ShareLink` only in `Experience/ECControls.swift`, each present there | verified | `.autonomy/checks/A25-P06.scan-sources.json` (`specs/185-ec-p06-release/scan-sources-release.sh`, T-A25-603) |
| A picked picture comes only from the system photo picker the person opens, is decoded off the main thread, held in memory only and never stored; a restored session shows the test picture | verified | `.autonomy/checks/A25-P05.ec-ios27-3.json` (`PictureSourceTests.anImportedPictureBecomesTheSourceAndTheChainAppliesToIt`, `aRestoredSessionShowsTheTestPicture`, `useTestPictureReturnsTheBuiltInPicture`, `aStaleImportFinishingLaterIsDropped`; baseline, T-A25-601); `.autonomy/checks/A25-P04.image-import.json` (`ImageImportTests`); `.autonomy/checks/A25-P06.scan-sources.json` (T-A25-603) |
| An export leaves the device only through the system share sheet the person opens: the file is written only on an export tap, at the picture's full size, tagged sRGB, with the content type of its format; a refused format or size writes nothing | verified | `.autonomy/checks/A25-P05.ec-ios27-3.json` (`StillExportTests.eachFormatWritesADecodableSRGBFile`, `unavailableFormatIsRefusedFirst`, `sizeLimits`, `PresenterExportTests.refusalsBeforeDrawing`, `regressionFixture`; baseline, T-A25-601) |
| Leftover export files: one export file exists at a time (a second export removes the first; a call while exporting is ignored), the export folder is removed when the experience closes, an interrupted export leaves no file, and the export folder, with any file a killed session left in it, is removed before the next export; the share sheet reports no completion, so a shared file stays until then (analyze C2) | verified | `.autonomy/checks/A25-P05.ec-ios27-3.json` (`PresenterExportTests.oneFileAtATime` "a second export removes the first file; a call while exporting is ignored", `PresenterExportTests.closingRemovesTheFolder`, `RobustnessTests.anExportInterruptedByAContextLossLeavesNoFileAndTheNextSucceeds`, `StillExportTests.writeReplacesAndFolderRemoves`; baseline, T-A25-601); [known-limitations](../../release/known-limitations.md) |
| Permission: the registration declares `"permissions": ["photo-library-add"]`; the app's `NSPhotoLibraryAddUsageDescription` reads "Saves exported artwork to your photo library when you choose Save Image."; the photo picker and the share sheet need no usage string; the experience calls no photo-library API | verified | `Catalog/registrations.json`; `.autonomy/checks/A25-P05.app-unit-2.json` (`BundleTests`, `app-unit-ios27`; baseline, T-A25-601); `.autonomy/checks/A25-P06.scan-sources.json` (`PHPhotoLibrary` and `import Photos` refused, T-A25-603) |
| The screen's idle timer and brightness are never changed | verified | `.autonomy/checks/A25-P06.scan-sources.json` (`isIdleTimerDisabled` and `brightness =` refused, T-A25-603) |
| Licenses and acknowledgements: the five effects, their programs and CPU references, the test picture, the pass plan, the renderer, the import, the export, the library and the file formats are original code; system frameworks only; no third-party code, font, image or asset in the experience | verified | [licenses.md](licenses.md) (T-A25-602); `Packages/ExperiencesCreative/Package.swift` (local VisualCore packages only); `.autonomy/checks/A25-P05.isolation.json`; `.autonomy/checks/A25-P06.experience-release.json` (T-A25-606) |
| Store text input describing only implemented and tested features, with a claim → proving-test table naming tests that exist; the phrase "Nothing is sent"; none of the refused words of Clarifications Q2 in the store text, the catalog entry's summary and capabilities and the interface Swift | verified | [store-listing.md](store-listing.md) (T-A25-606); `.autonomy/checks/A25-P06.scan-claims.json` (`specs/185-ec-p06-release/scan-claims-release.sh`, T-A25-607) |
| Copy check: no measured claim, unmeasured quality word or missing feature in the store text and in the interface strings of every Swift file of `Experience/` and `Experience/Adapter/`; only "share" allowed | verified | `.autonomy/checks/A25-P06.experience-release.json` (`copy-claims-a25`, T-A25-606; `Configs/copy-claims-denylist.json`); `.autonomy/checks/A25-P06.scan-claims.json` (T-A25-607) |
| Experience release check: required documents present (privacy and credits, store text, checklist, device campaign, licenses, VisualCore contract, build and archive), every checklist row has status and evidence | verified | `.autonomy/checks/A25-P06.experience-release.json` (`experience-release-a25`, T-A25-606) |
| Catalog entry: summary within 300 characters, true to the built experience, keeps "shader" for the catalog search; capabilities name built features only | verified | `Catalog/registrations.json`; `.autonomy/checks/A25-P06.scan-claims.json` (T-A25-607); `.autonomy/checks/A25-P06.experience-release.json` (T-A25-606) |
| Sample stored files: `snapshot-{v1,newer,damaged}.json` (v1 restores; newer and damaged refused), `preset-{current,newer,damaged}.json` (current opens; newer and damaged listed as unreadable with `newer-version` and `damaged`), `presets-{current,newer,damaged}.json` (current lists; newer makes the library read only; damaged still lists the looks from their files); a look file above 69,632 bytes is listed as `too-large` and kept; each stays byte-identical | verified | `.autonomy/checks/A25-P06.ec-recovery-samples.json` (`ReleaseSampleTests`, `ExperienceTests/Fixtures/`; T-A25-605) |
| Snapshot: schema 1, the chain file's body; the round trip keeps the digest; the digest follows the chain only; a damaged payload is refused; a restored core has an empty history | verified | `.autonomy/checks/A25-P05.ec-ios27-3.json` (`ComposerCoreTests.theSnapshotRoundTripsTheChainAndARestoredCoreHasAnEmptyHistory`, `theDigestFollowsTheChainOnly`, `aDamagedPayloadIsRefused`, `ECManifestTests.theSaveRestoreStateSurvivesARestore`; baseline, T-A25-601); `.autonomy/checks/A25-P06.ec-recovery-samples.json` (T-A25-605) |
| Looks library: save, open, rename and remove round-trip; a 25th save, a taken or bad name and a full storage are refused and change nothing; unreadable files are listed with their reason and kept byte-identical; only Remove deletes a file; a newer index makes the library read only and a damaged index is rebuilt only by the next change; opening a look is one undoable edit | verified | `.autonomy/checks/A25-P05.ec-ios27-3.json` (`LookLibraryTests.saveOpenRenameAndRemoveRoundTrip`, `refusedSavesAndRenamesChangeNothing`, `unreadableFilesAreListedAndKeptByteIdentical`, `aNewerIndexMakesTheLibraryReadOnly`, `aDamagedIndexIsRebuiltOnlyByTheNextChange`, `aFullQuotaRefusesWithTheMessageAndWritesNothing`, `anInvalidChainIsRefusedBeforeWriting`, `PresetPresenterTests.openingAPresetIsOneUndoableEdit`; baseline, T-A25-601) |
| Drawing-failure recovery: with two looks saved, a failed draw (test-only `failNextDraw` seam, `ComposerDrawError.injected`) fails the session with "The picture could not be drawn.", every storage file is byte-identical, and a new session over the same storage lists and opens both | verified | `.autonomy/checks/A25-P06.ec-recovery-samples.json` (`ComposerRecoveryTests.aFailedDrawLeavesTheLooksAndANewSessionOpensThem`; T-A25-604) |
| Context loss, rebuild and memory: ten context rebuilds give a byte-identical result; the source is byte-identical after a context loss; a written export survives a rebuild; two framebuffer sizes letterbox the same result; a memory warning keeps the preview; pooled targets stay bounded and a request above the cap is refused | verified | `.autonomy/checks/A25-P05.ec-ios27-3.json` (`RobustnessTests.tenContextRebuildsGiveAByteIdenticalResult`, `aWrittenExportSurvivesAContextRebuild`, `twoFramebufferSizesLetterboxTheSameResult`, `aMemoryWarningKeepsThePreviewAndDoesNotRaiseTheLiveCount`, `PictureSourceTests.theSourceIsByteIdenticalAfterAContextLoss`, `PoolTests.editsRebuildsAndAResizeLeaveTheLiveCountsAndBytesUnchanged`, `aRequestAboveTheCapIsRefusedBeforeAnythingIsMade`; baseline, T-A25-601) |
| Colour: grade, blur and vignette on linear light values, distort and posterize on stored values; identity chains return the picture within one code value on half-float and 8-bit intermediates; every effect matches its CPU reference | verified | `.autonomy/checks/A25-P05.ec-color-export.json`; `.autonomy/checks/A25-P05.ec-ios27-3.json` (`ColorPathTests`, `ColorDomainTests`, `ProgramRenderTests.theProgramMatchesItsReference`; baseline, T-A25-601) |
| Accessibility (automated): spoken labels for every effect row, its buttons and values, the status, the picture and export buttons and the presets; named actions to move, switch and step each effect; every edit is a button of at least 44 points whose text wraps with Dynamic Type | verified | `.autonomy/checks/A25-P05.ec-ios27-3.json` (`ComposerCoreTests.theSpokenLabelsNameTheEffectItsPositionAndTheValue`, `AccessibilityActionTests.theActionsOfTheFirstAMiddleAndTheLastNode`, `applyingEachChangesTheChainAsNamedAndRedraws`; baseline, T-A25-601); `Experience/ECControls.swift` (`frame(minWidth: 44, minHeight: 44)`); `.autonomy/checks/A25-P06.app-ui.json` (`ECReleaseUITests`, the labels "Export as PNG" and "Use the test picture", T-A25-610) |
| ExperiencesCreative package suites of Effects Composer on the iOS 27 simulator (sim-27.2; iOS 26 at X-A25 by owner ruling of 2026-11-14), each test under 10 s; the documented API, isolation and core purity | verified | `.autonomy/checks/A25-P05.ec-ios27-3.json`, `.autonomy/checks/A25-P05.documented-api.json`, `.autonomy/checks/A25-P05.isolation.json`, `.autonomy/checks/A25-P05.core-purity.json` (baseline, T-A25-601); `.autonomy/checks/A25-P06.ec-recovery-samples.json` (`EffectsComposerExperienceTests`, T-A25-605) |
| App build, unit tests and interface chunk h3 (serial): a fresh start reads "Ready" with no effect row, `export-png`, `export-jpeg`, `export-heic` and `test-picture` present, no `share` and no saved look | verified | `.autonomy/checks/A25-P05.app-unit-2.json` (`app-build-for-testing-ios27`, `app-unit-ios27`; baseline, T-A25-601); `.autonomy/checks/A25-P06.app-ui.json` (`ECReleaseUITests.testAFreshStartIsReadyWithNoEffectNoShareAndNoSavedLook`, `app-ui-ios27-h3`; T-A25-608, T-A25-610) |
| Experience runner on iOS 27 (standard scenarios) | verified | `.autonomy/checks/A25-P05.verify-27-2.json` (baseline, T-A25-601) |
| VisualCore contract: G-RELEASE closed by A25-P06 (all 14 gaps closed; its iOS 26.x runner half cited at X-A25) | verified | `.autonomy/checks/A25-P06.contract.json` (`scripts/check_app_contract.py --app effects-composer`, T-A25-612); `.autonomy/checks/A25-P05.contract.json` (the earlier gaps); [visualcore-contract.md](visualcore-contract.md) |
| Build-and-archive instructions for the one app, owner steps marked | verified | [build-and-archive.md](../../release/build-and-archive.md) |
| Peak memory while editing and exporting a 2,048-pixel picture with eight effects; the rise bounded and released after the export, per device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row EC-D1 (D1, D2, D3); no memory figure is claimed before device evidence |
| Preview frame time while editing, per device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row EC-D2; no frame-time figure is claimed beforehand |
| Export time per format (PNG, JPEG, HEIC where offered), per device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row EC-D3; no export time is claimed beforehand |
| Written file: pixel size, sRGB profile and look of each format in Files and, after Save Image, in Photos (the owner answers the add-only prompt) | pending-campaign-ii | [device-campaign.md](device-campaign.md) row EC-D4; the Photos prompt is an owner action |
| Recovery after backgrounding during an export and while editing | pending-campaign-ii | [device-campaign.md](device-campaign.md) row EC-D5 |
| Heat during ten exports back to back | pending-campaign-ii | [device-campaign.md](device-campaign.md) row EC-D6; no thermal figure is claimed beforehand |
| System accessibility audits of the Effects Composer screen at the default and the largest text size | pending-campaign-ii | [device-campaign.md](device-campaign.md) row EC-D7, run with `VC_RUN_AUDITS=1`; deferred to the device campaign by owner ruling of 2026-11-13 |
| Signing set-up: team, certificates and provisioning profiles | owner-action | `BLOCKED_OWNER_ACTION`: [build-and-archive.md](../../release/build-and-archive.md) section 5 step 1 (create the gitignored `Configs/Signing.local.xcconfig` with `DEVELOPMENT_TEAM`; certificates and profiles in Xcode Settings › Accounts with the owner's Apple ID) and step 2 (final bundle and product identifiers) |
| Archive of the one app | owner-action | `BLOCKED_OWNER_ACTION`: [build-and-archive.md](../../release/build-and-archive.md) section 5 step 3 (open `VisualCore.xcodeproj`, scheme `VisualCore`, destination "Any iOS Device (arm64)", Product › Archive) |
| Validation and upload of the archive | owner-action | `BLOCKED_OWNER_ACTION`: [build-and-archive.md](../../release/build-and-archive.md) section 5 step 4 (Organizer, Validate App, then Distribute App › App Store Connect › Upload) |

The App Store Connect record, the App Privacy answers (no data collected, no tracking), the store text from
[store-listing.md](store-listing.md), the screenshots and the review submission are further owner steps of the one app
([build-and-archive.md](../../release/build-and-archive.md) section 5 steps 5, 6, 8 and 9), recorded once for the app as
`BLOCKED_OWNER_ACTION`; the agent never does them.

The app-wide Release build checks (`app-release-build`, `app-release-symbols`, `app-privacy-manifest`,
`app-no-tracking`, `app-licenses`, `app-usage-descriptions`) are not part of this phase's release checks (T-A25-611
runs `experience-release-a25` and `copy-claims-a25`). They last passed in `.autonomy/checks/A24-P06.release-checks.json`,
before Effects Composer was linked into the app (A25-P02 T-A25-210); the app's privacy manifest, usage strings and
third-party inventory have not changed since, and the experience adds no required-reason use, no usage string and no
third-party component.

## Accessibility: proved so far and pending for devices

Proved by the experience's tests on the iOS 27 simulator (rows above): every effect row, its buttons and values, the
status, the picture and export buttons and the presets have spoken labels; each effect offers named actions; every
edit is a button at least 44 points high whose text wraps with Dynamic Type. Pending for devices (owner ruling of
2026-11-13: all system accessibility audits wait for device testing): the system accessibility audits, VoiceOver and
the largest text size on the devices (EC-D7).

## Artifact inventory

Documents of this phase (all under `docs/apps/effects-composer/` unless a path is given):

- `privacy-and-credits.md` — stored data, the picked picture, the export files, what is read, how to delete, the
  add-only Photos prompt, the screen, what is not done, required-reason APIs, the license inventory (T-A25-602).
- `licenses.md` — licenses of the effects, programs, test picture, formats, texts, VisualCore packages and system
  frameworks (T-A25-602).
- `store-listing.md` — store text input with the claim → proving-test table (T-A25-606).
- `release-checklist.md` — this checklist (T-A25-606).
- `release.json` — release configuration read by `check_experience_release.py` and `release_check.py` (T-A25-606;
  `specs/185-ec-p06-release/data-model.md`).
- `docs/release/known-limitations.md`, section "Effects Composer" — the five effects and the chain's caps, the picture
  sources and the 2,048-pixel limit, the truncated-PNG decode, the export files and the share sheet's missing
  completion, the half-float posterize boundary, and the device-only items (T-A25-606).
- `device-campaign.md` — device checks EC-D1 … EC-D7 (A25-P05).
- `docs/release/build-and-archive.md` — app-wide build and owner steps (existing).
- `README.md`, `visualcore-contract.json`, `visualcore-contract.md`, `regression-baseline.md` — existing documents.

Configuration:

- `Configs/copy-claims-denylist.json` — shared copy-claim denylist (unchanged; `copyCheck.allow` `["share"]`).
- `specs/185-ec-p06-release/scan-sources-release.sh` — source scan of Clarifications Q3 (T-A25-603).
- `specs/185-ec-p06-release/scan-claims-release.sh` — refused-word scan of the store text, the catalog entry and the
  interface Swift, the required phrase and the test-name check of the claim table (T-A25-607).
- `scripts/release_check.py` — serial interface chunk `h3` with `ECReleaseUITests` (T-A25-608).
- `Catalog/registrations.json` — the summary and capabilities of `a25.effects-composer` (T-A25-606).

Code and test artifacts of this phase:

- `Packages/ExperiencesCreative/EffectsComposer/Experience/ComposerPresenter.swift` — the test-only `failNextDraw`
  seam (T-A25-604).
- `Packages/ExperiencesCreative/EffectsComposer/ExperienceTests/ComposerRecoveryTests.swift` (T-A25-604).
- `Packages/ExperiencesCreative/EffectsComposer/ExperienceTests/Fixtures/` with `snapshot-{v1,newer,damaged}.json`,
  `preset-{current,newer,damaged}.json` and `presets-{current,newer,damaged}.json`, and
  `ExperienceTests/ReleaseSampleTests.swift` (T-A25-605).
- `Apps/VisualCore/Tests/UI/EffectsComposer/ECReleaseUITests.swift` (T-A25-608).

Evidence files (legacy ledger, stage A25-P06): `scan-sources`, `scan-claims`, `ec-recovery-samples`, `app-ui`,
`experience-release` under `.autonomy/checks/A25-P06.<name>.json`, with the further checks of T-A25-609 … T-A25-612;
sealed evidence of the earlier phases `.autonomy/evidence/A25-P00.json` … `A25-P05.json`; baseline cited from
`.autonomy/checks/A25-P05.{ec-ios27-3,app-unit-2,verify-27-2}.json` (T-A25-601).
