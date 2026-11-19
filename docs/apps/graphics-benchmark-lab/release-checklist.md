# Graphics Benchmark Lab — release checklist and artifact inventory

Graphics Benchmark Lab (`a24.graphics-benchmark-lab`) ships inside the one VisualCore app (ADR-0009); feature 178
(A24-P06), FR-A24-601 to FR-A24-607. App-wide commands are in
[build-and-archive.md](../../release/build-and-archive.md). The statuses are the words that
`scripts/check_experience_release.py` accepts for every experience (Clarifications Q1):

- `verified`: the evidence named in the row is a check of the legacy ledger (`.autonomy/checks/A24-P06.<name>.json`,
  recorded with `desktop_runbook.py run-check` before A24-P06 is sealed) or a sealed earlier phase
  (`.autonomy/checks/A24-P0N.*.json`; the A24-P05 runs `.autonomy/checks/A24-P05.{gbl-ios27-3,app-ui-3,verify-27}.json`
  passed on the sources unchanged since commit 975f9aa4, cited as the baseline by T-A24-601). A row whose check file
  does not exist yet is pending: the task named in the row records it, and A24-P06 is not sealed before every such
  file exists and passed;
- `pending-campaign-ii` (spec: pending device campaign): needs the device campaign D1 → D2 → D3 after
  `ImplementationLock-100`; the row names its rows GBL-D1 … GBL-D6 of [device-campaign.md](device-campaign.md); no
  device number is claimed before then;
- `owner-action` (spec: owner action): done by the owner only, steps in
  [build-and-archive.md](../../release/build-and-archive.md) section 5 (`BLOCKED_OWNER_ACTION` until done); never done
  by the agent (CLAUDE.md rule 6).

`scripts/check_experience_release.py --config docs/apps/graphics-benchmark-lab/release.json` rejects a row without a
known status or without evidence.

