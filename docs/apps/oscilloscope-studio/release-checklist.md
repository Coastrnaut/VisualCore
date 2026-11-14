# Oscilloscope Studio — release checklist and artifact inventory

Oscilloscope Studio (`a08.oscilloscope-studio`) ships inside the one VisualCore app (ADR-0009); feature 066 (A08-P06),
FR-A08-620, FR-A08-622 and FR-A08-623. App-wide commands are in [build-and-archive.md](../../release/build-and-archive.md).
The spec's four statuses (verified, pending, blocked-owner, device) are written with the status words that
`scripts/check_app_release.py` accepts for every experience:

- `verified` (spec: verified, and pending until its check is recorded): the evidence named in the row is a check of
  the legacy ledger (`.autonomy/checks/A08-P06.<name>.json`, recorded with `desktop_runbook.py run-check` before
  A08-P06 is sealed) or a sealed earlier phase (`.autonomy/checks/A08-P0N.*.json`). A row whose check file does not
  exist yet is pending: the task named in the row records it, and A08-P06 is not sealed before every such file exists
  and passed;
- `pending-campaign-ii` (spec: device): needs the device campaign D1 → D2 → D3 after `ImplementationLock-100`
  ([device-campaign.md](device-campaign.md)); task T-A08-616;
- `owner-action` (spec: blocked-owner): done by the owner only, steps in
  [build-and-archive.md](../../release/build-and-archive.md) section 5 (`BLOCKED_OWNER_ACTION` until done); task
  T-A08-615.

`scripts/check_experience_release.py --config docs/apps/oscilloscope-studio/release.json` rejects a row without a known
status or without evidence.

