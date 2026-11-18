# Shader Studio — release checklist and artifact inventory

Shader Studio (`a22.shader-studio`) ships inside the one VisualCore app (ADR-0009); feature 164 (A22-P06), FR-A22-601 to
FR-A22-607. App-wide commands are in [build-and-archive.md](../../release/build-and-archive.md). The statuses are the
words that `scripts/check_experience_release.py` accepts for every experience (Clarifications Q1):

- `verified`: the evidence named in the row is a check of the legacy ledger (`.autonomy/checks/A22-P06.<name>.json`,
  recorded with `desktop_runbook.py run-check` before A22-P06 is sealed) or a sealed earlier phase
  (`.autonomy/checks/A22-P0N.*.json`; the A22-P05 runs `.autonomy/checks/A22-P05.{ss-ios27,app-unit,app-ui,verify-27}.json`
  passed on the sources unchanged since the A22-P05 record commit 22b2b89f, cited as the baseline by T-A22-601). A
  row whose check file does not exist yet is pending: the task named in the row records it, and A22-P06 is not sealed
  before every such file exists and passed;
- `pending-campaign-ii` (spec: pending device campaign): needs the device campaign D1 → D2 → D3 after
  `ImplementationLock-100`; the row names its row SS-D1 … SS-D6 of [device-campaign.md](device-campaign.md); no
  device number is claimed before then;
- `owner-action` (spec: owner action): done by the owner only, steps in
  [build-and-archive.md](../../release/build-and-archive.md) section 5 (`BLOCKED_OWNER_ACTION` until done); never done
  by the agent (CLAUDE.md rule 6).

`scripts/check_experience_release.py --config docs/apps/shader-studio/release.json` rejects a row without a known
status or without evidence.

