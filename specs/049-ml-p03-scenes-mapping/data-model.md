# Data model: A06-P03

- **AudioFeatureKind** (VisualCore): `level`, `peak`, `beat`, `low`, `lowMid`, `highMid`, `high` (raw strings; index order
  0…6 for actions). Regions = bands 0–3, 4–7, 8–11, 12–15 of a 16-band layout (bands beyond the count read 0).
- **AudioMapping** (VisualCore, Codable, `schemaVersion` 1): `feature`, `gain` (0…4), `attack`, `release` (0.001…5 s),
  `clampLow`, `clampHigh` (0 ≤ low < high ≤ 1). Invalid on decode → error.
- **AudioMapper** (VisualCore): `mapping`, smoother state; `value(for:range:elapsed:) -> Double`, `normalized(_:)`,
  `reset()`.
- **MusicLabScene** (Core): `bars` 0, `rings` 1, `geometry` 2; `parameters: [SceneParameter]`, `defaultChoices`.
- **SceneParameter** (Core): `name`, `title`, `range` (ClosedRange<Double>), `attack`, `release`.
- **MappingChoice** (Core): `feature` (0…6), `gain` (0…4, finite).
- **MusicLabState** (schema 2): source, demoSeed, demoMode, `scene` (0…2), `mappings` ([[MappingChoice]], 3 lists, each
  exactly its scene's parameter count). Persisted: all of these. Digest: source, demoSeed, demoMode, scene, every choice.
  fileName and permission as in A06-P01/P02 (display/mirror only).
