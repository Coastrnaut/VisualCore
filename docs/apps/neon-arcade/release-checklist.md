# Neon Arcade — release checklist and artifact inventory

Neon Arcade (`a10.neon-arcade`) ships inside the one VisualCore app (ADR-0009); feature 080 (A10-P06), FR-A10-620,
FR-A10-622 and FR-A10-623. App-wide commands are in [build-and-archive.md](../../release/build-and-archive.md). The
spec's statuses are written with the status words that `scripts/check_app_release.py` accepts for every experience
(Clarifications Q1):

- `verified`: the evidence named in the row is a check of the legacy ledger (`.autonomy/checks/A10-P06.<name>.json`,
  recorded with `desktop_runbook.py run-check` before A10-P06 is sealed) or a sealed earlier phase
  (`.autonomy/checks/A10-P0N.*.json`). A row whose check file does not exist yet is pending: the task named in the row
  records it, and A10-P06 is not sealed before every such file exists and passed;
- `pending-campaign-ii` (spec: device): needs the device campaign D1 → D2 → D3 after `ImplementationLock-100`; the row
  names its row of [device-campaign.md](device-campaign.md) or the one app's campaign (Auto-Creator.md section 23.3);
  task T-A10-615;
- `owner-action` (spec: blocked-owner): done by the owner only, steps in
  [build-and-archive.md](../../release/build-and-archive.md) section 5 (`BLOCKED_OWNER_ACTION` until done); task
  T-A10-614.

`scripts/check_experience_release.py --config docs/apps/neon-arcade/release.json` rejects a row without a known status
or without evidence.

