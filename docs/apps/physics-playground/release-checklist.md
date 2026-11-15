# Physics Playground — release checklist and artifact inventory

Physics Playground (`a11.physics-playground`) ships inside the one VisualCore app (ADR-0009); feature 087 (A11-P06),
FR-A11-620, FR-A11-622, FR-A11-623, FR-A11-640 and FR-A11-641. App-wide commands are in
[build-and-archive.md](../../release/build-and-archive.md). The statuses are the words that
`scripts/check_experience_release.py` accepts for every experience (Clarifications Q1):

- `verified`: the evidence named in the row is a check of the legacy ledger (`.autonomy/checks/A11-P06.<name>.json`,
  recorded with `desktop_runbook.py run-check` before A11-P06 is sealed) or a sealed earlier phase
  (`.autonomy/checks/A11-P0N.*.json`). A row whose check file does not exist yet is pending: the task named in the row
  records it, and A11-P06 is not sealed before every such file exists and passed;
- `pending-campaign-ii` (spec: device): needs the device campaign D1 → D2 → D3 after `ImplementationLock-100`; the row
  names its row of [device-campaign.md](device-campaign.md) or the one app's campaign (Auto-Creator.md section 23.3);
  task T-A11-615;
- `owner-action` (spec: blocked-owner): done by the owner only, steps in
  [build-and-archive.md](../../release/build-and-archive.md) section 5 (`BLOCKED_OWNER_ACTION` until done); task
  T-A11-614.

`scripts/check_experience_release.py --config docs/apps/physics-playground/release.json` rejects a row without a known
status or without evidence.

