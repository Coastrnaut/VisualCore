# Visual Programming Lab — release checklist and artifact inventory

Visual Programming Lab (`a23.visual-programming-lab`) ships inside the one VisualCore app (ADR-0009); feature 171
(A23-P06), FR-A23-601 to FR-A23-607. App-wide commands are in [build-and-archive.md](../../release/build-and-archive.md).
The statuses are the words that `scripts/check_experience_release.py` accepts for every experience (Clarifications Q1):

- `verified`: the evidence named in the row is a check of the legacy ledger (`.autonomy/checks/A23-P06.<name>.json`,
  recorded with `desktop_runbook.py run-check` before A23-P06 is sealed) or a sealed earlier phase
  (`.autonomy/checks/A23-P0N.*.json`; the A23-P05 runs `.autonomy/checks/A23-P05.{vpl-ios27-2,app-unit-2,verify-27}.json`
  passed on the sources unchanged since commit 4318a204, cited as the baseline by T-A23-601). A row whose check file
  does not exist yet is pending: the task named in the row records it, and A23-P06 is not sealed before every such
  file exists and passed;
- `pending-campaign-ii` (spec: pending device campaign): needs the device campaign D1 → D2 → D3 after
  `ImplementationLock-100`; the row names its rows VPL-D1 … VPL-D6 of [device-campaign.md](device-campaign.md); no
  device number is claimed before then;
- `owner-action` (spec: owner action): done by the owner only, steps in
  [build-and-archive.md](../../release/build-and-archive.md) section 5 (`BLOCKED_OWNER_ACTION` until done); never done
  by the agent (CLAUDE.md rule 6).

`scripts/check_experience_release.py --config docs/apps/visual-programming-lab/release.json` rejects a row without a
known status or without evidence.

