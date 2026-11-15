# Tiny Worlds — release checklist and artifact inventory

Tiny Worlds (`a12.tiny-worlds`) ships inside the one VisualCore app (ADR-0009); feature 094 (A12-P06), FR-A12-620,
FR-A12-622, FR-A12-623, FR-A12-640 and FR-A12-641. App-wide commands are in
[build-and-archive.md](../../release/build-and-archive.md). The statuses are the words that
`scripts/check_experience_release.py` accepts for every experience (Clarifications Q1):

- `verified`: the evidence named in the row is a check of the legacy ledger (`.autonomy/checks/A12-P06.<name>.json`,
  recorded with `desktop_runbook.py run-check` before A12-P06 is sealed) or a sealed earlier phase
  (`.autonomy/checks/A12-P0N.*.json`). A row whose check file does not exist yet is pending: the task named in the row
  records it, and A12-P06 is not sealed before every such file exists and passed;
- `pending-campaign-ii` (spec: device): needs the device campaign D1 → D2 → D3 after `ImplementationLock-100`; the row
  names its row of [device-campaign.md](device-campaign.md) or the one app's campaign (Auto-Creator.md section 23.3);
  task T-A12-616;
- `owner-action` (spec: blocked-owner): done by the owner only, steps in
  [build-and-archive.md](../../release/build-and-archive.md) section 5 (`BLOCKED_OWNER_ACTION` until done); task
  T-A12-615.

`scripts/check_experience_release.py --config docs/apps/tiny-worlds/release.json` rejects a row without a known status
or without evidence.

