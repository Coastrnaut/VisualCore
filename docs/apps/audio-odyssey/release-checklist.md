# Audio Odyssey — release checklist and artifact inventory

Audio Odyssey (`a07.audio-odyssey`) ships inside the one VisualCore app (ADR-0009); feature 059 (A07-P06), FR-A07-620,
FR-A07-622 and FR-A07-623. App-wide commands are in [build-and-archive.md](../../release/build-and-archive.md). The
spec's four statuses (verified, pending, blocked-owner, device) are written with the status words that
`scripts/check_app_release.py` accepts for every experience:

- `verified` (spec: verified, and pending until its check is recorded): the evidence named in the row is a check of
  the legacy ledger (`.autonomy/checks/A07-P06.<name>.json`, recorded with `desktop_runbook.py run-check` before
  A07-P06 is sealed) or a sealed earlier phase (`.autonomy/checks/A07-P0N.*.json`). A row whose check file does not
  exist yet is pending: the task named in the row records it, and A07-P06 is not sealed before every such file exists
  and passed;
- `pending-campaign-ii` (spec: device): needs the device campaign D1 → D2 → D3 after `ImplementationLock-100`
  ([device-campaign.md](device-campaign.md)); task T-A07-616;
- `owner-action` (spec: blocked-owner): done by the owner only, steps in
  [build-and-archive.md](../../release/build-and-archive.md) section 5 (`BLOCKED_OWNER_ACTION` until done); task
  T-A07-615.

`scripts/check_experience_release.py --config docs/apps/audio-odyssey/release.json` rejects a row without a known
status or without evidence.

