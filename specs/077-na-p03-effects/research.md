# Research: A10-P03 Visual effects and audio/haptics

Facts verified on 2026-11-14: see spec Clarifications.

## D1 — Synth

- **Decision**: per-sample phase accumulation with the frequency interpolated exponentially from start to end; sine,
  triangle and square waves; noise from a fixed xorshift generator seeded from the effect's parameters; amplitude =
  gain × envelope (linear attack, sustain, linear release); output clamped to ±gain. Sample rate 48,000 by default.
- **Alternatives**: AVAudioUnit generators (non-deterministic, not host-testable); bundled files (forbidden).

## D2 — Player

- **Decision**: an `AVAudioEngine` with 4 `AVAudioPlayerNode`s connected to the main mixer, buffers made from the
  synth once per effect id; `AVAudioSession` category `.ambient` (mixes, silent switch, no input → no permission
  prompt); observes interruption and `didEnterBackground` to `stopAll()`; `isEnabled = false` makes `play` a no-op. The
  engine starts lazily on the first play and failures are reported as `false` (no crash).
- **Alternatives**: `AudioServicesPlaySystemSound` (needs files); one node (no overlap).

## D3 — Flow

- **Decision**: `ArcadeFlow.apply(_ action:, screen:) -> ArcadeScreen?` (nil = refused): title + start → playing;
  over + start → playing (new run); playing + pause 1 → paused; paused + pause 0 → playing; paused/over + restart →
  playing (new run). `run.paused` mirrors the paused screen so Phase 01/02 logic is unchanged; the core advances only
  when the screen is playing.

## D4 — Effect plans

- **Decision**: `ArcadeEffects.plan(previous: GameRun?, current: GameRun) -> [EffectCue]` from events with index >
  previous eventCount (pickup, hit), a wave change and a newly over run; at most 3 visual and 2 sound cues per call
  (first by event order). Each cue carries kind, position, sound shape and haptic kind. Pure; the presenter applies it.

## D5 — Fixtures

- **Decision**: `HighSpeedFixtureTests` (20, 50, 100 units/s, hit and side-pass); manifest fixture 12 plays a run past
  its first hit; fixtures 13 (title → start), 14 (settings off) added; fixtures 1–11 get a leading `run.start` and are
  regenerated.
