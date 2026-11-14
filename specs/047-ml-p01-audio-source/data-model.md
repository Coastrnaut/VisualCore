# Data model: A06-P01

- **MusicLabState** (schema 1, Codable): `source` (demo | file | microphone), `demoSeed` (UInt64), `demoMode` (sequence |
  tone440 | tone1k | silence — tone and silence for fixtures and the test list), `fileName` (String?, display only, ≤ 120
  chars), `permission` (notDetermined | granted | denied | restricted — mirrored, not persisted as authority).
  Digest: source, demoSeed, demoMode, fileName. Samples are never state.
- **Actions**: `source.demo`, `source.microphone` (refused as a rule when permission denied/restricted; when not
  determined, accepted as "requesting"), `source.file` (the presenter supplies the picked file; the core records the
  name), `demo.mode [0…3]`, `demo.reseed`.
- **SampleRingBuffer**: capacity (power of two, 1,024…262,144), written (total), latest(count:into:).
- **Spectrum**: size N ∈ {256…4,096}, magnitudesDB[N/2], peakBin.
