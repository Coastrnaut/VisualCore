# Contract: A10-P02 core additions

## NeonArcadeCore (public within the package, `///`-documented)

- `Lanes` — `static let count = 5`; `static func centre(_ lane: Int) -> Double`.
- `SpawnPattern`, `PatternTable` — `static let bundled: [SpawnPattern]`; `pattern(id:)`.
- `Difficulty` — `init(wave: Int)`; `level`, `fallSpeed: ClosedRange<Double>`, `spawnGap: Int`, `orbMultiplier: Int`;
  `static let ceilingLevel = 8`.
- `WaveDirector` — `static let waveLength = 600`; `static func step(_ run: inout GameRun, random: inout
  SeededRandom) -> [SpawnRequest]`; `SpawnRequest(lane:kind:contentId:)`.
- `GameRun` — schema 2; `migrated() -> GameRun`.
- `LicenseAudit` — rows include patterns (role `pattern`).

## Experience

Snapshot schema 2 (`ArcadeState`), migration 1 → 2, `ArcadeCore.schemaOneExample(seed:) -> MigrationExample?`.
Actions unchanged.
