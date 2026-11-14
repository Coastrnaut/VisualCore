# Research: A07-P00 (feature 053)

## 0. Verified facts (2026-11-14)

- `scripts/check_app_contract.py` verifies cited files, declared symbols (public when required), products, gap coverage
  and renders the Markdown view; contracts exist for A01–A06 under `docs/apps/<slug>/`.
- `scripts/check_experience_packages.py` forbids unregistered experience targets (`EXTRA_TARGET`).
- Constitution 2.3.0 commit `fcf6ad46`; specify commit `b5c919b4`; reference pin `d93edd1`.
- `VisualCoreAudio` (sources, permission, session events, `ResumableAudioSource`) and `VisualCoreAudioDSP` (ring
  buffer, FFT, bands, onsets, smoothing, `AudioMapper`, `AnalysisQuality`) are real since A06;
  `NSMicrophoneUsageDescription` is in `project.yml`.
- `VisualCoreMath` has `OrbitCamera`, `Camera2D` and matrices; `VisualCoreRendering` has `DepthMeshPass`. No camera
  rail, path easing with comfort caps, streaming segment pool or origin rebasing exists in any product (to be
  confirmed per row by the audit).

## 1. Decisions

- **D1 Shell:** the one app is the shell (clarification 1); targets arrive in A07-P01.
  Alternative rejected: an empty registered experience (a placeholder).
- **D2 Matrix scope:** five brainstorm capabilities and the six version 0.1 features, plus the cross-cutting rows
  (audio sources and permission, interruption recovery, persistence, quality tiers, comfort, accessibility, long-
  distance precision); availability rule of clarification 2.
- **D3 Regression:** two chunks as for every VisualCore-adjacent gate (`reference-engine-xcframework
  reference-build-projectm-ios-sim reference-clean`; `reference-test-anglerendering-ios27 reference-test-anglerendering-ios26
  projectm-reference-ios27 projectm-reference-ios26`).
- **D4 Gap owners:** camera rail and rebasing → `VisualCoreMath` (A07-P01); streaming segments → `VisualCoreScenes`
  with drawing in `VisualCoreRendering` (A07-P02); audio envelope mapping → reuse `VisualCoreAudioDSP` (A07-P03).
