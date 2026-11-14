# Implementation Plan: VisualCore Music Lab — Phase 01 Audio source and permission shell

**Branch**: `047-ml-p01-audio-source` (spec directory only; work on `main`) | **Date**: 2026-11-14 | **Spec**: [spec.md](spec.md)

## Summary

Build the first audio layer of VisualCore and the first Music Lab slice. `VisualCoreAudioDSP` (pure) gains
`SampleRingBuffer` (SPSC, `Atomic` positions), `DemoSignal` (seeded tone sequence plus noise, and pure tone /
silence modes for fixtures) and `SpectrumAnalyzer` (vDSP real FFT, Hann window, peak bin). `VisualCoreAudio` (iOS)
gains `AudioSource` with `DemoAudioSource`, `FileAudioSource` (AVAudioFile, chunked, looped) and
`MicrophoneAudioSource` (AVAudioEngine input tap) behind `MicrophonePermission` (system and test double). The
experience `a06.visualcore-music-lab` in `Packages/ExperiencesCreative/VisualCoreMusicLab` selects a source, shows its status and draws its waveform through
`PrimitiveRenderer`; it registers as a candidate with nine standard scenarios and five fixture scenarios. The app
declares `NSMicrophoneUsageDescription`. Research: [research.md](research.md).

## Technical Context

**Language**: Swift 6 (Synchronization, Accelerate, AVFoundation). **Storage**: experience snapshot (selected source,
demo seed, file display name) schema 1; no audio stored. **Testing**: host `swift test` (ring buffer, demo signal,
spectrum fixture); VisualCoreRendering on sim-27.2 (sources: demo, generated WAV/CAF/M4A files, permission double);
ExperiencesCreative on sim-27.2 (core, sessions, manifest); app build/unit; runner iOS 27; public API; script tests.
**Constraints**: tests < 10 s; no wall-clock asserts on CI; iOS 27 only at this gate; reference regression at X-A06.

## Constitution Check

I PASS (waveform through the host's PrimitiveRenderer) · II PASS (audio and DSP in VisualCore products; the experience
keeps only UI/copy/state) · II-a PASS · III PASS (sources started/stopped with the session lifecycle) · IV PASS (DSP and
core host-tested; no device needed) · V PASS (snapshot schema 1) · VI PASS (render tests on the simulator) · VII PASS
(buttons for every source; spoken canvas) · VIII PASS (usage string, permission only on request, demo without it) ·
IX PASS (file decode bounded, invalid refused) · X PASS (generated test audio, no bundled music) · XI–XIII PASS.

## Project Structure

```text
Packages/VisualCore/Sources/VisualCoreAudioDSP/{SampleRingBuffer,DemoSignal,SpectrumAnalyzer}.swift   new
Packages/VisualCore/Tests/VisualCoreAudioDSPTests/{SampleRingBufferTests,DemoSignalTests,SpectrumAnalyzerTests}.swift  new (+ testTarget in Package.swift)
Packages/VisualCoreRendering/Sources/VisualCoreAudio/{AudioSource,DemoAudioSource,FileAudioSource,MicrophoneAudioSource,MicrophonePermission}.swift  new
Packages/VisualCoreRendering/Tests/VisualCoreAudioTests/{DemoAudioSourceTests,FileAudioSourceTests,MicrophonePermissionTests}.swift  new (+ testTarget)
Packages/ExperiencesCreative/VisualCoreMusicLab/Core/{MusicLabState,SourceKind}.swift                          new  domain (GPU/device-free)
Packages/ExperiencesCreative/VisualCoreMusicLab/Experience/{Adapter/MusicLabCore.swift,Adapter/MusicLabManifest.swift,MusicLabPresenter.swift,MusicLabControls.swift,VisualCoreMusicLabExperience.swift}  new
Packages/ExperiencesCreative/VisualCoreMusicLab/{CoreTests,ExperienceTests}/…, Packages/ExperiencesCreative/VisualCoreMusicLab/scenario-manifest.json      new
Packages/ExperiencesCreative/Package.swift, Catalog/registrations.json, Apps/VisualCore/App/ExperienceRegistry.swift (candidate), project.yml (dependency, NSMicrophoneUsageDescription)  modify
docs/api/visualcore-public-api.txt, Packages/VisualCore/README.md, Packages/VisualCoreRendering/README.md, Auto-Creator.md §13   modify
```

**Dependency direction**: VisualCoreMusicLabExperience → VisualCoreAudio → VisualCoreAudioDSP; experience → VisualCore
host/rendering; nothing in VisualCore depends on the experience.

**Lifecycle**: the presenter owns the active `AudioSource` and one `SampleRingBuffer`; the source starts on activate
and stops on suspend/teardown; switching stops the old source before starting the new one; permission is re-read on
activate. **Migration**: none (new schema 1). **Rollback**: revert the commits.

## Parallel work

Agent A: VisualCoreAudioDSP + tests. Agent B: VisualCoreAudio + tests. Agent C: experience package targets, core,
presenter, controls, manifest, tests, registration. Lead: project.yml (usage string, dependency), xcodegen, manifest
regeneration, docs/baseline, runs, commits.