| Item | Area | Status | Evidence |
|---|---|---|---|
| Privacy and credits note: what is stored and where (the app's `state.json` with the `LabCore` schema 1 snapshot: graph and selection; `graph-<n>.json`, kind `a23.saved-graph` version 1, at most 81,920 bytes, at most 24 graphs; `library.json`, kind `a23.graph-library` version 1; all in the experience's own storage); no temporary file; nothing is sent; how to delete (Remove in the library; the Settings reset of the experience's data; the reset of all data; deleting the app); no permission is asked; no code is run; the license inventory (made in code only) | Privacy | verified | [privacy-and-credits.md](privacy-and-credits.md) (T-A23-602); [licenses.md](licenses.md); `.autonomy/checks/A23-P06.release-checks.json` (`experience-release-a23`, T-A23-611) |
| No network, tracking, location, sensor, recording, microphone input, camera, photo-library, contacts, pasteboard, share-link, idle-timer or system-brightness use in the experience's sources | Privacy | verified | `.autonomy/checks/A23-P06.scan-sources.json` (`specs/171-vpl-p06-release/scan-sources-release.sh`, T-A23-603) |
| No permission: the registration declares `"permissions": []`, so the experience needs no usage string; the app's usage strings are unchanged | Privacy | verified | `Catalog/registrations.json`; `.autonomy/checks/A23-P06.release-checks.json` (`app-usage-descriptions`, T-A23-611); [privacy-and-credits.md](privacy-and-credits.md) |
| The screen's idle timer and brightness are never changed | Privacy | verified | `.autonomy/checks/A23-P06.scan-sources.json` (`isIdleTimerDisabled` and `brightness =` refused, T-A23-603) |
| No typed code: a graph holds only the seven known node kinds; it is type-checked, sorted and refused (loops, wrong connections, more than 32 nodes, 64 connections or six preview textures) before any pass is compiled or any texture is allocated | Privacy | verified | `.autonomy/checks/A23-P05.vpl-ios27-2.json` (`TypeCheckTests`, `CycleTests`, `EditorTests`, `SlotTests`, `BudgetTests`, `HostCountTests`; baseline, T-A23-601); `.autonomy/checks/A23-P06.vpl-ios27.json` (T-A23-609); `.autonomy/checks/A23-P06.scan-claims.json` ("no code to type" required, T-A23-607) |
| App privacy manifest matches the Release build and covers the experience's required-reason uses | Privacy | verified | `.autonomy/checks/A23-P06.release-checks.json` (`app-privacy-manifest`, T-A23-611); [privacy-and-credits.md](privacy-and-credits.md) |
| No tracking or advertising in the built app | Privacy | verified | `.autonomy/checks/A23-P06.release-checks.json` (`app-no-tracking`, T-A23-611) |
| Licenses and acknowledgements: the three example graphs, the seven node kinds, the preview operators, the canvas grid and the file formats are original code; text uses the system fonts; no third-party code, image, stored texture, font file, model or sound file in the experience; app Licenses folder equals the inventory | Credits | verified | `.autonomy/checks/A23-P06.release-checks.json` (`app-licenses`, T-A23-611); [licenses.md](licenses.md); `ExampleTests.everyExamplePassesTheCheckerAndCompilesWithinTheBudget`, `OperatorPixelTests.mixMatchesItsReference` in `.autonomy/checks/A23-P05.vpl-ios27-2.json` (baseline, T-A23-601) and `.autonomy/checks/A23-P06.vpl-ios27.json` (T-A23-609) |
| Store text input describing only implemented and tested features, with a claim → proving-test table; the phrase "no code to type"; none of the refused words of Clarifications Q2 (no programming-language, typed-code, compatibility, educational, sharing or measured claim) | Store | verified | [store-listing.md](store-listing.md) (T-A23-606); `.autonomy/checks/A23-P06.scan-claims.json` (`specs/171-vpl-p06-release/scan-claims-release.sh`, T-A23-607) |
| Copy check: no measured claim, unmeasured quality word or missing feature in the store text and interface strings (controls, canvas overlay, library view, presenter, adapter); no word allowed | Store | verified | `.autonomy/checks/A23-P06.release-checks.json` (`copy-claims-a23`, T-A23-611; `Configs/copy-claims-denylist.json`); `.autonomy/checks/A23-P06.scan-claims.json` (T-A23-607) |
| Experience release check: required documents present (privacy and credits, store text, checklist, device campaign, licenses, VisualCore contract, build and archive), every checklist row has status and evidence | Store | verified | `.autonomy/checks/A23-P06.release-checks.json` (`experience-release-a23`, T-A23-611) |
| Sample stored files: `snapshot-{v1,newer,damaged}.json` (v1 opens; newer and damaged refused), `graph-sample.json` (A23-P04, opens), `graph-{newer,damaged}.json` (listed as unreadable with `newer-version` and `damaged`), `library-{current,newer,damaged}.json` (current lists; newer makes the library read only; damaged still lists the graphs from their files and is not rewritten by reading); an 81,921-byte graph file is listed as `too-large` and kept; each stays byte-identical | Data | verified | `.autonomy/checks/A23-P05.vpl-ios27-2.json` (`StoredSampleTests`; baseline, T-A23-601); `.autonomy/checks/A23-P06.vpl-ios27.json` (`ReleaseSampleTests`; T-A23-605, T-A23-609) |
| Snapshot: schema 1; the round trip keeps the digest; the digest covers the graph and not the selection; damaged and out-of-range snapshots are refused | Data | verified | `.autonomy/checks/A23-P05.vpl-ios27-2.json` (`LabCoreTests.theSnapshotRoundTripsAndDamagedSnapshotsAreRefused`, `LabCoreTests.theDigestCoversTheGraphButNotTheSelection`, `LabManifestTests.theSaveRestoreStateSurvivesARestore`; baseline, T-A23-601); `.autonomy/checks/A23-P06.vpl-ios27.json` (T-A23-609) |
| Graph library: save, open, rename and remove round-trip; opening over unsaved work asks first; every cap refuses with its message and changes nothing; unreadable files are listed, refused and kept; a full quota writes nothing; a newer index makes the library read only; an older graph file migrates and opens | Data | verified | `.autonomy/checks/A23-P05.vpl-ios27-2.json` (`LibraryTests.saveOpenRenameAndRemoveRoundTrip`, `openingOverUnsavedWorkAsksFirstAndDecliningChangesNothing`; `LibraryRefusalTests.theCountAndNameCapsRefuseAtOnePastAndChangeNothing`, `unreadableFilesAreListedRefusedAndKept`, `aFullQuotaRefusesAndWritesNothing`, `aNewerIndexMakesTheLibraryReadOnly`; `MigrationTests.anOldFileMigratesAndOpens`; baseline, T-A23-601); `.autonomy/checks/A23-P06.vpl-ios27.json` (T-A23-609) |
| Drawing-failure recovery: with two graphs saved, a failed draw (test-only `failNextDraw` seam, `LabDrawError.injected`) fails the session with the message, every storage file is byte-identical, and a new session over the same storage lists and opens both | Recovery | verified | `.autonomy/checks/A23-P06.vpl-ios27.json` (`LabRecoveryDrawTests`; T-A23-604, T-A23-609) |
| Context loss and rebuild recovery: the canvas and the preview are drawn the same after context losses and a resize; ten rebuilds while ready, invalid, refused, failed and hidden; stress cycles return to the level of the first | Recovery | verified | `.autonomy/checks/A23-P05.vpl-ios27-2.json` (`RebuildTests`, `PreviewRebuildTests`, `RecoveryTests`, `StressCycleTests`; baseline, T-A23-601); `.autonomy/checks/A23-P06.vpl-ios27.json` (T-A23-609) |
| Accessibility (automated): spoken labels for nodes, ports, connections, the examples and the library rows, and the experience's summary | Accessibility | verified | `.autonomy/checks/A23-P05.vpl-ios27-2.json` (`EditMessagesTests.nodesAreLabelledByTitleAndIdentity`, `portsAreLabelledWithDirectionTypeAndOptional`, `connectionsAreLabelledFromSourceToTarget`; `TouchTests.thePresenterDeclaresItsCapAndActions`; `ExampleTests.everyExamplePassesTheCheckerAndCompilesWithinTheBudget`; baseline, T-A23-601); `.autonomy/checks/A23-P06.vpl-ios27.json` (T-A23-609) |
| Accessibility (automated): the list form for every connection — every canvas edit can be made without dragging, and the list form sends the same connections as the canvas | Accessibility | verified | `.autonomy/checks/A23-P05.vpl-ios27-2.json` (`TouchTests.theListFormSendsTheSameConnections`, `LabCoreTests.theJourneyGraphIsBuiltByActions`; baseline, T-A23-601); `.autonomy/checks/A23-P05.app-unit-2.json` (`VPLCanvasUITests`, chunk `e3`; baseline); `.autonomy/checks/A23-P06.app-ui.json` (chunk `e3`, T-A23-610) |
| Accessibility (automated): Dynamic Type layout — the library's row buttons stack at accessibility text sizes; the starter's port targets are at least 44 points | Accessibility | verified | `.autonomy/checks/A23-P05.vpl-ios27-2.json` (`LibraryTests.withoutStorageTheLibraryIsUnavailableAndTheExamplesStillOpen`, `TouchTests.starterPortTargetsAreAtLeast44Points`, `CanvasLayoutTests.starterTargetsAtLeast44ScreenPoints`; baseline, T-A23-601); `.autonomy/checks/A23-P06.vpl-ios27.json` (T-A23-609) |
| ExperiencesCreative package suites of Visual Programming Lab on the iOS 27 simulator (sim-27.2; iOS 26 at X-A23 by owner ruling of 2026-11-14), each test under 10 s; the documented API, isolation and core purity | Tests | verified | `.autonomy/checks/A23-P05.vpl-ios27-2.json`, `.autonomy/checks/A23-P05.documented-api-2.json`, `.autonomy/checks/A23-P05.isolation.json`, `.autonomy/checks/A23-P05.core-purity.json` (baseline, T-A23-601); `.autonomy/checks/A23-P06.vpl-ios27.json` (`VisualProgrammingLabCoreTests`, `VisualProgrammingLabExperienceTests`) and `.autonomy/checks/A23-P06.documented-api.json`, `.autonomy/checks/A23-P06.isolation.json`, `.autonomy/checks/A23-P06.core-purity.json` (T-A23-609) |
| App build, unit tests and interface chunk e3 (serial): the list form builds a Mix graph to "Ready"; a mismatched choice shows its sentence; a saved graph survives a relaunch; a fresh start reads "Ready" with `node-row-1` and `node-row-2` present and no `node-row-3`, no `feedback`, and an empty library (no `library-row-graph-1`) | Tests | verified | `.autonomy/checks/A23-P05.app-unit-2.json` (`app-build-for-testing-ios27`, `app-unit-ios27`, `app-ui-ios27-e3`; baseline, T-A23-601); `.autonomy/checks/A23-P06.app-ui.json` (`VPLCanvasUITests`, `VPLRecoveryUITests`, `VPLReleaseUITests`; T-A23-608, T-A23-610) |
| Experience runner on iOS 27 (standard scenarios) | Tests | verified | `.autonomy/checks/A23-P05.verify-27.json` (baseline, T-A23-601); `.autonomy/checks/A23-P06.verify-27.json` (T-A23-612) |
| Packages, catalog and script tests (the release and copy-claim tools with the new release configuration) | Tests | verified | T-A23-612: `.autonomy/checks/A23-P06.experience-packages.json`, `.autonomy/checks/A23-P06.catalog.json`, `.autonomy/checks/A23-P06.realcatalog.json`, `.autonomy/checks/A23-P06.script-tests.json` |
| VisualCore contract: G-RELEASE closed by A23-P06 (all 9 gaps closed; its iOS 26.x runner half cited at X-A23) | Tests | verified | `.autonomy/checks/A23-P06.contract.json` (`scripts/check_app_contract.py --app visual-programming-lab`, T-A23-612); [visualcore-contract.md](visualcore-contract.md) |
| Release build checks: unsigned Release build, no debug or scenario symbols, manifest, tracking, licenses, usage strings, experience release documents, copy claims | Build | verified | `.autonomy/checks/A23-P06.release-checks.json` (T-A23-611) |
| Build-and-archive instructions for the one app, owner steps marked | Build | verified | [build-and-archive.md](../../release/build-and-archive.md); its agent-run release steps in `.autonomy/checks/A23-P06.release-checks.json` (T-A23-611) |
| The largest example's texture memory and pacing: Mixed clouds draws 6 passes, the registry's render-target bytes equal the schedule's, nothing leaks, per device | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) rows VPL-D1-D1 to VPL-D1-D3; no memory or frame figure is claimed before device evidence |
| A graph needing 7 textures refused with its sentence and nothing allocated, per device | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) rows VPL-D2-D1 to VPL-D2-D3 |
| Touch wiring with 44-point port targets at every zoom, a mismatched wire refused, and the same graph built only through the list form, per device | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) rows VPL-D3-D1 to VPL-D3-D3 |
| Pacing under heat and Low Power Mode: the preview keeps animating and stays responsive to edits | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) rows VPL-D4-D1 to VPL-D4-D3; charging, unplugging and Low Power Mode are owner actions; no pacing or thermal figure is claimed beforehand |
| Background and return (context loss): the same graph, picture and preview state come back, the resource level is unchanged and nothing leaks | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) rows VPL-D5-D1 to VPL-D5-D3 |
| System accessibility audits of the Visual Programming Lab screen, the list form and the library, with VoiceOver, at the largest text size and with Reduce Motion | Accessibility | pending-campaign-ii | the device campaign ([device-campaign.md](device-campaign.md) rows VPL-D6-D1 to VPL-D6-D3, run with `VC_RUN_AUDITS=1`); deferred to the device campaign by owner ruling of 2026-11-13 |
| Signing set-up: team, certificates and provisioning profiles | Distribution | owner-action | `BLOCKED_OWNER_ACTION`: [build-and-archive.md](../../release/build-and-archive.md) section 5 step 1 (create the gitignored `Configs/Signing.local.xcconfig` with `DEVELOPMENT_TEAM`; certificates and profiles in Xcode Settings › Accounts with the owner's Apple ID) and step 2 (final bundle and product identifiers) |
| Archive of the one app | Distribution | owner-action | `BLOCKED_OWNER_ACTION`: [build-and-archive.md](../../release/build-and-archive.md) section 5 step 3 (open `VisualCore.xcodeproj`, scheme `VisualCore`, destination "Any iOS Device (arm64)", Product › Archive) |
| Validation and upload of the archive | Distribution | owner-action | `BLOCKED_OWNER_ACTION`: [build-and-archive.md](../../release/build-and-archive.md) section 5 step 4 (Organizer, Validate App, then Distribute App › App Store Connect › Upload) |

The App Store Connect record, the App Privacy answers (no data collected, no tracking), the store text from
[store-listing.md](store-listing.md), the screenshots and the review submission are further owner steps of the one app
([build-and-archive.md](../../release/build-and-archive.md) section 5 steps 5, 6, 8 and 9), recorded once for the app as
`BLOCKED_OWNER_ACTION`; the agent never does them.

## Accessibility: proved so far and pending for devices

Proved by the experience's tests on the iOS 27 simulator (rows above): nodes, ports, connections, examples and library
rows have spoken labels; every canvas edit can be made without dragging in the list form, which sends the same
connections; the library's row buttons stack at accessibility text sizes, and the starter's port targets are at
least 44 points. Pending for devices (owner ruling of 2026-11-13: all system accessibility audits wait for
device testing): the system accessibility audits, VoiceOver, the largest text size and Reduce Motion on the devices
(VPL-D6), and touch wiring by a finger (VPL-D3).

## Artifact inventory

Documents of this phase (all under `docs/apps/visual-programming-lab/` unless a path is given):

- `privacy-and-credits.md` — stored data, no temporary file, what is read, how to delete, no permission, the screen,
  no code is run, what is not done, required-reason APIs, the license inventory (T-A23-602).
- `store-listing.md` — store text input with the claim → proving-test table (T-A23-606).
- `release-checklist.md` — this checklist (T-A23-606).
- `release.json` — release configuration read by `check_experience_release.py` and `release_check.py` (T-A23-606;
  `specs/171-vpl-p06-release/data-model.md`).
- `docs/release/known-limitations.md`, section "Visual Programming Lab" — seven node kinds, at most 32 nodes and 64
  connections, at most six preview textures, no typed code, no sharing or export, and the device-only items
  (T-A23-606).
- `device-campaign.md` — device checks VPL-D1 … VPL-D6 (A23-P05).
- `licenses.md` — licenses of the examples, node kinds, operators, grid and formats (A23-P04).
- `docs/release/build-and-archive.md` — app-wide build and owner steps (existing).
- `README.md`, `visualcore-contract.json`, `visualcore-contract.md`, `regression-baseline.md` — existing documents.

Configuration:

- `Configs/copy-claims-denylist.json` — shared copy-claim denylist (unchanged; `copyCheck.allow` `[]`).
- `specs/171-vpl-p06-release/scan-sources-release.sh` — source scan of Clarifications Q3 (T-A23-603).
- `specs/171-vpl-p06-release/scan-claims-release.sh` — refused-word scan of the store text and the interface Swift,
  the required phrase and the test-name check of the claim table (T-A23-607).
- `scripts/release_check.py` — serial interface chunk `e3` with `VPLCanvasUITests`, `VPLRecoveryUITests` and
  `VPLReleaseUITests` (T-A23-608).

Code and test artifacts of this phase:

- `Packages/ExperiencesCreative/VisualProgrammingLab/Experience/LabPresenter.swift` — the test-only `failNextDraw`
  seam (T-A23-604).
- `Packages/ExperiencesCreative/VisualProgrammingLab/ExperienceTests/LabRecoveryDrawTests.swift` (T-A23-604).
- `Packages/ExperiencesCreative/VisualProgrammingLab/ExperienceTests/Fixtures/` with `snapshot-{v1,newer,damaged}.json`,
  `graph-{newer,damaged}.json` and `library-{current,newer,damaged}.json` beside `graph-sample.json`, and
  `ExperienceTests/ReleaseSampleTests.swift` (T-A23-605).
- `Apps/VisualCore/Tests/UI/VisualProgrammingLab/VPLReleaseUITests.swift` (T-A23-608).

Evidence files (legacy ledger, stage A23-P06): `scan-sources`, `scan-claims`, `vpl-ios27`, `documented-api`,
`isolation`, `core-purity`, `app-ui`, `verify-27`, `release-checks`, `contract`, `experience-packages`, `catalog`,
`realcatalog`, `script-tests` under `.autonomy/checks/A23-P06.<name>.json`; sealed evidence of the earlier phases
`.autonomy/evidence/A23-P00.json` … `A23-P05.json`; baseline cited from
`.autonomy/checks/A23-P05.{vpl-ios27-2,app-unit-2,verify-27}.json` (T-A23-601).
