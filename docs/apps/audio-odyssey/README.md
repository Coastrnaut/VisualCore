# Audio Odyssey (`a07.audio-odyssey`)

An audio-reactive journey through procedural tunnels, particle corridors and moving landscapes (archived manual
`apps/07-audio-odyssey.md` §1). Audiences: entertainment users wanting immersive visuals and creators seeking
audio-driven ambient journeys (§2). Version 0.1: three distinct procedural environments on a controlled camera rail,
audio features mapped to geometry and lighting rather than hard cuts, manual flight speed with camera easing and a
reduced-motion setting, microphone (permission-gated), app-owned file and demo input, saved environment and mapping
presets, and stable pause/resume with a thermal quality downgrade. Non-goals: system-wide capture of other apps' audio,
VR or headset support, open-world exploration.

Audio Odyssey is an experience of the one VisualCore app (ADR-0009), built from Phase 01 on in
`Packages/ExperiencesCreative/AudioOdyssey`; it never has a standalone target. It reuses the audio products that A06
built (`VisualCoreAudio`, `VisualCoreAudioDSP`); the camera rail, streaming segments and origin rebasing are built in
VisualCore (gaps of the contract), not in the experience. Its rules are the A07 subsection of the constitution (2.3.0).

| Document | Content |
|---|---|
| [visualcore-contract.json](visualcore-contract.json) / [.md](visualcore-contract.md) | Phase 00 inventory, capability matrix, gaps, decision (checked by `scripts/check_app_contract.py`) |
| [regression-baseline.md](regression-baseline.md) | Phase start, reference pin, the ProjectM reference regression results |

Phases: A07-P00 boundary audit (feature 053), P01 journey/camera comfort contract, P02 streaming procedural tunnel,
P03 audio envelope mapping, P04 multi-world presets and UI, P05 long-session performance and accessibility
verification, P06 final verification, privacy, packaging and release.
