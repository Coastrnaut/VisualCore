# Ambient Clock — release checklist and artifact inventory

Ambient Clock (`a18.ambient-clock`) ships inside the one VisualCore app (ADR-0009); feature 136 (A18-P06), FR-A18-601
to FR-A18-607. App-wide commands are in [build-and-archive.md](../../release/build-and-archive.md). The statuses are
the words that `scripts/check_experience_release.py` accepts for every experience (Clarifications Q1):

- `verified`: the evidence named in the row is a check of the legacy ledger (`.autonomy/checks/A18-P06.<name>.json`,
  recorded with `desktop_runbook.py run-check` before A18-P06 is sealed) or a sealed earlier phase
  (`.autonomy/checks/A18-P0N.*.json`; the A18-P05 runs `.autonomy/checks/A18-P05.{ac-ios27,app-ui,verify-27}.json`
  passed on the sources unchanged since the A18-P05 record commit 495ae6b6, cited as the baseline by T-A18-601). A
  row whose check file does not exist yet is pending: the task named in the row records it, and A18-P06 is not sealed
  before every such file exists and passed;
- `pending-campaign-ii` (spec: pending device campaign): needs the device campaign D1 → D2 → D3 after
  `ImplementationLock-100`; the row names its row AC-D1 … AC-D10 of [device-campaign.md](device-campaign.md); no
  device number is claimed before then;
- `owner-action` (spec: owner action): done by the owner only, steps in
  [build-and-archive.md](../../release/build-and-archive.md) section 5 (`BLOCKED_OWNER_ACTION` until done); never done
  by the agent (CLAUDE.md rule 6).

`scripts/check_experience_release.py --config docs/apps/ambient-clock/release.json` rejects a row without a known
status or without evidence.

