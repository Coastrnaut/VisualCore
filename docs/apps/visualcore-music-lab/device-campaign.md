# VisualCore Music Lab — device campaign plan

**Status: nothing measured on a device.** Every result below is pending. Feature 052 (A06-P06), FR-A06-622 and
FR-A06-623, task T-A06-616 ({device}). VisualCore Music Lab (`a06.visualcore-music-lab`) is measured as a row of the
one VisualCore app's device campaign (Auto-Creator.md section 23), not as a separate app. Simulator results,
including the analysis, recovery and transition suites of A06-P04 and A06-P05 (`MusicLabRecoveryTests`,
`MusicLabTransitionTests`, `AudioSessionEventTests`, `MicrophoneRecoveryTests`) and the hot-path checks, are
development signals only and never device evidence; their interruptions and route changes are simulated events.

## When and in which order

1. Not before the gate `ImplementationLock-100` is recorded: `python3 scripts/migration_ledger.py guard-device` must
   exit 0. No install, launch or test of the app on a physical device happens earlier.
2. The owner has provisioned signing, paired, trusted and unlocked the devices and answers every system prompt that
   needs a person (owner steps; otherwise the row is `BLOCKED_OWNER_ACTION`). The agent never taps a permission or
   trust prompt itself; the permission rows below are carried out by the owner on the device, following the
   procedure, while the agent records the app's side.
3. Order: **D1** (iPhone 15), then **D2** (iPad Pro 13-inch M5), then **D3** (iPad A16). **D3 stays on iPadOS 26.5
   and is never updated**; if it reports another version, its campaign is blocked and the owner is told.
4. The runner of the campaign, `scripts/run_device_campaign.py`, is planned for UA-F13 (Auto-Creator.md 23.3) and does
   not exist yet. Hardware identifiers go only to untracked private files.
5. Test audio is the synthetic tone and note sequence the tests generate, played from a file picked in the experience
   or from a second device near the microphone; no recorded or third-party sound is used.

## Measurements

The host's quality tier is clamped to the analysis levels 0 to 2 (`MusicLabPresenter.draw`, `AnalysisQuality`):
tier 0 → level 0 (window 1,024, 16 bands), tier 1 → level 1 (512, 16), tier 2 and lower → level 2 (256, 8).

