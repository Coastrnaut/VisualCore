# VisualCore Music Lab (`a06.visualcore-music-lab`)

A modern audio-reactive visualizer with oscillograms, spectrum analysis and customizable graphics scenes that is not a
ProjectM clone (archived manual `apps/06-visualcore-music-lab.md` §1). Audiences: musicians testing dynamics visually,
people playing owned or in-app-controlled audio, and users seeking microphone-reactive visuals (§2). Version 0.1:
microphone (permission-gated) and local file input, RMS/peak/FFT/beat-energy signals, three scenes (bars, waveform
rings, 3D-ish responsive geometry), a source/status indicator with interruption recovery, presets with local
persistence and accessibility text metrics, and a silent demo signal for offline use. Non-goals: capturing other apps'
audio, reusing MilkDrop/ProjectM engine code, recording or uploading microphone audio.

VisualCore Music Lab is an experience of the one VisualCore app (ADR-0009), built from Phase 01 on in the audio
experience package chosen in A06-P01 (`Packages/ExperiencesAudio`, recorded by the A06-P00 audit); it never has a
standalone target. Audio capture and analysis are built in VisualCore's `VisualCoreAudio` and `VisualCoreAudioDSP`
products (gaps of the contract), not in the experience. Its rules are the A06 subsection of the constitution (2.2.0).

| Document | Content |
|---|---|
| [visualcore-contract.json](visualcore-contract.json) / [.md](visualcore-contract.md) | Phase 00 inventory, capability matrix, gaps, decision (checked by `scripts/check_app_contract.py`) |
| [regression-baseline.md](regression-baseline.md) | Phase start, reference pin, the ProjectM reference regression results |

Phases: A06-P00 boundary audit (feature 046), P01 audio source and permission shell, P02 FFT/feature analysis with
fixtures, P03 three visual scenes and mapping editor, P04 presets and recovery UX, P05 audio/render performance and
accessibility, P06 final verification, privacy, packaging and release.