| Item | Area | Status | Evidence |
|---|---|---|---|
| No network, tracking, advertising, motion, location, audio recorder or asset writer in the experience's and `VisualCoreAudio`'s sources | Privacy | verified | `.autonomy/checks/A08-P06.os-no-network.json` (T-A08-603); [privacy-and-credits.md](privacy-and-credits.md) |
| One permission: the app's existing `NSMicrophoneUsageDescription` covers Oscilloscope Studio; no other usage string added | Privacy | verified | `.autonomy/checks/A08-P06.release-checks.json` (`app-usage-descriptions`, T-A08-613); `project.yml`; [privacy-and-credits.md](privacy-and-credits.md) |
| App privacy manifest matches the Release build and covers the experience's required-reason uses | Privacy | verified | `.autonomy/checks/A08-P06.release-checks.json` (`app-privacy-manifest`, T-A08-613); [privacy-and-credits.md](privacy-and-credits.md) |
| No tracking or advertising in the built app | Privacy | verified | `.autonomy/checks/A08-P06.release-checks.json` (`app-no-tracking`, T-A08-613) |
| Microphone only while chosen; asked once; denied access keeps the previous source and offers the test signal; stopped in the background, on suspension and on close; one or two channels as the route delivers; mixes with other audio | Privacy | verified | `.autonomy/checks/A08-P05.scope-ios27-2.json` (`ScopeSessionTests`; baseline, T-A08-601); `.autonomy/checks/A08-P05.audio-ios27.json` (`StereoMicrophoneAudioSourceTests`); `.autonomy/checks/A08-P06.scope-ios27.json` (T-A08-610); `MicrophoneSourceTests.testSessionMixesWithOtherAudio` (VisualCoreRendering package) |
| Readouts relative to full scale; no calibrated, certified, laboratory or medical wording in the readouts | Privacy | verified | `.autonomy/checks/A08-P05.scope-ios27-2.json` (`ScopeAccuracyAuditTests`, `SpectrumReadoutTests.noCalibratedWordingInAnyText`; baseline, T-A08-601); `.autonomy/checks/A08-P06.scope-ios27.json` (T-A08-610) |
| Licenses and acknowledgements: no third-party code or non-code assets in the experience; app Licenses folder equals the inventory | Credits | verified | `.autonomy/checks/A08-P06.release-checks.json` (`app-licenses`, T-A08-613); [privacy-and-credits.md](privacy-and-credits.md) |
| Preset migration: committed fixtures (format 1 waveform, format 1 spectrum, format 2 newer, damaged, a file claiming a built-in id) load or are refused as specified; refused files byte-identical | Data | verified | `.autonomy/checks/A08-P06.scope-ios27.json` (`ScopePresetMigrationTests`, T-A08-604, T-A08-605, T-A08-610) |
| Preset store: built-ins first and read-only; save, rename, apply, delete; unreadable and newer files counted and kept; a save beyond the quota refused with a message and nothing changed | Data | verified | `.autonomy/checks/A08-P05.scope-ios27-2.json` (`ScopePresetStoreTests`; baseline, T-A08-601); `.autonomy/checks/A08-P06.scope-ios27.json` (T-A08-610) |
| Session state: schema 1 to 3 snapshots restore; damaged payloads refused | Data | verified | `.autonomy/checks/A08-P05.scope-ios27-2.json` (`ScopeCoreTests`, `ScopeStateTests`; baseline, T-A08-601) |
| Drawing-failure recovery: failure state, saved preset files byte-identical, a new session draws | Recovery | verified | `.autonomy/checks/A08-P06.scope-ios27.json` (`ScopeRecoveryDrawTests`, T-A08-606, T-A08-610) |
| Source recovery: an undecodable file keeps the previous source; a restored file asks to be chosen again; route changes rebuild the capture (simulated events) | Recovery | verified | `.autonomy/checks/A08-P05.scope-ios27-2.json` (`ScopeSessionTests.testAnUndecodableFileKeepsThePreviousSource`, `testATwoChannelMicrophoneRouteDrawsXYAndARouteChangeFallsBackWithTheMark`); `.autonomy/checks/A08-P05.audio-ios27.json` (`StereoMicrophoneAudioSourceTests`, `StereoFileAudioSourceTests`) |
| VoiceOver: every control has a label and identifier; the canvas description names view, source, channels, timebase or readout, frozen and clipping; announcements rate-limited and only with VoiceOver | Accessibility | verified | `.autonomy/checks/A08-P05.scope-ios27-2.json` (`ScopeDescriptionTests`, `ScopeAnnouncerTests`; baseline, T-A08-601); `.autonomy/checks/A08-P06.app-ui.json` (`OSScopeUITests`, `OSPresetsUITests`, chunk p2, T-A08-611) |
| System accessibility audits at default and largest text size | Accessibility | pending-campaign-ii | Run with `VC_RUN_AUDITS=1` in [device-campaign.md](device-campaign.md) (T-A08-616); deferred by owner ruling of 2026-11-13 |
| VoiceOver labels and values on hardware, including the canvas description and the announcements | Accessibility | pending-campaign-ii | [device-campaign.md](device-campaign.md) (T-A08-616) |
| Dynamic Type at the largest accessibility size | Accessibility | pending-campaign-ii | [device-campaign.md](device-campaign.md) (T-A08-616); controls use text styles and wrap (`ScopeControls.swift`) |
| Reduce Motion and Reduce Flashing on hardware | Accessibility | pending-campaign-ii | [device-campaign.md](device-campaign.md) (T-A08-616) |
| Trace contrast of the waveform, XY and spectrum traces, the clip colour, the grid and the cursors against the background | Accessibility | pending-campaign-ii | [device-campaign.md](device-campaign.md) (T-A08-616) |
| ExperiencesCreative package suites on the iOS 27 simulator (sim-27.2; iOS 26 at X-A08 by owner ruling of 2026-11-14) | Tests | verified | `.autonomy/checks/A08-P05.scope-ios27-2.json` (baseline, T-A08-601); `.autonomy/checks/A08-P06.scope-ios27.json` (T-A08-610) |
| App build, unit tests and interface chunk p2: waveform, timebase, gain, XY and spectrum views; freeze, cursors, built-in preset, save | Tests | verified | `.autonomy/checks/A08-P05.app-unit.json` (baseline, T-A08-601); `.autonomy/checks/A08-P06.app-ui.json` (`app-build-for-testing-ios27`, `app-unit-ios27`, `app-ui-ios27-p2`: `OSScopeUITests`, `OSPresetsUITests`, iOS 27.2 phone simulator, T-A08-611) |
| Experience runner on iOS 27 | Tests | verified | `.autonomy/checks/A08-P05.verify-27.json` (baseline, T-A08-601); `.autonomy/checks/A08-P06.verify-27.json` (T-A08-612) |
| Release build checks: unsigned Release build, no debug or scenario symbols, manifest, tracking, licenses, usage strings | Build | verified | `.autonomy/checks/A08-P06.release-checks.json` (T-A08-613) |
| Release document and copy check scripts tested (pass and fail cases, a missing required document fails) | Build | verified | `.autonomy/checks/A08-P06.script-tests.json` (T-A08-614) |
| Copy check: no measured claim, unmeasured quality word or missing feature in the store text and interface strings (allowed: audio, microphone; signal units marked line by line) | Store | verified | `.autonomy/checks/A08-P06.release-docs.json` (`copy-claims-a08`, T-A08-608; `Configs/copy-claims-denylist.json`) |
| Experience release check: required documents present, every checklist row has status and evidence | Store | verified | `.autonomy/checks/A08-P06.release-docs.json` (`experience-release-a08`, T-A08-608) |
| Store text input describing only implemented and tested features, readouts relative to full scale, no number with a unit, no hearing, health or accuracy claim | Store | verified | [store-listing.md](store-listing.md); `.autonomy/checks/A08-P06.release-docs.json` (T-A08-608) |
| Build-and-archive instructions for the one app, owner steps marked | Build | verified | [build-and-archive.md](../../release/build-and-archive.md); its agent-run release steps in `.autonomy/checks/A08-P06.release-checks.json` (T-A08-613) |
| CPU and GPU frame time per view (waveform, XY, spectrum) and quality level; thermal state over ten minutes on D1, D2, D3 | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) (T-A08-616); no number is claimed before device evidence |
| Memory across views, sources and leaving the experience | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) (T-A08-616) |
| Persistence and lifecycle: presets survive relaunch; the container holds only `scope-<uuid>.json` and `state.json`; no audio file | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) (T-A08-616) |
| Real stereo routes, route changes, sample rates and input latency | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) (T-A08-616); no latency figure is stated |
| Real interruptions (call, alarm, Siri) and microphone permission flows (first request, refusal, grant, revoke in Settings) | Device | pending-campaign-ii | [device-campaign.md](device-campaign.md) (T-A08-616) |
| Signing team, archive, validation and upload | Distribution | owner-action | [build-and-archive.md](../../release/build-and-archive.md) section 5 steps 1 to 4 (T-A08-615) |
| App Store Connect: record, App Privacy answers (microphone used on device, not collected), the one USD 1.99 non-consumable, store text, screenshots, review submission | Distribution | owner-action | [build-and-archive.md](../../release/build-and-archive.md) section 5 steps 5 to 9 (T-A08-615) |

