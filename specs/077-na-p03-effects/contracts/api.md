# Contract: A10-P03 APIs and actions

## VisualCoreAudioDSP (public, `///`-documented, API baseline)

- `enum SoundWaveform: String { sine, triangle, square }`
- `struct SoundEffect: Sendable, Equatable, Codable` with the fields of data-model.md, `init(...)`, `isValid`.
- `enum SoundEffectSynth { static let defaultSampleRate = 48_000.0; static func render(_ effect: SoundEffect,
  sampleRate: Double = defaultSampleRate) -> [Float] }`

## VisualCoreAudio (public)

- `final class SoundEffectPlayer` — `init(voices: Int = 4, sampleRate: Double = 48_000)`; `var isEnabled: Bool`;
  `@discardableResult func play(_ effect: SoundEffect, id: String) -> Bool`; `func stopAll()`; `var activeVoices: Int`;
  `static let sessionCategory = AVAudioSession.Category.ambient`.

## NeonArcadeCore

- `ArcadeScreen`, `ArcadeFlow`, `ArcadeEffects.plan(previous:current:)`, `EffectCue`, `ArcadeSound` (the four shapes as
  values: waveform name, frequencies, duration, noise, gain).

## Experience actions (`a10.neon-arcade`)

`run.start`, `run.steer [−1…1]`, `run.pause [0…1]`, `run.restart`, `settings.sound [0…1]`, `settings.haptics [0…1]`;
`a10.wrong-screen` for a flow action on the wrong screen. Snapshot schema 3.
