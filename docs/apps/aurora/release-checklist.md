# Aurora — release checklist and artifact inventory

Aurora (`a21.aurora`) ships inside the one VisualCore app (ADR-0009); feature 157 (A21-P06), FR-A21-601 to
FR-A21-607. App-wide commands are in [build-and-archive.md](../../release/build-and-archive.md). The statuses are the
words that `scripts/check_experience_release.py` accepts for every experience (Clarifications Q1):

- `verified`: the evidence named in the row is a check of the legacy ledger (`.autonomy/checks/A21-P06.<name>.json`,
  recorded with `desktop_runbook.py run-check` before A21-P06 is sealed) or a sealed earlier phase
  (`.autonomy/checks/A21-P0N.*.json`; the A21-P05 runs `.autonomy/checks/A21-P05.{au-ios27-2,app-ui,verify-27}.json`
  passed on the sources unchanged since the A21-P05 record commit 40aa885c, cited as the baseline by T-A21-601). A
  row whose check file does not exist yet is pending: the task named in the row records it, and A21-P06 is not sealed
  before every such file exists and passed;
- `pending-campaign-ii` (spec: pending device campaign): needs the device campaign D1 → D2 → D3 after
  `ImplementationLock-100`; the row names its row AU-D1 … AU-D8 of [device-campaign.md](device-campaign.md); no
  device number is claimed before then;
- `owner-action` (spec: owner action): done by the owner only, steps in
  [build-and-archive.md](../../release/build-and-archive.md) section 5 (`BLOCKED_OWNER_ACTION` until done); never done
  by the agent (CLAUDE.md rule 6).

`scripts/check_experience_release.py --config docs/apps/aurora/release.json` rejects a row without a known status or
without evidence.

