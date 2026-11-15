# Digital Aquarium — release checklist and artifact inventory

Digital Aquarium (`a09.digital-aquarium`) ships inside the one VisualCore app (ADR-0009); feature 073 (A09-P06),
FR-A09-620, FR-A09-622 and FR-A09-623. App-wide commands are in [build-and-archive.md](../../release/build-and-archive.md).
The spec's statuses are written with the status words that `scripts/check_app_release.py` accepts for every experience
(Clarifications Q1):

- `verified`: the evidence named in the row is a check of the legacy ledger (`.autonomy/checks/A09-P06.<name>.json`,
  recorded with `desktop_runbook.py run-check` before A09-P06 is sealed) or a sealed earlier phase
  (`.autonomy/checks/A09-P0N.*.json`). A row whose check file does not exist yet is pending: the task named in the row
  records it, and A09-P06 is not sealed before every such file exists and passed;
- `pending-campaign-ii` (spec: device): needs the device campaign D1 → D2 → D3 after `ImplementationLock-100`; the row
  names its row of [device-campaign.md](device-campaign.md); task T-A09-615;
- `owner-action` (spec: blocked-owner): done by the owner only, steps in
  [build-and-archive.md](../../release/build-and-archive.md) section 5 (`BLOCKED_OWNER_ACTION` until done); task
  T-A09-614.

`scripts/check_experience_release.py --config docs/apps/digital-aquarium/release.json` rejects a row without a known
status or without evidence.

