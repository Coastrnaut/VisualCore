# Data model: A06-P02

- **AudioFeatures** (value, not persisted): `timestamp` (Double s), `rms` (Float, ≥ 0), `peak` (Float, 0…1 clamped for
  display; raw ≥ 0), `bandEnergies` ([Float], count = band count, ≥ 0, linear power), `flux` (Float ≥ 0), `onset` (Bool),
  `beatEnergy` (Float 0…1). Derived: `rmsDB`, `peakDB` = 20·log10 floored at −120; `bandDB(i)` = 10·log10 floored at −120.
- **BandLayout**: `bandCount` (1…64, default 16), `lowestFrequency` 40 Hz, `highestFrequency` min(16 kHz, fs/2),
  `sampleRate` (> 0), `size` (SpectrumAnalyzer size) → `bins: [Range<Int>]`, contiguous, increasing, non-empty, within
  1…N/2−1. Invalid input → nil.
- **FeatureSmoother**: `attack`, `release` (seconds > 0), `value` (Float); `update(target:elapsed:)` with elapsed clamped
  to ≥ 0; `reset()` → 0.
- **OnsetDetector**: `historyCount` 43, `multiple` 1.5, `minimum` 1e-4, `minimumInterval` 0.1 s, fixed ring of fluxes,
  last onset time; `update(flux:time:) -> Bool`; `reset()`.
- **FeatureExtractor**: `size` (default 1,024), `sampleRate`, `layout`, `features` (last AudioFeatures); `analyze(_:time:
  elapsed:)`, `reset()`.
- **AnalysisDisplay** (experience Core): `bars: [Double]` 0…1, `level` 0…1, `peakMark` 0…1, `beat` 0…1, from band dB,
  RMS dB, peak dB and beat energy with the −80…0 dB mapping.
- **MusicLabState**: unchanged (schema 1); digest unchanged.
