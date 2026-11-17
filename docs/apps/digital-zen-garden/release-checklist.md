# Digital Zen Garden — release checklist and artifact inventory

Digital Zen Garden (`a20.digital-zen-garden`) ships inside the one VisualCore app (ADR-0009); feature 150 (A20-P06),
FR-A20-601 to FR-A20-607. App-wide commands are in [build-and-archive.md](../../release/build-and-archive.md). The
statuses are the words that `scripts/check_experience_release.py` accepts for every experience (Clarifications Q1):

- `verified`: the evidence named in the row is a check of the legacy ledger (`.autonomy/checks/A20-P06.<name>.json`,
  recorded with `desktop_runbook.py run-check` before A20-P06 is sealed) or a sealed earlier phase
  (`.autonomy/checks/A20-P0N.*.json`; the A20-P05 runs `.autonomy/checks/A20-P05.{zg-ios27,app-ui,verify-27}.json`
  passed on the sources unchanged since the A20-P05 record commit 1b4b6289, cited as the baseline by T-A20-601). A
  row whose check file does not exist yet is pending: the task named in the row records it, and A20-P06 is not sealed
  before every such file exists and passed;
- `pending-campaign-ii` (spec: pending device campaign): needs the device campaign D1 → D2 → D3 after
  `ImplementationLock-100`; the row names its row ZG-D1 … ZG-D8 of [device-campaign.md](device-campaign.md); no
  device number is claimed before then;
- `owner-action` (spec: owner action): done by the owner only, steps in
  [build-and-archive.md](../../release/build-and-archive.md) section 5 (`BLOCKED_OWNER_ACTION` until done); never done
  by the agent (CLAUDE.md rule 6).

`scripts/check_experience_release.py --config docs/apps/digital-zen-garden/release.json` rejects a row without a known
status or without evidence.