| Item | Area | Status | Evidence |
|---|---|---|---|
| Privacy and credits note: what is stored and where (`aquarium-<uuid>.json`, the app's `state.json`), nothing sent, how to delete, every bundled item credited with author and license | Privacy | verified | [privacy-and-credits.md](privacy-and-credits.md) (T-A09-602); [content-licenses.md](content-licenses.md); `.autonomy/checks/A09-P06.release-docs.json` (`experience-release-a09`, T-A09-607) |
| No network, tracking, sensor, system-brightness or idle-timer use in the experience's sources | Privacy | verified | `.autonomy/checks/A09-P06.da-no-network.json` (T-A09-603); `AquariumRenderTests.testNoSourceSetsTheSystemBrightnessOrTheIdleTimer` |
| No permission requested and no usage string added; the app's usage strings unchanged | Privacy | verified | `.autonomy/checks/A09-P06.release-checks.json` (`app-usage-descriptions`, T-A09-612); `project.yml`; [privacy-and-credits.md](privacy-and-credits.md) |
| App privacy manifest matches the Release build and covers the experience's required-reason uses | Privacy | verified | `.autonomy/checks/A09-P06.release-checks.json` (`app-privacy-manifest`, T-A09-612); [privacy-and-credits.md](privacy-and-credits.md) |
| No tracking or advertising in the built app | Privacy | verified | `.autonomy/checks/A09-P06.release-checks.json` (`app-no-tracking`, T-A09-612) |
| Licenses and acknowledgements: every species, plant, decoration and habitat is MIT content of the VisualCore project; no third-party code or asset in the experience; app Licenses folder equals the inventory | Credits | verified | `.autonomy/checks/A09-P06.release-checks.json` (`app-licenses`, T-A09-612); `LicenseAuditTests.theCommittedLicenseDocumentMatchesTheCatalog` in `.autonomy/checks/A09-P06.aquarium-ios27.json` (T-A09-609) |
| Store text input describing only implemented and tested features, with a claim → proving-test table; no number with a unit; no realism or care word | Store | verified | [store-listing.md](store-listing.md) (T-A09-606); `.autonomy/checks/A09-P06.release-docs.json` (`scan-realism.sh`, T-A09-607) |
| Copy check: no measured claim, unmeasured quality word or missing feature in the store text and interface strings (nothing allowed) | Store | verified | `.autonomy/checks/A09-P06.release-docs.json` (`copy-claims-a09`, T-A09-607; `Configs/copy-claims-denylist.json`) |
| Experience release check: required documents present, every checklist row has status and evidence | Store | verified | `.autonomy/checks/A09-P06.release-docs.json` (`experience-release-a09`, T-A09-607) |
| Sample saved files: a valid configuration (format 1) is listed; a newer (format 2), a damaged and a mismatched-id file are counted; all byte-identical after a reload and a save | Data | verified | `.autonomy/checks/A09-P06.aquarium-ios27.json` (`AquariumSampleFileTests`, T-A09-604, T-A09-605, T-A09-609) |
| Saved-aquarium library: save, list, open in a new session, delete; at most 12; damaged, foreign, invalid and newer files counted and kept; a save the storage refuses changes no file | Data | verified | `.autonomy/checks/A09-P05.aquarium-ios27.json` (`AquariumLibraryTests`; baseline, T-A09-601); `.autonomy/checks/A09-P06.aquarium-ios27.json` (T-A09-609) |
| Session state: snapshots of schemas 1 to 3 migrate and restore; newer and damaged snapshots refused, the starter habitat opens | Data | verified | `.autonomy/checks/A09-P06.aquarium-ios27.json` (`AquariumSampleFileTests` stored schema 1 to 3 examples; `AquariumCoreTests.testASchemaOneSnapshotMigratesWithTheStarterDecor`, `testSchemaTwoSnapshotsMigrateAndADamagedKindIsRefused`, `testASchemaThreeSnapshotMigratesWithAmbientOff`; `AquariumSessionTests.testANewerSavedStateIsRefusedAndTheStarterHabitatOpens`; T-A09-609) |
| Drawing-failure recovery: failure state, saved aquarium files byte-identical, a new session draws | Recovery | verified | `.autonomy/checks/A09-P06.aquarium-ios27.json` (`AquariumRecoveryDrawTests`, test-only `failNextDraw` seam; T-A09-605, T-A09-609); `AquariumRenderTests.testAFailedDrawReachesTheSession` |
| Accessibility (automated): the canvas description names habitat, species counts, food, decorations, ambient and pause; announcements rate-limited and only with VoiceOver | Accessibility | verified | `.autonomy/checks/A09-P06.aquarium-ios27.json` (`AquariumWordingTests.theReefStarterIsDescribedWithSpeciesCounts`, `emptyDecorFoodPausedAndLightingAreDescribed`; `AquariumRenderTests.testTheDescriptionNamesPelletAndDecorCounts`; `AquariumAnnouncerTests.theFirstAnnouncementSpeaksAndTheNextWithinTheIntervalWaits`, `withVoiceOverOffNothingIsSpokenOrHeld`; `AquariumAnnouncementTests.testFeedingAnnouncesFoodDroppedOnceWithVoiceOver`, `testNothingIsAnnouncedWithVoiceOverOff`; T-A09-609) |
| Accessibility (automated): Reduce Motion halves the swim displacement, the sway and the bubble rise and holds the caustics, without changing the state | Accessibility | verified | `.autonomy/checks/A09-P06.aquarium-ios27.json` (`AquariumRenderTests.testReduceMotionHalvesEveryPointsDisplacement`, `testTheCausticsChangeOverTimeAndHoldUnderReduceMotion`; `AquariumSessionTests.testReduceMotionHalvesTheSwayButNeverChangesTheState`; `WaterEffectsTests.reduceMotionHalvesTheRiseAndRemovesTheWobble`; T-A09-609) |
| Accessibility (automated): every gesture action (feed, place, move) has a labelled native control | Accessibility | verified | `.autonomy/checks/A09-P06.aquarium-ios27.json` (`AquariumRenderTests.testEveryGestureActionHasANativeControl`, T-A09-609); `.autonomy/checks/A09-P06.app-ui.json` (`DAAquariumUITests`, `DALibraryUITests`: controls found by identifier and label, chunk q2, T-A09-610) |
| ExperiencesCreative package suites of Digital Aquarium on the iOS 27 simulator (sim-27.2; iOS 26 at X-A09 by owner ruling of 2026-11-14) | Tests | verified | `.autonomy/checks/A09-P05.aquarium-ios27.json` (baseline, T-A09-601); `.autonomy/checks/A09-P06.aquarium-ios27.json` (`DigitalAquariumCoreTests`, `DigitalAquariumExperienceTests`, T-A09-609) |
| App build, unit tests and interface chunk q2: feed by the Feed button, add, move right and remove a decoration, switch to Kelp, ambient on; save under a name, change the habitat, open the saved one | Tests | verified | `.autonomy/checks/A09-P05.app-unit.json` (baseline, T-A09-601); `.autonomy/checks/A09-P06.app-ui.json` (`app-build-for-testing-ios27`, `app-unit-ios27`, `app-ui-ios27-q2`: `DAAquariumUITests`, `DALibraryUITests`, iOS 27.2 phone simulator, T-A09-610) |
| Experience runner on iOS 27 | Tests | verified | `.autonomy/checks/A09-P05.verify-27.json` (baseline, T-A09-601); `.autonomy/checks/A09-P06.verify-27.json` (T-A09-611) |
| Release build checks: unsigned Release build, no debug or scenario symbols, manifest, tracking, licenses, usage strings | Build | verified | `.autonomy/checks/A09-P06.release-checks.json` (T-A09-612) |
| Release document and copy check scripts tested (pass and fail cases) | Build | verified | `.autonomy/checks/A09-P06.script-tests.json` (T-A09-613) |
| Build-and-archive instructions for the one app, owner steps marked | Build | verified | [build-and-archive.md](../../release/build-and-archive.md); its agent-run release steps in `.autonomy/checks/A09-P06.release-checks.json` (T-A09-612) |
| CPU and GPU frame time per quality level, Reef and Kelp, with food and ambient, on D1, D2, D3 | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row "Frame time per level" (T-A09-615); no number is claimed before device evidence |
| Settled quality level and each step's cause | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row "Settled quality level" (T-A09-615) |
| Thermal state over ten minutes of ambient mode | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row "Thermal state over ten minutes" (T-A09-615) |
| Ambient dimming timing on hardware; Low Power Mode; the system screen brightness unchanged | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row "Ambient dimming" (T-A09-615) |
| Memory across levels, feeds, saved aquariums and reopening the experience | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row "Memory" (T-A09-615) |
| Persistence and lifecycle: saved aquariums survive relaunch; the container holds only `aquarium-<uuid>.json` and `state.json`; a suspension never fast-forwards fish or food | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row "Saved aquariums and lifecycle" (T-A09-615) |
| Gestures on hardware: tap to feed, long press to place, drag a piece, two-finger touches, with VoiceOver off and on | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row "Gestures" (T-A09-615) |
| VoiceOver on hardware: the canvas description in each state and the announcements | Accessibility | pending-campaign-ii | [device-campaign.md](device-campaign.md) row "VoiceOver and announcements" (T-A09-615) |
| System accessibility audits at default and largest text size | Accessibility | pending-campaign-ii | [device-campaign.md](device-campaign.md) row "Accessibility system audits", run with `VC_RUN_AUDITS=1` (T-A09-615); deferred by owner ruling of 2026-11-13 |
| Dynamic Type at the largest accessibility size, every control section in portrait and landscape | Accessibility | pending-campaign-ii | [device-campaign.md](device-campaign.md) row "Dynamic Type" (T-A09-615); controls use text styles (`AquariumControls.swift`) |
| Reduce Motion and Increase Contrast on hardware: fish, plants, decor and food distinguishable from the water | Accessibility | pending-campaign-ii | [device-campaign.md](device-campaign.md) row "Reduce Motion and contrast" (T-A09-615) |
| Signing team, archive, validation and upload | Distribution | owner-action | [build-and-archive.md](../../release/build-and-archive.md) section 5 steps 1 to 4 (T-A09-614) |
| App Store Connect: record, App Privacy answers (no data collected, no tracking), store text from [store-listing.md](store-listing.md), screenshots, review submission | Distribution | owner-action | [build-and-archive.md](../../release/build-and-archive.md) section 5 steps 5, 6, 8 and 9 (T-A09-614) |

## Artifact inventory

Documents of this phase (all under `docs/apps/digital-aquarium/` unless a path is given):

- `privacy-and-credits.md` — stored data, how to delete, permissions, what is not done, required-reason APIs, credits
  (T-A09-602).
- `store-listing.md` — store text input with the claim → proving-test table (T-A09-606).
- `release-checklist.md` — this checklist (T-A09-606).
- `release.json` — release configuration read by `check_experience_release.py` and `release_check.py` (T-A09-606).
- `device-campaign.md` — device measurements with procedure, pass criterion and pending result (feature 072
  T-A09-508).
- `content-licenses.md` — author and license of every bundled item, generated by `LicenseAudit` (feature 068).
- `README.md` — links to every document (updated by T-A09-606).
- `docs/release/known-limitations.md`, section "Digital Aquarium" — device-only items, library limit and quota, the
  arbiter's drag phase, ambient speed (T-A09-606).
- `docs/release/build-and-archive.md` — app-wide build and owner steps (existing).
- `visualcore-contract.json`, `visualcore-contract.md`, `regression-baseline.md` — Phase 00 documents (existing).

Configuration:

- `Configs/copy-claims-denylist.json` — shared copy-claim denylist (unchanged; Clarifications Q2).
- `specs/073-da-p06-release/scan-realism.sh` — realism and care word scan and test-name check of the claim table
  (T-A09-607).
- `scripts/release_check.py` — chunk `q2` in `UI_CHUNKS` and `SERIAL_CHUNKS` (T-A09-608).

Code and test artifacts of this phase:

- `Packages/ExperiencesCreative/Package.swift` — `resources: [.copy("Fixtures")]` of `DigitalAquariumExperienceTests`
  (T-A09-604).
- `Packages/ExperiencesCreative/DigitalAquarium/ExperienceTests/Fixtures/` — four sample saved files (valid format 1,
  newer format 2, damaged, mismatched id; synthetic ids) (T-A09-604).
- `Packages/ExperiencesCreative/DigitalAquarium/ExperienceTests/AquariumSampleFileTests.swift` (T-A09-605).
- `Packages/ExperiencesCreative/DigitalAquarium/ExperienceTests/AquariumRecoveryDrawTests.swift`, using the existing
  `failNextDraw` seam in `AquariumPresenter.swift` (T-A09-605).
- `Apps/VisualCore/Tests/UI/DigitalAquarium/` — `DASupport.swift`, `DAAquariumUITests.swift`, `DALibraryUITests.swift`
  (T-A09-608).

Test files cited by this checklist and the store text (existing, `Packages/ExperiencesCreative/DigitalAquarium/`):
`CoreTests/{AmbientDimmerTests, AquariumAnnouncerTests, AquariumBudgetTests, AquariumConfigurationTests,
AquariumSimulationTests, AquariumWordingTests, DecorEditingTests, FeedingTests, HabitatDocumentTests,
HabitatMigrationTests, LicenseAuditTests, SchoolingTests, SpeciesCatalogTests, UnknownContentTests,
WaterEffectsTests}.swift` and `ExperienceTests/{AquariumAnnouncementTests, AquariumCoreTests, AquariumGestureTests,
AquariumLibraryTests, AquariumManifestTests, AquariumRenderTests, AquariumSessionTests}.swift`.

Evidence files (legacy ledger, stage A09-P06): `da-no-network`, `release-docs`, `aquarium-ios27`, `app-ui`, `verify-27`,
`release-checks`, `script-tests` under `.autonomy/checks/A09-P06.<name>.json`; baseline cited from
`.autonomy/checks/A09-P05.{aquarium-ios27,app-unit,verify-27}.json` (T-A09-601).
