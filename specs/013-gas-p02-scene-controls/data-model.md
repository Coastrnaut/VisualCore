# Data model: A01-P02

## SceneClock (VisualCoreSimulation, public value type)
- `duration` (default 120 s, > 0), `time` (0 ≤ time < duration), `isPlaying`, `speed` (0…4), `reducedMotion` (Bool).
- `maxDelta = 0.25` s, `reducedMotionFactor = 0.5`.
- `advance(by:)`: when playing, adds `min(max(delta, 0), maxDelta) × speed × factor`, wrapping modulo `duration`.
- `scrub(to:)` clamps; `play()`, `pause()` and `toggle()` switch state.

## ParameterEditor (VisualCoreParameters, public value type)
- `schema`, `values: [String: Double]` (every schema name; always finite and in range), `baseline`.
- `set(_ name:, to value:) -> Bool`: false for an unknown name or a non-finite value; clamps otherwise.
- `set(_ name:, normalized:)`; `normalized(_ name:)`; `reset(_:)`; `resetAll()`; `isModified(_:)`; `modifiedNames`.
- `rebase(_ values:)` sets the baseline and values; `formatted(_ name:) -> String`.

## CompositionEditor (GenerativeArtStudioCore)
- `family`, `composition: ArtDocument` (always validated), `presetID`, `notes: [String]`,
  `editor: ParameterEditor` (kept in sync with `composition.parameters`).
- Operations:
  - `choosePreset(id)` rebases the editor;
  - `choosePalette(id)` (an unknown id is ignored);
  - `setSeed(UInt64)` and `shuffleSeed(using: inout some RandomNumberGenerator)`;
  - `setParameter(name, normalized:)` and `resetParameter`/`resetAll`;
  - `open(Data) -> OpenResult`; `useDefault()`.
- `OpenResult`: `.opened(notes: [String])` | `.failed(RecoverableError)`.
- `RecoverableError`: `.corrupt(String)` | `.unsupportedVersion(Int)` | `.unknownFamily(String)`. Each provides
  `title` and `message`, the user-facing text.
