# Research: A07-P04 (feature 057)

## 0. Verified facts (2026-11-14)

- `ExperienceStorage.write(_:to:)` writes atomically and enforces `StorageQuota`; `read`, `list`, `remove` throw
  `StorageError` with codes; the A07 factory already receives the storage.
- A06's `MusicPreset` and `MusicLabPresetStore` implement clean/unique names, built-ins first, counted unreadable and
  newer files, atomic writes; they live in another experience and are not imported.
- The A07 core accepts `world.select`, `mapping.set`, `speed.set`, `easing.select`, `comfort.calm` with validation.

## 1. Decisions

- **D1 Split:** pure `JourneyPreset` in Core; storage-bound `JourneyPresetStore` in the experience (as A06).
- **D2 Apply:** `preset.apply` with values [world, (primary channel, primary sensitivity, light channel, light
  sensitivity) × 3, speedTarget, easing, calm] = 16 numbers; the core validates and applies atomically (refused as a
  whole when any value is invalid).
- **D3 File:** `journey-<uuid>.json`, `{"calm":…,"easing":…,"format":1,"id":…,"mappings":[…],"name":…,"saved":…,
  "speedTarget":…,"world":…}` sorted keys; greater format → newer (counted); anything else undecodable → unreadable.
- **D4 Trace:** `DemoResponseTrace.run(seed:world:mapping:frames:step:)` feeds `DemoSignal`-like synthetic band
  energies? No — Core cannot import audio; the trace takes a closure or precomputed `[ [Float] ]` band frames. The
  experience test produces the band frames with the real `DemoSignal` + `FeatureExtractor`; Core tests use synthetic
  frames. Determinism and the 25% rise are asserted in both.
- **D5 Picker:** segmented control sending the existing source actions; status from the presenter.
