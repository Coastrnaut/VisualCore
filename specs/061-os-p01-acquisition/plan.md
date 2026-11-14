# Implementation Plan: Oscilloscope Studio — Phase 01 Audio fixture and acquisition interface

**Branch**: `061-os-p01-acquisition` (spec directory only; work on `main`) | **Date**: 2026-11-14 | **Spec**: [spec.md](spec.md)

## Summary

Close G-DEMOWAVES and G-TRIGGER in `VisualCoreAudioDSP` (pure, host-tested): `TestSignal` (sine, square, logarithmic
sweep, optional second channel), `StereoSampleBuffer` (interleaved two-channel lock-free buffer with absolute frame
reads) and `ScopeTrigger` with `TimebaseWindow` (level, slope, hysteresis, auto/normal; time per division → sample
span). Close G-STEREO for the test-signal and file paths in `VisualCoreAudio`: `StereoAudioSource`,
`TestSignalAudioSource`, `StereoFileAudioSource`. Create the experience `a08.oscilloscope-studio` in
`Packages/ExperiencesCreative/OscilloscopeStudio`: Core (`ScopeState` schema 1, `ScopeSettings` choices,
`SignalWindow`, `ScopeAcquisition` building triggered windows from a buffer), Experience (adapter `ScopeCore`, manifest,
presenter drawing grid and trace through `PrimitiveRenderer` as Music Lab does, controls), registered as a candidate
with nine standard scenarios and five fixture scenarios. Research: [research.md](research.md).

## Technical Context

**Language**: Swift 6. **Dependencies**: `VisualCoreAudioDSP` (`SampleRingBuffer`, `SpectrumAnalyzer`, new types),
`VisualCoreAudio` (`MicrophoneAudioSource`, `MicrophonePermission`, new sources), `VisualCoreScenes` (`SceneNode`,
`Primitive.line`), `VisualCoreRendering` (`PrimitiveRenderer`), `VisualCoreMath` (`Camera2D`), `VisualCoreExperience`,
`VisualCoreExperienceHost`, `VisualCoreUI`. **Storage**: experience snapshot (`ScopeState` schema 1); no files written.
**Testing**: host `swift test` (VisualCore: `TestSignalTests`, `StereoSampleBufferTests`, `ScopeTriggerTests`); the
VisualCoreRendering package's `VisualCoreAudioTests` on sim-27.2 for the new sources; ExperiencesCreative on sim-27.2
(OscilloscopeStudio core: state, settings, acquisition; adapter, manifest, session, render); app build and unit;
runner iOS 27; public API; script tests. **Performance**: window build and trigger search for 4,096 samples measured
on the host (no wall-clock assert on CI). **Constraints**: tests < 10 s; iOS 27 only; reference regression at X-A08;
no NEEDS CLARIFICATION remains.

## Constitution Check

I PASS (draws through the host's `PrimitiveRenderer`, no context) · II PASS (signals, buffer, trigger and two-channel
sources in VisualCore; scope choices, copy and UI in the experience) · II-a PASS (regression at X-A08, owner ruling) ·
III PASS (sources stop on suspend, restart on activate; windows never span a gap) · IV PASS (signal, trigger, window
host-tested with synthetic signals) · V PASS (snapshot schema 1) · VI PASS (render tests on the simulator) · VII PASS
(controls for every action; spoken canvas) · VIII PASS (the shared microphone string and permission; no recording, no
storage, no monitoring) · IX PASS (window ≤ 4,096, buffer 16,384 frames, NaN levels refused) · X PASS (no assets) ·
XI–XIII PASS. A08 rules: reuse first, audio privacy, truthful units (dBFS-relative, clipping shown), bounded
resources — PASS. Post-design: PASS.

## Project Structure

```text
Packages/VisualCore/Sources/VisualCoreAudioDSP/{TestSignal,StereoSampleBuffer,ScopeTrigger}.swift              new
Packages/VisualCore/Tests/VisualCoreAudioDSPTests/{TestSignalTests,StereoSampleBufferTests,ScopeTriggerTests}.swift new
Packages/VisualCoreRendering/Sources/VisualCoreAudio/{StereoAudioSource,TestSignalAudioSource,StereoFileAudioSource}.swift new
Packages/VisualCoreRendering/Tests/VisualCoreAudioTests/{TestSignalAudioSourceTests,StereoFileAudioSourceTests}.swift new
Packages/ExperiencesCreative/OscilloscopeStudio/Core/{ScopeSettings,ScopeState,SignalWindow,ScopeAcquisition}.swift new  domain
Packages/ExperiencesCreative/OscilloscopeStudio/CoreTests/{ScopeStateTests,SignalWindowTests,ScopeAcquisitionTests}.swift new
Packages/ExperiencesCreative/OscilloscopeStudio/Experience/{Adapter/ScopeCore.swift,Adapter/ScopeManifest.swift,
  ScopePresenter.swift,ScopeControls.swift,OscilloscopeStudioExperience.swift}                                    new
Packages/ExperiencesCreative/OscilloscopeStudio/ExperienceTests/{ScopeCoreTests,ScopeManifestTests,ScopeSessionTests,
  ScopeRenderTests}.swift, Packages/ExperiencesCreative/OscilloscopeStudio/scenario-manifest.json                new
Packages/ExperiencesCreative/Package.swift, Catalog/registrations.json, Apps/VisualCore/App/ExperienceRegistry.swift
  (candidate), project.yml (dependency), scripts/test_scripts.py (products list), RealCatalogTests (registrations) modify
docs/api/visualcore-public-api.txt, Packages/VisualCore/README.md, Packages/VisualCoreRendering/README.md,
  docs/apps/oscilloscope-studio/visualcore-contract.json (G-DEMOWAVES, G-TRIGGER, G-STEREO closed)              modify
```

**Dependency direction** (targets `OscilloscopeStudioCore`, `OscilloscopeStudioExperience`, their test targets and the
product `OscilloscopeStudioExperience`, as `scripts/check_experience_packages.py` requires; the adapter type is
`ScopeCore` so it does not shadow the `OscilloscopeStudioCore` module): OscilloscopeStudioExperience →
OscilloscopeStudioCore → VisualCoreAudioDSP; the experience → VisualCoreAudio, host and rendering; nothing in VisualCore
depends on the experience; `VisualCoreAudio` → `VisualCoreAudioDSP` only (unchanged direction).

**Lifecycle**: the presenter owns the active source (a `StereoAudioSource` for the test signal and files, the shared
mono `MicrophoneAudioSource` for the microphone), its buffer, one `ScopeAcquisition` and one `PrimitiveRenderer`
created when the host's context is current and released in teardown; suspend stops the source, activate restarts it
on a fresh buffer (no window spans the gap); the core holds only settings and advances by host steps; the window is
rebuilt each drawn frame from the buffer. **Migration**: none (new schema 1). **Rollback**: revert the commits.

## Parallel work

Agent A: VisualCoreAudioDSP `TestSignal`, `StereoSampleBuffer`, `ScopeTrigger` + tests. Agent B: VisualCoreAudio
sources + tests (against contracts/api.md; builds after A lands). Agent C: OscilloscopeStudio Core + CoreTests (against
contracts/api.md). Agent D: Experience target (adapter, manifest, presenter, controls) + tests after A–C land. Lead:
Package.swift, registrations, registry, project.yml, xcodegen, manifest regeneration, docs and API baseline, runs,
commits.