| Item | Area | Status | Evidence |
|---|---|---|---|
| Privacy and credits note: what is stored and where (the app's `state.json` with the schema 1 snapshot of the open sky; the saved choices as the experience value `prefs.v1`, kind `a21.preferences`: the sky preset, the colour shift, the motion and sky values, the brightness limit, the sound on or off and the volume; each replaced on change and removed when the app is deleted); no temporary file; nothing sent; how to delete (the Settings reset of the experience's data; the reset of all data; deleting the app); no permission; the license inventory (code only) | Privacy | verified | [privacy-and-credits.md](privacy-and-credits.md) (T-A21-602); [licenses.md](licenses.md); `.autonomy/checks/A21-P06.release-checks.json` (`experience-release-a21`, T-A21-611) |
| No network, tracking, location, sensor, recording, microphone input, camera, photo-library, idle-timer or system-brightness use in the experience's sources | Privacy | verified | `.autonomy/checks/A21-P06.au-no-network.json` (`specs/157-au-p06-release/scan-sources-release.sh`, T-A21-603) |
| No permission: the registration declares `"permissions": []`, so the experience needs no usage string; the app's usage strings are unchanged | Privacy | verified | `Catalog/registrations.json`; `.autonomy/checks/A21-P06.release-checks.json` (`app-usage-descriptions`, T-A21-611); [privacy-and-credits.md](privacy-and-credits.md) |
| The screen is never kept awake and its brightness never changed; the brightness limit caps only the drawn sky | Privacy | verified | `.autonomy/checks/A21-P06.au-no-network.json` (`isIdleTimerDisabled` and `brightness =` refused, T-A21-603); `LimitTests.testEveryPresetStaysUnderEveryLimit` and `LimitRenderTests.everyPresetStaysUnderEveryLimit` in `.autonomy/checks/A21-P05.au-ios27-2.json` (baseline, T-A21-601) and `.autonomy/checks/A21-P06.au-ios27.json` (T-A21-609) |
| The optional sound: one loop synthesised in code (`AmbientLoopRecipe.gentle`) on the ambient session category, off by default, playing only while Aurora is open in the active app with the sound on; its choice stays out of the snapshot and the digest | Privacy | verified | `.autonomy/checks/A21-P04.audio-ios27.json` (`VisualCoreAudioTests`); `.autonomy/checks/A21-P05.au-ios27-2.json` (`SoundLoopTests.aFreshStartHasTheSoundOffAndMakesNoPlayer`, `theLoopPlaysOnlyWhileOnOnScreenAndActive`, `theDigestAndTheManifestAreTheSameWithTheSoundOnAndOff`; baseline, T-A21-601); `.autonomy/checks/A21-P06.au-ios27.json` (T-A21-609) |
| App privacy manifest matches the Release build and covers the experience's required-reason uses | Privacy | verified | `.autonomy/checks/A21-P06.release-checks.json` (`app-privacy-manifest`, T-A21-611); [privacy-and-credits.md](privacy-and-credits.md) |
| No tracking or advertising in the built app | Privacy | verified | `.autonomy/checks/A21-P06.release-checks.json` (`app-no-tracking`, T-A21-611) |
| Licenses and acknowledgements: visuals and sound made in code (the sky shader over `vc/`, the fallback sky, the ambient loop synthesised by VisualCoreAudioDSP, original code; presets and bounds as numbers; text in the system font); no third-party code, image, texture, font file, model, sound file or recording in the experience; app Licenses folder equals the inventory | Credits | verified | `.autonomy/checks/A21-P06.release-checks.json` (`app-licenses`, T-A21-611); [licenses.md](licenses.md); `PresetTests.everyPresetIsVersionOneAndWrittenForVisualCore`, `SkyRenderTests.testShaderDeclaresItsUniformsAndIncludesTheLibrary` in `.autonomy/checks/A21-P05.au-ios27-2.json` (baseline, T-A21-601) and `.autonomy/checks/A21-P06.au-ios27.json` (T-A21-609) |
| Store text input describing only implemented and tested features, with a claim → proving-test table; "sound", never the refused words; no forecast, scientific, therapeutic, sleep, screen or measured claim and none of the refused words of Clarifications Q2 | Store | verified | [store-listing.md](store-listing.md) (T-A21-606); `.autonomy/checks/A21-P06.au-claims.json` (`specs/157-au-p06-release/scan-claims-release.sh`, T-A21-607) |
| Copy check: no measured claim, unmeasured quality word or missing feature in the store text and interface strings (controls, presenter, adapter, sound); no word allowed | Store | verified | `.autonomy/checks/A21-P06.release-checks.json` (`copy-claims-a21`, T-A21-611; `Configs/copy-claims-denylist.json`); `.autonomy/checks/A21-P06.au-claims.json` (T-A21-607) |
| Experience release check: required documents present (privacy and credits, store text, checklist, device campaign, licenses, VisualCore contract, build and archive), every checklist row has status and evidence | Store | verified | `.autonomy/checks/A21-P06.release-checks.json` (`experience-release-a21`, T-A21-611) |
| Sample stored files: `snapshot-{v1,newer,damaged}.json` (v1 restores; the newer one refused as `newerSchema`, the damaged one as `corrupt`) and `prefs-{current,newer,damaged,out-of-range}.json` (current opens with its values; the refused ones open the defaults with `newer-version`, `damaged` and `out-of-range`); each stays byte-identical | Data | verified | `.autonomy/checks/A21-P06.au-ios27.json` (`StoredSampleTests`; T-A21-605, T-A21-609) |
| Snapshot: schema 1, the open sky only (the scene, the colour shift and the limit); the round trip keeps the digest; damaged, refused and newer snapshots are refused | Data | verified | `.autonomy/checks/A21-P05.au-ios27-2.json` (`AuroraCoreTests.theSnapshotRoundTrips`, `damagedRefusedAndNewerSnapshotsAreRefused`, `theDigestCoversExactlyTheSceneTheHueAndTheLimit`; `AuroraManifestTests.theSaveRestoreStateSurvivesARestore`; baseline, T-A21-601); `.autonomy/checks/A21-P06.au-ios27.json` (T-A21-609) |
| Saved choices `prefs.v1`: every choice kept across a reopen; a damaged, newer or out-of-range value opens the defaults with the message and is not rewritten until the next accepted change; a failed save is reported once; a restored snapshot wins for the sky, never for the sound | Data | verified | `.autonomy/checks/A21-P05.au-ios27-2.json` (`PreferencesStoreTests.closingAndReopeningKeepsEveryChoice`, `damagedNewerAndOutOfRangeValuesOpenWithTheDefaults`, `aFailedSaveIsReportedOnceAndTheChoicesStay`, `aRestoredSnapshotWinsForTheSkyNeverForTheSound`; `PreferencesTests.damagedBytesAreRefusedAsDamaged`, `versionTwoIsRefusedAsNewer`, `eachFieldOutOfRangeIsRefusedAsOutOfRange`; baseline, T-A21-601); `.autonomy/checks/A21-P06.au-ios27.json` (T-A21-609) |
| Drawing-failure recovery: with Violet veil saved and the sound on, a failed draw fails the session with the injected message, `prefs.v1` is byte-identical, and a new session over the same storage opens on Violet veil with the sound on | Recovery | verified | `.autonomy/checks/A21-P06.au-ios27.json` (`SkyRecoveryDrawTests`, test-only `failNextDraw` seam; T-A21-604, T-A21-609) |
| Fallback sky: a compile failure or a missing fragment `highp` shows the simpler sky with its line; when the fallback fails too, the sky colour remains (never grey) | Recovery | verified | `.autonomy/checks/A21-P05.au-ios27-2.json` (`FallbackTests.aCompileFailureShowsTheFallbackSky`, `aMissingHighpShowsTheFallbackSky`, `whenTheFallbackFailsTooTheSkyColourRemains`; baseline, T-A21-601); `.autonomy/checks/A21-P06.au-ios27.json` (T-A21-609) |
| Accessibility (automated): every control has a spoken label and a native action; hidden controls return by a tap and by the action "Show controls"; the sound controls have spoken labels | Accessibility | verified | `.autonomy/checks/A21-P05.au-ios27-2.json` (`ChromeTests.everyControlHasASpokenLabelAndANativeAction`, `hiddenControlsReturnByATapAndByTheAction`; `SoundChoiceTests.theSoundControlsHaveSpokenLabelsAndSendNothing`; baseline, T-A21-601); `.autonomy/checks/A21-P06.au-ios27.json` (T-A21-609); `.autonomy/checks/A21-P06.app-ui.json` (chunk `c3`, T-A21-610) |
| Accessibility (automated): motion and flashing — under Reduce Motion frames are byte-identical and a change is immediate; the still view holds; reduced flashing turns the twinkle off and slows a change; every preset and every change stays under the brightness limit | Accessibility | verified | `.autonomy/checks/A21-P05.au-ios27-2.json` (`ReducedMotionFrameTests.testReducedMotionFramesAreByteIdentical`; `BlendTests.underReduceMotionAChangeIsImmediateAndTheSkyStill`; `StillViewTests.withReduceMotionTooTheStillViewWinsAndHolds`; `ReducedFlashTests.theControlTurnsTheTwinkleOffAndSlowsAChange`, `theSystemsReduceFlashingTurnsTheModeOn`; `LimitRenderTests.everyChangeStaysUnderTheLowLimit`; baseline, T-A21-601); `.autonomy/checks/A21-P06.au-ios27.json` (T-A21-609) |
| ExperiencesCreative package suites of Aurora on the iOS 27 simulator (sim-27.2; iOS 26 at X-A21 by owner ruling of 2026-11-14), each test under 10 s; the documented API | Tests | verified | `.autonomy/checks/A21-P05.au-ios27-2.json` and `.autonomy/checks/A21-P05.documented-api.json` (baseline, T-A21-601); `.autonomy/checks/A21-P06.au-ios27.json` (`AuroraCoreTests`, `AuroraExperienceTests`) and `.autonomy/checks/A21-P06.documented-api.json` (T-A21-609) |
| App build, unit tests and interface chunk c3 (serial): picking Violet veil names it on the canvas; Still sky and Reduced flashing turn on; hidden controls come back with a tap on the sky; the sound choice comes back after a relaunch; a fresh start opens on Polar night with the sound, Still sky and Reduced flashing off | Tests | verified | `.autonomy/checks/A21-P05.app-ui.json` (baseline, T-A21-601); `.autonomy/checks/A21-P06.app-ui.json` (`app-build-for-testing-ios27`, `app-unit-ios27`, `app-ui-ios27-c3`: `AUSkyUITests`, `AUSoundUITests`, `AUReleaseUITests`; T-A21-608, T-A21-610) |
| Experience runner on iOS 27 (standard scenarios) | Tests | verified | `.autonomy/checks/A21-P05.verify-27.json` (baseline, T-A21-601); `.autonomy/checks/A21-P06.verify-27.json` (T-A21-610) |
| Packages, catalog and script tests (the release and copy-claim tools with the new release configuration) | Tests | verified | T-A21-612: `.autonomy/checks/A21-P06.experience-packages.json`, `.autonomy/checks/A21-P06.catalog.json`, `.autonomy/checks/A21-P06.script-tests.json` |
| VisualCore contract: G-RELEASE closed by A21-P06 (its iOS 26.x runner half cited at X-A21) | Tests | verified | `.autonomy/checks/A21-P06.contract.json` (`scripts/check_app_contract.py --app aurora --render`, T-A21-612); [visualcore-contract.md](visualcore-contract.md) |
| Release build checks: unsigned Release build, no debug or scenario symbols, manifest, tracking, licenses, usage strings, experience release documents, copy claims | Build | verified | `.autonomy/checks/A21-P06.release-checks.json` (T-A21-611) |
| Build-and-archive instructions for the one app, owner steps marked | Build | verified | [build-and-archive.md](../../release/build-and-archive.md); its agent-run release steps in `.autonomy/checks/A21-P06.release-checks.json` (T-A21-611) |
| Thermal state and frame rate per preset | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row AU-D1 "Thermal state and frame rate per preset"; no thermal or frame figure is claimed before device evidence |
| Battery over a short session, full sky and still view | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row AU-D2 "Battery over a short session"; recorded only, no claim is made from it |
| Low-power cadence without a time jump | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row AU-D3 "Low-power cadence without a time jump" |
| Brightness limit, reduced flashing and comfort on screen | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row AU-D4 "Brightness limit, reduced flashing and comfort on screen"; Reduce Flashing in Settings is an owner action |
| The still view's idle drawing | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row AU-D5 "The still view's idle drawing" |
| The ambient loop on the speaker: quiet defaults, the silent switch, the volume, other playback, a call or an alarm, the background, the restored choice | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row AU-D6 "The ambient loop on the speaker"; the silent switch, the call and the alarm are owner actions |
| Shader compilation, fallback and refresh rates | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row AU-D7 "Shader compilation, fallback and refresh rates" |
| System accessibility audits of the Aurora screen, its controls and the hidden-controls view at the default and the largest text size | Accessibility | pending-campaign-ii | [device-campaign.md](device-campaign.md) row AU-D8 "Accessibility audit", run with `VC_RUN_AUDITS=1`; deferred to the device campaign by owner ruling of 2026-11-13 |
| Signing set-up: team, certificates and provisioning profiles | Distribution | owner-action | `BLOCKED_OWNER_ACTION`: [build-and-archive.md](../../release/build-and-archive.md) section 5 step 1 (create the gitignored `Configs/Signing.local.xcconfig` with `DEVELOPMENT_TEAM`; certificates and profiles in Xcode Settings › Accounts with the owner's Apple ID) and step 2 (final bundle and product identifiers) |
| Archive of the one app | Distribution | owner-action | `BLOCKED_OWNER_ACTION`: [build-and-archive.md](../../release/build-and-archive.md) section 5 step 3 (open `VisualCore.xcodeproj`, scheme `VisualCore`, destination "Any iOS Device (arm64)", Product › Archive) |
| Validation and upload of the archive | Distribution | owner-action | `BLOCKED_OWNER_ACTION`: [build-and-archive.md](../../release/build-and-archive.md) section 5 step 4 (Organizer, Validate App, then Distribute App › App Store Connect › Upload) |

The App Store Connect record, the App Privacy answers (no data collected, no tracking), the store text from
[store-listing.md](store-listing.md), the screenshots and the review submission are further owner steps of the one app
([build-and-archive.md](../../release/build-and-archive.md) section 5 steps 5, 6, 8 and 9), recorded once for the app as
`BLOCKED_OWNER_ACTION`; the agent never does them.

## Accessibility: proved so far and pending for devices

Proved by the experience's tests on the iOS 27 simulator (rows above): every control has a spoken label and a native
action; the hidden controls return by a tap on the sky and by the action "Show controls"; the sky stays still under
Reduce Motion and in the still view; reduced flashing turns the twinkle off and slows every change between skies;
every preset and every change stays under the brightness limit. Pending for devices (owner ruling of 2026-11-13: all
system accessibility audits wait for device testing): the system accessibility audits (AU-D8), the comfort of the
brightness limit and reduced flashing on a real screen (AU-D4) and the quiet defaults with the silent switch on
hardware (AU-D6).

## Artifact inventory

Documents of this phase (all under `docs/apps/aurora/` unless a path is given):

- `privacy-and-credits.md` — stored data, no temporary file, what is read, how to delete, no permission, the screen
  and the sound, what is not done, required-reason APIs, the license inventory (T-A21-602).
- `store-listing.md` — store text input with the claim → proving-test table (T-A21-606).
- `release-checklist.md` — this checklist (T-A21-606).
- `release.json` — release configuration read by `check_experience_release.py` and `release_check.py` (T-A21-606;
  `specs/157-au-p06-release/data-model.md`).
- `docs/release/known-limitations.md`, section "Aurora" — stylized skies, no live data, the optional sound, the still
  view, the fallback sky, the saved choices and the device-only items (T-A21-606).
- `device-campaign.md` — device measurements AU-D1 … AU-D8 (A21-P05).
- `licenses.md` — licenses of the visual and sound content (A21-P01, A21-P04).
- `docs/release/build-and-archive.md` — app-wide build and owner steps (existing).
- `README.md`, `visualcore-contract.json`, `visualcore-contract.md`, `regression-baseline.md` — existing documents.

Configuration:

- `Configs/copy-claims-denylist.json` — shared copy-claim denylist (unchanged; `copyCheck.allow` `[]`).
- `specs/157-au-p06-release/scan-sources-release.sh` — source scan of Clarifications Q3 (T-A21-603).
- `specs/157-au-p06-release/scan-claims-release.sh` — refused-word scan of the store text and the interface Swift and
  test-name check of the claim table (T-A21-607).
- `scripts/release_check.py` — serial interface chunk `c3` with `AUSkyUITests`, `AUSoundUITests` and
  `AUReleaseUITests` (T-A21-608).

Code and test artifacts of this phase:

- `Packages/ExperiencesCreative/Aurora/Experience/AuroraPresenter.swift` — the test-only `failNextDraw` seam
  (T-A21-604).
- `Packages/ExperiencesCreative/Aurora/ExperienceTests/SkyRecoveryDrawTests.swift` (T-A21-604).
- `Packages/ExperiencesCreative/Aurora/ExperienceTests/Fixtures/` with `snapshot-{v1,newer,damaged}.json` and
  `prefs-{current,newer,damaged,out-of-range}.json`, the test target's resources in
  `Packages/ExperiencesCreative/Package.swift`, and `ExperienceTests/StoredSampleTests.swift` (T-A21-605).
- `Apps/VisualCore/Tests/UI/Aurora/AUReleaseUITests.swift` (T-A21-608).

Evidence files (legacy ledger, stage A21-P06): `au-no-network`, `au-claims`, `au-ios27`, `documented-api`, `app-ui`,
`verify-27`, `release-checks`, `contract`, `experience-packages`, `catalog`, `script-tests` under
`.autonomy/checks/A21-P06.<name>.json`; sealed evidence of the earlier phases `.autonomy/evidence/A21-P00.json` …
`A21-P05.json`; baseline cited from `.autonomy/checks/A21-P05.{au-ios27-2,app-ui,verify-27}.json` (T-A21-601).