| Item | Area | Status | Evidence |
|---|---|---|---|
| Privacy and credits note: what is stored and where (the app's `state.json` with the `BenchCore` schema 1 snapshot: selected case and the start and stop request counters; `result-<n>.json`, kind `a24.saved-result` version 1, at most 2,162,688 bytes, embedding the run file `a24.benchmark-run` schema 3, at most 12 results; `results.json`, kind `a24.result-library` version 1; all in the experience's own storage); the export files in the temporary folder `GraphicsBenchmarkLab-Export`, written only on the Export tap and removed when the session closes and when the experience opens again; nothing is sent automatically; how to delete (Remove in the results list; the Settings reset of the experience's data; the reset of all data; deleting the app); no permission is asked; device facts from public APIs only; the license inventory (made in code only) | Privacy | verified | [privacy-and-credits.md](privacy-and-credits.md) (T-A24-602); [licenses.md](licenses.md); `.autonomy/checks/A24-P06.release-checks.json` (`experience-release-a24`, T-A24-611) |
| No network, tracking, location, sensor, recording, microphone input, camera, photo-library, contacts, pasteboard, idle-timer or system-brightness use, no vendor or advertising identifier and not the device's name in the experience's sources; `ShareLink` only in `Experience/ResultsView.swift` | Privacy | verified | `.autonomy/checks/A24-P06.scan-sources.json` (`specs/178-gbl-p06-release/scan-sources-release.sh`, T-A24-603); `.autonomy/checks/A24-P05.scan-identifiers.json` |
| An export leaves the device only through the system share sheet the person opens: the file is written only on the Export JSON or Export CSV tap, carries the content type of its format, and the export folder is emptied when the session closes | Privacy | verified | `.autonomy/checks/A24-P05.gbl-ios27-3.json` (`ExportTests.theActionAloneWritesTheJSONAndCSVFiles`, `theShareItemCarriesTheContentTypeOfItsFormat`, `closingTheSessionEmptiesTheExportFolder`; baseline, T-A24-601); `.autonomy/checks/A24-P06.gbl-ios27.json` (T-A24-609) |
| The report's device facts come from public APIs only (model identifier, OS version, bundle version and build, renderer and GL version, quality tier, thermal state and Low Power Mode at the start and the end) | Privacy | verified | `Experience/ReportSource.swift`; `.autonomy/checks/A24-P05.gbl-ios27-3.json` (`ReportTests.aFinishedRunCarriesAValidReportWithEveryFieldFilled`, `theSourceFillsEmptyStringsAndCutsLongOnes`; baseline, T-A24-601); `.autonomy/checks/A24-P06.scan-sources.json` (T-A24-603) |
| No permission: the registration declares `"permissions": []`, so the experience needs no usage string; the share sheet needs none; the app's usage strings are unchanged | Privacy | verified | `Catalog/registrations.json`; `.autonomy/checks/A24-P06.release-checks.json` (`app-usage-descriptions`, T-A24-611); [privacy-and-credits.md](privacy-and-credits.md) |
| The screen's idle timer and brightness are never changed; a serious or critical thermal state ends a run as interrupted | Privacy | verified | `.autonomy/checks/A24-P06.scan-sources.json` (`isIdleTimerDisabled` and `brightness =` refused, T-A24-603); `.autonomy/checks/A24-P05.gbl-ios27-3.json` (`ThermalStopTests.aSeriousOrCriticalThermalStateStopsTheRun`; baseline, T-A24-601) |
| App privacy manifest matches the Release build and covers the experience's required-reason uses | Privacy | verified | `.autonomy/checks/A24-P06.release-checks.json` (`app-privacy-manifest`, T-A24-611); [privacy-and-credits.md](privacy-and-credits.md) |
| No tracking or advertising in the built app | Privacy | verified | `.autonomy/checks/A24-P06.release-checks.json` (`app-no-tracking`, T-A24-611) |
| Licenses and acknowledgements: the three cases, the workload pictures (a texture made in code, the shader ALU pass, the instanced particles), the rules and the file formats are original code; text uses the system fonts; no third-party code, image, stored texture, font file, model or sound file in the experience; app Licenses folder equals the inventory | Credits | verified | `.autonomy/checks/A24-P06.release-checks.json` (`app-licenses`, T-A24-611); [licenses.md](licenses.md); `WorkloadDrawTests.framesZeroAndSixtyAreDrawnDifferAndRepeatOnAnotherHost` in `.autonomy/checks/A24-P05.gbl-ios27-3.json` (baseline, T-A24-601) and `.autonomy/checks/A24-P06.gbl-ios27.json` (T-A24-609) |
| Store text input describing only implemented and tested features, with a claim → proving-test table; the phrase "does not rank devices"; none of the refused words of Clarifications Q2 (no ranking, leaderboard, rigour, platform or other-tool comparison, sending or measured claim) | Store | verified | [store-listing.md](store-listing.md) (T-A24-606); `.autonomy/checks/A24-P06.scan-claims.json` (`specs/178-gbl-p06-release/scan-claims-release.sh`, T-A24-607) |
| Copy check: no measured claim, unmeasured quality word or missing feature in the store text and in the interface strings of every Swift file of `Experience/` and `Experience/Adapter/` (the explanation included); only "share" allowed | Store | verified | `.autonomy/checks/A24-P06.release-checks.json` (`copy-claims-a24`, T-A24-611; `Configs/copy-claims-denylist.json`); `.autonomy/checks/A24-P06.scan-claims.json` (T-A24-607); `.autonomy/checks/A24-P05.copy-explanation-2.json` |
| Experience release check: required documents present (privacy and credits, store text, checklist, device campaign, licenses, VisualCore contract, build and archive), every checklist row has status and evidence | Store | verified | `.autonomy/checks/A24-P06.release-checks.json` (`experience-release-a24`, T-A24-611) |
| Sample stored files: `snapshot-{v1,newer,damaged}.json` (v1 restores; newer and damaged refused), `result-{current,newer,damaged}.json` (current opens; newer and damaged listed as unreadable with `newer-version` and `damaged`), `results-{current,newer,damaged}.json` (current lists; newer makes the library read only; damaged still lists the result and is not rewritten by reading); a 2,162,689-byte result file is listed as `too-large` and kept; each stays byte-identical | Data | verified | `.autonomy/checks/A24-P06.gbl-ios27.json` (`ReleaseSampleTests`; T-A24-605, T-A24-609) |
| Snapshot: schema 1; the round trip keeps the digest; the digest covers the selected case only; damaged and out-of-range snapshots are refused; a restored snapshot never resumes a run | Data | verified | `.autonomy/checks/A24-P05.gbl-ios27-3.json` (`BenchCoreTests.aSnapshotRoundTrips`, `theDigestCoversTheSelectedCaseOnly`, `damagedAndOutOfRangeSnapshotsAreRefused`, `GBLManifestTests.theSaveRestoreStateSurvivesARestore`, `RecorderTests.aRestoredSnapshotNeverResumesARun`; baseline, T-A24-601); `.autonomy/checks/A24-P06.gbl-ios27.json` (T-A24-609) |
| Result library: save and open round-trip; the ended run is saved once; a 13th save and a full storage are refused and change nothing; unreadable files are listed with their reason and kept; only Remove deletes a file; a newer index makes the library read only and a damaged index is rebuilt only by a change; the run file migrates from older versions | Data | verified | `.autonomy/checks/A24-P05.gbl-ios27-3.json` (`ResultLibraryTests.aSavedRunOpensInANewLibraryEqualToTheOriginal`, `thePresenterSavesTheEndedRunOnceAndANewPresenterOpensIt`, `theThirteenthSaveIsRefusedAndNothingChanges`, `aFullStorageRefusesWithTheMessageAndWritesNothing`, `unreadableFilesAreListedWithTheirReasonAndKept`, `aRemovalDeletesOnlyTheChosenFile`, `aNewerIndexIsReadOnlyAndADamagedIndexIsRebuiltOnlyByAChange`; `RunDocumentTests.migrationChainEndsAtVersionThree`; baseline, T-A24-601); `.autonomy/checks/A24-P06.gbl-ios27.json` (T-A24-609) |
| Drawing-failure recovery: with two results saved, a failed draw (test-only `failNextDraw` seam, `BenchDrawError.injected`) fails the session with the message, every storage file is byte-identical, and a new session over the same storage lists and opens both | Recovery | verified | `.autonomy/checks/A24-P06.gbl-ios27.json` (`BenchRecoveryDrawTests.aFailedDrawLeavesTheResultsAndANewSessionOpensThem`; T-A24-604, T-A24-609) |
| Context loss, rebuild and interruption: ten recreations give the same picture with nothing leaked; a resize there and back gives the same picture; a context rebuild, the session closing or leaving the app mid-run ends the run as interrupted with its samples kept | Recovery | verified | `.autonomy/checks/A24-P05.gbl-ios27-3.json` (`RebuildTests`, `RecorderTests.aContextRebuildMidRunGivesInterruptedWithTheSamplesKept`, `closingTheSessionMidRunGivesInterrupted`; baseline, T-A24-601); `.autonomy/checks/A24-P05.app-ui-3.json` (`GBLRunUITests.testLeavingTheAppMidRunEndsItAsInterrupted`; baseline); `.autonomy/checks/A24-P06.gbl-ios27.json` (T-A24-609) |
| Accessibility (automated): spoken labels for the cases, the run buttons, the status, the summary, the result rows (case, state, percentiles, GPU timed, class) and the qualification; the explanation's title and section titles are headings | Accessibility | verified | `.autonomy/checks/A24-P05.gbl-ios27-3.json` (`ResultLibraryTests.aSavedRunOpensInANewLibraryEqualToTheOriginal`, `QualificationDisplayTests.theListAndTheOpenedResultShowTheClassAndTheSentences`, `RecorderTests.aRunThroughThePresenterMeasuresTheCPUTimeAndSaysGPUTimeIsNotAvailable`, `ExplanationTests.theExplanationHasTheFiveSectionsInOrder`; baseline, T-A24-601); `.autonomy/checks/A24-P05.app-ui-3.json` (`GBLRunUITests`, chunk `f3`, spoken status and headings; baseline); `.autonomy/checks/A24-P06.app-ui.json` (chunk `f3`, T-A24-610) |
| Accessibility (automated): Dynamic Type layout — every button of the controls and the results is at least 44 points high and its text wraps with Dynamic Type (`GBLControls.swift`, `ResultsView.swift`); the journeys reach every control by its identifier at the default text size | Accessibility | verified | `Experience/GBLControls.swift`, `Experience/ResultsView.swift` (`frame(minHeight: 44)`); `.autonomy/checks/A24-P05.app-ui-3.json` (`GBLRunUITests`; baseline); `.autonomy/checks/A24-P06.app-ui.json` (`GBLReleaseUITests`, T-A24-610); the largest text size on devices is row GBL-D6 |
| ExperiencesCreative package suites of Graphics Benchmark Lab on the iOS 27 simulator (sim-27.2; iOS 26 at X-A24 by owner ruling of 2026-11-14), each test under 10 s; the documented API, isolation and core purity | Tests | verified | `.autonomy/checks/A24-P05.gbl-ios27-3.json`, `.autonomy/checks/A24-P05.documented-api-2.json`, `.autonomy/checks/A24-P05.isolation.json`, `.autonomy/checks/A24-P05.core-purity.json` (baseline, T-A24-601); `.autonomy/checks/A24-P06.gbl-ios27.json` (`GraphicsBenchmarkLabCoreTests`, `GraphicsBenchmarkLabExperienceTests`) and `.autonomy/checks/A24-P06.documented-api.json`, `.autonomy/checks/A24-P06.isolation.json`, `.autonomy/checks/A24-P06.core-purity.json` (T-A24-609) |
| App build, unit tests and interface chunk f3 (serial): a quads run finishes and its result opens with its explanation; leaving the app mid-run ends it as interrupted; a fresh start reads "Ready" with `case-quads` selected, no `qualification`, and, after `results`, "No saved results." with no `result-row-1` | Tests | verified | `.autonomy/checks/A24-P05.app-ui-3.json` (`app-build-for-testing-ios27`, `app-unit-ios27`, `app-ui-ios27-f3`; baseline, T-A24-601); `.autonomy/checks/A24-P06.app-ui.json` (`GBLRunUITests`, `GBLReleaseUITests.testAFreshStartIsReadyOnQuadsWithNoResults`; T-A24-608, T-A24-610) |
| Experience runner on iOS 27 (standard scenarios) | Tests | verified | `.autonomy/checks/A24-P05.verify-27.json` (baseline, T-A24-601); `.autonomy/checks/A24-P06.verify-27.json` (T-A24-612) |
| Packages, catalog and script tests (the release and copy-claim tools with the new release configuration) | Tests | verified | T-A24-612: `.autonomy/checks/A24-P06.experience-packages.json`, `.autonomy/checks/A24-P06.catalog.json`, `.autonomy/checks/A24-P06.realcatalog.json`, `.autonomy/checks/A24-P06.script-tests.json` |
| VisualCore contract: G-RELEASE closed by A24-P06 (all 12 gaps closed; its iOS 26.x runner half cited at X-A24) | Tests | verified | `.autonomy/checks/A24-P06.contract.json` (`scripts/check_app_contract.py --app graphics-benchmark-lab`, T-A24-612); [visualcore-contract.md](visualcore-contract.md) |
| Release build checks: unsigned Release build, no debug or scenario symbols, manifest, tracking, licenses, usage strings, experience release documents, copy claims | Build | verified | `.autonomy/checks/A24-P06.release-checks.json` (T-A24-611) |
| Build-and-archive instructions for the one app, owner steps marked | Build | verified | [build-and-archive.md](../../release/build-and-archive.md); its agent-run release steps in `.autonomy/checks/A24-P06.release-checks.json` (T-A24-611) |
| Repeatability on hardware: 5 trials of each case, the comparable trials and their spread read in the repeatability view, per device | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) rows GBL-D1-D1 to GBL-D1-D3; no interval, spread or GPU figure is claimed before device evidence |
| Thermal behaviour: a back-to-back Particles series names the thermal state at the start and the end; a changed state qualifies the run; a serious or critical state ends it as "Interrupted: the device is hot", per device | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) rows GBL-D2-D1 to GBL-D2-D3; charging and unplugging are owner actions; no thermal figure is claimed beforehand |
| Low Power Mode: the report shows it as set and a run with it on is qualified, per device | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) rows GBL-D3-D1 to GBL-D3-D3; Low Power Mode on and off is an owner action |
| Pacing and dropped frames: at most 60 frames per second whatever the display's refresh; a frame counts as dropped only above the threshold; a run with dropped frames is qualified, per device | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) rows GBL-D4-D1 to GBL-D4-D3; no pacing figure is claimed beforehand |
| GPU timing on hardware: the timer probe's result, finite GPU times below their frame interval on measured frames only, the disjoint count; without a timer no GPU time is shown or exported | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) rows GBL-D5-D1 to GBL-D5-D3 |
| System accessibility audits of the Graphics Benchmark Lab screen, the results, the repeatability view and "About these numbers", with VoiceOver and at the largest text size | Accessibility | pending-campaign-ii | the device campaign ([device-campaign.md](device-campaign.md) rows GBL-D6-D1 to GBL-D6-D3, run with `VC_RUN_AUDITS=1`); deferred to the device campaign by owner ruling of 2026-11-13 |
| Signing set-up: team, certificates and provisioning profiles | Distribution | owner-action | `BLOCKED_OWNER_ACTION`: [build-and-archive.md](../../release/build-and-archive.md) section 5 step 1 (create the gitignored `Configs/Signing.local.xcconfig` with `DEVELOPMENT_TEAM`; certificates and profiles in Xcode Settings › Accounts with the owner's Apple ID) and step 2 (final bundle and product identifiers) |
| Archive of the one app | Distribution | owner-action | `BLOCKED_OWNER_ACTION`: [build-and-archive.md](../../release/build-and-archive.md) section 5 step 3 (open `VisualCore.xcodeproj`, scheme `VisualCore`, destination "Any iOS Device (arm64)", Product › Archive) |
| Validation and upload of the archive | Distribution | owner-action | `BLOCKED_OWNER_ACTION`: [build-and-archive.md](../../release/build-and-archive.md) section 5 step 4 (Organizer, Validate App, then Distribute App › App Store Connect › Upload) |

The App Store Connect record, the App Privacy answers (no data collected, no tracking), the store text from
[store-listing.md](store-listing.md), the screenshots and the review submission are further owner steps of the one app
([build-and-archive.md](../../release/build-and-archive.md) section 5 steps 5, 6, 8 and 9), recorded once for the app as
`BLOCKED_OWNER_ACTION`; the agent never does them.

## Accessibility: proved so far and pending for devices

Proved by the experience's tests on the iOS 27 simulator (rows above): the cases, the run buttons, the status, the
summary, the result rows and the qualification have spoken labels; the explanation's title and section titles are
headings; every button is at least 44 points high and its text wraps with Dynamic Type. Pending for devices (owner
ruling of 2026-11-13: all system accessibility audits wait for device testing): the system accessibility audits,
VoiceOver and the largest text size on the devices (GBL-D6).

## Artifact inventory

Documents of this phase (all under `docs/apps/graphics-benchmark-lab/` unless a path is given):

- `privacy-and-credits.md` — stored data, the export files, what is read and the device facts, how to delete, no
  permission, the screen, what is not done, required-reason APIs, the license inventory (T-A24-602).
- `licenses.md` — licenses of the cases, workload pictures, rules, texts and formats (T-A24-602).
- `store-listing.md` — store text input with the claim → proving-test table (T-A24-606).
- `release-checklist.md` — this checklist (T-A24-606).
- `release.json` — release configuration read by `check_experience_release.py` and `release_check.py` (T-A24-606;
  `specs/178-gbl-p06-release/data-model.md`).
- `docs/release/known-limitations.md`, section "Graphics Benchmark Lab" — three cases, a run of its plan, at most 12
  saved results, GPU time only where the timer exists, simulator numbers, a hot device ends a run, no ranking or
  comparison, and the device-only items (T-A24-606).
- `device-campaign.md` — device checks GBL-D1 … GBL-D6 (A24-P05).
- `docs/release/build-and-archive.md` — app-wide build and owner steps (existing).
- `README.md`, `visualcore-contract.json`, `visualcore-contract.md`, `regression-baseline.md` — existing documents.

Configuration:

- `Configs/copy-claims-denylist.json` — shared copy-claim denylist (unchanged; `copyCheck.allow` `["share"]`).
- `specs/178-gbl-p06-release/scan-sources-release.sh` — source scan of Clarifications Q3 (T-A24-603).
- `specs/178-gbl-p06-release/scan-claims-release.sh` — refused-word scan of the store text and the interface Swift,
  the required phrase and the test-name check of the claim table (T-A24-607).
- `scripts/release_check.py` — serial interface chunk `f3` with `GBLRunUITests` and `GBLReleaseUITests` (T-A24-608).

Code and test artifacts of this phase:

- `Packages/ExperiencesCreative/GraphicsBenchmarkLab/Experience/BenchPresenter.swift` — the test-only `failNextDraw`
  seam (T-A24-604).
- `Packages/ExperiencesCreative/GraphicsBenchmarkLab/ExperienceTests/BenchRecoveryDrawTests.swift` (T-A24-604).
- `Packages/ExperiencesCreative/GraphicsBenchmarkLab/ExperienceTests/Fixtures/` with `snapshot-{v1,newer,damaged}.json`,
  `result-{current,newer,damaged}.json` and `results-{current,newer,damaged}.json`, and
  `ExperienceTests/ReleaseSampleTests.swift` (T-A24-605).
- `Apps/VisualCore/Tests/UI/GraphicsBenchmarkLab/GBLReleaseUITests.swift` (T-A24-608).

Evidence files (legacy ledger, stage A24-P06): `scan-sources`, `scan-claims`, `gbl-ios27`, `documented-api`,
`isolation`, `core-purity`, `app-ui`, `verify-27`, `release-checks`, `contract`, `experience-packages`, `catalog`,
`realcatalog`, `script-tests` under `.autonomy/checks/A24-P06.<name>.json`; sealed evidence of the earlier phases
`.autonomy/evidence/A24-P00.json` … `A24-P05.json`; baseline cited from
`.autonomy/checks/A24-P05.{gbl-ios27-3,app-ui-3,verify-27}.json` (T-A24-601).
