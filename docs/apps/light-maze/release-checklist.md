# Light Maze — release checklist and artifact inventory

Light Maze (`a13.light-maze`) ships inside the one VisualCore app (ADR-0009); feature 101 (A13-P06), FR-A13-620,
FR-A13-622, FR-A13-623, FR-A13-630, FR-A13-631 and FR-A13-632. App-wide commands are in
[build-and-archive.md](../../release/build-and-archive.md). The statuses are the words that
`scripts/check_experience_release.py` accepts for every experience (Clarifications Q1):

- `verified`: the evidence named in the row is a check of the legacy ledger (`.autonomy/checks/A13-P06.<name>.json`,
  recorded with `desktop_runbook.py run-check` before A13-P06 is sealed) or a sealed earlier phase
  (`.autonomy/checks/A13-P0N.*.json`). A row whose check file does not exist yet is pending: the task named in the row
  records it, and A13-P06 is not sealed before every such file exists and passed;
- `pending-campaign-ii` (spec: device): needs the device campaign D1 → D2 → D3 after `ImplementationLock-100`; the row
  names its row of [device-campaign.md](device-campaign.md) or the one app's campaign (Auto-Creator.md section 23.3);
  task T-A13-615;
- `owner-action` (spec: blocked-owner): done by the owner only, steps in
  [build-and-archive.md](../../release/build-and-archive.md) section 5 (`BLOCKED_OWNER_ACTION` until done); task
  T-A13-614.

`scripts/check_experience_release.py --config docs/apps/light-maze/release.json` rejects a row without a known status
or without evidence.

