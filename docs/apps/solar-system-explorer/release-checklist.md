# Solar System Explorer — release checklist and artifact inventory

Solar System Explorer (`a14.solar-system-explorer`) ships inside the one VisualCore app (ADR-0009); feature 108
(A14-P06), FR-A14-620, FR-A14-622, FR-A14-623, FR-A14-630, FR-A14-631 and FR-A14-632. App-wide commands are in
[build-and-archive.md](../../release/build-and-archive.md). The statuses are the words that
`scripts/check_experience_release.py` accepts for every experience (Clarifications Q1):

- `verified`: the evidence named in the row is a check of the legacy ledger (`.autonomy/checks/A14-P06.<name>.json`,
  recorded with `desktop_runbook.py run-check` before A14-P06 is sealed) or a sealed earlier phase
  (`.autonomy/checks/A14-P0N.*.json`). A row whose check file does not exist yet is pending: the task named in the row
  records it, and A14-P06 is not sealed before every such file exists and passed;
- `pending-campaign-ii` (spec: pending device campaign): needs the device campaign D1 → D2 → D3 after
  `ImplementationLock-100`; the row names its row of [device-campaign.md](device-campaign.md) or the one app's campaign
  (Auto-Creator.md section 23.3); no device number is claimed before then;
- `owner-action` (spec: owner action): done by the owner only, steps in
  [build-and-archive.md](../../release/build-and-archive.md) section 5 (`BLOCKED_OWNER_ACTION` until done); never done
  by the agent (CLAUDE.md rule 6); task T-A14-614.

`scripts/check_experience_release.py --config docs/apps/solar-system-explorer/release.json` rejects a row without a
known status or without evidence.