| Item | Area | Status | Evidence |
|---|---|---|---|
| Privacy and credits note: what is stored and where (`world-<slot>.json` saved worlds and `world-<slot>.png` thumbnails of 160 × 120, the app's `state.json`), nothing sent, no personal data, how to delete (a slot's Clear, the Settings reset of the experience's data, removing the app), every preset, palette, prop, prop palette and pack credited with author and license | Privacy | verified | [privacy-and-credits.md](privacy-and-credits.md) (T-A12-602); [content-licenses.md](content-licenses.md); `.autonomy/checks/A12-P06.release-docs.json` (`experience-release-a12`, T-A12-608) |
| No network, tracking, sensor, recording, microphone input, system-brightness or idle-timer use in the experience's sources | Privacy | verified | `.autonomy/checks/A12-P06.tw-no-network.json` (T-A12-603) |
| No permission requested and no usage string added (the registration declares `"permissions": []`); no sound and no haptics; the app's usage strings unchanged | Privacy | verified | `.autonomy/checks/A12-P06.release-checks.json` (`app-usage-descriptions`, T-A12-613); `Catalog/registrations.json`; `project.yml`; [privacy-and-credits.md](privacy-and-credits.md) |
| App privacy manifest matches the Release build and covers the experience's required-reason uses | Privacy | verified | `.autonomy/checks/A12-P06.release-checks.json` (`app-privacy-manifest`, T-A12-613); [privacy-and-credits.md](privacy-and-credits.md) |
| No tracking or advertising in the built app | Privacy | verified | `.autonomy/checks/A12-P06.release-checks.json` (`app-no-tracking`, T-A12-613) |
| Licenses and acknowledgements: the three presets, three palettes, four props, four prop palettes and three packs are MIT content of the VisualCore project; no third-party code or asset in the experience; app Licenses folder equals the inventory | Credits | verified | `.autonomy/checks/A12-P06.release-checks.json` (`app-licenses`, T-A12-613); `LicenseAuditTests.theCommittedLicenseDocumentMatchesTheCatalog` in `.autonomy/checks/A12-P05.worlds-ios27-3.json` (baseline, T-A12-601) and `.autonomy/checks/A12-P06.worlds-ios27-2.json` (T-A12-610) |
| Store text input describing only implemented and tested features, with a claim → proving-test table; no number with a unit, no device value and none of the refused words of Clarifications Q2; unsupported promised features absent from the interface and the store text | Store | verified | [store-listing.md](store-listing.md) (T-A12-607); `.autonomy/checks/A12-P06.release-docs.json` (`scan-claims-release.sh`, T-A12-608) |
| Copy check: no measured claim, unmeasured quality word or missing feature in the store text and interface strings (nothing allowed) | Store | verified | `.autonomy/checks/A12-P06.release-docs.json` (`copy-claims-a12`, T-A12-608; `Configs/copy-claims-denylist.json`) |
| Catalog entry and README name only proven capabilities and make none of the refused claims | Store | verified | `.autonomy/checks/A12-P05.claims.json` (`specs/093-tw-p05-qa/scan-claims.sh`); `.autonomy/checks/A12-P05.catalog.json` |
| Experience release check: required documents present, every checklist row has status and evidence | Store | verified | `.autonomy/checks/A12-P06.release-docs.json` (`experience-release-a12`, T-A12-608) |
| Sample world files: exactly four committed; the valid one (file schema 2) opens; the newer, damaged and truncated ones are refused (`newer-version`, `damaged`, `damaged`) and stay byte-identical; a lone picture leaves the slot empty and a world file without its picture reads "no picture" | Data | verified | `.autonomy/checks/A12-P06.worlds-ios27-2.json` (`WorldSampleFileTests.testTheCommittedSamplesOpenOrAreRefused`; T-A12-606, T-A12-610) |
| Saved worlds: save and read round trip bit-identical, a thumbnail drawn and stored with the world, thumbnails above the cap not stored, an empty or invalid slot refused and Clear removing both files, refused files reported and left untouched, an interrupted write keeping the previous file, round trips across tiers and packs | Data | verified | `.autonomy/checks/A12-P05.worlds-ios27-3.json` (`WorldStoreTests`; baseline, T-A12-601); `.autonomy/checks/A12-P06.worlds-ios27-2.json` (T-A12-610) |
| Session state: the stored example of snapshot schema 1 migrates to schema 2; newer and damaged snapshots refused and the default world opens | Data | verified | `.autonomy/checks/A12-P06.worlds-ios27-2.json` (`WorldsEditingTests.testTheSchemaOneExampleMigrates`; `WorldsRecoveryDrawTests`; `WorldsSessionTests.testANewerSavedStateIsRefusedAndTheDefaultWorldOpens`, `testADamagedSavedStateIsRefusedAndTheDefaultWorldOpens`; T-A12-605, T-A12-610) |
| Drawing-failure recovery: failure state, `world-0.json` and `world-0.png` byte-identical, a new session draws | Recovery | verified | `.autonomy/checks/A12-P06.worlds-ios27-2.json` (`WorldsRecoveryDrawTests.testAFailedDrawLeavesSavedWorldsUntouched`, test-only `failNextDraw` seam; T-A12-604, T-A12-605, T-A12-610) |
| Accessibility (automated): labels and values — every control is built with a label, a value (or hint) and an identifier `experience.a12.tiny-worlds.<name>` (`WorldsControls.swift`); the status line names the world, the seed and the view in words; edits, light changes and packs are answered in words; the controls are found by identifier in the interface chunk | Accessibility | verified | `.autonomy/checks/A12-P06.worlds-ios27-2.json` (`WorldsRenderTests.testTheDescriptionNamesTheWorldSeedAndView`, `WorldsEditingTests.testEditingActionsAreAnsweredInWords`, `WorldsPackTests.testEveryActionHasAControlAndPacksAreAnsweredInWords`; T-A12-610); `.autonomy/checks/A12-P06.app-ui-2.json` (`TWWorldUITests`, `TWEditUITests`, chunk t2, T-A12-611) |
| Accessibility (automated): a native control for every gesture — drag to orbit, pinch to zoom and tap to select each have a control (Turn left and right, Tilt up and down, Zoom in and out, Reset view, Select previous and next); every editing, light and pack action has a control; no gesture action lacks a native action | Accessibility | verified | `.autonomy/checks/A12-P06.worlds-ios27-2.json` (`WorldsGestureTests.testEveryGestureHasANativeControl`: `GestureAlternatives.missing` is empty; `WorldsEditingTests.testEveryActionHasANativeControl`; `WorldsPackTests.testEveryActionHasAControlAndPacksAreAnsweredInWords`; T-A12-610); `.autonomy/checks/A12-P06.app-ui-2.json` (`TWWorldUITests`, `TWEditUITests` use the native controls only, T-A12-611) |
| Accessibility (automated): spoken view and pick descriptions — the world, seed and view described, view changes announced at most once per second, a tap on the land speaks the ground point and a tap on the sky speaks a miss, neither changing the world | Accessibility | verified | `.autonomy/checks/A12-P06.worlds-ios27-2.json` (`WorldsRenderTests.testTheDescriptionNamesTheWorldSeedAndView`, `testViewAnnouncementsAreSpokenAtMostOncePerSecond`; `WorldsGestureTests.testATapOnTheTerrainSpeaksAGroundPointAndChangesNothing`, `testATapOnTheSkySpeaksAMissAndChangesNothing`; `WorldsSessionTests.testTheFirstFrameDrawsTheIslandAndDescribesIt`; T-A12-610); the announcements themselves are heard on hardware in the device row TW-D5 |
| Accessibility (automated): Reduce Motion — the view eases to a new position, and under Reduce Motion it moves there directly, even in the middle of an ease; a pack's view is drawn directly; drawing never changes the world | Accessibility | verified | `.autonomy/checks/A12-P06.worlds-ios27-2.json` (`WorldsRenderTests.testReduceMotionMovesTheViewDirectlyEvenMidEase`, `testTheViewEasesToTheTargetIn035Seconds`, `testDrawingNeverChangesTheState`; `WorldsPackTests.testUnderReduceMotionThePackViewIsDrawnDirectly`; T-A12-610) |
| ExperiencesCreative package suites of Tiny Worlds on the iOS 27 simulator (sim-27.2; iOS 26 at X-A12 by owner ruling of 2026-11-14) | Tests | verified | `.autonomy/checks/A12-P05.worlds-ios27-3.json` (baseline, T-A12-601); `.autonomy/checks/A12-P06.worlds-ios27-2.json` (`TinyWorldsCoreTests`, `TinyWorldsExperienceTests`, T-A12-610) |
| VisualCore pieces built for Tiny Worlds: seeded gradient noise and height-field terrain (A12-P01), ray intersection for ground picking (A12-P02) | Tests | verified | `.autonomy/checks/A12-P01.visualcore-host.json` (`GradientNoise2DTests`, `HeightFieldTests`); `.autonomy/checks/A12-P02.visualcore-host.json` (`RayIntersectionTests`) |
| App build, unit tests and interface chunk t2 (serial): open the asteroid garden pack, turn and zoom by buttons, reset the view; place a prop, move the light azimuth, save to slot 0 and see its picture | Tests | verified | `.autonomy/checks/A12-P05.app-unit.json` (baseline, T-A12-601); `.autonomy/checks/A12-P06.app-ui-2.json` (`app-build-for-testing-ios27`, `app-unit-ios27`, `app-ui-ios27-t2`: `TWWorldUITests`, `TWEditUITests`, iOS 27.2 phone simulator, each test under 60 s, T-A12-609, T-A12-611) |
| Experience runner on iOS 27 (nine standard scenarios) | Tests | verified | `.autonomy/checks/A12-P05.verify-27.json` (baseline, T-A12-601); `.autonomy/checks/A12-P06.verify-27.json` (T-A12-612) |
| Release build checks: unsigned Release build, no debug or scenario symbols, manifest, tracking, licenses, usage strings | Build | verified | `.autonomy/checks/A12-P06.release-checks.json` (T-A12-613) |
| Release document and copy check scripts tested (pass and fail cases) | Build | verified | `.autonomy/checks/A12-P06.script-tests.json` (T-A12-614) |
| Build-and-archive instructions for the one app, owner steps marked | Build | verified | [build-and-archive.md](../../release/build-and-archive.md); its agent-run release steps in `.autonomy/checks/A12-P06.release-checks.json` (T-A12-613) |
| Frame pacing per detail tier (each pack with 24 props, levels 0, 1 and 2) | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row TW-D1 "Frame pacing per detail tier" (T-A12-616); no number is claimed before device evidence |
| Thermal state over 10 minutes | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row TW-D2 "Thermal state over 10 minutes" (T-A12-616) |
| Memory high-water mark across pack switches | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row TW-D3 "Memory high-water mark across pack switches" (T-A12-616) |
| Touch latency of orbit and place | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row TW-D4 "Touch latency of orbit and place" (T-A12-616) |
| System accessibility audits at default and largest text size; Dynamic Type layouts at the largest text size; VoiceOver on hardware over every control, the spoken view and the pick descriptions | Accessibility | pending-campaign-ii | [device-campaign.md](device-campaign.md) row TW-D5 "Accessibility system audits and Dynamic Type" and the one app's campaign, Auto-Creator.md section 23.3, run with `VC_RUN_AUDITS=1` (T-A12-616); deferred by owner ruling of 2026-11-13 |
| Signing team, archive, validation and upload | Distribution | owner-action | `BLOCKED_OWNER_ACTION`: [build-and-archive.md](../../release/build-and-archive.md) section 5 steps 1 to 4 (T-A12-615) |
| App Store Connect: record, App Privacy answers (no data collected, no tracking), store text from [store-listing.md](store-listing.md), screenshots, review submission | Distribution | owner-action | `BLOCKED_OWNER_ACTION`: [build-and-archive.md](../../release/build-and-archive.md) section 5 steps 5, 6, 8 and 9 (T-A12-615) |

## Artifact inventory

Documents of this phase (all under `docs/apps/tiny-worlds/` unless a path is given):

- `privacy-and-credits.md` — stored data, how to delete, permissions, what is not done, required-reason APIs, credits
  (T-A12-602).
- `store-listing.md` — store text input with the claim → proving-test table (T-A12-607).
- `release-checklist.md` — this checklist (T-A12-607).
- `release.json` — release configuration read by `check_experience_release.py` and `release_check.py` (T-A12-607;
  `specs/094-tw-p06-release/contracts/release-config.md`).
- `device-campaign.md` — device measurements TW-D1 … TW-D5 with procedure, threshold and pending status (feature 093,
  A12-P05).
- `content-licenses.md` — author and license of every preset, palette, prop, prop palette and pack, generated by
  `LicenseAudit`.
- `README.md` — links to every document (updated by T-A12-607).
- `docs/release/known-limitations.md`, section "Tiny Worlds" — device-only items and the stylised dioramas (T-A12-607).
- `docs/release/build-and-archive.md` — app-wide build and owner steps (existing).
- `visualcore-contract.json`, `visualcore-contract.md`, `regression-baseline.md` — Phase 00 documents (existing).

Configuration:

- `Configs/copy-claims-denylist.json` — shared copy-claim denylist (unchanged; Clarifications Q2).
- `specs/094-tw-p06-release/scan-claims-release.sh` — refused-word scan of the store text and the interface Swift and
  test-name check of the claim table (T-A12-608).
- `scripts/release_check.py` — serial interface chunk `t2` with `TWWorldUITests` and `TWEditUITests` (T-A12-609).

Code and test artifacts of this phase:

- `Packages/ExperiencesCreative/TinyWorlds/Experience/WorldsPresenter.swift` — the test-only `failNextDraw` seam
  (T-A12-604).
- `Packages/ExperiencesCreative/TinyWorlds/ExperienceTests/WorldsRecoveryDrawTests.swift` (T-A12-605).
- `Packages/ExperiencesCreative/TinyWorlds/ExperienceTests/Fixtures/` with `world-valid.json`, `world-newer.json`,
  `world-damaged.json` and `world-truncated.json`, the test target's resources in
  `Packages/ExperiencesCreative/Package.swift`, and `ExperienceTests/WorldSampleFileTests.swift` (T-A12-606).
- `Apps/VisualCore/Tests/UI/TinyWorlds/TWSupport.swift`, `TWWorldUITests.swift`, `TWEditUITests.swift` (T-A12-609).

Test files cited by this checklist and the store text (existing): `Packages/ExperiencesCreative/TinyWorlds/`
`CoreTests/{CameraPolicyTests, DetailTierTests, LicenseAuditTests, PropCatalogTests, TerrainColoringTests,
TerrainFixtureTests, TerrainGeneratorTests, TierPolicyTests, WorldEditingTests, WorldLightTests, WorldPackTests,
WorldStateTests, WorldViewTests}.swift` and `ExperienceTests/{WorldStoreTests, WorldsCoreTests, WorldsEditingTests,
WorldsGestureTests, WorldsPackTests, WorldsQualityTests, WorldsRenderTests, WorldsSessionTests}.swift`;
`Packages/VisualCore/Tests/VisualCoreScenesTests/{GradientNoise2DTests, HeightFieldTests}.swift` and
`Packages/VisualCore/Tests/VisualCoreMathTests/RayIntersectionTests.swift`.

Evidence files (legacy ledger, stage A12-P06): `tw-no-network`, `release-docs`, `worlds-ios27`, `app-ui`,
`verify-27`, `release-checks`, `script-tests` under `.autonomy/checks/A12-P06.<name>.json`; baseline cited from
`.autonomy/checks/A12-P05.{worlds-ios27-3,app-unit,verify-27}.json` (T-A12-601); earlier phases cited from
`.autonomy/checks/A12-P01.visualcore-host.json`, `.autonomy/checks/A12-P02.visualcore-host.json` and
`.autonomy/checks/A12-P05.{catalog,claims}.json`.
