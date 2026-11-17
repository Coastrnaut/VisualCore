# Implementation Plan: Aurora — Phase 05 Long-run thermal and comfort validation

**Branch**: `156-au-p05-sound-device` (spec directory only; work on `main`) | **Date**: 2026-11-17 | **Spec**: [spec.md](spec.md)

## Summary

This phase does three things, with no VisualCore change:
- **G-SOUND:** the presenter plays the shared ambient loop (`AmbientLoopPlayer`, A21-P04) through its sound choice,
  following the controls view's life and the app's scene phase, never the drawing's.
- **Fixture 5:** the low-power cadence is proved: the host's 30 fps cap, and the same sky time and pixels at both
  cadences.
- **Interface and G-DEVICE:** the journeys run in serial chunk `c3`, and G-DEVICE closes with a campaign plan (AU-D1
  to AU-D8, all pending).

Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contract:
[contracts/sound.md](contracts/sound.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

- **Language:** Swift 6, SwiftUI, XCTest UI tests and Markdown.
- **Dependencies:** adds `VisualCoreAudio` (package `VisualCoreRendering`) and `VisualCoreAudioDSP` (package
  `VisualCore`) to `AuroraExperience` in Package.swift (lead). Both products already serve other targets of the
  manifest (A20). The APIs used were verified in code:
  - `AmbientLoopPlayer(recipe:)` with `isEnabled`, `isPlaying`, `volume`, `play()` and `stop()`;
  - `AmbientLoopRecipe.gentle`;
  - `FramePacing(thermal:lowPower:requestedMaxFPS:)` with `.maxFPS` and `FramePacing.clampedDelta(_:)` (in
    VisualCoreDiagnostics, already a dependency);
  - `SkyClock.advance(by:)`.
- **Testing:**
  - the A21 package tests on sim-27.2;
  - `release_check.py --only app-build-for-testing-ios27 app-unit-ios27 app-ui-ios27-c3`;
  - the runner on iOS 27.
- **Constraints:**
  - unit tests run under 10 s each and interface tests under 60 s each;
  - no audio plays in tests;
  - audits wait for devices, and nothing is installed on a device before ImplementationLock-100.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| II | PASS: reuses `AmbientLoopPlayer`, `FramePacing` and the host's clamped delta; nothing copied |
| V | PASS: device rows wait for ImplementationLock-100; nothing runs on a device |
| VI | PASS: no simulator number presented as device evidence |
| IX | PASS: sound toggle and volume slider labelled; audits are campaign row AU-D8 |
| XIII | PASS: the loop is synthesised in code (`AmbientLoopRecipe.gentle`), recorded in `docs/apps/aurora/licenses.md` |
| A21 | PASS: sound off by default, no background audio, no microphone; no flashing; no forecast or measured claim |

Post-design: PASS.

## Project Structure

```text
Packages/ExperiencesCreative/Package.swift                                              modify  VisualCoreAudio, VisualCoreAudioDSP
Packages/ExperiencesCreative/Aurora/Experience/SkySound.swift                           new     SkyLoopPlaying seam, SkySound policy
Packages/ExperiencesCreative/Aurora/Experience/AuroraPresenter.swift                    modify  owns SkySound; setSound/setVolume drive it
Packages/ExperiencesCreative/Aurora/Experience/AuroraControls.swift                     modify  onAppear/onDisappear, scenePhase, hint text
Packages/ExperiencesCreative/Aurora/Experience/AuroraExperience.swift                   modify  test factory takes a loop
Packages/ExperiencesCreative/Aurora/ExperienceTests/{SoundLoopTests,LowPowerCadenceTests}.swift   new
Apps/VisualCore/Tests/UI/Aurora/{AUSupport,AUSkyUITests,AUSoundUITests}.swift           new
scripts/release_check.py (chunk "c3", SERIAL_CHUNKS)                                    modify
docs/apps/aurora/device-campaign.md                                                     new
docs/apps/aurora/licenses.md (the loop row)                                             modify
docs/apps/aurora/visualcore-contract.json (G-SOUND, G-DEVICE closed)                    modify
```

- **Dependency direction:** experience → VisualCoreAudio → VisualCoreAudioDSP; the core stays free of audio.
- **Lifecycle:** see [contracts/sound.md](contracts/sound.md). The drawing calls (`setup`, `resize`, `draw`,
  `teardown`) never touch the sound (Aurora keeps the protocol's default `shedCaches`, which does nothing).
- **As built:** `AuroraPresenter.fixedDelta` is a test-only seam (nil in the app, where the host's clamped delta
  drives the clock); the cadence tests set it to 1/30 s or 1/60 s.
- **Test seam:** `SkyLoopPlaying` (isEnabled, volume, isPlaying, play, stop), to which `AmbientLoopPlayer` conforms by
  extension; the presenter takes a factory (nil: `AmbientLoopPlayer(recipe: .gentle)`, made lazily on first need).
- **Migration:** none; `prefs.v1` already keeps the sound choice (A21-P04). **Rollback:** revert the commits.

## Parallel work

- **Agent E:** SkySound, the presenter and controls changes, and both test files.
- **Agent U:** the interface tests.
- **Agent D:** the campaign plan and the licence row.
- **Lead:** Package.swift, release_check.py, the contract, the runs and the commits.
