# VisualCore Music Lab — release checklist and artifact inventory

VisualCore Music Lab (`a06.visualcore-music-lab`) ships inside the one VisualCore app (ADR-0009); feature 052
(A06-P06), FR-A06-620, FR-A06-622 and FR-A06-623. App-wide commands are in
[build-and-archive.md](../../release/build-and-archive.md). The spec's four statuses (verified, pending, blocked-owner,
device) are written with the status words that `scripts/check_app_release.py` accepts for every experience:

- `verified` (spec: verified, and pending until its check is recorded): the evidence named in the row is a check of
  the legacy ledger (`.autonomy/checks/A06-P06.<name>.json`, recorded with `desktop_runbook.py run-check` before
  A06-P06 is sealed) or a sealed earlier phase (`.autonomy/checks/A06-P0N.*.json`). A row whose check file does not
  exist yet is pending: the task named in the row records it, and A06-P06 is not sealed before every such file exists
  and passed;
- `pending-campaign-ii` (spec: device): needs the device campaign D1 → D2 → D3 after `ImplementationLock-100`
  ([device-campaign.md](device-campaign.md)); task T-A06-616;
- `owner-action` (spec: blocked-owner): done by the owner only, steps in
  [build-and-archive.md](../../release/build-and-archive.md) section 5 (`BLOCKED_OWNER_ACTION` until done); task
  T-A06-615.

`scripts/check_experience_release.py --config docs/apps/visualcore-music-lab/release.json` rejects a row without a
known status or without evidence.

| Item | Area | Status | Evidence |
|---|---|---|---|
| No network, tracking, advertising, motion, location, audio recorder or asset writer in the experience's and `VisualCoreAudio`'s sources | Privacy | verified | `.autonomy/checks/A06-P06.ml-no-network.json` (T-A06-603); [privacy-and-credits.md](privacy-and-credits.md) |
| One permission: the app's existing `NSMicrophoneUsageDescription` covers Music Lab; no other usage string added | Privacy | verified | `.autonomy/checks/A06-P06.release-checks.json` (`app-usage-descriptions`, T-A06-613); `project.yml`; [privacy-and-credits.md](privacy-and-credits.md) |
| App privacy manifest matches the Release build and covers the experience's required-reason uses | Privacy | verified | `.autonomy/checks/A06-P06.release-checks.json` (`app-privacy-manifest`, T-A06-613); [privacy-and-credits.md](privacy-and-credits.md) |
| No tracking or advertising in the built app | Privacy | verified | `.autonomy/checks/A06-P06.release-checks.json` (`app-no-tracking`, T-A06-613) |
| Microphone only while chosen; stopped on source change and close; mixes with other audio; denied access leaves everything else usable | Privacy | verified | `.autonomy/checks/A06-P06.experiences-ios27.json` (`MusicLabSessionTests`, `MusicLabDeniedUsabilityTests`, T-A06-610); `.autonomy/checks/A06-P04.rendering-ios27.json` (`MicrophoneSourceTests`) |
| Licenses and acknowledgements: no third-party code or non-code assets in the experience; app Licenses folder equals the inventory | Credits | verified | `.autonomy/checks/A06-P06.release-checks.json` (`app-licenses`, T-A06-613); [privacy-and-credits.md](privacy-and-credits.md) |
| Preset migration: committed fixtures (format 1, format 2, newer format, damaged, a name claiming a built-in id) load or are refused as specified; refused files byte-identical | Data | verified | `.autonomy/checks/A06-P06.experiences-ios27.json` (`MusicLabPresetMigrationTests`, T-A06-604, T-A06-605, T-A06-610) |
| Preset store: built-ins first and read-only; save, rename, delete; unreadable and newer files counted and kept; a refused write changes nothing | Data | verified | `.autonomy/checks/A06-P05.experiences-ios27.json` (`MusicLabPresetStoreTests`); `.autonomy/checks/A06-P06.experiences-ios27.json` (T-A06-610) |
| Drawing-failure recovery: failure state, saved presets byte-identical, a new session draws | Recovery | verified | `.autonomy/checks/A06-P06.experiences-ios27.json` (`MusicLabRecoveryDrawTests`, T-A06-606, T-A06-610) |
| Audio interruptions, route loss and media reset: pause, Resume or demo signal, rebuild, at most one capture engine, rendering never wedged (simulated events) | Recovery | verified | `.autonomy/checks/A06-P04.rendering-ios27.json` (`AudioSessionEventTests`, `MicrophoneRecoveryTests`); `.autonomy/checks/A06-P06.experiences-ios27.json` (`MusicLabRecoveryTests`, `MusicLabTransitionTests`, T-A06-610) |
| VoiceOver: every control has a label and identifier; the canvas description and the sound metrics value follow the sound; announcements rate-limited and only with VoiceOver | Accessibility | verified | `.autonomy/checks/A06-P06.experiences-ios27.json` (`MusicLabMetricsTests`, T-A06-610); `.autonomy/checks/A06-P06.app-ui-5.json` (`MLScenesUITests`, chunk m2, T-A06-611) |
| Reduce Motion: the Geometry scene's sound-driven spin stays at rest | Accessibility | verified | `.autonomy/checks/A06-P06.experiences-ios27.json` (`MusicLabSceneRenderTests.testReduceMotionKeepsTheSpinAtItsMinimum`, T-A06-610) |
| System accessibility audits at default and largest text size | Accessibility | pending-campaign-ii | Run with `VC_RUN_AUDITS=1` in [device-campaign.md](device-campaign.md) (T-A06-616); deferred by owner ruling of 2026-11-13 |
| VoiceOver labels and values on hardware, including the sound metrics text | Accessibility | pending-campaign-ii | [device-campaign.md](device-campaign.md) (T-A06-616) |
| Dynamic Type at the largest accessibility size | Accessibility | pending-campaign-ii | [device-campaign.md](device-campaign.md) (T-A06-616); controls use text styles and wrap (`MusicLabControls.swift`) |
| Reduce Motion on hardware | Accessibility | pending-campaign-ii | [device-campaign.md](device-campaign.md) (T-A06-616) |
| Contrast of each palette (Aurora, Ember, Mono) on every scene | Accessibility | pending-campaign-ii | [device-campaign.md](device-campaign.md) (T-A06-616) |
| ExperiencesCreative package suites on the iOS 27 simulator (sim-27.2; iOS 26 at X-A06 by owner ruling of 2026-11-14) | Tests | verified | `.autonomy/checks/A06-P05.experiences-ios27.json` (baseline, T-A06-601); `.autonomy/checks/A06-P06.experiences-ios27.json` (T-A06-610) |
| App build, unit tests and interface chunk m2: scenes, palette, metrics text; mapping strength, built-in preset, save | Tests | verified | `.autonomy/checks/A06-P06.app-ui-5.json` (`app-build-for-testing-ios27`, `app-unit-ios27`, `app-ui-ios27-m2`: `MLScenesUITests`, `MLPresetsUITests`, iOS 27.2 phone simulator, T-A06-611) |
| Experience runner on iOS 27 | Tests | verified | `.autonomy/checks/A06-P06.verify-27.json` (T-A06-612) |
| Release build checks: unsigned Release build, no debug or scenario symbols, manifest, tracking, licenses, usage strings | Build | verified | `.autonomy/checks/A06-P06.release-checks.json` (T-A06-613) |
| Release document and copy check scripts tested (pass and fail cases) | Build | verified | `.autonomy/checks/A06-P06.script-tests.json` (T-A06-614) |
| Copy check: no measured claim, unmeasured quality word or missing feature in the store text and interface strings (allowed: audio, music, microphone) | Store | verified | `.autonomy/checks/A06-P06.release-docs.json` (`copy-claims-a06`, T-A06-608; `Configs/copy-claims-denylist.json`) |
| Experience release check: required documents present, every checklist row has status and evidence | Store | verified | `.autonomy/checks/A06-P06.release-docs.json` (`experience-release-a06`, T-A06-608) |
| Store text input describing only implemented and tested features, no hearing, health or accuracy claim | Store | verified | [store-listing.md](store-listing.md); `.autonomy/checks/A06-P06.release-docs.json` (T-A06-608) |
| Build-and-archive instructions for the one app, owner steps marked | Build | verified | [build-and-archive.md](../../release/build-and-archive.md); its agent-run release steps in `.autonomy/checks/A06-P06.release-checks.json` (T-A06-613) |
| Frame time per scene and analysis level, thermal state over ten minutes on D1, D2, D3 | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) (T-A06-616); no number is claimed before device evidence |
| Real interruptions (call, alarm, Siri) and route changes (headphones out) with the microphone and a file | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) (T-A06-616) |
| Microphone permission flows: first request, refusal, grant, revoke in Settings while running | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) (T-A06-616) |
| Signing team, archive, validation and upload | Distribution | owner-action | [build-and-archive.md](../../release/build-and-archive.md) section 5 steps 1 to 4 (T-A06-615) |
| App Store Connect: record, App Privacy answers (microphone used on device, not collected), the one USD 1.99 non-consumable, store text, screenshots, review submission | Distribution | owner-action | [build-and-archive.md](../../release/build-and-archive.md) section 5 steps 5 to 9 (T-A06-615) |