| Item | Area | Status | Evidence |
|---|---|---|---|
| Privacy and credits note: what is stored and where (the app's `state.json` with the schema 3 snapshot of the format, theme, night, reduced-motion and keep-awake settings, written at every suspension and close; `favourites.json` with at most 12 favourites, written only on a save or a removal), nothing sent, how to delete (removing a favourite; the Settings reset of the experience's data; the reset of all data; deleting the app); keep-awake off by default and only while the clock is open; the system brightness never written; the license inventory (themes, shaders and palettes written for this repository; the system font) | Privacy | verified | [privacy-and-credits.md](privacy-and-credits.md) (T-A18-602); [licenses.md](licenses.md); `.autonomy/checks/A18-P06.release-checks.json` (`experience-release-a18`, T-A18-611) |
| No network, tracking, sensor, recording, microphone input, photo-library, image-picker or system-brightness use in the experience's sources; the idle timer named only in `Experience/KeepAwake.swift` | Privacy | verified | `.autonomy/checks/A18-P06.ac-no-network.json` (`specs/136-ac-p06-release/scan-sources-release.sh`, T-A18-603); `SourceScanTests.theIdleTimerIsNamedOnlyInKeepAwake`, `SourceScanTests.noSourceWritesABrightness` in `.autonomy/checks/A18-P05.ac-ios27.json` (baseline, T-A18-601) and `.autonomy/checks/A18-P06.ac-ios27.json` (T-A18-609) |
| Keep-awake: off by default (also in every migrated older snapshot), turned on only with the toggle "Keep the screen on while the clock is open", held only while the setting is on and the clock is visible, released at resign-active, background and teardown, written only on a change | Privacy | verified | `.autonomy/checks/A18-P04.ac-ios27.json` and `.autonomy/checks/A18-P05.ac-ios27.json` (`KeepAwakeTests.withTheSettingOffThePortIsNeverSetToTrue`, `withTheSettingOnThePortFollowsEveryTransition`, `theControllerWritesOnlyOnChange`; `PowerCoreTests.theEarlierExamplesMigrateToSchemaThreeWithTheDefaults`; baseline, T-A18-601); `.autonomy/checks/A18-P06.ac-ios27.json` (T-A18-609) |
| No permission requested and no usage-description string added (the registration declares `"permissions": []`); no sound and no haptic; the app's usage strings unchanged | Privacy | verified | `.autonomy/checks/A18-P06.release-checks.json` (`app-usage-descriptions`, T-A18-611); `Catalog/registrations.json`; `project.yml`; [privacy-and-credits.md](privacy-and-credits.md) |
| App privacy manifest matches the Release build and covers the experience's required-reason uses | Privacy | verified | `.autonomy/checks/A18-P06.release-checks.json` (`app-privacy-manifest`, T-A18-611); [privacy-and-credits.md](privacy-and-credits.md) |
| No tracking or advertising in the built app | Privacy | verified | `.autonomy/checks/A18-P06.release-checks.json` (`app-no-tracking`, T-A18-611) |
| Licenses and acknowledgements: visuals made in code (the four theme shaders over the `vc/` GLSL library, original code; the palettes and night colours as numbers; the time and date in the system font); no third-party code, image, texture, font file, model or sound in the experience; app Licenses folder equals the inventory | Credits | verified | `.autonomy/checks/A18-P06.release-checks.json` (`app-licenses`, T-A18-611); [licenses.md](licenses.md); `ThemeRenderTests.everyThemeAtBothLevelsIsNotBlankWithADarkCentreAndItsBudget`, `ThemeCatalogTests.theCatalogHasFourThemesOfThreePalettesOfFourColours` in `.autonomy/checks/A18-P05.ac-ios27.json` (baseline, T-A18-601) and `.autonomy/checks/A18-P06.ac-ios27.json` (T-A18-609) |
| Store text input describing only implemented and tested features, with a claim → proving-test table; the clock shows the system time; keep-awake is the person's choice; no performance figure, no device value and none of the refused words of Clarifications Q2 | Store | verified | [store-listing.md](store-listing.md) (T-A18-606); `.autonomy/checks/A18-P06.ac-claims.json` (`specs/136-ac-p06-release/scan-claims-release.sh`, T-A18-607) |
| Copy check: no measured claim, unmeasured quality word or missing feature in the store text and interface strings (controls, overlay, presenter, adapter); no word allowed | Store | verified | `.autonomy/checks/A18-P06.release-checks.json` (`copy-claims-a18`, T-A18-611; `Configs/copy-claims-denylist.json`); `.autonomy/checks/A18-P06.experience-release.json` (T-A18-606) |
| Experience release check: required documents present (privacy and credits, store text, checklist, device campaign, licenses, VisualCore contract, build and archive), every checklist row has status and evidence | Store | verified | `.autonomy/checks/A18-P06.release-checks.json` (`experience-release-a18`, T-A18-611); `.autonomy/checks/A18-P06.experience-release.json` (T-A18-606) |
| Sample stored files: `snapshot-{v1,v2,v3,newer,damaged}.json` (v1 to v3 restore, v1 and v2 migrated; newer and damaged refused) and `favourites-{current,newer,damaged}.json` (current loads; newer reports `newer-version`; damaged reports `damaged`); each stays byte-identical | Data | verified | `.autonomy/checks/A18-P06.ac-ios27.json` (`StoredSampleTests`; T-A18-605, T-A18-609) |
| Snapshot: schema 3 round trip; schema 1 and 2 open migrated with the defaults; a stored value outside its range is refused; the settings come back after a relaunch | Data | verified | `.autonomy/checks/A18-P05.ac-ios27.json` (`PowerCoreTests.theSchemaThreeExampleRoundTrips`, `theEarlierExamplesMigrateToSchemaThreeWithTheDefaults`; `SnapshotMigrationTests.theSchemaIsThreeAndTheEarlierExamplesAreAcceptedByTheRegistryCheck`, `theSchemaOneExampleMigratesToThemeZeroPaletteZeroKeepingTheOtherFields`, `aStoredThemeOrPaletteOutsideItsRangeIsRefused`; `AmbientCoreTests.aStoredValueOutsideItsRangeIsRefused`, `anEngineSnapshotRestoresIntoAnotherEngine`; baseline, T-A18-601); `.autonomy/checks/A18-P05.app-ui.json` (`ACPowerUITests.testNightModeAndReduceMotionComeBackAfterARelaunch`); `.autonomy/checks/A18-P06.ac-ios27.json` (T-A18-609) |
| Favourites: a saved favourite is read again and applying it restores its preset; a 13th is refused as `over-cap`; a name in use is refused; a damaged, newer, too large or invalid file gives an empty list and is kept until a save; removing the last favourite removes the file | Data | verified | `.autonomy/checks/A18-P05.ac-ios27.json` (`FavouritesTests.aSavedFavouriteIsReadAgainAndApplyRestoresItsPreset`, `aThirteenthFavouriteIsRefusedAsOverCap`, `aNameInUseIsRefusedWithoutRegardToCase`, `aDamagedFileGivesAnEmptyListAndIsKeptUntilASave`, `aNewerSchemaIsNewerVersion`, `aFileAboveTheLimitIsTooLarge`, `anInvalidEntryIsInvalidEntry`, `removingTheLastFavouriteRemovesTheFile`; baseline, T-A18-601); `.autonomy/checks/A18-P06.ac-ios27.json` (T-A18-609) |
| Drawing-failure recovery: with two favourites saved, a failed draw fails the session with the injected error's message, `favourites.json` is byte-identical after the failure and after close, and a new session over the same storage opens and lists both | Recovery | verified | `.autonomy/checks/A18-P06.ac-ios27.json` (`AmbientRecoveryDrawTests`, test-only `failNextDraw` seam; T-A18-604, T-A18-609) |
| Theme failure: a theme whose fragment fails to compile keeps the previous theme and the time | Recovery | verified | `.autonomy/checks/A18-P05.ac-ios27.json` (`CrossfadeUseTests.aThemeThatFailsToCompileKeepsThePreviousThemeAndTheTime`; baseline, T-A18-601); `.autonomy/checks/A18-P06.ac-ios27.json` (T-A18-609) |
| Time: the system clock's instant, formatted for every zone, format and locale; time-zone, locale and foreground changes re-read once; daylight-saving changes never skip or repeat a minute wrongly | Time | verified | `.autonomy/checks/A18-P05.ac-ios27.json` (`PresenterClockTests.tickSendsTheClocksInstantAndReturnsTheNextWholeMinute`; `OverlayTests.theTextAfterATickIsTheFormattersForEveryZoneAndFormat`; `TimeZoneChangeTests.aZoneChangeSendsOneTimeChangeAndShowsKolkataTimeForTheSameInstant`, `aLocaleChangeReformatsTheText`; `ResumeTests.theReturnToTheForegroundShowsTheNewTimeBeforeAnyDraw`; `DaylightSavingTests.springForwardNeverShowsTheMissingHour`, `fallBackShowsTheRepeatedMinuteTwice`; baseline, T-A18-601); `.autonomy/checks/A18-P06.ac-ios27.json` (T-A18-609) |
| Accessibility (automated): the canvas label is the spoken time (and date when shown) in each locale (the name "Ambient Clock" before the first instant); labels, values, hints and identifiers `experience.a18.ambient-clock.<name>` on every control (`AmbientControls.swift`) | Accessibility | verified | `.autonomy/checks/A18-P05.ac-ios27.json` (`SpokenTimeTests.spokenNamesTheTimeAndTheDateInEachLocale`, `spokenIsTheTimeAloneWhenTheDateIsHidden`; `OverlayTests.beforeTheFirstInstantTheLabelIsTheName`; baseline, T-A18-601); `.autonomy/checks/A18-P06.ac-ios27.json` (T-A18-609); `.autonomy/checks/A18-P06.app-ui.json` (`ACPowerUITests`, `ACThemeUITests`, T-A18-610) |
| Accessibility (automated): the time fits one line within the width at the largest text size; white text and the night amber reach the required contrast against every palette colour, dimmed or not | Accessibility | verified | `.autonomy/checks/A18-P05.ac-ios27.json` (`OverlayTests.theLargestTextFitsOneLineWithinNinetyPercentOfTheWidth`; `ThemeCatalogTests.whiteTextReachesTheRequiredContrastOnEveryColour`; `NightPolicyTests.theNightTextReachesTheContrastAgainstEveryDimmedPaletteColour`; `NightRenderTests.theNightTextReachesTheRequiredContrastAgainstEveryDimmedColour`; baseline, T-A18-601); `.autonomy/checks/A18-P06.ac-ios27.json` (T-A18-609) |
| Accessibility (automated): motion — with motion off, the in-app reduced motion or the system's Reduce Motion the theme is still, a theme change is a cut and the drift is zero | Accessibility | verified | `.autonomy/checks/A18-P05.ac-ios27.json` (`AmbientRenderTests.withMotionOffTwoFramesAtDifferentTimesAreIdentical`, `withReduceMotionTwoFramesAtDifferentTimesAreIdentical`; `PowerCoreTests.inAppReducedMotionStillsTheThemeAndCutsAThemeChange`; `CrossfadeUseTests.underReduceMotionAThemeChangeShowsTheNewThemeOnTheNextFrame`; `ScreenCareTests.theDriftIsDeterministicAndZeroUnderReducedMotion`; baseline, T-A18-601); `.autonomy/checks/A18-P06.ac-ios27.json` (T-A18-609) |
| ExperiencesCreative package suites of Ambient Clock on the iOS 27 simulator (sim-27.2; iOS 26 at X-A18 by owner ruling of 2026-11-14), the slowest test under 10 s | Tests | verified | `.autonomy/checks/A18-P05.ac-ios27.json` (baseline, T-A18-601); `.autonomy/checks/A18-P06.ac-ios27.json` (`AmbientClockCoreTests`, `AmbientClockExperienceTests`, T-A18-609) |
| App build, unit tests and interface chunk z2 (serial): the clock opens labelled with its time; night mode On and reduced motion on change their values and come back after a relaunch; Wave Field chosen, saved as "Evening", the theme switched back, "Evening" applied, Wave Field shown again | Tests | verified | `.autonomy/checks/A18-P05.app-ui.json` (baseline, T-A18-601); `.autonomy/checks/A18-P06.app-ui.json` (`app-build-for-testing-ios27`, `app-unit-ios27`, `app-ui-ios27-z2`: `ACPowerUITests`, `ACThemeUITests`; T-A18-608, T-A18-610) |
| Experience runner on iOS 27 (standard scenarios) | Tests | verified | `.autonomy/checks/A18-P05.verify-27.json` (baseline, T-A18-601); `.autonomy/checks/A18-P06.verify-27.json` (T-A18-610) |
| Packages, catalog and script tests (the release and copy-claim tools with the new release configuration) | Tests | verified | T-A18-612: `.autonomy/checks/A18-P06.experience-packages.json`, `.autonomy/checks/A18-P06.catalog.json`, `.autonomy/checks/A18-P06.script-tests.json` |
| VisualCore contract: G-RELEASE closed by A18-P06 | Tests | verified | `.autonomy/checks/A18-P06.contract.json` (`scripts/check_app_contract.py --app ambient-clock --render`, T-A18-612); [visualcore-contract.md](visualcore-contract.md) |
| Release build checks: unsigned Release build, no debug or scenario symbols, manifest, tracking, licenses, usage strings, experience release documents, copy claims | Build | verified | `.autonomy/checks/A18-P06.release-checks.json` (T-A18-611) |
| Build-and-archive instructions for the one app, owner steps marked | Build | verified | [build-and-archive.md](../../release/build-and-archive.md); its agent-run release steps in `.autonomy/checks/A18-P06.release-checks.json` (T-A18-611) |
| Performance and heat overnight on power: the shown time against the system clock, the thermal state and the frame cap every 15 minutes | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row AC-D1 "Overnight run on power"; no number is claimed before device evidence |
| Overnight run on battery: battery use recorded, no claim made from it; no stale time after the screen dims | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row AC-D2 "Overnight run on battery" |
| Performance and heat over 30 minutes of motion at speed 2 with Particle Drift at `level-0`; the quality governor may drop to `level-1` and recovers | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row AC-D3 "Heat over 30 minutes" |
| Memory high-water mark, 20 theme changes and five reopens | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row AC-D4 "Memory" |
| Frame pacing with motion on and with a still picture (no theme draw between changes) | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row AC-D5 "Frame pacing" |
| Screen-care drift on OLED over 60 minutes | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row AC-D6 "Screen-care drift on OLED" |
| Night readability in a dark room for every theme and palette at dim 0.3 and 1; the system brightness unchanged | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row AC-D7 "Night readability" |
| Time zone, region format, language and a daylight-saving change on the device with the clock open | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row AC-D8 "Time changes on the device" |
| VoiceOver and Dynamic Type at the largest size on hardware | Accessibility | pending-campaign-ii | [device-campaign.md](device-campaign.md) row AC-D9 "VoiceOver and Dynamic Type" and the one app's campaign, Auto-Creator.md section 23.3 |
| System accessibility audits at the default and the largest text size | Accessibility | pending-campaign-ii | [device-campaign.md](device-campaign.md) row AC-D10 "Accessibility audit", run with `VC_RUN_AUDITS=1`; deferred to the device campaign by owner ruling of 2026-11-13 |
| Signing set-up: team, certificates and provisioning profiles | Distribution | owner-action | `BLOCKED_OWNER_ACTION`: [build-and-archive.md](../../release/build-and-archive.md) section 5 step 1 (create the gitignored `Configs/Signing.local.xcconfig` with `DEVELOPMENT_TEAM`; certificates and profiles in Xcode Settings › Accounts with the owner's Apple ID) and step 2 (final bundle and product identifiers) |
| Archive of the one app | Distribution | owner-action | `BLOCKED_OWNER_ACTION`: [build-and-archive.md](../../release/build-and-archive.md) section 5 step 3 (open `VisualCore.xcodeproj`, scheme `VisualCore`, destination "Any iOS Device (arm64)", Product › Archive) |
| Validation and upload of the archive | Distribution | owner-action | `BLOCKED_OWNER_ACTION`: [build-and-archive.md](../../release/build-and-archive.md) section 5 step 4 (Organizer, Validate App, then Distribute App › App Store Connect › Upload) |

The App Store Connect record, the App Privacy answers (no data collected, no tracking), the store text from
[store-listing.md](store-listing.md), the screenshots and the review submission are further owner steps of the one app
([build-and-archive.md](../../release/build-and-archive.md) section 5 steps 5, 6, 8 and 9), recorded once for the app as
`BLOCKED_OWNER_ACTION`; the agent never does them.

## Accessibility: proved so far and pending for devices

Proved by the experience's tests on the iOS 27 simulator (rows above): the canvas label is the spoken time in each
locale; labels, values, hints and identifiers on every control; the time on one line at the largest text size; the
contrast of the white and the night text against every palette colour; still themes, cut theme changes and no drift
under motion off, the in-app reduced motion and the system's Reduce Motion. Pending for devices (owner ruling of
2026-11-13: all system accessibility audits wait for device testing): VoiceOver and Dynamic Type on hardware (AC-D9),
night readability (AC-D7) and the system accessibility audits (AC-D10).

