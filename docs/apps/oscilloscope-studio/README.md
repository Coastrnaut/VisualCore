# Oscilloscope Studio (`a08.oscilloscope-studio`)

A responsive and technically legible waveform, XY (Lissajous) and spectrum display for permitted audio inputs
(archived manual `apps/08-oscilloscope-studio.md` §1). Audiences: musicians and audio enthusiasts, makers exploring
signals, educators demonstrating time and frequency domains (§2). Version 0.1: a time-domain waveform with adjustable
gain, timebase and a selectable trigger; a stereo XY view where stereo input exists; an FFT spectrum with relative
(dBFS) annotation; freeze, cursors and touch zoom; a synthetic sine, square and sweep generator for demos and tests; a
permission-aware audio input state with a safe microphone policy. Non-goals: a certified calibrated measuring
instrument, system-wide interception of other apps' audio, medical or laboratory accuracy claims.

Oscilloscope Studio is an experience of the one VisualCore app (ADR-0009), built from Phase 01 on in
`Packages/ExperiencesCreative/OscilloscopeStudio`; it never has a standalone target. It reuses the shared audio
products (`VisualCoreAudio`, `VisualCoreAudioDSP`); trigger and timebase, display decimation, the square and sweep
demo, two-channel capture and multi-point trace strips are built in VisualCore (gaps of the contract), not in the
experience. Its rules are the A08 subsection of the constitution (2.4.0).

| Document | Content |
|---|---|
| [visualcore-contract.json](visualcore-contract.json) / [.md](visualcore-contract.md) | Phase 00 inventory, capability matrix, gaps, decision (checked by `scripts/check_app_contract.py`) |
| [regression-baseline.md](regression-baseline.md) | Phase start, reference pin, the ProjectM reference regression results |

Phases: A08-P00 boundary audit (feature 060), P01 audio fixture and acquisition interface, P02 timebase/trigger
waveform renderer, P03 spectrum and XY modes, P04 cursors, freeze and presets, P05 device-route and accuracy audits,
P06 final verification, privacy, packaging and release.