## Artifact inventory

Documents of this phase (all under `docs/apps/visualcore-music-lab/` unless a path is given):

- `privacy-and-credits.md` — stored data, sound handling, the one permission, required-reason APIs, credits (T-A06-602).
- `store-listing.md` — store text input with the claim-to-test traceability table (T-A06-607).
- `release-checklist.md` — this checklist (T-A06-607).
- `device-campaign.md` — device measurements with procedure, pass criterion and pending result (T-A06-607).
- `release.json` — release configuration read by `check_experience_release.py` and `release_check.py` (T-A06-607).
- `docs/release/known-limitations.md`, section "VisualCore Music Lab" — device-only items (T-A06-607).
- `docs/release/build-and-archive.md` — app-wide build and owner steps (existing).
- `README.md`, `visualcore-contract.json`, `visualcore-contract.md`, `regression-baseline.md` — Phase 00 documents
  (existing).

Code and test artifacts of this phase:

- `Packages/ExperiencesCreative/VisualCoreMusicLab/ExperienceTests/Fixtures/` — five preset fixtures (T-A06-604).
- `Packages/ExperiencesCreative/VisualCoreMusicLab/ExperienceTests/MusicLabPresetMigrationTests.swift` (T-A06-605).
- `Packages/ExperiencesCreative/VisualCoreMusicLab/ExperienceTests/MusicLabRecoveryDrawTests.swift` and the
  `failNextDraw` seam in `MusicLabPresenter.swift` (T-A06-606).
- `Apps/VisualCore/Tests/UI/MusicLab/` — `MLSupport`, `MLScenesUITests`, `MLPresetsUITests`; chunk `m2` in
  `scripts/release_check.py` (T-A06-609).

Evidence files (legacy ledger, stage A06-P06): `ml-no-network`, `release-docs`, `experiences-ios27`, `app-ui`,
`verify-27`, `release-checks`, `script-tests` under `.autonomy/checks/A06-P06.<name>.json`.
