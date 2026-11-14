# Implementation Plan: VisualCore Music Lab — Phase 04 Presets and recovery UX

**Branch**: `050-ml-p04-presets-recovery` (spec directory only; work on `main`) | **Date**: 2026-11-14 | **Spec**: [spec.md](spec.md)

## Summary

VisualCore closes G-INTERRUPTION in `VisualCoreAudio`: `AudioSessionEvent` (pure mapping from the session's
notifications), `AudioSessionEventMonitor` (injectable `NotificationCenter`), `AudioSourceState.interrupted`, and
`MicrophoneAudioSource.handle(_:)`/`resume()` over an internal `MicrophoneCapture` seam (system capture = today's
session + engine code). The experience adds the status condition and recovery buttons, a preset library
(`MusicLabPresetStore`, one file per preset in `ExperienceStorage`, built-ins in code), the `preset.apply` action,
preset controls, and a permission-denied usability test. Research: [research.md](research.md); model:
[data-model.md](data-model.md); contract: [contracts/api.md](contracts/api.md); evidence: [quickstart.md](quickstart.md).

## Technical Context

**Language**: Swift 6. **Verified APIs**: `MicrophoneAudioSource.start(into:)`/`stop()`/`engineStartCount`,
`AudioSourceState`, `ExperienceStorage.write(_:to:)`/`read(_:)`/`list()`/`remove(_:)` (atomic, quota), the factory
`make(id:storage:reduceMotion:reduceFlashing:)`, `MusicLabState.select(scene:)`/`setMapping`, `MappingChoice`,
`MusicLabScene.parameters`, `ExperienceControl` (≤ 24 values), `AVAudioSession` notifications
`interruptionNotification` (keys `AVAudioSessionInterruptionTypeKey`, `AVAudioSessionInterruptionOptionKey` with
`.shouldResume`), `routeChangeNotification` (`AVAudioSessionRouteChangeReasonKey` = `.oldDeviceUnavailable`),
`mediaServicesWereResetNotification`. **Storage**: preset files format 1. **Testing**: VisualCoreRendering
`VisualCoreAudioTests` on sim-27.2 (event mapping, monitor, 50 seeded sequences with a capture double);
ExperiencesCreative on sim-27.2 (preset library, apply action, status, denied usability); app build/unit; runner iOS 27;
public API; script tests. **Constraints**: tests < 10 s; iOS 27 only; reference regression at X-A06.

## Constitution Check

I PASS (no new rendering; scenes unchanged) · II PASS (session recovery in VisualCore; presets app-local) · II-a PASS
(G-INTERRUPTION built) · III PASS (monitor lives while the microphone runs; capture released on stop/background) · IV
PASS (event mapping and preset library host/simulator-tested with doubles) · V PASS (preset format 1, newer refused,
unreadable kept) · VI PASS (denied path renders every scene) · VII PASS (labels/identifiers, plain messages) · VIII PASS
(no new permission; denied path fully usable) · IX PASS (one engine at most; storage quota) · X–XIII PASS · A06 PASS.

## Project Structure

```text
Packages/VisualCoreRendering/Sources/VisualCoreAudio/{AudioSessionEvent,MicrophoneCapture}.swift              new
Packages/VisualCoreRendering/Sources/VisualCoreAudio/{AudioSource,MicrophoneAudioSource}.swift                  modify (.interrupted; handle/resume; capture seam)
Packages/VisualCoreRendering/Tests/VisualCoreAudioTests/{AudioSessionEventTests,MicrophoneRecoveryTests}.swift  new
Packages/ExperiencesCreative/VisualCoreMusicLab/Core/MusicPreset.swift                                          new (preset value, built-ins, file coding)
Packages/ExperiencesCreative/VisualCoreMusicLab/CoreTests/MusicPresetTests.swift                                new
Packages/ExperiencesCreative/VisualCoreMusicLab/Experience/MusicLabPresetStore.swift                          new
Packages/ExperiencesCreative/VisualCoreMusicLab/Experience/Adapter/MusicLabCore.swift                           modify (preset.apply)
Packages/ExperiencesCreative/VisualCoreMusicLab/Experience/{MusicLabPresenter,MusicLabControls,VisualCoreMusicLabExperience}.swift  modify
Packages/ExperiencesCreative/VisualCoreMusicLab/ExperienceTests/{MusicLabPresetStoreTests,MusicLabRecoveryTests,MusicLabDeniedUsabilityTests}.swift  new
Packages/ExperiencesCreative/VisualCoreMusicLab/scenario-manifest.json                                           regenerate (new control)
docs/api/visualcore-public-api.txt, Packages/VisualCoreRendering/README.md, Auto-Creator.md §13, docs/apps/visualcore-music-lab/visualcore-contract.{json,md}  modify
```

**Dependency direction**: experience → VisualCoreAudio (events, source) → AVFAudio; Core stays audio-free; nothing in
VisualCore depends on the experience.

**Lifecycle**: `MicrophoneAudioSource` (public init) creates its monitor on start and drops it on stop; events arrive on
the main actor. The presenter reads `activeSource.state` each frame for the status; the library loads on setup and
writes through `ExperienceStorage`. **Migration**: none (state schema unchanged; preset format 1 is new). **Rollback**:
revert the commits; preset files stay in the experience's storage and are ignored by an older build.

## Parallel work

Agent A: VisualCoreAudio events + capture seam + recovery + tests. Agent B: Core `MusicPreset` + tests. Agent C:
`MusicLabPresetStore` + tests. Lead: core action, presenter status/recovery wiring, controls, denied-usability and
recovery experience tests, manifest, docs, runs, commits.