| Item | Area | Status | Evidence |
|---|---|---|---|
| Privacy and credits note: what is stored and where (the app's `state.json` with the schema 1 snapshot: template, 16 normalized values, 2 texture choices, run and reset counts, shape; `project-<n>.json`, kind `a22.saved-project`, at most 131,072 bytes, at most 24 projects; `library.json`, kind `a22.project-library`; all in the experience's own storage); no temporary file; nothing is sent; how to delete (Remove in the library; the Settings reset of the experience's data; the reset of all data; deleting the app); no permission is asked; GPU code is not a sandbox; the license inventory (code only) | Privacy | verified | [privacy-and-credits.md](privacy-and-credits.md) (T-A22-602); [licenses.md](licenses.md); `.autonomy/checks/A22-P06.release-checks.json` (`experience-release-a22`, T-A22-611) |
| No network, tracking, location, sensor, recording, microphone input, camera, photo-library, contacts, pasteboard, share-link, idle-timer or system-brightness use in the experience's sources | Privacy | verified | `.autonomy/checks/A22-P06.scan-sources.json` (`specs/164-ss-p06-release/scan-sources-release.sh`, T-A22-603) |
| No permission: the registration declares `"permissions": []`, so the experience needs no usage string; the app's usage strings are unchanged | Privacy | verified | `Catalog/registrations.json`; `.autonomy/checks/A22-P06.release-checks.json` (`app-usage-descriptions`, T-A22-611); [privacy-and-credits.md](privacy-and-credits.md) |
| The screen's idle timer and brightness are never changed | Privacy | verified | `.autonomy/checks/A22-P06.scan-sources.json` (`isIdleTimerDisabled` and `brightness =` refused, T-A22-603) |
| GPU code is not a sandbox: the person's shader runs on the graphics processor; the validator refuses a source past the limits before any compile, a failed compile keeps the last good program, and the watchdog stops a slow preview and Reset brings back the last good one; no safety claim is made | Privacy | verified | `.autonomy/checks/A22-P05.ss-ios27.json` (`ValidatorTests`, `OversizedProjectTests`, `LastGoodPreviewTests`, `FrameWatchdogTests`, `WatchdogTests`; baseline, T-A22-601); `.autonomy/checks/A22-P06.ss-ios27.json` (T-A22-609); `.autonomy/checks/A22-P06.scan-claims.json` ("not a sandbox" required, T-A22-607) |
| App privacy manifest matches the Release build and covers the experience's required-reason uses | Privacy | verified | `.autonomy/checks/A22-P06.release-checks.json` (`app-privacy-manifest`, T-A22-611); [privacy-and-credits.md](privacy-and-credits.md) |
| No tracking or advertising in the built app | Privacy | verified | `.autonomy/checks/A22-P06.release-checks.json` (`app-no-tracking`, T-A22-611) |
| Licenses and acknowledgements: the four templates, the three textures made in code, the prelude and the tokenizer's word lists are original code or facts; the editor uses the system font; no third-party code, image, stored texture, font file, model or sound file in the experience; app Licenses folder equals the inventory | Credits | verified | `.autonomy/checks/A22-P06.release-checks.json` (`app-licenses`, T-A22-611); [licenses.md](licenses.md); `TemplateCompileTests.thereAreFourTemplatesInOrderWithLicences`, `TextureRecipeTests.checksumsArePinned` in `.autonomy/checks/A22-P05.ss-ios27.json` (baseline, T-A22-601) and `.autonomy/checks/A22-P06.ss-ios27.json` (T-A22-609) |
| Store text input describing only implemented and tested features, with a claim → proving-test table; the phrase "not a sandbox"; none of the refused words of Clarifications Q2 (no safety, compatibility, sharing or measured claim) | Store | verified | [store-listing.md](store-listing.md) (T-A22-606); `.autonomy/checks/A22-P06.scan-claims.json` (`specs/164-ss-p06-release/scan-claims-release.sh`, T-A22-607) |
| Copy check: no measured claim, unmeasured quality word or missing feature in the store text and interface strings (controls, editor, inspector, library view, presenter, adapter); no word allowed | Store | verified | `.autonomy/checks/A22-P06.release-checks.json` (`copy-claims-a22`, T-A22-611; `Configs/copy-claims-denylist.json`); `.autonomy/checks/A22-P06.scan-claims.json` (T-A22-607) |
| Experience release check: required documents present (privacy and credits, store text, checklist, device campaign, licenses, VisualCore contract, build and archive), every checklist row has status and evidence | Store | verified | `.autonomy/checks/A22-P06.release-checks.json` (`experience-release-a22`, T-A22-611) |
| Sample stored files: `snapshot-{v1,p02,newer,damaged}.json` (v1 and p02 open; newer and damaged refused), `project-{current,newer,damaged}.json` (current opens; newer and damaged listed as unreadable with `newer-version` and `damaged`), `library-{current,newer,damaged}.json` (current lists; newer makes the library read only; damaged still lists the projects from their files and is not rewritten by reading); each stays byte-identical | Data | verified | `.autonomy/checks/A22-P06.ss-ios27.json` (`StoredSampleTests`; T-A22-605, T-A22-609) |
| Snapshot: schema 1; the round trip keeps the digest; damaged and out-of-range snapshots are refused; snapshots without `textures`, `resets` or `shape` read their defaults | Data | verified | `.autonomy/checks/A22-P05.ss-ios27.json` (`StudioCoreTests.theSnapshotRoundTripsAndDamageIsRefused`, `StudioManifestTests.theSaveRestoreStateSurvivesARestore`, `TextureInputTests.snapshotsKeepTheTexturesAndOldOnesReadTheDefault`, `WatchdogTests.snapshotsWithoutResetsRestoreWithZero`, `ShapeTests.aSnapshotWithoutShapeReadsTheTemplatesCounts`, `ShapeTests.outOfRangeShapesAreRefused`; baseline, T-A22-601); `.autonomy/checks/A22-P06.ss-ios27.json` (T-A22-609) |
| Project library: save, open, rename and remove round-trip; every cap refuses with its message and changes nothing; unreadable files are listed, kept and removed only on request; a full quota keeps the previous file; a newer index makes the library read only; a library on a new storage of the same root lists and opens | Data | verified | `.autonomy/checks/A22-P05.ss-ios27.json` (`LibraryTests.saveOpenRenameAndRemoveRoundTrip`, `everyCapRefusesWithItsMessageAndChangesNothing`, `unreadableFilesAreListedKeptAndOnlyRemovedOnRequest`, `aFullQuotaRefusesAndKeepsThePreviousFile`, `aNewerIndexMakesTheLibraryReadOnly`; `ShapeTests.aLibraryOnANewStorageOfTheSameRootListsAndOpens`; baseline, T-A22-601); `.autonomy/checks/A22-P06.ss-ios27.json` (T-A22-609) |
| Drawing-failure recovery: with two projects saved, a failed draw (test-only `failNextDraw` seam, `StudioDrawError.injected`) fails the session with the message, every storage file is byte-identical, and a new session over the same storage lists and opens both | Recovery | verified | `.autonomy/checks/A22-P06.ss-ios27.json` (`StudioRecoveryDrawTests`; T-A22-604, T-A22-609) |
| Context loss and stop recovery: the last good shader is drawn again after a context loss and a resize; ten rebuilds while running, after a failure, a refusal, while stopped and while textured; stress cycles return to the first level | Recovery | verified | `.autonomy/checks/A22-P05.ss-ios27.json` (`RebuildTests`, `RecoveryTests`, `StressCycleTests`; baseline, T-A22-601); `.autonomy/checks/A22-P06.ss-ios27.json` (T-A22-609) |
| Accessibility (automated): spoken labels for the uniforms, the texture inputs, the gutter's marked lines and the guidance | Accessibility | verified | `.autonomy/checks/A22-P05.ss-ios27.json` (`InspectorTests.theRowsMatchTheLiveProject`, `TextureInputTests.theThreeChoicesGiveThreeDifferentPictures`, `EditorModelTests.aBrokenRunMarksExactlyItsLineAndAFixClearsIt`, `GuidanceDisplayTests.aVersionLineIsRefusedWithItsSentenceAndLine`; baseline, T-A22-601); `.autonomy/checks/A22-P06.ss-ios27.json` (T-A22-609) |
| Accessibility (automated): Dynamic Type layout — the editor and the inspector stack at compact widths and accessibility text sizes, the editor's font follows the text size, and the gutter rows follow the wrapped lines; syntax emphasis is not colour only | Accessibility | verified | `.autonomy/checks/A22-P05.ss-ios27.json` (`EditorModelTests.theLayoutStacksAtCompactWidthsAndAccessibilitySizes`, `gutterRowsFollowTheWrappedLines`, `thePaletteMapsEveryKindAndEmphasisIsNotColour`; baseline, T-A22-601); `.autonomy/checks/A22-P06.ss-ios27.json` (T-A22-609) |
| Accessibility (automated): keyboard — ⌘R runs (the Run button's shortcut) and ⌘' moves to the next diagnostic in the person's source, wrapping and skipping entries outside it | Accessibility | verified | `.autonomy/checks/A22-P05.ss-ios27.json` (`EditorModelTests.nextErrorSkipsOutsideEntriesAndWraps`, `choosingADiagnosticGivesItsLineStart`; baseline, T-A22-601); `.autonomy/checks/A22-P05.app-ui.json` (`SSEditorUITests`, Run by the button or ⌘R; baseline); `.autonomy/checks/A22-P06.app-ui.json` (chunk `d3`, T-A22-610) |
| ExperiencesCreative package suites of Shader Studio on the iOS 27 simulator (sim-27.2; iOS 26 at X-A22 by owner ruling of 2026-11-14), each test under 10 s; the documented API, isolation and core purity | Tests | verified | `.autonomy/checks/A22-P05.ss-ios27.json`, `.autonomy/checks/A22-P05.documented-api.json`, `.autonomy/checks/A22-P05.isolation.json`, `.autonomy/checks/A22-P05.core-purity.json` (baseline, T-A22-601); `.autonomy/checks/A22-P06.ss-ios27.json` (`ShaderStudioCoreTests`, `ShaderStudioExperienceTests`) and `.autonomy/checks/A22-P06.documented-api.json`, `.autonomy/checks/A22-P06.isolation.json`, `.autonomy/checks/A22-P06.core-purity.json` (T-A22-609) |
| App build, unit tests and interface chunk d3 (serial): a broken line is marked and the fix clears it; the inspector slider changes and Reset restores it; a version line is refused with guidance; a saved project opens with its source and survives a relaunch; a fresh start reads "Compiled" with no `diagnostic-0`, `uniform-0` present and no `uniform-1`, and an empty library (no `project-0`) | Tests | verified | `.autonomy/checks/A22-P05.app-unit.json` and `.autonomy/checks/A22-P05.app-ui.json` (baseline, T-A22-601); `.autonomy/checks/A22-P06.app-ui.json` (`app-build-for-testing-ios27`, `app-unit-ios27`, `app-ui-ios27-d3`: `SSEditorUITests`, `SSLibraryUITests`, `SSRecoveryUITests`, `SSReleaseUITests`; T-A22-608, T-A22-610) |
| Experience runner on iOS 27 (standard scenarios) | Tests | verified | `.autonomy/checks/A22-P05.verify-27.json` (baseline, T-A22-601); `.autonomy/checks/A22-P06.verify-27.json` (T-A22-612) |
| Packages, catalog and script tests (the release and copy-claim tools with the new release configuration) | Tests | verified | T-A22-612: `.autonomy/checks/A22-P06.experience-packages.json`, `.autonomy/checks/A22-P06.catalog.json`, `.autonomy/checks/A22-P06.realcatalog.json`, `.autonomy/checks/A22-P06.script-tests.json` |
| VisualCore contract: G-RELEASE closed by A22-P06 (all 13 gaps closed; its iOS 26.x runner half cited at X-A22) | Tests | verified | `.autonomy/checks/A22-P06.contract.json` (`scripts/check_app_contract.py --app shader-studio`, T-A22-612); [visualcore-contract.md](visualcore-contract.md) |
| Release build checks: unsigned Release build, no debug or scenario symbols, manifest, tracking, licenses, usage strings, experience release documents, copy claims | Build | verified | `.autonomy/checks/A22-P06.release-checks.json` (T-A22-611) |
| Build-and-archive instructions for the one app, owner steps marked | Build | verified | [build-and-archive.md](../../release/build-and-archive.md); its agent-run release steps in `.autonomy/checks/A22-P06.release-checks.json` (T-A22-611) |
| A slow shader stopped by the watchdog, and Reset preview bringing back the last good program, per device | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) rows SS-D1-D1 to SS-D1-D3; no frame or stop time is claimed before device evidence |
| A compile error listed on the line the person wrote, the gutter marking it, and the cursor moving to it, per device | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) rows SS-D2-D1 to SS-D2-D3 |
| Hardware keyboard: typing without autocorrection, ⌘R and ⌘' on the device, the editor and preview usable at the iPhone size and side by side on iPad | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) rows SS-D3-D1 to SS-D3-D3; connecting a hardware keyboard is an owner action |
| A saved project kept across a relaunch from the app switcher, opening with its source, uniform values and textures | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) rows SS-D4-D1 to SS-D4-D3 |
| Compatibility profile read from the device's context (GLES and GLSL ES versions, fragment `highp`, maximum texture size), every template compiling and drawing | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) rows SS-D5-D1 to SS-D5-D3; nothing is claimed that the context does not report |
| Background and return: the picture comes back as it was and the resource level is unchanged with nothing leaked | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) rows SS-D6-D1 to SS-D6-D3 |
| System accessibility audits of the Shader Studio screen, the editor, the inspector and the library at the default and the largest text size | Accessibility | pending-campaign-ii | the device campaign ([device-campaign.md](device-campaign.md), run with `VC_RUN_AUDITS=1` alongside rows SS-D3-D1 to SS-D3-D3); deferred to the device campaign by owner ruling of 2026-11-13 |
| Signing set-up: team, certificates and provisioning profiles | Distribution | owner-action | `BLOCKED_OWNER_ACTION`: [build-and-archive.md](../../release/build-and-archive.md) section 5 step 1 (create the gitignored `Configs/Signing.local.xcconfig` with `DEVELOPMENT_TEAM`; certificates and profiles in Xcode Settings › Accounts with the owner's Apple ID) and step 2 (final bundle and product identifiers) |
| Archive of the one app | Distribution | owner-action | `BLOCKED_OWNER_ACTION`: [build-and-archive.md](../../release/build-and-archive.md) section 5 step 3 (open `VisualCore.xcodeproj`, scheme `VisualCore`, destination "Any iOS Device (arm64)", Product › Archive) |
| Validation and upload of the archive | Distribution | owner-action | `BLOCKED_OWNER_ACTION`: [build-and-archive.md](../../release/build-and-archive.md) section 5 step 4 (Organizer, Validate App, then Distribute App › App Store Connect › Upload) |

The App Store Connect record, the App Privacy answers (no data collected, no tracking), the store text from
[store-listing.md](store-listing.md), the screenshots and the review submission are further owner steps of the one app
([build-and-archive.md](../../release/build-and-archive.md) section 5 steps 5, 6, 8 and 9), recorded once for the app as
`BLOCKED_OWNER_ACTION`; the agent never does them.

## Accessibility: proved so far and pending for devices

Proved by the experience's tests on the iOS 27 simulator (rows above): the uniforms, the texture inputs, the gutter's
marked lines and the guidance have spoken labels; the editor and the inspector stack at compact widths and
accessibility text sizes and the editor's font follows the text size; syntax emphasis is not colour only; ⌘' moves to
the next diagnostic and Run is reachable by ⌘R. Pending for devices (owner ruling of 2026-11-13: all system
accessibility audits wait for device testing): the system accessibility audits, and the hardware keyboard on the
devices (SS-D3).

## Artifact inventory

Documents of this phase (all under `docs/apps/shader-studio/` unless a path is given):

- `privacy-and-credits.md` — stored data, no temporary file, what is read, how to delete, no permission, the screen,
  GPU code is not a sandbox, what is not done, required-reason APIs, the license inventory (T-A22-602).
- `store-listing.md` — store text input with the claim → proving-test table (T-A22-606).
- `release-checklist.md` — this checklist (T-A22-606).
- `release.json` — release configuration read by `check_experience_release.py` and `release_check.py` (T-A22-606;
  `specs/164-ss-p06-release/data-model.md`).
- `docs/release/known-limitations.md`, section "Shader Studio" — no sandbox, GLSL ES 3.00 fragment shaders only, no
  sharing or export, the limits, the watchdog and the device-only items (T-A22-606).
- `device-campaign.md` — device checks SS-D1 … SS-D6 (A22-P05).
- `licenses.md` — licenses of the templates, textures and word lists (A22-P01, A22-P03).
- `docs/release/build-and-archive.md` — app-wide build and owner steps (existing).
- `README.md`, `visualcore-contract.json`, `visualcore-contract.md`, `regression-baseline.md` — existing documents.

Configuration:

- `Configs/copy-claims-denylist.json` — shared copy-claim denylist (unchanged; `copyCheck.allow` `[]`).
- `specs/164-ss-p06-release/scan-sources-release.sh` — source scan of Clarifications Q3 (T-A22-603).
- `specs/164-ss-p06-release/scan-claims-release.sh` — refused-word scan of the store text and the interface Swift and
  test-name check of the claim table (T-A22-607).
- `scripts/release_check.py` — serial interface chunk `d3` with `SSEditorUITests`, `SSLibraryUITests`,
  `SSRecoveryUITests` and `SSReleaseUITests` (T-A22-608).

Code and test artifacts of this phase:

- `Packages/ExperiencesCreative/ShaderStudio/Experience/StudioPresenter.swift` — the test-only `failNextDraw` seam
  (T-A22-604).
- `Packages/ExperiencesCreative/ShaderStudio/ExperienceTests/StudioRecoveryDrawTests.swift` (T-A22-604).
- `Packages/ExperiencesCreative/ShaderStudio/ExperienceTests/Fixtures/` with `snapshot-{v1,p02,newer,damaged}.json`,
  `project-{current,newer,damaged}.json` and `library-{current,newer,damaged}.json`, the test target's resources in
  `Packages/ExperiencesCreative/Package.swift` if needed, and `ExperienceTests/StoredSampleTests.swift` (T-A22-605).
- `Apps/VisualCore/Tests/UI/ShaderStudio/SSReleaseUITests.swift` (T-A22-608).

Evidence files (legacy ledger, stage A22-P06): `scan-sources`, `scan-claims`, `ss-ios27`, `documented-api`,
`isolation`, `core-purity`, `app-ui`, `verify-27`, `release-checks`, `contract`, `experience-packages`, `catalog`,
`realcatalog`, `script-tests` under `.autonomy/checks/A22-P06.<name>.json`; sealed evidence of the earlier phases
`.autonomy/evidence/A22-P00.json` … `A22-P05.json`; baseline cited from
`.autonomy/checks/A22-P05.{ss-ios27,app-unit,app-ui,verify-27}.json` (T-A22-601).