| Item | Area | Status | Evidence |
|---|---|---|---|
| Privacy and credits note: what is stored and where (`view.json` saved view with body, date, rate, view steps and scale mode, at most 4,096 bytes; the app's `state.json` session state), nothing sent, no personal data, how to delete (Save view replaces the one saved view; the Settings reset of the experience's data; the reset of all data; removing the app); every data source credited with its license | Privacy | verified | [privacy-and-credits.md](privacy-and-credits.md) (T-A14-602); [data-sources.md](data-sources.md); `.autonomy/checks/A14-P06.release-checks.json` (`experience-release-a14`, T-A14-612) |
| No network, tracking, sensor, recording, microphone input, system-brightness or idle-timer use in the experience's sources | Privacy | verified | `.autonomy/checks/A14-P06.sse-no-network.json` (T-A14-603) |
| No permission requested and no usage string added (the registration declares `"permissions": []`); no sound and no haptic; the app's usage strings unchanged | Privacy | verified | `.autonomy/checks/A14-P06.release-checks.json` (`app-usage-descriptions`, T-A14-612); `Catalog/registrations.json`; `project.yml`; [privacy-and-credits.md](privacy-and-credits.md) |
| App privacy manifest matches the Release build and covers the experience's required-reason uses | Privacy | verified | `.autonomy/checks/A14-P06.release-checks.json` (`app-privacy-manifest`, T-A14-612); [privacy-and-credits.md](privacy-and-credits.md) |
| No tracking or advertising in the built app | Privacy | verified | `.autonomy/checks/A14-P06.release-checks.json` (`app-no-tracking`, T-A14-612) |
| Data credits and licenses: 34 stored values, the orbital elements and Saturn's rings each with source, epoch and license (NASA NSSDCA Planetary, Sun and Saturnian Rings Fact Sheets; IAU 2015 Resolution B3; E. M. Standish / JPL approximate elements; NASA Mars Exploration Program and US Naval Observatory event dates; all public domain); 0 problems; the committed data-sources document matches the catalog | Credits | verified | `.autonomy/checks/A14-P05.sse-ios27.json` (`CitationAuditTests.theBundledCatalogHasNoProblems`, `theCommittedDataSourcesDocumentMatchesTheCatalog`, `theOrbitalElementsAreAudited`; `RingRecordTests.theRingSourcesAreAudited`; baseline, T-A14-601); `.autonomy/checks/A14-P06.sse-ios27-3.json` (T-A14-610); [data-sources.md](data-sources.md) |
| Licenses and acknowledgements: visuals made in code (procedural spheres, ring, orbits, stars, markers); no third-party code, image, font or sound in the experience; app Licenses folder equals the inventory | Credits | verified | `.autonomy/checks/A14-P06.release-checks.json` (`app-licenses`, T-A14-612); `SolarRenderTests.testTheRecipeColoursAreProceduralAndDeterministic`, `testTheExperienceNeverCreatesAGraphicsContextOfItsOwn` in `.autonomy/checks/A14-P05.sse-ios27.json` (baseline, T-A14-601) and `.autonomy/checks/A14-P06.sse-ios27-3.json` (T-A14-610) |
| Scientific review: the model statement (approximate Kepler model from mean elements at J2000.0, 1950 to 2050, not an ephemeris; enlarged and not to scale in the enhanced view); seven published events (four Mars oppositions, three Earth perihelia) each within its tolerance of ±3 days; every tour caption number in the data sources; the committed review matches the model | Content | verified | `.autonomy/checks/A14-P05.sse-ios27.json` (`ScientificReviewTests`, `EventChecksTests`, `TruthfulLabelTests`; baseline, T-A14-601); `.autonomy/checks/A14-P06.sse-ios27-3.json` (T-A14-610); [scientific-review.md](scientific-review.md) |
| Store text input describing only implemented and tested features, with a claim → proving-test table; no performance figure, no device value and none of the refused words of Clarifications Q2 ("not an ephemeris" is the one allowed phrase); unsupported promised features absent from the interface and the store text | Store | verified | [store-listing.md](store-listing.md) (T-A14-607); `.autonomy/checks/A14-P06.sse-claims.json` (`scan-claims-release.sh`, T-A14-608) |
| Copy check: no measured claim, unmeasured quality word or missing feature in the store text and interface strings (only `camera` allowed: the view's virtual camera) | Store | verified | `.autonomy/checks/A14-P06.release-checks.json` (`copy-claims-a14`, T-A14-612; `Configs/copy-claims-denylist.json`) |
| Experience release check: required documents present (privacy and credits, store text, checklist, device campaign, scientific review, build and archive), every checklist row has status and evidence | Store | verified | `.autonomy/checks/A14-P06.release-checks.json` (`experience-release-a14`, T-A14-612) |
| Sample saved views: exactly four committed; the valid one loads; the newer, damaged and oversized ones are refused (`newer-version`, `damaged`, `oversized`) and each stays byte-identical; with no `view.json` the answer is `missing` | Data | verified | `.autonomy/checks/A14-P06.sse-ios27-3.json` (`SavedViewSampleTests`; T-A14-605, T-A14-610) |
| View store: save and load round trip identical, a missing file is its own result, damaged, newer and oversized files refused and left untouched, the view kept in memory without storage; every field outside its range refused | Data | verified | `.autonomy/checks/A14-P05.sse-ios27.json` (`ViewStoreTests`, `SavedViewTests`; baseline, T-A14-601); `.autonomy/checks/A14-P06.sse-ios27-3.json` (T-A14-610) |
| Session state: snapshots of schemas 1 to 3 migrate to schema 4 (stored examples `SolarCore.schemaOneExample()`, `schemaTwoExample()`, `schemaThreeExample()` with their digests); newer and damaged snapshots refused and the Sun opens; the saved state restores identically in a new session | Data | verified | `.autonomy/checks/A14-P05.sse-ios27.json` (`SolarCoreTests.testASchema1EnvelopeMigrates`, `testASchema2EnvelopeMigrates`, `testASchema3EnvelopeMigrates`; `SolarSessionTests.testANewerSavedStateIsRefusedAndTheSunOpens`, `testADamagedSavedStateIsRefusedAndTheSunOpens`, `testTheSavedStateRestoresIdenticallyInANewSession`; baseline, T-A14-601); `.autonomy/checks/A14-P06.sse-ios27-3.json` (`SolarSchemaExampleTests`; T-A14-606, T-A14-610) |
| Drawing-failure recovery: a failed draw during a tour fails the session, `view.json` byte-identical, a new session over the same storage draws | Recovery | verified | `.autonomy/checks/A14-P06.sse-ios27-3.json` (`SolarRecoveryDrawTests.testAFailedDrawLeavesTheSavedViewUntouched`, test-only `failNextDraw` seam; T-A14-604, T-A14-610) |
| Accessibility (automated): labels and values on every control — every control is built with a label, a value and a hint and an identifier `experience.a14.solar-system-explorer.<name>` (`SolarControls.swift`); the status line names the selected body; refused actions are answered in words; the controls are found by identifier in the interface chunk | Accessibility | verified | `.autonomy/checks/A14-P05.sse-ios27.json` (`SolarRenderTests.testTheWordsOfTheControls`, `SolarCoreTests.testRefusalsKeepTheStateWithTheirReasons`; baseline, T-A14-601); `.autonomy/checks/A14-P06.sse-ios27-3.json` (T-A14-610); `.autonomy/checks/A14-P06.app-ui-2.json` (`SSEViewUITests`, `SSETourUITests`, chunk v2, T-A14-611) |
| Accessibility (automated): native controls for every action — body (Body menu, Previous and Next body), view (Orbit left and right, Tilt up and down, Zoom in and out, Reset view), date (six date steps, Now), time (Play/Pause, Rate), tours (Tour menu, Next stop, Pause tour, Stop tour), Scale, Save view and Restore view; the experience has no gesture-only action | Accessibility | verified | `.autonomy/checks/A14-P05.sse-ios27.json` (`SolarCoreTests.testActionsInRangeAreAccepted`, `testDateAndCameraActions`, `testTheScaleModeAction`, `testTimeTourAndViewActions`; baseline, T-A14-601); `.autonomy/checks/A14-P06.sse-ios27-3.json` (T-A14-610); `.autonomy/checks/A14-P06.app-ui-2.json` (`SSEViewUITests`, `SSETourUITests` use the native controls only, T-A14-611) |
| Accessibility (automated): canvas description with the date, the distance and the scale — "Solar System Explorer: Earth in focus on 2000-01-01, 0.983 AU (… km) from the Sun; 9 bodies. Distances and sizes not to scale." plus the date, time and clock; truthful in every sampled state; every enhanced description says not to scale and no true-relative one does | Accessibility | verified | `.autonomy/checks/A14-P05.sse-ios27.json` (`SolarCoreTests.testTheCanvasDescriptionFollowsClarificationsQ4AndQ5`, `testTheCanvasDescriptionIsTruthfulInAllSampledStates`; `TruthfulLabelTests.everyEnhancedDescriptionSaysNotToScaleAndNoTrueRelativeOneDoes`; baseline, T-A14-601); `.autonomy/checks/A14-P06.sse-ios27-3.json` (T-A14-610) |
| Accessibility (automated): the model statement — "About this model" (`about-model`) shows the model statement as its text and accessible value right after the legend | Accessibility | verified | `.autonomy/checks/A14-P05.sse-ios27.json` (`SolarQualityTests.testTheControlsShowTheModelStatement`; `ScientificReviewTests.theModelStatementIsClarificationQ3`; baseline, T-A14-601); `.autonomy/checks/A14-P06.sse-ios27-3.json` (T-A14-610) |
| Accessibility (automated): Reduce Motion cuts flights — with Reduce Motion each focus change and each tour stop cuts to the new view in one frame; without it a flight lasts 30 frames; nothing flashes; drawing never changes the state | Accessibility | verified | `.autonomy/checks/A14-P05.sse-ios27.json` (`FocusFlightTests.testReduceMotionCutsToTheNewViewAtOnce`; `SolarBodiesRenderTests.testReduceMotionCutsTheFlightAndAFlightRestartsFromTheCurrentView`; `SolarTimeTourSessionTests.testWithReduceMotionTheCameraCutsToEachTourStop`; `SolarRenderTests.testDrawingNeverChangesTheState`; baseline, T-A14-601); `.autonomy/checks/A14-P06.sse-ios27-3.json` (T-A14-610) |
| Accessibility (automated): rate-limited announcements — event announcements (play or pause, a rate change, a tour stop with its caption, the end of a tour, the range end, a scale mode change) always pass; the periodic date while playing at most once every 10 s of wall-clock time; an event restarts the interval | Accessibility | verified | `.autonomy/checks/A14-P05.sse-ios27.json` (`AnnouncementLimiterTests.testEventAnnouncementsAlwaysPass`, `testThePeriodicDatePassesAtMostOnceEveryTenSeconds`, `testAnEventRestartsTheInterval`; baseline, T-A14-601); `.autonomy/checks/A14-P06.sse-ios27-3.json` (T-A14-610); the announcements themselves are heard on hardware in the device row SSE-D5 |
| ExperiencesCreative package suites of Solar System Explorer on the iOS 27 simulator (sim-27.2; iOS 26 at X-A14 by owner ruling of 2026-11-14) | Tests | verified | `.autonomy/checks/A14-P05.sse-ios27.json` (baseline, T-A14-601); `.autonomy/checks/A14-P06.sse-ios27-3.json` (`SolarSystemExplorerCoreTests`, `SolarSystemExplorerExperienceTests`, T-A14-610) |
| App build, unit tests and interface chunk v2 (serial): choose Earth from the Body menu, the status names Earth; +365 days then Play and Pause, the date changes; Scale True relative, the legend and the canvas description say "to one scale"; start the Inner planets tour, the Sun is selected and the canvas description names stop 1 of 5; Pause tour, Next stop, Mercury; Stop tour, "No tour"; Save view, choose Mars, Restore view, Earth again | Tests | verified | `.autonomy/checks/A14-P05.app-unit-2.json` (baseline, T-A14-601); `.autonomy/checks/A14-P06.app-ui-2.json` (`app-build-for-testing-ios27`, `app-unit-ios27`, `app-ui-ios27-v2`: `SSEViewUITests`, `SSETourUITests`, iOS 27.2 phone simulator, each test under 60 s, T-A14-609, T-A14-611) |
| Experience runner on iOS 27 (standard scenarios) | Tests | verified | `.autonomy/checks/A14-P05.verify-27.json` (baseline, T-A14-601); `.autonomy/checks/A14-P06.verify-27.json` (T-A14-611) |
| Release build checks: unsigned Release build, no debug or scenario symbols, manifest, tracking, licenses, usage strings, experience release documents, copy claims | Build | verified | `.autonomy/checks/A14-P06.release-checks.json` (T-A14-612) |
| Build-and-archive instructions for the one app, owner steps marked | Build | verified | [build-and-archive.md](../../release/build-and-archive.md); its agent-run release steps in `.autonomy/checks/A14-P06.release-checks.json` (T-A14-612) |
| Frame time at level 0 (overview, Giant planets tour, playing at 1 year/s, both scale modes) | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row SSE-D1 "Frame time at level 0"; no number is claimed before device evidence |
| The drop to level 1 under Low Power Mode or a serious thermal state | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row SSE-D2 "The drop to level 1" |
| Peak memory over tours, scale and level switches, saved views and five reopenings | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row SSE-D3 "Peak memory" |
| System accessibility audits at the default and the largest text size, with a tour running and paused | Accessibility | pending-campaign-ii | [device-campaign.md](device-campaign.md) row SSE-D4 "System accessibility audits", run with `VC_RUN_AUDITS=1`; deferred to the device campaign by owner ruling of 2026-11-13 |
| VoiceOver on hardware over every control, the model statement, the canvas description, the tour captions and the stop at a range end | Accessibility | pending-campaign-ii | [device-campaign.md](device-campaign.md) row SSE-D5 "VoiceOver reading" and the one app's campaign, Auto-Creator.md section 23.3 |
| Dynamic Type at the largest accessibility size over all controls; Reduce Motion on and off on hardware while focusing and during both tours | Accessibility | pending-campaign-ii | [device-campaign.md](device-campaign.md) row SSE-D6 "Dynamic Type and Reduce Motion" |
| Signing set-up: team, certificates and provisioning profiles | Distribution | owner-action | `BLOCKED_OWNER_ACTION`: [build-and-archive.md](../../release/build-and-archive.md) section 5 step 1 (create the gitignored `Configs/Signing.local.xcconfig` with `DEVELOPMENT_TEAM`; certificates and profiles in Xcode Settings › Accounts with the owner's Apple account) and step 2 (final bundle and product identifiers) (T-A14-614) |
| Archive of the one app | Distribution | owner-action | `BLOCKED_OWNER_ACTION`: [build-and-archive.md](../../release/build-and-archive.md) section 5 step 3 (open `VisualCore.xcodeproj`, scheme `VisualCore`, destination "Any iOS Device (arm64)", Product › Archive) (T-A14-614) |
| Validation and upload of the archive | Distribution | owner-action | `BLOCKED_OWNER_ACTION`: [build-and-archive.md](../../release/build-and-archive.md) section 5 step 4 (Organizer, Validate App, then Distribute App › App Store Connect › Upload) (T-A14-614) |
| App Store Connect: record, App Privacy answers (no data collected, no tracking), store text from [store-listing.md](store-listing.md), screenshots, review submission | Distribution | owner-action | `BLOCKED_OWNER_ACTION`: [build-and-archive.md](../../release/build-and-archive.md) section 5 steps 5, 6, 8 and 9 (T-A14-614) |

## Accessibility: proved so far and pending for devices

Proved by the experience's tests on the iOS 27 simulator (rows above): labels, values, hints and identifiers on every
control; a native control for every action (there is no gesture-only action); the canvas description with the date,
the distance and the scale label; the model statement under "About this model"; Reduce Motion cutting every focus
flight and tour stop to one frame; announcements limited to one periodic date announcement every 10 s while events
always pass; refused actions answered in words. Pending for devices (owner ruling of 2026-11-13: all system
accessibility audits wait for device testing): the system accessibility audits (SSE-D4), VoiceOver on hardware
(SSE-D5), Dynamic Type at the largest sizes and Reduce Motion on hardware (SSE-D6).

## Artifact inventory

Documents of this phase (all under `docs/apps/solar-system-explorer/` unless a path is given):

- `privacy-and-credits.md` — stored data, how to delete, permissions, what is not done, required-reason APIs, credits
  (T-A14-602).
- `store-listing.md` — store text input with the claim → proving-test table (T-A14-607).
- `release-checklist.md` — this checklist (T-A14-607).
- `release.json` — release configuration read by `check_experience_release.py` and `release_check.py` (T-A14-607;
  `specs/108-sse-p06-release/contracts/release.md`).
- `docs/release/known-limitations.md`, section "Solar System Explorer" — device-only items, the approximate model, its
  epoch and range (T-A14-607).
- `device-campaign.md` — device measurements SSE-D1 … SSE-D6 with procedure, threshold and pending status (A14-P05).
- `scientific-review.md` — the model statement, the event checks and the tour captions, generated by
  `ScientificReview` (A14-P05).
- `data-sources.md` — value, units, source, epoch and license of every stored number, generated by `CitationAudit`
  (A14-P02 onwards).
- `docs/release/build-and-archive.md` — app-wide build and owner steps (existing).
- `README.md`, `visualcore-contract.json`, `visualcore-contract.md`, `regression-baseline.md` — existing documents.

Configuration:

- `Configs/copy-claims-denylist.json` — shared copy-claim denylist (unchanged; Clarifications Q2).
- `specs/108-sse-p06-release/scan-sources-release.sh` — source scan of Clarifications Q3 (T-A14-603).
- `specs/108-sse-p06-release/scan-claims-release.sh` — refused-word scan of the store text and the interface Swift and
  test-name check of the claim table (T-A14-608).
- `scripts/release_check.py` — serial interface chunk `v2` with `SSEViewUITests` and `SSETourUITests` (T-A14-609).

Code and test artifacts of this phase:

- `Packages/ExperiencesCreative/SolarSystemExplorer/Experience/SolarPresenter.swift` — the test-only `failNextDraw`
  seam (T-A14-604).
- `Packages/ExperiencesCreative/SolarSystemExplorer/ExperienceTests/SolarRecoveryDrawTests.swift` (T-A14-604).
- `Packages/ExperiencesCreative/SolarSystemExplorer/ExperienceTests/Fixtures/` with `view-valid.json`,
  `view-newer.json`, `view-damaged.json` and `view-oversized.json`, the test target's resources in
  `Packages/ExperiencesCreative/Package.swift`, and `ExperienceTests/SavedViewSampleTests.swift` (T-A14-605).
- `Experience/Adapter/SolarCore.swift` — `schemaOneExample()`, `schemaTwoExample()`, `schemaThreeExample()`, passed to
  the registry in `Apps/VisualCore/App/ExperienceRegistry.swift`, with `ExperienceTests/SolarSchemaExampleTests.swift`
  (T-A14-606).
- `Apps/VisualCore/Tests/UI/SolarSystemExplorer/SSESupport.swift`, `SSEViewUITests.swift`, `SSETourUITests.swift`
  (T-A14-609).

Test files cited by this checklist and the store text (existing): `Packages/ExperiencesCreative/SolarSystemExplorer/`
`CoreTests/{BodyCatalogTests, CitationAuditTests, EventChecksTests, OrbitElementsTests, OrbitFixtureTests,
RingRecordTests, SavedViewTests, ScaleModeTests, ScientificReviewTests, SimClockTests, SimulatedDateTests,
SolarStateSchema2Tests, SolarStateSchema4Tests, SolarStateTests, SurfaceRecipeTests, ToursTests, TruthfulLabelTests,
UnitsTests}.swift` and `ExperienceTests/{AnnouncementLimiterTests, FocusFlightTests, LabelLayoutTests,
OrbitLayoutTests, SavedViewSampleTests, SceneMeshesTests, SolarBodiesRenderTests, SolarCoreTests, SolarOrbitRenderTests,
SolarQualityTests, SolarRecoveryDrawTests, SolarRenderTests, SolarSessionTests, SolarTimeTourSessionTests,
ViewStoreTests}.swift`.

Evidence files (legacy ledger, stage A14-P06): `sse-no-network`, `sse-ios27`, `app-ui`, `verify-27`, `release-checks`,
`sse-claims`, `script-tests` under `.autonomy/checks/A14-P06.<name>.json`; baseline cited from
`.autonomy/checks/A14-P05.{sse-ios27,app-unit-2,verify-27}.json` (T-A14-601).
