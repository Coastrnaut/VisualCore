# Implementation Plan: VisualCore Music Lab — Phase 02 FFT/feature analysis with fixtures

**Branch**: `048-ml-p02-feature-analysis` (spec directory only; work on `main`) | **Date**: 2026-11-14 | **Spec**: [spec.md](spec.md)

## Summary

Complete gap G-AUDIODSP in `VisualCoreAudioDSP` (pure, host-tested) and show its features in VisualCore Music Lab.
VisualCore gains `LevelMeter` (RMS, peak, dBFS with a −120 floor), `BandLayout` (16 log bands 40 Hz…min(16 kHz, fs/2)
over the bins of an N-point transform), an allocation-free power spectrum on `SpectrumAnalyzer` with a
`SpectrumWorkspace`, `FeatureSmoother` (attack/release in seconds, elapsed-time based), `OnsetDetector` (flux against
1.5 × mean of the previous 43 + 1e-4, 0.1 s minimum interval), `AudioFeatures` and `FeatureExtractor` (one object per
window size and sample rate holding every buffer). The experience analyses the newest 1,024 samples once per frame,
draws 16 spectrum bars, a level meter with a peak mark and a beat meter beside the waveform, resets the analysis on a
source change, and speaks the level and beat. Features are not state: digests, snapshot schema 1 and the scenario
manifest are unchanged. Research: [research.md](research.md); model: [data-model.md](data-model.md); contract:
[contracts/api.md](contracts/api.md); evidence: [quickstart.md](quickstart.md).

## Technical Context

**Language**: Swift 6 (Accelerate in VisualCoreAudioDSP, verified allowed in pure modules by
`scripts/check_dependencies.py` in A06-P01). **Verified APIs**: `SpectrumAnalyzer` (size 256…4,096, Hann,
`magnitudesDB(_:)`, scale 1/(N/2·0.5)), `SampleRingBuffer.latest(_:into:)`, `DemoSignal.Mode` {sequence, tone440, tone1k,
silence}, `FrameInfo.time` and `FrameInfo.delta` (clamped 0…0.1 s), `AudioSource.sampleRate`, `PrimitiveRenderer`
primitives used by the A06-P01 waveform. **Storage**: none new. **Testing**: host `swift test` for DSP; ExperiencesCreative
on sim-27.2 (core display mapping, sessions with the demo tone and silence); app build/unit; runner iOS 27; public API;
script tests. **Constraints**: tests < 10 s; no wall-clock asserts; analysis on the render side only (never in the audio
callback); iOS 27 only at this gate; reference regression at X-A06.

## Constitution Check

I PASS (bars and meters through the host's PrimitiveRenderer; no new context) · II PASS (analysis in a VisualCore
product; the experience keeps display mapping, copy and state) · II-a PASS (G-AUDIODSP recorded in the contract) · III
PASS (extractor created at setup, reset on source change, released at teardown) · IV PASS (all DSP and the display
mapping host-tested without GPU) · V PASS (no schema change) · VI PASS (render checks on the simulator: silence stable,
1 kHz bar) · VII PASS (level and beat in the spoken description) · VIII PASS (no new permission; nothing stored or sent) ·
IX PASS (bounded buffers, non-finite input treated as 0) · X PASS (synthetic test signals only) · XI–XIII PASS · A06
section PASS (no hearing/health/accuracy claims).

## Project Structure

```text
Packages/VisualCore/Sources/VisualCoreAudioDSP/{LevelMeter,BandLayout,FeatureSmoother,OnsetDetector,AudioFeatures,FeatureExtractor}.swift  new
Packages/VisualCore/Sources/VisualCoreAudioDSP/SpectrumAnalyzer.swift            modify (SpectrumWorkspace, powerSpectrum(_:into:workspace:))
Packages/VisualCore/Tests/VisualCoreAudioDSPTests/{LevelMeterTests,BandLayoutTests,FeatureSmootherTests,OnsetDetectorTests,FeatureExtractorTests}.swift  new
Packages/ExperiencesCreative/VisualCoreMusicLab/Core/AnalysisDisplay.swift       new  (dB → bar/meter heights; GPU-free)
Packages/ExperiencesCreative/VisualCoreMusicLab/CoreTests/AnalysisDisplayTests.swift  new
Packages/ExperiencesCreative/VisualCoreMusicLab/Experience/MusicLabPresenter.swift  modify (extractor, bars, meters, reset, description)
Packages/ExperiencesCreative/VisualCoreMusicLab/ExperienceTests/MusicLabAnalysisTests.swift  new
docs/api/visualcore-public-api.txt, Packages/VisualCore/README.md, Auto-Creator.md §13, docs/apps/visualcore-music-lab/visualcore-contract.{json,md} (G-AUDIODSP status)  modify
```

**Dependency direction**: VisualCoreMusicLabExperience → VisualCoreAudioDSP (already a dependency via VisualCoreAudio;
made explicit) ; VisualCoreMusicLabCore depends on nothing new; nothing in VisualCore depends on the experience.

**Lifecycle**: the presenter creates a `FeatureExtractor` in `setup` for the active source's sample rate, re-creates it
when the rate changes, calls `reset()` when the source key changes, analyses once per `draw` with `frame.time` and
`frame.delta`, and drops it in `teardown`. **Migration**: none. **Rollback**: revert the commits; no persisted data.

## Parallel work

Agent A: LevelMeter, BandLayout, SpectrumAnalyzer power path + tests. Agent B: FeatureSmoother, OnsetDetector + tests.
Agent C: AnalysisDisplay + tests. Lead: AudioFeatures/FeatureExtractor and tests (depends on A, B), presenter changes,
MusicLabAnalysisTests, docs/baseline, runs, commits.