| Item | Area | Status | Evidence |
|---|---|---|---|
| Privacy and credits note: what is stored and where (`progress.json` level progress, the app's `state.json` session state with level, orientations, selection and moves), nothing sent, no personal data, how to delete (the Settings reset of the experience's data, the reset of all data, removing the app), the 20 levels and the code-made success sweep credited with author and license | Privacy | verified | [privacy-and-credits.md](privacy-and-credits.md) (T-A13-602); [content-licenses.md](content-licenses.md); `.autonomy/checks/A13-P06.release-checks.json` (`experience-release-a13`, T-A13-612) |
| No network, tracking, sensor, recording, microphone input, system-brightness or idle-timer use in the experience's sources | Privacy | verified | `.autonomy/checks/A13-P06.lm-no-network.json` (T-A13-603) |
| No permission requested and no usage string added (the registration declares `"permissions": []`); the one sound uses the ambient session and never opens the input; the haptic follows the person's switch; the app's usage strings unchanged | Privacy | verified | `.autonomy/checks/A13-P06.release-checks.json` (`app-usage-descriptions`, T-A13-612); `Catalog/registrations.json`; `project.yml`; [privacy-and-credits.md](privacy-and-credits.md) |
| App privacy manifest matches the Release build and covers the experience's required-reason uses | Privacy | verified | `.autonomy/checks/A13-P06.release-checks.json` (`app-privacy-manifest`, T-A13-612); [privacy-and-credits.md](privacy-and-credits.md) |
| No tracking or advertising in the built app | Privacy | verified | `.autonomy/checks/A13-P06.release-checks.json` (`app-no-tracking`, T-A13-612) |
| Licenses and acknowledgements: the 20 levels are MIT content of the VisualCore project; the sweep is made in code; no third-party code or asset in the experience; app Licenses folder equals the inventory | Credits | verified | `.autonomy/checks/A13-P06.release-checks.json` (`app-licenses`, T-A13-612); `LicenseAuditTests.theCommittedLicenseDocumentMatchesTheCatalog` in `.autonomy/checks/A13-P05.maze-ios27.json` (baseline, T-A13-601) and `.autonomy/checks/A13-P06.maze-ios27-2.json` (T-A13-609) |
| Content QA: every level solvable, recorded solution lights every target with the fewest turns, start not solved, author and license present | Content | verified | `.autonomy/checks/A13-P05.maze-ios27.json` (`ContentQATests.everyBundledLevelPasses`, `ContentQATests.theCommittedQADocumentMatchesTheCatalog`; baseline, T-A13-601); `.autonomy/checks/A13-P06.maze-ios27-2.json` (T-A13-609); [content-qa.md](content-qa.md) |
| Store text input describing only implemented and tested features, with a claim → proving-test table; no number with a unit, no device value and none of the refused words of Clarifications Q2; unsupported promised features absent from the interface and the store text | Store | verified | [store-listing.md](store-listing.md) (T-A13-606); `.autonomy/checks/A13-P06.claims.json` (`scan-claims-release.sh`, T-A13-607) |
| Copy check: no measured claim, unmeasured quality word or missing feature in the store text and interface strings (nothing allowed) | Store | verified | `.autonomy/checks/A13-P06.release-checks.json` (`copy-claims-a13`, T-A13-612; `Configs/copy-claims-denylist.json`) |
| Experience release check: required documents present, every checklist row has status and evidence | Store | verified | `.autonomy/checks/A13-P06.release-checks.json` (`experience-release-a13`, T-A13-612) |
| Sample progress files: exactly four committed; the valid one (file schema 1) loads with level 1 solved and level 2 open; the newer, damaged and truncated ones are refused (`newer-version`, `damaged`, `damaged`), play starts from fresh progress and each stays byte-identical | Data | verified | `.autonomy/checks/A13-P06.maze-ios27-2.json` (`ProgressSampleFileTests`; T-A13-605, T-A13-609) |
| Progress store: save and load round trip identical, an absent file gives fresh progress and writes nothing, refused files reported and left untouched, an interrupted or refused write keeping the previous file, progress kept in memory without storage | Data | verified | `.autonomy/checks/A13-P05.maze-ios27.json` (`ProgressStoreTests`, `ProgressTests`; baseline, T-A13-601); `.autonomy/checks/A13-P06.maze-ios27-2.json` (T-A13-609) |
| Session state: the stored example of snapshot schema 1 restores with no moves; newer and damaged snapshots refused and level 1 opens | Data | verified | `.autonomy/checks/A13-P06.maze-ios27-2.json` (`MazeCoreTests.testTheSchemaOneExampleRestoresWithNoMoves`; `MazeSessionTests.testANewerSavedStateIsRefusedAndTheFirstLevelOpens`, `testADamagedSavedStateIsRefusedAndTheFirstLevelOpens`; T-A13-605, T-A13-609) |
| Drawing-failure recovery: failure state, `progress.json` byte-identical, a new session over the same storage loads the progress and draws | Recovery | verified | `.autonomy/checks/A13-P06.maze-ios27-2.json` (`MazeRecoveryDrawTests`, test-only `failNextDraw` seam; T-A13-604, T-A13-609) |
| Accessibility (automated): labels and values — every control is built with a label, a value and a hint and an identifier `experience.a13.light-maze.<name>` (`MazeControls.swift`); the status line names the level, the tiles, where the beam ends and whether it is solved; refused actions are answered in words; the controls are found by identifier in the interface chunk | Accessibility | verified | `.autonomy/checks/A13-P06.maze-ios27-2.json` (`MazeRenderTests.testTheWordsOfTheControls`, `MazeCoreTests.testTheCanvasDescriptionFollowsClarificationQ5`, `MazeGestureTests.testTapsElsewhereChangeNothingAndAreAnsweredInWords`; T-A13-609); `.autonomy/checks/A13-P06.app-ui.json` (`LMLevelUITests`, `LMHelpUITests`, chunk u2, T-A13-610) |
| Accessibility (automated): native alternatives to every gesture — tap to select and turn, drag to a diagonal and two-finger rotation each have a control (Select previous and next, Turn); every level action has a control (Level menu, Previous and Next level, Undo, Restart, Hint, Describe); no gesture action lacks a native action | Accessibility | verified | `.autonomy/checks/A13-P06.maze-ios27-2.json` (`MazeGestureTests.testEveryGestureActionHasANativeControl`; `MazeCoreTests.testActionsInRangeAreAccepted`; T-A13-609); `.autonomy/checks/A13-P06.app-ui.json` (`LMLevelUITests`, `LMHelpUITests` use the native controls only, T-A13-610) |
| Accessibility (automated): spoken board and hints — Describe speaks every tile, the beam's path and each target; Hint names the tile to turn by row and column; beam changes spoken at most once per second of frame time and only while VoiceOver runs; the words are shown in the message whether or not VoiceOver runs | Accessibility | verified | `.autonomy/checks/A13-P06.maze-ios27-2.json` (`BoardDescriptionTests.firstLevelReadsExactly`; `MazeHintTests.testDescribeSpeaksTheFullBoardAndTheSummaryCountsLitTargets`, `testTheHintControlAnswersInWordsAndKeepsThemWithVoiceOverOff`; `MazeGlowTests.testBeamChangesAreSpokenAtMostOncePerSecondOfFrameTime`, `testNothingReachesTheSinkWhileVoiceOverIsOff`; `MazeSessionTests.testTheFirstFrameDrawsLevelOneAndDescribesIt`; T-A13-609); `.autonomy/checks/A13-P06.app-ui.json` (`LMHelpUITests`, T-A13-610); the announcements themselves are heard on hardware in the device row LM-D6 |
| Accessibility (automated): colour plus sign with contrast — the nine tile states have distinct signs (lit targets carry a ring, the selected tile an outline, the solved board a tick) and every state colour has at least 3:1 contrast against the board | Accessibility | verified | `.autonomy/checks/A13-P06.maze-ios27-2.json` (`MazeStyleTests.testTheNineStatesHaveDistinctSigns`, `testEveryStateColourHasThreeToOneContrastAgainstTheBoard`; `MazeGlowTests.testLitTargetsCarryARingAndUnlitOnesNone`, `testTheSelectedTileCarriesAnOutline`; `MazeFeedbackTests.testTheSolvedBoardHasABorderAndTick`; T-A13-609) |
| Accessibility (automated): Reduce Motion and Reduce Flashing — the solved border brightens once, and under either setting it stays still; nothing else moves or flashes; drawing never changes the game state | Accessibility | verified | `.autonomy/checks/A13-P06.maze-ios27-2.json` (`SuccessCueTests.reduceMotionAndReduceFlashingKeepTheBorderStatic`, `brightnessRisesAndFallsOnce`; `MazeFeedbackTests.testTheBorderBrightensOnceAndReduceFlagsKeepItStatic`; `MazeRenderTests.testDrawingNeverChangesTheState`; T-A13-609) |
| ExperiencesCreative package suites of Light Maze on the iOS 27 simulator (sim-27.2; iOS 26 at X-A13 by owner ruling of 2026-11-14) | Tests | verified | `.autonomy/checks/A13-P05.maze-ios27.json` (baseline, T-A13-601); `.autonomy/checks/A13-P06.maze-ios27-2.json` (`LightMazeCoreTests`, `LightMazeExperienceTests`, T-A13-609) |
| App build, unit tests and interface chunk u2 (serial): on level 1 select next and turn, solved; undo, not solved; turn again; choose the opened level 2 from the Level menu; Hint selects a tile and the message names it; Describe shows the board text | Tests | verified | `.autonomy/checks/A13-P05.app-unit.json` (baseline, T-A13-601); `.autonomy/checks/A13-P06.app-ui.json` (`app-build-for-testing-ios27`, `app-unit-ios27`, `app-ui-ios27-u2`: `LMLevelUITests`, `LMHelpUITests`, iOS 27.2 phone simulator, each test under 60 s, T-A13-608, T-A13-610) |
| Experience runner on iOS 27 (standard scenarios) | Tests | verified | `.autonomy/checks/A13-P05.verify-27.json` (baseline, T-A13-601); `.autonomy/checks/A13-P06.verify-27.json` (T-A13-611) |
| Release build checks: unsigned Release build, no debug or scenario symbols, manifest, tracking, licenses, usage strings, experience release documents, copy claims | Build | verified | `.autonomy/checks/A13-P06.release-checks.json` (T-A13-612) |
| Build-and-archive instructions for the one app, owner steps marked | Build | verified | [build-and-archive.md](../../release/build-and-archive.md); its agent-run release steps in `.autonomy/checks/A13-P06.release-checks.json` (T-A13-612) |
| Frame pacing on the largest boards (levels 15 and 20) | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row LM-D1 "Frame pacing on the largest boards" (T-A13-615); no number is claimed before device evidence |
| Thermal state over 10 minutes | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row LM-D2 "Thermal state over 10 minutes" (T-A13-615) |
| Memory high-water mark across level switches | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row LM-D3 "Memory high-water mark across level switches" (T-A13-615) |
| Touch latency of tap-to-turn, drag and two-finger rotation | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row LM-D4 "Touch latency of tap-to-turn, drag and two-finger rotation" (T-A13-615) |
| Haptic and sound feel of the success cue (silent switch, haptics switch, mixing with other sound) | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) row LM-D5 "Haptic and sound feel of the success cue" (T-A13-615) |
| System accessibility audits at default and largest text size; Dynamic Type layouts at the largest text size; VoiceOver on hardware over every control, Describe, Hint and the spoken beam changes | Accessibility | pending-campaign-ii | [device-campaign.md](device-campaign.md) row LM-D6 "VoiceOver and the system accessibility audits" and the one app's campaign, Auto-Creator.md section 23.3, run with `VC_RUN_AUDITS=1` (T-A13-615); deferred by owner ruling of 2026-11-13 |
| Signing team, archive, validation and upload | Distribution | owner-action | `BLOCKED_OWNER_ACTION`: [build-and-archive.md](../../release/build-and-archive.md) section 5 steps 1 to 4 (T-A13-614) |
| App Store Connect: record, App Privacy answers (no data collected, no tracking), store text from [store-listing.md](store-listing.md), screenshots, review submission | Distribution | owner-action | `BLOCKED_OWNER_ACTION`: [build-and-archive.md](../../release/build-and-archive.md) section 5 steps 5, 6, 8 and 9 (T-A13-614) |