## Artifact inventory

Documents of this phase (all under `docs/apps/ambient-clock/` unless a path is given):

- `privacy-and-credits.md` — stored data, what is read, how to delete, permissions, keep-awake, brightness, what is not
  done, required-reason APIs, the license inventory (T-A18-602).
- `store-listing.md` — store text input with the claim → proving-test table (T-A18-606).
- `release-checklist.md` — this checklist (T-A18-606).
- `release.json` — release configuration read by `check_experience_release.py` and `release_check.py` (T-A18-606;
  `specs/136-ac-p06-release/data-model.md`).
- `docs/release/known-limitations.md`, section "Ambient Clock" — the system time, the themes, night mode, screen care,
  keep-awake, favourites, the stored files and the device-only items (T-A18-606).
- `device-campaign.md` — device measurements AC-D1 … AC-D10 (A18-P05).
- `licenses.md` — licenses of the visual content (A18-P03).
- `docs/release/build-and-archive.md` — app-wide build and owner steps (existing).
- `README.md`, `visualcore-contract.json`, `visualcore-contract.md`, `regression-baseline.md` — existing documents.

Configuration:

- `Configs/copy-claims-denylist.json` — shared copy-claim denylist (unchanged).
- `specs/136-ac-p06-release/scan-sources-release.sh` — source scan of Clarifications Q3 (T-A18-603).
- `specs/136-ac-p06-release/scan-claims-release.sh` — refused-word scan of the store text and the interface Swift and
  test-name check of the claim table (T-A18-607).