| Item | Area | Status | Evidence |
|---|---|---|---|
| No network, tracking, advertising, motion, location, audio recorder or asset writer in the experience's and `VisualCoreAudio`'s sources | Privacy | verified | `.autonomy/checks/A07-P06.ao-no-network.json` (T-A07-603); [privacy-and-credits.md](privacy-and-credits.md) |
| One permission: the app's existing `NSMicrophoneUsageDescription` covers Audio Odyssey; no other usage string added | Privacy | verified | `.autonomy/checks/A07-P06.release-checks.json` (`app-usage-descriptions`, T-A07-613); `project.yml`; [privacy-and-credits.md](privacy-and-credits.md) |
| App privacy manifest matches the Release build and covers the experience's required-reason uses | Privacy | verified | `.autonomy/checks/A07-P06.release-checks.json` (`app-privacy-manifest`, T-A07-613); [privacy-and-credits.md](privacy-and-credits.md) |
| No tracking or advertising in the built app | Privacy | verified | `.autonomy/checks/A07-P06.release-checks.json` (`app-no-tracking`, T-A07-613) |
| Microphone only while chosen; asked once; denied access keeps the demo and leaves everything else usable; stopped in the background and on close; mixes with other audio | Privacy | verified | `.autonomy/checks/A07-P05.odyssey-ios27.json` (`OdysseySourcePickerTests`, `OdysseyAudioTests`; baseline, T-A07-601); `.autonomy/checks/A07-P06.odyssey-ios27.json` (T-A07-610); `MicrophoneSourceTests.testSessionMixesWithOtherAudio` (VisualCoreRendering package) |
| Licenses and acknowledgements: no third-party code or non-code assets in the experience; app Licenses folder equals the inventory | Credits | verified | `.autonomy/checks/A07-P06.release-checks.json` (`app-licenses`, T-A07-613); [privacy-and-credits.md](privacy-and-credits.md) |
| Journey migration: committed fixtures (format 1 tunnel, format 1 star corridor with calm motion, format 2 newer, damaged, a name claiming a built-in id) load or are refused as specified; refused files byte-identical | Data | verified | `.autonomy/checks/A07-P06.odyssey-ios27.json` (`JourneyPresetMigrationTests`, T-A07-604, T-A07-605, T-A07-610) |
| Journey store: built-ins first and read-only; save, rename, delete; unique names; unreadable and newer files counted and kept; a refused write changes nothing | Data | verified | `.autonomy/checks/A07-P05.odyssey-ios27.json` (`JourneyPresetStoreTests`, `OdysseyPresetApplyTests`, `OdysseyPersistenceTests`); `.autonomy/checks/A07-P06.odyssey-ios27.json` (T-A07-610) |
| Drawing-failure recovery: failure state, saved journey files byte-identical, a new session draws | Recovery | verified | `.autonomy/checks/A07-P06.odyssey-ios27.json` (`OdysseyRecoveryDrawTests`, T-A07-606, T-A07-610) |
| Source recovery: an undecodable file keeps the previous source; a stopped source shows a plain message; source switches keep the flight and the host (simulated events) | Recovery | verified | `.autonomy/checks/A07-P05.odyssey-ios27.json` (`OdysseySourcePickerTests`, `OdysseyMappingTests.testFiveSourceSwitchesKeepTheHostAndTheJourney`, `OdysseyAudioTests.testSourceSwitchesKeepDistanceSpeedAndTheHost`); `.autonomy/checks/A07-P06.odyssey-ios27.json` (T-A07-610) |
| Long flights: the tunnel stream stays within its slots, pieces join at one billion units, a restored far journey draws on its first frame | Recovery | verified | `.autonomy/checks/A07-P05.odyssey-ios27.json` (`OdysseyStreamingTests`, `OdysseyLongSessionTests`); `.autonomy/checks/A07-P05.core-ios27.json` (`LongDistanceTests`) |
| VoiceOver: every control has a label and identifier; the canvas description names world, source, speed, easing and calm motion; announcements rate-limited and only with VoiceOver | Accessibility | verified | `.autonomy/checks/A07-P05.odyssey-ios27.json` (`OdysseyAnnouncementTests`, `OdysseySessionTests`); `.autonomy/checks/A07-P05.core-ios27.json` (`JourneyAnnouncerTests`); `.autonomy/checks/A07-P06.app-ui.json` (`AOJourneyUITests`, `AOPresetsUITests`, chunk o2, T-A07-611) |
| Reduce Motion and calm motion: speed capped, no sideways sway, primary response range halved; Reduce Flashing narrows the light | Accessibility | verified | `.autonomy/checks/A07-P05.odyssey-ios27.json` (`OdysseyComfortTests`, `OdysseyCoreTests.reduceMotionCapsTheSpeedAndRemovesTheSway`, `OdysseyMappingTests.testCalmMotionIsDescribedAndHalvesThePrimaryRange`, `OdysseyAudioTests.testReduceMotionAndReduceFlashingNarrowTheResponse`); `.autonomy/checks/A07-P06.odyssey-ios27.json` (T-A07-610) |
| System accessibility audits at default and largest text size | Accessibility | pending-campaign-ii | Run with `VC_RUN_AUDITS=1` in [device-campaign.md](device-campaign.md) (T-A07-616); deferred by owner ruling of 2026-11-13 |
| VoiceOver labels and values on hardware, including the canvas description and the announcements | Accessibility | pending-campaign-ii | [device-campaign.md](device-campaign.md) (T-A07-616) |
| Dynamic Type at the largest accessibility size | Accessibility | pending-campaign-ii | [device-campaign.md](device-campaign.md) (T-A07-616); controls use text styles and wrap (`OdysseyControls.swift`) |
| Reduce Motion and calm motion on hardware | Accessibility | pending-campaign-ii | [device-campaign.md](device-campaign.md) (T-A07-616) |
| Contrast of each world (Tunnel, Landscape, Star corridor) against its background and fog | Accessibility | pending-campaign-ii | [device-campaign.md](device-campaign.md) (T-A07-616) |
| Comfort review of the flight's motion (speed, easing, sway, calm motion) by a person on each device | Accessibility | pending-campaign-ii | [device-campaign.md](device-campaign.md) (T-A07-616); no comfort or motion-sickness claim is made before it |
| ExperiencesCreative package suites on the iOS 27 simulator (sim-27.2; iOS 26 at X-A07 by owner ruling of 2026-11-14) | Tests | verified | `.autonomy/checks/A07-P05.odyssey-ios27.json`, `.autonomy/checks/A07-P05.core-ios27.json` (baseline, T-A07-601); `.autonomy/checks/A07-P06.odyssey-ios27.json` (T-A07-610) |
| App build, unit tests and interface chunk o2: worlds, speed slider, calm motion, pause and resume; mapping change, built-in journey, save | Tests | verified | `.autonomy/checks/A07-P05.app-unit.json` (baseline, T-A07-601); `.autonomy/checks/A07-P06.app-ui.json` (`app-build-for-testing-ios27`, `app-unit-ios27`, `app-ui-ios27-o2`: `AOJourneyUITests`, `AOPresetsUITests`, iOS 27.2 phone simulator, T-A07-611) |
| Experience runner on iOS 27 | Tests | verified | `.autonomy/checks/A07-P05.verify-27.json` (baseline, T-A07-601); `.autonomy/checks/A07-P06.verify-27.json` (T-A07-612) |
| Release build checks: unsigned Release build, no debug or scenario symbols, manifest, tracking, licenses, usage strings | Build | verified | `.autonomy/checks/A07-P06.release-checks.json` (T-A07-613) |
| Release document and copy check scripts tested (pass and fail cases) | Build | verified | `.autonomy/checks/A07-P06.script-tests.json` (T-A07-614) |
| Copy check: no measured claim, unmeasured quality word or missing feature in the store text and interface strings (allowed: audio, music, microphone) | Store | verified | `.autonomy/checks/A07-P06.release-docs.json` (`copy-claims-a07`, T-A07-608; `Configs/copy-claims-denylist.json`) |
| Experience release check: required documents present, every checklist row has status and evidence | Store | verified | `.autonomy/checks/A07-P06.release-docs.json` (`experience-release-a07`, T-A07-608) |
| Store text input describing only implemented and tested features, no hearing, health, comfort or accuracy claim | Store | verified | [store-listing.md](store-listing.md); `.autonomy/checks/A07-P06.release-docs.json` (T-A07-608) |
| Build-and-archive instructions for the one app, owner steps marked | Build | verified | [build-and-archive.md](../../release/build-and-archive.md); its agent-run release steps in `.autonomy/checks/A07-P06.release-checks.json` (T-A07-613) |
| Frame time per world and quality level, piece generation per frame, thermal state over ten minutes on D1, D2, D3 | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) (T-A07-616); no number is claimed before device evidence |
| Real interruptions (call, alarm, Siri) and route changes (headphones out) with the microphone and a file | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) (T-A07-616) |
| Microphone permission flows: first request, refusal, grant, revoke in Settings while running | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) (T-A07-616) |
| Signing team, archive, validation and upload | Distribution | owner-action | [build-and-archive.md](../../release/build-and-archive.md) section 5 steps 1 to 4 (T-A07-615) |
| App Store Connect: record, App Privacy answers (microphone used on device, not collected), the one USD 1.99 non-consumable, store text, screenshots, review submission | Distribution | owner-action | [build-and-archive.md](../../release/build-and-archive.md) section 5 steps 5 to 9 (T-A07-615) |