## Artifact inventory

Documents of this phase (all under `docs/apps/light-maze/` unless a path is given):

- `privacy-and-credits.md` — stored data, how to delete, permissions, what is not done, required-reason APIs, credits
  (T-A13-602).
- `store-listing.md` — store text input with the claim → proving-test table (T-A13-606).
- `release-checklist.md` — this checklist (T-A13-606).
- `release.json` — release configuration read by `check_experience_release.py` and `release_check.py` (T-A13-606;
  `specs/101-lm-p06-release/contracts/release-config.md`).
- `device-campaign.md` — device measurements LM-D1 … LM-D6 with procedure, threshold and pending status (T-A13-606).
- `content-licenses.md` — author and license of every level, generated by `LicenseAudit` (A13-P05).
- `content-qa.md` — solvability, fewest turns and recorded solution per level, generated by `ContentQA` (A13-P05).
- `README.md` — links to every document (updated by T-A13-602).
- `docs/release/known-limitations.md`, section "Light Maze" — device-only items, the grid-rule beams and no level
  editor (T-A13-606).
- `docs/release/build-and-archive.md` — app-wide build and owner steps (existing).
- `visualcore-contract.json`, `visualcore-contract.md`, `regression-baseline.md` — Phase 00 documents (existing).

Configuration:

- `Configs/copy-claims-denylist.json` — shared copy-claim denylist (unchanged; Clarifications Q2).
- `specs/101-lm-p06-release/scan-claims-release.sh` — refused-word scan of the store text and the interface Swift and
  test-name check of the claim table (T-A13-607).
- `scripts/release_check.py` — serial interface chunk `u2` with `LMLevelUITests` and `LMHelpUITests` (T-A13-608).

Code and test artifacts of this phase:

- `Packages/ExperiencesCreative/LightMaze/Experience/MazePresenter.swift` — the test-only `failNextDraw` seam
  (T-A13-604).
- `Packages/ExperiencesCreative/LightMaze/ExperienceTests/MazeRecoveryDrawTests.swift` (T-A13-604).
- `Packages/ExperiencesCreative/LightMaze/ExperienceTests/Fixtures/` with `progress-valid.json`, `progress-newer.json`,
  `progress-damaged.json` and `progress-truncated.json`, the test target's resources in
  `Packages/ExperiencesCreative/Package.swift`, and `ExperienceTests/ProgressSampleFileTests.swift` (T-A13-605).
- `Apps/VisualCore/Tests/UI/LightMaze/LMSupport.swift`, `LMLevelUITests.swift`, `LMHelpUITests.swift` (T-A13-608).

Test files cited by this checklist and the store text (existing): `Packages/ExperiencesCreative/LightMaze/`
`CoreTests/{BeamFixtureTests, BeamTracerTests, BoardDescriptionTests, BoardTests, ContentQATests, HintTests,
LevelCatalogTests, LicenseAuditTests, LoopFixtureTests, MazeStateTests, MovesTests, ProgressTests, SolutionReplayTests,
SolverTests, SuccessCueTests}.swift` and `ExperienceTests/{MazeBeamFixtureTests, MazeCoreTests, MazeFeedbackTests,
MazeGestureTests, MazeGlowTests, MazeHintTests, MazeProgressTests, MazeRenderTests, MazeSessionTests, MazeStyleTests,
ProgressStoreTests}.swift`.

Evidence files (legacy ledger, stage A13-P06): `lm-no-network`, `maze-ios27`, `app-ui`, `verify-27`,
`release-checks`, `claims`, `script-tests` under `.autonomy/checks/A13-P06.<name>.json`; baseline cited from
`.autonomy/checks/A13-P05.{maze-ios27,app-unit,verify-27}.json` (T-A13-601).