- `scripts/release_check.py` — serial interface chunk `z2` with `ACPowerUITests` and `ACThemeUITests` (T-A18-608).

Code and test artifacts of this phase:

- `Packages/ExperiencesCreative/AmbientClock/Experience/AmbientPresenter.swift` — the test-only `failNextDraw` seam
  (T-A18-604).
- `Packages/ExperiencesCreative/AmbientClock/ExperienceTests/AmbientRecoveryDrawTests.swift` (T-A18-604).
- `Packages/ExperiencesCreative/AmbientClock/ExperienceTests/Fixtures/` with `snapshot-{v1,v2,v3,newer,damaged}.json`
  and `favourites-{current,newer,damaged}.json`, the test target's resources in
  `Packages/ExperiencesCreative/Package.swift`, and `ExperienceTests/StoredSampleTests.swift` (T-A18-605).
- `Apps/VisualCore/Tests/UI/AmbientClock/ACThemeUITests.swift` (T-A18-608).

Evidence files (legacy ledger, stage A18-P06): `ac-no-network`, `experience-release`, `ac-claims`, `ac-ios27`,
`app-ui`, `verify-27`, `release-checks`, `contract` under `.autonomy/checks/A18-P06.<name>.json`; sealed evidence of
the earlier phases `.autonomy/evidence/A18-P00.json` … `A18-P05.json`; baseline cited from
`.autonomy/checks/A18-P05.{ac-ios27,app-ui,verify-27}.json` (T-A18-601).