| Item | Area | Status | Evidence |
|---|---|---|---|
| Privacy and credits note: what is stored and where (`experiment-<slot>.json` saved experiments, the app's `state.json`), nothing sent, no personal data, how to delete (a slot's Clear, the Settings reset of the experience's data, removing the app), every material, preset and tutorial credited with author and license | Privacy | verified | [privacy-and-credits.md](privacy-and-credits.md) (T-A11-602); [content-licenses.md](content-licenses.md); `.autonomy/checks/A11-P06.release-docs.json` (`experience-release-a11`, T-A11-607) |
| No network, tracking, sensor, recording, microphone input, system-brightness or idle-timer use in the experience's sources | Privacy | verified | `.autonomy/checks/A11-P06.pp-no-network.json` (T-A11-603) |
| No permission requested and no usage string added (the registration declares `"permissions": []`); no sound and no haptics; the app's usage strings unchanged | Privacy | verified | `.autonomy/checks/A11-P06.release-checks.json` (`app-usage-descriptions`, T-A11-612); `Catalog/registrations.json`; `project.yml`; [privacy-and-credits.md](privacy-and-credits.md) |
| App privacy manifest matches the Release build and covers the experience's required-reason uses | Privacy | verified | `.autonomy/checks/A11-P06.release-checks.json` (`app-privacy-manifest`, T-A11-612); [privacy-and-credits.md](privacy-and-credits.md) |
| No tracking or advertising in the built app | Privacy | verified | `.autonomy/checks/A11-P06.release-checks.json` (`app-no-tracking`, T-A11-612) |
| Licenses and acknowledgements: the four materials, four presets and two tutorials are MIT content of the VisualCore project; no third-party code or asset in the experience; app Licenses folder equals the inventory | Credits | verified | `.autonomy/checks/A11-P06.release-checks.json` (`app-licenses`, T-A11-612); `LicenseAuditTests.theCommittedLicenseDocumentMatchesTheCatalog` in `.autonomy/checks/A11-P05.playground-ios27.json` (baseline, T-A11-601) and `.autonomy/checks/A11-P06.playground-ios27-2.json` (T-A11-609) |
| Store text input describing only implemented and tested features, with a claim → proving-test table; no number with a unit, no device value and none of the refused words of Clarifications Q2; unsupported promised features absent from the interface and the store text | Store | verified | [store-listing.md](store-listing.md) (T-A11-606); `.autonomy/checks/A11-P06.release-docs.json` (`scan-claims-release.sh`, T-A11-607) |
| Copy check: no measured claim, unmeasured quality word or missing feature in the store text and interface strings (nothing allowed) | Store | verified | `.autonomy/checks/A11-P06.release-docs.json` (`copy-claims-a11`, T-A11-607; `Configs/copy-claims-denylist.json`) |
| Catalog entry and README name only proven capabilities and make none of the refused claims | Store | verified | `.autonomy/checks/A11-P05.claims-2.json` (`specs/086-pp-p05-stability/scan-claims.sh`); `.autonomy/checks/A11-P05.catalog.json` |
| Experience release check: required documents present, every checklist row has status and evidence | Store | verified | `.autonomy/checks/A11-P06.release-docs.json` (`experience-release-a11`, T-A11-607) |
| Sample experiment files: exactly four bundled; the valid one (file schema 1) opens; the newer (file schema 2), damaged and truncated ones are refused and stay byte-identical | Data | verified | `.autonomy/checks/A11-P04.playground-ios27.json` (introduced in A11-P04); `.autonomy/checks/A11-P06.playground-ios27-2.json` (`ExperimentSampleFileTests.testExactlyTheFourSamplesAreBundled`, `testTheValidSampleOpens`, `testTheRefusedSamplesAreRefusedAndLeftByteIdentical`; T-A11-605, T-A11-609) |
| Saved experiments: save and read round trip without grab and selection, names cut or defaulted, an empty slot refused and Clear removing the file, a slot outside 0…3 refused, refused files reported and left untouched, storage refusals reported with nothing changed | Data | verified | `.autonomy/checks/A11-P05.playground-ios27.json` (`ExperimentStoreTests`; baseline, T-A11-601); `.autonomy/checks/A11-P06.playground-ios27-2.json` (T-A11-609) |
| Session state: the stored examples of snapshot schemas 1 to 4 restore to schema 5; newer and damaged snapshots refused and the starting scene opens | Data | verified | `.autonomy/checks/A11-P06.playground-ios27-2.json` (`PlaygroundRecoveryDrawTests.testTheStoredSchemaOneToFourExamplesRestore`; `PlaygroundQualityTests.testTheStoredExamplesOfSchemasOneToFourRestore`, `testTheSchemaFourExampleRestoresThroughTheStepFourToFive`; `PlaygroundSessionTests.testANewerSavedStateIsRefusedAndTheStartingSceneOpens`, `testADamagedSavedStateIsRefusedAndTheStartingSceneOpens`; T-A11-604, T-A11-609) |
| Drawing-failure recovery: failure state, `experiment-<slot>.json` byte-identical, a new session draws and opens the saved experiment | Recovery | verified | `.autonomy/checks/A11-P06.playground-ios27-2.json` (`PlaygroundRecoveryDrawTests.testADrawingFailureFailsTheSessionAndKeepsTheSavedExperiment`, test-only `failNextDraw` seam; T-A11-604, T-A11-609); `PlaygroundRenderTests.testAFailedDrawReachesTheSession` |
| Accessibility (automated): labels and values — the pickers' spoken values name each level in words; the selection value names the selected body; the panel rows carry their labels; every control is built with a label, a value (or hint) and an identifier `experience.a11.physics-playground.<name>` (`PlaygroundControls.swift`) and found by identifier in the interface chunk | Accessibility | verified | `.autonomy/checks/A11-P06.playground-ios27-2.json` (`PlaygroundRenderTests.testTheDescriptionNamesBodiesStateAndTimeScale`, `testTheControlsWalkTheSelectionAndMoveAHeldBody`, `testThePanelEqualsTheDiagnosticsAndOverlaysNeverWriteTheWorld`; T-A11-609); `.autonomy/checks/A11-P06.app-ui-4.json` (`PPWorldUITests`, `PPExperimentUITests`, chunk s2, T-A11-610) |
| Accessibility (automated): native alternatives to every gesture — tap to add, tap to select, drag to grab, long press to pin, double tap to delete each have a control (Add at centre, Previous and Next body, Hold with the direction buttons, Pin, Delete); no gesture action lacks a native action | Accessibility | verified | `.autonomy/checks/A11-P06.playground-ios27-2.json` (`PlaygroundSessionTests.testTheFirstFrameDrawsTheStartingSceneAndDescribesIt`, `PlaygroundGestureTests.testThePresenterDeclaresItsGesturesAndSendsThemThroughItsPort`: `GestureAlternatives.missing` is empty; `PlaygroundRenderTests.testTheControlsWalkTheSelectionAndMoveAHeldBody`; T-A11-609); `.autonomy/checks/A11-P06.app-ui-4.json` (`PPWorldUITests`, `PPExperimentUITests` use the native controls only, T-A11-610) |
| Accessibility (automated): spoken description and tutorial steps — bodies, running or paused, time scale, springs, levels, pins, selection, grab, arrows, the opened experiment and the running tutorial's name, step and text | Accessibility | verified | `.autonomy/checks/A11-P06.playground-ios27-2.json` (`PlaygroundRenderTests.testTheDescriptionNamesBodiesStateAndTimeScale`; `PlaygroundSessionTests.testTheFirstFrameDrawsTheStartingSceneAndDescribesIt`, `testAPresetAndATutorialRunThroughTheShell`; T-A11-609); the step announcement itself is heard on hardware in the device row "VoiceOver pass" |
| Accessibility (automated): Reduce Motion — the experience has no decorative motion and nothing flashes (`PhysicsPlaygroundExperience.make` leaves `reduceMotion` and `reduceFlashing` without effect); a paused world draws the same frame, and drawing never changes the world | Accessibility | verified | `.autonomy/checks/A11-P06.playground-ios27-2.json` (`PlaygroundRenderTests.testFramesDifferWhileBodiesFallAndAPausedWorldHolds`, `testDrawingNeverChangesTheDigest`; T-A11-609) |
| ExperiencesCreative package suites of Physics Playground on the iOS 27 simulator (sim-27.2; iOS 26 at X-A11 by owner ruling of 2026-11-14) | Tests | verified | `.autonomy/checks/A11-P05.playground-ios27.json` (baseline, T-A11-601); `.autonomy/checks/A11-P06.playground-ios27-2.json` (`PhysicsPlaygroundCoreTests`, `PhysicsPlaygroundExperienceTests`, T-A11-609) |
| VisualCore pieces built for Physics Playground: box contacts, impulse solver, springs and broad phase | Tests | verified | `.autonomy/checks/A11-P01.visualcore-host.json` (`Contacts2DTests`, `ImpulseSolver2DTests`); `.autonomy/checks/A11-P02.visualcore-host-1.json` (`Springs2DTests`, `BroadPhase2DTests`, `ImpulseSolver2DTests`, `Contacts2DTests`) |
| App build, unit tests and interface chunk s2 (serial): drop a body, pause, single step and time scale, force arrows; open a preset, start and stop a tutorial | Tests | verified | `.autonomy/checks/A11-P05.app-unit.json` (baseline, T-A11-601); `.autonomy/checks/A11-P06.app-ui-4.json` (`app-build-for-testing-ios27`, `app-unit-ios27`, `app-ui-ios27-s2`: `PPWorldUITests`, `PPExperimentUITests`, iOS 27.2 phone simulator, each test under 60 s, T-A11-608, T-A11-610) |
| Experience runner on iOS 27 (nine standard scenarios) | Tests | verified | `.autonomy/checks/A11-P05.verify-27.json` (baseline, T-A11-601); `.autonomy/checks/A11-P06.verify-27.json` (T-A11-611) |
| Release build checks: unsigned Release build, no debug or scenario symbols, manifest, tracking, licenses, usage strings | Build | verified | `.autonomy/checks/A11-P06.release-checks.json` (T-A11-612) |
| Release document and copy check scripts tested (pass and fail cases) | Build | verified | `.autonomy/checks/A11-P06.script-tests.json` (T-A11-613) |
| Build-and-archive instructions for the one app, owner steps marked | Build | verified | [build-and-archive.md](../../release/build-and-archive.md); its agent-run release steps in `.autonomy/checks/A11-P06.release-checks.json` (T-A11-612) |
| Frame pacing per quality level (stacked objects and free play at 48 bodies, levels 0, 1 and 2) | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row PP-D1 "Frame pacing per quality level" (T-A11-615); no number is claimed before device evidence |
| Thermal state over 10 minutes | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row PP-D2 "Thermal state over 10 minutes" (T-A11-615) |
| Touch latency for grab | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row PP-D3 "Touch latency for grab" (T-A11-615) |
| VoiceOver on hardware: every control reachable and labelled, the spoken description and the tutorial steps announced | Accessibility | pending-campaign-ii | [device-campaign.md](device-campaign.md) row PP-D4 "VoiceOver pass" (T-A11-615) |
| System accessibility audits at default and largest text size; Dynamic Type layouts at the largest text size | Accessibility | pending-campaign-ii | [device-campaign.md](device-campaign.md) row PP-D5 "Accessibility system audits and Dynamic Type" and the one app's campaign, Auto-Creator.md section 23.3, run with `VC_RUN_AUDITS=1` (T-A11-615); deferred by owner ruling of 2026-11-13 |
| Signing team, archive, validation and upload | Distribution | owner-action | `BLOCKED_OWNER_ACTION`: [build-and-archive.md](../../release/build-and-archive.md) section 5 steps 1 to 4 (T-A11-614) |
| App Store Connect: record, App Privacy answers (no data collected, no tracking), store text from [store-listing.md](store-listing.md), screenshots, review submission | Distribution | owner-action | `BLOCKED_OWNER_ACTION`: [build-and-archive.md](../../release/build-and-archive.md) section 5 steps 5, 6, 8 and 9 (T-A11-614) |

## Artifact inventory

Documents of this phase (all under `docs/apps/physics-playground/` unless a path is given):

- `privacy-and-credits.md` — stored data, how to delete, permissions, what is not done, required-reason APIs, credits
  (T-A11-602).
- `store-listing.md` — store text input with the claim → proving-test table (T-A11-606).
- `release-checklist.md` — this checklist (T-A11-606).
- `release.json` — release configuration read by `check_experience_release.py` and `release_check.py` (T-A11-606;
  `specs/087-pp-p06-release/contracts/release-config.md`).
- `device-campaign.md` — device measurements with procedure, threshold and pending status (feature 086, A11-P05); row
  PP-D5 for the system accessibility audits added in T-A11-606.
- `content-licenses.md` — author and license of every material, preset and tutorial, generated by `LicenseAudit`.
- `README.md` — links to every document (updated by T-A11-606).
- `docs/release/known-limitations.md`, section "Physics Playground" — device-only items and the educational
  approximation of the numbers (T-A11-606).
- `docs/release/build-and-archive.md` — app-wide build and owner steps (existing).
- `visualcore-contract.json`, `visualcore-contract.md`, `regression-baseline.md` — Phase 00 documents (existing).

Configuration:

- `Configs/copy-claims-denylist.json` — shared copy-claim denylist (unchanged; Clarifications Q2).
- `specs/087-pp-p06-release/scan-claims-release.sh` — refused-word scan of the store text and the interface Swift and
  test-name check of the claim table (T-A11-607).
- `scripts/release_check.py` — serial interface chunk `s2` with `PPWorldUITests` and `PPExperimentUITests`
  (T-A11-608).

Code and test artifacts of this phase:

- `Packages/ExperiencesCreative/PhysicsPlayground/ExperienceTests/PlaygroundRecoveryDrawTests.swift`, using the existing
  `failNextDraw` seam in `PlaygroundPresenter.swift` (T-A11-604).
- `Apps/VisualCore/Tests/UI/PhysicsPlayground/PPSupport.swift`, `PPWorldUITests.swift`, `PPExperimentUITests.swift`
  (T-A11-608).

Existing artifacts re-run here: the four sample experiment files in
`Packages/ExperiencesCreative/PhysicsPlayground/ExperienceTests/Fixtures/` (`experiment-valid.json`,
`experiment-newer.json`, `experiment-damaged.json`, `experiment-truncated.json`) and
`ExperienceTests/ExperimentSampleFileTests.swift` (A11-P04; T-A11-605).

Test files cited by this checklist and the store text (existing): `Packages/ExperiencesCreative/PhysicsPlayground/`
`CoreTests/{DrawingBudgetTests, ForceMeasurementTests, LicenseAuditTests, MaterialCatalogTests, PhysicsFixtureTests,
PinFixtureTests, PresetTests, ReplayTests, SleepTests, SpringWorldTests, StackFixtureTests, TutorialTests,
WorldEditingTests, WorldSimulationTests}.swift` and `ExperienceTests/{ExperimentSampleFileTests, ExperimentStoreTests,
PlaygroundCoreTests, PlaygroundGestureTests, PlaygroundQualityTests, PlaygroundRenderTests,
PlaygroundSessionTests}.swift`; `Packages/VisualCore/Tests/VisualCoreSimulationTests/{BroadPhase2DTests, Contacts2DTests,
ImpulseSolver2DTests, Springs2DTests}.swift`.

Evidence files (legacy ledger, stage A11-P06): `pp-no-network`, `release-docs`, `playground-ios27`, `app-ui`,
`verify-27`, `release-checks`, `script-tests` under `.autonomy/checks/A11-P06.<name>.json`; baseline cited from
`.autonomy/checks/A11-P05.{playground-ios27,app-unit,verify-27}.json` (T-A11-601); earlier phases cited from
`.autonomy/checks/A11-P01.visualcore-host.json`, `.autonomy/checks/A11-P02.visualcore-host-1.json`,
`.autonomy/checks/A11-P04.playground-ios27.json` and `.autonomy/checks/A11-P05.{catalog,claims-2}.json`.
