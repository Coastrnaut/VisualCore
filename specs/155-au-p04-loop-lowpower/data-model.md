# Data Model: A21-P04 (feature 155)

- **AmbientLoopRecipe** (VisualCoreAudioDSP): `seconds` 4…16 (whole, default 8), `sampleRate` 48,000, `partials`
  1…6 of (cycles per loop ≥ 1, amplitude 0…1), `swellCycles` ≥ 1, `gain` 0…0.3. Invalid recipes render no samples.
- **AmbientLoopSynth.render(_:)**: mono `[Float]` of `seconds × sampleRate` samples; deterministic; finite; |x| ≤ gain;
  the step from the last sample to the first is no larger than the largest step inside the buffer.
- **AmbientLoopPlayer** (VisualCoreAudio): `volume` 0…1 (non-finite ignored), `isEnabled`, `isPlaying`, `play()`,
  `stop()`; `volume` is the player node's volume (the buffer itself is unchanged, so a change of volume is
  immediate and never re-renders); additive API only (no existing declaration changes); `.ambient` category; stops on interruption, media-services reset and `didEnterBackground`.
- **Still view** (presenter): `stillView` flag; `CachedScene` key = digest + size; the clock holds.
- **Reduced flash**: twinkle 0; change 4.0 s; mean-luminance step < 0.02 per frame at 30 frames per second.
- **Fallback**: `SkyShader.fallbackSource` (gradient of the preset's sky colour to 0.6 × at the horizon, under the
  limit); message "This device shows a simpler sky."