| Item | Area | Status | Evidence |
|---|---|---|---|
| Privacy and credits note: what is stored and where (the app's `state.json` with the schema 1 snapshot of the open garden document; the named-garden library `garden-<n>.json`, at most 12, and `library.json`; the calm switches as the experience value `calm.v1`; each replaced on change and removed when the app is deleted), the temporary folder `DigitalZenGarden-Still` with at most one PNG, nothing sent, how to delete (Delete in the library; the Settings reset of the experience's data; the reset of all data; deleting the app); the add-only Photos string and when the system asks it; the license inventory (code only) | Privacy | verified | [privacy-and-credits.md](privacy-and-credits.md) (T-A20-602); [licenses.md](licenses.md); `.autonomy/checks/A20-P06.release-checks.json` (`experience-release-a20`, T-A20-611) |
| No network, tracking, sensor, recording, microphone input, photo-library, Photos picker, image-picker, idle-timer or system-brightness use in the experience's sources | Privacy | verified | `.autonomy/checks/A20-P06.zg-no-network.json` (`specs/150-zg-p06-release/scan-sources-release.sh`, T-A20-603); `.autonomy/checks/A20-P04.photos-scan.json` and `.autonomy/checks/A20-P05.photos-scan.json` |
| One permission: the app's add-only usage string `NSPhotoLibraryAddUsageDescription` "Saves exported artwork to your photo library when you choose Save Image.", asked by the system only when the person chooses Save Image in the share sheet; the registration declares `"permissions": ["photo-library-add"]` | Privacy | verified | `.autonomy/checks/A20-P04.usage.json` (`app-usage-descriptions`); `.autonomy/checks/A20-P06.release-checks.json` (`app-usage-descriptions`, T-A20-611); `Catalog/registrations.json`; `project.yml`; [privacy-and-credits.md](privacy-and-credits.md) |
| The picture leaves the app only through the share sheet; the temporary folder holds at most one file, replaced by the next picture; a failed picture leaves no file | Privacy | verified | `.autonomy/checks/A20-P05.zg-ios27.json` (`StillTests.aStillIsA1600By1200PNGAndASecondExportReplacesIt`, `aFailedExportLeavesNoFile`, `theSessionsStillRendererDrawsTheGardenForTheShareControl`; baseline, T-A20-601); `.autonomy/checks/A20-P06.zg-ios27.json` (T-A20-609) |
| App privacy manifest matches the Release build and covers the experience's required-reason uses | Privacy | verified | `.autonomy/checks/A20-P06.release-checks.json` (`app-privacy-manifest`, T-A20-611); [privacy-and-credits.md](privacy-and-credits.md) |
| No tracking or advertising in the built app | Privacy | verified | `.autonomy/checks/A20-P06.release-checks.json` (`app-no-tracking`, T-A20-611) |
| Licenses and acknowledgements: visuals and tones made in code (relief and stone shaders, procedural tones, original code; tones, rakes and stone kinds as numbers; text in the system font); no third-party code, image, texture, font file, model or sound file in the experience; app Licenses folder equals the inventory | Credits | verified | `.autonomy/checks/A20-P06.release-checks.json` (`app-licenses`, T-A20-611); [licenses.md](licenses.md); `PaletteTests.theTwoRakesDiffer`, `PaletteTests.theStoneKindsAreFiveWithRadiiInRange`, `CalmTests.theTonesAreQuietLowAndShort` in `.autonomy/checks/A20-P05.zg-ios27.json` (baseline, T-A20-601) and `.autonomy/checks/A20-P06.zg-ios27.json` (T-A20-609) |
| Store text input describing only implemented and tested features, with a claim → proving-test table; "sound", never the refused words; no physics, health or measured claim and none of the refused words of Clarifications Q2 | Store | verified | [store-listing.md](store-listing.md) (T-A20-606); `.autonomy/checks/A20-P06.zg-claims.json` (`specs/150-zg-p06-release/scan-claims-release.sh`, T-A20-607) |
| Copy check: no measured claim, unmeasured quality word or missing feature in the store text and interface strings (controls, presenter, adapter, picture); only "share" allowed | Store | verified | `.autonomy/checks/A20-P06.release-checks.json` (`copy-claims-a20`, T-A20-611; `Configs/copy-claims-denylist.json`); `.autonomy/checks/A20-P06.zg-claims.json` (T-A20-607) |
| Experience release check: required documents present (privacy and credits, store text, checklist, device campaign, licenses, VisualCore contract, build and archive), every checklist row has status and evidence | Store | verified | `.autonomy/checks/A20-P06.release-checks.json` (`experience-release-a20`, T-A20-611) |
| Sample stored files: `snapshot-{v1,newer,damaged}.json` (v1 restores; newer and damaged refused), `garden-{current,newer,damaged}.json` (current listed and opens; newer and damaged listed unreadable with `newer-version` and `damaged`) and `library-{current,newer,damaged}.json` (current lists two gardens; newer makes the library read only; damaged not rewritten by reading); each stays byte-identical | Data | verified | `.autonomy/checks/A20-P06.zg-ios27.json` (`StoredSampleTests`; T-A20-605, T-A20-609) |
| Snapshot: schema 1, the garden document only; the round trip keeps the digest; a refused file leaves the open garden unchanged | Data | verified | `.autonomy/checks/A20-P05.zg-ios27.json` (`GardenCoreTests.theSnapshotIsTheGardenDocumentOnly`; `GardenManifestTests.theSaveRestoreStateSurvivesARestore`; `DocumentTests.theRoundTripIsExact`, `aRefusalLeavesTheOpenGardenUnchanged`; baseline, T-A20-601); `.autonomy/checks/A20-P06.zg-ios27.json` (T-A20-609) |
| Named gardens: save and open round trip; list, rename and delete; at most 12; names 1 to 40 characters; refused files listed with their codes, never opened and kept; a failed write keeps the previous file; a damaged index is rebuilt and a newer index is read only | Data | verified | `.autonomy/checks/A20-P05.zg-ios27.json` (`LibraryTests.aSaveAndOpenRoundTripIsExact`, `listRenameAndDelete`, `theLibraryHoldsTwelveGardens`, `namesAreTrimmedAndOneToFortyCharacters`, `refusedFilesAreListedWithTheirCodesNeverOpenedAndKept`, `aFailedWriteKeepsThePreviousFile`, `aDamagedIndexIsRebuiltAndANewerIndexIsReadOnly`; baseline, T-A20-601); `.autonomy/checks/A20-P06.zg-ios27.json` (T-A20-609) |
| Calm switches: sound, sand drift and haptics off by default; a refused or damaged value changes nothing; kept across a reopen as `calm.v1`; the digest is unchanged by them | Data | verified | `.autonomy/checks/A20-P05.zg-ios27.json` (`CalmTests.theSwitchesAreOffByDefault`, `aRefusedSwitchValueChangesNothing`, `aDamagedValueIsIgnored`, `theSwitchesAreKeptAcrossAReopen`, `theDigestIsUnchangedByTheSwitches`; baseline, T-A20-601); `.autonomy/checks/A20-P06.zg-ios27.json` (T-A20-609) |
| Undo history: every command kind applies and undoes exactly; beyond 100 commands the oldest fold into the checkpoint; ten thousand commands stay within the bounds | Data | verified | `.autonomy/checks/A20-P05.zg-ios27.json` (`HistoryTests.eachCommandKindAppliesAndUndoesExactly`; `ReplayFixtureTests.beyondOneHundredCommandsTheOldestFoldIntoTheCheckpoint`; `BoundedHistoryTests.tenThousandCommandsStayWithinTheBounds`; baseline, T-A20-601); `.autonomy/checks/A20-P06.zg-ios27.json` (T-A20-609) |
| Drawing-failure recovery: with two gardens saved, a failed draw fails the session with the injected message, `library.json` and both garden files are byte-identical, and a new session over the same storage lists both | Recovery | verified | `.autonomy/checks/A20-P06.zg-ios27.json` (`GardenRecoveryDrawTests`, test-only `failNextDraw` seam; T-A20-604, T-A20-609) |
| Accessibility (automated): every control has a spoken label and value; undo, redo, library, picture and refusals are announced; at the largest accessibility text size the controls stack within the canvas; every gesture action has a native alternative | Accessibility | verified | `.autonomy/checks/A20-P05.zg-ios27.json` (`AccessibilityTests.everyControlHasASpokenLabelAndValue`, `undoRedoLibraryPictureAndRefusalsAreAnnounced`, `atAccessibilityFiveTheControlsStackWithinTheCanvas`; `PointerPathTests.everyGestureActionHasANativeAlternative`; baseline, T-A20-601); `.autonomy/checks/A20-P06.zg-ios27.json` (T-A20-609); `.autonomy/checks/A20-P06.app-ui.json` (chunk `b3`, T-A20-610) |
| Accessibility (automated): motion — with the drift off, or on under Reduce Motion, two frames are identical; reduce flashing leaves the picture the same | Accessibility | verified | `.autonomy/checks/A20-P05.zg-ios27.json` (`ReducedMotionTests.withTheDriftOffTwoFramesAreIdenticalAndTheStillFrameIsReused`, `withTheDriftOnUnderReduceMotionTwoFramesAreIdentical`, `reduceFlashingLeavesThePictureTheSame`; baseline, T-A20-601); `.autonomy/checks/A20-P06.zg-ios27.json` (T-A20-609) |
| ExperiencesCreative package suites of Digital Zen Garden on the iOS 27 simulator (sim-27.2; iOS 26 at X-A20 by owner ruling of 2026-11-14), each test under 10 s; the documented API | Tests | verified | `.autonomy/checks/A20-P05.zg-ios27.json` and `.autonomy/checks/A20-P05.documented-api.json` (baseline, T-A20-601); `.autonomy/checks/A20-P06.zg-ios27.json` (`DigitalZenGardenCoreTests`, `DigitalZenGardenExperienceTests`) and `.autonomy/checks/A20-P06.documented-api.json` (T-A20-609) |
| App build, unit tests and interface chunk b3 (serial): raking rows adds a stroke and Undo takes it back; a placed pebble is removed and Undo restores it; a garden saved as Evening opens with its stroke; a fresh start shows the three calm switches off and Make picture reports 1600 by 1200 pixels with the share control | Tests | verified | `.autonomy/checks/A20-P05.app-ui.json` (baseline, T-A20-601); `.autonomy/checks/A20-P06.app-ui.json` (`app-build-for-testing-ios27`, `app-unit-ios27`, `app-ui-ios27-b3`: `ZGGardenUITests`, `ZGLibraryUITests`, `ZGReleaseUITests`; T-A20-608, T-A20-610) |
| Experience runner on iOS 27 (standard scenarios) | Tests | verified | `.autonomy/checks/A20-P05.verify-27.json` (baseline, T-A20-601); `.autonomy/checks/A20-P06.verify-27.json` (T-A20-610) |
| Packages, catalog and script tests (the release and copy-claim tools with the new release configuration) | Tests | verified | T-A20-612: `.autonomy/checks/A20-P06.experience-packages.json`, `.autonomy/checks/A20-P06.catalog.json`, `.autonomy/checks/A20-P06.script-tests.json` |
| VisualCore contract: G-RELEASE closed by A20-P06 (its iOS 26.x runner half cited at X-A20) | Tests | verified | `.autonomy/checks/A20-P06.contract.json` (`scripts/check_app_contract.py --app digital-zen-garden --render`, T-A20-612); [visualcore-contract.md](visualcore-contract.md) |
| Release build checks: unsigned Release build, no debug or scenario symbols, manifest, tracking, licenses, usage strings, experience release documents, copy claims | Build | verified | `.autonomy/checks/A20-P06.release-checks.json` (T-A20-611) |
| Build-and-archive instructions for the one app, owner steps marked | Build | verified | [build-and-archive.md](../../release/build-and-archive.md); its agent-run release steps in `.autonomy/checks/A20-P06.release-checks.json` (T-A20-611) |
| Touch-to-groove latency on hardware | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row ZG-D1 "Touch-to-groove latency"; no latency is claimed before device evidence |
| Coalesced touches and fast drags: grooves continuous on hardware | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row ZG-D2 "Coalesced touches and fast drags" |
| Idle drawing with the quiet defaults, with drift on, and with drift on under Reduce Motion | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row ZG-D3 "Idle drawing" |
| Heat during ten minutes of raking | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row ZG-D4 "Heat during ten minutes of raking"; no thermal figure is claimed |
| Energy use during a long session | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row ZG-D5; recorded only, no claim is made from it |
| Precision on the smallest phone (fine rake, a stone between grooves, the topmost of two stones, a small turn) | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row ZG-D6 "Precision on the smallest phone" |
| Quiet defaults and the silent switch: nothing sounds, moves or vibrates by default; the tones follow the silent switch; the switches are restored after reopening | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row ZG-D7 "Quiet defaults and the silent switch"; the switches are owner actions |
| System accessibility audits of the Digital Zen Garden screen, its controls, the library and the calm switches at the default and the largest text size | Accessibility | pending-campaign-ii | [device-campaign.md](device-campaign.md) row ZG-D8 "Accessibility audit", run with `VC_RUN_AUDITS=1`; deferred to the device campaign by owner ruling of 2026-11-13 |
| Signing set-up: team, certificates and provisioning profiles | Distribution | owner-action | `BLOCKED_OWNER_ACTION`: [build-and-archive.md](../../release/build-and-archive.md) section 5 step 1 (create the gitignored `Configs/Signing.local.xcconfig` with `DEVELOPMENT_TEAM`; certificates and profiles in Xcode Settings › Accounts with the owner's Apple ID) and step 2 (final bundle and product identifiers) |
| Archive of the one app | Distribution | owner-action | `BLOCKED_OWNER_ACTION`: [build-and-archive.md](../../release/build-and-archive.md) section 5 step 3 (open `VisualCore.xcodeproj`, scheme `VisualCore`, destination "Any iOS Device (arm64)", Product › Archive) |
| Validation and upload of the archive | Distribution | owner-action | `BLOCKED_OWNER_ACTION`: [build-and-archive.md](../../release/build-and-archive.md) section 5 step 4 (Organizer, Validate App, then Distribute App › App Store Connect › Upload) |

The App Store Connect record, the App Privacy answers (no data collected, no tracking), the store text from
[store-listing.md](store-listing.md), the screenshots and the review submission are further owner steps of the one app
([build-and-archive.md](../../release/build-and-archive.md) section 5 steps 5, 6, 8 and 9), recorded once for the app as
`BLOCKED_OWNER_ACTION`; the agent never does them.

## Accessibility: proved so far and pending for devices

Proved by the experience's tests on the iOS 27 simulator (rows above): every control has a spoken label and value;
undo, redo, the library, the picture and refusals are announced; the controls stack within the canvas at the largest
accessibility text size; every gesture action has a native alternative; the picture stays still with the drift off and
under Reduce Motion. Pending for devices (owner ruling of 2026-11-13: all system accessibility audits wait for device
testing): the system accessibility audits (ZG-D8), the small-screen precision (ZG-D6) and the quiet defaults with the
silent switch on hardware (ZG-D7).

## Artifact inventory

Documents of this phase (all under `docs/apps/digital-zen-garden/` unless a path is given):

- `privacy-and-credits.md` — stored data, the temporary picture file, what is read, how to delete, permissions, what is
  not done, required-reason APIs, the license inventory (T-A20-602).
- `store-listing.md` — store text input with the claim → proving-test table (T-A20-606).
- `release-checklist.md` — this checklist (T-A20-606).
- `release.json` — release configuration read by `check_experience_release.py` and `release_check.py` (T-A20-606;
  `specs/150-zg-p06-release/data-model.md`).
- `docs/release/known-limitations.md`, section "Digital Zen Garden" — the drawn sand, no gallery or sign-in, one
  picture size, the library and history caps and the device-only items (T-A20-606).
- `device-campaign.md` — device measurements ZG-D1 … ZG-D8 (A20-P05).
- `licenses.md` — licenses of the visual content (A20-P01).
- `docs/release/build-and-archive.md` — app-wide build and owner steps (existing).
- `README.md`, `visualcore-contract.json`, `visualcore-contract.md`, `regression-baseline.md` — existing documents.

Configuration:

- `Configs/copy-claims-denylist.json` — shared copy-claim denylist (unchanged; `copyCheck.allow` `["share"]`).
- `specs/150-zg-p06-release/scan-sources-release.sh` — source scan of Clarifications Q3 (T-A20-603).
- `specs/150-zg-p06-release/scan-claims-release.sh` — refused-word scan of the store text and the interface Swift and
  test-name check of the claim table (T-A20-607).
- `scripts/release_check.py` — serial interface chunk `b3` with `ZGGardenUITests`, `ZGLibraryUITests` and
  `ZGReleaseUITests` (T-A20-608).

Code and test artifacts of this phase:

- `Packages/ExperiencesCreative/DigitalZenGarden/Experience/GardenPresenter.swift` — the test-only `failNextDraw` seam
  (T-A20-604).
- `Packages/ExperiencesCreative/DigitalZenGarden/ExperienceTests/GardenRecoveryDrawTests.swift` (T-A20-604).
- `Packages/ExperiencesCreative/DigitalZenGarden/ExperienceTests/Fixtures/` with `snapshot-{v1,newer,damaged}.json`,
  `garden-{current,newer,damaged}.json` and `library-{current,newer,damaged}.json`, the test target's resources in
  `Packages/ExperiencesCreative/Package.swift`, and `ExperienceTests/StoredSampleTests.swift` (T-A20-605).
- `Apps/VisualCore/Tests/UI/DigitalZenGarden/ZGReleaseUITests.swift` (T-A20-608).

Evidence files (legacy ledger, stage A20-P06): `zg-no-network`, `zg-claims`, `zg-ios27`, `documented-api`, `app-ui`,
`verify-27`, `release-checks`, `contract`, `experience-packages`, `catalog`, `script-tests` under
`.autonomy/checks/A20-P06.<name>.json`; sealed evidence of the earlier phases `.autonomy/evidence/A20-P00.json` …
`A20-P05.json`; baseline cited from `.autonomy/checks/A20-P05.{zg-ios27,app-ui,verify-27}.json` (T-A20-601).
