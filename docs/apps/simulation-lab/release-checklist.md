# Simulation Lab — release checklist and artifact inventory

Simulation Lab (`a16.simulation-lab`) ships inside the one VisualCore app (ADR-0009); feature 122 (A16-P06),
FR-A16-620, FR-A16-621, FR-A16-622, FR-A16-630, FR-A16-631 and FR-A16-632. App-wide commands are in
[build-and-archive.md](../../release/build-and-archive.md). The statuses are the words that
`scripts/check_experience_release.py` accepts for every experience (Clarifications Q1):

- `verified`: the evidence named in the row is a check of the legacy ledger (`.autonomy/checks/A16-P06.<name>.json`,
  recorded with `desktop_runbook.py run-check` before A16-P06 is sealed) or a sealed earlier phase
  (`.autonomy/checks/A16-P0N.*.json`; the A16-P05 package run `.autonomy/checks/A16-P05.sl-ios27-2.json` passed 63
  XCTest tests and 85 Swift Testing tests in 14 suites on the unchanged sources, cited as the baseline by T-A16-601).
  A row whose check file does not exist yet is pending: the task named in the row records it, and A16-P06 is not
  sealed before every such file exists and passed;
- `pending-campaign-ii` (spec: pending device campaign): needs the device campaign D1 → D2 → D3 after
  `ImplementationLock-100`; the row names its row of [device-campaign.md](device-campaign.md) or the one app's campaign
  (Auto-Creator.md section 23.3); no device number is claimed before then;
- `owner-action` (spec: owner action): done by the owner only, steps in
  [build-and-archive.md](../../release/build-and-archive.md) section 5 (`BLOCKED_OWNER_ACTION` until done); never done
  by the agent (CLAUDE.md rule 6).

`scripts/check_experience_release.py --config docs/apps/simulation-lab/release.json` rejects a row without a known
status or without evidence.

