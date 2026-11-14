# Data Model: A08-P04

- **ScopeState** (schema 3): A08-P03's fields + `frozen: Bool`, `cursorsShown: Bool`, `cursorA`, `cursorB`,
  `frequencyCursor` ∈ [0, 1], `levelCursor` ∈ [−1, 1] (finite; NaN refused). Migration 2 → 3: false, false, 0.25,
  0.75, 0.5, 0.5.
- **ScopeReadout**: `time(a:b:spanSeconds:sampleRate:) -> (text: String, frequencyText: String)`;
  `level(_ value: Double) -> String`; `spectrumFrequency(position:sampleRate:width:binWidth:) -> String`.
- **ScopePreset** (format 1): `id` UUID, `name` 1…40 characters after trimming, `savedAt` Date, `settings` (waveform,
  frequency index, gain index, timebase index, trigger level, slope, mode, display); file `scope-<lowercased uuid>.json`;
  greater format → `.newer`; built-ins with ids `00000000-0000-4000-8000-0000000008a1…a3`.
- **ScopeZoom**: `step(scale:lastStepScale:) -> Int` (−1, 0, +1) and the clamped index.