## Artifact inventory

Documents of this phase (all under `docs/apps/oscilloscope-studio/` unless a path is given):

- `privacy-and-credits.md` — stored data, sound handling, the one permission, required-reason APIs, credits (T-A08-602).
- `store-listing.md` — store text input with the claim-to-test traceability table (T-A08-607).
- `release-checklist.md` — this checklist (T-A08-607).
- `device-campaign.md` — device measurements with procedure, pass criterion and pending result (feature 065
  T-A08-512, extended by T-A08-607).
- `release.json` — release configuration read by `check_experience_release.py` and `release_check.py` (T-A08-607).
- `docs/release/known-limitations.md`, section "Oscilloscope Studio" — device-only items, quota and restored file
  (T-A08-607).
- `docs/release/build-and-archive.md` — app-wide build and owner steps (existing).
- `README.md`, `visualcore-contract.json`, `visualcore-contract.md`, `regression-baseline.md` — Phase 00 documents
  (existing).

Code and test artifacts of this phase:

- `Packages/ExperiencesCreative/OscilloscopeStudio/ExperienceTests/Fixtures/` — five preset fixtures (T-A08-604).
- `Packages/ExperiencesCreative/OscilloscopeStudio/ExperienceTests/ScopePresetMigrationTests.swift` (T-A08-605).
- `Packages/ExperiencesCreative/OscilloscopeStudio/ExperienceTests/ScopeRecoveryDrawTests.swift`, using the existing
  `failNextDraw` seam in `ScopePresenter.swift` (T-A08-606).
- `Packages/ExperiencesCreative/OscilloscopeStudio/Experience/ScopePresenter.swift` — `copy-claims: allow (signal
  unit)` markers on the signal-unit lines (T-A08-608).
- `Apps/VisualCore/Tests/UI/OscilloscopeStudio/` — `OSSupport`, `OSScopeUITests`, `OSPresetsUITests`; chunk `p2` in
  `scripts/release_check.py` (T-A08-609).

Evidence files (legacy ledger, stage A08-P06): `os-no-network`, `release-docs`, `scope-ios27`, `app-ui`, `verify-27`,
`release-checks`, `script-tests` under `.autonomy/checks/A08-P06.<name>.json`; baseline cited from
`.autonomy/checks/A08-P05.{scope-ios27-2,app-unit,verify-27}.json` (T-A08-601).
