# Research: A06-P00 (feature 046)

## 0. Verified facts (2026-11-14)

- `scripts/check_app_contract.py` (A01-P00) verifies cited files, declared symbols (public when required), products,
  gap coverage and renders the Markdown view; contracts exist for A01–A05 under `docs/apps/<slug>/`.
- `scripts/check_experience_packages.py` forbids unregistered experience targets (`EXTRA_TARGET`).
- Constitution 2.2.0 commit `c37f95fe`; reference pin `d93edd1`.
- `VisualCoreAudioDSP` (`AudioDSPInfo`) and `VisualCoreAudio` (`AudioInfo`) hold only version constants; there is no
  audio capture, decoding, FFT or band analysis in any VisualCore product; `NSMicrophoneUsageDescription` is absent.
- Only `Packages/ExperiencesCreative` exists for experiences; the audio package is an A06-P01 decision.

## 1. Decisions

- **D1 Shell:** the one app is the shell (clarification 1); targets arrive in A06-P01.
- **D2 Matrix scope:** five brainstorm capabilities and the six version 0.1 features, plus the cross-cutting rows
  (audio sources and permission, interruption recovery, persistence, still export, quality tiers,
  accessibility); availability rule of clarification 4.
- **D3 Regression:** two chunks as for every VisualCore-adjacent gate (`reference-engine-xcframework
  reference-build-projectm-ios-sim reference-clean`; `reference-test-anglerendering-ios27 reference-test-anglerendering-ios26
  projectm-reference-ios27 projectm-reference-ios26`).