| Item | Area | Status | Evidence |
|---|---|---|---|
| Privacy and credits note: what is stored and where (`high-scores.json` with at most ten entries of score, wave and run number, the app's `state.json`), nothing sent, no personal data, how to delete, every bundled item and pattern credited with author and license | Privacy | verified | [privacy-and-credits.md](privacy-and-credits.md) (T-A10-602); [content-licenses.md](content-licenses.md); `.autonomy/checks/A10-P06.release-docs.json` (`experience-release-a10`, T-A10-607) |
| No network, tracking, sensor, recording, microphone input, system-brightness or idle-timer use in the experience's sources | Privacy | verified | `.autonomy/checks/A10-P06.na-no-network.json` (T-A10-603) |
| No permission requested and no usage string added; the app's usage strings unchanged | Privacy | verified | `.autonomy/checks/A10-P06.release-checks.json` (`app-usage-descriptions`, T-A10-612); `project.yml`; [privacy-and-credits.md](privacy-and-credits.md) |
| Sound is synthesized and played with the ambient session (follows the silent switch, no input, no microphone permission); interruptions and the background stop playback; the Sound toggle silences it | Privacy | verified | `.autonomy/checks/A10-P03.audio-player-ios27-2.json` (`SoundEffectPlayerTests.testPlayingUsesTheAmbientSessionAndNeedsNoMicrophonePermission`, `testInterruptionStopsPlayback`, `testMovingToTheBackgroundStopsPlayback`, `testDisabledPlayerPlaysNothing`); `.autonomy/checks/A10-P03.audio-dsp-host.json` (`SoundEffectSynthTests`); `.autonomy/checks/A10-P06.arcade-ios27.json` (`ArcadeSessionTests.testTheSoundAndHapticSinksReceiveCuesOnlyWhenEnabled`, T-A10-609) |
| App privacy manifest matches the Release build and covers the experience's required-reason uses | Privacy | verified | `.autonomy/checks/A10-P06.release-checks.json` (`app-privacy-manifest`, T-A10-612); [privacy-and-credits.md](privacy-and-credits.md) |
| No tracking or advertising in the built app | Privacy | verified | `.autonomy/checks/A10-P06.release-checks.json` (`app-no-tracking`, T-A10-612) |
| Licenses and acknowledgements: the player, both hazards, the orb and the four patterns are MIT content of the VisualCore project; no third-party code or asset in the experience; app Licenses folder equals the inventory | Credits | verified | `.autonomy/checks/A10-P06.release-checks.json` (`app-licenses`, T-A10-612); `LicenseAuditTests.theCommittedLicenseDocumentMatchesTheCatalog` in `.autonomy/checks/A10-P05.arcade-ios27.json` (baseline, T-A10-601) and `.autonomy/checks/A10-P06.arcade-ios27.json` (T-A10-609) |
| Store text input describing only implemented and tested features, with a claim → proving-test table; no measured claim, no number with a unit, no benefit or competitive claim | Store | verified | [store-listing.md](store-listing.md) (T-A10-606); `.autonomy/checks/A10-P06.release-docs.json` (`scan-claims-release.sh`, T-A10-607) |
| Copy check: no measured claim, unmeasured quality word or missing feature in the store text and interface strings (nothing allowed) | Store | verified | `.autonomy/checks/A10-P06.release-docs.json` (`copy-claims-a10`, T-A10-607; `Configs/copy-claims-denylist.json`) |
| Catalog entry and README name only proven capabilities and make no benefit claim | Store | verified | `.autonomy/checks/A10-P05.claims-2.json` (`specs/079-na-p05-balance/scan-claims.sh`); `.autonomy/checks/A10-P05.catalog.json` |
| Experience release check: required documents present, every checklist row has status and evidence | Store | verified | `.autonomy/checks/A10-P06.release-docs.json` (`experience-release-a10`, T-A10-607) |
| Sample high-score files: a valid table (board version 1, three entries) is shown; a newer (board version 2), a damaged and a truncated file are reported; all byte-identical after a reload until a finished run writes a valid table | Data | verified | `.autonomy/checks/A10-P06.arcade-ios27.json` (`HighScoreSampleFileTests`, T-A10-604, T-A10-605, T-A10-609) |
| High-score table: ranked highest first, at most ten, a run entered once, an interrupted save leaves the last complete table, a refused storage reported once with the table kept in memory | Data | verified | `.autonomy/checks/A10-P05.arcade-ios27.json` (`HighScoreTableTests`, `HighScoreStoreTests`; baseline, T-A10-601); `.autonomy/checks/A10-P06.arcade-ios27.json` (T-A10-609) |
| Session state: snapshots of schemas 1 to 3 migrate and restore; newer and damaged snapshots refused and a new run opens | Data | verified | `.autonomy/checks/A10-P06.arcade-ios27.json` (`ArcadeRecoveryDrawTests` stored schema 1 to 3 examples; `ArcadeCoreTests.testASchemaOneSnapshotRestoresInANewEngineWithTheRunKept`, `testASchemaTwoSnapshotRestoresWithTheScreenDerived`, `testASchemaThreeSnapshotRestoresWithTheDefaultStepAndRunOne`; `ArcadeSessionTests.testANewerSavedStateIsRefusedAndANewRunOpens`, `testADamagedSavedStateIsRefusedAndANewRunOpens`; T-A10-609) |
| Drawing-failure recovery: failure state, `high-scores.json` byte-identical, a new session draws | Recovery | verified | `.autonomy/checks/A10-P06.arcade-ios27.json` (`ArcadeRecoveryDrawTests`, test-only `failNextDraw` seam; T-A10-605, T-A10-609); `ArcadeRenderTests.testAFailedDrawReachesTheSession` |
| Accessibility (automated): every control is labelled (label, value and hint from one table) | Accessibility | verified | `.autonomy/checks/A10-P05.arcade-ios27.json` and `.autonomy/checks/A10-P06.arcade-ios27.json` (`ArcadeSessionTests.testEveryControlIsLabelledAndTheControlsGrowWithDynamicType`, T-A10-609); `.autonomy/checks/A10-P06.app-ui.json` (`NAArcadeUITests`, `NASettingsUITests`: controls found by identifier and label, chunk r2, T-A10-610) |
| Accessibility (automated): Dynamic Type — every text uses a text style and wraps; hit areas at least 44 points high | Accessibility | verified | `.autonomy/checks/A10-P06.arcade-ios27.json` (`ArcadeSessionTests.testEveryControlIsLabelledAndTheControlsGrowWithDynamicType`, T-A10-609) |
| Accessibility (automated): every screen spoken; announcements for hits, waves and game over, at most one per second, only with VoiceOver | Accessibility | verified | `.autonomy/checks/A10-P06.arcade-ios27.json` (`ArcadeSessionTests.testEveryScreenIsSpoken`, `testAnnouncementsAreAtMostOnePerSecondOverARun`; `ArcadeAnnouncementsTests.textsForHitWaveAndGameOver`, `atMostOnePerSecondOverASixHundredStepBurst`, `nothingIsPostedWithVoiceOverOff`; `ArcadeRenderTests.testTheDescriptionNamesScoreLivesAndState`; T-A10-609) |
| Accessibility (automated): native alternatives — steering by Steer left, Steer right and Straight besides the drag; start, pause, restart, sound, haptics and sensitivity as native controls | Accessibility | verified | `.autonomy/checks/A10-P06.arcade-ios27.json` (`ArcadeSessionTests.testEveryControlIsLabelledAndTheControlsGrowWithDynamicType`, T-A10-609); `.autonomy/checks/A10-P06.app-ui.json` (`NAArcadeUITests.testStartAndSteer`, `testPauseAndResume`, `testSensitivity`; `NASettingsUITests.testSoundToggle`, `testHapticsToggle`, `testSensitivityStepper`; T-A10-610) |
| Accessibility (automated): Reduce Motion halves the glow pulse and drift, screens change without a fade, the run never changes | Accessibility | verified | `.autonomy/checks/A10-P06.arcade-ios27.json` (`ArcadeRenderTests.testReduceMotionHalvesPulseAndDriftAndLeavesTheCoreAlone`, `testScreensCrossFadeAndChangeAtOnceUnderReduceMotion`; `ArcadeSessionTests.testReduceMotionHalvesPulseAndDriftButNeverChangesTheState`; T-A10-609) |
| Accessibility (automated): reduced flashing holds the glow steady at the cap of every level with no pulse; effects drawn below the collision shapes; contrast of every core against the field and every hazard against its glow | Accessibility | verified | `.autonomy/checks/A10-P06.arcade-ios27.json` (`ArcadeRenderTests.testReducedFlashingHoldsTheGlowSteadyAtEveryLevel`, `testTheEffectsAreDrawnBelowTheCollisionShapes`; `ContrastTests.everyCoreIsReadableAgainstTheField`, `everyHazardIsReadableAgainstItsGlowAtEveryLevel`; T-A10-609) |
| ExperiencesCreative package suites of Neon Arcade on the iOS 27 simulator (sim-27.2; iOS 26 at X-A10 by owner ruling of 2026-11-14) | Tests | verified | `.autonomy/checks/A10-P05.arcade-ios27.json` (baseline, T-A10-601); `.autonomy/checks/A10-P06.arcade-ios27.json` (`NeonArcadeCoreTests`, `NeonArcadeExperienceTests`, T-A10-609) |
| VisualCore pieces built for Neon Arcade: swept 2D collision and synthesized sound effects with their player | Tests | verified | `.autonomy/checks/A10-P01.visualcore-host.json` (`Collision2DTests`); `.autonomy/checks/A10-P03.audio-dsp-host.json` (`SoundEffectSynthTests`); `.autonomy/checks/A10-P03.audio-player-ios27-2.json` (`SoundEffectPlayerTests`) |
| App build, unit tests and interface chunk r2: start and steer, pause and resume, sensitivity, best score on the title; Sound and Haptics toggles, sensitivity stepper | Tests | verified | `.autonomy/checks/A10-P05.app-ui.json` (baseline, T-A10-601); `.autonomy/checks/A10-P06.app-ui.json` (`app-build-for-testing-ios27`, `app-unit-ios27`, `app-ui-ios27-r2`: `NAArcadeUITests`, `NASettingsUITests`, iOS 27.2 phone simulator, T-A10-610) |
| Experience runner on iOS 27 (nine standard scenarios) | Tests | verified | `.autonomy/checks/A10-P05.verify-27.json` (baseline, T-A10-601); `.autonomy/checks/A10-P06.verify-27.json` (T-A10-611) |
| Release build checks: unsigned Release build, no debug or scenario symbols, manifest, tracking, licenses, usage strings | Build | verified | `.autonomy/checks/A10-P06.release-checks.json` (T-A10-612) |
| Release document and copy check scripts tested (pass and fail cases) | Build | verified | `.autonomy/checks/A10-P06.script-tests.json` (T-A10-613) |
| Build-and-archive instructions for the one app, owner steps marked | Build | verified | [build-and-archive.md](../../release/build-and-archive.md); its agent-run release steps in `.autonomy/checks/A10-P06.release-checks.json` (T-A10-612) |
| CPU and GPU time per frame per quality level, wave 1 and wave 3 or later, with bursts, on D1, D2, D3 | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row "Frame pacing per quality level" (T-A10-615); no number is claimed before device evidence |
| Thermal state over a ten-minute session | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row "Thermal state over a 10-minute session" (T-A10-615) |
| Glow readability in bright light at every level, reduced flashing off and on | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row "Glow readability in bright light" (T-A10-615) |
| Audio routes: speaker, wired and Bluetooth headphones, the silent switch, interruptions, sound off | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row "Audio routes" (T-A10-615) |
| High-score survival after force-quit; an interrupted save leaves the last complete table; the folder holds only `high-scores.json` and the state file | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row "High-score survival after force-quit" (T-A10-615) |
| VoiceOver on hardware: every screen and control, the announcements, every action reachable | Accessibility | pending-campaign-ii | [device-campaign.md](device-campaign.md) row "VoiceOver pass" (T-A10-615) |
| System accessibility audits at default and largest text size; layouts at the largest text size | Accessibility | pending-campaign-ii | `device-campaign.md` row "Accessibility system audits and Dynamic Type" and the one app's campaign, Auto-Creator.md section 23.3, run with `VC_RUN_AUDITS=1` (T-A10-615); deferred by owner ruling of 2026-11-13 |
| Signing team, archive, validation and upload | Distribution | owner-action | [build-and-archive.md](../../release/build-and-archive.md) section 5 steps 1 to 4 (T-A10-614) |
| App Store Connect: record, App Privacy answers (no data collected, no tracking), store text from [store-listing.md](store-listing.md), screenshots, review submission | Distribution | owner-action | [build-and-archive.md](../../release/build-and-archive.md) section 5 steps 5, 6, 8 and 9 (T-A10-614) |

## Artifact inventory

Documents of this phase (all under `docs/apps/neon-arcade/` unless a path is given):

- `privacy-and-credits.md` — stored data, how to delete, permissions, sound and haptics, what is not done,
  required-reason APIs, credits (T-A10-602).
- `store-listing.md` — store text input with the claim → proving-test table (T-A10-606).
- `release-checklist.md` — this checklist (T-A10-606).
- `release.json` — release configuration read by `check_experience_release.py` and `release_check.py` (T-A10-606).
- `device-campaign.md` — device measurements with procedure, pass criterion and pending result (feature 079
  T-A10-504).
- `content-licenses.md` — author and license of the player, every hazard, the orb and every pattern, generated by
  `LicenseAudit`.
- `README.md` — links to every document (updated by T-A10-606).
- `docs/release/known-limitations.md`, section "Neon Arcade" — device-only items, the table's size, local scores only,
  the run-number rule (T-A10-606).
- `docs/release/build-and-archive.md` — app-wide build and owner steps (existing).
- `visualcore-contract.json`, `visualcore-contract.md`, `regression-baseline.md` — Phase 00 documents (existing).

Configuration:

- `Configs/copy-claims-denylist.json` — shared copy-claim denylist (unchanged; Clarifications Q2).
- `specs/080-na-p06-release/scan-claims-release.sh` — skill and ranking word scan and test-name check of the claim
  table (T-A10-607).
- `scripts/release_check.py` — `NASettingsUITests` in chunk `r2` (T-A10-608).

Code and test artifacts of this phase:

- `Packages/ExperiencesCreative/Package.swift` — `resources: [.copy("Fixtures")]` of `NeonArcadeExperienceTests`
  (T-A10-604).
- `Packages/ExperiencesCreative/NeonArcade/ExperienceTests/Fixtures/` — four sample high-score files (valid board
  version 1 with three entries, newer board version 2, damaged, truncated) (T-A10-604).
- `Packages/ExperiencesCreative/NeonArcade/ExperienceTests/HighScoreSampleFileTests.swift` (T-A10-605).
- `Packages/ExperiencesCreative/NeonArcade/ExperienceTests/ArcadeRecoveryDrawTests.swift`, using the existing
  `failNextDraw` seam in `ArcadePresenter.swift` (T-A10-605).
- `Apps/VisualCore/Tests/UI/NeonArcade/NASettingsUITests.swift` (T-A10-608), beside the existing `NASupport.swift` and
  `NAArcadeUITests.swift`.

Test files cited by this checklist and the store text (existing): `Packages/ExperiencesCreative/NeonArcade/`
`CoreTests/{ArcadeAnnouncementsTests, ArcadeBudgetTests, ArcadeCatalogTests, ArcadeEffectsTests, ArcadeFlowTests,
ContrastTests, DifficultyTests, GameRunTests, GameSimulationTests, HighScoreTableTests, LicenseAuditTests, ReplayTests,
SensitivityTests, WaveDirectorTests}.swift` and `ExperienceTests/{ArcadeCoreTests, ArcadeRenderTests,
ArcadeSessionTests, HighScoreStoreTests}.swift`; `Packages/VisualCore/Tests/VisualCoreSimulationTests/Collision2DTests.swift`,
`Packages/VisualCore/Tests/VisualCoreAudioDSPTests/SoundEffectSynthTests.swift`,
`Packages/VisualCoreRendering/Tests/VisualCoreAudioTests/SoundEffectPlayerTests.swift`.

Evidence files (legacy ledger, stage A10-P06): `na-no-network`, `release-docs`, `arcade-ios27`, `app-ui`, `verify-27`,
`release-checks`, `script-tests` under `.autonomy/checks/A10-P06.<name>.json`; baseline cited from
`.autonomy/checks/A10-P05.{arcade-ios27,app-ui,verify-27}.json` (T-A10-601); earlier phases cited from
`.autonomy/checks/A10-P01.visualcore-host.json`, `.autonomy/checks/A10-P03.{audio-dsp-host,audio-player-ios27-2}.json`
and `.autonomy/checks/A10-P05.{catalog,claims-2}.json`.