| Measurement | Devices | Procedure | Pass criterion | Result |
|---|---|---|---|---|
| Frame time per scene and tier | D1, D2, D3 | For each scene (Bars, Rings, Geometry) with the demo signal, then a file, then the microphone, pin the host's quality level to each tier and record the frame intervals of the drawn frames over a short run; first-run and warm runs separate. Source: `PerformanceRecord.pacing`, `qualityLevel`, `qualityPinned` (written by `ExperienceSession.makeRecord`) | At the tier the governor settles on, no sustained run of dropped frames (frame intervals stay within twice the display's refresh interval except isolated spikes); every lower tier is at least as fast as the tier above it; no analysis-level change wedges drawing | pending |
| Settled quality tier | D1, D2, D3 | Automatic mode on each scene with the microphone; record the tier the governor settles on and each change with its cause (thermal state, Low Power Mode). Source: `PerformanceRecord.qualityLevel`, `stepsDown`, `stepsUp`; `QualityGovernor` | The governor settles; every step has a recorded cause; the analysis restarts cleanly at the new level (metrics text keeps updating) | pending |
| Thermal state over ten minutes | D1, D2, D3 | Ten minutes on the Geometry scene with the microphone live and a tone playing, the device at room temperature and not charging; record `PerformanceRecord.thermal`, `lowPower`, the tier and the frame intervals each minute | The thermal state never reaches critical; when it rises, the tier steps down instead of frames being dropped; the state digest never changes from the quality steps | pending |
| Memory | D1, D2, D3 | After every scene has been drawn at every tier, after switching sources five times and after leaving the experience: `PerformanceRecord.memoryFootprintBytes`, `gpuBytes`, `memoryEvents`; `ResourceRegistry` counts | No growth across repeated source switches; render resources return to the host's baseline after leaving | pending |
| Real interruption: phone call | D1 (call), D2 and D3 (FaceTime audio) | Microphone live; the owner places an incoming call, answers, hangs up; then repeats and declines. Watch the status line and the controls | During the call the status reads paused by the system; after it ends the input resumes or Resume is offered; Use demo signal works; drawing never stops; at most one capture engine (no doubled input) | pending |
| Real interruption: alarm | D1, D2, D3 | Microphone live; a Clock alarm fires and is stopped; then a timer ends | Same as the phone call row | pending |
| Real interruption: Siri | D1, D2, D3 | Microphone live; Siri is invoked and dismissed | Same as the phone call row | pending |
| Route change: headphones out | D1, D2, D3 | With wired or Bluetooth headphones carrying a microphone, choose the microphone, then disconnect them; repeat with a file playing in another app | The source rebuilds on the built-in microphone or stops with a plain message and Resume or Use demo signal; the other app's music keeps playing (`.mixWithOthers`); drawing never stops | pending |
| Other apps' music keeps playing | D1, D2, D3 | Start music in another app, open Music Lab and choose the microphone, change scenes and presets, close the experience | The other app's playback is not paused or ducked at any step | pending |
| Microphone permission: first request | D1, D2, D3 | Fresh install; choose Microphone; the owner reads the system prompt | The prompt shows the app's `NSMicrophoneUsageDescription` text verbatim; it is asked once only | pending |
| Microphone permission: refusal | D1, D2, D3 | The owner refuses; then choose Microphone again | The demo signal stays live; a plain message offers Open Settings; no second prompt; every scene, the mapping editor and the presets work | pending |
| Microphone permission: grant | D1, D2, D3 | The owner grants from Settings and returns to the app; choose Microphone | The input becomes live; the metrics text follows the room's sound | pending |
| Microphone permission: revoke in Settings while running | D1, D2, D3 | Microphone live; the owner turns microphone access off for VisualCore in Settings (the system ends the app) and reopens it | The app relaunches into the experience without the microphone: the next start fails with a message and offers the demo signal; saved presets are unchanged | pending |
| VoiceOver labels and values | D1, D2, D3 | VoiceOver on: open the experience and hear the canvas description; move through source, scene, palette, mapping (feature, strength, reset), presets (apply, rename, delete, save), Resume and Use demo signal; read the "Sound metrics (approximate)" value while a tone plays and in silence | Every control is reached and has a meaningful label and, where it has one, a value; the metrics value states level, strongest region and beat and follows the sound; announcements at most one per two seconds and only on changes | pending |
| Accessibility system audits | D1, D2, D3 | The system accessibility audits at the default and the largest accessibility text size, run with `VC_RUN_AUDITS=1` (`AppUITestSupport.swift`; deferred to the devices by owner ruling of 2026-11-13) | No audit issue in the Music Lab screens | pending |
| Dynamic Type | D1, D2, D3 | Set the largest accessibility text size; open every section of the controls in portrait and landscape | All text visible or scrollable, nothing clipped or overlapping; every control still operable | pending |
| Reduce Motion | D1, D2, D3 | Reduce Motion on; Geometry scene with a beat-heavy tone; then off | With it on, the sound-driven spin stays at rest while other mappings still respond; with it off, the spin follows the sound | pending |
| Palette contrast | D1, D2, D3 | Each palette (Aurora, Ember, Mono) on each scene in a lit room and in a dark room, with Increase Contrast off and on; screenshots kept privately | The drawn bars, rings and meshes are distinguishable from the background in every combination; controls text keeps the system's contrast | pending |
| Persistence and lifecycle | D1, D2, D3 | Save presets, relaunch, background and foreground with the microphone live | Presets survive relaunch; the container holds only `preset-<uuid>.json` files and the app's `state.json` in the experience's folder; no audio file anywhere in the container; the input stops in the background and restarts in the foreground | pending |

Each row is recorded pass, fail or `BLOCKED_OWNER_ACTION`; skipped is never success. No measured value of Music
Lab's speed, timing, heat or memory appears in any document or store text until a device row records it.

## Links

- Release checklist: [release-checklist.md](release-checklist.md) (rows with status `pending-campaign-ii`).
- Known limitations: [known-limitations.md](../../release/known-limitations.md), section "VisualCore Music Lab".
- Privacy: [privacy-and-credits.md](privacy-and-credits.md).
- Build and owner steps: [build-and-archive.md](../../release/build-and-archive.md).
