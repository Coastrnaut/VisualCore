# Data model: A01-P01

## VisualCoreParameters (pure, public)

- `ParameterTransform`: `linear` | `logarithmic` (log requires minimum > 0).
- `ParameterDefinition`: `name` (`^[a-zA-Z][a-zA-Z0-9_]{0,31}$`), `title`, `unit` (free text, e.g. "×", "Hz", "px"),
  `range` (finite, min < max), `defaultValue` (within range), `transform`. Provides `normalized(_:)` and
  `value(normalized:)` for UI sliders (0…1).
- `ParameterSchema`: ordered `[ParameterDefinition]`, unique names, ≤ 64 parameters.
  `resolve([String: Double]) throws(ParameterError) -> ResolvedParameters`:
  - non-finite values throw `.nonFinite(name)`;
  - out-of-range values are clamped, with a warning;
  - missing values take the default;
  - unknown names are dropped, with a warning.
- `ResolvedParameters`: `values: [String: Double]` (every schema name), `warnings: [String]`.
- `Palette`: `id` (`^[a-z0-9-]{1,40}$`), `name`, `stops: [SIMD3<Double>]` (sRGB 0…1, 2–8 stops). Provides
  `linearStops` (exact sRGB→linear) and `sample(_ t: Double) -> SIMD3<Double>` (linear-light interpolation, clamped t).
  `Palette.builtIns` lists 6 general palettes.
- `Preset`: `id`, `title`, `seed: UInt64`, `paletteID`, `values: [String: Double]` (Codable; seed as a decimal string).
- `ParameterHash.of(scope:seed:paletteID:values:) -> String`: FNV-1a 64, 16 lowercase hex digits (research R1).

## VisualCoreTestSupport (test-only)

- `ImageComparison.compare(_ a: [UInt8], _ b: [UInt8]) -> ImageDifference` (RGBA8, equal length).
  `ImageDifference` holds `meanAbsolute` (0…255), `maxAbsolute`, and `fractionWithin(_ tolerance:)`, computed over
  RGB channels.
- `ImageStatistics.of(_ rgba:) -> (meanLuminance 0…1, distinctColors quantized to 5 bits per channel)`.

## GenerativeArtStudioCore (app package, pure)

- `SceneFamilyID`: `gradient-noise` | `raymarched-shapes` | `geometric-tiling` | `particles`.
- `SceneFamily`: `id`, `title`, `summary`, `accessibilityDescription`, `symbol` (SF Symbol name), `shader` (fragment
  file name), `schema: ParameterSchema`, `defaultPaletteID`, `presets: [Preset]` (≥ 1).
- `FamilyCatalog.all`: the four families. `palettes`: the palette set the app offers (built-ins plus app palettes).
- `ArtDocument` (schema version 1): `id: UUID`, `schemaVersion: Int`, `familyID`, `seed: UInt64` (string in JSON),
  `paletteID`, `parameters: [String: Double]`, `previewTime: Double` (seconds, 0…120).
  `ArtDocument.validated() throws(DocumentError) -> (ArtDocument, warnings)`:
  - unknown family or newer schema throws;
  - non-finite values throw;
  - parameters are resolved through the family schema;
  - an unknown palette falls back to the default, with a warning;
  - `previewTime` is clamped to 0…120.

  Also provides `canonicalJSON() -> Data`, `hash` (ParameterHash), and `migrate(from version:)` (hook; v1 only).
- `SeedOffsets.of(seed) -> SIMD4<Double>`: four values in [0, 1), the first four outputs of `SeededRandom(seed)`.
- `ParticleReplay`: builds a `ParticleSystem` (capacity ≤ 10,000) from the document, then
  `instances(at time:) -> [ParticleInstance]` after replaying `min(time, 120) * 60` steps.