## Artifact inventory

Documents of this phase (all under `docs/apps/audio-odyssey/` unless a path is given):

- `privacy-and-credits.md` — stored data, sound handling, the one permission, required-reason APIs, credits (T-A07-602).
- `store-listing.md` — store text input with the claim-to-test traceability table (T-A07-607).
- `release-checklist.md` — this checklist (T-A07-607).
- `device-campaign.md` — device measurements with procedure, pass criterion and pending result (T-A07-607).
- `release.json` — release configuration read by `check_experience_release.py` and `release_check.py` (T-A07-607).
- `docs/release/known-limitations.md`, section "Audio Odyssey" — device-only items (T-A07-607).
- `docs/release/build-and-archive.md` — app-wide build and owner steps (existing).
- `README.md`, `visualcore-contract.json`, `visualcore-contract.md`, `regression-baseline.md` — Phase 00 documents
  (existing).

Code and test artifacts of this phase:

- `Packages/ExperiencesCreative/AudioOdyssey/ExperienceTests/Fixtures/` — five journey fixtures (T-A07-604).
- `Packages/ExperiencesCreative/AudioOdyssey/ExperienceTests/JourneyPresetMigrationTests.swift` (T-A07-605).
- `Packages/ExperiencesCreative/AudioOdyssey/ExperienceTests/OdysseyRecoveryDrawTests.swift`, using the existing
  `failNextDraw` seam in `OdysseyPresenter.swift` (T-A07-606).
- `Apps/VisualCore/Tests/UI/AudioOdyssey/` — `AOSupport`, `AOJourneyUITests`, `AOPresetsUITests`; chunk `o2` in
  `scripts/release_check.py` (T-A07-609).

Evidence files (legacy ledger, stage A07-P06): `ao-no-network`, `release-docs`, `odyssey-ios27`, `app-ui`,
`verify-27`, `release-checks`, `script-tests` under `.autonomy/checks/A07-P06.<name>.json`; baseline cited from
`.autonomy/checks/A07-P05.{odyssey-ios27,app-unit,verify-27}.json` (T-A07-601).
