# Data Model: A08-P01

- **TestSignal** (VisualCoreAudioDSP, value): `waveform` ∈ {sine, square, sweep}; `frequency` Hz in 20…20,000
  (sweep: start), `sweepEnd` Hz (sweep only), `sweepDuration` s > 0; `amplitude` 0…1; `sampleRate` > 0;
  `rightRatio` > 0 (right frequency = ratio × left; 1 = same), `rightPhase` radians; `channelCount` 1 or 2.
  Deterministic: `render(frames:left:right:)` continues from its own frame position.
- **StereoSampleBuffer** (class, lock-free single writer): `capacityFrames` power of two 1,024…131,072;
  `totalFrames`; `write(left:right:)` (equal lengths); `frames(from:count:left:right:) -> Int` (0 when the range was
  overwritten or not yet written); `latestFrames(_:left:right:)`.
- **TriggerSettings**: `channel` 0/1, `level` −1…1 (finite), `slope` ∈ {rising, falling}, `hysteresis` 0…0.5
  (default 0.02), `mode` ∈ {auto, normal}. **TriggerResult**: crossing frame or none.
- **TimebaseWindow**: `secondsPerDivision` > 0, `divisions` = 10 → `sampleCount(sampleRate:)` = min(round(s/div × 10 ×
  rate), 4,096) and `isShortened`.
- **SignalWindow** (OscilloscopeStudioCore): `sampleRate`, `channelCount` 1…2, `sampleCount`, `startFrame`, `left`,
  `right` (empty when mono), `triggered`, `partial`, `clipped` (after gain).
- **ScopeState** (schema 1): `source` ∈ {testSignal, file, microphone}, `waveform` ∈ {sine, square, sweep},
  `frequencyIndex` into {100, 440, 1,000, 5,000 Hz}, `gainIndex` into {0.5, 1, 2, 5, 10}, `timebaseIndex` into
  {0.1, 0.2, 0.5, 1, 2, 5 ms/div}, `trigger` (level, slope, mode). Unknown indices refused; digest over all fields.
