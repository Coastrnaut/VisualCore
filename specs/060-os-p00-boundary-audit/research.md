# Research: A08-P00 (feature 060)

## 0. Verified facts (2026-11-14)

- `scripts/check_app_contract.py` verifies cited files, declared symbols (public when required), products, gap coverage
  and renders the Markdown view; contracts exist for A01–A07 under `docs/apps/<slug>/`.
- `scripts/check_experience_packages.py` forbids unregistered experience targets (`EXTRA_TARGET`).
- Constitution 2.4.0 commit `0cdd2ca0`; specify commit `6fdb5ca9`; reference pin `d93edd1`.
- `VisualCoreAudio` (sources, permission, session events, `ResumableAudioSource`) and `VisualCoreAudioDSP` (ring
  buffer, FFT, bands, onsets, smoothing, `AudioMapper`, `AnalysisQuality`) are real since A06;
  `NSMicrophoneUsageDescription` is in `project.yml`.
- Every shared source writes mono samples (`AudioSource.swift`, the microphone and file sources mix down);
  `DemoSignal.Mode` is `sequence`, `tone440`, `tone1k`, `silence`; `SpectrumAnalyzer.magnitudesDB` floors at −200 dB
  and `expectedBin` maps a frequency to its bin; the scene graph's only line is the two-point `.line(Vec2, Vec2,
  width:)` drawn by `PrimitiveRenderer`. No trigger detection, timebase window, min/max decimation, square or sweep
  demo, two-channel capture or multi-point trace strip exists in any product (to be confirmed per row by the audit).

## 1. Decisions

- **D1 Shell:** the one app is the shell (clarification 1); targets arrive in A08-P01.
  Alternative rejected: an empty registered experience (a placeholder).
- **D2 Matrix scope:** five brainstorm capabilities and the six version 0.1 features, plus the cross-cutting rows
  (audio sources and permission, interruption recovery, persistence, quality tiers, accessibility, units and
  calibration, freeze and cursors); availability rule of clarification 2.
- **D3 Regression:** two chunks as for every VisualCore-adjacent gate (`reference-engine-xcframework
  reference-build-projectm-ios-sim reference-clean`; `reference-test-anglerendering-ios27 reference-test-anglerendering-ios26
  projectm-reference-ios27 projectm-reference-ios26`).
- **D4 Gap owners (clarification 5):** square and sweep demo → `VisualCoreAudioDSP` and two-channel capture →
  `VisualCoreAudio` (A08-P01); trigger and timebase window and min/max decimation → `VisualCoreAudioDSP`, multi-point
  trace strips → `VisualCoreScenes` with drawing in `VisualCoreRendering` (A08-P02); spectrum annotation and XY mode →
  app-local (A08-P03); spoken measurements → app-local (A08-P05).