| Item | Area | Status | Evidence |
|---|---|---|---|
| Privacy and credits note: what is stored and where (`preset-<uuid>.json` saved experiments, at most 24, in the experience's storage; the app's `state.json` session state, at most 1,048,576 bytes; the latest picture in `tmp/a16-captures`, at most one, emptied when the experience opens), nothing sent, a picture leaving only through the share sheet the person opens, how to delete (Delete per experiment; a new capture or a reopen for the picture; the Settings reset of the experience's data; the reset of all data; removing the app); the license inventory of the six presets, the three palettes and the shader programs | Privacy | verified | [privacy-and-credits.md](privacy-and-credits.md) (T-A16-602); `.autonomy/checks/A16-P06.release-checks.json` (`experience-release-a16`, T-A16-611) |
| No network, tracking, sensor, recording, microphone input, photo-library, image-picker, system-brightness or idle-timer use in the experience's sources | Privacy | verified | `.autonomy/checks/A16-P06.sl-no-network.json` (`specs/122-sl-p06-release/scan-sources-release.sh`, T-A16-603) |
| No permission requested and no usage string added (the registration declares `"permissions": []`; the share sheet needs none); no sound and no haptic; the app's usage strings unchanged | Privacy | verified | `.autonomy/checks/A16-P06.release-checks.json` (`app-usage-descriptions`, T-A16-611); `Catalog/registrations.json`; `project.yml`; [privacy-and-credits.md](privacy-and-credits.md) |
| App privacy manifest matches the Release build and covers the experience's required-reason uses | Privacy | verified | `.autonomy/checks/A16-P06.release-checks.json` (`app-privacy-manifest`, T-A16-611); [privacy-and-credits.md](privacy-and-credits.md) |
| No tracking or advertising in the built app | Privacy | verified | `.autonomy/checks/A16-P06.release-checks.json` (`app-no-tracking`, T-A16-611) |
| The capture: one 1024 × 1024 PNG in `tmp/a16-captures`; a new capture replaces the previous file; a failed render leaves no file; the folder is emptied when a presenter opens; capturing changes nothing in the simulation | Privacy | verified | `.autonomy/checks/A16-P05.sl-ios27-2.json` (`CaptureTests.testCapturesLeaveOnePNGAndChangeNothing`; `CaptureFileTests.testTwoCapturesLeaveOneFile`, `testThrowingRenderLeavesNoFile`, `testClearFolderEmpties`, `testAPresenterEmptiesTheCaptureFolder`; baseline, T-A16-601); `.autonomy/checks/A16-P06.sl-ios27.json` (T-A16-609) |
| Credits and licenses: six bundled presets with source and license (Life, Conway 1970; HighLife, Thompson 1994; Seeds, Silverman; Spots and Mazes, Pearson 1993: public-domain; Pulse, VisualCore: original); every bundled preset valid and attributed | Credits | verified | `.autonomy/checks/A16-P05.sl-ios27-2.json` (`ExperimentPresetTests.theSixFamilyPresetsAreBundled`, `everyBundledPresetIsValidAndAttributed`, `everyBundledPresetRoundTrips`; baseline, T-A16-601); `.autonomy/checks/A16-P06.sl-ios27.json` (T-A16-609); [privacy-and-credits.md](privacy-and-credits.md) |
| Licenses and acknowledgements: visuals made in code (the three `SimulationPalette` colour maps; the GLSL programs of `SimulationShaders.swift`, `GrayScottGPU.swift` and `WaveGPU.swift`, original code; native legend and inspector); no third-party code, image, font or sound in the experience; app Licenses folder equals the inventory | Credits | verified | `.autonomy/checks/A16-P06.release-checks.json` (`app-licenses`, T-A16-611); `SimulationRenderTests.testThePaletteMapsEachFamily`, `testEveryFamilyDrawsANonBlankFrame` in `.autonomy/checks/A16-P05.sl-ios27-2.json` (baseline, T-A16-601) and `.autonomy/checks/A16-P06.sl-ios27.json` (T-A16-609) |
| Educational approximation labels: every family shows and speaks its grid, values, boundary and step method ("Approximation: 64 × 64 cells, exact states (0 or 1), wrap boundary."; the reaction-diffusion label names the explicit Euler step and the wave's the leapfrog step); the validation report states the CPU and GPU agreement, the stability limits and the bounds | Content | verified | `.autonomy/checks/A16-P05.sl-ios27-2.json` (`InspectorWordsTests.theApproximationLabels`, `theInspectorRows`, `theDescriptionSpeaksTheState`; `SimulationValidationTests.testTheValidationReport`; baseline, T-A16-601); `.autonomy/checks/A16-P06.sl-ios27.json` (T-A16-609); `.autonomy/checks/A16-P06.app-ui.json` (`SLExploreUITests` reads the approximation element after Spots, T-A16-610); [validation-report.md](validation-report.md) |
| Store text input describing only implemented and tested features, with a claim → proving-test table; no performance figure, no device value and none of the refused words of Clarifications Q2 (no accuracy, prediction, certification or measured-performance word); unsupported promised features absent from the interface and the store text | Store | verified | [store-listing.md](store-listing.md) (T-A16-606); `.autonomy/checks/A16-P06.sl-claims.json` (`specs/122-sl-p06-release/scan-claims-release.sh`, T-A16-607) |
| Copy check: no measured claim, unmeasured quality word or missing feature in the store text and interface strings (only `share` allowed: the captured picture's share sheet) | Store | verified | `.autonomy/checks/A16-P06.release-checks.json` (`copy-claims-a16`, T-A16-611; `Configs/copy-claims-denylist.json`); earlier pass `.autonomy/checks/A16-P04.copy-claims-3.json` |
| Experience release check: required documents present (privacy and credits, store text, checklist, device campaign, validation report, VisualCore contract, build and archive), every checklist row has status and evidence | Store | verified | `.autonomy/checks/A16-P06.release-checks.json` (`experience-release-a16`, T-A16-611) |
| Sample stored files: `preset-{valid,newer,damaged,invalid}.json` answered by `SimulationPresetStore` (valid listed; newer, damaged and invalid reported) and `state-{valid,newer,damaged}.json` answered by `SimulationCore.restore` (valid restores; newer and damaged refused with their reasons); each stays byte-identical | Data | verified | `.autonomy/checks/A16-P06.sl-ios27.json` (`StoredFileSampleTests`; T-A16-605, T-A16-609) |
| Saved experiments: a saved experiment loads back in a new store and reopens in a new session; at most 24 files; damaged, newer and refused files reported and skipped, never deleted; Delete removes the file; sorted by name then id | Data | verified | `.autonomy/checks/A16-P05.sl-ios27-2.json` (`PresetStoreTests.testRoundTripAcrossStores`, `testASavedExperimentReopensInANewSession`, `testCapOfTwentyFour`, `testDamagedAndNewerFilesAreSkipped`, `testAPresetWithARefusedSpecIsReportedAndSkipped`, `testDeleteRemoves`, `testSortedByNameThenId`; `ExperimentPresetTests.damagedBytesAreRefusedAsDamaged`, `aNewerSchemaIsRefusedAsNewer`, `aRefusedSpecIsRefusedAsInvalid`; baseline, T-A16-601); `.autonomy/checks/A16-P06.sl-ios27.json` (T-A16-609) |
| Session state: the saved state restores to the same digest in a new session; damaged, newer and out-of-range states refused and the state stays; the round trip is byte for byte | Data | verified | `.autonomy/checks/A16-P05.sl-ios27-2.json` (`SimulationSessionTests.testTheSavedStateRestoresToTheSameDigestInANewSession`, `testADamagedSavedStateIsRefusedAndTheStateStays`; `SimulationStateTests.theRoundTripIsByteForByte`, `damagedPayloadsAreRefused`, `newerVersionsAreRefused`, `outOfRangeSettingsAreRefused`, `outOfRangeFieldValuesAreRefused`; `SimulationCoreTests.snapshotAndRestoreGiveTheSameDigest`; baseline, T-A16-601); `.autonomy/checks/A16-P06.sl-ios27.json` (T-A16-609) |
| Old sessions: no schema examples. The state and preset schemas are at version 1, so no older stored form exists and none is registered (research D6) | Data | verified | `Packages/ExperiencesCreative/SimulationLab/Core/SimulationState.swift` (`SimulationState.schemaVersion = 1`); `Packages/ExperiencesCreative/SimulationLab/Core/ExperimentPreset.swift` (`ExperimentPreset.schemaVersion = 1`); `SimulationStateTests.newerVersionsAreRefused`, `ExperimentPresetTests.aNewerSchemaIsRefusedAsNewer` in `.autonomy/checks/A16-P05.sl-ios27-2.json` (baseline, T-A16-601) |
| Drawing-failure recovery: a failed draw after a save fails the session, the preset file is byte-identical, a new session over the same storage lists it and `sim.spec` opens it | Recovery | verified | `.autonomy/checks/A16-P06.sl-ios27.json` (`SimulationRecoveryDrawTests`, test-only `failNextDraw` seam; T-A16-604, T-A16-609) |
| Accessibility (automated): labels, values and hints on every control, each with an identifier `experience.a16.simulation-lab.<name>` (`SimulationControls.swift`); hit areas at least 44 points high; the status line names the state and the step; refused actions are answered in words (time step beyond the stability limit, a faster speed under Reduce Motion) | Accessibility | verified | `.autonomy/checks/A16-P05.sl-ios27-2.json` (`InspectorWordsTests.theInspectorRows`; `TimeStepMessageTests.testRefusedTimeStepsShowTheirSentenceAndAnAcceptedOneClearsIt`; `SimulationCoreTests.refusalsChangeNothing`; `SimulationSessionTests.testActionsThroughThePortAndARefusalIsAnswered`; baseline, T-A16-601); `.autonomy/checks/A16-P06.sl-ios27.json` (T-A16-609); `.autonomy/checks/A16-P06.app-ui.json` (`SLExploreUITests`, `SLLibraryUITests`, chunk x2, T-A16-610) |
| Accessibility (automated): a native control for every gesture — the Seed button with its column and row steppers paints the cell a tap paints | Accessibility | verified | `.autonomy/checks/A16-P05.sl-ios27-2.json` (`PaintTests.testTouchesPaintCellsLikeTheSeedRow`; baseline, T-A16-601); `.autonomy/checks/A16-P06.sl-ios27.json` (T-A16-609); `.autonomy/checks/A16-P06.app-ui.json` (chunk x2 uses Seed, T-A16-610) |
| Accessibility (automated): canvas description with the family, the preset, the grid, the state and the step, with the legend in words, so colour is never the only information | Accessibility | verified | `.autonomy/checks/A16-P05.sl-ios27-2.json` (`SimulationCoreTests.theWordsNameTheFamilyPresetGridStateAndStep`; `InspectorWordsTests.theDescriptionSpeaksTheState`; `LegendTests.thePresenterCarriesTheLegendAndOffersTheOverlay`; baseline, T-A16-601); `.autonomy/checks/A16-P06.sl-ios27.json` (T-A16-609) |
| Accessibility (automated): motion — with Reduce Motion the simulation opens paused and the speed is capped at ×1; with Reduce Flashing the automaton is capped at ×0.25; drawing never changes the state | Accessibility | verified | `.autonomy/checks/A16-P05.sl-ios27-2.json` (`SimulationSessionTests.testReduceMotionOpensPaused`; `MotionCapTests.testTheCapsPerSettingAndFamily`, `testAFasterSpeedIsRefusedAndAFamilyChangeLowersIt`, `testActivationLowersARestoredSpeed`; `SimulationRenderTests.testDrawingNeverChangesTheDigest`; baseline, T-A16-601); `.autonomy/checks/A16-P06.sl-ios27.json` (T-A16-609) |
| ExperiencesCreative package suites of Simulation Lab on the iOS 27 simulator (sim-27.2; iOS 26 at X-A16 by owner ruling of 2026-11-14), the slowest test under 10 s | Tests | verified | `.autonomy/checks/A16-P05.sl-ios27-2.json` (baseline, T-A16-601); `.autonomy/checks/A16-P06.sl-ios27.json` (`SimulationLabCoreTests`, `SimulationLabExperienceTests`, T-A16-609) |
| App build, unit tests and interface chunk x2 (serial): Pause, the status starts "Paused"; Step, the step count rises by one; the bundled preset Spots, the status names time step 1 and the approximation label names the Euler step; Seed, the step count unchanged; type "My spots" and Save experiment, a "My spots" button appears; reopen the experience, it is still listed; the share sheet is never presented | Tests | verified | `.autonomy/checks/A16-P05.app-unit.json` (baseline, T-A16-601); `.autonomy/checks/A16-P06.app-ui.json` (`app-build-for-testing-ios27`, `app-unit-ios27`, `app-ui-ios27-x2`: `SLExploreUITests`, `SLLibraryUITests`, iOS 27.2 phone simulator, each test under 60 s, T-A16-608, T-A16-610) |
| Experience runner on iOS 27 (standard scenarios) | Tests | verified | `.autonomy/checks/A16-P05.verify-27.json` (baseline, T-A16-601); `.autonomy/checks/A16-P06.verify-27.json` (T-A16-610) |
| Script tests (the release and copy-claim tools with the new release configuration) | Tests | verified | `.autonomy/checks/A16-P06.script-tests.json` (T-A16-612) |
| VisualCore contract: G-RELEASE closed by A16-P06 | Tests | verified | `.autonomy/checks/A16-P06.contract.json` (`scripts/check_app_contract.py --app simulation-lab --render`, T-A16-612); [visualcore-contract.md](visualcore-contract.md) |
| Release build checks: unsigned Release build, no debug or scenario symbols, manifest, tracking, licenses, usage strings, experience release documents, copy claims | Build | verified | `.autonomy/checks/A16-P06.release-checks.json` (T-A16-611) |
| Build-and-archive instructions for the one app, owner steps marked | Build | verified | [build-and-archive.md](../../release/build-and-archive.md); its agent-run release steps in `.autonomy/checks/A16-P06.release-checks.json` (T-A16-611) |
| Frame pacing at ×4 for each family on D1 to D3 | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row SL-D1 "Frame pacing at ×4"; no number is claimed before device evidence |
| Thermal state and peak memory over a short run | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row SL-D2 "Thermal state over a short run" |
| VoiceOver on hardware reading every control, the canvas description and the legend | Accessibility | pending-campaign-ii | [device-campaign.md](device-campaign.md) row SL-D3 "VoiceOver reading the description and the legend" and the one app's campaign, Auto-Creator.md section 23.3 |
| Dynamic Type at the largest accessibility size and the system accessibility audits at the default and the largest text size | Accessibility | pending-campaign-ii | [device-campaign.md](device-campaign.md) row SL-D4 "Dynamic Type at the largest size", run with `VC_RUN_AUDITS=1`; deferred to the device campaign by owner ruling of 2026-11-13 |
| Floating-point render-target support on the oldest device, and the refusal sentence where it is missing | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row SL-D5 "Float-target support on the oldest device"; the refusal path is proved on the simulator by `FloatUnsupportedTests` only |
| Share sheet to Files on hardware (save, cancel, two captures, reopen) | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row SL-D6 "Share sheet to Files"; never automated, since the share sheet waits for a person |
| Signing set-up: team, certificates and provisioning profiles | Distribution | owner-action | `BLOCKED_OWNER_ACTION`: [build-and-archive.md](../../release/build-and-archive.md) section 5 step 1 (create the gitignored `Configs/Signing.local.xcconfig` with `DEVELOPMENT_TEAM`; certificates and profiles in Xcode Settings › Accounts with the owner's Apple account) and step 2 (final bundle and product identifiers) |
| Archive of the one app | Distribution | owner-action | `BLOCKED_OWNER_ACTION`: [build-and-archive.md](../../release/build-and-archive.md) section 5 step 3 (open `VisualCore.xcodeproj`, scheme `VisualCore`, destination "Any iOS Device (arm64)", Product › Archive) |
| Validation and upload of the archive | Distribution | owner-action | `BLOCKED_OWNER_ACTION`: [build-and-archive.md](../../release/build-and-archive.md) section 5 step 4 (Organizer, Validate App, then Distribute App › App Store Connect › Upload) |

The App Store Connect record, the App Privacy answers (no data collected, no tracking), the store text from
[store-listing.md](store-listing.md), the screenshots and the review submission are further owner steps of the one app
([build-and-archive.md](../../release/build-and-archive.md) section 5 steps 5, 6, 8 and 9), recorded once for the app as
`BLOCKED_OWNER_ACTION`; the agent never does them.

No schema examples: the state and preset schemas are at version 1.

## Accessibility: proved so far and pending for devices

Proved by the experience's tests on the iOS 27 simulator (rows above): labels, values, hints and identifiers on every
control and hit areas at least 44 points high; a native control for every gesture (the Seed button and its column and
row steppers paint what a tap paints); the canvas description with the family, the preset, the grid, the state and
the step, with the legend in words, so colour is never the only information; the approximation label shown and
spoken; refused actions answered in words; Reduce Motion opening paused with the speed capped at ×1, and Reduce
Flashing capping the automaton at ×0.25. Pending for devices (owner ruling of 2026-11-13: all system accessibility
audits wait for device testing): VoiceOver on hardware (SL-D3) and Dynamic Type at the largest sizes with the system
accessibility audits (SL-D4).

## Artifact inventory

Documents of this phase (all under `docs/apps/simulation-lab/` unless a path is given):

- `privacy-and-credits.md` — stored data, what is read, how a picture leaves, how to delete, permissions, what is not
  done, required-reason APIs, the license inventory (T-A16-602).
- `store-listing.md` — store text input with the claim → proving-test table (T-A16-606).
- `release-checklist.md` — this checklist (T-A16-606).
- `release.json` — release configuration read by `check_experience_release.py` and `release_check.py` (T-A16-606;
  `specs/122-sl-p06-release/contracts/release.md`).
- `device-campaign.md` — device measurements SL-D1 … SL-D6 with procedure, threshold and pending status (T-A16-606).
- `docs/release/known-limitations.md`, section "Simulation Lab" — the 64 × 64 grid, half-float values, the stability
  limits, float targets for two families and the device-only items (T-A16-606).
- `validation-report.md` — the CPU and GPU agreement, the stability limits, the bounds and the boundary rules,
  generated by `SimulationValidationTests` (A16-P05).
- `docs/release/build-and-archive.md` — app-wide build and owner steps (existing).
- `README.md`, `visualcore-contract.json`, `visualcore-contract.md`, `regression-baseline.md` — existing documents.

Configuration:

- `Configs/copy-claims-denylist.json` — shared copy-claim denylist (unchanged; Clarifications Q2).
- `specs/122-sl-p06-release/scan-sources-release.sh` — source scan of Clarifications Q3 (T-A16-603).
- `specs/122-sl-p06-release/scan-claims-release.sh` — refused-word scan of the store text and the interface Swift and
  test-name check of the claim table (T-A16-607).
- `scripts/release_check.py` — serial interface chunk `x2` with `SLExploreUITests` and `SLLibraryUITests`
  (T-A16-608).

Code and test artifacts of this phase:

- `Packages/ExperiencesCreative/SimulationLab/Experience/SimulationPresenter.swift` — the test-only `failNextDraw`
  seam (T-A16-604).
- `Packages/ExperiencesCreative/SimulationLab/ExperienceTests/SimulationRecoveryDrawTests.swift` (T-A16-604).
- `Packages/ExperiencesCreative/SimulationLab/ExperienceTests/Fixtures/` with
  `preset-{valid,newer,damaged,invalid}.json` and `state-{valid,newer,damaged}.json`, the test target's resources in
  `Packages/ExperiencesCreative/Package.swift`, and `ExperienceTests/StoredFileSampleTests.swift` (T-A16-605).
- `Apps/VisualCore/Tests/UI/SimulationLab/SLSupport.swift`, `SLExploreUITests.swift`, `SLLibraryUITests.swift`
  (T-A16-608).

Test files cited by this checklist and the store text (existing): `Packages/ExperiencesCreative/SimulationLab/`
`CoreTests/{AutomatonRuleTests, ExperimentPresetTests, GrayScottTests, SchedulerTests, SimulationBrushTests,
SimulationSpecTests, SimulationStateTests, WaveFieldTests}.swift` and `ExperienceTests/{AutomatonParityTests,
CaptureFileTests, CaptureTests, FloatFieldToleranceTests, FloatMirrorTests, FloatUnsupportedTests,
GrayScottToleranceTests, InspectorWordsTests, LegendTests, MotionCapTests, PaintTests, PresetStoreTests,
SimulationCoreTests, SimulationRenderTests, SimulationSessionTests, SimulationValidationTests, StepExactTests,
TimeStepMessageTests, TimeStepTests, WaveBorderTests}.swift`.

Evidence files (legacy ledger, stage A16-P06): `sl-no-network`, `sl-ios27`, `sl-claims`, `app-ui`, `verify-27`,
`release-checks`, `contract`, `script-tests` under `.autonomy/checks/A16-P06.<name>.json`; sealed evidence of the
earlier phases `.autonomy/evidence/A16-P00.json` … `A16-P05.json`; baseline cited from
`.autonomy/checks/A16-P05.{sl-ios27-2,app-unit,verify-27}.json` (T-A16-601).
