# Data Model: A10-P03

- **SoundEffect** (VisualCoreAudioDSP): `waveform` ∈ {sine, triangle, square}, `startFrequency`, `endFrequency`
  40…4,000 Hz, `duration` 0.02…1 s, `attack`, `release` ≥ 0.002 s, `noise` 0…1, `gain` 0…0.9.
- **ArcadeScreen**: title, playing, paused, over.
- **ArcadeState** (snapshot schema 3): `run`, `random`, `screen`, `sound` (Bool, default true), `haptics` (Bool,
  default true).
- **EffectCue**: `kind` ∈ {pickup, hit, wave, over}, `position` Vec2, `sound` ∈ {pickup, hit, wave, over}, `haptic`
  (HapticKind raw value).
- **Caps**: 3 visual cues and 2 sound cues per step; particle pool 256; 4 voices.
